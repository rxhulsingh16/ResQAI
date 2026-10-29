import '../../data/services/app_update_service.dart';
import '../../data/services/app_version_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import '../../data/repositories/incident_repository.dart';

class CitizenHelpScreen extends ConsumerStatefulWidget {
  const CitizenHelpScreen({super.key});

  @override
  ConsumerState<CitizenHelpScreen> createState() => _CitizenHelpScreenState();
}

class _CitizenHelpScreenState extends ConsumerState<CitizenHelpScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Life Safety',
    'Supplies & Food',
    'Shelter & Medical',
    'Damage & Claims',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final incidents = ref.watch(incidentsProvider);

    final myRequests = incidents
        .where((i) =>
            i.source == 'CITIZEN_HELP_REQUEST' ||
            i.source == 'CITIZEN_DAMAGE_CLAIM' ||
            i.source == 'ONE_TAP_SOS' ||
            i.source == 'CITIZEN_WEB')
        .take(2)
        .toList();

    final categories = _getAssistanceCategories();
    final filteredCategories = categories.where((cat) {
      final matchesSearch = cat.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cat.subtitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cat.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesFilter = _selectedFilter == 'All' || cat.group == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return AppShell(
      currentRoute: AppRoutes.citizenHelp,
      title: 'Disaster Assistance Hub',
      breadcrumbs: const ['Citizen', 'Help Hub'],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 28,
          vertical: isMobile ? 16 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER & DISTINCTION BANNER
            _buildHeader(context, isDark, isMobile),
            const SizedBox(height: 16),

            // 2. CRITICAL DISTINCTION CARDS (SOS vs Request Help vs Report Damage)
            _buildUrgentTriageRow(context, isMobile, isDark),
            const SizedBox(height: 20),

            // 3. SEARCH & GROUP FILTER BAR
            _buildSearchAndFilters(context, isDark),
            const SizedBox(height: 16),

            // 4. CATEGORY GRID / LIST
            Text(
              'Disaster Assistance Categories (${filteredCategories.length})',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 12),

            if (filteredCategories.isEmpty)
              _buildEmptySearchResults(isDark)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final int crossAxisCount = constraints.maxWidth >= 1024
                      ? 3
                      : (constraints.maxWidth >= 640 ? 2 : 1);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredCategories.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 180,
                    ),
                    itemBuilder: (context, index) {
                      return _buildCategoryCard(context, filteredCategories[index], isDark);
                    },
                  );
                },
              ),
            const SizedBox(height: 24),

            // 5. MY ACTIVE REQUESTS QUICK STATUS
            if (myRequests.isNotEmpty) ...[
              _buildActiveRequestsQuickBar(context, myRequests, isDark),
              const SizedBox(height: 20),
            ],

            // 6. 24x7 STATUTORY EMERGENCY HELPLINES BAR
            _buildHelplinesBanner(context, isDark, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.support_agent, color: AppColors.primaryGreen, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Citizen Disaster Assistance Portal',
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the specific help your household needs. Life-safety SOS is prioritized above long-form damage claims.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentTriageRow(BuildContext context, bool isMobile, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;

        final items = [
          _TriageAction(
            title: 'Emergency SOS',
            subtitle: 'Immediate life extraction',
            desc: 'Trapped, rising flood, severe injury. Rapid 2-tap GPS dispatch.',
            badge: 'IMMEDIATE',
            badgeColor: AppColors.primaryRed,
            icon: Icons.emergency,
            buttonText: 'Activate SOS',
            buttonColor: AppColors.primaryRed,
            gradient: AppColors.redGradient,
            onTap: () => Navigator.pushNamed(context, AppRoutes.citizenSos),
          ),
          _TriageAction(
            title: 'Request Help',
            subtitle: 'Essential relief supplies',
            desc: 'Food packets, clean water, medicines, tarpaulins, evacuation.',
            badge: '5-STEP FORM',
            badgeColor: AppColors.primaryGreen,
            icon: Icons.handshake_outlined,
            buttonText: 'Request Supplies',
            buttonColor: AppColors.primaryGreen,
            gradient: AppColors.greenGradient,
            onTap: () => Navigator.pushNamed(context, AppRoutes.citizenHelpRequest),
          ),
          _TriageAction(
            title: 'Report Damage',
            subtitle: 'SDRF assistance claims',
            desc: 'House destroyed, crops submerged, livestock loss, vital documents.',
            badge: 'RELIEF GRANT',
            badgeColor: AppColors.warningOrange,
            icon: Icons.assignment_turned_in_outlined,
            buttonText: 'File Loss Claim',
            buttonColor: AppColors.warningOrange,
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () => Navigator.pushNamed(context, AppRoutes.citizenNewReport),
          ),
        ];

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((action) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildTriageCard(action, isDark),
                ),
              );
            }).toList(),
          );
        } else {
          return Column(
            children: items.map((action) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTriageCard(action, isDark),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildTriageCard(_TriageAction action, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: action.buttonColor.withOpacity(0.3), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: action.buttonColor.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.buttonColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.buttonColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: action.badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: action.badgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  action.badge,
                  style: TextStyle(
                    color: action.badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            action.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.deepNavy,
            ),
          ),
          Text(
            action.subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: action.buttonColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            action.desc,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: action.gradient,
              color: action.gradient == null ? action.buttonColor : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: action.buttonColor.withOpacity(0.32),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: action.gradient != null ? Colors.transparent : action.buttonColor,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: action.onTap,
              child: Text(
                action.buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search assistance (e.g. food, water, boat, tent, doctor, missing)...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSel = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSel,
                  selectedColor: AppColors.primaryGreen.withOpacity(0.18),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? AppColors.primaryGreen : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  onSelected: (v) => setState(() => _selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, _AssistanceCategory cat, bool isDark) {
    return InkWell(
      onTap: () => cat.onTap(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cat.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(cat.icon, color: cat.accentColor, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.deepNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                cat.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cat.actionLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cat.accentColor,
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 12, color: cat.accentColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchResults(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 36, color: Colors.grey),
            SizedBox(height: 8),
            Text('No assistance categories match your search.', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Try searching for food, water, boat, tent, medicine, or missing person.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRequestsQuickBar(BuildContext context, List<dynamic> requests, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, size: 18, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text('My Active Requests & Submissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.citizenReports),
                child: const Text('View All Tracking ↗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...requests.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '${AppRoutes.citizenReports}/${r.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${r.id} • ${r.title}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            r.status.label,
                            style: const TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  bool _isCheckingUpdates = false;

  void _callHelpline(BuildContext context, String name, String number) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk, color: AppColors.emergencyRed, size: 24),
            const SizedBox(width: 8),
            Text(name),
          ],
        ),
        content: Text('Dial official toll-free statutory emergency helpline: $number\n\nDispatch connects immediately to nearest state control room.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergencyRed,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call, size: 16),
            label: Text('Call $number'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.primaryBlue,
                  content: Text('Dialing $name ($number)... Keep line clear for dispatch operator.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHelplinesBanner(BuildContext context, bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Helplines card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.deepNavy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.contact_phone, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('24x7 Official Emergency Helplines (Tap to Connect)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _buildInteractiveHelplineChip(context, 'NDRF Control', '1078'),
                  _buildInteractiveHelplineChip(context, 'National Emergency', '112'),
                  _buildInteractiveHelplineChip(context, 'Disaster Mgmt', '1070'),
                  _buildInteractiveHelplineChip(context, 'Ambulance', '108'),
                  _buildInteractiveHelplineChip(context, 'Fire Services', '101'),
                  _buildInteractiveHelplineChip(context, 'Childline', '1098'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. Expandable Frequently Asked Questions (FAQ) Section
        _buildFaqSection(isDark),
        const SizedBox(height: 18),

        // 3. App Version & Update Card (Workstream C Requirement)
        _buildAppVersionCard(context, isDark, isMobile),
      ],
    );
  }

  Widget _buildInteractiveHelplineChip(BuildContext context, String name, String number) {
    return InkWell(
      onTap: () => _callHelpline(context, name, number),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              '$name: $number',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqSection(bool isDark) {
    final faqs = [
      {
        'q': 'How does the 2-Tap Emergency SOS function work?',
        'a': 'Tapping Instant SOS arms your device GPS coordinates and transmits high-priority distress alerts directly to the NDRF/SDRF tactical command center and nearby field patrol units within seconds, even on 2G connections.',
      },
      {
        'q': 'Who receives my request for food, water, and medicines?',
        'a': 'Requests are routed simultaneously to all verified DARPAN-registered NGOs and the District EOC. Any active responder can accept, mark in-transit, and deliver with live timeline tracking.',
      },
      {
        'q': 'How do I report a missing family member?',
        'a': 'Use the Report Missing Person form. The report is distributed to search and rescue (SAR) teams. Once located, both the reporting family and the search authority must confirm before the case is closed.',
      },
      {
        'q': 'How do SDRF disaster damage claims and ex-gratia payouts work?',
        'a': 'Citizens file loss reports with photos. Revenue Patwari and SDMA officers inspect and approve the statutory ex-gratia amount. Funds are credited via Direct Benefit Transfer (DBT), after which you verify receipt.',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.help_center_outlined, color: AppColors.primaryBlue),
        title: const Text(
          'Frequently Asked Questions & Emergency Protocols',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: const Text('Statutory disaster rights, relief delivery & tracking', style: TextStyle(fontSize: 11, color: Colors.grey)),
        children: faqs.map((f) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
              const SizedBox(height: 3),
              Text(f['a']!, style: const TextStyle(fontSize: 12, height: 1.4)),
              const Divider(height: 12),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildAppVersionCard(BuildContext context, bool isDark, bool isMobile) {
    final currentVersion = ref.watch(appVersionProvider);

    return InkWell(
      onTap: _isCheckingUpdates
          ? null
          : () async {
              setState(() => _isCheckingUpdates = true);
              try {
                await AppUpdateService.checkForUpdates(context, ref: ref);
              } finally {
                if (mounted) setState(() => _isCheckingUpdates = false);
              }
            },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: _isCheckingUpdates
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                    )
                  : const Icon(Icons.system_update_alt, color: AppColors.primaryGreen, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ResQAI v$currentVersion (Build 150)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Production Stable • Disaster Response Framework • Tap to check updates',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isCheckingUpdates ? 'Checking...' : 'Check Updates',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_AssistanceCategory> _getAssistanceCategories() {
    return [
      _AssistanceCategory(
        title: 'Food & Drinking Water',
        subtitle: 'Cooked meal packets, dry ration kits, water tanker bowsers, or water chlorine tablets.',
        group: 'Supplies & Food',
        icon: Icons.water_drop_outlined,
        accentColor: AppColors.primaryBlue,
        actionLabel: 'Request Food/Water',
        tags: ['food', 'water', 'ration', 'drinking', 'rice', 'dal'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenHelpRequest),
      ),
      _AssistanceCategory(
        title: 'Temporary Shelter & Camps',
        subtitle: 'Find verified district relief camps with bed availability or request waterproof tarpaulins.',
        group: 'Shelter & Medical',
        icon: Icons.night_shelter_outlined,
        accentColor: AppColors.successGreen,
        actionLabel: 'Locate Shelters',
        tags: ['shelter', 'camp', 'tarpaulin', 'tent', 'roof', 'stay'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenShelters),
      ),
      _AssistanceCategory(
        title: 'Medicines & Medical Care',
        subtitle: 'Urgent prescription drugs, first aid dressing, anti-venom, ORS packets, hospital triage.',
        group: 'Shelter & Medical',
        icon: Icons.medical_services_outlined,
        accentColor: AppColors.emergencyRed,
        actionLabel: 'Request Medicines',
        tags: ['medical', 'medicine', 'doctor', 'first aid', 'hospital', 'injury', 'ors'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenHelpRequest),
      ),
      _AssistanceCategory(
        title: 'Rescue & Evacuation Boat',
        subtitle: 'Inflatable tactical boat extraction for cut-off families trapped by rising flood waters.',
        group: 'Life Safety',
        icon: Icons.directions_boat_outlined,
        accentColor: Colors.deepOrange,
        actionLabel: 'Request Rescue Boat',
        tags: ['boat', 'rescue', 'evacuate', 'trapped', 'water', 'submerged'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenSos),
      ),
      _AssistanceCategory(
        title: 'Missing Family Member',
        subtitle: 'Confidential tracing report routed directly to NDRF and State Police search units.',
        group: 'Life Safety',
        icon: Icons.person_search,
        accentColor: AppColors.emergencyRed,
        actionLabel: 'Report Missing Person',
        tags: ['missing', 'family', 'child', 'person', 'lost', 'separated', 'search'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenMissingPerson),
      ),
      _AssistanceCategory(
        title: 'Home & Property Damage',
        subtitle: 'Document pucca/kutcha structural collapse and inundation for SDRF grant assessment.',
        group: 'Damage & Claims',
        icon: Icons.home_work_outlined,
        accentColor: Colors.indigo,
        actionLabel: 'File Damage Claim',
        tags: ['home', 'damage', 'house', 'collapse', 'wall', 'submerged', 'property'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenNewReport),
      ),
      _AssistanceCategory(
        title: 'Lost or Damaged Documents',
        subtitle: 'Fast-track, fee-exempt reissuance of Aadhaar, NFSA ration card, voter ID, land records.',
        group: 'Damage & Claims',
        icon: Icons.file_copy_outlined,
        accentColor: AppColors.warningOrange,
        actionLabel: 'Report Lost Documents',
        tags: ['documents', 'aadhaar', 'ration card', 'voter id', 'certificate', 'passbook'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenNewReport),
      ),
      _AssistanceCategory(
        title: 'Financial Relief & Ex-Gratia',
        subtitle: 'Direct Benefit Transfer (DBT) gratuitous relief applications under Disaster Management norms.',
        group: 'Damage & Claims',
        icon: Icons.currency_rupee,
        accentColor: AppColors.verifiedGreen,
        actionLabel: 'Apply for Relief Grant',
        tags: ['financial', 'money', 'grant', 'ex gratia', 'dbt', 'sdrf', 'compensation'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenNewReport),
      ),
      _AssistanceCategory(
        title: 'Clothing, Blankets & Living Kits',
        subtitle: 'Warm woollen blankets, dry clothing sets, solar lamps, sleeping mats, sanitary napkins.',
        group: 'Supplies & Food',
        icon: Icons.checkroom_outlined,
        accentColor: Colors.teal,
        actionLabel: 'Request Living Kits',
        tags: ['clothing', 'blanket', 'clothes', 'sanitary', 'lamp', 'hygiene'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenHelpRequest),
      ),
      _AssistanceCategory(
        title: 'Agricultural & Livestock Loss',
        subtitle: 'Report standing crop inundation, animal fodder requirements, livestock casualty relief.',
        group: 'Damage & Claims',
        icon: Icons.agriculture_outlined,
        accentColor: Colors.brown,
        actionLabel: 'Report Crop/Cattle Loss',
        tags: ['crops', 'agriculture', 'livestock', 'cattle', 'buffalo', 'cow', 'farmer', 'fodder'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenNewReport),
      ),
      _AssistanceCategory(
        title: 'Disability & Senior Support',
        subtitle: 'Wheelchairs, walking aids, specialized transport, adult diapers, chronic illness meds.',
        group: 'Shelter & Medical',
        icon: Icons.accessible_outlined,
        accentColor: Colors.purple,
        actionLabel: 'Request Special Care',
        tags: ['disability', 'elderly', 'wheelchair', 'senior', 'handicapped', 'special care'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenHelpRequest),
      ),
      _AssistanceCategory(
        title: 'Transport & Safe Evacuation',
        subtitle: 'Relocation assistance to designated high-ground embankments or out-of-district transit.',
        group: 'Life Safety',
        icon: Icons.directions_bus_outlined,
        accentColor: Colors.blueGrey,
        actionLabel: 'Request Transport',
        tags: ['transport', 'bus', 'vehicle', 'evacuation', 'transit', 'move'],
        onTap: (ctx) => Navigator.pushNamed(ctx, AppRoutes.citizenHelpRequest),
      ),
    ];
  }
}

class _TriageAction {
  final String title;
  final String subtitle;
  final String desc;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final String buttonText;
  final Color buttonColor;
  final Gradient? gradient;
  final VoidCallback onTap;

  _TriageAction({
    required this.title,
    required this.subtitle,
    required this.desc,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.buttonText,
    required this.buttonColor,
    this.gradient,
    required this.onTap,
  });
}

class _AssistanceCategory {
  final String title;
  final String subtitle;
  final String group;
  final IconData icon;
  final Color accentColor;
  final String actionLabel;
  final List<String> tags;
  final void Function(BuildContext) onTap;

  _AssistanceCategory({
    required this.title,
    required this.subtitle,
    required this.group,
    required this.icon,
    required this.accentColor,
    required this.actionLabel,
    required this.tags,
    required this.onTap,
  });
}
