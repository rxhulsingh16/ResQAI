const fs = require('fs');

// --- 1. Update transparency_overview_screen.dart ---
let transp = fs.readFileSync('lib/features/transparency/transparency_overview_screen.dart', 'utf8').replace(/\r\n/g, '\n');

const oldTranspMetrics = `            // Top Financial Accountability Metrics
            Row(
              children: [
                Expanded(
                  child: _buildFinancialMetric(
                    'TOTAL CITIZEN DONATIONS',
                    '₹\${totalRaised.toStringAsFixed(0)}',
                    'Received via Razorpay PG',
                    AppColors.primaryBlue,
                    isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildFinancialMetric(
                    'VERIFIED EXPENDITURE',
                    '₹\${totalSpent.toStringAsFixed(0)}',
                    '100% Tax Invoice Backed',
                    AppColors.successGreen,
                    isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildFinancialMetric(
                    'AVAILABLE RELIEF BALANCE',
                    '₹\${(totalRaised - totalSpent).toStringAsFixed(0)}',
                    'Active Unspent Reserves',
                    AppColors.warningOrange,
                    isDark,
                  ),
                ),
              ],
            ),`;

const newTranspMetrics = `            // Top Financial Accountability Metrics (Responsive Grid)
            if (isMobile)
              Column(
                children: [
                  _buildFinancialMetric(
                    'TOTAL CITIZEN DONATIONS',
                    '₹\${totalRaised.toStringAsFixed(0)}',
                    'Received via Razorpay PG',
                    AppColors.primaryBlue,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildFinancialMetric(
                    'VERIFIED EXPENDITURE',
                    '₹\${totalSpent.toStringAsFixed(0)}',
                    '100% Tax Invoice Backed',
                    AppColors.successGreen,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildFinancialMetric(
                    'AVAILABLE RELIEF BALANCE',
                    '₹\${(totalRaised - totalSpent).toStringAsFixed(0)}',
                    'Active Unspent Reserves',
                    AppColors.warningOrange,
                    isDark,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildFinancialMetric(
                      'TOTAL CITIZEN DONATIONS',
                      '₹\${totalRaised.toStringAsFixed(0)}',
                      'Received via Razorpay PG',
                      AppColors.primaryBlue,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildFinancialMetric(
                      'VERIFIED EXPENDITURE',
                      '₹\${totalSpent.toStringAsFixed(0)}',
                      '100% Tax Invoice Backed',
                      AppColors.successGreen,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildFinancialMetric(
                      'AVAILABLE RELIEF BALANCE',
                      '₹\${(totalRaised - totalSpent).toStringAsFixed(0)}',
                      'Active Unspent Reserves',
                      AppColors.warningOrange,
                      isDark,
                    ),
                  ),
                ],
              ),`;

transp = transp.replace(oldTranspMetrics, newTranspMetrics);
fs.writeFileSync('lib/features/transparency/transparency_overview_screen.dart', transp, 'utf8');
console.log('Updated transparency_overview_screen.dart');


// --- 2. Update risk_forecast_screen.dart ---
let risk = fs.readFileSync('lib/features/intelligence/risk_forecast_screen.dart', 'utf8').replace(/\r\n/g, '\n');

const oldRiskMetrics = `            // Main Prediction Metric Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'PREDICTED RISK INDEX',
                    value: '\${currentData['riskScore']}/100',
                    subtitle: 'HIGH INUNDATION PROBABILITY',
                    color: AppColors.criticalRed,
                    icon: Icons.speed,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'MODEL CONFIDENCE',
                    value: '\${currentData['confidence']}%',
                    subtitle: '±2.4% UNCERTAINTY BAND',
                    color: AppColors.primaryBlue,
                    icon: Icons.check_circle_outline,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'PROJECTED PEAK GAUGE',
                    value: (currentData['waterLevelForecast'] as String).split(' ').first,
                    subtitle: 'DANGER MARK: 205.33m',
                    color: AppColors.warningOrange,
                    icon: Icons.water,
                    isDark: isDark,
                  ),
                ),
              ],
            ),`;

const newRiskMetrics = `            // Main Prediction Metric Cards (Responsive Grid)
            if (isMobile)
              Column(
                children: [
                  _buildMetricCard(
                    title: 'PREDICTED RISK INDEX',
                    value: '\${currentData['riskScore']}/100',
                    subtitle: 'HIGH INUNDATION PROBABILITY',
                    color: AppColors.criticalRed,
                    icon: Icons.speed,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    title: 'MODEL CONFIDENCE',
                    value: '\${currentData['confidence']}%',
                    subtitle: '±2.4% UNCERTAINTY BAND',
                    color: AppColors.primaryBlue,
                    icon: Icons.check_circle_outline,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    title: 'PROJECTED PEAK GAUGE',
                    value: (currentData['waterLevelForecast'] as String).split(' ').first,
                    subtitle: 'DANGER MARK: 205.33m',
                    color: AppColors.warningOrange,
                    icon: Icons.water,
                    isDark: isDark,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PREDICTED RISK INDEX',
                      value: '\${currentData['riskScore']}/100',
                      subtitle: 'HIGH INUNDATION PROBABILITY',
                      color: AppColors.criticalRed,
                      icon: Icons.speed,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'MODEL CONFIDENCE',
                      value: '\${currentData['confidence']}%',
                      subtitle: '±2.4% UNCERTAINTY BAND',
                      color: AppColors.primaryBlue,
                      icon: Icons.check_circle_outline,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PROJECTED PEAK GAUGE',
                      value: (currentData['waterLevelForecast'] as String).split(' ').first,
                      subtitle: 'DANGER MARK: 205.33m',
                      color: AppColors.warningOrange,
                      icon: Icons.water,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),`;

risk = risk.replace(oldRiskMetrics, newRiskMetrics);
fs.writeFileSync('lib/features/intelligence/risk_forecast_screen.dart', risk, 'utf8');
console.log('Updated risk_forecast_screen.dart');


// --- 3. Update government_command_centre_screen.dart ---
let govt = fs.readFileSync('lib/features/government/government_command_centre_screen.dart', 'utf8').replace(/\r\n/g, '\n');

// Replace Colors.pink with AppColors.primaryRed
govt = govt.replace('case UserRole.doctor: return Colors.pink;', 'case UserRole.doctor: return AppColors.primaryRed;');

// Equal height for _buildKpiCard
const oldKpi = `  Widget _buildKpiCard(String label, String value, Color color, bool isDark) {
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
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }`;

const newKpi = `  Widget _buildKpiCard(String label, String value, Color color, bool isDark) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }`;

govt = govt.replace(oldKpi, newKpi);
fs.writeFileSync('lib/features/government/government_command_centre_screen.dart', govt, 'utf8');
console.log('Updated government_command_centre_screen.dart');
