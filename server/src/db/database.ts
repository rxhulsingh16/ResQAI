import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';
import { hash, Algorithm } from '@node-rs/argon2';
import { ensurePrdV3Schema } from './prdV3Schema';

const DB_DIR = path.resolve(__dirname, '../../data');
if (!fs.existsSync(DB_DIR)) {
  fs.mkdirSync(DB_DIR, { recursive: true });
}

const DB_PATH = process.env.NODE_ENV === 'test' 
  ? ':memory:' 
  : path.join(DB_DIR, 'resqai.db');

export const db = new Database(DB_PATH, { timeout: 10000 });
try {
  db.pragma('busy_timeout = 10000');
  db.pragma('journal_mode = WAL');
} catch (_) {}
db.pragma('foreign_keys = ON');

export async function initDatabase() {
  let schemaPath = path.resolve(__dirname, 'schema.sql');
  if (!fs.existsSync(schemaPath)) {
    schemaPath = path.resolve(__dirname, '../../src/db/schema.sql');
  }
  const schemaSql = fs.readFileSync(schemaPath, 'utf-8');
  db.exec(schemaSql);

  // PRD v2.0 column migrations
  ensurePrdV2Columns();
  ensurePrdV3Schema();

  // Check if seed users exist
  const countStmt = db.prepare('SELECT count(*) as count FROM users');
  const userCount = (countStmt.get() as { count: number }).count;

  if (userCount === 0) {
    await seedInitialData();
  } else {
    // Ensure resource alerts exist if newly added
    const alertCountStmt = db.prepare('SELECT count(*) as count FROM resource_alerts');
    const alertCount = (alertCountStmt.get() as { count: number }).count;
    if (alertCount === 0) {
      seedResourceAlerts();
    }

    const ngoCountStmt = db.prepare('SELECT count(*) as count FROM ngos');
    const ngoCount = (ngoCountStmt.get() as { count: number }).count;
    if (ngoCount === 0) {
      seedNGOsAndCampaigns();
    }

    const caseCountStmt = db.prepare('SELECT count(*) as count FROM person_cases');
    const caseCount = (caseCountStmt.get() as { count: number }).count;
    if (caseCount === 0) {
      seedPhase7Data();
    }

    const teamCountStmt = db.prepare('SELECT count(*) as count FROM rescue_teams');
    const teamCount = (teamCountStmt.get() as { count: number }).count;
    if (teamCount === 0) {
      db.prepare(`
        INSERT OR IGNORE INTO rescue_teams (id, name, type, status, latitude, longitude, capacity, contact_number, jurisdiction_area)
        VALUES 
          ('TEAM-NDRF-9A', 'NDRF Battalion 9 Team Bravo', 'NDRF', 'IDLE', 25.6110, 85.1410, 25, '+919431011221', 'area-a'),
          ('TEAM-SDRF-1', 'Bihar SDRF Quick Response Unit', 'SDRF', 'IDLE', 25.5920, 85.1210, 15, '+919431011222', 'area-b')
      `).run();
    }
  }
}

export function ensurePrdV2Columns() {
  const tableInfo = db.prepare('PRAGMA table_info(users)').all() as { name: string }[];
  const existingCols = new Set(tableInfo.map(c => c.name));

  const colsToAdd: [string, string][] = [
    ['approval_status', "TEXT DEFAULT 'APPROVED'"],
    ['registration_number', 'TEXT'],
    ['legal_name', 'TEXT'],
    ['representative_name', 'TEXT'],
    ['service_districts', 'TEXT'],
    ['bank_account_details', 'TEXT'],
    ['department', 'TEXT'],
    ['designation', 'TEXT'],
    ['employee_id', 'TEXT'],
    ['skills_json', 'TEXT'],
    ['service_radius_km', 'REAL'],
    ['safety_briefing_accepted', 'INTEGER DEFAULT 0'],
    ['failed_login_attempts', 'INTEGER DEFAULT 0'],
    ['locked_until', 'TEXT'],
    ['app_pin_hash', 'TEXT'],
    ['training_quiz_passed', 'INTEGER DEFAULT 0']
  ];

  for (const [colName, colDef] of colsToAdd) {
    if (!existingCols.has(colName)) {
      try {
        db.exec(`ALTER TABLE users ADD COLUMN ${colName} ${colDef}`);
      } catch (_) {}
    }
  }

  // Ensure PRD v2.0 Phase 2 columns for incident_reports
  const reportCols = db.prepare('PRAGMA table_info(incident_reports)').all() as { name: string }[];
  const existingReportCols = new Set(reportCols.map(c => c.name));
  const reportColsToAdd: [string, string][] = [
    ['description_original', 'TEXT'],
    ['description_translated', 'TEXT'],
    ['needs_json', "TEXT DEFAULT '[]'"],
    ['voice_note_url', 'TEXT'],
    ['is_repeated_source', 'INTEGER DEFAULT 0'],
    ['is_flagged_spam', 'INTEGER DEFAULT 0'],
    ['retention_masked', 'INTEGER DEFAULT 0']
  ];

  for (const [colName, colDef] of reportColsToAdd) {
    if (!existingReportCols.has(colName)) {
      try {
        db.exec(`ALTER TABLE incident_reports ADD COLUMN ${colName} ${colDef}`);
      } catch (_) {}
    }
  }

  // Ensure PRD v2.0 Phase 3 columns for incidents (Escalation & Badge)
  const incidentCols = db.prepare('PRAGMA table_info(incidents)').all() as { name: string }[];
  const existingIncidentCols = new Set(incidentCols.map(c => c.name));
  const incidentColsToAdd: [string, string][] = [
    ['escalated_to_supervisor', 'INTEGER DEFAULT 0'],
    ['escalation_badge', 'TEXT'],
    ['escalated_at', 'TEXT'],
    ['escalation_timeout_minutes', 'INTEGER DEFAULT 15']
  ];

  for (const [colName, colDef] of incidentColsToAdd) {
    if (!existingIncidentCols.has(colName)) {
      try {
        db.exec(`ALTER TABLE incidents ADD COLUMN ${colName} ${colDef}`);
      } catch (_) {}
    }
  }

  // Create incident status history table for Phase 3 audit
  db.exec(`
    CREATE TABLE IF NOT EXISTS incident_status_history (
      id TEXT PRIMARY KEY,
      incident_id TEXT NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
      from_status TEXT,
      to_status TEXT NOT NULL,
      changed_by_user_id TEXT,
      changed_by_role TEXT,
      reason TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  // Ensure PRD v2.0 Phase 4 columns for official_alerts
  const alertCols = db.prepare('PRAGMA table_info(official_alerts)').all() as { name: string }[];
  const existingAlertCols = new Set(alertCols.map(c => c.name));
  const alertColsToAdd: [string, string][] = [
    ['drafted_by_officer_id', 'TEXT'],
    ['approved_by_officer_id', 'TEXT'],
    ['status', "TEXT DEFAULT 'ACTIVE'"],
    ['action_to_take', 'TEXT'],
    ['nearest_shelter', 'TEXT'],
    ['fetch_time', 'TEXT'],
    ['is_paused', 'INTEGER DEFAULT 0']
  ];

  for (const [colName, colDef] of alertColsToAdd) {
    if (!existingAlertCols.has(colName)) {
      try {
        db.exec(`ALTER TABLE official_alerts ADD COLUMN ${colName} ${colDef}`);
      } catch (_) {}
    }
  }

  // Create alert_deliveries table for tracking push & SMS fallback delivery receipts
  db.exec(`
    CREATE TABLE IF NOT EXISTS alert_deliveries (
      id TEXT PRIMARY KEY,
      alert_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      channel TEXT NOT NULL CHECK(channel IN ('PUSH', 'SMS', 'IN_APP')),
      status TEXT NOT NULL CHECK(status IN ('SENT', 'DELIVERED', 'FAILED', 'FALLBACK_SMS_TRIGGERED')),
      recipient_phone TEXT,
      matched_saved_place_id TEXT,
      delivered_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  // Ensure PRD v2.0 Phase 5 & 6 Tables
  db.exec(`
    CREATE TABLE IF NOT EXISTS damage_claims (
      id TEXT PRIMARY KEY,
      claimant_id TEXT NOT NULL REFERENCES users(id),
      disaster_id TEXT,
      loss_types TEXT NOT NULL,
      severity TEXT NOT NULL CHECK(severity IN ('MINOR', 'MODERATE', 'SEVERE', 'TOTAL_LOSS')),
      estimated_value REAL NOT NULL,
      household_size INTEGER NOT NULL,
      household_address TEXT NOT NULL,
      ward TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      incident_date TEXT NOT NULL,
      photo_urls TEXT DEFAULT '[]',
      video_urls TEXT DEFAULT '[]',
      documents_json TEXT DEFAULT '[]',
      evidence_strength_score REAL DEFAULT 0,
      evidence_suggestions TEXT DEFAULT '[]',
      status TEXT NOT NULL DEFAULT 'SUBMITTED' CHECK(status IN ('SUBMITTED', 'PENDING', 'ASSIGNED', 'UNDER_REVIEW', 'COMMUNITY_VERIFIED', 'OFFICIALLY_VERIFIED', 'PARTLY_VERIFIED', 'NOT_VERIFIABLE_NOW', 'NEEDS_FOLLOW_UP', 'AID_SANCTIONED', 'DELIVERED', 'APPEALED', 'REJECTED')),
      is_high_value INTEGER DEFAULT 0,
      assigned_volunteer_id TEXT REFERENCES users(id),
      assigned_officer_id TEXT REFERENCES users(id),
      is_offline_draft INTEGER DEFAULT 0,
      sync_status TEXT DEFAULT 'SYNCED',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS damage_verifications (
      id TEXT PRIMARY KEY,
      claim_id TEXT NOT NULL REFERENCES damage_claims(id) ON DELETE CASCADE,
      verifier_id TEXT NOT NULL REFERENCES users(id),
      verifier_role TEXT NOT NULL CHECK(verifier_role IN ('VOLUNTEER', 'GOVT_OFFICER', 'ADMIN')),
      conflict_of_interest_declared INTEGER NOT NULL DEFAULT 1,
      outcome TEXT NOT NULL CHECK(outcome IN ('VERIFIED', 'PARTLY_VERIFIED', 'NOT_VERIFIABLE_NOW', 'NEEDS_FOLLOW_UP')),
      truth_label TEXT NOT NULL CHECK(truth_label IN ('COMMUNITY_VERIFIED', 'OFFICIALLY_VERIFIED')),
      notes TEXT NOT NULL,
      photos_json TEXT DEFAULT '[]',
      gps_latitude REAL,
      gps_longitude REAL,
      gps_timestamp TEXT,
      verified_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS aid_plans (
      id TEXT PRIMARY KEY,
      claim_id TEXT NOT NULL REFERENCES damage_claims(id) ON DELETE CASCADE,
      sanctioning_officer_id TEXT NOT NULL REFERENCES users(id),
      aid_type TEXT NOT NULL CHECK(aid_type IN ('CASH_DBT', 'RELIEF_KIT', 'TEMPORARY_SHELTER', 'RECONSTRUCTION_REPAIR')),
      amount_paise INTEGER DEFAULT 0,
      items_description TEXT,
      delivery_status TEXT NOT NULL DEFAULT 'PENDING_DELIVERY' CHECK(delivery_status IN ('PENDING_DELIVERY', 'DELIVERED')),
      delivery_proof_type TEXT CHECK(delivery_proof_type IN ('RECEIVER_OTP', 'SIGNATURE_PLUS_PHOTO', NULL)),
      delivery_proof_url TEXT,
      delivery_otp TEXT,
      delivery_otp_verified INTEGER DEFAULT 0,
      delivered_by_user_id TEXT,
      delivered_at TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS claim_appeals (
      id TEXT PRIMARY KEY,
      claim_id TEXT NOT NULL REFERENCES damage_claims(id) ON DELETE CASCADE,
      claimant_id TEXT NOT NULL REFERENCES users(id),
      original_decision_officer_id TEXT NOT NULL,
      appeal_reason TEXT NOT NULL,
      additional_evidence_urls TEXT DEFAULT '[]',
      appealed_to_officer_id TEXT NOT NULL,
      appeal_status TEXT NOT NULL DEFAULT 'PENDING_REVIEW' CHECK(appeal_status IN ('PENDING_REVIEW', 'UPHELD', 'OVERTURNED')),
      appeal_notes TEXT,
      resolved_at TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS volunteer_tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL CHECK(category IN ('RESCUE', 'FOOD_WATER', 'MEDICINE', 'SHELTER', 'DAMAGE_VERIFICATION')),
      area_id TEXT NOT NULL,
      ward TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      priority_score REAL DEFAULT 50,
      safety_level TEXT NOT NULL CHECK(safety_level IN ('SAFE', 'CAUTION', 'UNSAFE_TRAINED_ONLY')),
      status TEXT NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN', 'ASSIGNED', 'CHECKED_IN', 'COMPLETED', 'CANCELLED')),
      assigned_volunteer_id TEXT REFERENCES users(id),
      check_in_at TEXT,
      check_in_lat REAL,
      check_in_lng REAL,
      proof_url TEXT,
      completed_at TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS volunteer_impact_ledgers (
      id TEXT PRIMARY KEY,
      volunteer_id TEXT NOT NULL REFERENCES users(id),
      task_id TEXT REFERENCES volunteer_tasks(id),
      hours_logged REAL NOT NULL DEFAULT 0,
      items_delivered_count INTEGER DEFAULT 0,
      activity_type TEXT NOT NULL,
      area_name TEXT,
      verified_by_user_id TEXT,
      logged_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS ngo_expenses (
      id TEXT PRIMARY KEY,
      ngo_id TEXT NOT NULL REFERENCES ngos(id),
      campaign_id TEXT REFERENCES campaigns(id),
      category TEXT NOT NULL CHECK(category IN ('FOOD_RATIONS', 'MEDICAL_SUPPLIES', 'SHELTER_MATERIALS', 'TRANSPORT', 'EQUIPMENT', 'OTHER')),
      amount_paise INTEGER NOT NULL,
      vendor_name TEXT NOT NULL,
      expense_date TEXT NOT NULL,
      area_id TEXT,
      receipt_url TEXT,
      is_unsupported INTEGER DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'APPROVED' CHECK(status IN ('APPROVED', 'UNSUPPORTED', 'Unsupported', 'FLAGGED')),
      approver_id TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS ngo_coverage_areas (
      id TEXT PRIMARY KEY,
      ngo_id TEXT NOT NULL REFERENCES ngos(id),
      area_id TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('HELPED', 'IN_PROGRESS', 'NOT_YET_HELPED')),
      people_reached INTEGER DEFAULT 0,
      supplies_delivered_json TEXT DEFAULT '[]',
      proof_urls_json TEXT DEFAULT '[]',
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    -- Phase 7: Government Command & Connect-and-Inform
    CREATE TABLE IF NOT EXISTS targeted_notices (
      id TEXT PRIMARY KEY,
      sender_officer_id TEXT NOT NULL REFERENCES users(id),
      target_group TEXT NOT NULL CHECK(target_group IN ('PUBLIC', 'RESCUE_TEAMS', 'DOCTORS_AND_HOSPITALS', 'NGOS', 'VOLUNTEERS', 'LOCAL_BODIES')),
      target_district TEXT NOT NULL,
      target_ward TEXT,
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      priority TEXT NOT NULL CHECK(priority IN ('NORMAL', 'URGENT', 'EMERGENCY')),
      total_targeted INTEGER DEFAULT 0,
      delivered_count INTEGER DEFAULT 0,
      failed_count INTEGER DEFAULT 0,
      sent_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS notice_deliveries (
      id TEXT PRIMARY KEY,
      notice_id TEXT NOT NULL REFERENCES targeted_notices(id) ON DELETE CASCADE,
      recipient_user_id TEXT NOT NULL REFERENCES users(id),
      recipient_name TEXT NOT NULL,
      recipient_role TEXT NOT NULL,
      recipient_district TEXT NOT NULL,
      recipient_phone TEXT,
      channel TEXT NOT NULL CHECK(channel IN ('PUSH', 'SMS', 'IN_APP')),
      status TEXT NOT NULL CHECK(status IN ('DELIVERED', 'FAILED')),
      delivered_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS government_sdrf_allocations (
      id TEXT PRIMARY KEY,
      district TEXT NOT NULL,
      fiscal_year TEXT NOT NULL,
      allocated_budget_paise INTEGER NOT NULL,
      released_budget_paise INTEGER NOT NULL,
      spent_budget_paise INTEGER NOT NULL DEFAULT 0,
      approved_by_officer_id TEXT NOT NULL REFERENCES users(id),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS government_datasets (
      id TEXT PRIMARY KEY,
      uploaded_by_officer_id TEXT NOT NULL REFERENCES users(id),
      dataset_name TEXT NOT NULL,
      district TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('PENDING_REVIEW', 'APPROVED', 'ROLLED_BACK')),
      total_rows INTEGER NOT NULL DEFAULT 0,
      duplicate_rows INTEGER NOT NULL DEFAULT 0,
      imported_records_json TEXT DEFAULT '[]',
      column_mapping_json TEXT DEFAULT '{}',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS inter_district_requests (
      id TEXT PRIMARY KEY,
      requesting_district TEXT NOT NULL,
      target_district TEXT NOT NULL,
      requesting_officer_id TEXT NOT NULL REFERENCES users(id),
      resource_type TEXT NOT NULL,
      requested_quantity INTEGER NOT NULL,
      urgency TEXT NOT NULL CHECK(urgency IN ('ROUTINE', 'HIGH', 'CRITICAL')),
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'APPROVED', 'DISPATCHED', 'REJECTED')),
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    -- Phase 8: Research Features (Silent Zones & Feedback)
    CREATE TABLE IF NOT EXISTS silent_zone_events (
      id TEXT PRIMARY KEY,
      area_id TEXT NOT NULL,
      ward TEXT,
      baseline_rate_per_hour REAL NOT NULL,
      observed_rate_per_hour REAL NOT NULL,
      drop_percentage REAL NOT NULL,
      hazard_status TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'SUSPECTED_BLACKOUT',
      flagged_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS ai_prediction_feedback (
      id TEXT PRIMARY KEY,
      prediction_id TEXT NOT NULL,
      responder_id TEXT NOT NULL REFERENCES users(id),
      is_accurate INTEGER NOT NULL,
      field_ground_truth TEXT NOT NULL,
      water_depth_observed_m REAL,
      feedback_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS shelters (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      area_id TEXT REFERENCES affected_areas(id),
      location_name TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      total_capacity INTEGER NOT NULL DEFAULT 500,
      occupied INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN', 'FULL', 'CLOSED')),
      facilities_json TEXT DEFAULT '["DRINKING_WATER", "MEDICAL_KIT", "CHARGING_STATION"]',
      contact_phone TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS ivr_call_logs (
      id TEXT PRIMARY KEY,
      call_sid TEXT,
      caller_phone TEXT NOT NULL,
      digits_pressed TEXT,
      selected_emergency TEXT,
      incident_id TEXT REFERENCES incidents(id),
      status TEXT NOT NULL DEFAULT 'COMPLETED',
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS voice_notes (
      id TEXT PRIMARY KEY,
      caller_phone TEXT NOT NULL,
      audio_url TEXT NOT NULL,
      duration_seconds INTEGER DEFAULT 0,
      language TEXT NOT NULL DEFAULT 'hi-IN',
      transcript_text TEXT NOT NULL,
      confidence_score REAL NOT NULL DEFAULT 0.90,
      parsed_category TEXT,
      parsed_location TEXT,
      parsed_urgency TEXT,
      parsed_people_count INTEGER DEFAULT 1,
      generated_incident_id TEXT REFERENCES incidents(id),
      status TEXT NOT NULL DEFAULT 'PROCESSED' CHECK(status IN ('RECORDED', 'TRANSCRIBED', 'PROCESSED', 'FAILED')),
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  try {
    const shelterCount = (db.prepare('SELECT count(*) as count FROM shelters').get() as any).count;
    if (shelterCount === 0) {
      db.prepare(`
        INSERT OR IGNORE INTO shelters (id, name, area_id, location_name, latitude, longitude, total_capacity, occupied, status)
        VALUES 
        ('SHELTER-A1', 'Sector A Community Relief Center', 'area-a', 'Govt Higher Secondary School, Ward 4', 25.6120, 85.1480, 450, 120, 'OPEN'),
        ('SHELTER-B1', 'Sector B Emergency Camp', 'area-b', 'Patna Stadium Hall 1', 25.6200, 85.1600, 800, 310, 'OPEN'),
        ('SHELTER-C1', 'Sector C Relief Enclave', 'area-c', 'Mithapur Polytechnic Ground', 25.5900, 85.1300, 300, 300, 'FULL')
      `).run();
    }
  } catch (_) {}
}

export function seedResourceAlerts() {
  const insertAlert = db.prepare(`
    INSERT OR IGNORE INTO resource_alerts (id, area_id, resource_type, alert_type, message)
    VALUES (@id, @area_id, @resource_type, @alert_type, @message)
  `);

  const seedAlerts = [
    {
      id: 'ALT-SHORT-001',
      area_id: 'area-b',
      resource_type: 'WATER',
      alert_type: 'CRITICAL_SHORTAGE',
      message: 'CRITICAL: Sector B Water coverage is 0% (0/800 L). 800 people at risk of dehydration. Immediate tanker dispatch required.'
    },
    {
      id: 'ALT-SHORT-002',
      area_id: 'area-a',
      resource_type: 'MEDICINE',
      alert_type: 'CRITICAL_SHORTAGE',
      message: 'URGENT: Sector A Medicine kits at 20% (60/300). Waterborne disease risk escalating.'
    },
    {
      id: 'ALT-OVER-001',
      area_id: 'area-a',
      resource_type: 'FOOD',
      alert_type: 'OVER_SUPPLY_WARNING',
      message: 'NOTICE: Sector A Food is 100% covered (500/500). Donor redirection active to prevent over-supply wastage.'
    }
  ];

  for (const alt of seedAlerts) {
    insertAlert.run(alt);
  }
}

export async function seedInitialData() {
  // Precompute Argon2id hashes
  const defaultPasswordHash = await hash('Password123!', { algorithm: Algorithm.Argon2id });
  const adminPasswordHash = await hash('AdminPassword123!', { algorithm: Algorithm.Argon2id });

  const insertUser = db.prepare(`
    INSERT OR IGNORE INTO users (id, name, email, phone, password_hash, role, jurisdiction_region_id, is_verified, two_factor_enabled, two_factor_secret)
    VALUES (@id, @name, @email, @phone, @password_hash, @role, @jurisdiction_region_id, @is_verified, @two_factor_enabled, @two_factor_secret)
  `);

  const seedUsers = [
    {
      id: 'USR-CITIZEN-01',
      name: 'Sunita Devi',
      email: 'sunita.citizen@resqai.org',
      phone: '+919876543210',
      password_hash: defaultPasswordHash,
      role: 'CITIZEN',
      jurisdiction_region_id: null,
      is_verified: 1,
      two_factor_enabled: 0,
      two_factor_secret: null
    },
    {
      id: 'USR-ADMIN-01',
      name: 'Rajesh Kumar (DDO)',
      email: 'admin@resqai.org',
      phone: '+919876543211',
      password_hash: adminPasswordHash,
      role: 'ADMIN',
      jurisdiction_region_id: null,
      is_verified: 1,
      two_factor_enabled: 1,
      two_factor_secret: 'RESQAI_ADMIN_2FA_SECRET'
    },
    {
      id: 'USR-GOVT-01',
      name: 'Inspector Meera Singh',
      email: 'meera.govt@resqai.org',
      phone: '+919876543212',
      password_hash: defaultPasswordHash,
      role: 'GOVT_OFFICER',
      jurisdiction_region_id: 'area-a',
      is_verified: 1,
      two_factor_enabled: 1,
      two_factor_secret: 'RESQAI_GOVT_2FA_SECRET'
    },
    {
      id: 'USR-RESPONDER-01',
      name: 'Team Lead Arjun',
      email: 'arjun.rescue@resqai.org',
      phone: '+919876543213',
      password_hash: defaultPasswordHash,
      role: 'RESPONDER',
      jurisdiction_region_id: 'area-a',
      is_verified: 1,
      two_factor_enabled: 0,
      two_factor_secret: null
    },
    {
      id: 'USR-NGO-01',
      name: 'Anita Sharma',
      email: 'anita.ngo@resqai.org',
      phone: '+919876543214',
      password_hash: defaultPasswordHash,
      role: 'NGO',
      jurisdiction_region_id: 'area-b',
      is_verified: 1,
      two_factor_enabled: 1,
      two_factor_secret: 'RESQAI_NGO_2FA_SECRET'
    },
    {
      id: 'USR-DONOR-01',
      name: 'Vikram Merchant',
      email: 'vikram.donor@resqai.org',
      phone: '+919876543215',
      password_hash: defaultPasswordHash,
      role: 'DONOR',
      jurisdiction_region_id: null,
      is_verified: 1,
      two_factor_enabled: 0,
      two_factor_secret: null
    },
    {
      id: 'USR-AUDITOR-01',
      name: 'Suresh Verma (CAG Auditor)',
      email: 'auditor@resqai.org',
      phone: '+919876543216',
      password_hash: defaultPasswordHash,
      role: 'AUDITOR',
      jurisdiction_region_id: null,
      is_verified: 1,
      two_factor_enabled: 0,
      two_factor_secret: null
    }
  ];

  for (const u of seedUsers) {
    insertUser.run(u);
  }

  // Seed Affected Areas (PRD E6 Worked Example: Area A, B, C)
  const insertArea = db.prepare(`
    INSERT OR IGNORE INTO affected_areas (id, name, district, state, latitude, longitude)
    VALUES (@id, @name, @district, @state, @latitude, @longitude)
  `);

  const areas = [
    { id: 'area-a', name: 'Sector A (North River Basin)', district: 'Patna', state: 'Bihar', latitude: 25.612, longitude: 85.144 },
    { id: 'area-b', name: 'Sector B (Lowland Colony)', district: 'Patna', state: 'Bihar', latitude: 25.594, longitude: 85.122 },
    { id: 'area-c', name: 'Sector C (Elevated Ridge)', district: 'Patna', state: 'Bihar', latitude: 25.628, longitude: 85.168 }
  ];

  for (const a of areas) {
    insertArea.run(a);
  }

  // Seed Rescue Teams (Required for Assignments and GIS Dispatch Flow)
  const insertTeam = db.prepare(`
    INSERT OR IGNORE INTO rescue_teams (id, name, type, status, latitude, longitude, capacity, contact_number, jurisdiction_area)
    VALUES (@id, @name, @type, @status, @latitude, @longitude, @capacity, @contact_number, @jurisdiction_area)
  `);

  const seedTeams = [
    {
      id: 'TEAM-NDRF-9A',
      name: 'NDRF Battalion 9 Team Bravo',
      type: 'NDRF',
      status: 'IDLE',
      latitude: 25.6110,
      longitude: 85.1410,
      capacity: 25,
      contact_number: '+919431011221',
      jurisdiction_area: 'area-a'
    },
    {
      id: 'TEAM-SDRF-1',
      name: 'Bihar SDRF Quick Response Unit',
      type: 'SDRF',
      status: 'IDLE',
      latitude: 25.5920,
      longitude: 85.1210,
      capacity: 15,
      contact_number: '+919431011222',
      jurisdiction_area: 'area-b'
    }
  ];

  for (const t of seedTeams) {
    insertTeam.run(t);
  }

  // Seed Area Needs (PRD E6 Worked Example)
  const insertNeed = db.prepare(`
    INSERT OR IGNORE INTO area_needs (id, area_id, resource_type, required_units, available_units, reserved_units, dispatched_units, delivered_units, pending_units, last_verified)
    VALUES (@id, @area_id, @resource_type, @required_units, @available_units, @reserved_units, @dispatched_units, @delivered_units, @pending_units, @last_verified)
  `);

  const needsList = [
    // Area A (Food 100%, Water 80%, Medicine 20%)
    { id: 'N-A-1', area_id: 'area-a', resource_type: 'FOOD', required_units: 500, available_units: 500, reserved_units: 50, dispatched_units: 350, delivered_units: 100, pending_units: 0, last_verified: '10 mins ago' },
    { id: 'N-A-2', area_id: 'area-a', resource_type: 'WATER', required_units: 1000, available_units: 800, reserved_units: 100, dispatched_units: 500, delivered_units: 200, pending_units: 200, last_verified: '15 mins ago' },
    { id: 'N-A-3', area_id: 'area-a', resource_type: 'MEDICINE', required_units: 300, available_units: 60, reserved_units: 10, dispatched_units: 30, delivered_units: 20, pending_units: 240, last_verified: '5 mins ago' },
    
    // Area B (Food 40%, Water 0%, Medicine 60%)
    { id: 'N-B-1', area_id: 'area-b', resource_type: 'FOOD', required_units: 400, available_units: 160, reserved_units: 20, dispatched_units: 100, delivered_units: 40, pending_units: 240, last_verified: '25 mins ago' },
    { id: 'N-B-2', area_id: 'area-b', resource_type: 'WATER', required_units: 800, available_units: 0, reserved_units: 0, dispatched_units: 0, delivered_units: 0, pending_units: 800, last_verified: '3 mins ago' },
    { id: 'N-B-3', area_id: 'area-b', resource_type: 'MEDICINE', required_units: 200, available_units: 120, reserved_units: 15, dispatched_units: 80, delivered_units: 25, pending_units: 80, last_verified: '18 mins ago' },

    // Area C (Food 95%, Water 90%, Medicine 90%)
    { id: 'N-C-1', area_id: 'area-c', resource_type: 'FOOD', required_units: 200, available_units: 190, reserved_units: 20, dispatched_units: 140, delivered_units: 30, pending_units: 10, last_verified: '1 hour ago' },
    { id: 'N-C-2', area_id: 'area-c', resource_type: 'WATER', required_units: 500, available_units: 450, reserved_units: 50, dispatched_units: 350, delivered_units: 50, pending_units: 50, last_verified: '45 mins ago' },
    { id: 'N-C-3', area_id: 'area-c', resource_type: 'MEDICINE', required_units: 100, available_units: 90, reserved_units: 10, dispatched_units: 70, delivered_units: 10, pending_units: 10, last_verified: '35 mins ago' }
  ];

  for (const n of needsList) {
    insertNeed.run(n);
  }

  // Seed Phase 4 Resource Alerts (FR-30 & E6 Worked Example)
  const insertAlert = db.prepare(`
    INSERT INTO resource_alerts (id, area_id, resource_type, alert_type, message)
    VALUES (@id, @area_id, @resource_type, @alert_type, @message)
  `);

  const seedAlerts = [
    {
      id: 'ALT-SHORT-001',
      area_id: 'area-b',
      resource_type: 'WATER',
      alert_type: 'CRITICAL_SHORTAGE',
      message: 'CRITICAL: Sector B Water coverage is 0% (0/800 L). 800 people at risk of dehydration. Immediate tanker dispatch required.'
    },
    {
      id: 'ALT-SHORT-002',
      area_id: 'area-a',
      resource_type: 'MEDICINE',
      alert_type: 'CRITICAL_SHORTAGE',
      message: 'URGENT: Sector A Medicine kits at 20% (60/300). Waterborne disease risk escalating.'
    },
    {
      id: 'ALT-OVER-001',
      area_id: 'area-a',
      resource_type: 'FOOD',
      alert_type: 'OVER_SUPPLY_WARNING',
      message: 'NOTICE: Sector A Food is 100% covered (500/500). Donor redirection active to prevent over-supply wastage.'
    }
  ];

  for (const alt of seedAlerts) {
    insertAlert.run(alt);
  }

  // Seed sample initial allocation
  db.prepare(`
    INSERT OR IGNORE INTO resource_allocations (id, area_id, resource_type, allocated_units, source_type, source_name, status, priority_score, score_factors_json, allocated_by_user_id)
    VALUES ('ALC-DEMO-001', 'area-a', 'FOOD', 50, 'CENTRAL_DEPOT', 'Patna State Emergency Buffer', 'RESERVED', 65.0, '{"shortageRatio":0.0,"threatToLife":50}', 'USR-ADMIN-01')
  `).run();

  // Seed Synthetic Drill Session (Part L Item 7)
  db.prepare(`
    INSERT OR IGNORE INTO drill_sessions (id, drill_name, scenario_type, status, is_watermarked_synthetic, total_synthetic_incidents)
    VALUES ('DRILL-2026-DEMO', 'Operation Jal-Suraksha 2026 (Simulated)', 'URBAN_FLASH_FLOOD', 'ACTIVE', 1, 12)
  `).run();

  // Seed Phase 6 NGOs, Campaigns, Ledger Disbursements & Webhooks
  seedNGOsAndCampaigns();

  // Seed Phase 7 Person Cases, Missing Persons & SMS Messages
  seedPhase7Data();

  // Log initial system audit log entry (FR-53)
  db.prepare(`
    INSERT OR IGNORE INTO audit_logs (id, action_type, actor_id, actor_role, entity_id, details)
    VALUES ('AUD-INIT-001', 'SYSTEM_INIT', 'SYSTEM', 'ADMIN', 'DB_INIT', 'ResQAI Database initialized with schema and Phase 0-7 seed records')
  `).run();
}

export function seedNGOsAndCampaigns() {
  const insertNGO = db.prepare(`
    INSERT OR IGNORE INTO ngos (
      id, name, darpan_id, fcra_number, fcra_valid_until, fcra_verified,
      tax_80g_number, tax_80g_valid_until, tax_80g_verified,
      authorized_rep_name, authorized_rep_email, authorized_rep_phone,
      kyc_status, kyc_notes, documents_json
    ) VALUES (
      @id, @name, @darpan_id, @fcra_number, @fcra_valid_until, @fcra_verified,
      @tax_80g_number, @tax_80g_valid_until, @tax_80g_verified,
      @authorized_rep_name, @authorized_rep_email, @authorized_rep_phone,
      @kyc_status, @kyc_notes, @documents_json
    )
  `);

  const seedNgos = [
    {
      id: 'NGO-RAPID-01',
      name: 'Rapid Relief Foundation India',
      darpan_id: 'DL/2019/0219482',
      fcra_number: 'FCRA-083920192',
      fcra_valid_until: '2027-12-31',
      fcra_verified: 1,
      tax_80g_number: 'AAATR1928DF20214',
      tax_80g_valid_until: '2028-03-31',
      tax_80g_verified: 1,
      authorized_rep_name: 'Dr. Arvind Swaminathan',
      authorized_rep_email: 'contact@rapidrelieffoundation.org',
      authorized_rep_phone: '+919811223344',
      kyc_status: 'APPROVED',
      kyc_notes: 'All Niti Aayog DARPAN, FCRA MHA and 80G tax certificates verified by DDO.',
      documents_json: JSON.stringify([
        { type: 'DARPAN_CERTIFICATE', url: '/docs/kyc/darpan_rapid.pdf', status: 'VERIFIED' },
        { type: 'FCRA_REGISTRATION', url: '/docs/kyc/fcra_rapid.pdf', status: 'VERIFIED' },
        { type: 'TAX_80G_CERTIFICATE', url: '/docs/kyc/80g_rapid.pdf', status: 'VERIFIED' }
      ])
    },
    {
      id: 'NGO-SEVA-02',
      name: 'Gramin Seva Samiti',
      darpan_id: 'UP/2021/0339182',
      fcra_number: null,
      fcra_valid_until: null,
      fcra_verified: 0,
      tax_80g_number: 'AABCG4412EF20221',
      tax_80g_valid_until: '2026-12-31',
      tax_80g_verified: 1,
      authorized_rep_name: 'Kavita Sharma',
      authorized_rep_email: 'info@graminseva.org',
      authorized_rep_phone: '+919877665544',
      kyc_status: 'APPROVED',
      kyc_notes: 'Domestic donations only. No FCRA clearance — foreign currency contributions restricted (FR-46).',
      documents_json: JSON.stringify([
        { type: 'DARPAN_CERTIFICATE', url: '/docs/kyc/darpan_seva.pdf', status: 'VERIFIED' },
        { type: 'TAX_80G_CERTIFICATE', url: '/docs/kyc/80g_seva.pdf', status: 'VERIFIED' }
      ])
    },
    {
      id: 'NGO-PENDING-03',
      name: 'Himalayan Hope Trust',
      darpan_id: 'UK/2024/099123',
      fcra_number: null,
      fcra_valid_until: null,
      fcra_verified: 0,
      tax_80g_number: 'PENDING_AUDIT',
      tax_80g_valid_until: null,
      tax_80g_verified: 0,
      authorized_rep_name: 'Mohit Rawat',
      authorized_rep_email: 'mohit@himalayanhope.org',
      authorized_rep_phone: '+919833445566',
      kyc_status: 'PENDING_VERIFICATION',
      kyc_notes: 'Under review by District Administration. Campaign publishing locked.',
      documents_json: JSON.stringify([
        { type: 'DARPAN_CERTIFICATE', url: '/docs/kyc/darpan_hope.pdf', status: 'UNDER_REVIEW' }
      ])
    }
  ];

  for (const ngo of seedNgos) {
    insertNGO.run(ngo);
  }

  // Seed Campaigns (FR-43, FR-44)
  const insertCampaign = db.prepare(`
    INSERT OR IGNORE INTO campaigns (
      id, ngo_id, title, description, category, area_id,
      target_amount_paise, received_amount_paise, committed_amount_paise, spent_amount_paise,
      status, approved_by, approved_at, beneficiary_count
    ) VALUES (
      @id, @ngo_id, @title, @description, @category, @area_id,
      @target_amount_paise, @received_amount_paise, @committed_amount_paise, @spent_amount_paise,
      @status, @approved_by, @approved_at, @beneficiary_count
    )
  `);

  const seedCampaigns = [
    {
      id: 'CMP-FLOOD-01',
      ngo_id: 'NGO-RAPID-01',
      title: 'Emergency Flood Relief Kits & Clean Water for Sector A',
      description: 'Providing 10,000L clean drinking water tankers, chlorine tablets, and dry ration ration kits to 1,200 families displaced by rising river levels in Sector A.',
      category: 'FLOOD',
      area_id: 'area-a',
      target_amount_paise: 100000000, // ₹10,00,000
      received_amount_paise: 65000000, // ₹6,50,000
      committed_amount_paise: 20000000, // ₹2,00,000
      spent_amount_paise: 35000000, // ₹3,50,000
      status: 'ACTIVE',
      approved_by: 'USR-ADMIN-01',
      approved_at: '2026-10-22T08:00:00Z',
      beneficiary_count: 1200
    },
    {
      id: 'CMP-MED-02',
      ngo_id: 'NGO-SEVA-02',
      title: 'Mobile Medical Van & Waterborne Infection Care for Sector B',
      description: 'Deploying a 4x4 mobile health clinic stocked with ORS, IV fluids, antivenom, and antibiotics for children and the elderly in hard-to-reach Sector B.',
      category: 'MEDICAL',
      area_id: 'area-b',
      target_amount_paise: 50000000, // ₹5,00,000
      received_amount_paise: 18000000, // ₹1,80,000
      committed_amount_paise: 5000000,  // ₹50,000
      spent_amount_paise: 9000000,   // ₹90,000
      status: 'ACTIVE',
      approved_by: 'USR-ADMIN-01',
      approved_at: '2026-10-22T09:30:00Z',
      beneficiary_count: 800
    },
    {
      id: 'CMP-DRAFT-03',
      ngo_id: 'NGO-RAPID-01',
      title: 'Temporary Elevated Shelter Reconstruction Initiative',
      description: 'Building 150 storm-resistant bamboo and waterproof tarpaulin shelters on elevated river embankment mounds.',
      category: 'SHELTER',
      area_id: 'area-c',
      target_amount_paise: 75000000, // ₹7,50,000
      received_amount_paise: 0,
      committed_amount_paise: 0,
      spent_amount_paise: 0,
      status: 'PENDING_APPROVAL', // FR-43: Hidden from public donor portal until Admin approves
      approved_by: null,
      approved_at: null,
      beneficiary_count: 450
    }
  ];

  for (const cmp of seedCampaigns) {
    insertCampaign.run(cmp);
  }

  // Seed Disbursements for Transparent Ledger (FR-44)
  const insertDisbursement = db.prepare(`
    INSERT OR IGNORE INTO campaign_disbursements (
      id, campaign_id, purpose, amount_paise, vendor_or_beneficiary, proof_receipt_url, disbursed_at, audited_by
    ) VALUES (
      @id, @campaign_id, @purpose, @amount_paise, @vendor_or_beneficiary, @proof_receipt_url, @disbursed_at, @audited_by
    )
  `);

  const seedDisbursements = [
    {
      id: 'DSB-001',
      campaign_id: 'CMP-FLOOD-01',
      purpose: 'Procurement of 10,000L bulk drinking water & 2,000 chlorine tablets',
      amount_paise: 20000000, // ₹2,00,000
      vendor_or_beneficiary: 'AquaPure Logistics & Water Services',
      proof_receipt_url: '/receipts/inv-aquapure-881.pdf',
      disbursed_at: '2026-10-22T10:15:00Z',
      audited_by: 'USR-ADMIN-01'
    },
    {
      id: 'DSB-002',
      campaign_id: 'CMP-FLOOD-01',
      purpose: '500 Heavy-duty Waterproof Tarpaulin Sheets & ground insulation mats',
      amount_paise: 15000000, // ₹1,50,000
      vendor_or_beneficiary: 'SafeShelter Disaster Supplies Ltd',
      proof_receipt_url: '/receipts/inv-safeshelter-904.pdf',
      disbursed_at: '2026-10-22T11:45:00Z',
      audited_by: 'USR-ADMIN-01'
    },
    {
      id: 'DSB-003',
      campaign_id: 'CMP-MED-02',
      purpose: 'ORS packets (5,000 units), Pediatric antibiotics, and waterborne disease test kits',
      amount_paise: 9000000, // ₹90,000
      vendor_or_beneficiary: 'MedLife Emergency Pharma Distributors',
      proof_receipt_url: '/receipts/inv-medlife-312.pdf',
      disbursed_at: '2026-10-22T12:30:00Z',
      audited_by: 'USR-ADMIN-01'
    }
  ];

  for (const dsb of seedDisbursements) {
    insertDisbursement.run(dsb);
  }

  // Seed sample initial donations (FR-44, FR-45)
  const insertDonation = db.prepare(`
    INSERT OR IGNORE INTO donations (
      id, campaign_id, donor_name, donor_email, donor_phone, donor_pan,
      is_indian_citizen, is_fcra_contribution, amount_paise, currency,
      razorpay_order_id, razorpay_payment_id, razorpay_signature, status,
      tax_80g_issued, tax_80g_receipt_no, created_at
    ) VALUES (
      @id, @campaign_id, @donor_name, @donor_email, @donor_phone, @donor_pan,
      @is_indian_citizen, @is_fcra_contribution, @amount_paise, @currency,
      @razorpay_order_id, @razorpay_payment_id, @razorpay_signature, @status,
      @tax_80g_issued, @tax_80g_receipt_no, @created_at
    )
  `);

  const seedDonations = [
    {
      id: 'DON-INIT-001',
      campaign_id: 'CMP-FLOOD-01',
      donor_name: 'Ananya Deshmukh',
      donor_email: 'ananya.d@example.com',
      donor_phone: '+919822334455',
      donor_pan: 'ABCDE1234F',
      is_indian_citizen: 1,
      is_fcra_contribution: 0,
      amount_paise: 250000, // ₹2,500
      currency: 'INR',
      razorpay_order_id: 'order_test_init_001',
      razorpay_payment_id: 'pay_test_init_001',
      razorpay_signature: 'sig_mock_verified_001',
      status: 'PAID',
      tax_80g_issued: 1,
      tax_80g_receipt_no: '80G-2026-0001',
      created_at: '2026-10-22T09:00:00Z'
    },
    {
      id: 'DON-INIT-002',
      campaign_id: 'CMP-MED-02',
      donor_name: 'Vikramaditya Roy',
      donor_email: 'v.roy@example.com',
      donor_phone: '+919811002233',
      donor_pan: 'FGHIJ5678K',
      is_indian_citizen: 1,
      is_fcra_contribution: 0,
      amount_paise: 500000, // ₹5,000
      currency: 'INR',
      razorpay_order_id: 'order_test_init_002',
      razorpay_payment_id: 'pay_test_init_002',
      razorpay_signature: 'sig_mock_verified_002',
      status: 'PAID',
      tax_80g_issued: 1,
      tax_80g_receipt_no: '80G-2026-0002',
      created_at: '2026-10-22T10:00:00Z'
    }
  ];

  for (const don of seedDonations) {
    insertDonation.run(don);
  }
}

export function seedPhase7Data() {
  // 1. Seed Person Cases (FR-38, FR-39, FR-40)
  const insertCase = db.prepare(`
    INSERT OR IGNORE INTO person_cases (
      id, household_head_name, contact_phone, area_id, shelter_id,
      household_size, vulnerability_flags_json, needs_summary,
      entitlement_ration_kits, entitlement_water_litres, entitlement_medical_kits,
      received_ration_kits, received_water_litres, received_medical_kits,
      caseworker_id, caseworker_notes, dpdp_consent_captured, status
    ) VALUES (
      @id, @household_head_name, @contact_phone, @area_id, @shelter_id,
      @household_size, @vulnerability_flags_json, @needs_summary,
      @entitlement_ration_kits, @entitlement_water_litres, @entitlement_medical_kits,
      @received_ration_kits, @received_water_litres, @received_medical_kits,
      @caseworker_id, @caseworker_notes, @dpdp_consent_captured, @status
    )
  `);

  const seedCases = [
    {
      id: 'CASE-2026-001',
      household_head_name: 'Rameshwar Paswan',
      contact_phone: '+919876543210',
      area_id: 'area-a',
      shelter_id: 'SHELTER-A1',
      household_size: 6,
      vulnerability_flags_json: JSON.stringify(['ELDERLY', 'INFANT']),
      needs_summary: 'Displaced by embankment breach; needs clean infant formula and dry rations.',
      entitlement_ration_kits: 2,
      entitlement_water_litres: 40,
      entitlement_medical_kits: 1,
      received_ration_kits: 1,
      received_water_litres: 20,
      received_medical_kits: 0,
      caseworker_id: 'USR-ADMIN-01',
      caseworker_notes: 'Family sheltered at Government Primary School Ward 2. 1 elder with mobility impairment.',
      dpdp_consent_captured: 1,
      status: 'IN_ASSISTANCE'
    },
    {
      id: 'CASE-2026-002',
      household_head_name: 'Geeta Devi',
      contact_phone: '+919811223344',
      area_id: 'area-b',
      shelter_id: 'SHELTER-B1',
      household_size: 4,
      vulnerability_flags_json: JSON.stringify(['PREGNANT', 'DISABLED']),
      needs_summary: 'Third-trimester pregnancy; requires regular prenatal monitoring and clean hydration.',
      entitlement_ration_kits: 1,
      entitlement_water_litres: 20,
      entitlement_medical_kits: 2,
      received_ration_kits: 0,
      received_water_litres: 0,
      received_medical_kits: 0,
      caseworker_id: 'USR-ADMIN-01',
      caseworker_notes: 'Priority referral created for Mobile Health Clinic 2.',
      dpdp_consent_captured: 1,
      status: 'OPEN'
    },
    {
      id: 'CASE-2026-003',
      household_head_name: 'Rameshwar Paswan (Field Camp Report)',
      contact_phone: '+919876543210',
      area_id: 'area-a',
      shelter_id: 'SHELTER-A1',
      household_size: 6,
      vulnerability_flags_json: JSON.stringify(['ELDERLY']),
      needs_summary: 'Second registration at auxiliary gate.',
      entitlement_ration_kits: 1,
      entitlement_water_litres: 20,
      entitlement_medical_kits: 0,
      received_ration_kits: 0,
      received_water_litres: 0,
      received_medical_kits: 0,
      caseworker_id: 'USR-ADMIN-01',
      caseworker_notes: 'Duplicate record identified for auditable merging (FR-40).',
      dpdp_consent_captured: 1,
      status: 'OPEN'
    }
  ];

  for (const c of seedCases) {
    insertCase.run(c);
  }

  // 2. Seed Missing Persons with Child Protection Controls (FR-41)
  const insertMissing = db.prepare(`
    INSERT OR IGNORE INTO missing_person_records (
      id, full_name, age, gender, last_known_location, last_seen_time,
      reported_by_user_id, status, shelter_id, is_child, child_protection_consent_verified
    ) VALUES (
      @id, @full_name, @age, @gender, @last_known_location, @last_seen_time,
      @reported_by_user_id, @status, @shelter_id, @is_child, @child_protection_consent_verified
    )
  `);

  const seedMissing = [
    {
      id: 'MP-2026-001',
      full_name: 'Aarav Kumar',
      age: 9,
      gender: 'Male',
      last_known_location: 'Sector A Embankment, near primary school',
      last_seen_time: '2026-10-22 08:30:00',
      reported_by_user_id: 'USR-CITIZEN-01',
      status: 'SEARCHING',
      shelter_id: null,
      is_child: 1,
      child_protection_consent_verified: 1
    },
    {
      id: 'MP-2026-002',
      full_name: 'Bimla Devi',
      age: 72,
      gender: 'Female',
      last_known_location: 'Near Relief Camp 1, Danapur',
      last_seen_time: '2026-10-22 09:15:00',
      reported_by_user_id: 'USR-CITIZEN-01',
      status: 'AT_SHELTER',
      shelter_id: 'SHELTER-A1',
      is_child: 0,
      child_protection_consent_verified: 1
    }
  ];

  for (const mp of seedMissing) {
    insertMissing.run(mp);
  }

  // 3. Seed Inbound SMS Messages (FR-48, FR-50)
  const insertSms = db.prepare(`
    INSERT OR IGNORE INTO inbound_sms_messages (
      id, sender_phone, raw_message, parsed_category, parsed_location,
      parsed_urgency, parsed_people_count, parsed_needs, delivery_status
    ) VALUES (
      @id, @sender_phone, @raw_message, @parsed_category, @parsed_location,
      @parsed_urgency, @parsed_people_count, @parsed_needs, @delivery_status
    )
  `);

  const seedSms = [
    {
      id: 'SMS-2026-001',
      sender_phone: '+919876500112',
      raw_message: 'HELP FLOOD Sector A East Ward 4 5 people need water and boat urgently',
      parsed_category: 'FLOOD',
      parsed_location: 'Sector A East Ward 4',
      parsed_urgency: 'CRITICAL',
      parsed_people_count: 5,
      parsed_needs: 'water, boat',
      delivery_status: 'PROCESSED'
    },
    {
      id: 'SMS-2026-002',
      sender_phone: '+919811009988',
      raw_message: 'SOS MEDICAL Embankment Shelter 2 elder diabetic insulin needed',
      parsed_category: 'MEDICAL',
      parsed_location: 'Embankment Shelter 2',
      parsed_urgency: 'HIGH',
      parsed_people_count: 2,
      parsed_needs: 'insulin, medical',
      delivery_status: 'PROCESSED'
    }
  ];

  for (const s of seedSms) {
    insertSms.run(s);
  }
}


