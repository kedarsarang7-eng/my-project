import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/neon_card.dart';
import '../../../dashboard/data/dashboard_analytics_repository.dart';
import '../../../../core/session/session_manager.dart';

class ExpenseOverviewChart extends StatefulWidget {
  const ExpenseOverviewChart({super.key});

  @override
  State<ExpenseOverviewChart> createState() => _ExpenseOverviewChartState();
}

class _ExpenseOverviewChartState extends State<ExpenseOverviewChart> {
  bool _isLoading = true;
  Map<String, double> _data = {};
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userId = sl<SessionManager>().userId;
      if (userId == null) return;

      final now = DateTime.now();
      final result = await sl<DashboardAnalyticsRepository>()
          .getExpenseBreakdown(userId: userId, monthDate: now);

      if (mounted) {
        setState(() {
          _data = result.data ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<PieChartSectionData> _showingSections() {
    if (_data.isEmpty) return [];

    final total = _data.values.fold(0.0, (sum, val) => sum + val);
    final List<Color> colors = [
      FuturisticColors.accent1, // Cyan
      FuturisticColors.accent2, // Purple
      FuturisticColors.primary, // Blue
      FuturisticColors.warning, // Yellow
      FuturisticColors.error, // Red
      Colors.green,
    ];

    int index = 0;
    return _data.entries.map((entry) {
      final isTouched = index == _touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 50.0 : 40.0;
      final color = colors[index % colors.length];
      final percent = (entry.value / total * 100).toStringAsFixed(1);

      final section = PieChartSectionData(
        color: color,
        value: entry.value,
        title: '$percent%', // Hide title if small?
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 2),
          ],
        ),
      );
      index++;
      return section;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // We only need top 4 items for legend, rest can be 'Others' visually if too many
    // But for simplicity, we list them all for now or scroll

    final sortedEntries = _data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = _data.values.fold(0.0, (sum, val) => sum + val);

    return NeonCard(
      height: 350,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expense Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: FuturisticColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FuturisticColors.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FuturisticColors.divider),
                ),
                child: const Text(
                  'This Month',
                  style: TextStyle(
                    color: FuturisticColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_data.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No expenses recorded this month',
                  style: TextStyle(color: FuturisticColors.textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  // Chart
                  Expanded(
                    flex: 3,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback:
                                  (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection ==
                                              null) {
                                        _touchedIndex = -1;
                                        return;
                                      }
                                      _touchedIndex = pieTouchResponse
                                          .touchedSection!
                                          .touchedSectionIndex;
                                    });
                                  },
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: _showingSections(),
                          ),
                        ),
                        // Center Text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                color: FuturisticColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              NumberFormat.compactCurrency(
                                symbol: sl<CurrencyService>().symbol,
                              ).format(totalExpense),
                              style: const TextStyle(
                                color: FuturisticColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Legend
                  Expanded(
                    flex: 2,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: sortedEntries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = sortedEntries[index];
                        final List<Color> colors = [
                          FuturisticColors.accent1, // Cyan
                          FuturisticColors.accent2, // Purple
                          FuturisticColors.primary, // Blue
                          FuturisticColors.warning, // Yellow
                          FuturisticColors.error, // Red
                          Colors.green,
                        ];
                        final color = colors[index % colors.length];
                        return Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  color: FuturisticColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              NumberFormat.compact().format(entry.value),
                              style: const TextStyle(
                                color: FuturisticColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
