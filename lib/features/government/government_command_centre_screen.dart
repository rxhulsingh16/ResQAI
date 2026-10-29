import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/user_model.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import 'government_operations_screen.dart';
import '../../shared/models/incident_model.dart';
import '../../data/services/notification_client_service.dart';

class GovernmentCommandCentreScreen extends ConsumerStatefulWidget {
  const GovernmentCommandCentreScreen({super.key});

  @override
  ConsumerState<GovernmentCommandCentreScreen> createState() => _GovernmentCommandCentreScreenState();
}

class _GovernmentCommandCentreScreenState extends ConsumerState<GovernmentCommandCentreScreen> {
  bool _showRoleManagementModal = false;

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(incidentsProvider);
    final currentUser = ref.watch(authProvider);
    final activeRole = ref.watch(activeRoleProvider);
    final systemUsers = ref.watch(systemUsersProvider);
    final pendingUsers = ref.watch(pendingApprovalsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    final criticalQueue = incidents.where((i) => i.priorityScore >= 80).toList();
    final pendingVerifications = incidents.where((i) => i.status == IncidentStatus.received || i.status == IncidentStatus.pendingReview).toList();

    final isAdmin = currentUser?.role == UserRole.admin || activeRole == UserRole.admin;

    return AppShell(
      currentRoute: AppRoutes.governmentCommandCentre,
      title: 'State Disaster Management Authority (SDMA) Command',
      breadcrumbs: const ['Government', 'Command Centre'],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 32, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. MAIN ADMIN MASTER DASHBOARD SWITCHER
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isAdmin
                            ? 'MASTER ADMIN CONTROL: SWITCH ANY ROLE DASHBOARD'
                            : 'GOVERNMENT OPERATIONAL VIEW SWITCHER',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.6),
                      ),
                      const Spacer(),
                      if (isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text('SUPER ADMIN ALL-ACCESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDashboardSwitchChip(
                        label: '👤 Citizen Dashboard',
                        role: UserRole.citizen,
                        route: AppRoutes.citizenDashboard,
                        activeRole: activeRole,
                      ),
                      _buildDashboardSwitchChip(
                        label: '🤝 Volunteer Workspace',
                        role: UserRole.volunteer,
                        route: AppRoutes.volunteerDashboard,
                        activeRole: activeRole,
                      ),
                      _buildDashboardSwitchChip(
                        label: '🏢 NGO Console',
                        role: UserRole.ngoLead,
                        route: AppRoutes.ngoDashboard,
                        activeRole: activeRole,
                      ),
                      _buildDashboardSwitchChip(
                        label: '🚑 Responder View',
                        role: UserRole.rescueTeam,
                        route: AppRoutes.responderDashboard,
                        activeRole: activeRole,
                      ),
                      _buildDashboardSwitchChip(
                        label: '🩺 Medical Triage',
                        role: UserRole.doctor,
                        route: AppRoutes.medicalDashboard,
                        activeRole: activeRole,
                      ),
                      _buildDashboardSwitchChip(
                        label: '🏛️ Command Center (Current)',
                        role: UserRole.admin,
                        route: AppRoutes.governmentCommandCentre,
                        activeRole: activeRole,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ==========================================
            // 2. MAIN ADMIN ACCESS CONTROL & ROLE MANAGEMENT BAR
            // ==========================================
            if (isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.indigo.shade400.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.manage_accounts, color: Colors.indigo, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Roles & Access Control Center',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Create new official positions, assign roles, approve NGOs/Volunteers, or change user permissions.',
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Manage Roles & Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _openRoleManagementDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Authority Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.criticalRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.criticalRed.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: AppColors.criticalRed, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delhi Disaster Management Authority (DDMA) Operations Command',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'District Magistrate / ADM Relief Jurisdiction • 24/7 Live Incident Verification & SDRF Dispatch',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Command Metrics
            if (isMobile)
              Column(
                children: [
                  _buildKpiCard('CRITICAL EMERGENCIES', '${criticalQueue.length}', AppColors.criticalRed, isDark),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard('PENDING REVIEWS', '${pendingVerifications.length}', AppColors.warningOrange, isDark)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildKpiCard('ACTIVE TEAMS', '12 Units', AppColors.primaryBlue, isDark)),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _buildKpiCard('CRITICAL EMERGENCIES', '${criticalQueue.length}', AppColors.criticalRed, isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildKpiCard('PENDING VERIFICATIONS', '${pendingVerifications.length}', AppColors.warningOrange, isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildKpiCard('ACTIVE DISPATCH TEAMS', '12 Units', AppColors.primaryBlue, isDark)),
                ],
              ),
            const SizedBox(height: 22),

            // Quick Actions & Navigation
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.redGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.campaign),
                      label: const Text('Issue Official Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GovernmentOperationsScreen()),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.greenGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.account_balance),
                      label: const Text('SDRF Financial Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.governmentFinancialTransparency),
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.radar),
                      label: const Text('Live Tactical Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.disasterMap),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Live Priority Incident Queue
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priority Intake & Case Review Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 14),
                  for (final item in incidents) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.priorityScore >= 80 ? AppColors.criticalRed.withOpacity(0.12) : AppColors.primaryBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.priorityScore.toStringAsFixed(0)} PTS',
                              style: TextStyle(
                                color: item.priorityScore >= 80 ? AppColors.criticalRed : AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('ID: ${item.id} • ${item.address}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.assignedTeam != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.assignedTeam!,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryRed,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      ref.read(incidentsProvider.notifier).updateStatus(item.id, IncidentStatus.helpAssigned, team: 'NDRF 8th Bn Inflatable Boat Unit');
                                      ref.read(notificationsProvider.notifier).addAlertNotification(
                                        title: '🚨 Official NDRF Rescue Dispatched (' + item.id + ')',
                                        body: 'NDRF Unit 4 dispatched by SDMA Incident Command to ' + item.address + '.',
                                        severity: 'CRITICAL',
                                        source: 'SDMA Command',
                                        type: 'SOS',
                                        direction: 'SENT',
                                        status: 'DISPATCHED',
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('NDRF Boat Unit 4 dispatched to "' + item.title + '"!'),
                                          backgroundColor: AppColors.primaryRed,
                                        ),
                                      );
                                    },
                                    child: const Text('Deploy NDRF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '${AppRoutes.citizenReports}/${item.id}');
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Review & Sanction', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardSwitchChip({
    required String label,
    required UserRole role,
    required String route,
    required UserRole activeRole,
  }) {
    final isSelected = activeRole == role;
    return ActionChip(
      avatar: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      backgroundColor: isSelected ? AppColors.primaryBlue : null,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onPressed: () {
        ref.read(activeRoleProvider.notifier).state = role;
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // ==========================================
  // MASTER ACCESS CONTROL & ROLE MANAGEMENT DIALOG
  // ==========================================
  void _openRoleManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final users = ref.watch(systemUsersProvider);
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.indigo, size: 26),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Main Admin Master Access & Role Management',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                              ),
                              Text(
                                'Create new role positions, change assigned roles, and control permission access.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Top Action: Create New Role Position
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Create New Official Position / Account', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        _showCreatePositionDialog(context);
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('REGISTERED USERS & ACTIVE ROLE PERMISSIONS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                    const SizedBox(height: 10),

                    // User List
                    Expanded(
                      child: ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final u = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getRoleColor(u.role).withOpacity(0.2),
                              child: Icon(_getRoleIcon(u.role), color: _getRoleColor(u.role), size: 18),
                            ),
                            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('${u.role.title} • ${u.badgeOrJurisdiction ?? u.district ?? "Global"}\nID: ${u.citizenId} • ${u.email}', style: const TextStyle(fontSize: 11)),
                            isThreeLine: true,
                            trailing: PopupMenuButton<UserRole>(
                              tooltip: 'Change User Role',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Change Role', style: TextStyle(color: Colors.indigo.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, size: 16, color: Colors.indigo),
                                  ],
                                ),
                              ),
                              itemBuilder: (context) => [
                                UserRole.citizen,
                                UserRole.volunteer,
                                UserRole.ngoLead,
                                UserRole.govtOfficial,
                                UserRole.rescueTeam,
                                UserRole.doctor,
                                UserRole.admin,
                              ].map((role) {
                                return PopupMenuItem<UserRole>(
                                  value: role,
                                  child: Text('${role.title} (${role.name})', style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onSelected: (newRole) {
                                ref.read(systemUsersProvider.notifier).updateUserRole(
                                  u.id,
                                  newRole,
                                  designation: '${newRole.title} Position',
                                  department: newRole == UserRole.admin ? 'SDMA Governance' : 'Disaster Relief Cell',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.successGreen,
                                    content: Text('✓ Changed ${u.name} role to ${newRole.title}. Access permissions updated.'),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreatePositionDialog(BuildContext parentContext) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'DDMA Revenue & Relief Desk');
    final desigCtrl = TextEditingController(text: 'Assistant Disaster Officer');
    final jurCtrl = TextEditingController(text: 'North East Delhi');
    UserRole selectedRole = UserRole.govtOfficial;

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create New Role Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Role Category *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 4),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: [
                    UserRole.citizen,
                    UserRole.volunteer,
                    UserRole.ngoLead,
                    UserRole.govtOfficial,
                    UserRole.rescueTeam,
                    UserRole.doctor,
                    UserRole.admin,
                  ].map((r) => DropdownMenuItem(value: r, child: Text(r.title, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Officer / Staff Full Name *', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Official Email *', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile Phone (+91) *', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department / Organization', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: desigCtrl, decoration: const InputDecoration(labelText: 'Official Designation / Position Title', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: jurCtrl, decoration: const InputDecoration(labelText: 'Jurisdiction District / Sector', border: OutlineInputBorder(), isDense: true)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade800, foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || (emailCtrl.text.trim().isEmpty && phoneCtrl.text.trim().isEmpty)) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(backgroundColor: AppColors.emergencyRed, content: Text('Please fill name and email/phone')),
                  );
                  return;
                }

                ref.read(systemUsersProvider.notifier).createUserPosition(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  role: selectedRole,
                  department: deptCtrl.text.trim(),
                  designation: desigCtrl.text.trim(),
                  jurisdiction: jurCtrl.text.trim(),
                );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.successGreen,
                    content: Text('✓ Created new role position for ${nameCtrl.text.trim()} as ${selectedRole.title}.'),
                  ),
                );
              },
              child: const Text('Provision Position'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin: return Colors.indigo;
      case UserRole.govtOfficial: return AppColors.criticalRed;
      case UserRole.rescueTeam: return Colors.orange;
      case UserRole.doctor: return Colors.pink;
      case UserRole.ngoLead: return Colors.teal;
      case UserRole.volunteer: return Colors.green;
      default: return AppColors.primaryBlue;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin: return Icons.security;
      case UserRole.govtOfficial: return Icons.account_balance;
      case UserRole.rescueTeam: return Icons.airport_shuttle;
      case UserRole.doctor: return Icons.local_hospital;
      case UserRole.ngoLead: return Icons.corporate_fare;
      case UserRole.volunteer: return Icons.handshake;
      default: return Icons.person;
    }
  }
}
