// ============================================================================
// PATIENT INSIGHTS PANEL
// ============================================================================
// Donut chart showing new patients by department
// Recent patients table (name, ID, last visit, reason, status)
// "View Patient" button
// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../models/clinic_dashboard_models.dart';

class PatientInsightsPanel extends StatelessWidget {
  final PatientInsights insights;

  const PatientInsightsPanel({
    super.key,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Patient Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Navigate to patients list
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('View Patient'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart
          if (insights.newPatientsByDepartment.isNotEmpty) ...[
            SizedBox(
              height: 140,
              child: Row(
                children: [
                  // Donut Chart
                  Expanded(
                    flex: 2,
                    child: _buildDonutChart(),
                  ),
                  // Legend
                  Expanded(
                    flex: 1,
                    child: _buildChartLegend(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'New Patients By Department',
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 140,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No department data',
                      style: TextStyle(
                        fontSize: 12,
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Recent Patients Table
          Text(
            'Recent Patients',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FuturisticColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Table Header
          Row(
            children: [
              _TableHeader('Name, ID', flex: 2),
              _TableHeader('Last Visit', flex: 1),
              _TableHeader('Reason', flex: 2),
              _TableHeader('Status', flex: 1),
            ],
          ),
          const SizedBox(height: 8),

          // Table Rows
          if (insights.recentPatients.isNotEmpty)
            ...insights.recentPatients.take(5).map((patient) => _PatientRow(patient: patient))
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No recent patients',
                  style: TextStyle(
                    fontSize: 12,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDonutChart() {
    final sections = insights.newPatientsByDepartment.asMap().entries.map((entry) {
      final dept = entry.value;
      final colors = [
        const Color(0xFF1565C0), // Primary Blue
        const Color(0xFF00ACC1), // Cyan
        const Color(0xFF9C27B0), // Purple
        const Color(0xFFFF9800), // Orange
        const Color(0xFF4CAF50), // Green
      ];
      final color = colors[entry.key % colors.length];

      return PieChartSectionData(
        color: color,
        value: dept.percentage.toDouble(),
        title: '${dept.percentage}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 30,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(enabled: false),
      ),
    );
  }

  Widget _buildChartLegend() {
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF00ACC1),
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
      const Color(0xFF4CAF50),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: insights.newPatientsByDepartment.asMap().entries.map((entry) {
        final dept = entry.value;
        final color = colors[entry.key % colors.length];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  dept.department,
                  style: TextStyle(
                    fontSize: 10,
                    color: FuturisticColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${dept.percentage}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: FuturisticColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String label;
  final int flex;

  const _TableHeader(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: FuturisticColors.textSecondary,
        ),
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  final RecentPatient patient;

  const _PatientRow({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          // Name, ID
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FuturisticColors.textPrimary,
                  ),
                ),
                Text(
                  patient.id.substring(0, patient.id.length > 8 ? 8 : patient.id.length),
                  style: TextStyle(
                    fontSize: 10,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Last Visit
          Expanded(
            flex: 1,
            child: Text(
              patient.formattedLastVisit,
              style: TextStyle(
                fontSize: 11,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ),
          // Reason
          Expanded(
            flex: 2,
            child: Text(
              patient.reason,
              style: TextStyle(
                fontSize: 11,
                color: FuturisticColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(patient.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getStatusLabel(patient.status),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(patient.status),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'New';
      case 'returning':
        return 'Returning';
      case 'confirmed':
        return 'Confirmed';
      default:
        return status.capitalize();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return FuturisticColors.primary;
      case 'returning':
        return FuturisticColors.success;
      case 'confirmed':
        return const Color(0xFF9C27B0);
      default:
        return FuturisticColors.textSecondary;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
