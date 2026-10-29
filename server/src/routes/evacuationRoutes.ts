import { Router, Request, Response } from 'express';
import { EvacuationService } from '../services/evacuationService';

export const evacuationRouter = Router();

// GET /api/v1/evacuation: Evacuation zones and assisted pickup operations
evacuationRouter.get('/', (_req: Request, res: Response) => {
  try {
    const zones = EvacuationService.getAllZones();
    res.json({
      success: true,
      service: 'ResQAI Emergency Evacuation & Corridor Directives',
      totalZones: zones.length,
      zones,
      endpoints: {
        zones: '/api/v1/evacuation/zones',
        assistedPickups: '/api/v1/evacuation/assisted-pickups'
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/evacuation/zones - List evacuation zones
evacuationRouter.get('/zones', (_req: Request, res: Response) => {
  try {
    const zones = EvacuationService.getAllZones();
    res.json({ success: true, zones });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// POST /api/v1/evacuation/zones/:id/status - Update zone status
evacuationRouter.post('/zones/:id/status', (req: Request, res: Response) => {
  try {
    const actorRole = (req.headers['x-user-role'] as string) || req.body.role || 'GOVT_OFFICER';
    const actorId = (req.headers['x-user-id'] as string) || req.body.officer_id || 'USR-OFFICER-01';

    const zone = EvacuationService.updateZoneStatus(
      req.params.id,
      req.body.active_status,
      req.body.route_notes || '',
      actorId,
      actorRole
    );
    res.json({ success: true, zone });
  } catch (error: any) {
    const status = error.message?.includes('Unauthorized') ? 403 : 400;
    res.status(status).json({ success: false, error: error.message });
  }
});

// GET /api/v1/evacuation/assisted-pickups - Vulnerable citizens requiring assisted transport
evacuationRouter.get('/assisted-pickups', (req: Request, res: Response) => {
  try {
    const areaId = req.query.area_id as string;
    const pickups = EvacuationService.getAssistedPickupList(areaId);
    res.json({ success: true, pickups });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
