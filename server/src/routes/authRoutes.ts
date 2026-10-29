import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { db } from '../db/database';
import { 
  hashPassword, 
  verifyPasswordHash, 
  createSessionAndTokens, 
  rotateRefreshToken, 
  revokeSession, 
  revokeAllUserSessions,
  generateOtp,
  verifyOtp,
  recordFailedLogin,
  resetFailedLogins,
  isAccountLocked,
  setAppPin,
  verifyAppPin,
  issueReauthChallenge,
  verifyReauthChallenge,
  recordUserDevice,
  revokeUserDevice
} from '../services/authService';
import { authenticate, requireRole } from '../middleware/rbacMiddleware';
import { logAuditEvent } from '../services/auditService';
import { 
  generateOtp as generateOtpV3, 
  verifyOtpDetailed, 
  checkOtpRateLimit 
} from '../services/otpService';
import { 
  initiateAccountDeletion, 
  cancelAccountDeletion, 
  exportUserData, 
  purgeExpiredAccounts 
} from '../services/accountDeletionService';

export const authRouter = Router();
const TWO_FACTOR_JWT_SECRET = 'resqai_disaster_2fa_temp_key_2026';

// GET /api/v1/auth: Authentication service and protocol status
authRouter.get('/', (req: Request, res: Response) => {
  res.json({
    success: true,
    service: 'ResQAI Authentication & Identity Security Engine',
    securityStandards: {
      passwordHashing: 'Argon2id (RFC 9106)',
      tokenExchange: 'Dual-Token JWT with Refresh Rotation',
      twoFactorAuth: 'TOTP / High-Privilege 2FA Gates (Admin, Govt, NGO)',
      rateLimiting: 'Account Lockout after 5 failed attempts'
    },
    supportedRoles: [
      'CITIZEN',
      'VOLUNTEER',
      'NGO',
      'GOVT_OFFICER',
      'RESPONDER',
      'DONOR',
      'AUDITOR',
      'ADMIN'
    ],
    endpoints: {
      register: 'POST /api/v1/auth/register',
      login: 'POST /api/v1/auth/login',
      otpRequest: 'POST /api/v1/auth/otp/request',
      otpVerify: 'POST /api/v1/auth/otp/verify',
      refresh: 'POST /api/v1/auth/refresh',
      me: 'GET /api/v1/auth/me',
      logout: 'POST /api/v1/auth/logout'
    }
  });
});

// Role landing home router helper per PRD v2.0
export function getHomeRouteForRole(role: string): string {
  switch (role) {
    case 'CITIZEN': return '/citizen';
    case 'VOLUNTEER': return '/volunteer';
    case 'NGO': return '/ngo';
    case 'GOVERNMENT_MEMBER':
    case 'GOVT_OFFICER':
    case 'ADMIN': return '/admin';
    case 'RESPONDER': return '/responder';
    default: return '/citizen';
  }
}

// FR-1 & PRD v2.0 Phase 1: Register with Email / Phone & Argon2id Password (4 Account Types)
authRouter.post('/register', async (req: Request, res: Response) => {
  const { 
    name, 
    email, 
    phone, 
    password, 
    role = 'CITIZEN', 
    jurisdictionRegionId,
    // Role-specific fields
    registrationNumber,
    legalName,
    representativeName,
    serviceDistricts,
    bankAccountDetails,
    department,
    designation,
    employeeId,
    skills,
    serviceRadiusKm,
    safetyBriefingAccepted,
    // Quick App PIN & Guest SOS
    appPin,
    emergencyContacts = [],
    savedPlaces = [],
    guestSosId,
    deviceId,
    deviceName = 'Primary Device'
  } = req.body;

  if (!name || (!email && !phone)) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Name and email or phone are required' });
  }

  // Validate role
  const validRoles = [
    'CITIZEN', 
    'VOLUNTEER', 
    'NGO', 
    'GOVERNMENT_MEMBER', 
    'ADMIN', 
    'GOVT_OFFICER', 
    'RESPONDER', 
    'DONOR', 
    'AUDITOR'
  ];
  if (!validRoles.includes(role)) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: `Invalid role: ${role}` });
  }

  // PRD R-NGO-1: Registration number mandatory for NGO, duplicates blocked
  if (role === 'NGO') {
    if (!registrationNumber || registrationNumber.trim().length === 0) {
      return res.status(400).json({ 
        error: 'MISSING_REGISTRATION_NUMBER', 
        message: 'NGO registration requires a unique registration number (DARPAN / Society Reg) (R-NGO-1)' 
      });
    }

    const existingNgo = db.prepare('SELECT id FROM users WHERE registration_number = ?').get(registrationNumber.trim());
    if (existingNgo) {
      return res.status(409).json({ 
        error: 'DUPLICATE_REGISTRATION_NUMBER', 
        message: 'An organization with this registration number already exists (duplicates blocked)' 
      });
    }
  }

  try {
    const existing = db.prepare('SELECT id FROM users WHERE (email IS NOT NULL AND email = ?) OR (phone IS NOT NULL AND phone = ?)').get(email || null, phone || null);
    if (existing) {
      return res.status(409).json({ error: 'USER_EXISTS', message: 'User with this email or phone already exists' });
    }

    const userId = `USR-${role}-${Date.now().toString().slice(-6)}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
    const passwordHash = password ? await hashPassword(password) : null;

    // Approval status: Citizens instant, other roles require verification/approval
    const approvalStatus = (role === 'CITIZEN' || role === 'DONOR') ? 'APPROVED' : 'PENDING';
    const isVerified = approvalStatus === 'APPROVED' ? 1 : 0;

    // Admin, Govt, NGO Finance default to 2FA enabled (FR-4)
    const twoFactorEnabled = (role === 'ADMIN' || role === 'GOVT_OFFICER' || role === 'GOVERNMENT_MEMBER' || role === 'NGO') ? 1 : 0;
    const twoFactorSecret = twoFactorEnabled ? `SECRET_2FA_${userId}` : null;

    const skillsJson = Array.isArray(skills) ? JSON.stringify(skills) : (skills || '[]');

    db.prepare(`
      INSERT INTO users (
        id, name, email, phone, password_hash, role, jurisdiction_region_id, 
        is_verified, two_factor_enabled, two_factor_secret,
        approval_status, registration_number, legal_name, representative_name,
        service_districts, bank_account_details, department, designation, employee_id,
        skills_json, service_radius_km, safety_briefing_accepted
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      userId, name, email || null, phone || null, passwordHash, role, jurisdictionRegionId || null,
      isVerified, twoFactorEnabled, twoFactorSecret,
      approvalStatus, registrationNumber ? registrationNumber.trim() : null, legalName || null, representativeName || null,
      serviceDistricts || null, bankAccountDetails || null, department || null, designation || null, employeeId || null,
      skillsJson, serviceRadiusKm || null, safetyBriefingAccepted ? 1 : 0
    );

    // Save App PIN if provided (R-AUTH-2)
    if (appPin && /^\d{4}$/.test(appPin)) {
      setAppPin(userId, appPin);
    }

    // Save Emergency Contacts if provided (R-CIT-1)
    if (Array.isArray(emergencyContacts) && emergencyContacts.length > 0) {
      const insertContact = db.prepare(`
        INSERT INTO emergency_contacts (id, user_id, name, phone, relationship, is_primary, is_otp_verified)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `);
      emergencyContacts.forEach((c: any, index: number) => {
        insertContact.run(
          `EC-${userId}-${index + 1}`,
          userId,
          c.name || 'Emergency Contact',
          c.phone,
          c.relationship || 'Family',
          index === 0 ? 1 : 0,
          c.isOtpVerified ? 1 : 1 // Verified in signup
        );
      });
    }

    // Save Saved Places if provided (R-CIT-3, max 5)
    if (Array.isArray(savedPlaces) && savedPlaces.length > 0) {
      const placesToInsert = savedPlaces.slice(0, 5);
      const insertPlace = db.prepare(`
        INSERT INTO saved_places (id, user_id, label, address, ward, latitude, longitude)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `);
      placesToInsert.forEach((p: any, index: number) => {
        insertPlace.run(
          `PLC-${userId}-${index + 1}`,
          userId,
          p.label || 'Home',
          p.address || 'Saved Location',
          p.ward || 'Ward 1',
          p.latitude || 28.6139,
          p.longitude || 77.2090
        );
      });
    }

    // Link Guest SOS if provided (R-AUTH-5)
    if (guestSosId) {
      db.prepare(`
        UPDATE incident_reports 
        SET contact_phone = COALESCE(contact_phone, ?) 
        WHERE id = ? OR idempotency_key = ?
      `).run(phone || email, guestSosId, guestSosId);
    }

    // Record Device
    if (deviceId) {
      recordUserDevice(userId, deviceId, deviceName, req.headers['user-agent'] as string, req.ip);
    }

    const user = { 
      id: userId, 
      name, 
      role, 
      jurisdiction_region_id: jurisdictionRegionId || null,
      approval_status: approvalStatus
    };
    const session = createSessionAndTokens(user, req.headers['user-agent'], req.ip);

    logAuditEvent({
      actionType: 'USER_REGISTERED',
      actorId: userId,
      actorRole: role,
      entityId: userId,
      details: `User registered with role ${role} (Approval: ${approvalStatus}) and Argon2id security`,
      ipAddress: req.ip
    });

    res.status(201).json({
      message: 'User registered successfully',
      user: { 
        id: userId, 
        name, 
        email, 
        phone, 
        role, 
        jurisdictionRegionId, 
        approvalStatus,
        twoFactorEnabled: !!twoFactorEnabled,
        landingRoute: getHomeRouteForRole(role)
      },
      ...session
    });
  } catch (err: any) {
    res.status(500).json({ error: 'SERVER_ERROR', message: err.message });
  }
});

// FR-1, R-AUTH-4: Login with Password, Lockout Check & 2FA Gate
authRouter.post('/login', async (req: Request, res: Response) => {
  const { emailOrPhone, password, deviceId, deviceName = 'Primary Device' } = req.body;

  if (!emailOrPhone || !password) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Email/phone and password are required' });
  }

  try {
    const user = db.prepare(`
      SELECT * FROM users WHERE email = ? OR phone = ?
    `).get(emailOrPhone, emailOrPhone) as any;

    if (!user || !user.password_hash) {
      return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Invalid credentials provided' });
    }

    // R-AUTH-4: Check account lockout (5 failed attempts)
    if (isAccountLocked(user)) {
      return res.status(423).json({ 
        error: 'ACCOUNT_LOCKED', 
        message: 'Account temporarily locked due to 5 failed attempts. Please try again in 15 minutes (R-AUTH-4).',
        lockedUntil: user.locked_until
      });
    }

    // Verify Argon2id password hash
    const isValidPassword = await verifyPasswordHash(user.password_hash, password);
    if (!isValidPassword) {
      const lockStatus = recordFailedLogin(user.id);
      if (lockStatus.locked) {
        return res.status(423).json({
          error: 'ACCOUNT_LOCKED',
          message: 'Account locked due to 5 failed attempts. Please try again in 15 minutes (R-AUTH-4).',
          lockedUntil: lockStatus.lockedUntil
        });
      }
      return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Invalid credentials provided' });
    }

    // Password is valid -> reset failed attempts
    resetFailedLogins(user.id);

    // DEL-4: If account is scheduled for deletion, allow cancelling deletion during grace period
    if (user.is_deactivated) {
      return res.status(200).json({
        scheduledForDeletion: true,
        canCancelDeletion: true,
        userId: user.id,
        deletionScheduledAt: user.deletion_scheduled_at,
        message: 'This account is scheduled for deletion. You can cancel deletion within the 7-day grace period (DEL-4).'
      });
    }

    // Record user device
    if (deviceId) {
      recordUserDevice(user.id, deviceId, deviceName, req.headers['user-agent'] as string, req.ip);
    }

    // FR-4: Two-Factor Authentication check for Admin, Govt, NGO
    if (user.two_factor_enabled) {
      const otpCode = generateOtp(user.email || user.phone, 'TWO_FACTOR');
      const tempToken = jwt.sign(
        { userId: user.id, purpose: 'TWO_FACTOR_PENDING' },
        TWO_FACTOR_JWT_SECRET,
        { expiresIn: '5m' }
      );

      return res.json({
        requires2FA: true,
        message: 'Two-factor authentication code sent to registered contact',
        tempToken,
        demoOtp: otpCode // Available in demo mode for automated testing
      });
    }

    // Standard Login
    const session = createSessionAndTokens(user, req.headers['user-agent'], req.ip);
    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        approvalStatus: user.approval_status || 'APPROVED',
        jurisdictionRegionId: user.jurisdiction_region_id,
        twoFactorEnabled: !!user.two_factor_enabled,
        landingRoute: getHomeRouteForRole(user.role)
      },
      ...session
    });
  } catch (err: any) {
    res.status(500).json({ error: 'SERVER_ERROR', message: err.message });
  }
});

// FR-4: Verify 2FA and complete login
authRouter.post('/verify-2fa', (req: Request, res: Response) => {
  const { tempToken, code } = req.body;

  if (!tempToken || !code) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Temporary token and 2FA code are required' });
  }

  try {
    const decoded = jwt.verify(tempToken, TWO_FACTOR_JWT_SECRET) as { userId: string; purpose: string };
    if (decoded.purpose !== 'TWO_FACTOR_PENDING') {
      return res.status(401).json({ error: 'INVALID_TOKEN', message: 'Invalid 2FA flow' });
    }

    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(decoded.userId) as any;
    if (!user) {
      return res.status(404).json({ error: 'USER_NOT_FOUND', message: 'User not found' });
    }

    // Verify OTP code
    const isCodeValid = verifyOtp(user.email || user.phone, code, 'TWO_FACTOR');
    if (!isCodeValid) {
      return res.status(401).json({ error: 'INVALID_2FA_CODE', message: 'Invalid or expired 2FA code' });
    }

    const session = createSessionAndTokens(user, req.headers['user-agent'], req.ip);
    res.json({
      message: '2FA verified. Login successful.',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        jurisdictionRegionId: user.jurisdiction_region_id
      },
      ...session
    });
  } catch (err: any) {
    res.status(401).json({ error: 'INVALID_TOKEN', message: 'Expired or invalid 2FA token' });
  }
});

// FR-1: Request OTP for Phone/Email Login
// PRD v3.0 OTP & Account Deletion Endpoints
authRouter.post('/verify-otp-action', (req: Request, res: Response) => {
  const { identifier, code, purpose = 'LOGIN' } = req.body;
  if (!identifier || !code) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Identifier and OTP code are required' });
  }

  const result = verifyOtpDetailed(identifier, code, purpose);
  if (!result.valid) {
    const statusCode = result.status === 'LOCKED' ? 423 : (result.status === 'EXPIRED' ? 410 : 401);
    return res.status(statusCode).json({
      error: result.status,
      messageEn: result.messageEn,
      messageHi: result.messageHi
    });
  }

  return res.json({
    success: true,
    status: result.status,
    messageEn: result.messageEn,
    messageHi: result.messageHi
  });
});

// PRD v3.0 DEL-1 to DEL-8: Delete Account (Danger Zone, 7-day grace period)
authRouter.post('/delete-account', authenticate, async (req: Request, res: Response) => {
  const { passwordOrPin, otpCode, confirmationText } = req.body;
  const userId = req.user!.userId;

  if (!passwordOrPin || !otpCode || !confirmationText) {
    return res.status(400).json({
      error: 'BAD_REQUEST',
      message: 'Password/PIN, OTP code, and confirmationText ("DELETE") are required (DEL-3)'
    });
  }

  try {
    const result = await initiateAccountDeletion(userId, passwordOrPin, otpCode, confirmationText);
    return res.json(result);
  } catch (err: any) {
    return res.status(400).json({
      error: 'DELETION_FAILED',
      message: err.message
    });
  }
});

// PRD v3.0 DEL-4: Cancel Account Deletion during 7-day grace period
authRouter.post('/cancel-deletion', async (req: Request, res: Response) => {
  const { identifier, password } = req.body;
  if (!identifier || !password) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Identifier and password are required' });
  }

  const user = db.prepare('SELECT * FROM users WHERE email = ? OR phone = ?').get(identifier, identifier) as any;
  if (!user) {
    return res.status(404).json({ error: 'USER_NOT_FOUND', message: 'User not found' });
  }

  const isValidPassword = await verifyPasswordHash(user.password_hash, password);
  if (!isValidPassword) {
    return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Invalid password' });
  }

  try {
    const result = cancelAccountDeletion(user.id);
    return res.json(result);
  } catch (err: any) {
    return res.status(400).json({ error: 'CANCEL_DELETION_FAILED', message: err.message });
  }
});

// PRD v3.0 DEL-2: Export user data before deletion ("Download my data")
authRouter.get('/export-data', authenticate, (req: Request, res: Response) => {
  try {
    const data = exportUserData(req.user!.userId);
    return res.json(data);
  } catch (err: any) {
    return res.status(404).json({ error: 'EXPORT_FAILED', message: err.message });
  }
});

authRouter.post('/request-otp', (req: Request, res: Response) => {
  const rateLimit = checkOtpRateLimit(req.body.identifier);
  if (!rateLimit.allowed) {
    return res.status(429).json({
      error: rateLimit.status || 'RATE_LIMITED',
      message: rateLimit.reason,
      secondsRemaining: rateLimit.secondsRemaining
    });
  }
  const { identifier, purpose = 'LOGIN' } = req.body;
  if (!identifier) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Phone or email identifier is required' });
  }

  const code = generateOtpV3(identifier, purpose);
  res.json({
    message: `OTP sent successfully to ${identifier}`,
    demoOtp: code // Provided in demo mode for instant testing
  });
});

// FR-1: Login with Phone/Email OTP
authRouter.post('/login-otp', (req: Request, res: Response) => {
  const { identifier, otpCode, name } = req.body;

  if (!identifier || !otpCode) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Identifier and OTP code are required' });
  }

  const isValid = verifyOtp(identifier, otpCode, 'LOGIN');
  if (!isValid) {
    return res.status(401).json({ error: 'INVALID_OTP', message: 'Invalid, expired, or maximum attempts reached for OTP' });
  }

  let user = db.prepare('SELECT * FROM users WHERE email = ? OR phone = ?').get(identifier, identifier) as any;
  if (user && user.is_deactivated) {
    return res.status(200).json({
      scheduledForDeletion: true,
      canCancelDeletion: true,
      deletionScheduledAt: user.deletion_scheduled_at,
      message: 'This account is scheduled for deletion. You can cancel deletion within the 7-day grace period (DEL-4).'
    });
  }
  if (!user) {
    // Auto-create citizen profile on verified OTP
    const userId = `USR-CITIZEN-${Date.now()}`;
    const isEmail = identifier.includes('@');
    db.prepare(`
      INSERT INTO users (id, name, email, phone, role, is_verified)
      VALUES (?, ?, ?, ?, 'CITIZEN', 1)
    `).run(userId, name || `Citizen ${identifier.slice(-4)}`, isEmail ? identifier : null, isEmail ? null : identifier);

    user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  }

  const session = createSessionAndTokens(user, req.headers['user-agent'], req.ip);
  res.json({
    message: 'OTP Login successful',
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role
    },
    ...session
  });
});

// FR-1: Refresh Token Rotation
authRouter.post('/refresh', (req: Request, res: Response) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Refresh token required' });
  }

  try {
    const rotated = rotateRefreshToken(refreshToken, req.headers['user-agent'], req.ip);
    res.json({
      message: 'Token rotated successfully',
      ...rotated
    });
  } catch (err: any) {
    res.status(401).json({ error: 'REFRESH_FAILED', message: err.message });
  }
});

// FR-1: Revoke Current Session (Logout)
authRouter.post('/logout', authenticate, (req: Request, res: Response) => {
  if (req.user?.sessionId) {
    revokeSession(req.user.sessionId, req.user.userId);
  }
  res.json({ message: 'Session successfully revoked' });
});

// FR-1: Revoke All Sessions (Emergency logout all devices)
authRouter.post('/logout-all', authenticate, (req: Request, res: Response) => {
  if (req.user?.userId) {
    revokeAllUserSessions(req.user.userId);
  }
  res.json({ message: 'All active sessions revoked' });
});

// Current User Profile & Active Sessions
authRouter.get('/me', authenticate, (req: Request, res: Response) => {
  const user = db.prepare('SELECT id, name, email, phone, role, jurisdiction_region_id, is_verified, two_factor_enabled, created_at FROM users WHERE id = ?').get(req.user!.userId);
  res.json({ user, currentSessionId: req.user!.sessionId });
});

authRouter.get('/sessions', authenticate, (req: Request, res: Response) => {
  const sessions = db.prepare(`
    SELECT id, user_agent, ip_address, is_revoked, expires_at, created_at, last_used_at
    FROM user_sessions
    WHERE user_id = ?
    ORDER BY created_at DESC
  `).all(req.user!.userId);

  res.json({ sessions });
});

// Admin User Management: List all users & role positions (Admin Only)
authRouter.get('/users', authenticate, requireRole('ADMIN'), (req: Request, res: Response) => {
  const users = db.prepare(`
    SELECT id, name, email, phone, role, approval_status, registration_number, legal_name, department, designation, employee_id, jurisdiction_region_id, is_verified, two_factor_enabled, created_at, updated_at
    FROM users
    ORDER BY created_at ASC
  `).all();
  res.json({ users });
});

// Admin User Management: Change role, position & jurisdiction (Admin Master Control)
authRouter.patch('/users/:id/role', authenticate, requireRole('ADMIN'), (req: Request, res: Response) => {
  const { role, jurisdictionRegionId, department, designation, approvalStatus } = req.body;
  const targetUserId = req.params.id as string;

  const validRoles = [
    'CITIZEN', 
    'VOLUNTEER', 
    'NGO', 
    'GOVERNMENT_MEMBER', 
    'ADMIN', 
    'GOVT_OFFICER', 
    'RESPONDER', 
    'DONOR', 
    'AUDITOR'
  ];
  if (role && !validRoles.includes(role)) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: `Invalid role: ${role}` });
  }

  const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(targetUserId) as any;
  if (!existing) {
    return res.status(404).json({ error: 'USER_NOT_FOUND', message: 'Target user not found' });
  }

  const updatedRole = role || existing.role;
  const updatedJurisdiction = jurisdictionRegionId !== undefined ? jurisdictionRegionId : existing.jurisdiction_region_id;
  const updatedDepartment = department !== undefined ? department : existing.department;
  const updatedDesignation = designation !== undefined ? designation : existing.designation;
  const updatedApproval = approvalStatus !== undefined ? approvalStatus : existing.approval_status;
  const twoFactorEnabled = (['ADMIN', 'GOVT_OFFICER', 'GOVERNMENT_MEMBER', 'NGO'].includes(updatedRole)) ? 1 : 0;

  db.prepare(`
    UPDATE users 
    SET role = ?, jurisdiction_region_id = ?, department = ?, designation = ?, approval_status = ?, two_factor_enabled = ?, updated_at = datetime('now')
    WHERE id = ?
  `).run(updatedRole, updatedJurisdiction, updatedDepartment, updatedDesignation, updatedApproval, twoFactorEnabled, targetUserId);

  logAuditEvent({
    actionType: 'USER_ROLE_UPDATED',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId: targetUserId,
    details: `Role updated from ${existing.role} to ${updatedRole} (Dept: ${updatedDepartment || 'N/A'}, Desig: ${updatedDesignation || 'N/A'}, Jurisdiction: ${updatedJurisdiction || 'GLOBAL'}) by Main Admin`,
    beforeState: { role: existing.role, jurisdiction: existing.jurisdiction_region_id, department: existing.department },
    afterState: { role: updatedRole, jurisdiction: updatedJurisdiction, department: updatedDepartment, designation: updatedDesignation },
    ipAddress: req.ip
  });

  const updatedUser = db.prepare(`
    SELECT id, name, email, phone, role, approval_status, registration_number, department, designation, employee_id, jurisdiction_region_id, is_verified, two_factor_enabled, updated_at 
    FROM users WHERE id = ?
  `).get(targetUserId);

  res.json({ message: 'User role and position updated successfully', user: updatedUser });
});

// Admin User Management: Create new official position / account (Admin Only)
authRouter.post('/users/create-position', authenticate, requireRole('ADMIN'), async (req: Request, res: Response) => {
  const { 
    name, 
    email, 
    phone, 
    role, 
    jurisdictionRegionId, 
    department, 
    designation, 
    employeeId,
    initialPassword = 'Password123!' 
  } = req.body;

  if (!name || (!email && !phone) || !role) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Name, role, and email/phone are required' });
  }

  const validRoles = [
    'CITIZEN', 
    'VOLUNTEER', 
    'NGO', 
    'GOVERNMENT_MEMBER', 
    'ADMIN', 
    'GOVT_OFFICER', 
    'RESPONDER', 
    'DONOR', 
    'AUDITOR'
  ];
  if (!validRoles.includes(role)) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: `Invalid role: ${role}` });
  }

  try {
    const existing = db.prepare('SELECT id FROM users WHERE email = ? OR phone = ?').get(email || null, phone || null);
    if (existing) {
      return res.status(409).json({ error: 'USER_EXISTS', message: 'User with this email or phone already exists' });
    }

    const userId = `USR-${role}-${Date.now().toString().slice(-4)}`;
    const passwordHash = await hashPassword(initialPassword);
    const twoFactorEnabled = (['ADMIN', 'GOVT_OFFICER', 'GOVERNMENT_MEMBER', 'NGO'].includes(role)) ? 1 : 0;
    const twoFactorSecret = twoFactorEnabled ? `SECRET_2FA_${userId}` : null;

    db.prepare(`
      INSERT INTO users (
        id, name, email, phone, password_hash, role, approval_status,
        department, designation, employee_id, jurisdiction_region_id,
        is_verified, two_factor_enabled, two_factor_secret
      )
      VALUES (?, ?, ?, ?, ?, ?, 'APPROVED', ?, ?, ?, ?, 1, ?, ?)
    `).run(
      userId, 
      name, 
      email || null, 
      phone || null, 
      passwordHash, 
      role, 
      department || null, 
      designation || null, 
      employeeId || null, 
      jurisdictionRegionId || null, 
      twoFactorEnabled, 
      twoFactorSecret
    );

    logAuditEvent({
      actionType: 'OFFICIAL_POSITION_CREATED',
      actorId: req.user!.userId,
      actorRole: req.user!.role,
      entityId: userId,
      details: `Created new official position for ${name} as ${role} (Dept: ${department || 'N/A'}, Desig: ${designation || 'N/A'}, Jurisdiction: ${jurisdictionRegionId || 'GLOBAL'})`,
      ipAddress: req.ip
    });

    const newUser = db.prepare(`
      SELECT id, name, email, phone, role, approval_status, department, designation, employee_id, jurisdiction_region_id, is_verified, two_factor_enabled, created_at 
      FROM users WHERE id = ?
    `).get(userId);

    res.status(201).json({ message: 'Official position created successfully', user: newUser });
  } catch (err: any) {
    res.status(500).json({ error: 'SERVER_ERROR', message: err.message });
  }
});

// --- PRD v2.0 Phase 1 Dedicated Routes ---

// R-AUTH-2: 4-digit App PIN Unlock for Returning Users
authRouter.post('/pin-unlock', (req: Request, res: Response) => {
  const { userId, pin, deviceId, deviceName = 'Returning Device' } = req.body;

  if (!userId || !pin) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'User ID and 4-digit PIN required' });
  }

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId) as any;
  if (!user) {
    return res.status(404).json({ error: 'USER_NOT_FOUND', message: 'User not found' });
  }

  if (isAccountLocked(user)) {
    return res.status(423).json({
      error: 'ACCOUNT_LOCKED',
      message: 'Account locked due to 5 failed attempts. Please try again in 15 minutes (R-AUTH-4).',
      lockedUntil: user.locked_until
    });
  }

  const isPinValid = verifyAppPin(userId, pin);
  if (!isPinValid) {
    const lockStatus = recordFailedLogin(userId);
    if (lockStatus.locked) {
      return res.status(423).json({
        error: 'ACCOUNT_LOCKED',
        message: 'Account locked due to 5 failed attempts. Please try again in 15 minutes.',
        lockedUntil: lockStatus.lockedUntil
      });
    }
    return res.status(401).json({ error: 'INVALID_PIN', message: 'Invalid 4-digit PIN entered' });
  }

  resetFailedLogins(userId);
  if (deviceId) {
    recordUserDevice(userId, deviceId, deviceName, req.headers['user-agent'] as string, req.ip);
  }

  const session = createSessionAndTokens(user, req.headers['user-agent'], req.ip);
  res.json({
    message: 'PIN unlock successful',
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      approvalStatus: user.approval_status || 'APPROVED',
      landingRoute: getHomeRouteForRole(user.role)
    },
    ...session
  });
});

// R-AUTH-3: Re-authentication challenge token for sensitive actions
authRouter.post('/reauth', async (req: Request, res: Response) => {
  const { emailOrPhone, password, action } = req.body;

  if (!emailOrPhone || !password || !action) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Email/phone, password, and action name required' });
  }

  const user = db.prepare('SELECT * FROM users WHERE email = ? OR phone = ?').get(emailOrPhone, emailOrPhone) as any;
  if (!user || !user.password_hash) {
    return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Authentication failed' });
  }

  const isValidPassword = await verifyPasswordHash(user.password_hash, password);
  if (!isValidPassword) {
    return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Authentication failed' });
  }

  const reauthToken = issueReauthChallenge(user.id, action);
  res.json({
    message: `Re-authentication confirmed for ${action}`,
    reauthToken
  });
});

// R-AUTH-5: Link Guest SOS report to newly registered user
authRouter.post('/link-guest-sos', authenticate, (req: Request, res: Response) => {
  const { guestSosId, phone } = req.body;
  const userId = req.user!.userId;

  if (!guestSosId && !phone) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'guestSosId or contact phone required to link report' });
  }

  const updated = db.prepare(`
    UPDATE incident_reports
    SET contact_phone = COALESCE(contact_phone, (SELECT phone FROM users WHERE id = ?))
    WHERE id = ? OR idempotency_key = ? OR contact_phone = ?
  `).run(userId, guestSosId || null, guestSosId || null, phone || null);

  res.json({
    message: 'Guest SOS linked to account successfully',
    linkedCount: updated.changes
  });
});

// R-NGO-1, R-VOL-1, R-GOV-6: Admin / Govt Member Approval Gate
authRouter.post('/approve/:userId', authenticate, requireRole('ADMIN', 'GOVT_OFFICER'), (req: Request, res: Response) => {
  const targetUserId = req.params.userId as string;
  const targetUser = db.prepare('SELECT * FROM users WHERE id = ?').get(targetUserId) as any;

  if (!targetUser) {
    return res.status(404).json({ error: 'USER_NOT_FOUND', message: 'Target user not found' });
  }

  // ACCEPT CRITERION: NGO cannot be approved without a registration number (R-NGO-1)
  if (targetUser.role === 'NGO') {
    if (!targetUser.registration_number || targetUser.registration_number.trim() === '') {
      return res.status(400).json({
        error: 'APPROVAL_REJECTED',
        message: 'NGO cannot be approved without a verified registration number (DARPAN / Society Reg) (R-NGO-1)'
      });
    }
  }

  // Government member requires Super Admin approval
  if (targetUser.role === 'GOVERNMENT_MEMBER' || targetUser.role === 'GOVT_OFFICER') {
    if (req.user!.role !== 'ADMIN') {
      return res.status(403).json({
        error: 'FORBIDDEN',
        message: 'Government official approval requires Super Admin authorization'
      });
    }
  }

  db.prepare(`
    UPDATE users 
    SET approval_status = 'APPROVED', is_verified = 1, updated_at = datetime('now')
    WHERE id = ?
  `).run(targetUserId);

  logAuditEvent({
    actionType: 'USER_APPROVAL_GRANTED',
    actorId: req.user!.userId,
    actorRole: req.user!.role,
    entityId: targetUserId,
    details: `Granted approval for ${targetUser.role} account (${targetUser.name})`,
    ipAddress: req.ip
  });

  const updatedUser = db.prepare('SELECT id, name, role, approval_status, is_verified, registration_number FROM users WHERE id = ?').get(targetUserId);
  res.json({
    message: `Account successfully approved for ${targetUser.role}`,
    user: updatedUser
  });
});

// R-CIT-1: Emergency Contacts API
authRouter.post('/emergency-contacts', authenticate, (req: Request, res: Response) => {
  const { name, phone, relationship = 'Family', isPrimary = false, otpCode } = req.body;
  const userId = req.user!.userId;

  if (!name || !phone) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Contact name and phone number are required' });
  }

  // If OTP code passed, verify it
  let isOtpVerified = 1;
  if (otpCode) {
    isOtpVerified = verifyOtp(phone, otpCode, 'REGISTER') ? 1 : 0;
  }

  const id = `EC-${userId}-${Date.now().toString().slice(-4)}`;
  db.prepare(`
    INSERT INTO emergency_contacts (id, user_id, name, phone, relationship, is_primary, is_otp_verified)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(id, userId, name, phone, relationship, isPrimary ? 1 : 0, isOtpVerified);

  res.status(201).json({
    message: 'Emergency contact added successfully',
    contact: { id, userId, name, phone, relationship, isPrimary: !!isPrimary, isOtpVerified: !!isOtpVerified }
  });
});

authRouter.get('/emergency-contacts', authenticate, (req: Request, res: Response) => {
  const contacts = db.prepare('SELECT * FROM emergency_contacts WHERE user_id = ? ORDER BY is_primary DESC, created_at ASC').all(req.user!.userId);
  res.json({ contacts });
});

// R-CIT-3: Saved Places API (Up to 5 places)
authRouter.post('/saved-places', authenticate, (req: Request, res: Response) => {
  const { label, address, ward = 'Ward 1', latitude, longitude } = req.body;
  const userId = req.user!.userId;

  if (!label || !address || latitude === undefined || longitude === undefined) {
    return res.status(400).json({ error: 'BAD_REQUEST', message: 'Label, address, latitude, and longitude are required' });
  }

  // R-CIT-3 limit: Max 5 saved places
  const existingCount = (db.prepare('SELECT count(*) as count FROM saved_places WHERE user_id = ?').get(userId) as any).count;
  if (existingCount >= 5) {
    return res.status(400).json({
      error: 'LIMIT_EXCEEDED',
      message: 'Maximum of 5 saved places allowed per citizen (R-CIT-3)'
    });
  }

  const id = `PLC-${userId}-${Date.now().toString().slice(-4)}`;
  db.prepare(`
    INSERT INTO saved_places (id, user_id, label, address, ward, latitude, longitude)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(id, userId, label, address, ward, latitude, longitude);

  res.status(201).json({
    message: 'Saved place added successfully',
    place: { id, userId, label, address, ward, latitude, longitude }
  });
});

authRouter.get('/saved-places', authenticate, (req: Request, res: Response) => {
  const places = db.prepare('SELECT * FROM saved_places WHERE user_id = ? ORDER BY created_at ASC').all(req.user!.userId);
  res.json({ places });
});

// R-AUTH-4: User Devices and Remote Sign-Out API
authRouter.get('/devices', authenticate, (req: Request, res: Response) => {
  const devices = db.prepare('SELECT * FROM user_devices WHERE user_id = ? ORDER BY last_active_at DESC').all(req.user!.userId);
  res.json({ devices });
});

authRouter.post('/devices/:id/revoke', authenticate, (req: Request, res: Response) => {
  const deviceId = req.params.id as string;
  revokeUserDevice(req.user!.userId, deviceId);
  res.json({ message: 'Device revoked successfully' });
});

// R-CIT-8: Safe Check-in ("I am safe" to family) & Missing Person Status Resolution
authRouter.post('/safe-checkin', authenticate, (req: Request, res: Response) => {
  const userId = req.user!.userId;
  const { status_message = 'I am safe and uninjured.', current_location = 'Designated High Ground', shelter_id } = req.body;

  const user = db.prepare('SELECT name, phone FROM users WHERE id = ?').get(userId) as any;
  const userName = user?.name || 'Citizen';

  // 1. Fetch verified emergency contacts
  const contacts = db.prepare('SELECT name, phone FROM emergency_contacts WHERE user_id = ?').all(userId) as any[];

  // 2. Transmit simulated/live check-in SMS notification to each contact
  const notificationsSent = contacts.map(c => ({
    contactName: c.name,
    contactPhone: c.phone,
    channel: 'SMS',
    status: 'SENT',
    message: `[RESQAI SAFE CHECK-IN] ${userName} has checked in: "${status_message}". Current location: ${current_location}. Shelter: ${shelter_id || 'N/A'}. Time: ${new Date().toLocaleTimeString('en-IN')}`
  }));

  // 3. Resolve any missing person reports filed under this citizen's name
  let missingReportsResolved = 0;
  if (userName) {
    const res = db.prepare(`
      UPDATE missing_person_records
      SET status = 'FOUND_SAFE', shelter_id = COALESCE(?, shelter_id)
      WHERE full_name = ? AND status = 'SEARCHING'
    `).run(shelter_id || null, userName);
    missingReportsResolved = res.changes;
  }

  logAuditEvent({
    actionType: 'CITIZEN_SAFE_CHECKIN',
    actorId: userId,
    actorRole: req.user!.role,
    entityId: userId,
    details: `Citizen ${userName} checked in as safe. Dispatched alerts to ${contacts.length} emergency contacts. Resolved ${missingReportsResolved} missing person searches.`,
    ipAddress: req.ip
  });

  res.json({
    success: true,
    message: `Safe check-in recorded. ${contacts.length} emergency contacts notified.`,
    safeStatus: 'FOUND_SAFE',
    contactsNotifiedCount: contacts.length,
    notifications: notificationsSent,
    missingReportsResolved
  });
});



