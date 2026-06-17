import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

/// Fee Collection Bar Chart (last 6 months)
class FeeCollectionChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthlyData;
  const FeeCollectionChart({super.key, required this.monthlyData});

  @override
  Widget build(BuildContext context) {
    if (monthlyData.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final maxY = monthlyData.fold<double>(0, (p, e) => ((e['amount'] ?? 0) as num).toDouble() > p ? ((e['amount'] ?? 0) as num).toDouble() : p);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Fee Collection (6 months)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: BarChart(BarChartData(
            maxY: maxY * 1.2,
            barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(fmt.format(rod.toY), const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            )),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(fmt.format(v), style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i >= 0 && i < monthlyData.length) {
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(monthlyData[i]['month'] ?? '', style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)));
                }
                return const SizedBox.shrink();
              })),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.divider, strokeWidth: 0.8)),
            borderData: FlBorderData(show: false),
            barGroups: monthlyData.asMap().entries.map((e) => BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(toY: ((e.value['amount'] ?? 0) as num).toDouble(), color: AppTheme.primary, width: 18, borderRadius: BorderRadius.circular(4))],
            )).toList(),
          )),
        ),
      ]),
    );
  }
}

/// Attendance Donut Chart
class AttendanceDonutChart extends StatefulWidget {
  final double presentPct;
  final double absentPct;
  final double leavePct;
  const AttendanceDonutChart({super.key, required this.presentPct, required this.absentPct, required this.leavePct});

  @override
  State<AttendanceDonutChart> createState() => _AttendanceDonutChartState();
}

class _AttendanceDonutChartState extends State<AttendanceDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Today\'s Attendance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 16),
      Row(children: [
        SizedBox(
          height: 120, width: 120,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 32,
            pieTouchData: PieTouchData(touchCallback: (_, response) {
              setState(() => _touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1);
            }),
            sections: [
              _section(widget.presentPct, AppTheme.success, 'Present', 0),
              _section(widget.absentPct, AppTheme.error, 'Absent', 1),
              _section(widget.leavePct, AppTheme.warning, 'Leave', 2),
            ],
          )),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _legend(AppTheme.success, 'Present', '${widget.presentPct.toStringAsFixed(0)}%'),
          const SizedBox(height: 8),
          _legend(AppTheme.error, 'Absent', '${widget.absentPct.toStringAsFixed(0)}%'),
          const SizedBox(height: 8),
          _legend(AppTheme.warning, 'Leave', '${widget.leavePct.toStringAsFixed(0)}%'),
        ])),
      ]),
    ]),
  );

  PieChartSectionData _section(double value, Color color, String title, int index) {
    final isTouched = _touchedIndex == index;
    return PieChartSectionData(
      value: value.clamp(0.1, 100),
      color: color,
      radius: isTouched ? 36 : 30,
      title: isTouched ? '${value.toStringAsFixed(0)}%' : '',
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
    );
  }

  Widget _legend(Color color, String label, String value) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
  ]);
}

/// Admission Trend Line Chart (last 12 months)
class AdmissionTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  const AdmissionTrendChart({super.key, required this.trendData});

  @override
  Widget build(BuildContext context) {
    if (trendData.isEmpty) return const SizedBox.shrink();
    final spots = trendData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), ((e.value['count'] ?? 0) as num).toDouble())).toList();
    final maxY = trendData.fold<double>(0, (p, e) => ((e['count'] ?? 0) as num).toDouble() > p ? ((e['count'] ?? 0) as num).toDouble() : p);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Admissions Trend', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: LineChart(LineChartData(
            maxY: (maxY * 1.3).clamp(10, double.infinity),
            minY: 0,
            lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toInt()} admissions', const TextStyle(color: Colors.white, fontSize: 11))).toList(),
            )),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i >= 0 && i < trendData.length && i % 2 == 0) return Padding(padding: const EdgeInsets.only(top: 4), child: Text(trendData[i]['month'] ?? '', style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary)));
                return const SizedBox.shrink();
              })),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.divider, strokeWidth: 0.8)),
            borderData: FlBorderData(show: false),
            lineBarsData: [LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.warning,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppTheme.warning.withValues(alpha: 0.1)),
            )],
          )),
        ),
      ]),
    );
  }
}
