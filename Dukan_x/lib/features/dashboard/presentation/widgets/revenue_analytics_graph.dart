import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/neon_card.dart';
import '../../../dashboard/data/dashboard_analytics_repository.dart';
import '../../../../core/session/session_manager.dart';

class RevenueAnalyticsGraph extends StatefulWidget {
  final Map<DateTime, double>? dataMap; // Optional: Pass data directly
  final bool isLoading;

  const RevenueAnalyticsGraph({
    super.key,
    this.dataMap,
    this.isLoading = false,
  });

  @override
  State<RevenueAnalyticsGraph> createState() => _RevenueAnalyticsGraphState();
}

class _RevenueAnalyticsGraphState extends State<RevenueAnalyticsGraph> {
  String _selectedFilter = 'Weekly'; // Daily, Weekly, Monthly
  bool _isLoading = true;
  Map<DateTime, double> _chartData = {};
  double _maxY = 1000;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.dataMap != null) {
      _chartData = widget.dataMap!;
      _isLoading = widget.isLoading;
      _calculateMaxY();
    } else {
      _fetchData();
    }
  }

  @override
  void didUpdateWidget(covariant RevenueAnalyticsGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataMap != null && widget.dataMap != oldWidget.dataMap) {
      setState(() {
        _chartData = widget.dataMap!;
        _isLoading = widget.isLoading;
        _calculateMaxY();
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = sl<SessionManager>().userId;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "User not logged in";
        });
        return;
      }

      final now = DateTime.now();
      DateTime startDate;

      // Determine date range based on filter
      switch (_selectedFilter) {
        case 'Daily':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'Weekly':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case 'Monthly':
          startDate = now.subtract(
            const Duration(days: 90),
          ); // Show last 3 months
          break;
        default:
          startDate = now.subtract(const Duration(days: 30));
      }

      final result = await sl<DashboardAnalyticsRepository>().getRevenueStats(
        userId: userId,
        startDate: startDate,
        endDate: now,
      );

      if (mounted) {
        setState(() {
          _chartData = result.data ?? {};
          _calculateMaxY();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _calculateMaxY() {
    if (_chartData.isEmpty) {
      _maxY = 1000;
      return;
    }
    double max = 0;
    for (var val in _chartData.values) {
      if (val > max) max = val;
    }
    _maxY = max * 1.25; // Add 25% padding
    if (_maxY == 0) _maxY = 1000;
  }

  // Generate spots for Line Chart
  List<FlSpot> _getLineSpots() {
    if (_chartData.isEmpty) return [];
    final sortedKeys = _chartData.keys.toList()..sort();
    final List<FlSpot> spots = [];
    for (int i = 0; i < sortedKeys.length; i++) {
      spots.add(FlSpot(i.toDouble(), _chartData[sortedKeys[i]]!));
    }
    return spots;
  }

  // Generate groups for Bar Chart
  List<BarChartGroupData> _getBarGroups() {
    if (_chartData.isEmpty) return [];
    final sortedKeys = _chartData.keys.toList()..sort();
    final List<BarChartGroupData> groups = [];

    for (int i = 0; i < sortedKeys.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _chartData[sortedKeys[i]]!,
              color: FuturisticColors.primary.withOpacity(0.15),
              width: 12,
              borderRadius: BorderRadius.circular(2),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: _maxY, // Fill height for "grid" effect
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      );
    }
    return groups;
  }

  // Get X-axis labels based on date keys
  String _getBottomTitle(double value) {
    if (_chartData.isEmpty) return '';
    final sortedKeys = _chartData.keys.toList()..sort();
    final index = value.toInt();

    if (index >= 0 && index < sortedKeys.length) {
      final date = sortedKeys[index];
      if (_selectedFilter == 'Daily') {
        return DateFormat('E').format(date);
      } else if (_selectedFilter == 'Weekly') {
        // Show only some dates to avoid clutter
        if (index % 5 == 0) return DateFormat('d MMM').format(date);
        return '';
      } else {
        return DateFormat('d MMM').format(date);
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      height: 400,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue Analytics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: FuturisticColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revenue vs Time',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // Filter Toggle
              Container(
                decoration: BoxDecoration(
                  color: FuturisticColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FuturisticColors.divider),
                ),
                child: Row(
                  children: ['Daily', 'Weekly', 'Monthly'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        if (widget.dataMap == null) {
                          _fetchData();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? FuturisticColors.primary.withOpacity(0.2)
                              : null,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(filter == 'Daily' ? 8 : 0),
                            bottomLeft: Radius.circular(
                              filter == 'Daily' ? 8 : 0,
                            ),
                            topRight: Radius.circular(
                              filter == 'Monthly' ? 8 : 0,
                            ),
                            bottomRight: Radius.circular(
                              filter == 'Monthly' ? 8 : 0,
                            ),
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected
                                ? FuturisticColors.primary
                                : FuturisticColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Chart Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: FuturisticColors.error),
                    ),
                  )
                : _chartData.isEmpty
                ? const Center(
                    child: Text(
                      'No revenue data available',
                      style: TextStyle(color: FuturisticColors.textSecondary),
                    ),
                  )
                : Stack(
                    children: [
                      // Layer 1: Bar Chart (Background for Volume)
                      BarChart(
                        BarChartData(
                          barTouchData: BarTouchData(
                            enabled: false,
                          ), // Disable touch on bars to let Line accept it
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                          minY: 0,
                          maxY: _maxY,
                          barGroups: _getBarGroups(),
                        ),
                      ),

                      // Layer 2: Line Chart (Foreground for Trend)
                      LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _maxY / 5,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: FuturisticColors.divider.withOpacity(
                                  0.05,
                                ), // Faint grid
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _getBottomTitle(value),
                                      style: const TextStyle(
                                        color: FuturisticColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                },
                                reservedSize: 30,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: _maxY / 5,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    NumberFormat.compact().format(value),
                                    style: const TextStyle(
                                      color: FuturisticColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  );
                                },
                                reservedSize: 40,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: _chartData.length.toDouble() - 1,
                          minY: 0,
                          maxY: _maxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _getLineSpots(),
                              isCurved: true,
                              color: FuturisticColors.accent1,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    FuturisticColors.accent1.withOpacity(0.2),
                                    FuturisticColors.accent1.withOpacity(0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) =>
                                  FuturisticColors.surface.withOpacity(0.9),
                              tooltipPadding: const EdgeInsets.all(8),
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((
                                  LineBarSpot touchedSpot,
                                ) {
                                  return LineTooltipItem(
                                    '${_getBottomTitle(touchedSpot.x)}\n',
                                    const TextStyle(
                                      color: FuturisticColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: sl<CurrencyService>().format(touchedSpot.y),
                                        style: const TextStyle(
                                          color: FuturisticColors.accent1,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList();
                              },
                            ),
                          ),
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
