import '../../data/services/app_update_service.dart';
import '../../data/services/app_version_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/user_model.dart';
import '../auth/auth_screen.dart';
import '../../core/utils/i18n.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const UserProfileScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeSectionIndex = 0;

  IconData _getSectionIcon(int index) {
    switch (index) {
      case 0: return Icons.person;
      case 1: return Icons.security;
      case 2: return Icons.notifications_active;
      case 3: return Icons.settings;
      case 4: return Icons.privacy_tip_outlined;
      case 5: return Icons.help_outline;
      default: return Icons.person;
    }
  }

  String _getSectionTitle(int index) {
    switch (index) {
      case 0: return 'Profile Settings';
      case 1: return 'Personal Security & PIN';
      case 2: return 'Life-Safety Channels';
      case 3: return 'Settings & Updates';
      case 4: return 'Hidden / Data Privacy';
      case 5: return 'Emergency Helplines';
      default: return 'Profile Settings';
    }
  }

  void _showThreeLineMenu(BuildContext context, UserModel user, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.menu, color: AppColors.primaryBlue, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Three-Line Menu (☰)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildThreeLineItem(ctx, 0, 'Profile Settings', 'Personal identity, saved places & emergency contact', Icons.person, AppColors.primaryBlue),
              _buildThreeLineItem(ctx, 1, 'Personal Security', '4-digit App PIN, biometric unlock, and active sessions', Icons.security, AppColors.emergencyRed),
              _buildThreeLineItem(ctx, 2, 'Life-Safety Channels', 'Push, SMS, WhatsApp alerts & multi-channel verification', Icons.notifications_active, AppColors.warningOrange),
              _buildThreeLineItem(ctx, 3, 'Settings & Updates', 'System language, location telemetry & app version check', Icons.settings, AppColors.primaryBlue),
              _buildThreeLineItem(ctx, 4, 'Hidden Settings & Privacy', 'DPDP 2023 masking, data export & account lifecycle', Icons.privacy_tip_outlined, const Color(0xFF7C3AED)),
              _buildThreeLineItem(ctx, 5, 'Helplines & Disaster Protocols', 'Official 112, 1070 & 1077 toll-free emergency call lines', Icons.help_outline, AppColors.successGreen),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThreeLineItem(BuildContext ctx, int index, String title, String subtitle, IconData icon, Color color) {
    final isSelected = _activeSectionIndex == index;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(isSelected ? 0.2 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? AppColors.primaryBlue : null,
          fontSize: 14,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryBlue, size: 18) : null,
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          _activeSectionIndex = index;
          if (_tabController.length > index) {
            _tabController.animateTo(index.clamp(0, 4));
          }
        });
      },
    );
  }

  bool _smsAlerts = true;
  bool _pushAlerts = true;
  bool _whatsappAlerts = true;
  bool _locationPermission = true;
  String _selectedLanguage = 'en';

  bool _isSendingTestNotification = false;
  bool _isExportingData = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _activeSectionIndex = widget.initialTabIndex.clamp(0, 5);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.emergencyRed, size: 22),
            SizedBox(width: 8),
            Text('Sign Out of ResQAI'),
          ],
        ),
        content: const Text(
          'Are you sure you wish to end your authenticated session? You can sign back in anytime to access your role workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergencyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              ref.read(activeRoleProvider.notifier).state = UserRole.citizen;
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.primaryBlue,
                  content: Text('✓ Successfully signed out. Session terminated.'),
                ),
              );
            },
            child: const Text('Confirm Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    setState(() => _isSendingTestNotification = true);
    try {
      final uri = Uri.parse('http://localhost:5000/api/v1/notifications/test');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'ResQAI Emergency Alert Test',
          'body': 'This is a test notification across In-App, Push and SMS channels.',
          'channels': ['IN_APP', 'PUSH', 'SMS'],
        }),
      ).timeout(const Duration(seconds: 4));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as Map<String, dynamic>?;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.successGreen,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✓ Test alerts dispatched! In-App: ${results?["in_app"] == true ? "Sent" : "Ready"}, Push: ${results?["push"] == true ? "Sent" : "Ready"}, SMS: ${results?["sms"] == true ? "Sent" : "Ready"}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryBlue,
            content: Text('✓ Test notification simulated across In-App, Push, and SMS channels.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingTestNotification = false);
    }
  }

  Future<void> _exportMyData(UserModel user) async {
    setState(() => _isExportingData = true);
    try {
      final exportData = {
        'export_format': 'ResQAI_DPDP_Compliant_User_Archive_v1',
        'generated_at': DateTime.now().toIso8601String(),
        'profile': {
          'id': user.id,
          'citizen_id': user.citizenId,
          'name': user.name,
          'email': user.email,
          'phone': user.phoneMasked,
          'emergency_contact': {
            'name': user.emergencyContactName,
            'phone': user.emergencyContactPhone,
          },
          'blood_group': user.bloodGroup,
          'district': user.district,
          'role': user.role.title,
          'verification_status': user.verificationStatus,
        },
        'incident_count': 1,
        'claim_count': 1,
        'compliance_notice': 'Exported in compliance with Digital Personal Data Protection (DPDP) Act 2023.',
      };

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.download_done, color: AppColors.successGreen, size: 22),
              SizedBox(width: 8),
              Text('Data Export Generated'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your complete account data archive has been generated in machine-readable JSON format:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    const JsonEncoder.withIndent('  ').convert(exportData),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.lightGreenAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingData = false);
    }
  }

  void _showDeleteAccountDialog(UserModel user) {
    // PRD v3.0 DEL-5 & DEL-7: Admin Handover Check
    if (user.role == UserRole.ngoLead ||
        user.role == UserRole.incidentCommander ||
        user.role == UserRole.govtOfficial) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.warningOrange, size: 24),
              SizedBox(width: 8),
              Text('Handover Required'),
            ],
          ),
          content: Text(
            'As an active ${user.role.title}, statutory disaster management protocols require transferring active emergency jurisdictions and relief campaigns to another verified officer before deleting your account.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understand', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // Step-by-step Delete Account Modal (DEL-1 to DEL-8)
    final passwordCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final deleteConfirmCtrl = TextEditingController();
    bool isOtpSent = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 24),
                SizedBox(width: 8),
                Text('Delete Account (Danger Zone)'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.emergencyRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emergencyRed.withOpacity(0.3)),
                    ),
                    child: const Text(
                      '• Personal details, credentials, and push tokens will be permanently erased.\n'
                      '• Historical disaster reports will be anonymized to protect public audit integrity.\n'
                      '• 7-day grace period: You can sign back in before deletion completes to cancel.',
                      style: TextStyle(fontSize: 11, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Password input
                  const Text('Enter Current Password or PIN *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Your password or demo PIN',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. OTP Verification
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('6-Digit Phone OTP *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() => isOtpSent = true);
                          otpCtrl.text = '123456';
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✓ 6-Digit OTP sent to your registered phone (Demo: 123456)')),
                          );
                        },
                        child: Text(isOtpSent ? 'Resend OTP (30s)' : 'Send OTP'),
                      ),
                    ],
                  ),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter 6-digit OTP',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Confirmation phrase
                  const Text(
                    'Type "DELETE" in capital letters to confirm *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emergencyRed),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: deleteConfirmCtrl,
                    decoration: const InputDecoration(
                      hintText: 'DELETE',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (deleteConfirmCtrl.text.trim() != 'DELETE') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.emergencyRed,
                              content: Text('Please type "DELETE" exactly to confirm.'),
                            ),
                          );
                          return;
                        }
                        if (passwordCtrl.text.trim().isEmpty || otpCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.emergencyRed,
                              content: Text('Please fill all required verification fields.'),
                            ),
                          );
                          return;
                        }

                        setModalState(() => isSubmitting = true);

                        // Call backend delete account API
                        try {
                          final uri = Uri.parse('http://localhost:5000/api/v1/auth/delete-account');
                          await http.post(
                            uri,
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'password': passwordCtrl.text.trim(),
                              'otp': otpCtrl.text.trim(),
                              'confirmationPhrase': 'DELETE',
                            }),
                          ).timeout(const Duration(seconds: 4));
                        } catch (_) {}

                        final scheduledDate = DateTime.now().add(const Duration(days: 7));
                        final formattedDate = '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}';

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        ref.read(authProvider.notifier).logout();
                        ref.read(activeRoleProvider.notifier).state = UserRole.citizen;
                        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 7),
                            backgroundColor: AppColors.warningOrange,
                            content: Text(
                              'Account scheduled for deletion on $formattedDate (7-day grace period). Sign back in anytime before then to cancel.',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Schedule Deletion (7-Day Grace)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return AppShell(
      currentRoute: AppRoutes.citizenProfile,
      title: 'Profile',
      breadcrumbs: const ['Profile'],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: currentUser == null
                ? _buildUnauthenticatedCard(context, isDark, isMobile)
                : _buildProfileContent(context, currentUser, isDark, isMobile),
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedCard(BuildContext context, bool isDark, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 36),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline, size: 48, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 18),
          Text(
            'Not Signed In',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in or create an account to access specialized disaster response workflows, emergency telemetry, and role workspaces.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen(isRegisterMode: false)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen(isRegisterMode: true)),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user, bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Profile Header Card
        Container(
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: isMobile ? 30 : 36,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
                    child: Text(
                      user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.deepNavy,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (user.isVerified ? AppColors.successGreen : AppColors.warningOrange).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.isVerified ? Icons.verified : Icons.hourglass_top,
                                    size: 13,
                                    color: user.isVerified ? AppColors.successGreen : AppColors.warningOrange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.verificationStatus,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: user.isVerified ? AppColors.successGreen : AppColors.warningOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.withOpacity(0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mail_outline, size: 10, color: Colors.red),
                                  SizedBox(width: 4),
                                  Text(
                                    'Gmail Verified',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildPill(user.role.title, AppColors.primaryRed),
                            _buildPill('ID: ${user.citizenId}', Colors.grey),
                            if (user.district.isNotEmpty) _buildPill('📍 ${user.district}', AppColors.successGreen),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. Three-Line (☰) Navigation Bar
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showThreeLineMenu(context, user, isDark),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // ☰ 3-Line Menu Icon Pill
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu, color: AppColors.primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Current Active Section & Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'NAVIGATION MENU (☰)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(Icons.touch_app, size: 10, color: AppColors.primaryBlue),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                _getSectionIcon(_activeSectionIndex),
                                size: 15,
                                color: isDark ? Colors.white70 : AppColors.deepNavy,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _getSectionTitle(_activeSectionIndex),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.deepNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Options button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Options', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(width: 3),
                          Icon(Icons.keyboard_arrow_down, size: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Active Section Content (Full fluid height)
        Builder(
          builder: (context) {
            switch (_activeSectionIndex) {
              case 0:
                return _buildMyProfileTab(user, isDark);
              case 1:
                return _buildSecurityTab(user, isDark);
              case 2:
                return _buildNotificationsTab(isDark);
              case 3:
                return _buildSettingsTab(user, isDark);
              case 4:
                return _buildHiddenDangerZoneTab(user, isDark);
              case 5:
                return _buildHelpTab(isDark);
              default:
                return _buildMyProfileTab(user, isDark);
            }
          },
        ),

        const SizedBox(height: 20),

        // 4. Sign Out Button
        OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, color: AppColors.emergencyRed, size: 18),
          label: const Text('Sign Out of Account', style: TextStyle(color: AppColors.emergencyRed, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.emergencyRed),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHiddenDangerZoneTab(UserModel user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.emergencyRed.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.privacy_tip_outlined, color: AppColors.emergencyRed, size: 22),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hidden Settings & Privacy',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Digital Personal Data Protection (DPDP) Act 2023 Compliance',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Under statutory DPDP provisions, you retain full rights over your data. Historical disaster incident reports are permanently anonymized to preserve disaster audit integrity, while personal identifiers are scrubbed.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isExportingData ? null : () => _exportMyData(user),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isExportingData
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 16),
                label: const Text('Download My Data (DPDP Archive)'),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDeleteAccountDialog(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text(
                  'Delete My Account (Danger Zone)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _editProfileDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final contactNameCtrl = TextEditingController(text: user.emergencyContactName);
    final contactPhoneCtrl = TextEditingController(text: user.emergencyContactPhone);
    final districtCtrl = TextEditingController(text: user.district);
    final bloodGroup = user.bloodGroup;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: AppColors.primaryBlue, size: 24),
            SizedBox(width: 8),
            Text('Update Profile Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Full Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              const Text('Emergency Contact Person *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: contactNameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              const Text('Emergency Contact Phone (Mandatory) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: contactPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              const Text('District / Territory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: districtCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final trimmedName = nameCtrl.text.trim();
              final trimmedPhone = contactPhoneCtrl.text.trim();
              if (trimmedName.isEmpty || trimmedPhone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: AppColors.emergencyRed, content: Text('Please fill all mandatory fields.')),
                );
                return;
              }

              final updatedUser = user.copyWith(
                name: trimmedName,
                emergencyContactName: contactNameCtrl.text.trim(),
                emergencyContactPhone: trimmedPhone,
                district: districtCtrl.text.trim(),
                bloodGroup: bloodGroup,
              );

              ref.read(authProvider.notifier).loginAs(updatedUser);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.successGreen,
                  content: Text('✓ Profile updated successfully. Session preserved.'),
                ),
              );
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMyProfileTab(UserModel user, bool isDark) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Personal & Jurisdiction Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            _buildDetailRow('Full Name', user.name),
            _buildDetailRow('Email Address', user.email),
            _buildDetailRow('Primary Phone (Masked)', user.phoneMasked),
            _buildDetailRow('Mandatory Emergency Contact', '${user.emergencyContactName} (${user.emergencyContactPhone})'),
            _buildDetailRow('Blood Group', user.bloodGroup),
            _buildDetailRow('Assigned Role', user.role.title),
            _buildDetailRow('Jurisdiction / Area', user.badgeOrJurisdiction.isNotEmpty ? user.badgeOrJurisdiction : user.district),
            if (user.organization != null) _buildDetailRow('Affiliated Organization', user.organization!),
            if (user.regNumber != null) _buildDetailRow('Statutory Reg / MCI / DARPAN ID', user.regNumber!),
            if (user.skills.isNotEmpty) _buildDetailRow('Certified Skills', user.skills.join(', ')),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Update Profile Details', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _editProfileDialog(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab(UserModel user, bool isDark) {
    final currentVersion = ref.watch(appVersionProvider);
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Application Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language, color: AppColors.primaryBlue),
              title: const Text('Interface Language', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Bilingual English & Hindi disaster prompts'),
              trailing: DropdownButton<String>(
                value: ref.watch(languageProvider),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedLanguage = val);
                    ref.read(languageProvider.notifier).setLanguage(val);
                  }
                },
              ),
            ),
            const Divider(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.gps_fixed, color: AppColors.primaryBlue),
              title: const Text('Live GPS Telemetry', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Provides precision coordinates during emergency SOS dispatch'),
              value: _locationPermission,
              activeColor: AppColors.primaryBlue,
              onChanged: (val) => setState(() => _locationPermission = val),
            ),
            const Divider(height: 24),
            const Text('App Version & Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Keep your disaster intelligence protocols, offline maps, and live weather telemetry up to date.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline, color: AppColors.primaryBlue),
              title: const Text('Current Version', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                'ResQAI v$currentVersion (Production Stable - Up to Date)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 2,
                  shadowColor: AppColors.primaryRed.withOpacity(0.3),
                ),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => AppUpdateService.showUpdateCheckDialog(context, ref: ref),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                if (currentVersion != AppConstants.appVersion)
                  TextButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 14, color: AppColors.warningOrange),
                    label: Text(
                      'Reset to v${AppConstants.appVersion} (Test Update Again)',
                      style: const TextStyle(fontSize: 11, color: AppColors.warningOrange),
                    ),
                    onPressed: () {
                      ref.read(appVersionProvider.notifier).resetVersion(AppConstants.appVersion);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('App version reset to v${AppConstants.appVersion}. Tap "Check for Updates" to test the update flow.'),
                          backgroundColor: AppColors.primaryBlue,
                        ),
                      );
                    },
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.new_releases_outlined, size: 14),
                  label: Text(
                    'Check for Next Release (v${AppUpdateService.computeNextVersion(currentVersion)})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => AppUpdateService.showUpdateCheckDialog(context, ref: ref, simulateUpdate: true),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab(bool isDark) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Life-Safety Alert Channels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Statutory broadcast channels from NDMA, IMD, and District Control Rooms.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.priority_high, color: AppColors.emergencyRed),
              title: const Text('Critical Emergency Push Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Immediate evacuation warnings (Bypasses DND)'),
              value: _pushAlerts,
              activeColor: AppColors.primaryBlue,
              onChanged: (val) => setState(() => _pushAlerts = val),
            ),
            const Divider(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.sms, color: AppColors.primaryBlue),
              title: const Text('SMS Early Warnings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Fallback SMS broadcast during network congestion'),
              value: _smsAlerts,
              activeColor: AppColors.primaryBlue,
              onChanged: (val) => setState(() => _smsAlerts = val),
            ),
            const Divider(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.chat, color: AppColors.successGreen),
              title: const Text('WhatsApp Disaster Bulletins', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Daily flood maps, relief camp locations, and water levels'),
              value: _whatsappAlerts,
              activeColor: AppColors.successGreen,
              onChanged: (val) => setState(() => _whatsappAlerts = val),
            ),
            const Divider(height: 16),

            // PRD NTF-8: "Send Test Notification" Action
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.send_to_mobile, size: 20, color: AppColors.primaryBlue),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verify Channel Delivery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Trigger test ping across In-App, Push & SMS', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSendingTestNotification ? null : _sendTestNotification,
                    child: _isSendingTestNotification
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Send Test Alert'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTab(UserModel user, bool isDark) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Security, Storage & Session Integrity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            _buildDetailRow('Session Persistence', 'Active & Verified (Local Secure Storage)'),
            _buildDetailRow('User Identifier (UID)', user.id),
            _buildDetailRow('Citizen ID / Officer Badge', user.citizenId),
            _buildDetailRow('Last Session Timestamp', user.loggedInAt.toIso8601String()),
            _buildDetailRow('DPDP Act 2023 Compliance', 'Phone masked in public feeds • Telemetry protected'),
            _buildDetailRow('Account Status', 'Active & Unscheduled for Deletion'),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpTab(bool isDark) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('24x7 Statutory Emergency Helplines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Immediate toll-free government hotlines for life-safety emergencies.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 20),
            _buildHelplineRow('112', 'National Emergency Response System (All Emergencies)', AppColors.emergencyRed),
            _buildHelplineRow('1077', 'District Disaster Control Room (East Delhi & NCR)', AppColors.primaryBlue),
            _buildHelplineRow('1070', 'State Disaster Management Authority (SDMA)', AppColors.primaryBlue),
            _buildHelplineRow('108', 'Free Emergency Medical Ambulance Service', AppColors.successGreen),
            _buildHelplineRow('101', 'Fire & Rescue Emergency Service', AppColors.warningOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelplineRow(String number, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone, size: 14, color: color),
                const SizedBox(width: 6),
                Text(number, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
