import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/incident_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/models/incident_model.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import '../../shared/widgets/interactive_sos_button.dart';

class CitizenSosScreen extends ConsumerStatefulWidget {
  const CitizenSosScreen({super.key});

  @override
  ConsumerState<CitizenSosScreen> createState() => _CitizenSosScreenState();
}

class _CitizenSosScreenState extends ConsumerState<CitizenSosScreen>
    with SingleTickerProviderStateMixin {
  // Emergency parameters
  IncidentCategory _emergencyCategory = IncidentCategory.flood;
  int _peopleAffected = 3;
  bool _medicalAttentionRequired = false;
  bool _elderlyOrInfantsTrapped = true;
  String _locationName = 'Hindon Basin, Ghaziabad';
  double _latitude = 28.6480;
  double _longitude = 77.3450;

  // Activation & Submission state
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isArmed = false;
  int _remainingSeconds = 5;
  Timer? _countdownTimer;
  bool _isSubmitting = false;

  // Submitted request details
  bool _isSubmitted = false;
  String? _incidentRef;
  DateTime? _submittedTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onSosButtonPressed() {
    if (!_isArmed) {
      setState(() {
        _isArmed = true;
        _remainingSeconds = 5;
      });
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_remainingSeconds > 1) {
          setState(() => _remainingSeconds--);
        } else {
          timer.cancel();
          setState(() => _isArmed = false);
        }
      });
    } else {
      _countdownTimer?.cancel();
      _submitSos();
    }
  }

  Future<void> _submitSos() async {
    setState(() {
      _isSubmitting = true;
      _isArmed = false;
    });

    final refId = 'RQ-SOS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final user = ref.read(authProvider);

    final sosIncident = IncidentModel(
      id: refId,
      title: 'EMERGENCY SOS: ${_emergencyCategory.name.toUpperCase()} - $_peopleAffected Trapped',
      descriptionOriginal: 'Direct emergency SOS signal transmitted. Location: $_locationName. '
          '$_peopleAffected persons trapped. ${_medicalAttentionRequired ? "Immediate medical triage needed. " : ""}'
          '${_elderlyOrInfantsTrapped ? "Infants or elderly on scene." : ""}',
      descriptionTranslated: 'Direct emergency SOS signal transmitted. Location: $_locationName. '
          '$_peopleAffected persons trapped.',
      category: _emergencyCategory,
      latitude: _latitude,
      longitude: _longitude,
      address: '$_locationName (${_latitude.toStringAsFixed(4)}°N, ${_longitude.toStringAsFixed(4)}°E)',
      status: IncidentStatus.verified,
      priorityScore: 96.0,
      priorityExplanation: 'Critical life-safety distress signal from monitored flood zone',
      vulnerableGroups: [
        if (_elderlyOrInfantsTrapped) 'Elderly/Infants',
        if (_medicalAttentionRequired) 'Critical Injury',
      ],
      reporterPhoneMasked: user?.phoneMasked ?? '+91 98*** **112',
      reportedAt: DateTime.now(),
      source: 'ONE_TAP_SOS',
      householdMembersCount: _peopleAffected,
      reliefRequirements: [
        'Evacuation Boat',
        if (_medicalAttentionRequired) 'Paramedic Support',
      ],
    );

    // Persist to central Riverpod state and local database
    ref.read(incidentsProvider.notifier).addIncident(sosIncident);

    await Future.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _isSubmitted = true;
      _incidentRef = refId;
      _submittedTime = DateTime.now();
    });
  }

  void _showLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Confirm Distress Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.my_location, color: AppColors.primaryBlue),
                title: const Text('Hindon Basin, Ghaziabad (Current GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('28.6480° N, 77.3450° E • ±6m accuracy', style: TextStyle(fontSize: 12)),
                onTap: () {
                  setState(() {
                    _locationName = 'Hindon Basin, Ghaziabad';
                    _latitude = 28.6480;
                    _longitude = 77.3450;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                title: const Text('Kaushambi Lowland Crossing'),
                subtitle: const Text('28.6250° N, 77.3150° E', style: TextStyle(fontSize: 12)),
                onTap: () {
                  setState(() {
                    _locationName = 'Kaushambi Lowland Crossing';
                    _latitude = 28.6250;
                    _longitude = 77.3150;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                title: const Text('Yamuna Khadar Embankment, East Delhi'),
                subtitle: const Text('28.6200° N, 77.2650° E', style: TextStyle(fontSize: 12)),
                onTap: () {
                  setState(() {
                    _locationName = 'Yamuna Khadar Embankment, East Delhi';
                    _latitude = 28.6200;
                    _longitude = 77.2650;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleClose(BuildContext context) async {
    if (_isSubmitting || _isArmed) {
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 24),
              SizedBox(width: 8),
              Text('Cancel SOS?'),
            ],
          ),
          content: const Text(
            'An emergency SOS distress signal is currently in progress. Are you sure you want to cancel transmission?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Sending'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergencyRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      );

      if (shouldCancel == true) {
        _countdownTimer?.cancel();
        if (_incidentRef != null) {
          ref.read(incidentsProvider.notifier).updateStatus(_incidentRef!, IncidentStatus.rejected);
        }
        setState(() {
          _isArmed = false;
          _isSubmitting = false;
        });
        _returnToHomeOrBack();
      }
      return;
    }

    _returnToHomeOrBack();
  }

  void _returnToHomeOrBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      final role = ref.read(activeRoleProvider);
      Navigator.pushReplacementNamed(context, AppRouter.getHomeRouteForRole(role));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleClose(context);
        }
      },
      child: AppShell(
        currentRoute: AppRoutes.citizenSos,
        title: 'Emergency SOS',
        breadcrumbs: const ['Citizen', 'Emergency SOS'],
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: isMobile ? 16 : 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _isSubmitted
                  ? _buildIncidentStatusView(isDark, isMobile)
                  : _buildEmergencyToolView(isDark, isMobile),
            ),
          ),
        ),
      ),
    );
  }

  // 1. FOCUSED PURPOSE-BUILT EMERGENCY TOOL VIEW
  Widget _buildEmergencyToolView(bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Close (X) Header
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 20, color: isDark ? Colors.white : AppColors.deepNavy),
            ),
            tooltip: 'Close Emergency Screen',
            onPressed: () => _handleClose(context),
          ),
        ),
        const SizedBox(height: 4),
        // Clear emergency heading
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.emergencyRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency, color: AppColors.emergencyRed, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'PRIORITY EMERGENCY LINK',
                    style: TextStyle(
                      color: AppColors.emergencyRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Emergency Rescue Request',
              style: TextStyle(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.deepNavy,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Transmits live coordinates directly to State EOC & Patrol Units',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Prominent Interactive Circular SOS Control with Radar Ripple & Hold-to-Activate
        Center(
          child: InteractiveSosButton(
            mode: SosButtonMode.circle,
            width: 140,
            localityName: _locationName,
            isSubmitting: _isSubmitting,
            activeIncidentId: _isSubmitted ? _incidentRef : null,
            onTriggered: _submitSos,
            onCancel: () {
              setState(() {
                _isSubmitted = false;
                _incidentRef = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Distress beacon cancelled.')),
              );
            },
          ),
        ),
        const SizedBox(height: 26),

        // Location Selector Pill
        InkWell(
          onTap: () => _showLocationPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distress Coordinates (Live GPS)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      Text(
                        '$_locationName (${_latitude.toStringAsFixed(4)}°N, ${_longitude.toStringAsFixed(4)}°E)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.deepNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_location_alt_outlined, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Concise Emergency Type Selection
        Text(
          'EMERGENCY NATURE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCategoryChip('Flood / Inundation', IncidentCategory.flood, Icons.water),
            _buildCategoryChip('Medical Trauma', IncidentCategory.medical, Icons.medical_services),
            _buildCategoryChip('Building Collapse', IncidentCategory.landslide, Icons.home_work),
            _buildCategoryChip('Fire Hazard', IncidentCategory.fire, Icons.local_fire_department),
            _buildCategoryChip('Evacuation Needed', IncidentCategory.cyclone, Icons.directions_run),
          ],
        ),
        const SizedBox(height: 20),

        // Immediate Medical or Rescue Needs
        Text(
          'IMMEDIATE NEEDS & HEADCOUNT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('People Trapped on Scene:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: _peopleAffected > 1 ? () => setState(() => _peopleAffected--) : null,
                  ),
                  Text(
                    '$_peopleAffected',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () => setState(() => _peopleAffected++),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2 High-Priority Life-Safety Toggles
        _buildTogglePill(
          title: 'Infants, Elderly, or Pregnant Persons Trapped',
          value: _elderlyOrInfantsTrapped,
          onChanged: (v) => setState(() => _elderlyOrInfantsTrapped = v),
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildTogglePill(
          title: 'Immediate Paramedic Triage / Severe Bleeding',
          value: _medicalAttentionRequired,
          onChanged: (v) => setState(() => _medicalAttentionRequired = v),
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // Short Explanation & Toll-Free 112 Dial Link
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                  const SizedBox(width: 6),
                  const Text('Direct EOC Telemetry Disclosure', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Confirming transmits your verified GPS coordinates, distress tags, and trapped headcount to the Central Disaster Control Room. '
                'For voice escalation, dial 112 (National Emergency Helpline).',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, IncidentCategory cat, IconData icon) {
    final isSelected = _emergencyCategory == cat;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primaryBlue),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.emergencyRed,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      onSelected: (val) {
        if (val) setState(() => _emergencyCategory = cat);
      },
    );
  }

  Widget _buildTogglePill({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? AppColors.emergencyRed.withOpacity(0.08)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? AppColors.emergencyRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: value ? AppColors.emergencyRed : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: value ? FontWeight.bold : FontWeight.w500,
                  color: value ? AppColors.emergencyRed : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. DEDICATED HONEST INCIDENT STATUS SCREEN
  Widget _buildIncidentStatusView(bool isDark, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Close (X) Header
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 20, color: isDark ? Colors.white : AppColors.deepNavy),
            ),
            tooltip: 'Return to Dashboard',
            onPressed: () => _handleClose(context),
          ),
        ),
        const SizedBox(height: 4),
        // Verified Success Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.successGreen.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.successGreen.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
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
                    decoration: const BoxDecoration(
                      color: AppColors.successGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distress Request Transmitted',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Logged in Central Disaster Management Queue',
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Reference & Submission Details
              _buildDetailRow('Incident Reference:', _incidentRef ?? 'RQ-SOS-8419', isHighlight: true),
              _buildDetailRow('Reported Coordinates:', '$_locationName (${_latitude.toStringAsFixed(4)}°N, ${_longitude.toStringAsFixed(4)}°E)'),
              _buildDetailRow('Submission Time:', '${_submittedTime?.hour.toString().padLeft(2, '0')}:${_submittedTime?.minute.toString().padLeft(2, '0')} (Just now)'),
              _buildDetailRow('Trapped Headcount:', '$_peopleAffected Persons (${_emergencyCategory.name.toUpperCase()})'),
              _buildDetailRow(
                'Assigned Unit:',
                'Pending field responder acceptance (Unassigned)',
                isWarning: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Real-Time Request Lifecycle Status
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Real-Time Dispatch Progression',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _buildProgressionStep(
                title: '1. Request Received at EOC',
                subtitle: 'Logged and stored in NDMA centralized dispatch repository.',
                isDone: true,
                isActive: false,
              ),
              _buildProgressionStep(
                title: '2. GPS Triage & Radius Match',
                subtitle: 'Sector coordinates matched with Hindon Basin relief corridor.',
                isDone: true,
                isActive: false,
              ),
              _buildProgressionStep(
                title: '3. Field Unit Alert & Acceptance',
                subtitle: 'Transmitted to nearest active boat unit. Awaiting responder confirmation.',
                isDone: false,
                isActive: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Relevant Safety Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFB78103), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Vital Safety Instructions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7A5500)),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '• Move to highest accessible ground or terrace.\n'
                '• Conserve phone battery; turn off video streaming and high-power apps.\n'
                '• Do not attempt to walk or drive through moving flood waters.\n'
                '• Wave a bright cloth or whistle if rescue vessels approach.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5C4000), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.phone, size: 18),
                label: const Text('Dial 112 Helpline', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dialing 112 (National Emergency Helpline)...')),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Back to Live Map'),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.citizenDashboard);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                color: isHighlight
                    ? AppColors.deepNavy
                    : (isWarning ? AppColors.warningOrange : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionStep({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppColors.successGreen
                  : (isActive ? AppColors.warningOrange : Colors.grey.shade300),
            ),
            child: Icon(
              isDone ? Icons.check : (isActive ? Icons.hourglass_top : Icons.circle),
              size: 11,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: (isDone || isActive) ? FontWeight.bold : FontWeight.w500,
                    color: isDone
                        ? AppColors.successGreen
                        : (isActive ? AppColors.warningOrange : Colors.grey),
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
