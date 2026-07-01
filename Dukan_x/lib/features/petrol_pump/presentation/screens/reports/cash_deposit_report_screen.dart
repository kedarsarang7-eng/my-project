import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/session/session_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Cash Deposit Report Screen for Petrol Pump
/// Tracks cash deposits to bank from daily collections
class CashDepositReportScreen extends StatefulWidget {
  const CashDepositReportScreen({super.key});

  @override
  State<CashDepositReportScreen> createState() =>
      _CashDepositReportScreenState();
}

class _CashDepositReportScreenState extends State<CashDepositReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;
  List<CashDepositEntity> _deposits = [];
  double _totalDeposited = 0;
  double _pendingDeposit = 0;

  @override
  void initState() {
    super.initState();
    _loadDeposits();
  }

  Future<void> _loadDeposits() async {
    setState(() => _isLoading = true);
    try {
      final db = sl<AppDatabase>();

      // Query deposits for date range
      final deposits =
          await (db.select(db.cashDeposits)
                ..where((d) => d.depositDate.isBiggerOrEqualValue(_startDate))
                ..where((d) => d.depositDate.isSmallerOrEqualValue(_endDate))
                ..orderBy([(d) => OrderingTerm.desc(d.depositDate)]))
              .get();

      double total = 0;
      double pending = 0;
      for (final d in deposits) {
        total += d.amount;
        if (d.status == 'PENDING') {
          pending += d.amount;
        }
      }

      setState(() {
        _deposits = deposits;
        _totalDeposited = total;
        _pendingDeposit = pending;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading deposits: $e')));
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadDeposits();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Deposit Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDeposits),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDepositDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Deposit'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Card(
                  margin: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Divider(),
                        context.isMobile
                            ? Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: _buildSummaryItem(
                                          'Total Deposited',
                                          '₹${_totalDeposited.toStringAsFixed(0)}',
                                          Colors.green,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildSummaryItem(
                                          'Pending',
                                          '₹${_pendingDeposit.toStringAsFixed(0)}',
                                          Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSummaryItem(
                                    'Deposits',
                                    '${_deposits.length}',
                                    Colors.blue,
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryItem(
                                    'Total Deposited',
                                    '₹${_totalDeposited.toStringAsFixed(0)}',
                                    Colors.green,
                                  ),
                                  _buildSummaryItem(
                                    'Pending',
                                    '₹${_pendingDeposit.toStringAsFixed(0)}',
                                    Colors.orange,
                                  ),
                                  _buildSummaryItem(
                                    'Deposits',
                                    '${_deposits.length}',
                                    Colors.blue,
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),

                // Deposits List
                Expanded(
                  child: _deposits.isEmpty
                      ? const Center(
                          child: Text('No deposits found for this period'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _deposits.length,
                          itemBuilder: (context, index) {
                            final deposit = _deposits[index];
                            return _buildDepositCard(deposit);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDepositCard(CashDepositEntity deposit) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final statusColor = _getStatusColor(deposit.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.account_balance, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${deposit.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Deposited: ${dateFormat.format(deposit.depositDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (deposit.bankName != null)
                    Text(
                      'Bank: ${deposit.bankName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                deposit.status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DEPOSITED':
        return Colors.green;
      case 'VERIFIED':
        return Colors.blue;
      case 'PENDING':
      default:
        return Colors.orange;
    }
  }

  void _showAddDepositDialog() {
    final amountController = TextEditingController();
    final bankController = TextEditingController();
    final slipController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Cash Deposit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankController,
                decoration: const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: slipController,
                decoration: const InputDecoration(
                  labelText: 'Deposit Slip Number',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                await _addDeposit(
                  amount: amount,
                  bankName: bankController.text,
                  slipNumber: slipController.text,
                  depositDate: selectedDate,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDeposit({
    required double amount,
    required String bankName,
    required String slipNumber,
    required DateTime depositDate,
  }) async {
    try {
      final db = sl<AppDatabase>();
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      await db
          .into(db.cashDeposits)
          .insert(
            CashDepositsCompanion.insert(
              id: id,
              ownerId: sl<SessionManager>().ownerId ?? 'unknown',
              depositDate: depositDate,
              amount: amount,
              collectionDate: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      _loadDeposits();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deposit added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding deposit: $e')));
      }
    }
  }
}
