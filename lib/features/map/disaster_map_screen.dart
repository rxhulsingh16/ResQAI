import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/incident_model.dart';
import '../../shared/models/shelter_model.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';

class DisasterMapScreen extends ConsumerStatefulWidget {
  final String routePath;

  const DisasterMapScreen({super.key, this.routePath = AppRoutes.disasterMap});

  @override
  ConsumerState<DisasterMapScreen> createState() => _DisasterMapScreenState();
}

class _DisasterMapScreenState extends ConsumerState<DisasterMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  IncidentModel? _selectedIncident;
  ShelterModel? _selectedShelter;

  // Layer switches
  bool _showShelters = true;
  bool _showHazards = true;
  bool _showRoadBlockage = true;
  bool _showHospitals = true;

  // Filter & Search
  String _severityFilter = 'ALL'; // 'ALL', 'CRITICAL', 'MODERATE'
  String _searchQuery = '';
  bool _isLegendExpanded = false;

  // Real geographic coordinates: Ghaziabad / Hindon River & Yamuna Corridor
  final LatLng _initialCenter = const LatLng(28.6480, 77.3450);

  // Hindon River High Risk Polygon
  final List<LatLng> _highRiskPolygon = const [
    LatLng(28.7100, 77.3100),
    LatLng(28.6900, 77.3400),
    LatLng(28.6700, 77.3600),
    LatLng(28.6500, 77.3500),
    LatLng(28.6600, 77.3200),
    LatLng(28.6900, 77.3000),
  ];

  // Blocked NH-9 crossing polyline
  final List<LatLng> _blockedRoute = const [
    LatLng(28.6250, 77.2900),
    LatLng(28.6350, 77.3200),
    LatLng(28.6420, 77.3500),
  ];

  // Hospitals in Ghaziabad sector
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
      'beds': '12 Trauma beds available',
      'phone': '+91 120 477 7000',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(incidentsProvider);
    final shelters = ref.watch(sheltersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    // Filter incidents by severity and search
    final displayedIncidents = incidents.where((i) {
      if (_severityFilter == 'CRITICAL' && i.priorityScore < 80) return false;
      if (_severityFilter == 'MODERATE' && (i.priorityScore < 50 || i.priorityScore >= 80)) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = i.title.toLowerCase().contains(q) ||
            i.address.toLowerCase().contains(q) ||
            i.id.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    // Filter shelters by search
    final displayedShelters = shelters.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return s.name.toLowerCase().contains(q) || s.address.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return AppShell(
      currentRoute: widget.routePath,
      title: 'Disaster Navigation Map',
      breadcrumbs: const ['Disaster Map', 'Navigation'],
      hideMobileAppBar: true,
      child: Stack(
        children: [
          // 1. FULL-BLEED OPENSTREETMAP WORKSPACE
          Row(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 12.8,
                    minZoom: 10.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'org.resqai.disaster',
                    ),

                    // Verified Hindon Hazard Polygon
                    if (_showHazards)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _highRiskPolygon,
                            color: const Color(0x4AF04438),
                            borderColor: const Color(0xCCF04438),
                            borderStrokeWidth: 2.0,
                            isFilled: true,
                          ),
                        ],
                      ),

                    // Blocked Road Hazard Line
                    if (_showRoadBlockage)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _blockedRoute,
                            strokeWidth: 4.5,
                            color: AppColors.criticalRed,
                            pattern: StrokePattern.dashed(segments: const [10, 8]),
                          ),
                        ],
                      ),

                    // Relief Shelters Markers
                    if (_showShelters)
                      MarkerLayer(
                        markers: displayedShelters.map((s) {
                          final isSelected = _selectedShelter?.id == s.id;
                          return Marker(
                            point: LatLng(s.latitude, s.longitude),
                            width: isSelected ? 44 : 36,
                            height: isSelected ? 44 : 36,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedShelter = s;
                                  _selectedIncident = null;
                                });
                                if (!isDesktop) _showShelterDetailSheet(context, s);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1570EF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: const Icon(Icons.night_shelter, color: Colors.white, size: 19),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    // Hospital Markers
                    if (_showHospitals)
                      MarkerLayer(
                        markers: _hospitals.map((h) {
                          return Marker(
                            point: h['point'] as LatLng,
                            width: 34,
                            height: 34,
                            child: GestureDetector(
                              onTap: () {
                                if (!isDesktop) _showHospitalDetailSheet(context, h);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.emergencyRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    // Incident Markers
                    if (_showHazards)
                      MarkerLayer(
                        markers: displayedIncidents.map((inc) {
                          final isCrit = inc.priorityScore >= 80;
                          final isSelected = _selectedIncident?.id == inc.id;

                          return Marker(
                            point: LatLng(inc.latitude, inc.longitude),
                            width: isSelected ? 46 : 38,
                            height: isSelected ? 46 : 38,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIncident = inc;
                                  _selectedShelter = null;
                                });
                                if (!isDesktop) _showIncidentDetailSheet(context, inc);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCrit ? AppColors.criticalRed : AppColors.warningOrange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.yellowAccent : Colors.white,
                                    width: isSelected ? 3 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isCrit ? AppColors.criticalRed : AppColors.warningOrange).withOpacity(0.5),
                                      blurRadius: isSelected ? 12 : 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  inc.source == 'ONE_TAP_SOS' ? Icons.emergency : Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: isSelected ? 22 : 18,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),

              // DESKTOP CONTEXTUAL RIGHT SIDE PANEL
              if (isDesktop && _selectedIncident != null)
                Container(
                  width: 360,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    border: Border(left: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                  ),
                  child: _buildDesktopDetailPanel(context, _selectedIncident!, isDark),
                ),
            ],
          ),

          // 2. FLOATING TOP SEARCH & FILTER BAR
          Positioned(
            top: 14,
            left: 14,
            right: isDesktop ? (360 + 14) : 14,
            child: Row(
              children: [
                // Back button if popped
                if (Navigator.canPop(context))
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.deepNavy, size: 20),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                  ),

                // Search Pill
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.97),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search shelter, hospital, or locality...',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.black45),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.close, size: 16, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Layers Sheet Trigger
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.layers_outlined, color: AppColors.deepNavy, size: 20),
                    tooltip: 'Map Layers',
                    onPressed: () => _showLayersModal(context),
                  ),
                ),
              ],
            ),
          ),

          // 3. FLOATING MAP CONTROLS (RIGHT-SIDE PILL)
          Positioned(
            bottom: 24,
            right: isDesktop ? (360 + 16) : 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFloatingAction(Icons.my_location, 'Locate', () {
                    _mapController.move(_initialCenter, 14.0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Centered to live GPS coordinates'), duration: Duration(seconds: 1)),
                    );
                  }),
                  const Divider(height: 1, indent: 4, endIndent: 4),
                  _buildFloatingAction(Icons.center_focus_strong, 'Overview', () {
                    _mapController.move(_initialCenter, 12.8);
                  }),
                ],
              ),
            ),
          ),

          // 4. COLLAPSIBLE MAP LEGEND (BOTTOM-LEFT)
          Positioned(
            bottom: 24,
            left: 14,
            child: _buildCollapsibleLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAction(IconData icon, String tooltip, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 20, color: AppColors.deepNavy),
      ),
    );
  }

  // COLLAPSIBLE LEGEND
  Widget _buildCollapsibleLegend() {
    if (!_isLegendExpanded) {
      return InkWell(
        onTap: () => setState(() => _isLegendExpanded = true),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers, size: 13, color: AppColors.primaryGreen),
              SizedBox(width: 5),
              Text(
                'Legend ▾',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.deepNavy),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
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
              const Text('Map Legend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.deepNavy)),
              const SizedBox(width: 14),
              InkWell(
                onTap: () => setState(() => _isLegendExpanded = false),
                child: const Icon(Icons.close, size: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildLegendRow(const Color(0xFFF04438), 'High Flood Risk', isBox: true),
          _buildLegendRow(const Color(0xFF1570EF), 'Relief Shelter', icon: Icons.night_shelter),
          _buildLegendRow(AppColors.emergencyRed, 'Hospital', icon: Icons.add),
          _buildLegendRow(const Color(0xFFD92D20), 'Blocked Route', isDashed: true),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String text, {bool isBox = false, bool isDashed = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBox)
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))
          else if (isDashed)
            Row(
              children: [
                Container(width: 4, height: 2, color: color),
                const SizedBox(width: 2),
                Container(width: 4, height: 2, color: color),
              ],
            )
          else if (icon != null)
            Icon(icon, size: 12, color: color)
          else
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showLayersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tactical Map Layers & Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Flood Hazard Risk Zones'),
                  value: _showHazards,
                  onChanged: (v) {
                    setState(() => _showHazards = v);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Relief Shelters'),
                  value: _showShelters,
                  onChanged: (v) {
                    setState(() => _showShelters = v);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Hospitals & Trauma Centers'),
                  value: _showHospitals,
                  onChanged: (v) {
                    setState(() => _showHospitals = v);
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
                const Divider(),
                const Text('Severity Filter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _severityFilter == 'ALL',
                      onSelected: (v) {
                        setState(() => _severityFilter = 'ALL');
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Critical (≥80)'),
                      selected: _severityFilter == 'CRITICAL',
                      selectedColor: AppColors.criticalRed.withOpacity(0.2),
                      onSelected: (v) {
                        setState(() => _severityFilter = 'CRITICAL');
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Moderate (50-79)'),
                      selected: _severityFilter == 'MODERATE',
                      selectedColor: AppColors.warningOrange.withOpacity(0.2),
                      onSelected: (v) {
                        setState(() => _severityFilter = 'MODERATE');
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showIncidentDetailSheet(BuildContext context, IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: incident.priorityScore >= 80 ? AppColors.criticalRed.withOpacity(0.12) : AppColors.warningOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRIORITY: ${incident.priorityScore.toStringAsFixed(0)}/100',
                        style: TextStyle(
                          color: incident.priorityScore >= 80 ? AppColors.criticalRed : AppColors.warningOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text('ID: ${incident.id}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(incident.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Location: ${incident.address}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                Text(incident.descriptionOriginal, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '${AppRoutes.citizenReports}/${incident.id}');
                  },
                  child: const Text('Open Case Details & Verification'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShelterDetailSheet(BuildContext context, ShelterModel shelter) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('VERIFIED SHELTER', style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                    Text('Available: ${shelter.remainingBeds}/${shelter.totalCapacity} Beds', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(shelter.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(shelter.address, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.navigation, size: 16),
                        label: const Text('Get Directions'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Route mapped to ${shelter.name}')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, AppRoutes.citizenShelters);
                        },
                        child: const Text('Shelter Directory'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHospitalDetailSheet(BuildContext context, Map<String, dynamic> hospital) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('TRAUMA & EMERGENCY HOSPITAL', style: TextStyle(color: AppColors.emergencyRed, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(hospital['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(hospital['beds'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successGreen)),
                const SizedBox(height: 4),
                Text('Emergency Contact: ${hospital['phone']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergencyRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Call Emergency Department'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dialing ${hospital['phone']}...')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopDetailPanel(BuildContext context, IncidentModel incident, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Incident Workspace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedIncident = null),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.criticalRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRIORITY: ${incident.priorityScore.toStringAsFixed(0)}/100',
                        style: const TextStyle(color: AppColors.criticalRed, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('ID: ${incident.id}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  incident.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Locality: ${incident.address}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                const Text('Field Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(incident.descriptionOriginal, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Dispatch Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  incident.status.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 42),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Detailed Case File'),
                  onPressed: () {
                    Navigator.pushNamed(context, '${AppRoutes.citizenReports}/${incident.id}');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
