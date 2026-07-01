import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../services/daybook_service.dart';
import '../../../../../models/daybook_entry.dart';
import '../../../services/shift_service.dart';
import '../../../services/tank_service.dart';
import '../../../models/shift.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Daily Sales Report (DSR) Screen for Petrol Pump
/// Shows comprehensive daily summary: opening stock, purchases, sales,
/// closing stock, and payment summary
class DsrReportScreen extends StatefulWidget {
  const DsrReportScreen({super.key});

  @override
  State<DsrReportScreen> createState() => _DsrReportScreenState();
}

class _DsrReportScreenState extends State<DsrReportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  DsrData? _dsrData;

  @override
  void initState() {
    super.initState();
    _loadDsrData();
  }

  Future<void> _loadDsrData() async {
    setState(() => _isLoading = true);
    try {
      final shiftService = sl<ShiftService>();
      final tankService = sl<TankService>();

      // Get all shifts for the selected date
      final dayStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final dayEnd = dayStart.add(const Duration(days: 1));

      final shifts = await shiftService.getShiftsForDateRange(dayStart, dayEnd);
      final tanks = await tankService.getTanks().first;

      // Calculate totals from shifts
      double totalSalesAmount = 0;
      double totalLitresSold = 0;
      double totalCash = 0;
      double totalOnline = 0;
      double totalCard = 0;
      double totalCredit = 0;
      int billCount = 0;

      for (final shift in shifts) {
        totalSalesAmount += shift.totalSaleAmount;
        totalLitresSold += shift.totalLitresSold;
        totalCash += shift.paymentBreakup.cash;
        totalOnline += shift.paymentBreakup.upi;
        totalCard += shift.paymentBreakup.card;
        totalCredit += shift.paymentBreakup.credit;
        billCount++; // Count each shift as 1 (we don't have individual bills count)
      }

      // Build fuel-wise breakdown
      final fuelSummary = <String, FuelDaySummary>{};

      // Get DayBook entry for opening stock
      final dayBookService = sl<DayBookService>();
      final ownerId = sl<AppDatabase>()
          .toString()
          .hashCode
          .toString(); // Simplified owner
      DayBookEntry? dayBookEntry;
      try {
        dayBookEntry = await dayBookService.getOrCreateEntry(
          ownerId,
          _selectedDate,
        );
      } catch (_) {
        // DayBook entry may not exist yet
      }

      // Get purchases for the day
      final db = sl<AppDatabase>();
      final purchases =
          await (db.select(db.purchaseOrders)..where(
                (p) =>
                    p.purchaseDate.isBetweenValues(dayStart, dayEnd) &
                    p.deletedAt.isNull(),
              ))
              .get();

      // Calculate total purchases
      double totalPurchaseAmount = 0;
      for (final po in purchases) {
        totalPurchaseAmount += po.totalAmount;
      }

      for (final tank in tanks) {
        // Calculate opening stock from daybook or estimate
        final openingStock =
            dayBookEntry?.openingCashBalance ?? tank.currentStock;

        // Calculate purchases for this fuel type
        final fuelPurchases =
            totalPurchaseAmount / (tanks.isNotEmpty ? tanks.length : 1);

        fuelSummary[tank.fuelTypeId] = FuelDaySummary(
          fuelType: tank.tankName,
          openingStock: openingStock,
          closingStock: tank.currentStock,
          purchases: fuelPurchases,
          sales: 0,
        );
      }

      // Fuel-wise breakdown simplified - use tank data only for now
      // Note: Per-nozzle tracking would require ShiftReconciliation data

      setState(() {
        _dsrData = DsrData(
          date: _selectedDate,
          shifts: shifts,
          totalSalesAmount: totalSalesAmount,
          totalLitresSold: totalLitresSold,
          cashCollected: totalCash,
          onlineCollected: totalOnline,
          cardCollected: totalCard,
          creditSales: totalCredit,
          billCount: billCount,
          fuelSummary: fuelSummary.values.toList(),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading DSR: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadDsrData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Sales Report (DSR)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDsrData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dsrData == null
          ? const Center(child: Text('No data available'))
          : _buildDsrContent(),
    );
  }

  Widget _buildDsrContent() {
    final data = _dsrData!;
    final dateFormat = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          Card(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: ${dateFormat.format(data.date)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${data.shifts.length} Shifts',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sales Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Total Sales',
                    '₹${data.totalSalesAmount.toStringAsFixed(2)}',
                  ),
                  _buildSummaryRow(
                    'Total Litres Sold',
                    '${data.totalLitresSold.toStringAsFixed(2)} L',
                  ),
                  _buildSummaryRow('Total Bills', '${data.billCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment Collection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Collection',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Cash',
                    '₹${data.cashCollected.toStringAsFixed(2)}',
                    valueColor: Colors.green,
                  ),
                  _buildSummaryRow(
                    'Online/UPI',
                    '₹${data.onlineCollected.toStringAsFixed(2)}',
                    valueColor: Colors.blue,
                  ),
                  _buildSummaryRow(
                    'Card',
                    '₹${data.cardCollected.toStringAsFixed(2)}',
                    valueColor: Colors.purple,
                  ),
                  _buildSummaryRow(
                    'Credit',
                    '₹${data.creditSales.toStringAsFixed(2)}',
                    valueColor: Colors.orange,
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Total Collected',
                    '₹${(data.cashCollected + data.onlineCollected + data.cardCollected).toStringAsFixed(2)}',
                    valueColor: Colors.teal,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fuel-wise Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fuel-wise Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  if (data.fuelSummary.isEmpty)
                    const Text('No fuel data available')
                  else
                    ...data.fuelSummary.map(
                      (fuel) => _buildFuelSummaryCard(fuel),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Shift-wise Breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shift-wise Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  if (data.shifts.isEmpty)
                    const Text('No shifts for this date')
                  else
                    ...data.shifts.map((shift) => _buildShiftCard(shift)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelSummaryCard(FuelDaySummary fuel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fuel.fuelType,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          context.isMobile
              ? SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMiniStat(
                        'Opening',
                        '${fuel.openingStock.toStringAsFixed(0)} L',
                      ),
                      _buildMiniStat(
                        'Purchases',
                        '+${fuel.purchases.toStringAsFixed(0)} L',
                      ),
                      _buildMiniStat('Sales', '-${fuel.sales.toStringAsFixed(0)} L'),
                      _buildMiniStat(
                        'Closing',
                        '${fuel.closingStock.toStringAsFixed(0)} L',
                      ),
                    ],
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStat(
                      'Opening',
                      '${fuel.openingStock.toStringAsFixed(0)} L',
                    ),
                    _buildMiniStat(
                      'Purchases',
                      '+${fuel.purchases.toStringAsFixed(0)} L',
                    ),
                    _buildMiniStat('Sales', '-${fuel.sales.toStringAsFixed(0)} L'),
                    _buildMiniStat(
                      'Closing',
                      '${fuel.closingStock.toStringAsFixed(0)} L',
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildShiftCard(Shift shift) {
    final timeFormat = DateFormat('hh:mm a');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shift.shiftName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${timeFormat.format(shift.startTime)} - ${shift.endTime != null ? timeFormat.format(shift.endTime!) : 'Active'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${shift.totalSaleAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${shift.totalLitresSold.toStringAsFixed(1)} L',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// DSR Data Model
class DsrData {
  final DateTime date;
  final List<Shift> shifts;
  final double totalSalesAmount;
  final double totalLitresSold;
  final double cashCollected;
  final double onlineCollected;
  final double cardCollected;
  final double creditSales;
  final int billCount;
  final List<FuelDaySummary> fuelSummary;

  DsrData({
    required this.date,
    required this.shifts,
    required this.totalSalesAmount,
    required this.totalLitresSold,
    required this.cashCollected,
    required this.onlineCollected,
    required this.cardCollected,
    required this.creditSales,
    required this.billCount,
    required this.fuelSummary,
  });
}

/// Fuel-wise daily summary
class FuelDaySummary {
  final String fuelType;
  final double openingStock;
  final double purchases;
  final double sales;
  final double closingStock;

  FuelDaySummary({
    required this.fuelType,
    required this.openingStock,
    required this.purchases,
    required this.sales,
    required this.closingStock,
  });
}
