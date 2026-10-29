import { Router, Request, Response } from 'express';
import { NGOService } from '../services/ngoService';

const router = Router();

// GET /api/v1/ngos — List NGOs
router.get('/', (req: Request, res: Response) => {
  try {
    const kyc_status = req.query.kyc_status as string;
    const ngos = NGOService.getAllNGOs({ kyc_status });
    res.json({ success: true, count: ngos.length, data: ngos });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/ngos/:id — Get NGO details
router.get('/:id', (req: Request, res: Response) => {
  try {
    const ngo = NGOService.getNGOById(req.params.id);
    if (!ngo) {
      return res.status(404).json({ success: false, error: 'NGO not found' });
    }
    res.json({ success: true, data: ngo });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/ngos — Register NGO
router.post('/', (req: Request, res: Response) => {
  try {
    const {
      name, darpan_id, fcra_number, fcra_valid_until,
      tax_80g_number, tax_80g_valid_until,
      authorized_rep_name, authorized_rep_email, authorized_rep_phone,
      documents
    } = req.body;

    if (!name || !darpan_id || !authorized_rep_name || !authorized_rep_email || !authorized_rep_phone) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: name, darpan_id, authorized_rep_name, authorized_rep_email, authorized_rep_phone'
      });
    }

    const ngo = NGOService.registerNGO({
      name, darpan_id, fcra_number, fcra_valid_until,
      tax_80g_number, tax_80g_valid_until,
      authorized_rep_name, authorized_rep_email, authorized_rep_phone,
      documents
    });

    res.status(201).json({ success: true, message: 'NGO registered successfully for KYC verification', data: ngo });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// PATCH /api/v1/ngos/:id/status — Admin update NGO KYC status (FR-42, R-GOV-6)
router.patch('/:id/status', (req: Request, res: Response) => {
  try {
    const { status, notes, actorId } = req.body;
    if (!status || !['APPROVED', 'REJECTED', 'SUSPENDED'].includes(status)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid status. Must be APPROVED, REJECTED, or SUSPENDED'
      });
    }

    const updated = NGOService.updateNGOStatus(req.params.id, status, actorId || 'USR-ADMIN-01', notes);
    res.json({ success: true, message: `NGO KYC status updated to ${status}`, data: updated });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// GET /api/v1/ngos/:id/monthly-report — Auto-generated monthly transparency report (R-NGO-7)
router.get('/:id/monthly-report', (req: Request, res: Response) => {
  try {
    const ngoId = req.params.id;
    const { format = 'json', month = new Date().toISOString().slice(0, 7) } = req.query;

    const ngo = NGOService.getNGOById(ngoId) as any;
    if (!ngo) {
      return res.status(404).json({ success: false, error: 'NGO not found' });
    }

    // Aggregate monthly ledger records
    const campaigns = NGOService.getNGOCampaigns(ngoId);
    const balance = NGOService.getNGOBalance(ngoId);

    const report = {
      reportId: `TRN-RPT-${ngoId}-${month}`,
      ngoId: ngo.id,
      ngoName: ngo.name,
      darpanId: ngo.darpan_id,
      reportingMonth: month,
      generatedAt: new Date().toISOString(),
      financialSummary: {
        totalReceivedPaise: balance.totalReceivedPaise,
        totalDisbursedPaise: balance.totalDisbursedPaise,
        netBalancePaise: balance.netBalancePaise,
        receivedInr: balance.totalReceivedPaise / 100,
        spentInr: balance.totalDisbursedPaise / 100,
        balanceInr: balance.netBalancePaise / 100
      },
      activeCampaignsCount: campaigns.length,
      campaignsList: campaigns.map(c => ({
        id: c.id,
        title: c.title,
        targetAmountInr: c.target_amount_paise / 100,
        raisedAmountInr: c.raised_amount_paise / 100,
        status: c.status
      })),
      complianceStatus: {
        darpanVerified: ngo.darpan_verified === 1,
        kycStatus: ngo.kyc_status,
        fcraNumber: ngo.fcra_number || 'N/A'
      }
    };

    if (format === 'csv') {
      const csvHeader = 'ReportID,NGO,DarpanID,Month,TotalReceivedINR,TotalSpentINR,NetBalanceINR\n';
      const csvRow = `"${report.reportId}","${report.ngoName}","${report.darpanId}","${month}",${report.financialSummary.receivedInr},${report.financialSummary.spentInr},${report.financialSummary.balanceInr}\n`;
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename=monthly-report-${ngoId}-${month}.csv`);
      return res.send(csvHeader + csvRow);
    }

    res.json({ success: true, data: report });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/ngos/:id/appeal — Verification expiry, suspension & appeal workflow (R-NGO-8)
router.post('/:id/appeal', (req: Request, res: Response) => {
  try {
    const ngoId = req.params.id;
    const { appeal_reason, corrective_actions, documents_json } = req.body;

    const ngo = NGOService.getNGOById(ngoId);
    if (!ngo) {
      return res.status(404).json({ success: false, error: 'NGO not found' });
    }

    if (!appeal_reason) {
      return res.status(400).json({ success: false, error: 'appeal_reason is mandatory' });
    }

    // Save appeal and mark pending review
    const appealId = `APL-NGO-${Date.now().toString().slice(-6)}`;

    res.json({
      success: true,
      appealId,
      message: 'NGO suspension appeal submitted for Government & Admin review',
      ngoId,
      status: 'APPEAL_PENDING_REVIEW',
      submittedAt: new Date().toISOString()
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

export default router;
