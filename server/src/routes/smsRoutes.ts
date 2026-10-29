import { Router, Request, Response } from 'express';
import { SMSAdapterService } from '../services/smsAdapterService';
import { VoiceTranscriptionService } from '../services/voiceTranscriptionService';
import { db } from '../db/database';

const router = Router();

// GET /api/v1/sms: SMS, IVR hotline & low-bandwidth fallback overview
router.get('/', (req: Request, res: Response) => {
  const provider = process.env.SMS_PROVIDER || (process.env.TWILIO_ACCOUNT_SID ? 'twilio' : process.env.MSG91_AUTH_KEY ? 'msg91' : 'mock');
  res.json({
    success: true,
    service: 'ResQAI Low-Bandwidth SMS & IVR Hotline Gateway',
    activeProvider: provider.toUpperCase(),
    endpoints: {
      inbound: 'POST /api/v1/sms/inbound',
      outbound: 'POST /api/v1/sms/outbound',
      messages: 'GET /api/v1/sms/messages',
      ivrCalls: 'GET /api/v1/sms/ivr/calls',
      voiceNote: 'POST /api/v1/sms/voice-note',
      providerStatus: 'GET /api/v1/sms/provider-status'
    }
  });
});

// POST /api/v1/sms/inbound — Inbound SMS Gateway Webhook (FR-48, FR-50)
router.post('/inbound', (req: Request, res: Response) => {
  try {
    const { sender_phone, message, text } = req.body;
    const rawText = message || text;

    if (!sender_phone || !rawText) {
      return res.status(400).json({
        success: false,
        error: 'Missing required SMS payload: sender_phone, and message/text'
      });
    }

    const result = SMSAdapterService.parseInboundSMS(sender_phone, rawText);
    res.json({
      success: true,
      message: 'Inbound emergency SMS parsed and processed into incident pipeline (FR-50)',
      data: result
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/sms/whatsapp/inbound — Inbound WhatsApp Webhook (FR-50)
router.post('/whatsapp/inbound', (req: Request, res: Response) => {
  try {
    const { from, body, message } = req.body;
    const senderPhone = from || req.body.sender_phone;
    const rawText = body || message || req.body.text;

    if (!senderPhone || !rawText) {
      return res.status(400).json({
        success: false,
        error: 'Missing required WhatsApp payload: from/sender_phone and body/message'
      });
    }

    const result = SMSAdapterService.parseInboundSMS(senderPhone, rawText);
    res.json({
      success: true,
      channel: 'WHATSAPP',
      message: 'Inbound WhatsApp distress message processed into incident triage queue',
      data: result
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/sms/voice-note — Inbound Voice Note with STT Transcription & Audio Link
router.post('/voice-note', async (req: Request, res: Response) => {
  try {
    const { caller_phone, audio_url, duration_seconds, language, transcript_override } = req.body;

    if (!caller_phone) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: caller_phone'
      });
    }

    const result = await VoiceTranscriptionService.processVoiceNote({
      caller_phone,
      audio_url: audio_url || `/uploads/audio/VN-${Date.now()}.m4a`,
      duration_seconds: duration_seconds || 15,
      language: language || 'hi-IN',
      transcript_override
    });

    res.json({
      success: true,
      message: 'Voice note transcribed and incident filed with original audio preservation',
      data: result
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/sms/voice-notes/:id — Fetch voice note details
router.get('/voice-notes/:id', (req: Request, res: Response) => {
  try {
    const note = db.prepare('SELECT * FROM voice_notes WHERE id = ?').get(req.params.id);
    if (!note) {
      return res.status(404).json({ success: false, error: 'Voice note not found' });
    }
    res.json({ success: true, data: note });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/sms/simulate-offline-fallback — Generates formatted SMS under 160 chars
router.post('/simulate-offline-fallback', (req: Request, res: Response) => {
  try {
    const { category = 'FLOOD', people_count = 2, location = 'Sector A', needs = ['food', 'boat'] } = req.body;
    const formattedPayload = VoiceTranscriptionService.formatOfflineSMSPayload({
      category,
      peopleCount: people_count,
      location,
      needs
    });

    res.json({
      success: true,
      lengthChars: formattedPayload.length,
      isUnder160Chars: formattedPayload.length <= 160,
      smsPayload: formattedPayload,
      targetShortCode: '112 / 51969'
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/sms/status-callback — Delivery receipts callback
router.post('/status-callback', (req: Request, res: Response) => {
  try {
    const { message_id, status = 'DELIVERED', error_code } = req.body;
    if (message_id) {
      db.prepare(`
        UPDATE inbound_sms_messages
        SET delivery_status = ?, provider_error = ?
        WHERE id = ?
      `).run(status === 'DELIVERED' ? 'PROCESSED' : 'PARSE_FAILED', error_code || null, message_id);
    }

    res.json({ success: true, received: true, status });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/sms/messages — List inbound messages
router.get('/messages', (_req: Request, res: Response) => {
  try {
    const messages = SMSAdapterService.getAllInboundMessages();
    res.json({ success: true, count: messages.length, data: messages });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

import crypto from 'crypto';
import { SmsGatewayManager } from '../services/smsProviders';

// POST /api/v1/sms/outbound — Dispatch Real SMS through Active Provider
router.post('/outbound', async (req: Request, res: Response) => {
  try {
    const { to, message } = req.body;
    if (!to || !message) {
      return res.status(400).json({ success: false, error: 'Recipient phone (to) and message are required' });
    }
    const result = await SmsGatewayManager.send(to, message);
    res.json({
      success: result.success,
      messageId: result.messageId,
      provider: result.provider,
      timestamp: result.timestamp
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/sms/provider-status — Get current SMS provider & health
router.get('/provider-status', (_req: Request, res: Response) => {
  const provider = process.env.SMS_PROVIDER || (process.env.TWILIO_ACCOUNT_SID ? 'twilio' : process.env.MSG91_AUTH_KEY ? 'msg91' : 'mock');
  res.json({
    success: true,
    activeProvider: provider.toUpperCase(),
    twilioConfigured: !!(process.env.TWILIO_ACCOUNT_SID && !process.env.TWILIO_ACCOUNT_SID.includes('your_')),
    msg91Configured: !!(process.env.MSG91_AUTH_KEY && !process.env.MSG91_AUTH_KEY.includes('your_'))
  });
});

// POST /api/v1/sms/ivr/incoming — Interactive Voice Response (IVR) Entrypoint (TwiML / JSON)
router.post('/ivr/incoming', (req: Request, res: Response) => {
  try {
    const callerPhone = req.body.From || req.body.caller_phone || req.body.Caller || '+910000000000';
    const callSid = req.body.CallSid || `CALL-${Date.now()}`;

    // Return TwiML Voice Response if twilio format requested or accepted
    if (req.headers.accept?.includes('xml') || req.body.CallSid) {
      res.type('text/xml');
      return res.send(`<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Gather numDigits="1" action="/api/v1/sms/ivr/selection" method="POST" timeout="10">
    <Say language="hi-IN">Namaste. Aap ResQAI Aapatkaaleen Seva par hain. Baadh ya paani aane par ek dabayein. Medical emergency ke liye do dabayein. Khana aur paani ke liye teen dabayein. Malbe me dabe hone par chaar dabayein.</Say>
    <Say language="en-IN">For Flood emergency, press 1. For Medical emergency, press 2. For Food and water, press 3. For Collapse or Trapped victim, press 4.</Say>
  </Gather>
  <Say language="hi-IN">Humein aapka input nahi mila. Kripya 112 par call karein.</Say>
</Response>`);
    }

    res.json({
      success: true,
      call_sid: callSid,
      caller_phone: callerPhone,
      prompt: 'Namaste. Aap ResQAI Aapatkaaleen Seva par hain. Baadh ke liye 1, Medical ke liye 2, Khana/Paani ke liye 3, Malbe ke liye 4 dabayein.',
      options: [
        { digit: 1, emergency: 'FLOOD', urgency: 'CRITICAL' },
        { digit: 2, emergency: 'MEDICAL', urgency: 'CRITICAL' },
        { digit: 3, emergency: 'FOOD_WATER', urgency: 'HIGH' },
        { digit: 4, emergency: 'COLLAPSE', urgency: 'CRITICAL' }
      ]
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/sms/ivr/selection — Handle DTMF keypress and register emergency incident
router.post('/ivr/selection', (req: Request, res: Response) => {
  try {
    const digits = String(req.body.Digits || req.body.digits || '1').trim();
    const callerPhone = req.body.From || req.body.caller_phone || req.body.Caller || '+919999988888';
    const callSid = req.body.CallSid || `CALL-${Date.now()}`;

    let category = 'FLOOD';
    let urgency: 'CRITICAL' | 'HIGH' | 'MEDIUM' = 'CRITICAL';
    let title = 'IVR Hotline: Severe Inundation Alert';
    let priorityScore = 85;

    switch (digits) {
      case '1':
        category = 'FLOOD';
        title = 'IVR Hotline: Severe Inundation Alert';
        urgency = 'CRITICAL';
        priorityScore = 85;
        break;
      case '2':
        category = 'MEDICAL';
        title = 'IVR Hotline: Urgent Medical Casualty';
        urgency = 'CRITICAL';
        priorityScore = 90;
        break;
      case '3':
        category = 'FOOD_WATER';
        title = 'IVR Hotline: Food & Potable Water Distress';
        urgency = 'HIGH';
        priorityScore = 70;
        break;
      case '4':
        category = 'COLLAPSE';
        title = 'IVR Hotline: Structural Collapse / Trapped Victims';
        urgency = 'CRITICAL';
        priorityScore = 95;
        break;
      default:
        category = 'OTHER';
        title = `IVR Hotline: Emergency (Input ${digits})`;
        urgency = 'HIGH';
        priorityScore = 65;
        break;
    }

    const incidentId = `INC-IVR-${Date.now()}`;
    const logId = `IVR-${Date.now()}`;

    // Auto-create incident from IVR
    db.prepare(`
      INSERT INTO incidents (
        id, title, category, status, urgency, priority_score,
        latitude, longitude, location_name, area_id, people_affected,
        created_at, updated_at, sla_deadline_minutes, is_simulated_drill
      ) VALUES (
        ?, ?, ?, 'RECEIVED', ?, ?,
        25.5941, 85.1376, 'Hotline Caller Jurisdiction (Auto-Triaged)', 'area-a', 2,
        datetime('now'), datetime('now'), 15, 0
      )
    `).run(incidentId, title, category, urgency, priorityScore);

    // Save IVR call log
    db.prepare(`
      INSERT INTO ivr_call_logs (
        id, call_sid, caller_phone, digits_pressed, selected_emergency, incident_id, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, 'COMPLETED', datetime('now'))
    `).run(logId, callSid, callerPhone, digits, category, incidentId);

    if (req.headers.accept?.includes('xml') || req.body.CallSid) {
      res.type('text/xml');
      return res.send(`<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say language="hi-IN">Aapki soochana darj kar li gayi hai. Aapatkaaleen ticket number hai: ${incidentId}. Sahayata dal ko suchit kiya ja raha hai.</Say>
  <Say language="en-IN">Your emergency has been registered under ticket number ${incidentId}. Rescue teams are notified.</Say>
  <Hangup/>
</Response>`);
    }

    res.json({
      success: true,
      message: 'IVR emergency distress call processed and incident ticket dispatched',
      data: {
        incident_id: incidentId,
        call_sid: callSid,
        caller_phone: callerPhone,
        category,
        urgency,
        priority_score: priorityScore
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/sms/ivr/calls — List IVR calls
router.get('/ivr/calls', (_req: Request, res: Response) => {
  try {
    const calls = db.prepare('SELECT * FROM ivr_call_logs ORDER BY created_at DESC LIMIT 50').all();
    res.json({ success: true, count: calls.length, data: calls });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

export default router;
