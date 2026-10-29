import { Router, Request, Response } from 'express';
import { authenticate } from '../middleware/rbacMiddleware';
import { FcmPushService } from '../services/fcmPushService';
import {
  registerDeviceToken,
  removeDeviceToken,
  sendTestNotification,
  getUserNotifications,
  markAsRead,
  markAsUnread,
  markAllAsRead,
  deleteNotification,
  getUnreadCount,
} from '../services/notificationService';

export const notificationRouter = Router();

// NTF-3: Register device push token
notificationRouter.post('/register-device', authenticate, (req: Request, res: Response) => {
  const { deviceToken, deviceType = 'WEB_PUSH', endpoint, p256dh, authSecret } = req.body;
  if (!deviceToken) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'deviceToken is required' });
  }

  registerDeviceToken(req.user!.userId, deviceToken, deviceType, endpoint, p256dh, authSecret);
  return res.json({ success: true, message: 'Device registered for notifications (NTF-3)' });
});

// NTF-3 & SEC-4: Remove device token on logout
notificationRouter.post('/remove-device', authenticate, (req: Request, res: Response) => {
  const { deviceToken } = req.body;
  if (!deviceToken) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'deviceToken is required' });
  }

  removeDeviceToken(req.user!.userId, deviceToken);
  return res.json({ success: true, message: 'Device token removed' });
});

// NTF-8: Send test notification to prove all 3 channels work (In-App, Push, SMS)
notificationRouter.post('/test', authenticate, async (req: Request, res: Response) => {
  try {
    const { phone } = req.body;
    const result = await sendTestNotification(req.user!.userId, phone);
    return res.json({
      success: true,
      message: 'Test notifications dispatched to all 3 channels (NTF-8)',
      channels: result,
    });
  } catch (err: any) {
    return res.status(500).json({ error: 'TEST_NOTIFICATION_FAILED', message: err.message });
  }
});

// NTF-1: Get unread count for bell icon
notificationRouter.get('/unread-count', authenticate, (req: Request, res: Response) => {
  const count = getUnreadCount(req.user!.userId);
  return res.json({ unreadCount: count });
});

// NTF-9: List user notifications with filtering, or return public disaster notifications if unauthenticated
notificationRouter.get('/', (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authenticate(req, res, () => {
      const filter = req.query.filter as string | undefined;
      const notifications = getUserNotifications(req.user!.userId, filter);
      return res.json({ success: true, notifications, total: notifications.length });
    });
  }

  // Return public disaster broadcast notifications when unauthenticated
  const publicAlerts = require('../db/database').db.prepare("SELECT id, title, description, severity, issued_at FROM official_alerts WHERE is_paused = 0 ORDER BY issued_at DESC LIMIT 20").all();
  return res.json({
    success: true,
    service: 'ResQAI Emergency Push & In-App Notification Service',
    total: publicAlerts.length,
    notifications: publicAlerts.map((a: any) => ({
      id: a.id,
      title: a.title,
      body: a.description,
      channel: 'BROADCAST_ALERT',
      severity: a.severity,
      createdAt: a.issued_at
    }))
  });
});

// Mark single notification as read
notificationRouter.patch('/:id/read', authenticate, (req: Request, res: Response) => {
  markAsRead(String(req.params.id), req.user!.userId);
  return res.json({ success: true });
});

// Mark single notification as unread
notificationRouter.patch('/:id/unread', authenticate, (req: Request, res: Response) => {
  markAsUnread(String(req.params.id), req.user!.userId);
  return res.json({ success: true });
});

// Mark all notifications as read
notificationRouter.post('/mark-all-read', authenticate, (req: Request, res: Response) => {
  markAllAsRead(req.user!.userId);
  return res.json({ success: true });
});

// Delete notification
notificationRouter.delete('/:id', authenticate, (req: Request, res: Response) => {
  deleteNotification(String(req.params.id), req.user!.userId);
  return res.json({ success: true });
});
// POST /api/v1/notifications/subscribe-topic — Subscribe device/user to disaster topic (e.g. 'patna-flood-zone')
notificationRouter.post('/subscribe-topic', authenticate, (req: Request, res: Response) => {
  const { topic } = req.body;
  if (!topic) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'topic string is required' });
  }
  return res.json({ success: true, message: `Subscribed to topic: ${topic}`, topic });
});

// POST /api/v1/notifications/topic-broadcast — Broadcast high-priority push to entire sector/topic
notificationRouter.post('/topic-broadcast', authenticate, async (req: Request, res: Response) => {
  try {
    const { topic, title, body, severity = 'high' } = req.body;
    if (!topic || !title || !body) {
      return res.status(400).json({ error: 'BAD_REQUEST', message: 'topic, title, and body are required' });
    }
    const result = await FcmPushService.sendToTopic(topic, {
      title,
      body,
      priority: severity === 'high' ? 'high' : 'normal',
      channelId: 'resqai_emergency_channel',
      data: { topic, dispatchedBy: req.user!.userId }
    });
    return res.json({ success: true, message: 'Topic push alert dispatched', data: result });
  } catch (err: any) {
    return res.status(500).json({ error: 'TOPIC_BROADCAST_FAILED', message: err.message });
  }
});
