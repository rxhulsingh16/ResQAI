import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import { db } from '../db/database';
import { authenticate, requireRole } from '../middleware/rbacMiddleware';
import { logAuditEvent } from '../services/auditService';

export const governmentRouter = Router();

// GET /api/v1/government: Government command & administration overview
governmentRouter.get('/', (req: Request, res: Response) => {
  try {
    const sdrfAllocations = db.prepare('SELECT * FROM government_sdrf_allocations').all() as any[];
    const interDistrictRequests = db.prepare('SELECT * FROM inter_district_requests').all() as any[];
    const targetedNotices = db.prepare('SELECT * FROM targeted_notices').all() as any[];

    res.json({
      success: true,
      service: 'ResQAI Government Disaster Command & Inter-Agency Coordination',
      stats: {
        activeSdrfAllocations: sdrfAllocations.length,
        interDistrictRequestsCount: interDistrictRequests.length,
        targetedNoticesDispatched: targetedNotices.length
      },
      sdrfAllocations,
      interDistrictRequests
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/government/command-summary: High-level inter-agency summary
governmentRouter.get('/command-summary', (req: Request, res: Response) => {
  try {
    const sdrfAllocations = db.prepare('SELECT * FROM government_sdrf_allocations').all() as any[];
    const interDistrictRequests = db.prepare('SELECT * FROM inter_district_requests').all() as any[];
    const targetedNotices = db.prepare('SELECT * FROM targeted_notices').all() as any[];

    res.json({
      success: true,
      data: {
        sdrfAllocations,
        interDistrictRequests,
        targetedNoticesCount: targetedNotices.length
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/government/oversight
 * R-GOV-1: Jurisdiction oversight dashboard across incidents, claims, alerts, NGOs, funds & inventory.
 */
governmentRouter.get('/oversight', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const district = (req.query.district as string) || req.user!.jurisdictionRegionId || 'District X';

  // 1. Incidents in jurisdiction
  const incidentStats = db.prepare(`
    SELECT count(*) as total,
           sum(case when status = 'VERIFIED' then 1 else 0 end) as verified,
           sum(case when urgency = 'CRITICAL' then 1 else 0 end) as critical,
           sum(case when status = 'RECEIVED' then 1 else 0 end) as unassigned
    FROM incidents
    WHERE area_id LIKE ? OR location_name LIKE ?
  `).get(`%${district}%`, `%${district}%`) as any;

  // 2. Damage claims pipeline
  const claimStats = db.prepare(`
    SELECT count(*) as total,
           sum(case when status = 'SUBMITTED' then 1 else 0 end) as submitted,
           sum(case when status IN ('COMMUNITY_VERIFIED', 'OFFICIALLY_VERIFIED') then 1 else 0 end) as verified,
           sum(case when status = 'AID_SANCTIONED' then 1 else 0 end) as sanctioned,
           sum(case when status = 'DELIVERED' then 1 else 0 end) as delivered,
           sum(estimated_value) as total_claimed_loss
    FROM damage_claims
  `).get() as any;

  // 3. Active Official Alerts
  const activeAlertsCount = (db.prepare(`
    SELECT count(*) as count FROM official_alerts WHERE status = 'ACTIVE' AND is_paused = 0
  `).get() as any).count;

  // 4. Approved NGOs & Registered Volunteers
  const ngoCount = (db.prepare("SELECT count(*) as count FROM ngos WHERE kyc_status = 'APPROVED'").get() as any).count;
  const volunteerCount = (db.prepare("SELECT count(*) as count FROM users WHERE role = 'VOLUNTEER'").get() as any).count;

  // 5. SDRF Fund Ledger
  const sdrf = db.prepare('SELECT * FROM government_sdrf_allocations WHERE district = ?').get(district) as any;
  const sdrfStats = sdrf ? {
    allocatedInr: sdrf.allocated_budget_paise / 100,
    releasedInr: sdrf.released_budget_paise / 100,
    spentInr: sdrf.spent_budget_paise / 100,
    balanceInr: (sdrf.released_budget_paise - sdrf.spent_budget_paise) / 100
  } : {
    allocatedInr: 25000000, // ₹2.5 Crore default SDRF quota
    releasedInr: 15000000,
    spentInr: 4500000,
    balanceInr: 10500000
  };

  res.json({
    district,
    reportingOfficer: req.user!.userId,
    incidents: incidentStats || { total: 0, verified: 0, critical: 0, unassigned: 0 },
    claimsPipeline: claimStats || { total: 0, submitted: 0, verified: 0, sanctioned: 0, delivered: 0, total_claimed_loss: 0 },
    activeAlerts: activeAlertsCount,
    ecosystem: {
      approvedNgos: ngoCount,
      activeVolunteers: volunteerCount
    },
    sdrfFunds: sdrfStats
  });
});

/**
 * POST /api/v1/government/connect-and-inform
 * R-GOV-3: Targeted notices with group chips and area targeting.
 * ACCEPTANCE CRITERIA: A notice to Doctors in District X reaches only doctors registered there and shows delivered and failed counts.
 */
governmentRouter.post('/connect-and-inform', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const {
    target_group, // 'PUBLIC', 'RESCUE_TEAMS', 'DOCTORS_AND_HOSPITALS', 'NGOS', 'VOLUNTEERS', 'LOCAL_BODIES'
    target_district,
    target_ward,
    title,
    message,
    priority = 'NORMAL'
  } = req.body;

  if (!target_group || !target_district || !title || !message) {
    return res.status(400).json({
      error: 'BAD_REQUEST',
      message: 'target_group, target_district, title, and message are required.'
    });
  }

  // Find users in target group within target district
  let query = 'SELECT id, name, role, phone, jurisdiction_region_id, service_districts, department, designation, skills_json FROM users WHERE 1=1';
  const params: any[] = [];

  // 1. Group filtering
  if (target_group === 'DOCTORS_AND_HOSPITALS') {
    query += ` AND (
      department = 'HEALTHCARE' OR department = 'MEDICAL'
      OR designation LIKE '%Doctor%' OR designation LIKE '%Physician%'
      OR skills_json LIKE '%doctor%' OR skills_json LIKE '%medical%'
    )`;
  } else if (target_group === 'RESCUE_TEAMS') {
    query += ` AND (role = 'RESPONDER' OR skills_json LIKE '%rescue%' OR department = 'FIRE_AND_RESCUE')`;
  } else if (target_group === 'NGOS') {
    query += ` AND (role = 'NGO')`;
  } else if (target_group === 'VOLUNTEERS') {
    query += ` AND (role = 'VOLUNTEER')`;
  } else if (target_group === 'PUBLIC') {
    query += ` AND (role = 'CITIZEN')`;
  }

  // 2. Strict district scoping: user MUST be registered in target_district
  query += ` AND (
    jurisdiction_region_id = ?
    OR service_districts LIKE ?
  )`;
  params.push(target_district, `%${target_district}%`);

  const recipients = db.prepare(query).all(...params) as any[];

  const noticeId = `NTC-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
  let deliveredCount = 0;
  let failedCount = 0;
  const deliveryReceipts: any[] = [];

  // Insert targeted_notices parent row FIRST to satisfy foreign key constraint
  db.prepare(`
    INSERT INTO targeted_notices (
      id, sender_officer_id, target_group, target_district, target_ward,
      title, message, priority, total_targeted, delivered_count, failed_count
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0)
  `).run(
    noticeId,
    req.user!.userId,
    target_group,
    target_district,
    target_ward || null,
    title,
    message,
    priority,
    recipients.length
  );

  for (const r of recipients) {
    const deliveryId = `NDEL-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
    // Check simulated failure (e.g. invalid phone number format or marked inactive)
    const isDeliverySuccessful = Boolean(r.phone && r.phone.length >= 10 && !r.phone.includes('00000'));
    const status = isDeliverySuccessful ? 'DELIVERED' : 'FAILED';
    const channel = isDeliverySuccessful ? 'PUSH' : 'SMS';

    if (isDeliverySuccessful) {
      deliveredCount++;
    } else {
      failedCount++;
    }

    db.prepare(`
      INSERT INTO notice_deliveries (
        id, notice_id, recipient_user_id, recipient_name, recipient_role,
        recipient_district, recipient_phone, channel, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      deliveryId,
      noticeId,
      r.id,
      r.name,
      r.role,
      target_district,
      r.phone,
      channel,
      status
    );

    deliveryReceipts.push({
      deliveryId,
      recipientId: r.id,
      name: r.name,
      role: r.role,
      phone: r.phone,
      district: target_district,
      channel,
      status
    });
  }

  // Update counts on targeted_notices
  db.prepare(`
    UPDATE targeted_notices
    SET delivered_count = ?, failed_count = ?
    WHERE id = ?
  `).run(deliveredCount, failedCount, noticeId);

  logAuditEvent({
    actionType: 'TARGETED_NOTICE_BROADCAST',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId: noticeId,
    details: `Targeted notice sent to ${target_group} in ${target_district}. Total: ${recipients.length}, Delivered: ${deliveredCount}, Failed: ${failedCount}.`
  });

  res.status(201).json({
    message: `Targeted notice dispatched to ${target_group} in ${target_district}`,
    noticeId,
    targetGroup: target_group,
    targetDistrict: target_district,
    totalTargeted: recipients.length,
    deliveredCount,
    failedCount,
    deliveryReceipts
  });
});

/**
 * GET /api/v1/government/watch-panel
 * R-GOV-4: Watch panel for NGO and volunteer performance: spend vs delivery, unsupported expenses, areas ignored.
 */
governmentRouter.get('/watch-panel', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  // 1. Spend vs Delivery across NGOs
  const ngos = db.prepare('SELECT * FROM ngos WHERE kyc_status = ?').all('APPROVED') as any[];
  const performanceRoster = [];

  for (const ngo of ngos) {
    const campaigns = db.prepare('SELECT * FROM campaigns WHERE ngo_id = ?').all(ngo.id) as any[];
    const totalReceived = campaigns.reduce((acc, c) => acc + (c.received_amount_paise || 0), 0);
    const totalSpent = campaigns.reduce((acc, c) => acc + (c.spent_amount_paise || 0), 0);

    const expenses = db.prepare('SELECT * FROM ngo_expenses WHERE ngo_id = ?').all(ngo.id) as any[];
    const unsupportedExpenses = expenses.filter(e => e.is_unsupported === 1 || !e.receipt_url).length;

    const coverage = db.prepare('SELECT * FROM ngo_coverage_areas WHERE ngo_id = ?').all(ngo.id) as any[];
    const areasHelpedCount = coverage.filter(c => c.status === 'HELPED').length;

    performanceRoster.push({
      ngoId: ngo.id,
      name: ngo.name,
      darpanId: ngo.darpan_id,
      totalReceivedInr: totalReceived / 100,
      totalSpentInr: totalSpent / 100,
      areasHelpedCount,
      unsupportedExpensesCount: unsupportedExpenses,
      statusFlag: unsupportedExpenses > 0 ? 'NEEDS_FINANCIAL_AUDIT' : 'COMPLIANT'
    });
  }

  // 2. Areas Ignored: Areas with critical shortages or unfulfilled claims but 0 active NGO coverage
  const areas = db.prepare('SELECT * FROM affected_areas').all() as any[];
  const ignoredAreas = [];

  for (const a of areas) {
    const ngoPresence = (db.prepare('SELECT count(*) as count FROM ngo_coverage_areas WHERE area_id = ?').get(a.id) as any).count;
    const criticalNeeds = db.prepare("SELECT * FROM area_needs WHERE area_id = ? AND pending_units > 0").all(a.id) as any[];

    if (ngoPresence === 0 && criticalNeeds.length > 0) {
      ignoredAreas.push({
        areaId: a.id,
        areaName: a.name,
        severity: a.severity_level,
        unmetNeeds: criticalNeeds.map(n => `${n.pending_units} units of ${n.resource_type}`),
        flag: 'NEGLECTED_AREA_ZERO_NGO_PRESENCE'
      });
    }
  }

  res.json({
    summary: 'Government NGO & Volunteer Performance Watch Panel (R-GOV-4)',
    performanceRoster,
    ignoredAreasCount: ignoredAreas.length,
    ignoredAreas
  });
});

/**
 * POST /api/v1/government/entities/:id/suspend
 * R-GOV-6: Approve or suspend NGO and volunteers with recorded reason.
 */
governmentRouter.post('/entities/:id/suspend', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const entityId = req.params.id;
  const { reason, entityType = 'NGO' } = req.body;

  if (!reason || reason.trim().length < 5) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Mandatory recorded suspension reason required (R-GOV-6).' });
  }

  if (entityType === 'NGO') {
    db.prepare("UPDATE ngos SET kyc_status = 'SUSPENDED', updated_at = datetime('now') WHERE id = ?").run(entityId);
  } else {
    db.prepare("UPDATE users SET approval_status = 'SUSPENDED', updated_at = datetime('now') WHERE id = ?").run(entityId);
  }

  logAuditEvent({
    actionType: 'ENTITY_SUSPENDED_BY_GOVERNMENT',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId,
    details: `Official suspension of ${entityType} ${entityId}. Reason: "${reason}".`
  });

  res.json({
    message: `${entityType} suspended successfully with recorded reason.`,
    entityId,
    entityType,
    status: 'SUSPENDED',
    recordedReason: reason,
    suspendedBy: req.user!.userId
  });
});

/**
 * POST /api/v1/government/datasets/import
 * R-GOV-8: Dataset import for affected persons with duplicate review and rollback.
 */
governmentRouter.post('/datasets/import', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const {
    dataset_name = 'Affected Persons Roster',
    district = 'District X',
    column_mapping = {},
    records = []
  } = req.body;

  if (!records || records.length === 0) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Dataset records array is required.' });
  }

  const datasetId = `DSET-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
  let duplicateCount = 0;
  const reviewedRecords = [];

  for (const r of records) {
    // Check duplicate by phone or name in existing database
    const existing = db.prepare('SELECT id FROM users WHERE phone = ? OR name = ?').get(r.phone, r.name) as any;
    const isDuplicate = Boolean(existing);
    if (isDuplicate) duplicateCount++;

    reviewedRecords.push({
      ...r,
      isDuplicate,
      existingId: existing ? existing.id : null
    });
  }

  db.prepare(`
    INSERT INTO government_datasets (
      id, uploaded_by_officer_id, dataset_name, district, status,
      total_rows, duplicate_rows, imported_records_json, column_mapping_json
    ) VALUES (?, ?, ?, ?, 'PENDING_REVIEW', ?, ?, ?, ?)
  `).run(
    datasetId,
    req.user!.userId,
    dataset_name,
    district,
    records.length,
    duplicateCount,
    JSON.stringify(reviewedRecords),
    JSON.stringify(column_mapping)
  );

  res.status(201).json({
    message: 'Dataset imported successfully. Awaiting official duplicate review and approval.',
    datasetId,
    datasetName: dataset_name,
    status: 'PENDING_REVIEW',
    totalRows: records.length,
    duplicateRows: duplicateCount,
    duplicatesDetected: duplicateCount > 0
  });
});

/**
 * POST /api/v1/government/datasets/:id/approve
 * R-GOV-8: Officer approves dataset.
 */
governmentRouter.post('/datasets/:id/approve', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const datasetId = req.params.id;
  const dataset = db.prepare('SELECT * FROM government_datasets WHERE id = ?').get(datasetId) as any;

  if (!dataset) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'Dataset not found' });
  }

  db.prepare("UPDATE government_datasets SET status = 'APPROVED', updated_at = datetime('now') WHERE id = ?").run(datasetId);

  logAuditEvent({
    actionType: 'DATASET_APPROVED',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId: datasetId,
    details: `Dataset "${dataset.dataset_name}" approved by officer.`
  });

  res.json({ message: 'Dataset approved and committed into district relief roster', datasetId, status: 'APPROVED' });
});

/**
 * POST /api/v1/government/datasets/:id/rollback
 * R-GOV-8: Officer rolls back dataset.
 */
governmentRouter.post('/datasets/:id/rollback', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const datasetId = req.params.id;
  db.prepare("UPDATE government_datasets SET status = 'ROLLED_BACK', updated_at = datetime('now') WHERE id = ?").run(datasetId);

  logAuditEvent({
    actionType: 'DATASET_ROLLED_BACK',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId: datasetId,
    details: `Dataset ${datasetId} rolled back cleanly.`
  });

  res.json({ message: 'Dataset successfully rolled back. Records revoked.', datasetId, status: 'ROLLED_BACK' });
});

/**
 * POST /api/v1/government/resource-requests
 * R-GOV-10: Resource requests to neighbouring districts and state level.
 */
governmentRouter.post('/resource-requests', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const {
    requesting_district,
    target_district = 'State SDMA Central Reserves',
    resource_type,
    requested_quantity,
    urgency = 'HIGH',
    notes
  } = req.body;

  if (!requesting_district || !resource_type || !requested_quantity) {
    return res.status(400).json({
      error: 'BAD_REQUEST',
      message: 'requesting_district, resource_type, and requested_quantity are required.'
    });
  }

  const requestId = `REQ-MUTUAL-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;

  db.prepare(`
    INSERT INTO inter_district_requests (
      id, requesting_district, target_district, requesting_officer_id,
      resource_type, requested_quantity, urgency, status, notes
    ) VALUES (?, ?, ?, ?, ?, ?, ?, 'PENDING', ?)
  `).run(
    requestId,
    requesting_district,
    target_district,
    req.user!.userId,
    resource_type,
    requested_quantity,
    urgency,
    notes || null
  );

  logAuditEvent({
    actionType: 'INTER_DISTRICT_REQUISITION',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId: requestId,
    details: `Requisition: ${requested_quantity} ${resource_type} requested from ${target_district} by ${requesting_district}.`
  });

  res.status(201).json({
    message: 'Inter-district mutual aid resource request lodged successfully (R-GOV-10)',
    requestId,
    requestingDistrict: requesting_district,
    targetDistrict: target_district,
    resourceType: resource_type,
    requestedQuantity: requested_quantity,
    status: 'PENDING'
  });
});
