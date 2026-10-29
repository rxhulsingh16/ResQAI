import { Router, Request, Response } from 'express';
import { ReliefService } from '../services/reliefService';
import { db } from '../db/database';
import { logAuditEvent } from '../services/auditService';

export const reliefRouter = Router();

// GET /api/v1/relief: Relief coordination overview & needs matrix
reliefRouter.get('/', (req: Request, res: Response) => {
  try {
    const matrix = ReliefService.getNeedsMatrix();
    const shelters = db.prepare('SELECT * FROM shelters').all() as any[];
    res.json({
      success: true,
      service: 'ResQAI Disaster Relief & Supply Allocation System',
      totalShelters: shelters.length,
      needsMatrix: matrix
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/relief/shelters: Operational relief camps & capacities
reliefRouter.get('/shelters', (req: Request, res: Response) => {
  try {
    const shelters = db.prepare('SELECT * FROM shelters').all();
    res.json({
      success: true,
      count: shelters.length,
      data: shelters
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/relief/matrix
 * PRD E6 & H4-6: Returns full needs matrix with coverage percentages, shortage counts, and system outputs
 */
reliefRouter.get('/matrix', (req: Request, res: Response) => {
  try {
    const matrix = ReliefService.getNeedsMatrix();
    res.json({
      success: true,
      data: matrix,
      timestamp: new Date().toISOString()
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/relief/recommendations/:areaId/:resourceType
 * PRD H4-6: Recommendation drawer details with "Why this score?" factors, free stock, route safety
 */
reliefRouter.get('/recommendations/:areaId/:resourceType', (req: Request, res: Response) => {
  try {
    const { areaId, resourceType } = req.params;
    const recommendation = ReliefService.getCellRecommendation(areaId, resourceType.toUpperCase());
    res.json({
      success: true,
      data: recommendation
    });
  } catch (error: any) {
    res.status(404).json({ success: false, error: error.message });
  }
});

/**
 * POST /api/v1/relief/allocate
 * PRD FR-28: Reservation system with double-allocation gate and mandatory override reason
 */
reliefRouter.post('/allocate', (req: Request, res: Response) => {
  try {
    const {
      areaId,
      resourceType,
      allocatedUnits,
      sourceType,
      sourceName,
      allocatedByUserId,
      overrideReason
    } = req.body;

    if (!areaId || !resourceType || !allocatedUnits || !sourceName) {
      return res.status(400).json({
        success: false,
        error: 'Missing mandatory fields: areaId, resourceType, allocatedUnits, and sourceName are required.'
      });
    }

    const result = ReliefService.allocateResource({
      areaId,
      resourceType: resourceType.toUpperCase(),
      allocatedUnits: Number(allocatedUnits),
      sourceType: sourceType || 'CENTRAL_DEPOT',
      sourceName,
      allocatedByUserId: allocatedByUserId || 'USR-ADMIN-01',
      overrideReason
    });

    res.status(201).json({
      success: true,
      data: result,
      message: `Successfully reserved ${allocatedUnits} units of ${resourceType}.`
    });
  } catch (error: any) {
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/relief/confirm-delivery
 * PRD FR-29: Delivery confirmation requiring photo/OTP/signature proof
 */
reliefRouter.post('/confirm-delivery', (req: Request, res: Response) => {
  try {
    const {
      allocationId,
      confirmationType,
      confirmationRef,
      confirmedByUserId,
      notes
    } = req.body;

    if (!allocationId || !confirmationType || !confirmationRef) {
      return res.status(400).json({
        success: false,
        error: 'FR-29 Violation: allocationId, confirmationType (PHOTO, OTP, SIGNATURE), and confirmationRef are mandatory.'
      });
    }

    const result = ReliefService.confirmDelivery({
      allocationId,
      confirmationType: confirmationType.toUpperCase(),
      confirmationRef,
      confirmedByUserId: confirmedByUserId || 'USR-RESPONDER-01',
      notes
    });

    res.json({
      success: true,
      data: result
    });
  } catch (error: any) {
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/v1/relief/donor-matching
 * PRD FR-27: Smart Donation Matching and Redirection Engine
 */
reliefRouter.post('/donor-matching', (req: Request, res: Response) => {
  try {
    const {
      donorName,
      donorContact,
      resourceType,
      offeredUnits,
      targetAreaId,
      forceAcceptRedirect,
      redirectedFromAreaId
    } = req.body;

    if (!donorName || !resourceType || !offeredUnits || !targetAreaId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required donor pledge fields: donorName, resourceType, offeredUnits, targetAreaId.'
      });
    }

    const result = ReliefService.processDonorMatching({
      donorName,
      donorContact: donorContact || 'donor@resqai.org',
      resourceType: resourceType.toUpperCase(),
      offeredUnits: Number(offeredUnits),
      targetAreaId,
      forceAcceptRedirect: Boolean(forceAcceptRedirect),
      redirectedFromAreaId
    });

    res.json({
      success: true,
      data: result
    });
  } catch (error: any) {
    res.status(400).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/v1/relief/alerts
 * PRD FR-30: Resource Shortage and Expiry Alerts
 */
reliefRouter.get('/alerts', (req: Request, res: Response) => {
  try {
    const alerts = ReliefService.getResourceAlerts();
    res.json({
      success: true,
      data: alerts
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * GET /api/v1/relief/donor-view
 * PRD H4-6: Public Donor View showing Needed Now, Fully Covered, and Alternatives
 */
reliefRouter.get('/donor-view', (req: Request, res: Response) => {
  try {
    const matrix = ReliefService.getNeedsMatrix();

    const neededNow: any[] = [];
    const fullyCovered: any[] = [];
    const alternativesNearby: any[] = [];

    for (const area of matrix) {
      for (const [resKey, item] of Object.entries(area.needs)) {
        if (item.coveragePercent >= 100) {
          fullyCovered.push({
            areaId: area.areaId,
            areaName: area.areaName,
            resourceType: resKey,
            coveragePercent: 100,
            statusLabel: 'Fully covered (thank you)',
            unitsFulfilled: `${item.availableUnits}/${item.requiredUnits}`
          });
        } else if (item.coveragePercent < 50) {
          neededNow.push({
            areaId: area.areaId,
            areaName: area.areaName,
            resourceType: resKey,
            coveragePercent: item.coveragePercent,
            shortageUnits: item.shortageUnits,
            urgencyBadge: item.coveragePercent === 0 ? 'CRITICAL' : 'HIGH',
            priorityScore: item.priorityScore,
            statusLabel: `Needed now (${item.coveragePercent}% met, short ${item.shortageUnits} units)`
          });
        } else {
          alternativesNearby.push({
            areaId: area.areaId,
            areaName: area.areaName,
            resourceType: resKey,
            coveragePercent: item.coveragePercent,
            shortageUnits: item.shortageUnits,
            statusLabel: `Partially met (${item.coveragePercent}%)`
          });
        }
      }
    }

    res.json({
      success: true,
      data: {
        neededNow,
        fullyCovered,
        alternativesNearby
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * POST /api/v1/relief/reset-demo
 * Resets the seed worked example so evaluators can test live repeatedly
 */
reliefRouter.post('/reset-demo', (req: Request, res: Response) => {
  try {
    // Reset Area A, B, C numbers to initial worked example
    const updateNeed = db.prepare(`
      UPDATE area_needs 
      SET available_units = @available, reserved_units = @reserved, dispatched_units = @dispatched, delivered_units = @delivered, pending_units = @pending, last_verified = datetime('now')
      WHERE area_id = @areaId AND resource_type = @resType
    `);

    // Area A
    updateNeed.run({ areaId: 'area-a', resType: 'FOOD', available: 500, reserved: 50, dispatched: 350, delivered: 100, pending: 0 });
    updateNeed.run({ areaId: 'area-a', resType: 'WATER', available: 800, reserved: 100, dispatched: 500, delivered: 200, pending: 200 });
    updateNeed.run({ areaId: 'area-a', resType: 'MEDICINE', available: 60, reserved: 10, dispatched: 30, delivered: 20, pending: 240 });

    // Area B
    updateNeed.run({ areaId: 'area-b', resType: 'FOOD', available: 160, reserved: 20, dispatched: 100, delivered: 40, pending: 240 });
    updateNeed.run({ areaId: 'area-b', resType: 'WATER', available: 0, reserved: 0, dispatched: 0, delivered: 0, pending: 800 });
    updateNeed.run({ areaId: 'area-b', resType: 'MEDICINE', available: 120, reserved: 15, dispatched: 80, delivered: 25, pending: 80 });

    // Area C
    updateNeed.run({ areaId: 'area-c', resType: 'FOOD', available: 190, reserved: 20, dispatched: 140, delivered: 30, pending: 10 });
    updateNeed.run({ areaId: 'area-c', resType: 'WATER', available: 450, reserved: 50, dispatched: 350, delivered: 50, pending: 50 });
    updateNeed.run({ areaId: 'area-c', resType: 'MEDICINE', available: 90, reserved: 10, dispatched: 70, delivered: 10, pending: 10 });

    logAuditEvent({
      actionType: 'ALLOCATION',
      actorId: 'DEMO_RESET',
      actorRole: 'ADMIN',
      entityId: 'WORKED_EXAMPLE_RESET',
      details: 'Reset Area A/B/C relief worked example to seed numbers for demonstration'
    });

    res.json({
      success: true,
      message: 'Worked example numbers reset to PRD Part E6 baseline.'
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
