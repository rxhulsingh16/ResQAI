import { Router, Request, Response } from 'express';
import { authenticate, requireRole, requireJurisdiction } from '../middleware/rbacMiddleware';
import { getAuditLogs } from '../services/auditService';

export const rbacTestRouter = Router();

// GET /api/v1/rbac: RBAC policy and role verification overview
rbacTestRouter.get('/', (req: Request, res: Response) => {
  res.json({
    success: true,
    service: 'ResQAI Role-Based Access Control (RBAC) System',
    description: 'Enforces principle of least privilege, strict 2FA on high-privilege roles, and jurisdiction scopes.',
    demoEndpoints: {
      citizenOnly: '/api/v1/rbac/citizen-only',
      adminOnly: '/api/v1/rbac/admin-only',
      responderTask: '/api/v1/rbac/responder-task',
      ngoInventory: '/api/v1/rbac/ngo-inventory',
      jurisdictionEnforcement: '/api/v1/rbac/jurisdiction-data/:regionId'
    }
  });
});

// Endpoint accessible only by CITIZEN or ADMIN
rbacTestRouter.get('/citizen-only', authenticate, requireRole('CITIZEN'), (req: Request, res: Response) => {
  res.json({ message: 'Welcome Citizen', user: req.user });
});

// Endpoint accessible only by ADMIN
rbacTestRouter.get('/admin-only', authenticate, requireRole('ADMIN'), (req: Request, res: Response) => {
  res.json({ message: 'Welcome Admin / Control Room Commander', user: req.user });
});

// Endpoint accessible only by RESPONDER or ADMIN
rbacTestRouter.get('/responder-task', authenticate, requireRole('RESPONDER'), (req: Request, res: Response) => {
  res.json({ message: 'Rescue task data loaded', team: 'NDRF Unit', user: req.user });
});

// Endpoint accessible only by NGO or ADMIN
rbacTestRouter.get('/ngo-inventory', authenticate, requireRole('NGO'), (req: Request, res: Response) => {
  res.json({ message: 'NGO inventory board accessible', user: req.user });
});

// Endpoint accessible by AUDITOR or ADMIN (FR-53)
rbacTestRouter.get('/audit-logs', authenticate, requireRole('AUDITOR', 'ADMIN'), (req: Request, res: Response) => {
  const logs = getAuditLogs(50);
  res.json({ message: 'Immutable audit logs retrieved', count: logs.length, logs });
});

// FR-2: Jurisdiction-Scoped Resource Access (e.g. Area-specific operational clearance)
rbacTestRouter.get(
  '/area-operation/:areaId',
  authenticate,
  requireRole('GOVT_OFFICER', 'RESPONDER', 'ADMIN'),
  requireJurisdiction(req => req.params.areaId as string),
  (req: Request, res: Response) => {
    res.json({
      message: `Authorized operational clearance for ${req.params.areaId}`,
      officer: req.user?.name,
      jurisdiction: req.user?.jurisdictionRegionId || 'GLOBAL'
    });
  }
);
