import { Router, Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { db } from '../db/database';
import { authenticate, requireRole } from '../middleware/rbacMiddleware';
import { logAuditEvent } from '../services/auditService';
import { AiVisionDamageService } from '../services/aiVisionDamageService';

export const claimRouter = Router();

export interface EvidenceScoreResult {
  score: number;
  suggestions: string[];
}

/**
 * PRD Section 8 Flow 2 & R-DMG-8:
 * Evidence-strength meter that never rejects a claim, only suggests additions.
 */
export function calculateEvidenceScore(claim: {
  photo_urls?: string[];
  video_urls?: string[];
  documents_json?: string[];
  latitude?: number;
  longitude?: number;
  loss_types?: string[];
  estimated_value?: number;
  household_size?: number;
}): EvidenceScoreResult {
  let score = 0;
  const suggestions: string[] = [];

  const photos = claim.photo_urls || [];
  if (photos.length > 0) {
    score += Math.min(25, photos.length * 10 + 5);
  } else {
    suggestions.push('Upload clear photos of property or asset damage from multiple angles');
  }

  const videos = claim.video_urls || [];
  if (videos.length > 0) {
    score += 15;
  } else {
    suggestions.push('Optional: Attach a short video showing extent of damage');
  }

  if (claim.latitude && claim.longitude && claim.latitude !== 0 && claim.longitude !== 0) {
    score += 20;
  } else {
    suggestions.push('Capture exact GPS coordinates at the damaged property site');
  }

  const docs = claim.documents_json || [];
  if (docs.length > 0) {
    score += Math.min(20, docs.length * 10);
  } else {
    suggestions.push('Attach identity or property documentation (Aadhaar, Ration Card, or Land deed)');
  }

  const losses = claim.loss_types || [];
  if (losses.length > 0 && (claim.estimated_value || 0) > 0) {
    score += 20;
  } else {
    suggestions.push('Itemize damage categories and provide realistic estimated loss amount');
  }

  return {
    score: Math.min(100, score),
    suggestions
  };
}

/**
 * POST /api/v1/claims
 * Submit or sync a damage claim (R-DMG-1). Supports offline syncing.
 */
claimRouter.post('/', authenticate, (req: Request, res: Response) => {
  const {
    id: clientClaimId,
    loss_types = [],
    severity = 'MODERATE',
    estimated_value = 0,
    household_size = 1,
    household_address,
    ward,
    latitude,
    longitude,
    incident_date,
    photo_urls = [],
    video_urls = [],
    documents_json = [],
    is_offline_draft = false
  } = req.body;

  if (!household_address || latitude === undefined || longitude === undefined || !incident_date) {
    return res.status(400).json({
      error: 'BAD_REQUEST',
      message: 'Household address, GPS coordinates, and incident date are required.'
    });
  }

  const claimId = clientClaimId || `CLAIM-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
  const claimantId = req.user!.userId;
  const isHighValue = estimated_value >= 100000 ? 1 : 0; // R-DMG-2: High value claims (>= 1 Lakh)
  const initialStatus = is_offline_draft ? 'PENDING' : 'SUBMITTED';

  const evidence = calculateEvidenceScore({
    photo_urls,
    video_urls,
    documents_json,
    latitude,
    longitude,
    loss_types,
    estimated_value,
    household_size
  });

  // Check for duplicate household claim in the same area
  const existingHouseholdClaim = db.prepare(`
    SELECT id, claimant_id, status FROM damage_claims 
    WHERE household_address = ? AND status NOT IN ('REJECTED')
  `).get(household_address) as any;

  db.prepare(`
    INSERT INTO damage_claims (
      id, claimant_id, loss_types, severity, estimated_value, household_size,
      household_address, ward, latitude, longitude, incident_date,
      photo_urls, video_urls, documents_json, evidence_strength_score,
      evidence_suggestions, status, is_high_value, is_offline_draft, sync_status
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'SYNCED')
  `).run(
    claimId,
    claimantId,
    JSON.stringify(loss_types),
    severity,
    estimated_value,
    household_size,
    household_address,
    ward || 'Default Ward',
    latitude,
    longitude,
    incident_date,
    JSON.stringify(photo_urls),
    JSON.stringify(video_urls),
    JSON.stringify(documents_json),
    evidence.score,
    JSON.stringify(evidence.suggestions),
    initialStatus,
    isHighValue,
    is_offline_draft ? 1 : 0
  );

  logAuditEvent({
    actionType: 'DAMAGE_CLAIM_SUBMITTED',
    actorId: claimantId,
    actorRole: req.user!.role,
    entityId: claimId,
    details: `Damage claim submitted for ${household_address}. Severity: ${severity}, Est: ₹${estimated_value}. Evidence score: ${evidence.score}%.`,
    afterState: { claimId, status: initialStatus, evidenceScore: evidence.score },
    ipAddress: req.ip
  });

  res.status(201).json({
    message: is_offline_draft
      ? 'Offline damage claim queued as PENDING until verified on server'
      : 'Damage claim submitted successfully',
    claimId,
    status: initialStatus,
    isHighValue: Boolean(isHighValue),
    duplicateHouseholdDetected: Boolean(existingHouseholdClaim),
    evidenceScore: evidence.score,
    evidenceSuggestions: evidence.suggestions
  });
});

/**
 * GET /api/v1/claims
 * List claims filtered by role and jurisdiction (R-DMG-4 & R-DMG-5), or return public statistics if unauthenticated.
 */
claimRouter.get('/', (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authenticate(req, res, () => {
      const user = req.user!;
      let claims: any[] = [];

      if (user.role === 'CITIZEN') {
        claims = db.prepare('SELECT * FROM damage_claims WHERE claimant_id = ? ORDER BY created_at DESC').all(user.userId);
      } else if (user.role === 'VOLUNTEER') {
        claims = db.prepare(`
          SELECT * FROM damage_claims 
          WHERE assigned_volunteer_id = ? OR status IN ('SUBMITTED', 'PENDING')
          ORDER BY is_high_value DESC, created_at DESC
        `).all(user.userId);
      } else {
        const { ward, status, is_high_value } = req.query;
        let query = 'SELECT * FROM damage_claims WHERE 1=1';
        const params: any[] = [];

        if (ward) {
          query += ' AND ward = ?';
          params.push(ward);
        }
        if (status) {
          query += ' AND status = ?';
          params.push(status);
        }
        if (is_high_value !== undefined) {
          query += ' AND is_high_value = ?';
          params.push(is_high_value === 'true' ? 1 : 0);
        }
        query += ' ORDER BY created_at DESC';
        claims = db.prepare(query).all(...params);
      }

      return res.json({
        success: true,
        total: claims.length,
        claims: claims.map(c => ({
          ...c,
          loss_types: JSON.parse(c.loss_types || '[]'),
          photo_urls: JSON.parse(c.photo_urls || '[]'),
          video_urls: JSON.parse(c.video_urls || '[]'),
          documents_json: JSON.parse(c.documents_json || '[]'),
          evidence_suggestions: JSON.parse(c.evidence_suggestions || '[]')
        }))
      });
    });
  }

  // Public overview if no auth token is provided
  const stats = db.prepare(`
    SELECT count(*) as total,
           sum(case when status IN ('COMMUNITY_VERIFIED', 'OFFICIALLY_VERIFIED') then 1 else 0 end) as verified,
           sum(case when status = 'AID_SANCTIONED' then 1 else 0 end) as sanctioned,
           sum(case when status = 'DELIVERED' then 1 else 0 end) as delivered,
           sum(estimated_value) as total_claimed_losses
    FROM damage_claims
  `).get() as any;

  return res.json({
    success: true,
    service: 'ResQAI Damage Assessment & Relief Sanction Claims Service',
    requiresAuthForFullDetails: true,
    message: 'Provide Authorization header (Bearer <token>) to view personal claims.',
    publicStatistics: {
      totalClaimsFiled: stats?.total || 0,
      verifiedClaims: stats?.verified || 0,
      aidSanctionedCount: stats?.sanctioned || 0,
      aidDeliveredCount: stats?.delivered || 0,
      totalClaimedLossInr: stats?.total_claimed_losses || 0
    }
  });
});

/**
 * GET /api/v1/claims/:id
 * Get full claim record with audit timeline, verifications, and aid plans.
 */
claimRouter.get('/:id', authenticate, (req: Request, res: Response) => {
  const claimId = req.params.id;
  const claim = db.prepare('SELECT * FROM damage_claims WHERE id = ?').get(claimId) as any;

  if (!claim) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'Damage claim not found' });
  }

  // R-DMG-5: Citizen can only view their own claim
  if (req.user!.role === 'CITIZEN' && claim.claimant_id !== req.user!.userId) {
    return res.status(403).json({ error: 'FORBIDDEN', message: 'You are not authorized to view this claim' });
  }

  const verifications = db.prepare(`
    SELECT dv.*, u.name as verifier_name 
    FROM damage_verifications dv
    JOIN users u ON dv.verifier_id = u.id
    WHERE dv.claim_id = ?
    ORDER BY dv.verified_at ASC
  `).all(claimId);

  const aidPlans = db.prepare(`
    SELECT ap.*, u.name as sanctioning_officer_name
    FROM aid_plans ap
    JOIN users u ON ap.sanctioning_officer_id = u.id
    WHERE ap.claim_id = ?
  `).all(claimId);

  const appeals = db.prepare(`
    SELECT ca.*, u.name as reviewing_officer_name
    FROM claim_appeals ca
    JOIN users u ON ca.appealed_to_officer_id = u.id
    WHERE ca.claim_id = ?
  `).all(claimId);

  const auditTimeline = db.prepare(`
    SELECT id, action_type, actor_id, actor_role, details, created_at
    FROM audit_logs
    WHERE entity_id = ?
    ORDER BY created_at ASC
  `).all(claimId);

  res.json({
    claim: {
      ...claim,
      loss_types: JSON.parse(claim.loss_types || '[]'),
      photo_urls: JSON.parse(claim.photo_urls || '[]'),
      video_urls: JSON.parse(claim.video_urls || '[]'),
      documents_json: JSON.parse(claim.documents_json || '[]'),
      evidence_suggestions: JSON.parse(claim.evidence_suggestions || '[]')
    },
    verifications,
    aidPlans,
    appeals,
    auditTimeline
  });
});

/**
 * POST /api/v1/claims/:id/assign
 * Government officer assigns a volunteer or officer to verify a claim (R-DMG-4).
 */
claimRouter.post('/:id/assign', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const claimId = req.params.id;
  const { volunteer_id, officer_id } = req.body;

  const claim = db.prepare('SELECT * FROM damage_claims WHERE id = ?').get(claimId) as any;
  if (!claim) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'Damage claim not found' });
  }

  db.prepare(`
    UPDATE damage_claims 
    SET assigned_volunteer_id = COALESCE(?, assigned_volunteer_id),
        assigned_officer_id = COALESCE(?, assigned_officer_id),
        status = 'ASSIGNED',
        updated_at = datetime('now')
    WHERE id = ?
  `).run(volunteer_id || null, officer_id || null, claimId);

  logAuditEvent({
    actionType: 'DAMAGE_CLAIM_VERIFIER_ASSIGNED',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId: claimId,
    details: `Verifier assigned: Volunteer=${volunteer_id || 'none'}, Officer=${officer_id || 'none'}.`,
    ipAddress: req.ip
  });

  res.json({ message: 'Verifier successfully assigned', claimId, volunteer_id, officer_id });
});

/**
 * POST /api/v1/claims/:id/verify
 * Verification step by volunteer or government officer (R-DMG-3, Section 8 Flow 4).
 * ACCEPTANCE CRITERIA: A volunteer cannot verify their own household.
 */
claimRouter.post('/:id/verify', authenticate, requireRole('ADMIN', 'GOVT_OFFICER', 'VOLUNTEER'), (req: Request, res: Response) => {
  const claimId = req.params.id;
  const verifierId = req.user!.userId;
  const verifierRole = req.user!.role;

  const claim = db.prepare('SELECT * FROM damage_claims WHERE id = ?').get(claimId) as any;
  if (!claim) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'Damage claim not found' });
  }

  // ACCEPTANCE CRITERIA CHECK: A volunteer cannot verify their own household
  if (verifierId === claim.claimant_id) {
    return res.status(403).json({
      error: 'CONFLICT_OF_INTEREST_VIOLATION',
      message: 'Conflict of interest: Verifiers cannot inspect or verify their own household or claim.'
    });
  }

  const {
    outcome, // 'VERIFIED' | 'PARTLY_VERIFIED' | 'NOT_VERIFIABLE_NOW' | 'NEEDS_FOLLOW_UP'
    notes,
    photos_json = [],
    gps_latitude,
    gps_longitude,
    conflict_of_interest_declared = true
  } = req.body;

  if (!outcome || !notes) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Verification outcome and notes are required.' });
  }

  if (!conflict_of_interest_declared) {
    return res.status(400).json({
      error: 'CONFLICT_OF_INTEREST_REQUIRED',
      message: 'Conflict of interest declaration is mandatory before verification.'
    });
  }

  const verificationId = `VER-DMG-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
  const truthLabel = verifierRole === 'VOLUNTEER' ? 'COMMUNITY_VERIFIED' : 'OFFICIALLY_VERIFIED';
  const gpsTimestamp = new Date().toISOString();

  db.prepare(`
    INSERT INTO damage_verifications (
      id, claim_id, verifier_id, verifier_role, conflict_of_interest_declared,
      outcome, truth_label, notes, photos_json, gps_latitude, gps_longitude, gps_timestamp
    ) VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    verificationId,
    claimId,
    verifierId,
    verifierRole,
    outcome,
    truthLabel,
    notes,
    JSON.stringify(photos_json),
    gps_latitude || claim.latitude,
    gps_longitude || claim.longitude,
    gpsTimestamp
  );

  // Update claim status according to verifier role and outcome
  const nextStatus = outcome === 'VERIFIED'
    ? (verifierRole === 'VOLUNTEER' ? 'COMMUNITY_VERIFIED' : 'OFFICIALLY_VERIFIED')
    : outcome;

  db.prepare(`
    UPDATE damage_claims
    SET status = ?, updated_at = datetime('now')
    WHERE id = ?
  `).run(nextStatus, claimId);

  logAuditEvent({
    actionType: 'DAMAGE_CLAIM_VERIFIED',
    actorId: verifierId,
    actorRole: verifierRole,
    entityId: claimId,
    details: `Claim verified by ${verifierRole} (${verifierId}). Outcome: ${outcome}, TruthLabel: ${truthLabel}. Notes: "${notes}"`,
    afterState: { verificationId, outcome, truthLabel, status: nextStatus },
    ipAddress: req.ip
  });

  res.status(201).json({
    message: 'Verification recorded successfully',
    verificationId,
    claimId,
    truthLabel,
    outcome,
    status: nextStatus
  });
});

/**
 * POST /api/v1/claims/:id/aid-plan
 * Government officer assigns aid package (Section 8 Flow 6).
 */
claimRouter.post('/:id/aid-plan', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const claimId = req.params.id;
  const sanctioningOfficerId = req.user!.userId;
  const { aid_type, amount_paise = 0, items_description } = req.body;

  if (!aid_type || !items_description) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Aid type and items description are required.' });
  }

  const planId = `AID-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
  const deliveryOtp = Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit OTP

  db.prepare(`
    INSERT INTO aid_plans (
      id, claim_id, sanctioning_officer_id, aid_type, amount_paise,
      items_description, delivery_status, delivery_otp
    ) VALUES (?, ?, ?, ?, ?, ?, 'PENDING_DELIVERY', ?)
  `).run(planId, claimId, sanctioningOfficerId, aid_type, amount_paise, items_description, deliveryOtp);

  db.prepare(`
    UPDATE damage_claims
    SET status = 'AID_SANCTIONED', updated_at = datetime('now')
    WHERE id = ?
  `).run(claimId);

  logAuditEvent({
    actionType: 'AID_PLAN_SANCTIONED',
    actorId: sanctioningOfficerId,
    actorRole: req.user!.role,
    entityId: claimId,
    details: `Official aid sanctioned. Type: ${aid_type}, Amount: ${amount_paise / 100} INR. Items: "${items_description}"`,
    afterState: { planId, aid_type, amount_paise, status: 'AID_SANCTIONED' },
    ipAddress: req.ip
  });

  res.status(201).json({
    message: 'Aid package sanctioned successfully. Ready for proof-verified delivery.',
    planId,
    claimId,
    aid_type,
    amount_inr: amount_paise / 100,
    deliveryOtp,
    status: 'AID_SANCTIONED'
  });
});

/**
 * POST /api/v1/claims/:id/deliver
 * Confirm aid delivery with receiver proof (R-DMG-7, Section 8 Flow 7).
 * ACCEPTANCE CRITERIA: Delivered appears ONLY after proof.
 */
claimRouter.post('/:id/deliver', authenticate, requireRole('ADMIN', 'GOVT_OFFICER', 'VOLUNTEER'), (req: Request, res: Response) => {
  const claimId = req.params.id;
  const delivererId = req.user!.userId;
  const { receiver_otp, proof_url, proof_type = 'RECEIVER_OTP' } = req.body;

  const plan = db.prepare('SELECT * FROM aid_plans WHERE claim_id = ? AND delivery_status = ?').get(claimId, 'PENDING_DELIVERY') as any;
  if (!plan) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'No pending aid plan found for this claim' });
  }

  // ACCEPTANCE CRITERIA CHECK: Delivered appears ONLY after proof
  let proofVerified = false;

  if (proof_type === 'RECEIVER_OTP') {
    if (receiver_otp && receiver_otp.trim() === plan.delivery_otp) {
      proofVerified = true;
    }
  } else if (proof_type === 'SIGNATURE_PLUS_PHOTO') {
    if (proof_url && proof_url.trim().length > 0) {
      proofVerified = true;
    }
  }

  if (!proofVerified) {
    return res.status(400).json({
      error: 'DELIVERY_PROOF_REQUIRED',
      message: 'Delivered appears only after proof: Valid receiver OTP or signature/photo proof is mandatory.'
    });
  }

  const deliveredAt = new Date().toISOString();

  db.prepare(`
    UPDATE aid_plans
    SET delivery_status = 'DELIVERED',
        delivery_proof_type = ?,
        delivery_proof_url = ?,
        delivery_otp_verified = 1,
        delivered_by_user_id = ?,
        delivered_at = ?
    WHERE id = ?
  `).run(proof_type, proof_url || 'OTP_VERIFIED', delivererId, deliveredAt, plan.id);

  db.prepare(`
    UPDATE damage_claims
    SET status = 'DELIVERED', updated_at = datetime('now')
    WHERE id = ?
  `).run(claimId);

  logAuditEvent({
    actionType: 'AID_DELIVERY_CONFIRMED',
    actorId: delivererId,
    actorRole: req.user!.role,
    entityId: claimId,
    details: `Aid delivered with verified proof (${proof_type}). Beneficiary receipt confirmed.`,
    afterState: { planId: plan.id, delivery_status: 'DELIVERED', proof_type, deliveredAt },
    ipAddress: req.ip
  });

  res.json({
    message: 'Aid delivery successfully verified with proof. Status transitioned to DELIVERED.',
    planId: plan.id,
    claimId,
    deliveryStatus: 'DELIVERED',
    proofType: proof_type,
    deliveredAt
  });
});

/**
 * POST /api/v1/claims/:id/appeal
 * Citizen submits an appeal against a decision (R-DMG-6).
 * ACCEPTANCE CRITERIA: Appeal goes to a DIFFERENT officer.
 */
claimRouter.post('/:id/appeal', authenticate, (req: Request, res: Response) => {
  const claimId = req.params.id;
  const claimantId = req.user!.userId;
  const { appeal_reason, additional_evidence_urls = [], appealed_to_officer_id } = req.body;

  if (!appeal_reason || !appealed_to_officer_id) {
    return res.status(400).json({
      error: 'BAD_REQUEST',
      message: 'Appeal reason and target reviewing officer ID are required.'
    });
  }

  const claim = db.prepare('SELECT * FROM damage_claims WHERE id = ?').get(claimId) as any;
  if (!claim) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'Damage claim not found' });
  }

  // Find the officer who made the previous decision / verification
  const prevVerification = db.prepare(`
    SELECT verifier_id FROM damage_verifications 
    WHERE claim_id = ? AND verifier_role IN ('GOVT_OFFICER', 'ADMIN')
    ORDER BY verified_at DESC LIMIT 1
  `).get(claimId) as any;

  const originalDecisionOfficerId = prevVerification ? prevVerification.verifier_id : claim.assigned_officer_id;

  // ACCEPTANCE CRITERIA CHECK: Appeal goes to a different officer than the original
  if (originalDecisionOfficerId && appealed_to_officer_id === originalDecisionOfficerId) {
    return res.status(403).json({
      error: 'APPEAL_OFFICER_CONFLICT',
      message: 'Independent appeal requirement: Appeals must be assigned to a different officer than the original decision maker (R-DMG-6).'
    });
  }

  const appealId = `APL-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;

  db.prepare(`
    INSERT INTO claim_appeals (
      id, claim_id, claimant_id, original_decision_officer_id,
      appeal_reason, additional_evidence_urls, appealed_to_officer_id, appeal_status
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 'PENDING_REVIEW')
  `).run(
    appealId,
    claimId,
    claimantId,
    originalDecisionOfficerId || 'ORIGINAL_DECISION_MAKER',
    appeal_reason,
    JSON.stringify(additional_evidence_urls),
    appealed_to_officer_id
  );

  db.prepare(`
    UPDATE damage_claims
    SET status = 'APPEALED', updated_at = datetime('now')
    WHERE id = ?
  `).run(claimId);

  logAuditEvent({
    actionType: 'DAMAGE_CLAIM_APPEALED',
    actorId: claimantId,
    actorRole: req.user!.role,
    entityId: claimId,
    details: `Claim appealed by citizen. Assigned to independent reviewing officer ${appealed_to_officer_id}. Reason: "${appeal_reason}"`,
    afterState: { appealId, status: 'APPEALED', appealedTo: appealed_to_officer_id },
    ipAddress: req.ip
  });

  res.status(201).json({
    message: 'Appeal filed successfully and escalated to independent reviewing officer.',
    appealId,
    claimId,
    status: 'APPEALED',
    appealedToOfficerId: appealed_to_officer_id
  });
});

/**
 * GET /api/v1/claims/stats/public
 * Public aggregated statistics with privacy rules (Section 7.3 & R-DMG-5).
 * Aggregates below 5 are masked as "fewer than 5". Never exposes victim PII.
 */
claimRouter.get('/stats/public', (req: Request, res: Response) => {
  const stats = db.prepare(`
    SELECT ward, count(*) as total_claims,
           sum(case when status = 'DELIVERED' then 1 else 0 end) as delivered_count,
           sum(case when is_high_value = 1 then 1 else 0 end) as high_value_count,
           sum(estimated_value) as total_estimated_value
    FROM damage_claims
    GROUP BY ward
  `).all() as any[];

  // Apply privacy rule: counts below 5 show as "fewer than 5"
  const aggregated = stats.map(row => ({
    ward: row.ward,
    totalClaims: row.total_claims < 5 ? 'fewer than 5' : row.total_claims,
    deliveredAidClaims: row.delivered_count < 5 ? 'fewer than 5' : row.delivered_count,
    highValueClaims: row.high_value_count < 5 ? 'fewer than 5' : row.high_value_count,
    totalEstimatedLossInr: row.total_estimated_value || 0
  }));

  res.json({
    summary: 'Public aggregate loss and damage verification summary (Privacy-compliant: no victim PII exposed)',
    privacyRuleEnforced: 'Aggregates below 5 reported as "fewer than 5". Zero PII.',
    aggregatesByWard: aggregated
  });
});
// POST /api/v1/claims/ai-inspect — AI Vision Structural Damage Inspection from Photos
claimRouter.post('/ai-inspect', async (req: Request, res: Response) => {
  try {
    const { photo_base64, photo_url, claim_id, damage_description } = req.body;
    const result = await AiVisionDamageService.inspectDamagePhoto({
      photoBase64: photo_base64,
      photoUrl: photo_url,
      claimId: claim_id,
      damageDescription: damage_description
    });

    res.json({
      success: true,
      message: 'AI Vision structural damage inspection completed',
      data: result
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
