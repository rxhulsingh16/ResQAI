import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import '../../data/repositories/incident_repository.dart';
import '../../data/services/notification_client_service.dart';
import 'ngo_management_screen.dart';

class NgoDashboardScreen extends ConsumerWidget {
  const NgoDashboardScreen({super.key});

  void _showShareReportDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.rate_review, color: AppColors.primaryRed, size: 22),
            SizedBox(width: 8),
            Text('Share NGO Situation Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Headline / Operation Name',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. 500 Food Packets Dispatched in Sector 4',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Details & Relief Metrics',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Detail beneficiary counts, items delivered and warehouse reserve status...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Publish to EOC & Citizens',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              final title = titleCtrl.text.trim();
              final body = bodyCtrl.text.trim();
              if (title.isEmpty || body.isEmpty) return;

              ref.read(notificationsProvider.notifier).addAlertNotification(
                    title: '📋 NGO SitRep: $title',
                    body: body,
                    severity: 'INFO',
                    source: 'Goonj Foundation Relief Mission',
                    type: 'NGO_REPORT',
                    direction: 'SENT',
                    status: 'PUBLISHED',
                  );

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'NGO report successfully broadcasted to Incident Command & Citizens.'),
                  backgroundColor: AppColors.primaryGreen,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(ngoCampaignsProvider);
    final incidents = ref.watch(incidentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    final totalRaised =
        campaigns.fold<double>(0, (sum, c) => sum + c.raisedAmount);
    final totalSpent =
        campaigns.fold<double>(0, (sum, c) => sum + c.spentAmount);

    final openRequests = incidents.take(3).toList();

    return AppShell(
      currentRoute: AppRoutes.ngoDashboard,
      title: 'NGO Operations Command',
      breadcrumbs: const ['NGO', 'Dashboard'],
      child: SingleChildScrollView(
        padding:
            EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top DARPAN Verification Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user,
                        color: AppColors.successGreen, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Goonj Foundation Relief Mission (DARPAN: DL/2021/0088192)',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Authorized Relief Operator • Designated Operation Zones: East Delhi & Yamuna Basin',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Operations Action Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text('Share Situation Report',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _showShareReportDialog(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(
                          color: AppColors.primaryGreen, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.volunteer_activism, size: 18),
                    label: const Text('New Relief Campaign',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.ngoCampaigns),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4-Card Metrics Grid
            if (isMobile) ...[
              Row(
                children: [
                  Expanded(
                      child: _buildKpiCard(
                          'DONATIONS AUDITED',
                          '₹${totalRaised.toStringAsFixed(0)}',
                          AppColors.primaryGreen,
                          isDark)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildKpiCard(
                          'RELIEF DISBURSED',
                          '₹${totalSpent.toStringAsFixed(0)}',
                          AppColors.primaryRed,
                          isDark)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _buildKpiCard(
                          'ACTIVE CAMPAIGNS',
                          '${campaigns.length}',
                          AppColors.primaryBlue,
                          isDark)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildKpiCard(
                          'OPEN REQUESTS',
                          '${incidents.length}',
                          AppColors.warningOrange,
                          isDark)),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                      child: _buildKpiCard(
                          'DONATIONS AUDITED',
                          '₹${totalRaised.toStringAsFixed(0)}',
                          AppColors.primaryGreen,
                          isDark)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: _buildKpiCard(
                          'RELIEF DISBURSED',
                          '₹${totalSpent.toStringAsFixed(0)}',
                          AppColors.primaryRed,
                          isDark)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: _buildKpiCard(
                          'ACTIVE CAMPAIGNS',
                          '${campaigns.length}',
                          AppColors.primaryBlue,
                          isDark)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: _buildKpiCard(
                          'OPEN REQUESTS',
                          '${incidents.length}',
                          AppColors.warningOrange,
                          isDark)),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // Live Citizen Aid Requests & Emergency Queue
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nearby Citizen Aid Requirements',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${incidents.length} Pending Delivery',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryRed)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final inc in openRequests) ...[
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
                            child: const Icon(Icons.inventory_2_outlined,
                                color: AppColors.primaryGreen, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(inc.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('${inc.address} • ${inc.category.label}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Aid request for "${inc.title}" accepted! Dispatched Goonj relief team.'),
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                              );
                            },
                            child: const Text('Accept & Supply',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11)),
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

            // Quick Operations Navigation
            Row(
              children: [
                Expanded(
                  child: _buildNavCard(
                    context,
                    title: 'Relief Campaigns',
                    subtitle: 'Manage fundraising & target relief packets',
                    icon: Icons.volunteer_activism,
                    route: AppRoutes.ngoCampaigns,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNavCard(
                    context,
                    title: 'Financial Ledger',
                    subtitle: 'Log tax invoices, vendor receipts & GSTIN proof',
                    icon: Icons.receipt_long,
                    route: AppRoutes.ngoFinances,
                    isDark: isDark,
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNavCard(
                      context,
                      title: 'Warehouse Reserves',
                      subtitle: 'Inventory counts, rations & medical packs',
                      icon: Icons.inventory_2,
                      route: AppRoutes.ngoResources,
                      isDark: isDark,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildNavCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 24),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
