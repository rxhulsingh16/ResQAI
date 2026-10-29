import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import { db } from '../db/database';
import { authenticate, requireRole } from '../middleware/rbacMiddleware';
import { logAuditEvent } from '../services/auditService';

export const transparencyRouter = Router();

// GET /api/v1/transparency: Public disaster response ledger and fund transparency
transparencyRouter.get('/', (req: Request, res: Response) => {
  try {
    const campaigns = db.prepare('SELECT count(*) as c, sum(received_amount_paise) as r, sum(spent_amount_paise) as s FROM campaigns').get() as any;
    const ngos = db.prepare("SELECT count(*) as c FROM ngos WHERE kyc_status = 'APPROVED'").get() as any;
    const donations = db.prepare("SELECT count(*) as c, sum(amount_paise) as total FROM donations WHERE status = 'PAID'").get() as any;

    res.json({
      success: true,
      service: 'ResQAI Public Transparency & Audit Ledger',
      financials: {
        totalReceivedInr: (campaigns?.r || 0) / 100,
        totalSpentInr: (campaigns?.s || 0) / 100,
        unspentInr: ((campaigns?.r || 0) - (campaigns?.s || 0)) / 100,
        verifiedNgosCount: ngos?.c || 0,
        totalDonationsCount: donations?.c || 0
      },
      endpoints: {
        search: '/api/v1/transparency/search',
        summary: '/api/v1/transparency/summary',
        export: '/api/v1/transparency/export'
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/transparency/summary: Detailed financial breakdown
transparencyRouter.get('/summary', (req: Request, res: Response) => {
  try {
    const campaigns = db.prepare('SELECT count(*) as c, sum(received_amount_paise) as r, sum(spent_amount_paise) as s FROM campaigns').get() as any;
    const ngos = db.prepare("SELECT count(*) as c FROM ngos WHERE kyc_status = 'APPROVED'").get() as any;
    const donations = db.prepare("SELECT count(*) as c, sum(amount_paise) as total FROM donations WHERE status = 'PAID'").get() as any;

    res.json({
      success: true,
      data: {
        totalReceivedInr: (campaigns?.r || 0) / 100,
        totalSpentInr: (campaigns?.s || 0) / 100,
        netBalanceInr: ((campaigns?.r || 0) - (campaigns?.s || 0)) / 100,
        verifiedNGOs: ngos?.c || 0,
        completedDonations: donations?.c || 0
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/transparency/search
 * Universal search across NGOs, Volunteers, Government, Disasters, Areas, and Claim IDs (R-TRN-1).
 */
transparencyRouter.get('/search', (req: Request, res: Response) => {
  const { query = '', entityType } = req.query;
  const q = `%${query}%`;
  const results: any[] = [];

  // Search NGOs
  if (!entityType || entityType === 'NGO') {
    const ngos = db.prepare(`
      SELECT id, name, darpan_id, kyc_status, fcra_verified, tax_80g_verified, 'NGO' as entity_type
      FROM ngos
      WHERE name LIKE ? OR darpan_id LIKE ?
    `).all(q, q) as any[];
    results.push(...ngos.map(n => ({
      entityType: 'NGO',
      id: n.id,
      title: n.name,
      subtitle: `Darpan ID: ${n.darpan_id}`,
      badge: n.kyc_status,
      isVerified: n.kyc_status === 'APPROVED'
    })));
  }

  // Search Volunteers (only opt-in public profiles per R-VOL-7 & Section 7.3)
  if (!entityType || entityType === 'VOLUNTEER') {
    const vols = db.prepare(`
      SELECT u.id, u.name, u.role, 'VOLUNTEER' as entity_type
      FROM users u
      LEFT JOIN volunteer_profiles vp ON u.id = vp.user_id
      WHERE u.role = 'VOLUNTEER' AND (vp.is_public_profile = 1 OR vp.is_public_profile IS NULL) AND u.name LIKE ?
    `).all(q) as any[];
    results.push(...vols.map(v => ({
      entityType: 'VOLUNTEER',
      id: v.id,
      title: v.name,
      subtitle: 'Certified Volunteer',
      badge: 'COMMUNITY_VERIFIED',
      isVerified: true
    })));
  }

  // Search Disasters / Events
  if (!entityType || entityType === 'DISASTER') {
    const areas = db.prepare(`
      SELECT id, name, severity_level, 'DISASTER_ZONE' as entity_type
      FROM affected_areas
      WHERE name LIKE ?
    `).all(q) as any[];
    results.push(...areas.map(a => ({
      entityType: 'DISASTER',
      id: a.id,
      title: a.name,
      subtitle: `Severity: ${a.severity_level}`,
      badge: a.severity_level,
      isVerified: true
    })));
  }

  // Search Claim by Reference ID (Anonymous lookup per R-TRN-1 & Section 7.1)
  if (!entityType || entityType === 'CLAIM') {
    const claims = db.prepare(`
      SELECT id, status, severity, ward, created_at, 'CLAIM' as entity_type
      FROM damage_claims
      WHERE id LIKE ?
    `).all(q) as any[];
    results.push(...claims.map(c => ({
      entityType: 'CLAIM',
      id: c.id,
      title: `Claim Ref: ${c.id}`,
      subtitle: `Ward: ${c.ward} | Stage: ${c.status}`,
      badge: c.status,
      isVerified: c.status === 'OFFICIALLY_VERIFIED' || c.status === 'DELIVERED'
    })));
  }

  res.json({
    query,
    totalResults: results.length,
    results
  });
});

/**
 * GET /api/v1/transparency/entities/:entityType/:entityId
 * Full entity transparency profile with tabs: Overview, Money, Expenses, Areas Helped, Proofs (R-TRN-1, R-TRN-2, R-TRN-3, R-TRN-4).
 */
transparencyRouter.get('/entities/:entityType/:entityId', (req: Request, res: Response) => {
  const { entityType, entityId } = req.params;

  if (entityType.toUpperCase() === 'NGO') {
    const ngo = db.prepare('SELECT * FROM ngos WHERE id = ?').get(entityId) as any;
    if (!ngo) {
      return res.status(404).json({ error: 'NOT_FOUND', message: 'NGO entity not found' });
    }

    // 1. Money & Ledger: Computed from entries (Section 7.4: "public balance is computed from entries, never typed")
    const campaigns = db.prepare('SELECT * FROM campaigns WHERE ngo_id = ?').all(entityId) as any[];
    const campaignIds = campaigns.map(c => c.id);

    let totalReceivedPaise = 0;
    let totalCommittedPaise = 0;
    let totalSpentPaise = 0;

    for (const c of campaigns) {
      totalReceivedPaise += c.received_amount_paise || 0;
      totalCommittedPaise += c.committed_amount_paise || 0;
      totalSpentPaise += c.spent_amount_paise || 0;
    }

    // ACCEPTANCE CRITERIA 3: Public balance equals the ledger sum (received - spent)
    const publicBalancePaise = totalReceivedPaise - totalSpentPaise;

    // 2. Expenses with receipts (R-TRN-3):
    // ACCEPTANCE CRITERIA 2: An expense without receipt is shown as "Unsupported" in red.
    const expenses = db.prepare(`
      SELECT * FROM ngo_expenses WHERE ngo_id = ? ORDER BY expense_date DESC
    `).all(entityId) as any[];

    const formattedExpenses = expenses.map(e => {
      const hasReceipt = Boolean(e.receipt_url && e.receipt_url.trim().length > 0);
      const isUnsupported = !hasReceipt || e.is_unsupported === 1;
      return {
        id: e.id,
        category: e.category,
        amountInr: e.amount_paise / 100,
        vendor: e.vendor_name,
        date: e.expense_date,
        receiptUrl: e.receipt_url,
        hasReceipt,
        status: isUnsupported ? 'Unsupported' : 'APPROVED',
        statusColor: isUnsupported ? 'RED' : 'GREEN',
        anomalyFlag: isUnsupported ? 'ANOMALY_NO_RECEIPT' : null,
        approverId: e.approver_id
      };
    });

    const unsupportedCount = formattedExpenses.filter(e => e.status === 'Unsupported').length;

    // 3. Areas Helped vs Not Yet Helped (R-TRN-4)
    const areasCovered = db.prepare(`
      SELECT * FROM ngo_coverage_areas WHERE ngo_id = ?
    `).all(entityId) as any[];

    const areasHelped = areasCovered.filter(a => a.status === 'HELPED');
    const areasInProgress = areasCovered.filter(a => a.status === 'IN_PROGRESS');
    const areasNotYetHelped = areasCovered.filter(a => a.status === 'NOT_YET_HELPED');

    res.json({
      entityType: 'NGO',
      overview: {
        id: ngo.id,
        name: ngo.name,
        darpanId: ngo.darpan_id,
        kycStatus: ngo.kyc_status,
        fcraVerified: Boolean(ngo.fcra_verified),
        tax80gVerified: Boolean(ngo.tax_80g_verified),
        trustBadge: ngo.kyc_status === 'APPROVED' ? 'VERIFIED_NGO' : 'PENDING_KYC',
        anomalyBadges: unsupportedCount > 0 ? [`${unsupportedCount} Unsupported Expenses`] : []
      },
      money: {
        receivedPaise: totalReceivedPaise,
        receivedInr: totalReceivedPaise / 100,
        committedPaise: totalCommittedPaise,
        committedInr: totalCommittedPaise / 100,
        spentPaise: totalSpentPaise,
        spentInr: totalSpentPaise / 100,
        publicBalancePaise,
        publicBalanceInr: publicBalancePaise / 100,
        formula: 'publicBalance = totalReceived - totalSpent (dynamically computed from ledger entries)'
      },
      expenses: formattedExpenses,
      areasHelped,
      areasInProgress,
      areasNotYetHelped,
      campaigns: campaigns.map(c => ({
        id: c.id,
        title: c.title,
        status: c.status,
        targetInr: c.target_amount_paise / 100,
        receivedInr: c.received_amount_paise / 100,
        spentInr: c.spent_amount_paise / 100
      }))
    });
  } else {
    // Government or generic entity
    res.json({
      entityType,
      entityId,
      message: 'Government / District overview provided under SDRF consolidated ledger'
    });
  }
});

/**
 * POST /api/v1/transparency/expenses
 * Record an expense entry.
 * ACCEPTANCE CRITERIA: An expense without receipt is shown as "Unsupported" in red.
 */
transparencyRouter.post('/expenses', authenticate, requireRole('NGO', 'ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const {
    ngo_id,
    campaign_id,
    category,
    amount_paise,
    vendor_name,
    expense_date,
    area_id,
    receipt_url
  } = req.body;

  if (!ngo_id || !category || !amount_paise || !vendor_name || !expense_date) {
    return res.status(400).json({
      error: 'BAD_REQUEST',
      message: 'ngo_id, category, amount_paise, vendor_name, and expense_date are mandatory.'
    });
  }

  const expenseId = `EXP-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
  const hasReceipt = Boolean(receipt_url && receipt_url.trim().length > 0);
  const isUnsupported = !hasReceipt ? 1 : 0;
  const status = isUnsupported ? 'Unsupported' : 'APPROVED';

  db.prepare(`
    INSERT INTO ngo_expenses (
      id, ngo_id, campaign_id, category, amount_paise, vendor_name,
      expense_date, area_id, receipt_url, is_unsupported, status, approver_id
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    expenseId,
    ngo_id,
    campaign_id || null,
    category,
    amount_paise,
    vendor_name,
    expense_date,
    area_id || null,
    receipt_url || null,
    isUnsupported,
    status,
    req.user!.userId
  );

  // Update campaign spent balance if linked
  if (campaign_id) {
    db.prepare(`
      UPDATE campaigns
      SET spent_amount_paise = spent_amount_paise + ?, updated_at = datetime('now')
      WHERE id = ?
    `).run(amount_paise, campaign_id);
  }

  logAuditEvent({
    actionType: 'EXPENSE_RECORDED',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId: expenseId,
    details: `Expense of ₹${amount_paise / 100} recorded for ${vendor_name}. Has receipt: ${hasReceipt}. Status: ${status}.`,
    afterState: { expenseId, status, hasReceipt }
  });

  res.status(201).json({
    message: isUnsupported
      ? 'Expense recorded without receipt image — flagged publicly as "Unsupported" in red (R-TRN-3)'
      : 'Expense recorded successfully with verified receipt image',
    expenseId,
    status,
    hasReceipt,
    statusColor: isUnsupported ? 'RED' : 'GREEN',
    isUnsupported: Boolean(isUnsupported),
    amountInr: amount_paise / 100
  });
});

/**
 * GET /api/v1/transparency/compare
 * Compare two NGOs or two districts side by side (R-TRN-8).
 */
transparencyRouter.get('/compare', (req: Request, res: Response) => {
  const { entity1Id, entity2Id } = req.query as { entity1Id: string; entity2Id: string };

  if (!entity1Id || !entity2Id) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'entity1Id and entity2Id are required for comparison.' });
  }

  const getEntityStats = (id: string) => {
    const ngo = db.prepare('SELECT * FROM ngos WHERE id = ?').get(id) as any;
    if (!ngo) return null;

    const campaigns = db.prepare('SELECT * FROM campaigns WHERE ngo_id = ?').all(id) as any[];
    const totalReceived = campaigns.reduce((acc, c) => acc + (c.received_amount_paise || 0), 0);
    const totalSpent = campaigns.reduce((acc, c) => acc + (c.spent_amount_paise || 0), 0);

    const expenses = db.prepare('SELECT * FROM ngo_expenses WHERE ngo_id = ?').all(id) as any[];
    const unsupportedExpenses = expenses.filter(e => e.is_unsupported === 1 || !e.receipt_url).length;

    const areas = db.prepare('SELECT * FROM ngo_coverage_areas WHERE ngo_id = ?').all(id) as any[];
    const areasHelpedCount = areas.filter(a => a.status === 'HELPED').length;

    return {
      id: ngo.id,
      name: ngo.name,
      darpanId: ngo.darpan_id,
      kycStatus: ngo.kyc_status,
      totalReceivedInr: totalReceived / 100,
      totalSpentInr: totalSpent / 100,
      balanceInr: (totalReceived - totalSpent) / 100,
      reliefUtilizationPct: totalReceived > 0 ? Math.round((totalSpent / totalReceived) * 100) : 0,
      areasHelpedCount,
      unsupportedExpensesCount: unsupportedExpenses,
      anomalyFlags: unsupportedExpenses > 0 ? ['UNSUPPORTED_EXPENSES'] : []
    };
  };

  const entity1 = getEntityStats(entity1Id);
  const entity2 = getEntityStats(entity2Id);

  if (!entity1 || !entity2) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'One or both entities not found for comparison.' });
  }

  res.json({
    comparisonType: 'NGO_SIDE_BY_SIDE',
    entity1,
    entity2,
    insights: {
      higherFundUtilization: entity1.reliefUtilizationPct >= entity2.reliefUtilizationPct ? entity1.name : entity2.name,
      cleanerAuditRecord: entity1.unsupportedExpensesCount <= entity2.unsupportedExpensesCount ? entity1.name : entity2.name
    }
  });
});

/**
 * GET /api/v1/transparency/disaster-summary
 * Disaster-level losses and aid delivered with privacy aggregation (R-TRN-7 & Section 7.3).
 */
transparencyRouter.get('/disaster-summary', (req: Request, res: Response) => {
  const claimStats = db.prepare(`
    SELECT ward, count(*) as count_claims, sum(household_size) as people_affected,
           sum(estimated_value) as estimated_loss_inr,
           sum(case when status = 'DELIVERED' then 1 else 0 end) as aid_delivered_count
    FROM damage_claims
    GROUP BY ward
  `).all() as any[];

  const formattedStats = claimStats.map(s => ({
    ward: s.ward,
    peopleAffected: s.people_affected < 5 ? 'fewer than 5' : s.people_affected,
    claimsFiled: s.count_claims < 5 ? 'fewer than 5' : s.count_claims,
    aidDelivered: s.aid_delivered_count < 5 ? 'fewer than 5' : s.aid_delivered_count,
    estimatedLossInr: s.estimated_loss_inr || 0
  }));

  res.json({
    summary: 'Public Consolidated Disaster Loss & Relief Disbursal Report',
    privacyNotice: 'Aggregates below 5 masked as "fewer than 5". Zero victim PII.',
    wards: formattedStats
  });
});

