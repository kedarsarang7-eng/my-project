// ignore_for_file: unused_local_variable
// ============================================================================
// CLINIC PERFORMANCE PANEL
// ============================================================================
// Three sections:
// - Monthly Revenue Bar Chart
// - Upcoming Appointments Table
// - Avg Wait Time Gauge
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../models/clinic_dashboard_models.dart';
import '../widgets/role_guard.dart';

class ClinicPerformancePanel extends StatelessWidget {
  final BillingSummary billing;
  final AppointmentList appointments;
  final WaitTimeInfo waitTime;
  final bool isLargeDesktop;

  const ClinicPerformancePanel({
    super.key,
    required this.billing,
    required this.appointments,
    required this.waitTime,
    this.isLargeDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isLargeDesktop ? 32 : 24),
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
          // Title
          Text(
            'Clinic Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Content Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Monthly Revenue Chart
              Expanded(
                flex: 2,
                child: RoleGuard.billing(
                  fallback: _buildRevenuePlaceholder(),
                  child: _buildRevenueChart(),
                ),
              ),
              const SizedBox(width: 24),

              // Middle: Upcoming Appointments
              Expanded(
                flex: 2,
                child: _buildUpcomingAppointments(),
              ),
              const SizedBox(width: 24),

              // Right: Wait Time Gauge
              Expanded(
                flex: 1,
                child: _buildWaitTimeGauge(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenuePlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 32,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Revenue data restricted',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    if (billing.monthlyRevenue.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No revenue data',
            style: TextStyle(
              fontSize: 12,
              color: FuturisticColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final data = billing.monthlyRevenue;
    final maxY = data.map((d) => d.amountCents).reduce((a, b) => a > b ? a : b);
    final interval = maxY > 0 ? (maxY / 5).ceilToDouble() : 100000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Revenue',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FuturisticColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < data.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data[index].month.substring(0, 3),
                            style: TextStyle(
                              fontSize: 10,
                              color: FuturisticColors.textSecondary,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 20,
                  ),
                ),
              ),
              barGroups: data.asMap().entries.map((entry) {
                final index = entry.key;
                final revenue = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: revenue.amountCents.toDouble(),
                      color: FuturisticColors.primary,
                      width: 24,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
              maxY: maxY * 1.1,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (touchedSpot) => Colors.white,
                  tooltipBorder: BorderSide(color: Colors.grey.shade300),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final revenue = data[groupIndex];
                    return BarTooltipItem(
                      '${revenue.month}\n${revenue.formatted}',
                      TextStyle(
                        fontSize: 12,
                        color: FuturisticColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointments() {
    final upcoming = appointments.appointments
        .where((a) => a.status == 'scheduled')
        .take(4)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Appointments',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FuturisticColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Table Header
        Row(
          children: [
            _TableHeader('Name', flex: 2),
            _TableHeader('Type', flex: 1),
            _TableHeader('Doctor', flex: 2),
            _TableHeader('Status', flex: 1),
          ],
        ),
        const SizedBox(height: 8),

        // Table Rows
        if (upcoming.isNotEmpty)
          ...upcoming.map((appt) => _AppointmentRow(appointment: appt))
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No upcoming appointments',
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaitTimeGauge() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Avg. Patient Wait Time',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FuturisticColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Gauge
        SizedBox(
          height: 100,
          child: CustomPaint(
            size: const Size(120, 60),
            painter: _GaugePainter(
              value: waitTime.avgWaitMinutes,
              maxValue: 60,
              zone: waitTime.zone,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Time Display
        Text(
          waitTime.formattedTime,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _getZoneColor(waitTime.zone),
          ),
        ),
        const SizedBox(height: 4),

        // Zone Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getZoneColor(waitTime.zone).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            waitTime.zone.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _getZoneColor(waitTime.zone),
            ),
          ),
        ),
      ],
    );
  }

  Color _getZoneColor(WaitTimeZone zone) {
    switch (zone) {
      case WaitTimeZone.green:
        return const Color(0xFF2E7D32); // Green
      case WaitTimeZone.yellow:
        return const Color(0xFFF57F17); // Amber
      case WaitTimeZone.red:
        return const Color(0xFFC62828); // Red
    }
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

class _AppointmentRow extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentRow({required this.appointment});

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
          Expanded(
            flex: 2,
            child: Text(
              appointment.patientName,
              style: TextStyle(
                fontSize: 12,
                color: FuturisticColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              appointment.type.capitalize(),
              style: TextStyle(
                fontSize: 11,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              appointment.doctorName,
              style: TextStyle(
                fontSize: 11,
                color: FuturisticColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: FuturisticColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Confirmed',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: FuturisticColors.success,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the gauge
class _GaugePainter extends CustomPainter {
  final int value;
  final int maxValue;
  final WaitTimeZone zone;

  _GaugePainter({
    required this.value,
    required this.maxValue,
    required this.zone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    // Background arc (gray)
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      3.14159, // Start from left
      3.14159, // 180 degrees
      false,
      bgPaint,
    );

    // Value arc (colored)
    final zoneColors = {
      WaitTimeZone.green: const Color(0xFF2E7D32),
      WaitTimeZone.yellow: const Color(0xFFF57F17),
      WaitTimeZone.red: const Color(0xFFC62828),
    };

    final valuePaint = Paint()
      ..color = zoneColors[zone] ?? Colors.grey
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (value / maxValue).clamp(0.0, 1.0) * 3.14159;

    canvas.drawArc(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      3.14159,
      sweepAngle,
      false,
      valuePaint,
    );

    // Ticks
    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    for (int i = 0; i <= 6; i++) {
      final angle = 3.14159 + (i / 6) * 3.14159;
      final tickStart = Offset(
        center.dx + (radius - 8) * cos(angle),
        center.dy + (radius - 8) * sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(tickStart, tickEnd, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
