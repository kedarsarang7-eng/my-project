import 'package:flutter/material.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../services/fuel_service.dart';
import '../../../models/fuel_type.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Fuel Profit Analysis Report Screen
class FuelProfitReportScreen extends StatefulWidget {
  const FuelProfitReportScreen({super.key});

  @override
  State<FuelProfitReportScreen> createState() => _FuelProfitReportScreenState();
}

class _FuelProfitReportScreenState extends State<FuelProfitReportScreen> {
  final _fuelService = sl<FuelService>();

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
      body: StreamBuilder<List<FuelType>>(
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
                          fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      context.isMobile
                          ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: _buildSummaryItem(
                                        'Total Sales',
                                        '₹0',
                                        Icons.trending_up,
                                        Colors.green,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildSummaryItem(
                                        'Total Cost',
                                        '₹0',
                                        Icons.trending_down,
                                        Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildSummaryItem(
                                  'Profit',
                                  '₹0',
                                  Icons.account_balance_wallet,
                                  Colors.blue,
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryItem(
                                  'Total Sales',
                                  '₹0',
                                  Icons.trending_up,
                                  Colors.green,
                                ),
                                _buildSummaryItem(
                                  'Total Cost',
                                  '₹0',
                                  Icons.trending_down,
                                  Colors.red,
                                ),
                                _buildSummaryItem(
                                  'Profit',
                                  '₹0',
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
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
                          _buildMetric('Litres Sold', '0 L'),
                          _buildMetric('Revenue', '₹0'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _buildMetric('Margin', '0%'),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric('Litres Sold', '0 L'),
                      _buildMetric('Revenue', '₹0'),
                      _buildMetric('Margin', '0%'),
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

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    );

    if (range != null) {
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
