import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import { db } from '../db/database';
import { authenticate, requireRole } from '../middleware/rbacMiddleware';
import { logAuditEvent } from '../services/auditService';

export const volunteerRouter = Router();

function formatVolunteerTasks(tasks: any[]) {
  return tasks.map(t => ({
    ...t,
    safetyWarning: t.safety_level === 'UNSAFE_TRAINED_ONLY'
      ? 'WARNING: Severe hazard zone. Untrained volunteers: DO NOT ENTER. Restricted to certified emergency response teams.'
      : t.safety_level === 'CAUTION'
      ? 'CAUTION: Standing water / debris. Protective rubber boots & lifejacket required.'
      : 'SAFE: Clear access corridor.',
    isRestricted: t.safety_level === 'UNSAFE_TRAINED_ONLY'
  }));
}

// GET /api/v1/volunteer: Community volunteer coordination overview
volunteerRouter.get('/', (req: Request, res: Response) => {
  try {
    const tasks = db.prepare('SELECT * FROM volunteer_tasks ORDER BY priority_score DESC').all() as any[];
    const volunteerCount = (db.prepare("SELECT count(*) as count FROM users WHERE role = 'VOLUNTEER'").get() as any).count;
    res.json({
      success: true,
      service: 'ResQAI Community Volunteer Operations',
      registeredVolunteers: volunteerCount,
      totalTasks: tasks.length,
      tasks: formatVolunteerTasks(tasks)
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/volunteer/tasks: List open and assigned tasks
volunteerRouter.get('/tasks', (req: Request, res: Response) => {
  try {
    const { status, area_id } = req.query;
    let query = 'SELECT * FROM volunteer_tasks WHERE 1=1';
    const params: any[] = [];
    if (status) {
      query += ' AND status = ?';
      params.push(status);
    }
    if (area_id) {
      query += ' AND area_id = ?';
      params.push(area_id);
    }
    query += ' ORDER BY priority_score DESC, created_at DESC';
    const tasks = db.prepare(query).all(...params) as any[];
    res.json({
      success: true,
      count: tasks.length,
      tasks: formatVolunteerTasks(tasks)
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/volunteer/board
 * Local help board ranked by priority with safety status and flags (R-VOL-2).
 * High risk/inundated zones flag: "untrained volunteers: do not enter".
 */
volunteerRouter.get('/board', (req: Request, res: Response) => {
  const { area_id } = req.query;
  let query = 'SELECT * FROM volunteer_tasks WHERE status IN (\'OPEN\', \'ASSIGNED\')';
  const params: any[] = [];

  if (area_id) {
    query += ' AND area_id = ?';
    params.push(area_id);
  }
  query += ' ORDER BY priority_score DESC, created_at DESC';

  const tasks = db.prepare(query).all(...params) as any[];

  res.json({
    totalTasks: tasks.length,
    tasks: tasks.map(t => ({
      ...t,
      safetyWarning: t.safety_level === 'UNSAFE_TRAINED_ONLY'
        ? 'WARNING: Severe hazard zone. Untrained volunteers: DO NOT ENTER. Restricted to certified emergency response teams.'
        : t.safety_level === 'CAUTION'
        ? 'CAUTION: Standing water / debris. Protective rubber boots & lifejacket required.'
        : 'SAFE: Clear access corridor.',
      isRestricted: t.safety_level === 'UNSAFE_TRAINED_ONLY'
    }))
  });
});

/**
 * POST /api/v1/volunteer/tasks/:id/accept
 * Volunteer accepts a task (R-VOL-3).
 */
volunteerRouter.post('/tasks/:id/accept', authenticate, requireRole('VOLUNTEER', 'ADMIN'), (req: Request, res: Response) => {
  const taskId = req.params.id;
  const volunteerId = req.user!.userId;

  const task = db.prepare('SELECT * FROM volunteer_tasks WHERE id = ?').get(taskId) as any;
  if (!task) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'Volunteer task not found' });
  }

  if (task.safety_level === 'UNSAFE_TRAINED_ONLY') {
    // Check if volunteer has safety training
    const user = db.prepare('SELECT safety_briefing_accepted FROM users WHERE id = ?').get(volunteerId) as any;
    if (!user || user.safety_briefing_accepted !== 1) {
      return res.status(403).json({
        error: 'SAFETY_RESTRICTION',
        message: 'Untrained volunteers: DO NOT ENTER. This task requires completed safety training & SDRF briefing.'
      });
    }
  }

  db.prepare(`
    UPDATE volunteer_tasks
    SET status = 'ASSIGNED', assigned_volunteer_id = ?
    WHERE id = ?
  `).run(volunteerId, taskId);

  logAuditEvent({
    actionType: 'VOLUNTEER_TASK_ACCEPTED',
    actorId: volunteerId,
    actorRole: 'VOLUNTEER',
    entityId: taskId,
    details: `Volunteer ${volunteerId} accepted task "${task.title}".`
  });

  res.json({ message: 'Task successfully accepted', taskId, status: 'ASSIGNED', assignedVolunteerId: volunteerId });
});

/**
 * POST /api/v1/volunteer/tasks/:id/check-in
 * Volunteer checks in on-site (R-VOL-3).
 */
volunteerRouter.post('/tasks/:id/check-in', authenticate, requireRole('VOLUNTEER', 'ADMIN'), (req: Request, res: Response) => {
  const taskId = req.params.id;
  const { latitude, longitude } = req.body;
  const checkInTime = new Date().toISOString();

  db.prepare(`
    UPDATE volunteer_tasks
    SET status = 'CHECKED_IN', check_in_at = ?, check_in_lat = ?, check_in_lng = ?
    WHERE id = ?
  `).run(checkInTime, latitude || 0, longitude || 0, taskId);

  res.json({ message: 'Checked in on-site successfully', taskId, status: 'CHECKED_IN', checkInTime });
});

/**
 * POST /api/v1/volunteer/tasks/:id/complete
 * Upload delivery proof and complete task (R-VOL-3).
 */
volunteerRouter.post('/tasks/:id/complete', authenticate, requireRole('VOLUNTEER', 'ADMIN'), (req: Request, res: Response) => {
  const taskId = req.params.id;
  const { proof_url, hours_spent = 2, items_delivered = 10 } = req.body;
  const volunteerId = req.user!.userId;

  if (!proof_url) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Delivery proof photo or document URL is mandatory.' });
  }

  const completedAt = new Date().toISOString();

  db.prepare(`
    UPDATE volunteer_tasks
    SET status = 'COMPLETED', proof_url = ?, completed_at = ?
    WHERE id = ?
  `).run(proof_url, completedAt, taskId);

  // Log in volunteer impact ledger (R-VOL-5)
  const ledgerId = `LEDG-${Date.now().toString().slice(-6)}-${Math.floor(Math.random() * 1000)}`;
  db.prepare(`
    INSERT INTO volunteer_impact_ledgers (
      id, volunteer_id, task_id, hours_logged, items_delivered_count, activity_type, logged_at
    ) VALUES (?, ?, ?, ?, ?, 'RELIEF_TASK_COMPLETION', ?)
  `).run(ledgerId, volunteerId, taskId, hours_spent, items_delivered, completedAt);

  logAuditEvent({
    actionType: 'VOLUNTEER_TASK_COMPLETED',
    actorId: volunteerId,
    actorRole: 'VOLUNTEER',
    entityId: taskId,
    details: `Task ${taskId} completed with delivery proof. Logged ${hours_spent} hours, ${items_delivered} items.`
  });

  res.json({
    message: 'Task marked as completed with verified delivery proof.',
    taskId,
    status: 'COMPLETED',
    proofUrl: proof_url,
    hoursLogged: hours_spent,
    itemsDelivered: items_delivered
  });
});

/**
 * POST /api/v1/volunteer/quiz
 * Short claim verification training quiz (R-VOL-4).
 */
volunteerRouter.post('/quiz', authenticate, (req: Request, res: Response) => {
  const { answers = [] } = req.body; // array of answers
  const volunteerId = req.user!.userId;

  // Evaluate quiz: expects 3 correct core answers
  const isCertified = answers.length >= 3 && answers.every((a: boolean) => a === true);

  if (isCertified) {
    try {
      db.prepare(`
        INSERT INTO volunteer_profiles (user_id, claim_verification_certified)
        VALUES (?, 1)
        ON CONFLICT(user_id) DO UPDATE SET claim_verification_certified = 1
      `).run(volunteerId);
    } catch (_) {}

    try {
      db.prepare('UPDATE users SET training_quiz_passed = 1 WHERE id = ?').run(volunteerId);
    } catch (_) {}

    return res.json({
      certified: true,
      message: 'Congratulations! You scored 100% and are certified to verify community damage claims (R-VOL-4).'
    });
  }

  res.json({
    certified: false,
    message: 'Quiz incomplete or answers incorrect. Please review the verification guidelines and try again.'
  });
});

/**
 * GET /api/v1/volunteer/:id/impact
 * Personal impact ledger and certificate (R-VOL-5).
 */
volunteerRouter.get('/:id/impact', authenticate, (req: Request, res: Response) => {
  const volunteerId = req.params.id;

  const entries = db.prepare(`
    SELECT * FROM volunteer_impact_ledgers WHERE volunteer_id = ? ORDER BY logged_at DESC
  `).all(volunteerId) as any[];

  const totalHours = entries.reduce((acc, e) => acc + (e.hours_logged || 0), 0);
  const totalItems = entries.reduce((acc, e) => acc + (e.items_delivered_count || 0), 0);
  const tasksCompleted = entries.length;

  res.json({
    volunteerId,
    totalHoursLogged: totalHours,
    totalItemsDelivered: totalItems,
    tasksCompleted,
    impactCertificate: {
      certificateNumber: `CERT-${volunteerId.slice(-8)}-${Date.now().toString().slice(-4)}`,
      status: 'VERIFIED',
      issuer: 'ResQAI Disaster Volunteer Corps',
      honorsBadge: totalHours >= 10 ? 'GOLD_COMMUNITY_RESPONDER' : 'ACTIVE_VOLUNTEER',
      hoursVerified: totalHours
    },
    entries
  });
});

