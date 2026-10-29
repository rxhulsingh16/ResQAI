import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/layout/app_shell.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/incident_repository.dart';
import '../../shared/models/incident_model.dart';

class CitizenHelpRequestScreen extends ConsumerStatefulWidget {
  const CitizenHelpRequestScreen({super.key});

  @override
  ConsumerState<CitizenHelpRequestScreen> createState() => _CitizenHelpRequestScreenState();
}

class _CitizenHelpRequestScreenState extends ConsumerState<CitizenHelpRequestScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Incident details
  String _disasterType = 'Flooding / River Water Inundation';
  final List<String> _disasterTypes = [
    'Flooding / River Water Inundation',
    'Severe Cyclone / High-Velocity Storm',
    'Structural Building Collapse / Debris',
    'Earthquake Tremors & Damage',
    'Urban / Industrial Fire Hazard',
    'Landslide / Slope Mudslide',
    'Extreme Heatwave / Water Scarcity',
    'Other Severe Emergency',
  ];
  final DateTime _incidentDate = DateTime.now();
  final TextEditingController _stateDistrictController =
      TextEditingController(text: 'East Delhi, NCT of Delhi');
  final TextEditingController _localityController =
      TextEditingController(text: 'Yamuna Khadar, Ward 4');
  final TextEditingController _addressPinController =
      TextEditingController(text: 'Near Geeta Colony Bridge, Embankment Post 12');
  final TextEditingController _descriptionController = TextEditingController(
    text: 'Water entered ground floor up to 3 feet. Power transformer submerged; drinking water line disrupted.',
  );
  bool _isSituationOngoing = true;
  bool _isImmediateDanger = false;

  // Step 2: Household & Vulnerability
  final TextEditingController _affectedCountController = TextEditingController(text: '5');
  final TextEditingController _familyMembersController = TextEditingController(text: '5');
  final TextEditingController _childrenCountController = TextEditingController(text: '2');
  final TextEditingController _elderlyCountController = TextEditingController(text: '1');
  final TextEditingController _medicalNeedsCountController = TextEditingController(text: '1');
  String _currentSituation = 'At Home (Roads Waterlogged)';
  final List<String> _situations = [
    'At Home (Roads Waterlogged)',
    'Stranded on Rooftop / Upper Floor',
    'Evacuated to High Embankment',
    'In Temporary Relief Camp',
    'Cut off / Isolated in Lowland',
    'Other',
  ];
  final TextEditingController _safePhoneController = TextEditingController(text: '+91 98111 22334');
  final TextEditingController _emergencyPhoneController = TextEditingController(text: '+91 98222 33445');

  // Step 3: Help Required (Items, Quantities & Urgency)
  final Map<String, _HelpNeedItem> _helpItems = {
    'Food Packets & Dry Rations': _HelpNeedItem('Food Packets & Dry Rations', isSelected: true, quantity: '15 meal packets', urgency: 'Urgent (Today)'),
    'Potable Drinking Water Cans': _HelpNeedItem('Potable Drinking Water Cans', isSelected: true, quantity: '30 Litres (6 cans)', urgency: 'Critical (Immediate)'),
    'Temporary Waterproof Tarpaulins': _HelpNeedItem('Temporary Waterproof Tarpaulins', isSelected: true, quantity: '2 tarpaulin sheets', urgency: 'Urgent (Today)'),
    'Medicines & First Aid Care': _HelpNeedItem('Medicines & First Aid Care', isSelected: false, quantity: '1 kit', urgency: 'Standard (24h)'),
    'Warm Clothing & Blankets': _HelpNeedItem('Warm Clothing & Blankets', isSelected: false, quantity: '4 blankets', urgency: 'Standard (24h)'),
    'Rescue Boat Evacuation': _HelpNeedItem('Rescue Boat Evacuation', isSelected: false, quantity: '1 boat extraction', urgency: 'Critical (Immediate)'),
    'Safe Transport / Transit': _HelpNeedItem('Safe Transport / Transit', isSelected: false, quantity: 'Family transit', urgency: 'Urgent (Today)'),
    'Baby Food & Diapers': _HelpNeedItem('Baby Food & Diapers', isSelected: true, quantity: '2 formula tins, diapers', urgency: 'Urgent (Today)'),
    'Sanitary / Hygiene Kits': _HelpNeedItem('Sanitary / Hygiene Kits', isSelected: false, quantity: '2 dignity kits', urgency: 'Standard (24h)'),
    'Accessibility / Wheelchair Care': _HelpNeedItem('Accessibility / Wheelchair Care', isSelected: false, quantity: '1 folding wheelchair', urgency: 'Urgent (Today)'),
    'Ex-Gratia Financial Grant': _HelpNeedItem('Ex-Gratia Financial Grant', isSelected: false, quantity: 'SDRF Immediate Grant', urgency: 'Standard (24h)'),
  };

  // Step 4: Damage & Supporting Information
  String _damageSeverity = 'Moderate (Partial flooding / damaged contents)';
  final List<String> _severityLevels = [
    'Minor (Habitable with minor repairs)',
    'Moderate (Partial flooding / damaged contents)',
    'Severe Structural Damage (Boundary collapsed / cracked)',
    'Total Destruction (Structure fully submerged / collapsed)',
  ];
  final List<String> _damagedAssets = ['Ground Floor Housing', 'Household Electricals', 'Drinking Water Supply'];
  final List<String> _allAssetOptions = [
    'Ground Floor Housing',
    'Thatched / Kutcha Roof',
    'Standing Agricultural Crops',
    'Livestock / Dairy Cattle',
    'Household Electricals & Beds',
    'Motorbike / Cycle Rickshaw',
    'Small Kirana Shop / Workshop',
    'Drinking Water Supply',
  ];
  final TextEditingController _estimatedLossController = TextEditingController(text: '120000');
  bool _attachedPhotoProof = true;

  // Step 5: Review & Declaration
  bool _declarationConfirmed = true;

  @override
  void dispose() {
    _stateDistrictController.dispose();
    _localityController.dispose();
    _addressPinController.dispose();
    _descriptionController.dispose();
    _affectedCountController.dispose();
    _familyMembersController.dispose();
    _childrenCountController.dispose();
    _elderlyCountController.dispose();
    _medicalNeedsCountController.dispose();
    _safePhoneController.dispose();
    _emergencyPhoneController.dispose();
    _estimatedLossController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return AppShell(
      currentRoute: AppRoutes.citizenHelpRequest,
      title: 'Disaster Assistance Request',
      breadcrumbs: const ['Citizen', 'Help Hub', 'Request Assistance'],
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 28,
          vertical: isMobile ? 16 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 28),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFormHeader(isDark, isMobile),
                  const SizedBox(height: 20),

                  // STEPPER
                  Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppColors.primaryGreen,
                        surface: isDark ? AppColors.darkSurfaceCard : Colors.white,
                      ),
                    ),
                    child: Stepper(
                      currentStep: _currentStep,
                      physics: const NeverScrollableScrollPhysics(),
                      onStepContinue: () {
                        if (_currentStep < 4) {
                          setState(() => _currentStep++);
                        } else {
                          _submitHelpRequest();
                        }
                      },
                      onStepCancel: () {
                        if (_currentStep > 0) {
                          setState(() => _currentStep--);
                        }
                      },
                      controlsBuilder: (context, details) {
                        final isLastStep = _currentStep == 4;
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: isLastStep ? AppColors.redGradient : AppColors.greenGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isLastStep ? AppColors.primaryRed : AppColors.primaryGreen).withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _isSubmitting ? null : details.onStepContinue,
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text(
                                          isLastStep ? 'Transmit Help Request ✓' : 'Save & Continue →',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                ),
                              ),
                              if (_currentStep > 0) ...[
                                const SizedBox(width: 14),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white70 : AppColors.deepNavy,
                                    side: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade400, width: 1.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: details.onStepCancel,
                                  child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      steps: [
                        // STEP 1: Incident & Location Details
                        Step(
                          title: const Text('Incident Details', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Disaster type & exact locality', style: TextStyle(fontSize: 11)),
                          isActive: _currentStep >= 0,
                          content: _buildStep1IncidentDetails(isDark),
                        ),

                        // STEP 2: Affected Household & Family
                        Step(
                          title: const Text('Affected Household', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('People count & current situation', style: TextStyle(fontSize: 11)),
                          isActive: _currentStep >= 1,
                          content: _buildStep2HouseholdInfo(isDark),
                        ),

                        // STEP 3: Help Required
                        Step(
                          title: const Text('Required Relief Items', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Select items, quantities & urgency', style: TextStyle(fontSize: 11)),
                          isActive: _currentStep >= 2,
                          content: _buildStep3HelpRequired(isDark),
                        ),

                        // STEP 4: Damage & Losses
                        Step(
                          title: const Text('Damage & Supporting Info', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Structural loss & utilities', style: TextStyle(fontSize: 11)),
                          isActive: _currentStep >= 3,
                          content: _buildStep4DamageInfo(isDark),
                        ),

                        // STEP 5: Review & Submit
                        Step(
                          title: const Text('Review & Transmit', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Final check & dispatch log', style: TextStyle(fontSize: 11)),
                          isActive: _currentStep >= 4,
                          content: _buildStep5ReviewAndSubmit(isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormHeader(bool isDark, bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.handshake_outlined, color: AppColors.primaryGreen, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formal Disaster Relief Request',
                style: TextStyle(
                  fontSize: isMobile ? 17 : 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '5-Step guided intake routed directly to District Emergency Control & Verified NGOs',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1IncidentDetails(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isImmediateDanger)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.emergencyRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.emergencyRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: AppColors.emergencyRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Immediate Life Danger Detected!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emergencyRed),
                      ),
                      const Text(
                        'If water is rapidly rising or lives are in imminent peril, do not wait for supply forms.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.citizenSos),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text('Switch to Rapid 2-Tap Emergency SOS ↗',
                            style: TextStyle(color: AppColors.emergencyRed, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const Text('Disaster Classification *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _disasterType,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: _disasterTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (v) => setState(() => _disasterType = v ?? _disasterTypes.first),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('State & District *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _stateDistrictController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date of Occurrence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text('${_incidentDate.day}/${_incidentDate.month}/${_incidentDate.year}'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        const Text('City / Ward / Village / Locality *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _localityController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'e.g. Ward 4, Yamuna Khadar',
          ),
        ),
        const SizedBox(height: 14),

        const Text('Exact Landmark or GPS Address *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _addressPinController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined, size: 18),
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'Near Geeta Colony bridge / School embankment',
          ),
        ),
        const SizedBox(height: 14),

        const Text('Concise Situation Description *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Describe current conditions, water depth, road blockage...',
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Situation is actively ongoing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                value: _isSituationOngoing,
                onChanged: (v) => setState(() => _isSituationOngoing = v ?? true),
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('People in immediate danger', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emergencyRed)),
                value: _isImmediateDanger,
                onChanged: (v) => setState(() => _isImmediateDanger = v ?? false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2HouseholdInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Affected People *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _affectedCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Children (<12 yrs)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _childrenCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Elderly / Disabled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _elderlyCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Requiring Urgent Meds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _medicalNeedsCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        const Text('Current Physical Location / Situation *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _currentSituation,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: _situations.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _currentSituation = v ?? _situations.first),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Safe Contact Phone *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _safePhoneController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alternate Emergency Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emergencyPhoneController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Privacy Guarantee: Phone numbers are masked and only revealed to assigned responders upon task acceptance.',
                  style: TextStyle(fontSize: 11, color: AppColors.deepNavy),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3HelpRequired(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select all essential assistance categories required by your household:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),

        ..._helpItems.entries.map((entry) {
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : (item.isSelected ? Colors.blue.shade50 : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.isSelected ? AppColors.primaryBlue : Colors.grey.shade300,
                width: item.isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: item.isSelected,
                      activeColor: AppColors.primaryBlue,
                      onChanged: (v) {
                        setState(() => item.isSelected = v ?? false);
                      },
                    ),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: item.isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isDark ? Colors.white : AppColors.deepNavy,
                        ),
                      ),
                    ),
                    if (item.isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.urgency == 'Critical (Immediate)'
                              ? AppColors.emergencyRed.withOpacity(0.15)
                              : AppColors.warningOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.urgency,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.urgency == 'Critical (Immediate)' ? AppColors.emergencyRed : AppColors.warningOrange,
                          ),
                        ),
                      ),
                  ],
                ),
                if (item.isSelected) ...[
                  const Divider(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          initialValue: item.quantity,
                          decoration: const InputDecoration(
                            labelText: 'Estimated Quantity',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => item.quantity = val,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          value: item.urgency,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Urgency Tier',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: ['Critical (Immediate)', 'Urgent (Today)', 'Standard (24h)']
                              .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 11))))
                              .toList(),
                          onChanged: (v) => setState(() => item.urgency = v ?? 'Urgent (Today)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep4DamageInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Observed Structural Damage Severity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _damageSeverity,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: _severityLevels.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => _damageSeverity = v ?? _severityLevels.first),
        ),
        const SizedBox(height: 14),

        const Text('Affected Assets / Inundated Properties', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _allAssetOptions.map((asset) {
            final isSel = _damagedAssets.contains(asset);
            return FilterChip(
              label: Text(asset, style: TextStyle(fontSize: 12, color: isSel ? AppColors.primaryBlue : null)),
              selected: isSel,
              selectedColor: AppColors.primaryBlue.withOpacity(0.18),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _damagedAssets.add(asset);
                  } else {
                    _damagedAssets.remove(asset);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        const Text('Estimated Economic Loss (INR ₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _estimatedLossController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: '₹ ',
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'e.g. 80000',
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Optional Geotagged Photo Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('flood_waterlogging_inundated_home_east_delhi.jpg (1.8 MB)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Switch(
                value: _attachedPhotoProof,
                activeColor: AppColors.primaryBlue,
                onChanged: (v) => setState(() => _attachedPhotoProof = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep5ReviewAndSubmit(bool isDark) {
    final selectedNeeds = _helpItems.values.where((i) => i.isSelected).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Disaster: $_disasterType', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton(onPressed: () => setState(() => _currentStep = 0), child: const Text('Edit')),
                ],
              ),
              Text('Location: ${_addressPinController.text}, ${_localityController.text}'),
              Text('Situation: $_currentSituation • Ongoing: ${_isSituationOngoing ? "Yes" : "No"}'),
              const Divider(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Household: ${_affectedCountController.text} persons (${_childrenCountController.text} kids, ${_elderlyCountController.text} elderly)'),
                  TextButton(onPressed: () => setState(() => _currentStep = 1), child: const Text('Edit')),
                ],
              ),
              Text('Contact: ${_safePhoneController.text}'),
              const Divider(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Requested Relief Items (${selectedNeeds.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => setState(() => _currentStep = 2), child: const Text('Edit')),
                ],
              ),
              ...selectedNeeds.map((item) => Text('• ${item.name} (${item.quantity}) - [${item.urgency}]', style: const TextStyle(fontSize: 12))),
              const Divider(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated Damage Loss: ₹${_estimatedLossController.text}'),
                  TextButton(onPressed: () => setState(() => _currentStep = 3), child: const Text('Edit')),
                ],
              ),
              Text('Severity: $_damageSeverity'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _declarationConfirmed,
          activeColor: AppColors.primaryGreen,
          title: const Text(
            'I solemnly declare that the information provided is accurate and represents genuine humanitarian need. I consent to field coordination by authorized disaster response units.',
            style: TextStyle(fontSize: 11),
          ),
          onChanged: (v) => setState(() => _declarationConfirmed = v ?? true),
        ),
      ],
    );
  }

  void _submitHelpRequest() async {
    if (!_declarationConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.warningOrange,
          content: Text('Please accept the declaration of truth before transmitting.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final reqId = 'RQ-HLP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final user = ref.read(authProvider);

    final selectedNeedsList = _helpItems.values
        .where((i) => i.isSelected)
        .map((i) => '${i.name} (${i.quantity})')
        .toList();

    final loss = double.tryParse(_estimatedLossController.text) ?? 50000.0;
    final affected = int.tryParse(_affectedCountController.text) ?? 4;
    final medicalCount = int.tryParse(_medicalNeedsCountController.text) ?? 0;

    final incident = IncidentModel(
      id: reqId,
      title: 'HUMANITARIAN REQUEST: $_disasterType (${selectedNeedsList.take(2).join(", ")})',
      descriptionOriginal: '${_descriptionController.text} • Situation: $_currentSituation • Needs: ${selectedNeedsList.join(", ")}',
      descriptionTranslated: '${_descriptionController.text} • Situation: $_currentSituation • Needs: ${selectedNeedsList.join(", ")}',
      category: _isImmediateDanger ? IncidentCategory.flood : IncidentCategory.foodWater,
      latitude: 28.6250,
      longitude: 77.2950,
      address: '${_addressPinController.text}, ${_localityController.text}, ${_stateDistrictController.text}',
      status: IncidentStatus.received,
      priorityScore: _isImmediateDanger ? 92.0 : (medicalCount > 0 ? 84.0 : 68.0),
      priorityExplanation: _isImmediateDanger
          ? 'High Priority: Immediate peril declared for household with $affected persons'
          : 'Humanitarian intake logged for $affected persons across ${selectedNeedsList.length} relief categories',
      vulnerableGroups: [
        if (int.tryParse(_childrenCountController.text) != null && int.parse(_childrenCountController.text) > 0) 'Children',
        if (int.tryParse(_elderlyCountController.text) != null && int.parse(_elderlyCountController.text) > 0) 'Elderly',
        if (medicalCount > 0) 'Medical Patient',
      ],
      reporterPhoneMasked: user?.phoneMasked ?? _safePhoneController.text,
      reportedAt: DateTime.now(),
      source: 'CITIZEN_HELP_REQUEST',
      affectedProperties: _damagedAssets,
      estimatedLossInr: loss,
      householdMembersCount: affected,
      reliefRequirements: selectedNeedsList,
      evidencePhotos: _attachedPhotoProof ? ['flood_waterlogging_inundated_home_east_delhi.jpg'] : const [],
      assistanceDeliveryStatus: 'PENDING_INSPECTION',
    );

    ref.read(incidentsProvider.notifier).addIncident(incident);

    setState(() => _isSubmitting = false);

    // Confirmation Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.successGreen, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Request Transmitted Successfully',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Request Reference:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  Text(reqId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your assistance request has been routed to the District Emergency Operations Center (EOC) and authorized relief partners.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dispatch updates will appear in your tracking dashboard.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '${AppRoutes.citizenReports}/$reqId');
            },
            child: const Text('Open Request Tracking'),
          ),
        ],
      ),
    );
  }
}

class _HelpNeedItem {
  final String name;
  bool isSelected;
  String quantity;
  String urgency;

  _HelpNeedItem(this.name, {this.isSelected = false, required this.quantity, required this.urgency});
}
