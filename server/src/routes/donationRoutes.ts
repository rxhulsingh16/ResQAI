import { Router, Request, Response } from 'express';
import { PaymentService } from '../services/paymentService';

const router = Router();

// GET /api/v1/donations: Public donations and verified receipts overview
router.get('/', (req: Request, res: Response) => {
  try {
    const { campaign_id } = req.query;
    let query = "SELECT id, campaign_id, donor_name, amount_paise, currency, status, is_fcra_contribution, tax_80g_issued, created_at FROM donations WHERE status = 'PAID'";
    const params: any[] = [];
    if (campaign_id) {
      query += " AND campaign_id = ?";
      params.push(campaign_id);
    }
    query += " ORDER BY created_at DESC LIMIT 50";
    const donations = require('../db/database').db.prepare(query).all(...params);
    res.json({
      success: true,
      service: 'ResQAI Donation Gateway & 80G Receipt Service',
      totalDonations: donations.length,
      donations
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/donations/create-order — Initiate Razorpay Order (FR-44, FR-46, FR-47)
router.post('/create-order', (req: Request, res: Response) => {
  try {
    const {
      campaign_id, donor_name, donor_email, donor_phone, donor_pan,
      is_indian_citizen, is_fcra_contribution, amount_paise
    } = req.body;

    if (!campaign_id || !donor_name || !donor_email || !amount_paise) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: campaign_id, donor_name, donor_email, amount_paise'
      });
    }

    const order = PaymentService.createDonationOrder({
      campaign_id,
      donor_name,
      donor_email,
      donor_phone,
      donor_pan,
      is_indian_citizen: is_indian_citizen !== false,
      is_fcra_contribution: Boolean(is_fcra_contribution),
      amount_paise: Number(amount_paise)
    });

    res.status(201).json({
      success: true,
      message: 'Razorpay donation order created in test mode (FR-45)',
      data: order
    });
  } catch (error: any) {
    const status = error.message.includes('FCRA_COMPLIANCE_ERROR') ? 403 : 400;
    res.status(status).json({ success: false, error: error.message });
  }
});

// POST /api/v1/donations/verify-payment — Verify Server-Side Signature (FR-45, FR-46)
router.post('/verify-payment', (req: Request, res: Response) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(400).json({
        success: false,
        error: 'Missing required verification fields: razorpay_order_id, razorpay_payment_id, razorpay_signature'
      });
    }

    const result = PaymentService.verifyPayment({
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature
    });

    res.json({
      success: true,
      data: result
    });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// POST /api/v1/donations/webhook — Idempotent Razorpay Webhook Handler (FR-45)
router.post('/webhook', (req: Request, res: Response) => {
  try {
    const signature = req.headers['x-razorpay-signature'] as string;
    const rawBody = (req as any).rawBody || JSON.stringify(req.body);

    const result = PaymentService.handleWebhook(rawBody, signature, req.body);
    res.json({ success: true, data: result });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message });
  }
});

// GET /api/v1/donations/:id/receipt — 80G Tax Receipt (FR-46)
router.get('/:id/receipt', (req: Request, res: Response) => {
  try {
    const receipt = PaymentService.getDonationReceipt(req.params.id);
    res.json({ success: true, data: receipt });
  } catch (error: any) {
    res.status(404).json({ success: false, error: error.message });
  }
});

export default router;
