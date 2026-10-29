import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/user_model.dart';

enum AuthPortal { citizen, governmentAdmin, volunteerNgo }

class AuthScreen extends ConsumerStatefulWidget {
  final bool isRegisterMode;

  const AuthScreen({super.key, this.isRegisterMode = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  AuthPortal _activePortal = AuthPortal.citizen;
  late bool _isRegister;
  UserRole _selectedRole = UserRole.citizen;

  // Citizen credentials
  final TextEditingController _citizenNameController = TextEditingController(text: 'Aarav Sharma');
  final TextEditingController _citizenPhoneController = TextEditingController(text: '+91 98765 43210');
  final TextEditingController _citizenEmailController = TextEditingController(text: 'citizen@resqai.org');
  final TextEditingController _citizenPasswordController = TextEditingController(text: 'password123');
  final TextEditingController _citizenEmergencyNameController = TextEditingController(text: 'Sunita Sharma (Mother)');
  final TextEditingController _citizenEmergencyPhoneController = TextEditingController(text: '+91 98111 22233');
  final TextEditingController _citizenDistrictController = TextEditingController(text: 'East Delhi');
  final TextEditingController _citizenLocalityController = TextEditingController(text: 'Mayur Vihar Phase 1');
  String _citizenLanguage = 'en';

  // Government & Main Admin credentials
  final TextEditingController _adminEmailController = TextEditingController(text: 'admin@resqai.org');
  final TextEditingController _adminPasswordController = TextEditingController(text: 'AdminPassword123!');
  final TextEditingController _adminDepartmentController = TextEditingController(text: 'SDMA IT & Disaster Governance');
  final TextEditingController _adminDesignationController = TextEditingController(text: 'Chief Disaster Management Director');
  bool _isAdminSuperAccess = true;

  // Volunteer credentials
  final TextEditingController _volNameController = TextEditingController(text: 'Pooja Sharma');
  final TextEditingController _volPhoneController = TextEditingController(text: '+91 98111 22334');
  final TextEditingController _volEmailController = TextEditingController(text: 'pooja.volunteer@resqai.org');
  final TextEditingController _volPasswordController = TextEditingController(text: 'password123');
  final TextEditingController _volServiceAreaController = TextEditingController(text: 'Yamuna Riverbank & East Delhi');
  final List<String> _selectedSkills = ['First Aid Certified', 'Flood Rescue', 'Food Distribution'];
  bool _volSafetyAgreed = true;

  // NGO credentials
  final TextEditingController _ngoOrgNameController = TextEditingController(text: 'Indian Red Cross Society');
  final TextEditingController _ngoRegNumberController = TextEditingController(text: 'DARPAN-DL-2024-00192');
  final TextEditingController _ngoRepNameController = TextEditingController(text: 'Vikram Sethi');
  final TextEditingController _ngoPhoneController = TextEditingController(text: '+91 99123 44556');
  final TextEditingController _ngoEmailController = TextEditingController(text: 'director@redcrossdelhi.org');
  final TextEditingController _ngoPasswordController = TextEditingController(text: 'password123');
  final TextEditingController _ngoBankDetailsController = TextEditingController(text: 'SBI Relief A/C #8841294103');

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.isRegisterMode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return AppShell(
      currentRoute: _isRegister ? AppRoutes.register : AppRoutes.login,
      title: 'ResQAI Secure Access Portal',
      breadcrumbs: const ['Auth', 'Unified Access'],
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 28, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield, color: AppColors.primaryBlue, size: 34),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'ResQAI Disaster Response Platform',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : AppColors.deepNavy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Unified Transparent Relief Platform for Citizens, Volunteers, NGOs and Government',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emergency Red Alert Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.emergencyRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emergencyRed.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'If life is in immediate danger, call 112 directly.',
                            style: TextStyle(
                              color: AppColors.emergencyRed,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Portal Selector Normal Buttons
                  const Text(
                    'SELECT LOGIN PORTAL TYPE:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPortalButton(
                          title: 'Citizen',
                          icon: Icons.person_outline,
                          portal: AuthPortal.citizen,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPortalButton(
                          title: 'Gov & Admin',
                          icon: Icons.admin_panel_settings_outlined,
                          portal: AuthPortal.governmentAdmin,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPortalButton(
                          title: 'NGO / Vol',
                          icon: Icons.handshake_outlined,
                          portal: AuthPortal.volunteerNgo,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Portal View
                  if (_activePortal == AuthPortal.citizen)
                    _buildCitizenPortal(isDark, isMobile)
                  else if (_activePortal == AuthPortal.governmentAdmin)
                    _buildGovernmentAdminPortal(isDark, isMobile)
                  else
                    _buildVolunteerNgoPortal(isDark, isMobile),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Emergency Guest SOS Button with Pink/Red urgency
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      side: const BorderSide(color: AppColors.primaryRed, width: 1.6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.flash_on, size: 18, color: AppColors.primaryRed),
                    label: const Text(
                      'Continue as Guest (Instant SOS Only - No ID Required)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.citizenSos);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortalButton({
    required String title,
    required IconData icon,
    required AuthPortal portal,
    required bool isDark,
  }) {
    final isSelected = _activePortal == portal;
    Color activeColor = AppColors.primaryGreen;
    if (portal == AuthPortal.governmentAdmin) activeColor = AppColors.primaryRed;
    if (portal == AuthPortal.volunteerNgo) activeColor = const Color(0xFF0D9488);

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? activeColor
            : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade100),
        foregroundColor: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : AppColors.deepNavy),
        elevation: isSelected ? 3 : 0,
        shadowColor: activeColor.withOpacity(0.35),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
      ),
      onPressed: () {
        setState(() {
          _activePortal = portal;
          if (portal == AuthPortal.citizen) {
            _selectedRole = UserRole.citizen;
          } else if (portal == AuthPortal.governmentAdmin) {
            _selectedRole = _isAdminSuperAccess ? UserRole.admin : UserRole.govtOfficial;
          } else {
            _selectedRole = UserRole.volunteer;
          }
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. CITIZEN PORTAL (NEW USER: 1st CREATE ID, THEN LOGIN)
  // ==========================================
  Widget _buildCitizenPortal(bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Citizen Registration Notice',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'New citizens: First create your Citizen ID with emergency contact details. Once created, you are logged directly into your Citizen Dashboard for emergency warnings and relief tracking.',
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : AppColors.deepNavy, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Toggle Buttons: [1. Create Citizen ID] & [2. Citizen Sign In]
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRegister ? AppColors.primaryGreen : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade200),
                  foregroundColor: _isRegister ? Colors.white : (isDark ? Colors.white70 : AppColors.deepNavy),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('1. Create Citizen ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => setState(() => _isRegister = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_isRegister ? AppColors.primaryGreen : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade200),
                  foregroundColor: !_isRegister ? Colors.white : (isDark ? Colors.white70 : AppColors.deepNavy),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.login, size: 16),
                label: const Text('2. Citizen Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => setState(() => _isRegister = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (_isRegister) ...[
          // REGISTER FLOW (NEW USER CREATES ID)
          const Text('Full Legal Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _citizenNameController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
              hintText: 'e.g. Aarav Sharma',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mobile Phone (+91) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _citizenPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        hintText: '+91 98765 43210',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Password *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _citizenPasswordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mandatory Emergency Contact Card (PRD R-CIT-1)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.emergencyRed.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.emergencyRed.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.contact_emergency, color: AppColors.emergencyRed, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Mandatory Emergency Contact (R-CIT-1) *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emergencyRed),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _citizenEmergencyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Person Name (e.g. Sunita Sharma - Mother)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _citizenEmergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Mobile Number (+91)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _citizenDistrictController,
                  decoration: const InputDecoration(
                    labelText: 'Home District *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _citizenLocalityController,
                  decoration: const InputDecoration(
                    labelText: 'Locality / Ward *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              gradient: AppColors.greenGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: AppColors.primaryGreen.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _handleCitizenRegistration(),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Create Citizen ID & Open Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
        ] else ...[
          // SIGN IN FLOW (EXISTING USER)
          const Text('Registered Phone or Email *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _citizenEmailController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline, size: 20),
              hintText: 'citizen@resqai.org or +91 98765 43210',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          const Text('Password or 4-Digit PIN *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _citizenPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              gradient: AppColors.greenGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: AppColors.primaryGreen.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _handleCitizenLogin(),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 18),
                  SizedBox(width: 8),
                  Text('Sign In to Citizen Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // 2. GOVERNMENT & MAIN ADMIN PORTAL (SUPER ADMIN & OFFICIALS)
  // ==========================================
  Widget _buildGovernmentAdminPortal(bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade800.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security, color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Administrative & Governance Command Desk',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• Main Admin (Super Admin): Unrestricted master access across ALL role dashboards, role assignment, and official position creation.\n• Government Member / DDMA Officer: Statutory incident verification, SDRF disbursement, and dispatch command.',
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : AppColors.deepNavy, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Admin Sign In Preset Buttons
        const Text('QUICK ACCESS PRESETS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.6)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAdminSuperAccess ? AppColors.deepNavy : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade200),
                  foregroundColor: _isAdminSuperAccess ? Colors.white : (isDark ? Colors.white70 : AppColors.deepNavy),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: _isAdminSuperAccess ? AppColors.primaryBlue : Colors.transparent),
                  ),
                ),
                icon: const Icon(Icons.admin_panel_settings, size: 16),
                label: const Text('Main Admin (Master)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _isAdminSuperAccess = true;
                    _adminEmailController.text = 'admin@resqai.org';
                    _adminPasswordController.text = 'AdminPassword123!';
                    _adminDepartmentController.text = 'SDMA IT & Disaster Governance';
                    _adminDesignationController.text = 'System SuperAdmin (All Access)';
                    _selectedRole = UserRole.admin;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_isAdminSuperAccess ? AppColors.deepNavy : (isDark ? AppColors.darkSurfaceCard : Colors.grey.shade200),
                  foregroundColor: !_isAdminSuperAccess ? Colors.white : (isDark ? Colors.white70 : AppColors.deepNavy),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: !_isAdminSuperAccess ? AppColors.primaryBlue : Colors.transparent),
                  ),
                ),
                icon: const Icon(Icons.account_balance, size: 16),
                label: const Text('Gov Officer (DDMA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _isAdminSuperAccess = false;
                    _adminEmailController.text = 'adm.delhi@gov.in';
                    _adminPasswordController.text = 'Password123!';
                    _adminDepartmentController.text = 'DDMA / Revenue & Relief';
                    _adminDesignationController.text = 'Additional District Magistrate (Relief)';
                    _selectedRole = UserRole.govtOfficial;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text('Official Email / Username *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _adminEmailController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.email_outlined, size: 20),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        const Text('Password *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _adminPasswordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 18),

        Container(
          decoration: BoxDecoration(
            gradient: _isAdminSuperAccess
                ? const LinearGradient(colors: [Color(0xFF4338CA), Color(0xFF6366F1)])
                : AppColors.redGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (_isAdminSuperAccess ? Colors.indigo : AppColors.primaryRed).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _handleAdminLogin(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isAdminSuperAccess ? Icons.security : Icons.shield, size: 18),
                const SizedBox(width: 8),
                Text(
                  _isAdminSuperAccess ? 'Sign In as Main Admin (Master Control)' : 'Sign In as Government Officer',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. VOLUNTEERS & RELIEF NGOS PORTAL
  // ==========================================
  Widget _buildVolunteerNgoPortal(bool isDark, bool isMobile) {
    final isVolunteer = _selectedRole == UserRole.volunteer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Volunteer Desk', style: TextStyle(fontWeight: FontWeight.bold)),
                selected: isVolunteer,
                onSelected: (val) {
                  if (val) setState(() => _selectedRole = UserRole.volunteer);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('NGO Organization', style: TextStyle(fontWeight: FontWeight.bold)),
                selected: !isVolunteer,
                onSelected: (val) {
                  if (val) setState(() => _selectedRole = UserRole.ngoLead);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (isVolunteer) ...[
          // Volunteer Form
          const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _volNameController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          const Text('Email or Phone *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _volEmailController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          const Text('Service Area / Operational District *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _volServiceAreaController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),

          CheckboxListTile(
            value: _volSafetyAgreed,
            contentPadding: EdgeInsets.zero,
            title: const Text('I accept the Disaster Volunteer Safety Briefing and Field Code of Conduct.', style: TextStyle(fontSize: 12)),
            onChanged: (v) => setState(() => _volSafetyAgreed = v ?? true),
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _handleVolunteerSubmit(),
            child: const Text('Enter Volunteer Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ] else ...[
          // NGO Form
          const Text('Registered NGO / Society Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _ngoOrgNameController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          const Text('NGO DARPAN ID / Registration Number (Unique, Required R-NGO-1) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _ngoRegNumberController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          const Text('Authorized Representative *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _ngoRepNameController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 12),
          const Text('Official Email *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _ngoEmailController, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 14),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _handleNgoSubmit(),
            child: const Text('Enter NGO Relief Console', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // AUTH ACTION HANDLERS
  // ==========================================

  void _handleCitizenRegistration() {
    final name = _citizenNameController.text.trim();
    final phone = _citizenPhoneController.text.trim();
    final emergencyName = _citizenEmergencyNameController.text.trim();
    final emergencyPhone = _citizenEmergencyPhoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showError('Full name and mobile phone are required.');
      return;
    }
    if (emergencyName.isEmpty || emergencyPhone.isEmpty) {
      _showError('Mandatory Emergency Contact details must be provided (R-CIT-1).');
      return;
    }

    final newCitizenId = 'RQ-CIT-2026-${Random().nextInt(9000) + 1000}';
    final user = UserModel(
      id: 'USR-${newCitizenId.replaceAll('-', '_')}',
      citizenId: newCitizenId,
      name: name,
      email: _citizenEmailController.text.trim().isNotEmpty ? _citizenEmailController.text.trim() : 'citizen@resqai.org',
      phoneMasked: phone.length > 5 ? '${phone.substring(0, 3)}*** **${phone.substring(phone.length - 3)}' : phone,
      phoneRaw: phone,
      role: UserRole.citizen,
      badgeOrJurisdiction: '${_citizenDistrictController.text}, ${_citizenLocalityController.text}',
      emergencyContactName: emergencyName,
      emergencyContactPhone: emergencyPhone,
      district: _citizenDistrictController.text,
      stateName: 'Delhi',
      isVerified: true,
      verificationStatus: 'APPROVED',
      preferredLanguage: _citizenLanguage,
      loggedInAt: DateTime.now(),
    );

    // Save user & set active role
    ref.read(authProvider.notifier).loginAs(user);
    ref.read(activeRoleProvider.notifier).state = UserRole.citizen;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.successGreen,
        content: Text('✓ Citizen ID generated: $newCitizenId. Logged into Citizen Dashboard.'),
      ),
    );

    Navigator.pushReplacementNamed(context, AppRoutes.citizenDashboard);
  }

  void _handleCitizenLogin() {
    final email = _citizenEmailController.text.trim();
    final user = UserModel(
      id: 'USR-CITIZEN-01',
      citizenId: 'RQ-CIT-2026-1042',
      name: _citizenNameController.text.trim().isNotEmpty ? _citizenNameController.text.trim() : 'Aarav Sharma',
      email: email.isNotEmpty ? email : 'citizen@resqai.org',
      phoneMasked: '+91 98*** **210',
      phoneRaw: '+91 98765 43210',
      role: UserRole.citizen,
      badgeOrJurisdiction: 'Yamuna Lowland Ward 4, Delhi',
      emergencyContactName: _citizenEmergencyNameController.text,
      emergencyContactPhone: _citizenEmergencyPhoneController.text,
      district: 'East Delhi',
      stateName: 'Delhi',
      isVerified: true,
      verificationStatus: 'APPROVED',
      loggedInAt: DateTime.now(),
    );

    ref.read(authProvider.notifier).loginAs(user);
    ref.read(activeRoleProvider.notifier).state = UserRole.citizen;

    Navigator.pushReplacementNamed(context, AppRoutes.citizenDashboard);
  }

  void _handleAdminLogin() {
    final email = _adminEmailController.text.trim();
    final role = _isAdminSuperAccess ? UserRole.admin : UserRole.govtOfficial;

    final adminUser = UserModel(
      id: _isAdminSuperAccess ? 'USR-ADMIN-01' : 'USR-GOV-01',
      citizenId: _isAdminSuperAccess ? 'RQ-ADM-2026-001' : 'RQ-GOV-2026-001',
      name: _isAdminSuperAccess ? 'System SuperAdmin' : 'Rajesh Kumar (ADM Relief)',
      email: email.isNotEmpty ? email : (_isAdminSuperAccess ? 'admin@resqai.org' : 'adm.delhi@gov.in'),
      phoneMasked: '+91 98*** **999',
      phoneRaw: '+91 98765 43211',
      role: role,
      badgeOrJurisdiction: _adminDesignationController.text,
      organization: _adminDepartmentController.text,
      district: 'National Capital Region',
      stateName: 'Delhi',
      isVerified: true,
      verificationStatus: 'APPROVED',
      loggedInAt: DateTime.now(),
    );

    ref.read(authProvider.notifier).loginAs(adminUser);
    ref.read(activeRoleProvider.notifier).state = role;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isAdminSuperAccess ? Colors.indigo : AppColors.criticalRed,
        content: Text(_isAdminSuperAccess
            ? '✓ Authenticated as Main Admin (Super Admin). Full master control enabled.'
            : '✓ Authenticated as Government Relief Officer. Command Desk active.'),
      ),
    );

    Navigator.pushReplacementNamed(context, AppRoutes.governmentCommandCentre);
  }

  void _handleVolunteerSubmit() {
    if (!_volSafetyAgreed) {
      _showError('Please accept the volunteer safety briefing.');
      return;
    }

    final volUser = UserModel(
      id: 'USR-VOL-01',
      citizenId: 'RQ-VOL-2026-${Random().nextInt(900) + 100}',
      name: _volNameController.text.trim(),
      email: _volEmailController.text.trim(),
      phoneMasked: '+91 98*** **334',
      phoneRaw: _volPhoneController.text.trim(),
      role: UserRole.volunteer,
      badgeOrJurisdiction: 'Civil Defense Volunteer',
      skills: _selectedSkills,
      serviceArea: _volServiceAreaController.text.trim(),
      isVerified: true,
      verificationStatus: 'APPROVED',
      loggedInAt: DateTime.now(),
    );

    ref.read(authProvider.notifier).loginAs(volUser);
    ref.read(activeRoleProvider.notifier).state = UserRole.volunteer;

    Navigator.pushReplacementNamed(context, AppRoutes.volunteerDashboard);
  }

  void _handleNgoSubmit() {
    final regNum = _ngoRegNumberController.text.trim();
    if (regNum.isEmpty) {
      _showError('NGO Registration Number (DARPAN / Society Reg) is mandatory (R-NGO-1).');
      return;
    }

    final ngoUser = UserModel(
      id: 'USR-NGO-01',
      citizenId: 'RQ-NGO-2026-${Random().nextInt(900) + 100}',
      name: _ngoRepNameController.text.trim(),
      email: _ngoEmailController.text.trim(),
      phoneMasked: '+91 99*** **331',
      phoneRaw: _ngoPhoneController.text.trim(),
      role: UserRole.ngoLead,
      badgeOrJurisdiction: 'NGO Operations Lead',
      organization: _ngoOrgNameController.text.trim(),
      regNumber: regNum,
      isVerified: true,
      verificationStatus: 'APPROVED',
      loggedInAt: DateTime.now(),
    );

    ref.read(authProvider.notifier).loginAs(ngoUser);
    ref.read(activeRoleProvider.notifier).state = UserRole.ngoLead;

    Navigator.pushReplacementNamed(context, AppRoutes.ngoDashboard);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.emergencyRed, content: Text(message)),
    );
  }
}
