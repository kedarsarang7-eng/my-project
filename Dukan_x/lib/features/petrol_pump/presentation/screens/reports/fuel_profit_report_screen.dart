import 'package:flutter/material.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/session/session_manager.dart';
import '../../../../../core/repository/bills_repository.dart';
import '../../../services/fuel_service.dart';
import '../../../models/fuel_type.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Summary data computed from actual bill records within a date range.
class FuelProfitSummary {
  final double totalSales;
  final double totalCost;
  final double profit;
  final double marginPercent;

  /// Per-fuel breakdown: fuelName → {litresSold, revenue, marginPercent}
  final Map<String, FuelBreakdown> perFuel;

  const FuelProfitSummary({
    this.totalSales = 0,
    this.totalCost = 0,
    this.profit = 0,
    this.marginPercent = 0,
    this.perFuel = const {},
  });
}

/// Per-fuel-type breakdown metrics.
class FuelBreakdown {
  final double litresSold;
  final double revenue;
  final double marginPercent;

  const FuelBreakdown({
    this.litresSold = 0,
    this.revenue = 0,
    this.marginPercent = 0,
  });
}

/// Fuel Profit Analysis Report Screen
class FuelProfitReportScreen extends StatefulWidget {
  const FuelProfitReportScreen({super.key});

  @override
  State<FuelProfitReportScreen> createState() => _FuelProfitReportScreenState();
}

class _FuelProfitReportScreenState extends State<FuelProfitReportScreen> {
  final _fuelService = sl<FuelService>();

  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  FuelProfitSummary _summary = const FuelProfitSummary();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Compute summary for default range on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _computeSummary(_selectedRange);
    });
  }

  /// Queries BillsRepository for petrolPump bills within [range],
  /// sums Total Sales / Litres Sold / Revenue per fuel, and computes
  /// Profit and Margin. Cost is stubbed as 0 until Surface 7 lands.
  Future<void> _computeSummary(DateTimeRange range) async {
    setState(() => _isLoading = true);

    try {
      final ownerId = sl<SessionManager>().ownerId ?? '';
      final billsRepo = sl<BillsRepository>();

      final result = await billsRepo.getAll(userId: ownerId);
      final allBills = result.data ?? <Bill>[];

      // Filter to petrolPump bills within the selected date range
      final rangeStart = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final rangeEnd = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );

      final filteredBills = allBills.where((bill) {
        return bill.businessType == 'petrolPump' &&
            !bill.date.isBefore(rangeStart) &&
            !bill.date.isAfter(rangeEnd);
      }).toList();

      // Aggregate totals
      double totalSales = 0;
      final Map<String, double> fuelLitres = {};
      final Map<String, double> fuelRevenue = {};

      for (final bill in filteredBills) {
        totalSales += bill.grandTotal;

        // Per-fuel breakdown from bill items
        for (final item in bill.items) {
          // Use the bill's fuelType or fall back to item productName as fuel key
          final fuelKey = bill.fuelType ?? item.productName;
          fuelLitres[fuelKey] = (fuelLitres[fuelKey] ?? 0) + item.qty;
          fuelRevenue[fuelKey] = (fuelRevenue[fuelKey] ?? 0) + item.total;
        }
      }

      // Total Cost: stub as 0 until Surface 7 (purchase price) lands
      const double totalCost = 0;
      final double profit = totalSales - totalCost;
      final double marginPercent = totalSales > 0
          ? (profit / totalSales) * 100
          : 0;

      // Build per-fuel breakdown
      final perFuel = <String, FuelBreakdown>{};
      for (final key in {...fuelLitres.keys, ...fuelRevenue.keys}) {
        final litres = fuelLitres[key] ?? 0;
        final revenue = fuelRevenue[key] ?? 0;
        // Per-fuel margin: revenue - cost (cost stubbed as 0)
        final fuelMargin = revenue > 0 ? (revenue / revenue) * 100 : 0;
        perFuel[key] = FuelBreakdown(
          litresSold: litres,
          revenue: revenue,
          // With cost stubbed as 0, margin = 100% when there's revenue;
          // will be corrected once Surface 7 provides purchase price
          marginPercent: revenue > 0 ? fuelMargin.toDouble() : 0,
        );
      }

      setState(() {
        _summary = FuelProfitSummary(
          totalSales: totalSales,
          totalCost: totalCost,
          profit: profit,
          marginPercent: marginPercent,
          perFuel: perFuel,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error computing summary: $e')));
      }
    }
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
    );

    if (range != null) {
      setState(() {
        _selectedRange = range;
      });
      await _computeSummary(_selectedRange);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Showing data from ${range.start.day}/${range.start.month} to ${range.end.day}/${range.end.month}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Profit Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date Range',
            onPressed: () => _selectDateRange(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<FuelType>>(
              stream: _fuelService.getFuelTypes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final fuels = snapshot.data!.where((f) => f.isActive).toList();

                if (fuels.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_gas_station_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('No fuel types configured'),
                        SizedBox(height: 8),
                        Text('Configure fuel rates in Petrol Pump settings'),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Summary',
                              style: TextStyle(
                                fontSize: responsiveValue<double>(
                                  context,
                                  mobile: 14.0,
                                  tablet: 16.0,
                                  desktop:
                                      18.0, // PRESERVED: Desktop uses exactly 18 as before
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            context.isMobile
                                ? Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: _buildSummaryItem(
                                              'Total Sales',
                                              '₹${_summary.totalSales.toStringAsFixed(0)}',
                                              Icons.trending_up,
                                              Colors.green,
                                            ),
                                          ),
                                          Expanded(
                                            child: _buildSummaryItem(
                                              'Total Cost',
                                              '₹${_summary.totalCost.toStringAsFixed(0)}',
                                              Icons.trending_down,
                                              Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildSummaryItem(
                                        'Profit',
                                        '₹${_summary.profit.toStringAsFixed(0)}',
                                        Icons.account_balance_wallet,
                                        Colors.blue,
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildSummaryItem(
                                        'Total Sales',
                                        '₹${_summary.totalSales.toStringAsFixed(0)}',
                                        Icons.trending_up,
                                        Colors.green,
                                      ),
                                      _buildSummaryItem(
                                        'Total Cost',
                                        '₹${_summary.totalCost.toStringAsFixed(0)}',
                                        Icons.trending_down,
                                        Colors.red,
                                      ),
                                      _buildSummaryItem(
                                        'Profit',
                                        '₹${_summary.profit.toStringAsFixed(0)}',
                                        Icons.account_balance_wallet,
                                        Colors.blue,
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fuel-wise breakdown
                    const Text(
                      'Fuel-wise Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...fuels.map((fuel) => _buildFuelProfitCard(fuel)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: responsiveValue<double>(
              context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
            ),
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildFuelProfitCard(FuelType fuel) {
    // Look up per-fuel breakdown by fuel name
    final breakdown =
        _summary.perFuel[fuel.fuelName] ??
        _summary.perFuel[fuel.fuelId] ??
        const FuelBreakdown();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fuel.fuelName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '₹${fuel.currentRatePerLitre.toStringAsFixed(2)}/L',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            context.isMobile
                ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMetric(
                            'Litres Sold',
                            '${breakdown.litresSold.toStringAsFixed(1)} L',
                          ),
                          _buildMetric(
                            'Revenue',
                            '₹${breakdown.revenue.toStringAsFixed(0)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _buildMetric(
                          'Margin',
                          '${breakdown.marginPercent.toStringAsFixed(1)}%',
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(
                        'Litres Sold',
                        '${breakdown.litresSold.toStringAsFixed(1)} L',
                      ),
                      _buildMetric(
                        'Revenue',
                        '₹${breakdown.revenue.toStringAsFixed(0)}',
                      ),
                      _buildMetric(
                        'Margin',
                        '${breakdown.marginPercent.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
