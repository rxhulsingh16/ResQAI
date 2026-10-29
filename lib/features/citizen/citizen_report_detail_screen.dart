import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/incident_model.dart';
import '../../shared/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/notification_client_service.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';

class CitizenReportDetailScreen extends ConsumerWidget {
  final String incidentId;

  const CitizenReportDetailScreen({super.key, required this.incidentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);
    final incident = incidents.firstWhere(
      (i) => i.id == incidentId,
      orElse: () => incidents.first,
    );

    final currentUser = ref.watch(authProvider);
    final activeRole = ref.watch(activeRoleProvider);
    final isAdminOrGov = currentUser?.role == UserRole.admin || activeRole == UserRole.admin || currentUser?.role == UserRole.govtOfficial || activeRole == UserRole.govtOfficial;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return AppShell(
      currentRoute: '${AppRoutes.citizenReports}/$incidentId',
      title: 'Report #${incident.id}',
      breadcrumbs: ['Citizen', 'Reports', incident.id],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. TOP HEADER BANNER
                _buildHeaderBanner(context, incident, isDark, isMobile),
                const SizedBox(height: 20),

                // 1.B SDMA COMMAND ACTION CONSOLE (WHEN VIEWED BY ADMIN / GOV)
                if (isAdminOrGov) ...[
                  _buildCommandActionConsole(context, ref, incident, isDark, isMobile),
                  const SizedBox(height: 20),
                ],

                // 1.C WORKFLOW CONNECTIVITY: CITIZEN VERIFICATION & DISPUTE CONSOLE (Workstream D)
                _buildConnectedWorkflowActionCard(context, ref, incident, currentUser, isDark, isMobile),
                const SizedBox(height: 20),

                // 2. 10-STAGE VERIFICATION TIMELINE
                _buildVerificationTimeline(context, incident, isDark),
                const SizedBox(height: 20),

                // 3. CASE REVIEW & SANCTION NOTES
                _buildReviewerNotesCard(context, incident, isDark),
                const SizedBox(height: 20),

                // 4. CLAIM DETAILS & ECONOMIC LOSS
                _buildClaimDetailsCard(context, incident, isDark, isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, IncidentModel incident, bool isDark, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_outlined, color: AppColors.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Case ID: ${incident.id}',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.deepNavy,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.successGreen.withOpacity(0.4)),
                      ),
                      child: Text(
                        incident.status.label.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.successGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  incident.title,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Location: ${incident.address} • Filed: ${incident.reportedAt.toLocal().toString().substring(0, 16)}',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationTimeline(BuildContext context, IncidentModel incident, bool isDark) {
    final stages = [
      {'title': 'Submitted', 'desc': 'Logged into intake queue', 'done': true},
      {'title': 'Under Review', 'desc': 'District Disaster Board review', 'done': incident.status != IncidentStatus.received},
      {'title': 'Verification Assigned', 'desc': 'Field Patwari allocated', 'done': incident.reviewerName != null},
      {'title': 'Verified', 'desc': 'Loss confirmed by inspector', 'done': incident.status == IncidentStatus.verified || incident.status == IncidentStatus.helpAssigned || incident.status == IncidentStatus.resolved},
      {'title': 'Assistance Sanctioned', 'desc': 'SDRF Grant Sanctioned', 'done': incident.status == IncidentStatus.verified || incident.status == IncidentStatus.helpAssigned || incident.status == IncidentStatus.resolved},
      {'title': 'Relief Delivered', 'desc': 'Direct Benefit Transfer / Kits', 'done': incident.status == IncidentStatus.resolved},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Official 6-Stage Relief Verification Progress',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 18),
          for (int i = 0; i < stages.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stages[i]['done'] as bool ? AppColors.successGreen : Colors.grey.withOpacity(0.3),
                      ),
                      child: Icon(
                        stages[i]['done'] as bool ? Icons.check : Icons.circle,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    if (i < stages.length - 1)
                      Container(
                        width: 2,
                        height: 32,
                        color: stages[i]['done'] as bool ? AppColors.successGreen : Colors.grey.withOpacity(0.3),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stages[i]['title'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: stages[i]['done'] as bool ? (isDark ? Colors.white : AppColors.deepNavy) : Colors.grey,
                          ),
                        ),
                        Text(
                          stages[i]['desc'] as String,
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewerNotesCard(BuildContext context, IncidentModel incident, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Authorized Officer Decision & Audit Record',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      incident.reviewerName ?? 'Dr. Rajeshwar Singh (ADM Relief)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      incident.reviewerRole ?? 'District Magistrate Relief Board',
                      style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Reason: ${incident.decisionReason ?? 'SDRF Gratuitous Cash Grant Sanctioned under Disaster Guidelines.'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Notes: ${incident.reviewerNotes ?? 'Field Patwari verified structural wall collapse and livestock casualty. Eligible for Gratuitous DBT relief grant.'}',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimDetailsCard(BuildContext context, IncidentModel incident, bool isDark, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Claimed Property & Economic Loss Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          Text(incident.descriptionOriginal, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _buildInfoBadge('Estimated Loss', '₹${incident.estimatedLossInr?.toStringAsFixed(0) ?? '0'}', AppColors.primaryBlue, isDark),
              _buildInfoBadge('Household Count', '${incident.householdMembersCount} Persons', Colors.purple, isDark),
              _buildInfoBadge('Priority Score', '${incident.priorityScore.toStringAsFixed(0)}/100', AppColors.emergencyRed, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

  Widget _buildConnectedWorkflowActionCard(
    BuildContext context,
    WidgetRef ref,
    IncidentModel incident,
    UserModel? currentUser,
    bool isDark,
    bool isMobile,
  ) {
    final isFoodOrAid = incident.source == 'CITIZEN_HELP_REQUEST' || incident.reliefRequirements.isNotEmpty;
    final isDamageClaim = incident.source == 'CITIZEN_DAMAGE_CLAIM' || incident.estimatedLossInr != null;
    final isMissingPerson = incident.category == IncidentCategory.missingPerson || incident.missingPersonsCount > 0;
    final isSos = incident.source == 'ONE_TAP_SOS';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_alt, color: AppColors.primaryGreen, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Live End-to-End Workflow Verification',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  incident.status.label.toUpperCase(),
                  style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // D1. Food / Aid / Supply Verification
          if (isFoodOrAid) ...[
            Text(
              'Current Status: ${incident.assistanceDeliveryStatus ?? "Processing at Regional NGO Hub"}.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (incident.acceptedBy != null)
              Text('Accepted by: ${incident.acceptedRole ?? "NGO"} ${incident.acceptedBy}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            if (incident.citizenReceiptConfirmed)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.successGreen, size: 16),
                    SizedBox(width: 6),
                    Text('Citizen has verified receipt of supplies. Case Closed ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.successGreen)),
                  ],
                ),
              )
            else if (incident.citizenReceiptDisputed)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.emergencyRed, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Disputed by Citizen: "${incident.citizenDisputeReason ?? "Not received"}". Reopened for review.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.emergencyRed)),
                    ),
                  ],
                ),
              )
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Confirm "I Received It"', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      ref.read(incidentsProvider.notifier).verifyReceiptByCitizen(
                        incident.id,
                        confirmed: true,
                        citizenName: currentUser?.name ?? 'Citizen',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.successGreen,
                          content: Text('✓ Thank you! Receipt confirmed. Incident closed successfully.'),
                        ),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.emergencyRed,
                      side: const BorderSide(color: AppColors.emergencyRed),
                    ),
                    icon: const Icon(Icons.error_outline, size: 16),
                    label: const Text('Not Received / Raise Dispute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      ref.read(incidentsProvider.notifier).verifyReceiptByCitizen(
                        incident.id,
                        confirmed: false,
                        disputeReason: 'Supplies have not arrived at given coordinates.',
                        citizenName: currentUser?.name ?? 'Citizen',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.emergencyRed,
                          content: Text('Dispute recorded. Case reopened and escalated to NGO & SDRF Command!'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],

          // D2. Missing Persons Joint Verification
          if (isMissingPerson) ...[
            const Text(
              'Joint Verification Protocol (Requires Family + Search Authority):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildVerificationBadge('Family Confirmed', incident.foundConfirmedByCitizen),
                const SizedBox(width: 12),
                _buildVerificationBadge('Authority Verified', incident.foundConfirmedByAuthority),
              ],
            ),
            const SizedBox(height: 12),
            if (incident.foundConfirmedByCitizen && incident.foundConfirmedByAuthority)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, color: AppColors.successGreen, size: 18),
                    SizedBox(width: 6),
                    Text('PERSON FOUND SAFE • Jointly Confirmed & Case Closed ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.successGreen)),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (!incident.foundConfirmedByCitizen)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.family_restroom, size: 16),
                      label: const Text('Family: Confirm Person Found Safe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        ref.read(incidentsProvider.notifier).confirmMissingPersonFoundByCitizen(
                          incident.id,
                          familyNotes: 'Family confirmed Rameshwar is safe at transit relief camp.',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.successGreen,
                            content: Text('Family verification recorded!'),
                          ),
                        );
                      },
                    ),
                  if (!incident.foundConfirmedByAuthority)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(color: AppColors.primaryBlue),
                      ),
                      icon: const Icon(Icons.security, size: 16),
                      label: const Text('Authority: Verify Person Identity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        ref.read(incidentsProvider.notifier).confirmMissingPersonFoundByAuthority(
                          incident.id,
                          officerName: currentUser?.name ?? 'Inspector Sharma (NDRF)',
                          officerRole: 'SAR Officer',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.primaryBlue,
                            content: Text('Official search authority verification recorded!'),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],

          // D3. Damage Claim DBT Disbursement Verification
          if (isDamageClaim && !isFoodOrAid && !isMissingPerson) ...[
            Text(
              'Statutory Relief Status: ${incident.assistanceDeliveryStatus ?? "Under Field Assessment"}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (incident.assistanceDeliveryStatus == 'DISBURSED' || incident.assistanceDeliveredInr != null) ...[
              if (incident.citizenReceiptConfirmed)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.successGreen, size: 16),
                      SizedBox(width: 6),
                      Text('Citizen verified DBT grant receipt in bank account. Case Closed ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.successGreen)),
                    ],
                  ),
                )
              else if (incident.citizenReceiptDisputed)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: AppColors.emergencyRed, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Disputed: "${incident.citizenDisputeReason ?? "Funds not received"}". Sent to Finance audit.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.emergencyRed)),
                      ),
                    ],
                  ),
                )
              else ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.verified, size: 16),
                      label: const Text('Confirm "Money Received via Bank"', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        ref.read(incidentsProvider.notifier).confirmClaimReceiptByCitizen(
                          incident.id,
                          received: true,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.successGreen,
                            content: Text('✓ Ex-gratia bank credit confirmed! Formal clearance recorded.'),
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emergencyRed,
                        side: const BorderSide(color: AppColors.emergencyRed),
                      ),
                      icon: const Icon(Icons.report_problem_outlined, size: 16),
                      label: const Text('Not Received / Raise Dispute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        ref.read(incidentsProvider.notifier).confirmClaimReceiptByCitizen(
                          incident.id,
                          received: false,
                          disputeReason: 'DBT bank credit not reflected in account after 48h.',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.emergencyRed,
                            content: Text('Dispute recorded. Case escalated to State Disaster Response Fund finance desk.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ],

          // D5. SOS Joint Rescue Confirmation
          if (isSos) ...[
            const Text(
              'Emergency Rescue Joint Protocol:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildVerificationBadge('Responder Arrived/Extracted', incident.sosRescuedConfirmedByResponder),
                const SizedBox(width: 12),
                _buildVerificationBadge('Citizen Safe Confirmed', incident.sosRescuedConfirmedByCitizen),
              ],
            ),
            const SizedBox(height: 12),
            if (incident.sosRescuedConfirmedByCitizen && incident.sosRescuedConfirmedByResponder)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.successGreen, size: 18),
                    SizedBox(width: 6),
                    Text('RESCUE MISSION COMPLETED & CLOSED BY BOTH PARTIES ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.successGreen)),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (!incident.sosRescuedConfirmedByCitizen)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.shield, size: 16),
                      label: const Text('Citizen: Confirm "I am Rescued & Safe"', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        ref.read(incidentsProvider.notifier).confirmSosRescuedByCitizen(incident.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.successGreen,
                            content: Text('✓ Safe rescue confirmation logged!'),
                          ),
                        );
                      },
                    ),
                  if (!incident.sosRescuedConfirmedByResponder)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryRed,
                        side: const BorderSide(color: AppColors.primaryRed),
                      ),
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Responder: Confirm Extraction Complete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        ref.read(incidentsProvider.notifier).confirmSosRescuedByResponder(
                          incident.id,
                          unitId: 'NDRF-Boat-04',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.primaryRed,
                            content: Text('Responder extraction recorded!'),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationBadge(String title, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? AppColors.successGreen.withOpacity(0.15) : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDone ? AppColors.successGreen : Colors.grey.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: isDone ? AppColors.successGreen : Colors.grey),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDone ? AppColors.successGreen : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandActionConsole(BuildContext context, WidgetRef ref, IncidentModel incident, bool isDark, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.primaryBlue.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: AppColors.primaryBlue, size: 22),
              const SizedBox(width: 8),
              const Text(
                'SDMA & Incident Command Decision Console',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AUTHORITY DESK', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Authorized SDMA Officers can verify ground claims, deploy rescue units, or sanction statutory DBT relief grants.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // 1. Sanction DBT Relief Grant
              if (incident.governmentAssistanceApproved != true)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.account_balance, size: 16),
                  label: const Text('Sanction Statutory Relief (DBT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    const amount = 50000.0;
                    ref.read(incidentsProvider.notifier).recordAssistanceSanction(
                      incident.id,
                      amount: amount,
                      category: 'SDRF Gratuitous Relief Grant',
                      reviewerName: 'Dr. Rajeshwar Singh (ADM Relief)',
                      reviewerId: 'GOV-DEL-001',
                    );
                    ref.read(incidentsProvider.notifier).recordAssistanceDisbursal(
                      incident.id,
                      amount,
                      bankRef: 'DBT-SDRF-' + DateTime.now().millisecondsSinceEpoch.toString(),
                    );
                    ref.read(notificationsProvider.notifier).addAlertNotification(
                      title: '💰 Statutory Relief Sanctioned (Case #' + incident.id + ')',
                      body: 'SDMA Relief Board sanctioned ₹50,000 Gratuitous Grant via Direct Benefit Transfer (DBT) to citizen account.',
                      severity: 'SUCCESS',
                      source: 'SDMA Incident Command',
                      type: 'SYSTEM',
                      direction: 'SENT',
                      status: 'DISBURSED',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Statutory Relief of ₹50,000 sanctioned & disbursed to citizen DBT account!'),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryGreen),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '₹' + (incident.sanctionedAmountInr?.toStringAsFixed(0) ?? "50000") + ' Disbursed via DBT ✓',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // 2. Deploy NDRF / SDRF Unit
              if (incident.status != IncidentStatus.helpAssigned && incident.status != IncidentStatus.resolved)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.directions_boat, size: 16),
                  label: const Text('Deploy NDRF Boat Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    ref.read(incidentsProvider.notifier).updateStatus(
                      incident.id,
                      IncidentStatus.helpAssigned,
                      team: 'NDRF 8th Bn Inflatable Boat Unit',
                    );
                    ref.read(notificationsProvider.notifier).addAlertNotification(
                      title: '🚨 NDRF Team Dispatched (Case #' + incident.id + ')',
                      body: 'NDRF 8th Bn Inflatable Boat Unit dispatched to ' + incident.address + '.',
                      severity: 'CRITICAL',
                      source: 'SDMA Incident Command',
                      type: 'SOS',
                      direction: 'SENT',
                      status: 'DISPATCHED',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('NDRF Boat Unit dispatched to incident location!'),
                        backgroundColor: AppColors.primaryRed,
                      ),
                    );
                  },
                ),

              // 3. Mark Physically Verified
              if (incident.status == IncidentStatus.received || incident.status == IncidentStatus.underReview)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.fact_check, size: 16),
                  label: const Text('Mark Ground-Verified', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    ref.read(incidentsProvider.notifier).recordVerificationDecision(
                      incident.id,
                      newStatus: IncidentStatus.verified,
                      reviewerId: 'ADM-DEL-04',
                      reviewerName: 'Dr. Rajeshwar Singh (ADM Relief)',
                      reviewerRole: 'District Magistrate Relief Desk',
                      notes: 'Field patwari verified structural damage and flood height on site.',
                      reason: 'Physical site visit confirmed genuine humanitarian distress.',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Case verified and confirmed genuine by Field Inspection!'),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
