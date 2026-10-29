import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import '../../data/repositories/incident_repository.dart';

class HomePortalScreen extends ConsumerWidget {
  const HomePortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);
    final shelters = ref.watch(sheltersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return AppShell(
      currentRoute: AppRoutes.home,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HERO BANNER WITH DIRECT EMERGENCY ACTIONS (NO HUGE DECORATIVE HERO)
            Container(
              padding: EdgeInsets.all(isMobile ? 20 : 28),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryBlue.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield, color: AppColors.primaryBlue, size: 14),
                            SizedBox(width: 6),
                            Text('UNIFIED DISASTER COORDINATION PLATFORM', style: TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('SYSTEM ONLINE • IMD LEVEL 3', style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'AI-Assisted Rescue, Relief, and Transparent Public Accountability',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connecting citizens, disaster victims, NGOs, field volunteers, and government authorities during emergencies.',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 15,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Immediate Action Buttons with Green & Pink Synergy
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.redGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: AppColors.primaryRed.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.emergency, size: 18),
                          label: const Text('Get Emergency SOS Help', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.citizenSos),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.greenGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: AppColors.primaryGreen.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('View Tactical Disaster Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.disasterMap),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.account_balance, size: 18),
                        label: const Text('Explore Public Transparency', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.transparency),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. LIVE SYSTEM STATS COUNTERS
            Row(
              children: [
                Expanded(child: _buildCounterCard('ACTIVE HAZARD INCIDENTS', '${incidents.length}', AppColors.criticalRed, isDark)),
                const SizedBox(width: 14),
                Expanded(child: _buildCounterCard('VERIFIED RELIEF SHELTERS', '${shelters.length}', AppColors.successGreen, isDark)),
                const SizedBox(width: 14),
                Expanded(child: _buildCounterCard('AVAILABLE SHELTER BEDS', '840 Beds', AppColors.primaryBlue, isDark)),
              ],
            ),
            const SizedBox(height: 28),

            // 3. HOW THE RESCUE & RELIEF LIFECYCLE WORKS
            Text('HOW RESQAI ORCHESTRATES DISASTER RELIEF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText)),
            const SizedBox(height: 12),
            if (isMobile) ...[
              Row(
                children: [
                  Expanded(child: _buildStepCard('1. Citizen SOS', 'Victim GPS coordinates ingested into emergency queue.', Icons.touch_app, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStepCard('2. AI Priority', 'Life-safety score calculated using water depth & elderly flags.', Icons.psychology, isDark)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildStepCard('3. Unit Dispatch', 'Nearest NDRF boat or SDRF vehicle dispatched via safe route.', Icons.directions_boat, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStepCard('4. Public Audit', 'Every relief delivery & grant published to the transparent ledger.', Icons.verified, isDark)),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildStepCard('1. Citizen 1-Tap SOS', 'Victim distress and GPS coordinates ingested into emergency queue.', Icons.touch_app, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStepCard('2. AI Prioritization', 'Life-safety score calculated using water depth & elderly flags.', Icons.psychology, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStepCard('3. Unit Dispatch', 'Nearest NDRF boat or SDRF ambulance assigned via optimal route.', Icons.directions_boat, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStepCard('4. Public Audit', 'Every relief delivery and expenditure published to the ledger.', Icons.verified, isDark)),
                ],
              ),
            ],
            const SizedBox(height: 28),

            // 4. STATUTORY SAFETY DISCLAIMER FOOTER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'DISASTER ADVISORY DISCLAIMER: ResQAI is an AI-assisted decision support system developed for disaster management and coordination. '
                'It operates alongside official emergency services, NDMA, and 112 emergency calls. '
                'In immediate life danger, always contact the national helpline at 112.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildStepCard(String title, String desc, IconData icon, bool isDark) {
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
          Icon(icon, color: AppColors.primaryBlue, size: 24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
