import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import '../../data/repositories/auth_repository.dart';
import 'volunteer_portal_screen.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/incident_model.dart';
import '../../data/services/notification_client_service.dart';

class VolunteerDashboardScreen extends ConsumerStatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  ConsumerState<VolunteerDashboardScreen> createState() => _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends ConsumerState<VolunteerDashboardScreen> {
  bool _isAvailableForDispatch = true;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(volunteerTasksProvider);
    final user = ref.watch(authProvider);
    final incidents = ref.watch(incidentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    final acceptedTasks = tasks.where((t) => t.isAccepted && !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    return AppShell(
      currentRoute: AppRoutes.volunteerDashboard,
      title: 'Volunteer Operations Portal',
      breadcrumbs: const ['Volunteer', 'Dashboard'],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Welcome & Availability Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volunteer_activism, color: AppColors.primaryGreen, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Volunteer: ${user?.name ?? 'Ananya Deshmukh (Registered Volunteer)'}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Verified Skills: First Aid Certified, Bilingual • Service Radius: 8.0 km',
                              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _isAvailableForDispatch ? AppColors.primaryGreen : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isAvailableForDispatch ? 'STATUS: AVAILABLE FOR DISPATCH' : 'STATUS: CURRENTLY OFF-DUTY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isAvailableForDispatch ? AppColors.primaryGreen : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isAvailableForDispatch,
                        activeColor: AppColors.primaryGreen,
                        onChanged: (val) {
                          setState(() => _isAvailableForDispatch = val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val ? 'You are marked Available for emergency missions!' : 'You are now Off-Duty.'),
                              backgroundColor: val ? AppColors.primaryGreen : Colors.grey.shade700,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Service Hours & Missions Stats
            if (isMobile)
              Row(
                children: [
                  Expanded(child: _buildStatCard('ACCEPTED TASKS', '${acceptedTasks.length}', AppColors.primaryGreen, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard('COMPLETED', '${completedTasks.length}', AppColors.primaryRed, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard('SERVICE HRS', '${completedTasks.length * 4 + 12}h', const Color(0xFF0284C7), isDark)),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _buildStatCard('ACCEPTED TASKS', '${acceptedTasks.length}', AppColors.primaryGreen, isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildStatCard('COMPLETED MISSIONS', '${completedTasks.length}', AppColors.primaryRed, isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildStatCard('TOTAL SERVICE HOURS', '${completedTasks.length * 4 + 12} hrs', const Color(0xFF0284C7), isDark)),
                ],
              ),
            const SizedBox(height: 24),

            // Next Immediate Assignment Card with Status Flow
            if (acceptedTasks.isNotEmpty) ...[
              const Text('ACTIVE MISSION PROGRESSION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryGreen.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(color: AppColors.primaryGreen.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            acceptedTasks.first.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('EN ROUTE', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Location: ${acceptedTasks.first.location}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 14),

                    // 3-Stage Progression Indicator
                    Row(
                      children: [
                        _buildStepIndicator('Assigned', true, true),
                        _buildStepDivider(true),
                        _buildStepIndicator('On the way', true, false),
                        _buildStepDivider(false),
                        _buildStepIndicator('Completed', false, false),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(color: AppColors.primaryGreen),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.navigation, size: 16),
                          label: const Text('Navigate Route'),
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.disasterMap),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Complete & Upload Proof'),
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.volunteerTasks),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Live Citizen Aid Requirements Queue for Volunteers
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Live Citizen Relief Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${incidents.where((i) => i.status != IncidentStatus.resolved).length} Open in District', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final inc in incidents.where((i) => i.status != IncidentStatus.resolved).take(3)) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.handshake_outlined, color: AppColors.primaryGreen, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(inc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('${inc.address} • ${inc.category.label}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final isVolunteerAssigned = inc.assignedTeam?.contains('Volunteer') ?? false;
                              if (isVolunteerAssigned) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Claimed by You ✓', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                                );
                              }
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  final volName = user?.name ?? 'Volunteer';
                                  ref.read(incidentsProvider.notifier).updateStatus(inc.id, IncidentStatus.helpAssigned, team: 'Volunteer: ' + volName);
                                  ref.read(notificationsProvider.notifier).addAlertNotification(
                                    title: '🤝 Volunteer Dispatched for ' + inc.id,
                                    body: volName + ' accepted citizen relief request for "' + inc.title + '" at ' + inc.address + '.',
                                    severity: 'INFO',
                                    source: 'Volunteer Network',
                                    type: 'REQUIREMENT',
                                    direction: 'SENT',
                                    status: 'ACCEPTED & DISPATCHED',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Accepted task for "' + inc.title + '"! Dispatched as volunteer.'),
                                      backgroundColor: AppColors.primaryGreen,
                                    ),
                                  );
                                },
                                child: const Text('Volunteer to Assist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Opportunities Navigator
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.greenGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Discover Nearby Volunteer Opportunities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.volunteerTasks),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String label, bool isCompleted, bool isPast) {
    final color = isCompleted ? AppColors.primaryGreen : Colors.grey.shade400;
    return Column(
      children: [
        Icon(isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: color),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildStepDivider(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppColors.primaryGreen : Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
