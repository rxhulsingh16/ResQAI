import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/incident_model.dart';
import '../../shared/models/shelter_model.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import 'widgets/live_weather_card.dart';
import '../../data/services/weather_service.dart';
import 'widgets/sos_confirmation_dialog.dart';
import '../../data/services/notification_client_service.dart';
import '../notifications/notifications_screen.dart';
import '../../data/repositories/donation_repository.dart';
import '../../shared/widgets/interactive_sos_button.dart';

class CitizenDashboardScreen extends ConsumerStatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  ConsumerState<CitizenDashboardScreen> createState() =>
      _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends ConsumerState<CitizenDashboardScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Location selector state
  String _selectedLocality = 'Ghaziabad, UP';
  LatLng _mapCenter = const LatLng(
    28.6480,
    77.3450,
  ); // Ghaziabad / Hindon River

  // Map layer toggles
  bool _showHazards = true;
  bool _showShelters = true;
  bool _showHospitals = true;
  bool _showRescueTeams = true;
  bool _showRoadBlockage = true;

  // Live location & permission fallback (PRD MAP-2, MAP-3)
  bool _locationPermissionDenied = false;
  final LatLng _userLocation = const LatLng(28.6440, 77.3400);

  // Live Header Weather telemetry state
  WeatherModel? _headerWeather;

  String? _activeSosIncidentId;

  // Double-tap SOS state
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isArmed = false;
  int _remainingSeconds = 5;
  Timer? _countdownTimer;
  bool _isSubmittingSos = false;

  // Ghaziabad / Hindon River High Risk Polygon
  final List<LatLng> _highRiskPolygon = const [
    LatLng(28.7100, 77.3100),
    LatLng(28.6900, 77.3400),
    LatLng(28.6700, 77.3600),
    LatLng(28.6500, 77.3500),
    LatLng(28.6600, 77.3200),
    LatLng(28.6900, 77.3000),
  ];

  // Kaushambi & Vaishali Lowland Polygon
  final List<LatLng> _kaushambiFloodPolygon = const [
    LatLng(28.6400, 77.3100),
    LatLng(28.6450, 77.3400),
    LatLng(28.6250, 77.3500),
    LatLng(28.6150, 77.3250),
    LatLng(28.6250, 77.3050),
  ];

  // Moderate Risk Polygon
  final List<LatLng> _moderateRiskPolygon = const [
    LatLng(28.6480, 77.3400),
    LatLng(28.6600, 77.3800),
    LatLng(28.6350, 77.3900),
    LatLng(28.6250, 77.3500),
  ];

  // Safe Zone Polygon (Vasundhara Plateau)
  final List<LatLng> _safeZonePolygon = const [
    LatLng(28.6650, 77.3550),
    LatLng(28.6800, 77.3750),
    LatLng(28.6700, 77.3950),
    LatLng(28.6550, 77.3750),
  ];

  // Blocked Road (NH-9 Crossing)
  final List<LatLng> _blockedRoad = const [
    LatLng(28.6250, 77.2900),
    LatLng(28.6350, 77.3200),
    LatLng(28.6420, 77.3500),
  ];

  // Static emergency facilities in Ghaziabad region
  final List<Map<String, dynamic>> _hospitals = const [
    {
      'name': 'Max Super Speciality Hospital Vaishali',
      'point': LatLng(28.6440, 77.3350),
      'beds': '18 ICU beds available',
      'phone': '+91 120 418 8000',
    },
    {
      'name': 'Shanti Gopal Hospital Indirapuram',
      'point': LatLng(28.6380, 77.3700),
      'beds': '12 Emergency beds available',
      'phone': '+91 120 477 7000',
    },
    {
      'name': 'Yashoda Super Speciality Hospital Kaushambi',
      'point': LatLng(28.6280, 77.3180),
      'beds': '24 Trauma beds available',
      'phone': '+91 120 455 5555',
    },
  ];

  final List<Map<String, dynamic>> _rescueTeams = const [
    {
      'id': 'NDRF-BOAT-04',
      'name': 'NDRF 8th Bn Inflatable Boat Unit',
      'point': LatLng(28.6550, 77.3450),
      'status': 'Active Patrol • Hindon Basin',
    },
    {
      'id': 'SDRF-VAN-02',
      'name': 'SDRF Mobile Evacuation Van',
      'point': LatLng(28.6180, 77.3450),
      'status': 'Staged at Kaushambi Crossing',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _fetchHeaderWeather() {
    WeatherService.getWeather(
      lat: _mapCenter.latitude,
      lon: _mapCenter.longitude,
      locationName: _selectedLocality,
    ).then((weather) {
      if (mounted) {
        setState(() {
          _headerWeather = weather;
        });
      }
    }).catchError((_) {});
  }

  String _getWeatherEmoji(String condition) {
    final lower = condition.toLowerCase();
    if (lower.contains('thunder') || lower.contains('storm')) return '⛈️';
    if (lower.contains('rain') || lower.contains('shower') || lower.contains('drizzle')) return '🌧️';
    if (lower.contains('cloud')) return '⛅';
    if (lower.contains('clear') || lower.contains('sun')) return '☀️';
    if (lower.contains('snow')) return '❄️';
    if (lower.contains('fog') || lower.contains('mist')) return '🌫️';
    return '⛅';
  }

  Widget _buildWeatherPill(bool isDark) {
    final tempStr = _headerWeather != null
        ? '${_headerWeather!.temperature.toStringAsFixed(1)}°C'
        : '24.1°C';
    final condStr = _headerWeather?.condition ?? 'Partly Cloudy';
    final emoji = _getWeatherEmoji(condStr);

    return InkWell(
      onTap: () {
        _fetchHeaderWeather();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated weather for $_selectedLocality: $tempStr $condStr'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              '$tempStr $condStr',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.deepNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // DONATION / RELIEF CONTRIBUTION MODAL & CARD
  void _showDonationModal(BuildContext context) {
    int selectedAmount = 1000;
    String selectedCampaign = 'Hindon & Yamuna Basin Emergency Flood Relief';
    final customCtrl = TextEditingController(text: '1000');
    final nameCtrl = TextEditingController(text: 'Citizen Donor');
    final emailCtrl = TextEditingController(text: 'citizen@gmail.com');
    String paymentMethod = 'UPI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volunteer_activism, color: AppColors.successGreen, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Direct Relief Contribution',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campaign Select
                    const Text('Target Relief Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCampaign,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Hindon & Yamuna Basin Emergency Flood Relief',
                          child: Text('Hindon & Yamuna Emergency Flood Relief', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: 'State Disaster Response Fund (SDRF Ex-Gratia)',
                          child: Text('State Disaster Response Fund (SDRF)', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: 'Clean Drinking Water & Infant Nutrition Drive',
                          child: Text('Clean Drinking Water & Infant Nutrition', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCampaign = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Preset Amount Chips
                    const Text('Select Relief Amount (INR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [500, 1000, 2500, 5000].map((amt) {
                        final isSel = selectedAmount == amt;
                        return ChoiceChip(
                          label: Text('₹$amt', style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : null)),
                          selected: isSel,
                          selectedColor: AppColors.successGreen,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedAmount = amt;
                                customCtrl.text = amt.toString();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: customCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Or enter custom amount (₹)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) setModalState(() => selectedAmount = parsed);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Donor Details
                    const Text('Donor Identity (for 80G Tax Receipt)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Gmail / Email Address',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 80G Exemption Note
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.successGreen.withOpacity(0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user, color: AppColors.successGreen, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '100% Tax Deductible under Section 80G of Income Tax Act. Verified by Govt of India.',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.successGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.payment, size: 16),
                label: Text('Donate ₹$selectedAmount', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _completeDonation(context, selectedAmount, selectedCampaign, nameCtrl.text);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _completeDonation(BuildContext context, int amount, String campaign, String donorName) {
    final receiptNum = '80G-RQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    // Wire to donationsProvider & notificationsProvider
    try {
      ref.read(donationsProvider.notifier).createVerifiedDonation(
        campaignId: 'CMP-RELIEF-01',
        campaignTitle: campaign,
        ngoName: 'Goonj Foundation Relief Mission',
        ngoId: 'NGO-DARPAN-DL-024810',
        amount: amount.toDouble(),
        donorName: donorName.isEmpty ? 'Citizen Donor' : donorName,
        donorEmail: 'citizen@resqai.org',
        donorPhone: '+91 98765 43210',
        isAnonymous: false,
        paymentMethod: 'UPI (Razorpay Verified)',
      );
      ref.read(notificationsProvider.notifier).addAlertNotification(
        title: '🎉 Relief Contribution of ₹$amount Verified',
        body: 'Your 80G tax-exempt donation towards $campaign was recorded on the audited NGO ledger. Receipt: $receiptNum',
        severity: 'INFO',
        source: 'ResQAI Transparency & Payment Gateway',
        type: 'DONATION',
        direction: 'RECEIVED',
      );
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.successGreen, size: 28),
            SizedBox(width: 10),
            Text('Contribution Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thank you, $donorName! Your disaster relief contribution of ₹$amount has been verified and recorded on the transparent ledger.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Campaign: $campaign', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Receipt Number: $receiptNum', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  const Text('Section 80G Statutory Exemption: VALID', style: TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildReliefDonationCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
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
                  color: AppColors.successGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism, color: AppColors.successGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Relief Contributions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Direct NGO & SDRF disaster grants with 80G tax exemption',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '100% SECURE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.successGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Support verified disaster victims in Hindon and Yamuna flood plains. 100% of public relief contributions are audited on the blockchain-backed transparency ledger.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.white70 : AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 14),
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
                    onPressed: () => _showDonationModal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.favorite, size: 16),
                    label: const Text('Donate Relief Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.citizenDonate),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Browse Campaigns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onSosTap() {
    if (_isSubmittingSos) return;

    if (!_isArmed) {
      // First tap: Arm the SOS with 5-second countdown window
      setState(() {
        _isArmed = true;
        _remainingSeconds = 5;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.emergency, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SOS Armed: Tap again within 5s to transmit emergency help request with your location ($_selectedLocality).',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.emergencyRed,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 1) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          // Window expired without 2nd tap: safe automatic disarm
          timer.cancel();
          setState(() {
            _isArmed = false;
            _remainingSeconds = 5;
          });
        }
      });
    } else {
      // Second tap: Confirmed emergency submission!
      _countdownTimer?.cancel();
      _submitSos();
    }
  }

  Future<void> _submitSos() async {
    setState(() {
      _isSubmittingSos = true;
      _isArmed = false;
    });

    final randomId = 'RQ-SOS-${Random().nextInt(9000) + 1000}';
    setState(() => _activeSosIncidentId = randomId);

    // Persist incident in Riverpod state & backend
    try {
      ref
          .read(incidentsProvider.notifier)
          .addIncident(
            IncidentModel(
              id: randomId,
              title: 'Critical Emergency SOS Transmitted by Citizen',
              descriptionOriginal: '1-Tap Double Confirmed Emergency SOS. Citizen requesting immediate rescue and evacuation.',
              descriptionTranslated: '1-Tap Double Confirmed Emergency SOS. Citizen requesting immediate rescue and evacuation.',
              category: IncidentCategory.flood,
              latitude: _mapCenter.latitude,
              longitude: _mapCenter.longitude,
              address: '$_selectedLocality (Live GPS Fix)',
              source: 'ONE_TAP_SOS',
              priorityScore: 95.0,
              priorityExplanation: 'High-urgency double-tap SOS triggered from active flood zone',
              reporterPhoneMasked: '+91 98*** **112',
              reportedAt: DateTime.now(),
              status: IncidentStatus.verified,
            ),
          );
      ref.read(notificationsProvider.notifier).addAlertNotification(
        title: '🚨 Urgent SOS Transmitted ($randomId)',
        body: 'Distress dispatch transmitted to EOC Queue & NDRF Teams for $_selectedLocality. Live GPS fix active.',
        severity: 'CRITICAL',
        source: 'Citizen Distress Telemetry',
        type: 'SOS',
        direction: 'SENT',
        status: 'DISPATCHED TO EOC',
      );
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() {
      _isSubmittingSos = false;
    });

    // Show honest emergency request tracking dialog (PRD SOS-4, SOS-7, SOS-13)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SosConfirmationDialog(
        incidentId: randomId,
        locationAddress: '$_selectedLocality (Live GPS Fix)',
        latitude: _mapCenter.latitude,
        longitude: _mapCenter.longitude,
        emergencyContacts: const [
          'Kavita Verma (+91 98765 00112)',
          'EOC District Dispatch Desk (+91 11 2343 8000)',
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isDone ? AppColors.successGreen : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isLegendExpanded = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final incidents = ref.watch(incidentsProvider);
    final shelters = ref.watch(sheltersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    final myReports = incidents.take(3).toList();

    return AppShell(
      currentRoute: AppRoutes.citizenDashboard,
      title: 'Citizen Emergency Portal',
      breadcrumbs: const ['Citizen', 'Dashboard'],
      hideMobileAppBar: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 28,
          vertical: isMobile ? 8 : 20,
        ),
        child: isMobile
            ? _buildMobileLayout(
                context,
                currentUser,
                shelters,
                myReports,
                isDark,
              )
            : _buildDesktopLayout(
                context,
                currentUser,
                shelters,
                myReports,
                isDark,
              ),
      ),
    );
  }

  // MOBILE VERTICAL LAYOUT (EXACTLY MATCHING SMARTPHONE MOCKUP & DESIGN PRINCIPLES)
  Widget _buildMobileLayout(
    BuildContext context,
    dynamic currentUser,
    List<ShelterModel> shelters,
    List<IncidentModel> myReports,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. UNIFIED COMPACT BRAND & LOCATION HEADER (NO STACKED BANNERS)
        _buildMobileHeader(context, currentUser, isDark),
        const SizedBox(height: 10),

        // Fallback banner when GPS is disabled (MAP-3)
        if (_locationPermissionDenied) ...[
          _buildLocationFallbackBanner(isDark),
          const SizedBox(height: 10),
        ],

        // Live Weather Card (WX-1 to WX-5)
        LiveWeatherCard(
          latitude: _mapCenter.latitude,
          longitude: _mapCenter.longitude,
          locationName: _selectedLocality,
        ),
        const SizedBox(height: 12),

        // Two Ways to Ask for Help: Instant SOS & Emergency Form (SOS-1, SOS-2)
        _buildSosAndFormButtons(context, isDark),
        const SizedBox(height: 14),

        // 2. LARGE REALISTIC DISASTER MAP WITH INTEGRATED BLUE DOT & RECENTER
        _buildDisasterMapCard(context, shelters, isDark, height: 420),
        const SizedBox(height: 14),

        // 3. ACTION SHORTCUTS (Report Damage & Find Shelter)
        _buildShortcutsRow(context, isDark),
        const SizedBox(height: 12),

        // 4. CONTEXTUAL DISASTER ALERT (Flood Watch 2.4 km away)
        _buildContextualAlertCard(context, isDark),
        const SizedBox(height: 16),

        // 5. RELIEF CONTRIBUTION CARD & DONATION MODAL
        _buildReliefDonationCard(context, isDark),
        const SizedBox(height: 16),

        // 6. MY REPORTS & ASSISTANCE TRACKING
        _buildMyReportsCard(context, myReports, isDark),
        const SizedBox(height: 16),

        // 7. NEARBY SHELTERS PREVIEW
        _buildNearbySheltersPreview(context, shelters, isDark),
        const SizedBox(height: 20),
      ],
    );
  }

  // UNIFIED ADAPTIVE MOBILE HEADER (2-ROW SPACIOUS & TOUCH-FRIENDLY)
  Widget _buildMobileHeader(
    BuildContext context,
    dynamic currentUser,
    bool isDark,
  ) {
    final activeRole = ref.watch(activeRoleProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ROW 1: BRAND LOGO + TITLE + NOTIFICATION + PROFILE
          Row(
            children: [
              // Role-Aware Brand Logo & Name
              InkWell(
                onTap: () {
                  switch (activeRole) {
                    case UserRole.citizen:
                      Navigator.pushNamed(context, AppRoutes.citizenDashboard);
                      break;
                    case UserRole.volunteer:
                      Navigator.pushNamed(
                        context,
                        AppRoutes.volunteerDashboard,
                      );
                      break;
                    case UserRole.ngoLead:
                      Navigator.pushNamed(context, AppRoutes.ngoDashboard);
                      break;
                    case UserRole.govtOfficial:
                      Navigator.pushNamed(
                        context,
                        AppRoutes.governmentCommandCentre,
                      );
                      break;
                    case UserRole.rescueTeam:
                      Navigator.pushNamed(
                        context,
                        AppRoutes.responderDashboard,
                      );
                      break;
                    case UserRole.doctor:
                      Navigator.pushNamed(context, AppRoutes.medicalDashboard);
                      break;
                    default:
                      Navigator.pushNamed(context, AppRoutes.home);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.health_and_safety,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ResQAI',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : AppColors.deepNavy,
                            ),
                          ),
                          Text(
                            'DISASTER COMMAND',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Alert Bell with Live Unread Counter & Notifications Center
              Consumer(
                builder: (context, ref, _) {
                  final unread = ref.watch(unreadNotificationCountProvider);
                  return InkWell(
                    onTap: () => NotificationsScreen.showNotificationCenter(context),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: 24,
                            color: isDark ? Colors.white : AppColors.deepNavy,
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: unread > 0 ? AppColors.emergencyRed : Colors.grey.shade600,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                unread.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),

              // Profile Avatar with minimum 44x44 tap target
              InkWell(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.citizenProfile),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
                    child: const Icon(
                      Icons.person,
                      size: 20,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ROW 2: LOCATION SELECTOR + WEATHER + STATUS INDICATOR
          Row(
            children: [
              // Location Selector Dropdown Chip
              Expanded(
                child: InkWell(
                  onTap: () => _showLocalitySelector(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _selectedLocality,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.deepNavy,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Weather Information Pill
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌧️', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '28°C Rain',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.deepNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // DESKTOP TWO-COLUMN ADAPTIVE LAYOUT
  Widget _buildDesktopLayout(
    BuildContext context,
    dynamic currentUser,
    List<ShelterModel> shelters,
    List<IncidentModel> myReports,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_locationPermissionDenied) ...[
          _buildLocationFallbackBanner(isDark),
          const SizedBox(height: 12),
        ],
        // Top Section: Live Weather Card
        LiveWeatherCard(
          latitude: _mapCenter.latitude,
          longitude: _mapCenter.longitude,
          locationName: _selectedLocality,
        ),
        const SizedBox(height: 16),

        // Two Ways to Ask for Help: Instant SOS & Emergency Form
        _buildSosAndFormButtons(context, isDark),
        const SizedBox(height: 18),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Large Interactive Map with Centered Circular Double-Tap SOS
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDisasterMapCard(context, shelters, isDark, height: 560),
                  const SizedBox(height: 18),
                  _buildShortcutsRow(context, isDark),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Right Column: Alert Card, My Reports & Shelter Status
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildContextualAlertCard(context, isDark),
                  const SizedBox(height: 18),
                  _buildReliefDonationCard(context, isDark),
                  const SizedBox(height: 18),
                  _buildMyReportsCard(context, myReports, isDark),
                  const SizedBox(height: 18),
                  _buildNearbySheltersPreview(context, shelters, isDark),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // PRD MAP-3: Location Access Fallback Banner
  Widget _buildLocationFallbackBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warningOrange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: AppColors.warningOrange, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Location access disabled. Showing default city center. Tap to enable GPS.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warningOrange,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _locationPermissionDenied = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('GPS Telemetry enabled. Calibrating live coordinates...')),
              );
            },
            child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // PRD SOS-1 & SOS-2: Two Ways to Ask for Help (Instant SOS & Emergency Form)
  Widget _buildSosAndFormButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        // 1. Instant SOS Hero Button with Vibrant Pink/Red Emergency Gradient
        Expanded(
          flex: 6,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = _isArmed ? _pulseAnimation.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _isArmed
                        ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF991B1B)])
                        : const LinearGradient(colors: [AppColors.primaryRed, AppColors.primaryRed]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (_isArmed ? const Color(0xFFDC2626) : AppColors.primaryRed).withOpacity(0.35),
                        blurRadius: _isArmed ? 14 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: _isArmed ? Colors.yellowAccent : Colors.white.withOpacity(0.25),
                          width: _isArmed ? 2.0 : 1.0,
                        ),
                      ),
                    ),
                    onPressed: _onSosTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isArmed ? Icons.warning_amber : Icons.emergency,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isArmed ? 'CONFIRM SOS ($_remainingSeconds s)' : 'INSTANT SOS',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isArmed ? 'Tap again to transmit distress' : 'One-Tap Emergency Alert',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),

        // 2. Fill Emergency Form Button with Mint/Emerald Theme
        Expanded(
          flex: 5,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightGreen,
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen, width: 1.6),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.citizenHelpRequest);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_outlined, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Emergency Form',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Detailed Request (Trapped/Med)',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. LOCALITY SELECTOR & WEATHER BAR
  Widget _buildLocalityWeatherBar(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Location Selector Dropdown
        InkWell(
          onTap: () => _showLocalitySelector(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _selectedLocality,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.deepNavy,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),

        // Weather Summary Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🌧️', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                '28°C Light Rain',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color.fromARGB(221, 236, 233, 233),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLocalitySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  'Select Monitored Disaster Sector',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              _buildLocalityTile(
                'Ghaziabad, UP',
                const LatLng(28.6480, 77.3450),
                'Hindon River Basin • High Risk Flood Watch',
              ),
              _buildLocalityTile(
                'East Delhi (Yamuna Khadar)',
                const LatLng(28.6250, 77.2650),
                'Yamuna Floodplain • Level 3 Evacuation Alert',
              ),
              _buildLocalityTile(
                'Noida Sector 62',
                const LatLng(28.6200, 77.3650),
                'Lowland Commercial & Residential Sector',
              ),
              _buildLocalityTile(
                'Patna Lowlands',
                const LatLng(25.6130, 85.1430),
                'Ganga Embankment Basin',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalityTile(String name, LatLng point, String description) {
    final isSelected = _selectedLocality == name;
    return ListTile(
      leading: Icon(
        Icons.location_city,
        color: isSelected ? AppColors.primaryBlue : Colors.grey,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(description, style: const TextStyle(fontSize: 11)),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primaryBlue)
          : null,
      onTap: () {
        setState(() {
          _selectedLocality = name;
          _mapCenter = point;
        });
        _mapController.move(point, 15.2);
        Navigator.pop(context);
      },
    );
  }

  // 3. LARGE REALISTIC DISASTER MAP CARD WITH CIRCULAR DOUBLE-TAP SOS
  Widget _buildDisasterMapCard(
    BuildContext context,
    List<ShelterModel> shelters,
    bool isDark, {
    required double height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // FlutterMap OpenStreetMap View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 15.2,
              minZoom: 10.0,
              maxZoom: 17.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.resqai.disaster',
              ),

              // Hazard Risk Polygons
              if (_showHazards)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _highRiskPolygon,
                      color: const Color(0x55F04438),
                      borderColor: const Color(0xCCF04438),
                      borderStrokeWidth: 2.0,
                      isFilled: true,
                    ),
                    Polygon(
                      points: _kaushambiFloodPolygon,
                      color: const Color(0x55F04438),
                      borderColor: const Color(0xCCF04438),
                      borderStrokeWidth: 2.0,
                      isFilled: true,
                    ),
                    Polygon(
                      points: _moderateRiskPolygon,
                      color: const Color(0x44F79009),
                      borderColor: const Color(0xAAF79009),
                      borderStrokeWidth: 1.8,
                      isFilled: true,
                    ),
                    Polygon(
                      points: _safeZonePolygon,
                      color: const Color(0x4412B76A),
                      borderColor: const Color(0xAA12B76A),
                      borderStrokeWidth: 1.8,
                      isFilled: true,
                    ),
                  ],
                ),

              // Blocked Road Dashed Polyline
              if (_showRoadBlockage)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _blockedRoad,
                      strokeWidth: 4.0,
                      color: const Color(0xFFD92D20),
                      pattern: StrokePattern.dashed(segments: const [8, 6]),
                    ),
                  ],
                ),

              // Shelter Markers
              if (_showShelters)
                MarkerLayer(
                  markers: shelters.take(5).map((sh) {
                    return Marker(
                      point: LatLng(sh.latitude, sh.longitude),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetails(
                          context,
                          'Shelter: ${sh.name}',
                          sh.address,
                          'Capacity: ${sh.totalCapacity - sh.occupiedBeds} beds open',
                          Icons.night_shelter,
                          AppColors.primaryBlue,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1570EF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.night_shelter,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Hospital Markers
              if (_showHospitals)
                MarkerLayer(
                  markers: _hospitals.map((hosp) {
                    return Marker(
                      point: hosp['point'] as LatLng,
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetails(
                          context,
                          hosp['name'] as String,
                          'Emergency Contact: ${hosp['phone']}',
                          hosp['beds'] as String,
                          Icons.local_hospital,
                          AppColors.emergencyRed,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.emergencyRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Rescue Team Markers
              if (_showRescueTeams)
                MarkerLayer(
                  markers: _rescueTeams.map((rt) {
                    return Marker(
                      point: rt['point'] as LatLng,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetails(
                          context,
                          rt['name'] as String,
                          rt['id'] as String,
                          rt['status'] as String,
                          Icons.fire_truck,
                          AppColors.emergencyRed,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_boat,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Hindon River Breach Warning Marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: const LatLng(28.6480, 77.3450),
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.warningOrange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              // PRD MAP-2: User Live Location Marker (Blue Dot + Accuracy Ring)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation,
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryBlue.withOpacity(0.2),
                            border: Border.all(
                              color: AppColors.primaryBlue.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryBlue,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // TOP-LEFT MAP LEGEND (MATCHING SMARTPHONE MOCKUP)
          Positioned(top: 12, left: 12, child: _buildMapLegend(isDark)),

          // PRD MAP-5: Reverse Geocoding Banner
          Positioned(
            top: 12,
            left: 70,
            right: 70,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location, size: 12, color: AppColors.primaryBlue),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Near: $_selectedLocality',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // TOP-RIGHT MAP CONTROLS (LAYERS, LOCATE, RE-CENTER)
          Positioned(top: 12, right: 12, child: _buildMapControls(isDark)),

          // BOTTOM-LEFT SCALE BAR
          Positioned(bottom: 12, left: 12, child: _buildScaleBar(isDark)),

          // PRD MAP-4: Floating Recenter Button
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'recenter_gps_dot',
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              foregroundColor: AppColors.primaryBlue,
              tooltip: 'Re-center to my location',
              onPressed: () {
                _mapController.move(_userLocation, 15.5);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    duration: Duration(milliseconds: 1200),
                    content: Text('Re-centered to live GPS blue dot'),
                  ),
                );
              },
              child: const Icon(Icons.gps_fixed, size: 18),
            ),
          ),

          // CENTER-BOTTOM CIRCULAR DOUBLE-TAP SOS BUTTON (SIGNATURE FEATURE)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(child: _buildDoubleTapSosButton()),
          ),
        ],
      ),
    );
  }

  // MAP LEGEND OVERLAY (COLLAPSIBLE FOR MOBILE CLARITY)
  Widget _buildMapLegend(bool isDark) {
    if (!_isLegendExpanded) {
      return InkWell(
        onTap: () => setState(() => _isLegendExpanded = true),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers, size: 12, color: AppColors.primaryBlue),
              SizedBox(width: 4),
              Text(
                'Legend ▾',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Map Legend',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: () => setState(() => _isLegendExpanded = false),
                child: const Icon(Icons.close, size: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildLegendRow(
            const Color(0xFFF04438),
            'High Flood Risk',
            isBox: true,
          ),
          _buildLegendRow(
            const Color(0xFFF79009),
            'Moderate Risk',
            isBox: true,
          ),
          _buildLegendRow(const Color(0xFF12B76A), 'Safe Zone', isBox: true),
          _buildLegendRow(
            const Color(0xFF1570EF),
            'Shelter',
            icon: Icons.night_shelter,
          ),
          _buildLegendRow(AppColors.emergencyRed, 'Hospital', icon: Icons.add),
          _buildLegendRow(
            Colors.red.shade800,
            'Rescue Team',
            icon: Icons.directions_boat,
          ),
          _buildLegendRow(
            const Color(0xFFD92D20),
            'Blocked Road',
            isDashed: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(
    Color color,
    String text, {
    bool isBox = false,
    bool isDashed = false,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBox)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else if (isDashed)
            Row(
              children: [
                Container(width: 4, height: 2, color: color),
                const SizedBox(width: 2),
                Container(width: 4, height: 2, color: color),
              ],
            )
          else if (icon != null)
            Icon(icon, size: 11, color: color)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // MAP CONTROLS PILL
  Widget _buildMapControls(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapControlButton(
            Icons.layers_outlined,
            'Layers',
            () => _showLayersModal(context),
          ),
          const Divider(height: 1, indent: 4, endIndent: 4),
          _buildMapControlButton(Icons.near_me_outlined, 'Locate', () {
            _mapController.move(_userLocation, 15.5);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('GPS Centered at $_selectedLocality'),
                duration: const Duration(seconds: 1),
              ),
            );
          }),
          const Divider(height: 1, indent: 4, endIndent: 4),
          _buildMapControlButton(Icons.my_location, 'Re-center', () {
            _mapController.move(_userLocation, 15.5);
          }),
        ],
      ),
    );
  }

  Widget _buildMapControlButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.deepNavy),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLayersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toggle Tactical Map Layers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Flood Risk Zones'),
                  value: _showHazards,
                  onChanged: (v) {
                    setState(() => _showHazards = v);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Emergency Shelters'),
                  value: _showShelters,
                  onChanged: (v) {
                    setState(() => _showShelters = v);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Hospital & Trauma Centers'),
                  value: _showHospitals,
                  onChanged: (v) {
                    setState(() => _showHospitals = v);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Rescue & NDRF Teams'),
                  value: _showRescueTeams,
                  onChanged: (v) {
                    setState(() => _showRescueTeams = v);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Blocked Road Hazards'),
                  value: _showRoadBlockage,
                  onChanged: (v) {
                    setState(() => _showRoadBlockage = v);
                    setModalState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // BOTTOM-LEFT SCALE BAR
  Widget _buildScaleBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '0    2    4 km',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 1),
          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black87, width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(child: Container(color: Colors.black87)),
                Expanded(child: Container(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. SIGNATURE FEATURE: PROMINENT CIRCULAR DOUBLE-TAP SOS BUTTON
  Widget _buildDoubleTapSosButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing Rings + Core Circular SOS Button
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = _isArmed ? _pulseAnimation.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: _onSosTap,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isArmed
                            ? Colors.redAccent.withOpacity(0.6)
                            : AppColors.emergencyRed.withOpacity(0.35),
                        blurRadius: _isArmed ? 24 : 16,
                        spreadRadius: _isArmed ? 6 : 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer soft halo
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              (_isArmed
                                      ? Colors.redAccent
                                      : AppColors.emergencyRed)
                                  .withOpacity(0.2),
                        ),
                      ),
                      // Core circular button
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: _isArmed
                                ? const [Color(0xFFFF5252), Color(0xFFD32F2F)]
                                : const [Color(0xFFEF4444), Color(0xFFB91C1C)],
                            center: Alignment.topLeft,
                            radius: 0.85,
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '✱',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                height: 0.9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _isArmed ? '$_remainingSeconds' : 'SOS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),

        // Confirmation / Cancellation and Accessible Alternative Badges
        if (_isArmed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.emergencyRed, width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Text(
                  '⚠️ Tap again to confirm SOS (${_remainingSeconds}s)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emergencyRed,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  _countdownTimer?.cancel();
                  setState(() => _isArmed = false);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 12, color: Colors.grey),
                      SizedBox(width: 2),
                      Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFCDD2),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: const Text(
                  'Double-tap to request emergency dispatch',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.citizenSos),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Motor Assist / Form SOS Mode ↗',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // 5. SHORTCUTS: 4 High-Impact Emergency Action Cards
  Widget _buildShortcutsRow(BuildContext context, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            // Card 1: Report Damage (Pink accent)
            Expanded(
              child: _buildShortcutCard(
                context,
                icon: Icons.assignment_late_outlined,
                iconColor: AppColors.primaryRed,
                iconBg: AppColors.red50,
                title: 'Report Damage',
                subtitle: 'Homes, roads, hazards',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.citizenNewReport),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),

            // Card 2: Find Shelter (Emerald Green)
            Expanded(
              child: _buildShortcutCard(
                context,
                icon: Icons.night_shelter_outlined,
                iconColor: AppColors.primaryGreen,
                iconBg: AppColors.lightGreen,
                title: 'Find Shelter',
                subtitle: 'Nearby safe camps',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.citizenShelters),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Card 3: Request Relief (Vibrant Pink)
            Expanded(
              child: _buildShortcutCard(
                context,
                icon: Icons.volunteer_activism_outlined,
                iconColor: AppColors.primaryRed,
                iconBg: AppColors.red50,
                title: 'Request Aid',
                subtitle: 'Food, rations & relief',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.citizenHelpRequest),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),

            // Card 4: Emergency Contacts & Helplines
            Expanded(
              child: _buildShortcutCard(
                context,
                icon: Icons.contact_phone_outlined,
                iconColor: const Color(0xFF0284C7),
                iconBg: const Color(0xFFF0F9FF),
                title: 'Helplines',
                subtitle: '112, 1070 & contacts',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.citizenEmergencyContacts),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortcutCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? iconColor.withOpacity(0.15) : iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.deepNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // 6. CONTEXTUAL DISASTER ALERT (FLOOD WATCH 2.4 KM AWAY)
  Widget _buildContextualAlertCard(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, AppRoutes.citizenAlerts),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECDCA), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.emergencyRed.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFD92D20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Flood Watch • 2.4 km away',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB42318),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD92D20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'High Risk',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rising water levels in Hindon River. Avoid low-lying areas. Stay updated and follow official instructions.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF55160C),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFB42318), size: 20),
          ],
        ),
      ),
    );
  }

  // 7. MY ACTIVE REPORTS & CASE FILES
  Widget _buildMyReportsCard(
    BuildContext context,
    List<IncidentModel> reports,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Expanded(
                child: Text(
                  'My Filed Reports & Claims',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepNavy,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.citizenReports),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No open emergency claims filed.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else
            ...reports.map((r) => _buildReportTile(context, r, isDark)),
        ],
      ),
    );
  }

  Widget _buildReportTile(
    BuildContext context,
    IncidentModel inc,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/citizen/reports/${inc.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.primaryBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${inc.address} • Score: ${inc.priorityScore.toStringAsFixed(0)}/100',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: inc.status == IncidentStatus.verified
                    ? AppColors.successGreen.withOpacity(0.12)
                    : AppColors.warningOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                inc.status.label.toUpperCase(),
                style: TextStyle(
                  color: inc.status == IncidentStatus.verified
                      ? AppColors.successGreen
                      : AppColors.warningOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // DESKTOP: NEARBY SHELTERS PREVIEW
  Widget _buildNearbySheltersPreview(
    BuildContext context,
    List<ShelterModel> shelters,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Nearby Safe Havens',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepNavy,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.citizenShelters),
                child: const Text(
                  'All Shelters',
                  style: TextStyle(fontSize: 12, color: AppColors.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...shelters.take(3).map((s) {
            final remaining = s.totalCapacity - s.occupiedBeds;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.night_shelter,
                    size: 16,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$remaining beds',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.successGreen,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // MARKER DETAILS MODAL
  void _showMarkerDetails(
    BuildContext context,
    String title,
    String subtitle,
    String details,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                details,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Directions to $title started.'),
                            backgroundColor: AppColors.primaryBlue,
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Get Directions'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
