import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/incident_model.dart';
import '../../shared/widgets/truth_badge_widget.dart';
import '../ngo/ngo_management_screen.dart';
import '../volunteer/volunteer_portal_screen.dart';

class AreaResourceAllocation {
  final String areaName;
  final String district;
  final int affectedPeopleEstimated;
  final double foodCoveragePercent;
  final double waterCoveragePercent;
  final double medicalCoveragePercent;
  final double shelterCoveragePercent;
  final String primaryShortage;
  final String primarySurplus;
  final String recommendedRedirection;
  bool isAllocationLocked;

  AreaResourceAllocation({
    required this.areaName,
    required this.district,
    required this.affectedPeopleEstimated,
    required this.foodCoveragePercent,
    required this.waterCoveragePercent,
    required this.medicalCoveragePercent,
    required this.shelterCoveragePercent,
    required this.primaryShortage,
    required this.primarySurplus,
    required this.recommendedRedirection,
    this.isAllocationLocked = false,
  });
}

final areaAllocationsProvider = StateNotifierProvider<AreaAllocationsNotifier, List<AreaResourceAllocation>>((ref) {
  return AreaAllocationsNotifier();
});

class AreaAllocationsNotifier extends StateNotifier<List<AreaResourceAllocation>> {
  AreaAllocationsNotifier() : super(_initialAllocations());

  static List<AreaResourceAllocation> _initialAllocations() {
    return [
      AreaResourceAllocation(
        areaName: 'Yamuna Khadar Lowland Ward 4',
        district: 'East Delhi',
        affectedPeopleEstimated: 1250,
        foodCoveragePercent: 115.0, // Surplus food
        waterCoveragePercent: 42.0,  // Severe water deficit
        medicalCoveragePercent: 55.0,
        shelterCoveragePercent: 78.0,
        primaryShortage: 'Drinking Water & Water Filters',
        primarySurplus: 'Dry Food Packets (+15% Over-Covered)',
        recommendedRedirection: 'Divert upcoming food supplies to Kashmere Gate Sector 2. Dispatch 2,000L drinking water bowsers here immediately.',
        isAllocationLocked: true,
      ),
      AreaResourceAllocation(
        areaName: 'Kashmere Gate Lowland Enclave',
        district: 'North Delhi',
        affectedPeopleEstimated: 680,
        foodCoveragePercent: 48.0,  // Food shortage
        waterCoveragePercent: 92.0,  // Adequate water
        medicalCoveragePercent: 40.0, // Medical shortage
        shelterCoveragePercent: 65.0,
        primaryShortage: 'Cooked Meals & Diabetic Insulin',
        primarySurplus: 'Packaged Mineral Water (92% Covered)',
        recommendedRedirection: 'Accept food packets diverted from Yamuna Khadar. Request CMO medical team for elderly diabetic insulin kits.',
        isAllocationLocked: false,
      ),
      AreaResourceAllocation(
        areaName: 'Shakarpur Drainage Basin Ward 6',
        district: 'East Delhi',
        affectedPeopleEstimated: 840,
        foodCoveragePercent: 88.0,
        waterCoveragePercent: 75.0,
        medicalCoveragePercent: 85.0,
        shelterCoveragePercent: 35.0, // Heavy shelter shortage
        primaryShortage: 'Emergency Tarpaulins & Elevated Tents',
        primarySurplus: 'General First Aid Dressings',
        recommendedRedirection: 'Requisition 200 tarpaulins from SDRF Rohini Depot. Route displaced families to Mayur Vihar Community Hall.',
        isAllocationLocked: false,
      ),
    ];
  }

  void toggleLock(String areaName) {
    state = [
      for (final a in state)
        if (a.areaName == areaName)
          AreaResourceAllocation(
            areaName: a.areaName,
            district: a.district,
            affectedPeopleEstimated: a.affectedPeopleEstimated,
            foodCoveragePercent: a.foodCoveragePercent,
            waterCoveragePercent: a.waterCoveragePercent,
            medicalCoveragePercent: a.medicalCoveragePercent,
            shelterCoveragePercent: a.shelterCoveragePercent,
            primaryShortage: a.primaryShortage,
            primarySurplus: a.primarySurplus,
            recommendedRedirection: a.recommendedRedirection,
            isAllocationLocked: !a.isAllocationLocked,
          )
        else
          a
    ];
  }
}

class PublicTransparencyPortalScreen extends ConsumerStatefulWidget {
  const PublicTransparencyPortalScreen({super.key});

  @override
  ConsumerState<PublicTransparencyPortalScreen> createState() => _PublicTransparencyPortalScreenState();
}

class _PublicTransparencyPortalScreenState extends ConsumerState<PublicTransparencyPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _caseSearchController = TextEditingController();
  IncidentModel? _searchedCase;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _caseSearchController.dispose();
    super.dispose();
  }

  void _searchCase(List<IncidentModel> incidents, dynamic currentUser) {
    final query = _caseSearchController.text.trim().toUpperCase();
    if (query.isEmpty) return;

    setState(() {
      _hasSearched = true;
      try {
        _searchedCase = incidents.firstWhere((i) => i.id.toUpperCase() == query);
      } catch (_) {
        _searchedCase = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ngoCampaigns = ref.watch(ngoCampaignsProvider);
    final ngoTransactions = ref.watch(ngoTransactionsProvider);
    final volunteerTasks = ref.watch(volunteerTasksProvider);
    final incidents = ref.watch(incidentsProvider);
    final allocations = ref.watch(areaAllocationsProvider);
    final currentUser = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance, color: AppColors.mintGreen, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Public Transparency & Relief Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Open Humanitarian Audit, SDRF Records & Resource Coordination', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: const TruthBadgeWidget(type: TruthBadgeType.piiMasked, customText: 'DPDP PII PROTECTED'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primaryGreen,
          indicatorWeight: 3,
          labelColor: AppColors.mintGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.corporate_fare, size: 18), text: 'NGO Transparency'),
            Tab(icon: Icon(Icons.account_balance, size: 18), text: 'Govt SDRF Spending'),
            Tab(icon: Icon(Icons.volunteer_activism, size: 18), text: 'Volunteer Impact'),
            Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Citizen Relief & Case Tracker'),
            Tab(icon: Icon(Icons.balance, size: 18), text: 'Anti-Duplication Matrix'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNgoTransparencyTab(ngoCampaigns, ngoTransactions),
          _buildGovernmentSpendingTab(),
          _buildVolunteerImpactTab(volunteerTasks),
          _buildCitizenReliefAndTrackingTab(incidents, currentUser),
          _buildAntiDuplicationMatrixTab(allocations),
        ],
      ),
    );
  }

  // TAB 1: NGO Transparency (Part 11.A)
  Widget _buildNgoTransparencyTab(List<NgoCampaign> campaigns, List<NgoFinancialTransaction> txs) {
    final totalRaised = campaigns.fold<double>(0.0, (s, c) => s + c.raisedAmount);
    final totalSpent = campaigns.fold<double>(0.0, (s, c) => s + c.spentAmount);
    final totalCommitted = campaigns.fold<double>(0.0, (s, c) => s + c.committedAmount);
    final totalBeneficiaries = campaigns.fold<int>(0, (s, c) => s + c.verifiedBeneficiariesReached);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.infoBlue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: AppColors.infoBlue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Part 11.A Public NGO Ledger: Only verified non-profit organizations with active DARPAN and Section 80G registrations publish expenditures here. Every voucher has an auditable tax invoice number.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // High-level aggregate cards
          Row(
            children: [
              _metricSummaryCard('Verified Donations', '₹${(totalRaised / 100000).toStringAsFixed(1)}L', AppColors.verifiedGreen),
              const SizedBox(width: 8),
              _metricSummaryCard('Verified Expenditures', '₹${(totalSpent / 100000).toStringAsFixed(1)}L', AppColors.criticalRed),
              const SizedBox(width: 8),
              _metricSummaryCard('Committed Orders', '₹${(totalCommitted / 100000).toStringAsFixed(1)}L', AppColors.warningAmber),
              const SizedBox(width: 8),
              _metricSummaryCard('Families Assisted', '$totalBeneficiaries', Colors.lightBlueAccent),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Verified NGO Relief Campaigns & Published Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: campaigns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = campaigns[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        const TruthBadgeWidget(type: TruthBadgeType.verifiedSafe, customText: 'DARPAN REG: DL/2019/024810'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(c.objective, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Raised: ₹${(c.raisedAmount / 100000).toStringAsFixed(1)}L', style: const TextStyle(fontSize: 12, color: AppColors.verifiedGreen, fontWeight: FontWeight.bold)),
                        Text('Audited Spent: ₹${(c.spentAmount / 100000).toStringAsFixed(1)}L', style: const TextStyle(fontSize: 12, color: AppColors.criticalRed, fontWeight: FontWeight.bold)),
                        Text('Beneficiaries Reached: ${c.verifiedBeneficiariesReached}', style: const TextStyle(fontSize: 12, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: c.inKindNeeds.map((need) => Chip(
                        label: Text(need, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.darkSurfaceCard,
                      )).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          const Text('Public Voucher Records (Invoices & Receipts)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tx = txs[index];
              final isCredit = tx.transactionType == 'DONATION_RECEIVED';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? AppColors.verifiedGreen : AppColors.criticalRed, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${tx.category} • ${tx.entityName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Ref: ${tx.transactionRef} • Invoice: ${tx.invoiceNumber}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(
                      '${isCredit ? "+" : "-"}₹${tx.amount.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isCredit ? AppColors.verifiedGreen : AppColors.criticalRed),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // TAB 2: Government SDRF Spending (Part 10 & 11.C)
  Widget _buildGovernmentSpendingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.criticalRed.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.account_balance, color: AppColors.warningAmber, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'State Disaster Response Fund (SDRF) Expenditure Disclosure: Statutory reporting under Section 48 of DM Act 2005. Distinguishes Allocated, Released, and Audited Spend.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SDRF Fund Ledger Cards
          Row(
            children: [
              _metricSummaryCard('SDRF Allocation', '₹50.0 Lakhs', Colors.white),
              const SizedBox(width: 8),
              _metricSummaryCard('Funds Released', '₹35.0 Lakhs', Colors.lightBlueAccent),
              const SizedBox(width: 8),
              _metricSummaryCard('Audited Invoices', '₹19.45 Lakhs', AppColors.verifiedGreen),
              const SizedBox(width: 8),
              _metricSummaryCard('Pending Audit', '₹15.55 Lakhs', AppColors.warningAmber),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Government Relief Sanction Programs (District East Delhi)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          _govtProgramCard(
            'Gratuitous Immediate Relief & Nutrition Grant',
            '₹10,000 direct DBT per severely affected household for cooking utensils, clothes and dry rations.',
            '₹12.50 Lakhs Disbursed',
            '125 Families Credited',
            AppColors.verifiedGreen,
          ),
          const SizedBox(height: 10),
          _govtProgramCard(
            'Mobile Water Tanker & Sanitation Desilting Contracts',
            'Emergency deployment of 18 water tankers (Delhi Jal Board) and 4 heavy mud desilting pumps.',
            '₹4.20 Lakhs Spent',
            'Contract Ref: DJB/DISASTER/2026/014',
            Colors.lightBlueAccent,
          ),
          const SizedBox(height: 10),
          _govtProgramCard(
            'Emergency Camp Shelter Operation & Community Kitchens',
            'Running 3 centralized community relief camps providing three meals daily with round-the-clock medical desk.',
            '₹2.75 Lakhs Spent',
            'Food Supplies via Central Civil Supplies Depot',
            AppColors.warningAmber,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // TAB 3: Volunteer Impact (Part 11.B)
  Widget _buildVolunteerImpactTab(List<VolunteerTask> tasks) {
    final completedTasks = tasks.where((t) => t.isCompleted).toList();
    final inProgressTasks = tasks.where((t) => t.isAccepted && !t.isCompleted).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.verifiedGreen.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.volunteer_activism, color: AppColors.verifiedGreen, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Community Volunteers Transparency: Summarizes humanitarian tasks fulfilled on the ground. Volunteer home addresses, private mobile numbers, and personal PII are strictly protected.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _metricSummaryCard('Registered Volunteers', '412 Volunteers', AppColors.primaryLight),
              const SizedBox(width: 8),
              _metricSummaryCard('Verified Tasks Closed', '${completedTasks.length} Completed', AppColors.verifiedGreen),
              const SizedBox(width: 8),
              _metricSummaryCard('Active In-Field', '${inProgressTasks.length} Active', AppColors.warningAmber),
              const SizedBox(width: 8),
              _metricSummaryCard('Hot Meals Served', '4,850 Meals', Colors.white),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Recent Verified Field Deliveries by Citizens & Volunteers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final t = tasks[index];
              final isDone = t.isCompleted;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDone ? AppColors.verifiedGreen.withOpacity(0.4) : Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDone ? AppColors.verifiedGreen.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isDone ? 'COMPLETED & VERIFIED' : (t.isAccepted ? 'IN PROGRESS' : 'UNASSIGNED'),
                            style: TextStyle(color: isDone ? AppColors.verifiedGreen : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(t.id, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Spacer(),
                        Text(t.category, style: const TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Sector: ${t.location}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (t.deliveryProofNote != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurfaceCard,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.verifiedGreen, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Proof: ${t.deliveryProofNote}', style: const TextStyle(fontSize: 11, color: Colors.white70))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // TAB 4: Citizen Relief & Case Tracker (Part 11.D & 11.E)
  Widget _buildCitizenReliefAndTrackingTab(List<IncidentModel> incidents, dynamic currentUser) {
    final damageClaims = incidents.where((i) => i.source == 'DAMAGE_REPORT').toList();
    final totalReported = damageClaims.length;
    final totalVerified = damageClaims.where((i) => i.status == IncidentStatus.verified || i.status == IncidentStatus.helpAssigned || i.status == IncidentStatus.resolved).length;
    final totalAssistanceSanctioned = damageClaims.where((i) => i.governmentAssistanceApproved == true).length;
    final pendingReview = damageClaims.where((i) => i.status == IncidentStatus.received || i.status == IncidentStatus.pendingReview || i.status == IncidentStatus.underReview).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aggregate statistics (Part 11.D - strictly privacy preserving)
          const Text('Affected Person Aggregate Assistance Statistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('DPDP Compliant Aggregate Metrics: Tracks claims, field inspection status, and assistance sanctioned.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 12),

          Row(
            children: [
              _metricSummaryCard('Claims Submitted', '$totalReported', Colors.white),
              const SizedBox(width: 8),
              _metricSummaryCard('Field Verified', '$totalVerified', AppColors.verifiedGreen),
              const SizedBox(width: 8),
              _metricSummaryCard('Relief Sanctioned', '$totalAssistanceSanctioned', Colors.lightBlueAccent),
              const SizedBox(width: 8),
              _metricSummaryCard('Pending Review', '$pendingReview', AppColors.warningAmber),
            ],
          ),
          const SizedBox(height: 24),

          // Individual Authenticated Case Tracker (Part 11.E)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.infoBlue.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.infoBlue, size: 22),
                    const SizedBox(width: 8),
                    const Text('Track Your Private Disaster Relief Case', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                      child: const Text('AUTHENTICATED LOOKUP', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Enter your unique Case Reference ID (e.g., RQ-DMG-001 or INC-2026-001) to view field verification stage and government sanction status.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _caseSearchController,
                        decoration: InputDecoration(
                          hintText: 'Enter Case ID (e.g. RQ-DMG-001)',
                          filled: true,
                          fillColor: AppColors.darkSurfaceCard,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.infoBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Track Case'),
                      onPressed: () => _searchCase(incidents, currentUser),
                    ),
                  ],
                ),

                if (_hasSearched) ...[
                  const SizedBox(height: 16),
                  if (_searchedCase != null)
                    _buildCaseResultCard(_searchedCase!)
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.criticalRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.criticalRed.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.criticalRed, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Case Reference ID not found. Verify the reference on your submission receipt, or check whether the application was saved as a local draft.',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // TAB 5: Smart Resource Allocation & Anti-Duplication Matrix (Part 14)
  Widget _buildAntiDuplicationMatrixTab(List<AreaResourceAllocation> allocations) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warningAmber.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.balance, color: AppColors.warningAmber, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Part 14 Intelligent Matching Rule: Prevents duplicate aid distribution (e.g. food surplus while water is deficient). Dispatches are atomic and locked to prevent simultaneous double-fulfillment.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allocations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final a = allocations[index];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: a.isAllocationLocked ? AppColors.warningAmber.withOpacity(0.4) : Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(a.areaName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Text('(${a.district})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const Spacer(),
                        Chip(
                          backgroundColor: a.isAllocationLocked ? AppColors.warningAmber.withOpacity(0.2) : Colors.white12,
                          side: BorderSide(color: a.isAllocationLocked ? AppColors.warningAmber : Colors.transparent),
                          avatar: Icon(a.isAllocationLocked ? Icons.lock : Icons.lock_open, size: 14, color: a.isAllocationLocked ? AppColors.warningAmber : Colors.grey),
                          label: Text(
                            a.isAllocationLocked ? 'DISPATCH LOCKED' : 'OPEN FOR ALLOCATION',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: a.isAllocationLocked ? AppColors.warningAmber : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Estimated Population Exposed: ${a.affectedPeopleEstimated} Residents', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 14),

                    // 4 Resource Coverage Bars
                    _resourceBar('Drinking Water', a.waterCoveragePercent),
                    const SizedBox(height: 6),
                    _resourceBar('Emergency Food Rations', a.foodCoveragePercent),
                    const SizedBox(height: 6),
                    _resourceBar('Medical Kits & Anti-Venom', a.medicalCoveragePercent),
                    const SizedBox(height: 6),
                    _resourceBar('Emergency Tents & Tarpaulins', a.shelterCoveragePercent),
                    const SizedBox(height: 14),

                    // AI-Assisted Recommendation Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology, color: AppColors.unverifiedPurple, size: 18),
                              const SizedBox(width: 8),
                              const Text('Smart Resource Allocation Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.unverifiedPurple)),
                              const Spacer(),
                              Text('Surplus: ${a.primarySurplus}', style: const TextStyle(fontSize: 10, color: AppColors.verifiedGreen, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(a.recommendedRedirection, style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4)),
                          const SizedBox(height: 4),
                          Text('Priority Shortage: ${a.primaryShortage}', style: const TextStyle(fontSize: 11, color: AppColors.criticalRed, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: Icon(a.isAllocationLocked ? Icons.lock_open : Icons.lock, size: 14),
                          label: Text(a.isAllocationLocked ? 'Unlock Consignments' : 'Lock Dispatch (Prevent Duplicates)', style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            ref.read(areaAllocationsProvider.notifier).toggleLock(a.areaName);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${a.areaName} status changed to ${!a.isAllocationLocked ? "DISPATCH LOCKED" : "UNLOCKED"}.'),
                                backgroundColor: !a.isAllocationLocked ? AppColors.warningAmber : AppColors.verifiedGreen,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _resourceBar(String name, double percent) {
    final isSurplus = percent > 100;
    final isCritical = percent < 50;
    final color = isSurplus ? AppColors.primaryLight : (isCritical ? AppColors.criticalRed : AppColors.verifiedGreen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text('${percent.toInt()}% Covered ${isSurplus ? "(SURPLUS)" : ""}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildCaseResultCard(IncidentModel caseModel) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.verifiedGreen.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.verifiedGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(caseModel.id, style: const TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(caseModel.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              _caseStatusBadge(caseModel.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(caseModel.descriptionOriginal, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 10),

          // Detailed Status Pipeline
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_edu, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Reviewer: ${caseModel.reviewerName ?? "State Review Board"} (${caseModel.reviewerRole ?? "District Triage Desk"})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                if (caseModel.decisionReason != null) ...[
                  const SizedBox(height: 4),
                  Text('Official Finding: ${caseModel.decisionReason}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                ],
                if (caseModel.governmentAssistanceApproved == true) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.verifiedGreen, size: 16),
                      const SizedBox(width: 6),
                      Text('Assistance Sanctioned: ₹${caseModel.sanctionedAmountInr?.toStringAsFixed(0) ?? "10,000"} (${caseModel.reliefAssistanceCategory ?? "SDRF Gratuitous Grant"})', style: const TextStyle(color: AppColors.verifiedGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricSummaryCard(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _govtProgramCard(String title, String desc, String spend, String beneficiaries, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(spend, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Text('Audit Scope: $beneficiaries', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _caseStatusBadge(IncidentStatus status) {
    Color color;
    switch (status) {
      case IncidentStatus.verified:
      case IncidentStatus.resolved:
        color = AppColors.verifiedGreen;
        break;
      case IncidentStatus.helpAssigned:
      case IncidentStatus.inProgress:
        color = AppColors.warningAmber;
        break;
      default:
        color = Colors.lightBlueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
