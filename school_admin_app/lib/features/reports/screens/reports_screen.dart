import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _State();
}

class _State extends ConsumerState<ReportsScreen> {
  String _period = 'this_month';
  String _type = 'fee';

  static const _periods = [('this_month', 'This Month'), ('last_month', 'Last Month'), ('this_year', 'This Year')];
  static const _types = [('fee', 'Fee Collection', Icons.account_balance_wallet_rounded, AppTheme.success), ('attendance', 'Attendance', Icons.fact_check_rounded, AppTheme.primary), ('admission', 'Admissions', Icons.how_to_reg_rounded, AppTheme.warning), ('academic', 'Academic', Icons.quiz_rounded, AppTheme.secondary)];

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Reports & Analytics',
      body: Column(children: [
        _buildTopBar(),
        Expanded(child: FutureBuilder<Map<String, dynamic>>(
          future: ref.read(adminRepoProvider).getReports(type: _type, period: _period),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) return Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 12), child: const ShimmerBox(height: 80)))));
            if (snap.hasError) return ErrorState(message: snap.error.toString());
            final data = snap.data ?? {};
            return _buildReport(data);
          },
        )),
      ]),
    );
  }

  Widget _buildTopBar() => Container(
    color: AppTheme.cardBg,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Column(children: [
      // Period selector
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _periods.map((p) {
          final sel = _period == p.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _period = p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: sel ? AppTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider)),
                child: Text(p.$2, style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.w500)),
              ),
            ),
          );
        }).toList()),
      ),
      const SizedBox(height: 10),
      // Type selector
      Row(children: _types.map((t) {
        final sel = _type == t.$1;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _type = t.$1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: sel ? t.$4.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? t.$4 : AppTheme.divider)),
            child: Column(children: [Icon(t.$3, size: 18, color: sel ? t.$4 : AppTheme.textSecondary), const SizedBox(height: 3), Text(t.$2, style: TextStyle(fontSize: 10, color: sel ? t.$4 : AppTheme.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.w400), textAlign: TextAlign.center)]),
          ),
        ));
      }).toList()),
    ]),
  );

  Widget _buildReport(Map<String, dynamic> data) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final metrics = (data['metrics'] as List?) ?? [];
    final chartData = (data['chartData'] as List?) ?? [];
    final breakdown = (data['breakdown'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (metrics.isNotEmpty) ...[
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4,
            children: metrics.map((m) {
              final metric = m as Map<String, dynamic>;
              final val = metric['value'];
              final isNum = val is num;
              return StatCard(
                label: metric['label'] ?? '',
                value: isNum && (metric['format'] == 'currency') ? fmt.format(val) : val.toString(),
                icon: Icons.analytics_rounded,
                color: AppTheme.primary,
                subtitle: metric['change'],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        if (breakdown.isNotEmpty) ...[
          const SectionHeader(title: 'Breakdown'),
          ...breakdown.map((b) {
            final item = b as Map<String, dynamic>;
            final val = item['value'] ?? 0;
            final maxVal = breakdown.fold<num>(0, (p, e) => (e as Map)['value'] > p ? e['value'] : p);
            final pct = maxVal > 0 ? val / maxVal : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(item['label'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    Text(val is num ? (item['format'] == 'currency' ? fmt.format(val) : '$val') : val.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct.toDouble(), backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary), minHeight: 5)),
                ]),
              ),
            );
          }),
        ],

        if (data.isEmpty) const EmptyState(message: 'No report data available', icon: Icons.bar_chart_outlined),
      ]),
    );
  }
}
