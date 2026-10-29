import { db } from '../db/database';
import crypto from 'crypto';

export interface NGORegistrationInput {
  name: string;
  darpan_id: string;
  fcra_number?: string;
  fcra_valid_until?: string;
  tax_80g_number?: string;
  tax_80g_valid_until?: string;
  authorized_rep_name: string;
  authorized_rep_email: string;
  authorized_rep_phone: string;
  documents?: { type: string; url: string; status?: string }[];
}

export interface CampaignInput {
  ngo_id: string;
  title: string;
  description: string;
  category: 'FLOOD' | 'MEDICAL' | 'SHELTER' | 'FOOD' | 'RECOVERY' | 'GENERAL';
  area_id: string;
  target_amount_paise: number;
  beneficiary_count?: number;
}

export interface DisbursementInput {
  campaign_id: string;
  purpose: string;
  amount_paise: number;
  vendor_or_beneficiary: string;
  proof_receipt_url?: string;
}

export class NGOService {
  // --- NGO KYC Management (FR-42, FR-46) ---

  public static getAllNGOs(filter?: { kyc_status?: string }) {
    if (filter?.kyc_status) {
      const stmt = db.prepare('SELECT * FROM ngos WHERE kyc_status = ? ORDER BY created_at DESC');
      return stmt.all(filter.kyc_status);
    }
    const stmt = db.prepare('SELECT * FROM ngos ORDER BY created_at DESC');
    return stmt.all();
  }

  public static getNGOById(id: string) {
    const stmt = db.prepare('SELECT * FROM ngos WHERE id = ?');
    return stmt.get(id);
  }

  public static getNGOCampaigns(ngoId: string) {
    const stmt = db.prepare('SELECT * FROM campaigns WHERE ngo_id = ? ORDER BY created_at DESC');
    return stmt.all(ngoId) as any[];
  }

  public static getNGOBalance(ngoId: string) {
    const stmt = db.prepare(`
      SELECT 
        COALESCE(SUM(c.received_amount_paise), 0) as totalReceivedPaise,
        COALESCE(SUM(c.spent_amount_paise), 0) as totalDisbursedPaise
      FROM campaigns c
      WHERE c.ngo_id = ?
    `);
    const row = stmt.get(ngoId) as any;
    const totalReceivedPaise = Number(row?.totalReceivedPaise || 0);
    const totalDisbursedPaise = Number(row?.totalDisbursedPaise || 0);
    return {
      totalReceivedPaise,
      totalDisbursedPaise,
      netBalancePaise: totalReceivedPaise - totalDisbursedPaise
    };
  }

  public static registerNGO(input: NGORegistrationInput) {
    const id = `NGO-${crypto.randomUUID().substring(0, 8).toUpperCase()}`;
    const fcraVerified = input.fcra_number && input.fcra_valid_until ? 1 : 0;
    const tax80gVerified = input.tax_80g_number && input.tax_80g_valid_until ? 1 : 0;

    const stmt = db.prepare(`
      INSERT INTO ngos (
        id, name, darpan_id, fcra_number, fcra_valid_until, fcra_verified,
        tax_80g_number, tax_80g_valid_until, tax_80g_verified,
        authorized_rep_name, authorized_rep_email, authorized_rep_phone,
        kyc_status, kyc_notes, documents_json
      ) VALUES (
        @id, @name, @darpan_id, @fcra_number, @fcra_valid_until, @fcra_verified,
        @tax_80g_number, @tax_80g_valid_until, @tax_80g_verified,
        @authorized_rep_name, @authorized_rep_email, @authorized_rep_phone,
        'PENDING_VERIFICATION', 'Awaiting administrative verification of Darpan ID and Registration documents.', @documents_json
      )
    `);

    stmt.run({
      id,
      name: input.name,
      darpan_id: input.darpan_id,
      fcra_number: input.fcra_number || null,
      fcra_valid_until: input.fcra_valid_until || null,
      fcra_verified: fcraVerified,
      tax_80g_number: input.tax_80g_number || null,
      tax_80g_valid_until: input.tax_80g_valid_until || null,
      tax_80g_verified: tax80gVerified,
      authorized_rep_name: input.authorized_rep_name,
      authorized_rep_email: input.authorized_rep_email,
      authorized_rep_phone: input.authorized_rep_phone,
      documents_json: JSON.stringify(input.documents || [])
    });

    // Audit log (FR-53)
    db.prepare(`
      INSERT INTO audit_logs (id, action_type, actor_id, actor_role, entity_id, details)
      VALUES (?, 'NGO_REGISTERED', ?, 'NGO', ?, ?)
    `).run(
      `AUD-${crypto.randomUUID().substring(0, 8)}`,
      input.authorized_rep_email,
      id,
      `NGO registered: ${input.name} (Darpan ID: ${input.darpan_id})`
    );

    return this.getNGOById(id);
  }

  public static updateNGOStatus(
    ngoId: string,
    status: 'APPROVED' | 'REJECTED' | 'SUSPENDED',
    actorId: string,
    notes?: string
  ) {
    const ngo = this.getNGOById(ngoId) as any;
    if (!ngo) {
      throw new Error(`NGO with ID ${ngoId} not found`);
    }

    const stmt = db.prepare(`
      UPDATE ngos
      SET kyc_status = ?, kyc_notes = COALESCE(?, kyc_notes), updated_at = datetime('now')
      WHERE id = ?
    `);
    stmt.run(status, notes || null, ngoId);

    // Audit log
    db.prepare(`
      INSERT INTO audit_logs (id, action_type, actor_id, actor_role, entity_id, details, before_state_json, after_state_json)
      VALUES (?, 'NGO_KYC_UPDATED', ?, 'ADMIN', ?, ?, ?, ?)
    `).run(
      `AUD-${crypto.randomUUID().substring(0, 8)}`,
      actorId,
      ngoId,
      `NGO ${ngo.name} KYC status transitioned to ${status}. Notes: ${notes || 'None'}`,
      JSON.stringify({ status: ngo.kyc_status }),
      JSON.stringify({ status, notes })
    );

    return this.getNGOById(ngoId);
  }

  // --- Campaign Management & Approval Gate (FR-43, FR-44) ---

  public static getAllCampaigns(filter?: {
    status?: string;
    category?: string;
    area_id?: string;
    publicOnly?: boolean;
  }) {
    let query = `
      SELECT c.*, n.name as ngo_name, n.darpan_id, n.tax_80g_verified, n.fcra_verified, a.name as area_name
      FROM campaigns c
      JOIN ngos n ON c.ngo_id = n.id
      JOIN affected_areas a ON c.area_id = a.id
      WHERE 1=1
    `;
    const params: any[] = [];

    // FR-43: Campaign cannot be public until Admin approval
    if (filter?.publicOnly) {
      query += ` AND c.status = 'ACTIVE'`;
    } else if (filter?.status) {
      query += ` AND c.status = ?`;
      params.push(filter.status);
    }

    if (filter?.category) {
      query += ` AND c.category = ?`;
      params.push(filter.category);
    }

    if (filter?.area_id) {
      query += ` AND c.area_id = ?`;
      params.push(filter.area_id);
    }

    query += ` ORDER BY c.created_at DESC`;

    const stmt = db.prepare(query);
    return stmt.all(...params);
  }

  public static getCampaignById(id: string) {
    const stmt = db.prepare(`
      SELECT c.*, n.name as ngo_name, n.darpan_id, n.tax_80g_number, n.tax_80g_verified, n.fcra_number, n.fcra_verified, n.authorized_rep_name, a.name as area_name
      FROM campaigns c
      JOIN ngos n ON c.ngo_id = n.id
      JOIN affected_areas a ON c.area_id = a.id
      WHERE c.id = ?
    `);
    return stmt.get(id);
  }

  public static createCampaign(input: CampaignInput) {
    const ngo = this.getNGOById(input.ngo_id) as any;
    if (!ngo) {
      throw new Error(`NGO ${input.ngo_id} not found`);
    }

    // FR-42 & FR-43: Only verified or approved NGOs can create campaigns
    if (ngo.kyc_status === 'SUSPENDED' || ngo.kyc_status === 'REJECTED') {
      throw new Error(`Cannot create campaign: NGO status is ${ngo.kyc_status}`);
    }

    const id = `CMP-${crypto.randomUUID().substring(0, 8).toUpperCase()}`;

    // FR-43: Campaign cannot be public until Admin approval -> initial status is PENDING_APPROVAL
    const stmt = db.prepare(`
      INSERT INTO campaigns (
        id, ngo_id, title, description, category, area_id,
        target_amount_paise, received_amount_paise, committed_amount_paise, spent_amount_paise,
        status, beneficiary_count
      ) VALUES (
        @id, @ngo_id, @title, @description, @category, @area_id,
        @target_amount_paise, 0, 0, 0,
        'PENDING_APPROVAL', @beneficiary_count
      )
    `);

    stmt.run({
      id,
      ngo_id: input.ngo_id,
      title: input.title,
      description: input.description,
      category: input.category,
      area_id: input.area_id,
      target_amount_paise: input.target_amount_paise,
      beneficiary_count: input.beneficiary_count || 0
    });

    // Audit log
    db.prepare(`
      INSERT INTO audit_logs (id, action_type, actor_id, actor_role, entity_id, details)
      VALUES (?, 'CAMPAIGN_SUBMITTED', ?, 'NGO', ?, ?)
    `).run(
      `AUD-${crypto.randomUUID().substring(0, 8)}`,
      ngo.authorized_rep_email,
      id,
      `Campaign submitted for approval: "${input.title}" by ${ngo.name}. Target: ₹${input.target_amount_paise / 100}`
    );

    return this.getCampaignById(id);
  }

  public static updateCampaignStatus(
    campaignId: string,
    status: 'ACTIVE' | 'REJECTED' | 'PAUSED' | 'COMPLETED',
    actorId: string
  ) {
    const campaign = this.getCampaignById(campaignId) as any;
    if (!campaign) {
      throw new Error(`Campaign with ID ${campaignId} not found`);
    }

    const stmt = db.prepare(`
      UPDATE campaigns
      SET status = ?, approved_by = ?, approved_at = CASE WHEN ? = 'ACTIVE' THEN datetime('now') ELSE approved_at END, updated_at = datetime('now')
      WHERE id = ?
    `);
    stmt.run(status, actorId, status, campaignId);

    // Audit log (FR-53)
    db.prepare(`
      INSERT INTO audit_logs (id, action_type, actor_id, actor_role, entity_id, details, before_state_json, after_state_json)
      VALUES (?, 'CAMPAIGN_STATUS_UPDATED', ?, 'ADMIN', ?, ?, ?, ?)
    `).run(
      `AUD-${crypto.randomUUID().substring(0, 8)}`,
      actorId,
      campaignId,
      `Campaign "${campaign.title}" status changed to ${status} by admin ${actorId}`,
      JSON.stringify({ status: campaign.status }),
      JSON.stringify({ status })
    );

    return this.getCampaignById(campaignId);
  }

  // --- Transparent Financial Ledger (FR-44) ---

  public static getCampaignLedger(campaignId: string) {
    const campaign = this.getCampaignById(campaignId) as any;
    if (!campaign) {
      throw new Error(`Campaign ${campaignId} not found`);
    }

    const disbursementsStmt = db.prepare(`
      SELECT * FROM campaign_disbursements
      WHERE campaign_id = ?
      ORDER BY disbursed_at DESC
    `);
    const disbursements = disbursementsStmt.all(campaignId);

    const donationsStmt = db.prepare(`
      SELECT id, donor_name, is_indian_citizen, is_fcra_contribution, amount_paise, currency, status, tax_80g_issued, tax_80g_receipt_no, created_at
      FROM donations
      WHERE campaign_id = ? AND status = 'PAID'
      ORDER BY created_at DESC
    `);
    const donations = donationsStmt.all(campaignId);

    const targetPaise = campaign.target_amount_paise;
    const receivedPaise = campaign.received_amount_paise;
    const committedPaise = campaign.committed_amount_paise;
    const spentPaise = campaign.spent_amount_paise;
    const unspentBalancePaise = receivedPaise - spentPaise;
    const uncommittedBalancePaise = receivedPaise - committedPaise - spentPaise;

    return {
      campaignId: campaign.id,
      title: campaign.title,
      ngoName: campaign.ngo_name,
      darpanId: campaign.darpan_id,
      tax80gVerified: Boolean(campaign.tax_80g_verified),
      fcraVerified: Boolean(campaign.fcra_verified),
      status: campaign.status,
      ledger: {
        targetPaise,
        receivedPaise,
        committedPaise,
        spentPaise,
        unspentBalancePaise,
        uncommittedBalancePaise,
        targetRupees: targetPaise / 100,
        receivedRupees: receivedPaise / 100,
        committedRupees: committedPaise / 100,
        spentRupees: spentPaise / 100,
        unspentBalanceRupees: unspentBalancePaise / 100,
        percentFunded: targetPaise > 0 ? Math.min(100, Math.round((receivedPaise / targetPaise) * 1000) / 10) : 0,
        percentSpent: receivedPaise > 0 ? Math.min(100, Math.round((spentPaise / receivedPaise) * 1000) / 10) : 0
      },
      disbursements,
      donations
    };
  }

  public static recordDisbursement(input: DisbursementInput, actorId: string) {
    const campaign = this.getCampaignById(input.campaign_id) as any;
    if (!campaign) {
      throw new Error(`Campaign ${input.campaign_id} not found`);
    }

    const availablePaise = campaign.received_amount_paise - campaign.spent_amount_paise;
    if (input.amount_paise > availablePaise) {
      throw new Error(
        `Insufficient unspent campaign balance. Available: ₹${availablePaise / 100}, Requested: ₹${input.amount_paise / 100}`
      );
    }

    const disbursementId = `DSB-${crypto.randomUUID().substring(0, 8).toUpperCase()}`;

    const insertStmt = db.prepare(`
      INSERT INTO campaign_disbursements (
        id, campaign_id, purpose, amount_paise, vendor_or_beneficiary, proof_receipt_url, audited_by
      ) VALUES (
        @id, @campaign_id, @purpose, @amount_paise, @vendor_or_beneficiary, @proof_receipt_url, @audited_by
      )
    `);

    insertStmt.run({
      id: disbursementId,
      campaign_id: input.campaign_id,
      purpose: input.purpose,
      amount_paise: input.amount_paise,
      vendor_or_beneficiary: input.vendor_or_beneficiary,
      proof_receipt_url: input.proof_receipt_url || null,
      audited_by: actorId
    });

    // Update campaign spent balance
    db.prepare(`
      UPDATE campaigns
      SET spent_amount_paise = spent_amount_paise + ?, updated_at = datetime('now')
      WHERE id = ?
    `).run(input.amount_paise, input.campaign_id);

    // Audit log (FR-53)
    db.prepare(`
      INSERT INTO audit_logs (id, action_type, actor_id, actor_role, entity_id, details)
      VALUES (?, 'DISBURSEMENT_RECORDED', ?, 'ADMIN', ?, ?)
    `).run(
      `AUD-${crypto.randomUUID().substring(0, 8)}`,
      actorId,
      disbursementId,
      `Disbursed ₹${input.amount_paise / 100} for "${input.purpose}" to ${input.vendor_or_beneficiary} from campaign "${campaign.title}"`
    );

    return this.getCampaignLedger(input.campaign_id);
  }
}
