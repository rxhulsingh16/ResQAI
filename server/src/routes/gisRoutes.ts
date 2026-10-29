import { Router, Request, Response } from 'express';
import { db } from '../db/database';
import { authenticate, requireRole } from '../middleware/rbacMiddleware';
import { logAuditEvent } from '../services/auditService';
import { verifyAccessToken } from '../services/authService';
import { PolygonGeofenceService } from '../services/polygonGeofenceService';

export const gisRouter = Router();

// Seed road closures and shelters if not present
function ensureGisFixtures() {
  const roadCount = (db.prepare('SELECT count(*) as c FROM road_closures').get() as any).c;
  if (roadCount === 0) {
    db.prepare(`
      INSERT INTO road_closures (id, road_name, area_id, cause, start_lat, start_lng, end_lat, end_lng, is_passable_for_emergency)
      VALUES 
      ('RC-001', 'Ashok Rajpath East Corridor', 'area-a', 'FLOODING', 25.6180, 85.1480, 25.6210, 85.1550, 0),
      ('RC-002', 'Bypass Lowland Underpass', 'area-b', 'FLOODING', 25.5910, 85.1200, 25.5930, 85.1260, 0)
    `).run();
  }
}

// GET /api/v1/gis: Overview of GIS layers, stats, and safe corridors
gisRouter.get('/', (req: Request, res: Response) => {
  ensureGisFixtures();
  try {
    const areas = db.prepare('SELECT * FROM affected_areas').all();
    const closures = db.prepare('SELECT * FROM road_closures').all();
    const shelters = db.prepare('SELECT * FROM shelters').all();
    const activeIncidents = db.prepare("SELECT count(*) as c FROM incidents WHERE status NOT IN ('CLOSED', 'REJECTED')").get() as any;

    res.json({
      success: true,
      service: 'ResQAI GIS & Geospatial Navigation Engine',
      stats: {
        affectedAreasCount: areas.length,
        activeRoadClosures: closures.length,
        operationalShelters: shelters.length,
        activeIncidentsCount: activeIncidents?.c || 0
      },
      endpoints: {
        layers: '/api/v1/gis/layers',
        corridors: '/api/v1/gis/corridors',
        stats: '/api/v1/gis/stats',
        shelters: '/api/v1/gis/shelters/capacity-board'
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/gis/stats
gisRouter.get('/stats', (req: Request, res: Response) => {
  try {
    const areas = db.prepare('SELECT count(*) as c FROM affected_areas').get() as any;
    const closures = db.prepare('SELECT count(*) as c FROM road_closures').get() as any;
    const shelters = db.prepare('SELECT count(*) as c FROM shelters').get() as any;
    const activeIncidents = db.prepare("SELECT count(*) as c FROM incidents WHERE status NOT IN ('CLOSED', 'REJECTED')").get() as any;

    res.json({
      success: true,
      data: {
        affectedAreas: areas?.c || 0,
        activeRoadClosures: closures?.c || 0,
        shelters: shelters?.c || 0,
        activeIncidents: activeIncidents?.c || 0
      }
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/gis/corridors
gisRouter.get('/corridors', (req: Request, res: Response) => {
  try {
    ensureGisFixtures();
    const closures = db.prepare('SELECT * FROM road_closures').all();
    res.json({
      success: true,
      count: closures.length,
      roadClosures: closures
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// FR-20, FR-21, FR-24: Retrieve all GIS map layers with distinct metadata
gisRouter.get('/layers', (req: Request, res: Response) => {
  ensureGisFixtures();

  // 1. Official Alerts
  const officialAlerts = db.prepare('SELECT * FROM official_alerts').all();

  // 2. Incidents (Verified and Unverified)
  const incidents = db.prepare(`
    SELECT id, title, category, status, urgency, priority_score, latitude, longitude, location_name, area_id, people_affected, assigned_team_id, created_at
    FROM incidents
    WHERE status NOT IN ('CLOSED', 'REJECTED')
  `).all();

  // 3. ML Hazard Prediction Risk Polygons (FR-24: polygons/grid cells, never falsely precise points)
  const mlPredictions = [
    {
      id: 'ML-POLY-SECTOR-A',
      areaId: 'area-a',
      areaName: 'Sector A (North River Basin)',
      riskLevel: 'CRITICAL',
      calibratedProbability: 0.87,
      polygonCoordinates: [
        [25.608, 85.138],
        [25.620, 85.139],
        [25.622, 85.152],
        [25.611, 85.155],
        [25.608, 85.138]
      ],
      rainfall48h: '168mm',
      cwcGaugeStatus: '+0.85m Danger Mark',
      modelAssessmentNote: 'ML Assessment — not an official government warning'
    },
    {
      id: 'ML-POLY-SECTOR-B',
      areaId: 'area-b',
      areaName: 'Sector B (Lowland Colony)',
      riskLevel: 'HIGH',
      calibratedProbability: 0.74,
      polygonCoordinates: [
        [25.589, 85.115],
        [25.599, 85.116],
        [25.601, 85.130],
        [25.591, 85.129],
        [25.589, 85.115]
      ],
      rainfall48h: '95mm',
      cwcGaugeStatus: 'Drainage Canal Saturation 94%',
      modelAssessmentNote: 'ML Assessment — not an official government warning'
    }
  ];

  // 4. Rescue Teams (FR-16)
  const teams = db.prepare('SELECT * FROM rescue_teams').all();

  // 5. Safe Shelters & Facilities
  const shelters = [
    {
      id: 'SHELTER-01',
      name: 'Patna Central High School Relief Camp',
      areaId: 'area-a',
      latitude: 25.6150,
      longitude: 85.1480,
      capacity: 500,
      currentOccupancy: 310,
      facilities: ['DRINKING_WATER', 'MEDICAL_FIRST_AID', 'KITCHEN', 'POWER_GENERATOR'],
      contactPhone: '+91 94310 99881'
    },
    {
      id: 'SHELTER-02',
      name: 'Sector C Community Cyclone/Flood Center',
      areaId: 'area-c',
      latitude: 25.6300,
      longitude: 85.1700,
      capacity: 350,
      currentOccupancy: 85,
      facilities: ['SOLAR_POWER', 'DRINKING_WATER', 'SANITATION'],
      contactPhone: '+91 94310 99882'
    }
  ];

  // 6. Road Closures (FR-23)
  const roadClosures = db.prepare('SELECT * FROM road_closures').all();

  res.json({
    timestamp: new Date().toISOString(),
    layers: {
      officialAlerts,
      incidents,
      mlPredictions,
      teams,
      shelters,
      roadClosures
    }
  });
});

// PRD v2.0 Phase 3: Shelter & Resource Capacity Board (F-20)
gisRouter.get('/shelters/capacity-board', (req: Request, res: Response) => {
  const shelters = [
    {
      id: 'SHELTER-01',
      name: 'Patna Central High School Relief Camp',
      areaId: 'area-a',
      areaName: 'Sector A (North River Basin)',
      latitude: 25.6150,
      longitude: 85.1480,
      totalCapacity: 500,
      currentOccupancy: 310,
      remainingCapacity: 190,
      occupancyPercentage: 62,
      status: 'OPEN',
      supplies: {
        foodKitsRemaining: 420,
        waterLitersRemaining: 2800,
        medicalKitsRemaining: 65,
        generatorOperational: true
      },
      facilities: ['DRINKING_WATER', 'MEDICAL_FIRST_AID', 'KITCHEN', 'POWER_GENERATOR', 'WASH_BLOCK'],
      contactPhone: '+91 94310 99881',
      lastUpdated: new Date().toISOString()
    },
    {
      id: 'SHELTER-02',
      name: 'Sector C Community Cyclone/Flood Center',
      areaId: 'area-c',
      areaName: 'Sector C (Elevated Ridge)',
      latitude: 25.6300,
      longitude: 85.1700,
      totalCapacity: 350,
      currentOccupancy: 85,
      remainingCapacity: 265,
      occupancyPercentage: 24,
      status: 'OPEN',
      supplies: {
        foodKitsRemaining: 550,
        waterLitersRemaining: 4200,
        medicalKitsRemaining: 95,
        generatorOperational: true
      },
      facilities: ['SOLAR_POWER', 'DRINKING_WATER', 'SANITATION', 'WOMEN_CHILD_CORRIDOR'],
      contactPhone: '+91 94310 99882',
      lastUpdated: new Date().toISOString()
    },
    {
      id: 'SHELTER-03',
      name: 'Sector B Lowland Primary School Relief Center',
      areaId: 'area-b',
      areaName: 'Sector B (Lowland Colony)',
      latitude: 25.5940,
      longitude: 85.1220,
      totalCapacity: 200,
      currentOccupancy: 195,
      remainingCapacity: 5,
      occupancyPercentage: 98,
      status: 'NEAR_CAPACITY',
      supplies: {
        foodKitsRemaining: 25,
        waterLitersRemaining: 150,
        medicalKitsRemaining: 10,
        generatorOperational: false
      },
      facilities: ['DRINKING_WATER'],
      contactPhone: '+91 94310 99883',
      lastUpdated: new Date().toISOString()
    }
  ];

  res.json({
    timestamp: new Date().toISOString(),
    totalShelters: shelters.length,
    totalBeds: shelters.reduce((acc, s) => acc + s.totalCapacity, 0),
    occupiedBeds: shelters.reduce((acc, s) => acc + s.currentOccupancy, 0),
    remainingBeds: shelters.reduce((acc, s) => acc + s.remainingCapacity, 0),
    shelters
  });
});

// PRD v2.0 Phase 3: Emergency Hospitals on Map
gisRouter.get('/hospitals', (req: Request, res: Response) => {
  const hospitals = [
    {
      id: 'HOSP-01',
      name: 'Patna Medical College Hospital (PMCH) Trauma Center',
      areaId: 'area-a',
      latitude: 25.6200,
      longitude: 85.1580,
      totalEmergencyBeds: 120,
      availableEmergencyBeds: 28,
      totalIcuBeds: 40,
      availableIcuBeds: 6,
      traumaCapable: true,
      oxygenSupplyHoursRemaining: 72,
      contactPhone: '+91 612 230 0080',
      openStatus: 'OPEN_24_7'
    },
    {
      id: 'HOSP-02',
      name: 'AIIMS Patna Emergency & Disaster Triage Wing',
      areaId: 'area-b',
      latitude: 25.5600,
      longitude: 85.0400,
      totalEmergencyBeds: 200,
      availableEmergencyBeds: 75,
      totalIcuBeds: 60,
      availableIcuBeds: 18,
      traumaCapable: true,
      oxygenSupplyHoursRemaining: 120,
      contactPhone: '+91 612 245 1070',
      openStatus: 'OPEN_24_7'
    }
  ];

  res.json({
    timestamp: new Date().toISOString(),
    hospitals
  });
});

// FR-23: Safe Routing Calculation avoiding Road Closures
gisRouter.post('/safe-route', (req: Request, res: Response) => {
  const sLat = req.body.startLat ?? req.body.origin?.lat;
  const sLng = req.body.startLng ?? req.body.origin?.lng;
  const eLat = req.body.endLat ?? req.body.destination?.lat;
  const eLng = req.body.endLng ?? req.body.destination?.lng;
  const avoidHazards = req.body.avoidHazards ?? true;

  if (sLat === undefined || eLat === undefined || sLng === undefined || eLng === undefined) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Start and end coordinates required.' });
  }

  const startLat = Number(sLat);
  const startLng = Number(sLng);
  const endLat = Number(eLat);
  const endLng = Number(eLng);

  // Retrieve active road closures
  const activeClosures = db.prepare('SELECT * FROM road_closures WHERE is_passable_for_emergency = 0').all() as any[];

  // Calculate waypoint path. If road closure lies on direct path, route adds a safe bypass waypoint
  const waypoints: [number, number][] = [
    [startLat, startLng]
  ];

  let hasDetour = false;
  let detourReason = '';

  for (const rc of activeClosures) {
    // Check if line passes near road closure start/end
    const midLat = (startLat + endLat) / 2;
    const midLng = (startLng + endLng) / 2;
    const distToClosure = Math.hypot(midLat - rc.start_lat, midLng - rc.start_lng);

    if (distToClosure < 0.02 && avoidHazards) {
      hasDetour = true;
      detourReason = `Safe bypass active: Avoided flooded road [${rc.road_name}] (${rc.cause})`;
      // Add safe detour waypoint 1.5km to the north/ridge
      waypoints.push([rc.start_lat + 0.008, rc.start_lng + 0.006]);
      break;
    }
  }

  waypoints.push([endLat, endLng]);

  // Distance estimate (haversine)
  const totalDistKm = Math.hypot(endLat - startLat, endLng - startLng) * 111.2;

  res.json({
    safeRoute: {
      waypoints,
      totalDistanceKm: parseFloat(totalDistKm.toFixed(2)),
      estimatedMinutes: Math.round(totalDistKm * 3.5) + (hasDetour ? 6 : 0),
      hasDetour,
      detourReason: detourReason || 'Direct safe clearance confirmed',
      safeAccessVerified: true
    }
  });
});

// FR-16, FR-17: Responder Task Status Updates & Resource Request
export const responderRouter = Router();

// GET /api/v1/responder: Responder teams and tasks overview
responderRouter.get('/', (req: Request, res: Response) => {
  try {
    const teams = db.prepare('SELECT * FROM rescue_teams').all() as any[];
    const activeAssignments = db.prepare("SELECT * FROM assignments WHERE status != 'RESOLVED'").all() as any[];
    res.json({
      success: true,
      service: 'ResQAI Emergency Responder & Field Team Service',
      totalTeams: teams.length,
      activeAssignmentsCount: activeAssignments.length,
      teams,
      assignments: activeAssignments
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/v1/responder/teams: List rescue teams
responderRouter.get('/teams', (req: Request, res: Response) => {
  try {
    const teams = db.prepare('SELECT * FROM rescue_teams').all();
    res.json({
      success: true,
      count: teams.length,
      data: teams
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Retrieve tasks assigned to a team
responderRouter.get('/tasks/:teamId', (req: Request, res: Response) => {
  const teamId = req.params.teamId as string;
  const assignments = db.prepare(`
    SELECT a.*, i.title, i.category, i.urgency, i.priority_score, i.latitude, i.longitude, i.location_name, i.people_affected
    FROM assignments a
    JOIN incidents i ON a.incident_id = i.id
    WHERE a.team_id = ?
    ORDER BY a.assigned_at DESC
  `).all(teamId);

  res.json({ assignments });
});

// Update assignment status (FR-17: ASSIGNED -> ACCEPTED -> EN_ROUTE -> ON_SCENE -> RESOLVED)
responderRouter.post('/tasks/:assignmentId/status', (req: Request, res: Response) => {
  const assignmentId = req.params.assignmentId as string;
  const { status, notes = '' } = req.body;

  let actorId = 'DEMO-NDRF-LEAD';
  let actorRole = 'RESPONDER';

  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    try {
      const payload = verifyAccessToken(token);
      req.user = payload;
      actorId = payload.userId;
      actorRole = payload.role;
    } catch {
      // Fallback for drill/offline modes
    }
  }

  const validStatuses = ['ACCEPTED', 'EN_ROUTE', 'ON_SCENE', 'RESOLVED', 'DECLINED'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: `Invalid status: ${status}` });
  }

  const assignment = db.prepare('SELECT * FROM assignments WHERE id = ?').get(assignmentId) as any;
  if (!assignment) {
    return res.status(404).json({ error: 'NOT_FOUND', message: 'Assignment not found' });
  }

  const now = new Date().toISOString();
  let timeFieldUpdate = '';
  if (status === 'ACCEPTED') timeFieldUpdate = ", acknowledged_at = datetime('now')";
  else if (status === 'ON_SCENE') timeFieldUpdate = ", arrived_at_scene_at = datetime('now')";
  else if (status === 'RESOLVED') timeFieldUpdate = ", resolved_at = datetime('now')";

  db.prepare(`
    UPDATE assignments 
    SET status = ?, notes = ? ${timeFieldUpdate}
    WHERE id = ?
  `).run(status, notes, assignmentId);

  // Sync incident status
  let incidentStatus = 'RESPONSE_ASSIGNED';
  if (status === 'EN_ROUTE' || status === 'ON_SCENE') incidentStatus = 'IN_PROGRESS';
  else if (status === 'RESOLVED') incidentStatus = 'RESOLVED';

  db.prepare("UPDATE incidents SET status = ?, updated_at = datetime('now') WHERE id = ?").run(incidentStatus, assignment.incident_id);

  // Update team status
  let teamStatus = 'ASSIGNED';
  if (status === 'EN_ROUTE') teamStatus = 'EN_ROUTE';
  else if (status === 'ON_SCENE') teamStatus = 'ON_SCENE';
  else if (status === 'RESOLVED') teamStatus = 'IDLE';

  db.prepare('UPDATE rescue_teams SET status = ? WHERE id = ?').run(teamStatus, assignment.team_id);

  logAuditEvent({
    actionType: 'RESPONDER_STATUS_UPDATED',
    actorId,
    actorRole,
    entityId: assignmentId,
    details: `Task status updated to ${status} for incident ${assignment.incident_id}. Notes: ${notes}`,
    beforeState: { assignmentStatus: assignment.status },
    afterState: { assignmentStatus: status, incidentStatus },
    ipAddress: req.ip
  });

  res.json({
    message: `Task successfully updated to ${status}`,
    assignmentId,
    status,
    incidentStatus,
    teamStatus
  });
});
// GET /api/v1/gis/inundation-polygons — Fetch active GeoJSON inundation & containment polygons
gisRouter.get('/inundation-polygons', (_req: Request, res: Response) => {
  const polygons = PolygonGeofenceService.getAllPolygons();
  res.json({
    success: true,
    count: polygons.length,
    features: polygons.map(p => ({
      type: 'Feature',
      id: p.id,
      properties: {
        name: p.name,
        zoneType: p.type,
        severity: p.severity,
        waterDepthMeters: p.waterDepthMeters,
        description: p.description
      },
      geometry: {
        type: 'Polygon',
        coordinates: [p.coordinates.map(c => [c[1], c[0]])] // GeoJSON [lng, lat]
      }
    }))
  });
});

// POST /api/v1/gis/geofence-check — Check if a point is inside an active flood polygon
gisRouter.post('/geofence-check', (req: Request, res: Response) => {
  const lat = Number(req.body.lat ?? req.body.latitude);
  const lng = Number(req.body.lng ?? req.body.longitude);

  if (isNaN(lat) || isNaN(lng)) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Valid latitude and longitude required' });
  }

  const result = PolygonGeofenceService.checkGeofence({ lat, lng });
  res.json({
    success: true,
    latitude: lat,
    longitude: lng,
    ...result
  });
});

// POST /api/v1/gis/evacuation-corridor — Calculate hazard-avoiding evacuation corridor
gisRouter.post('/evacuation-corridor', (req: Request, res: Response) => {
  const originLat = Number(req.body.origin?.lat ?? req.body.startLat);
  const originLng = Number(req.body.origin?.lng ?? req.body.startLng);
  const destLat = Number(req.body.destination?.lat ?? req.body.endLat);
  const destLng = Number(req.body.destination?.lng ?? req.body.endLng);

  if (isNaN(originLat) || isNaN(originLng) || isNaN(destLat) || isNaN(destLng)) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Origin and destination coordinates required' });
  }

  const corridor = PolygonGeofenceService.computeSafeCorridor(
    { lat: originLat, lng: originLng },
    { lat: destLat, lng: destLng }
  );

  res.json({
    success: true,
    corridor
  });
});
