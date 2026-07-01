import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/database/app_database.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:dukanx/core/responsive/responsive.dart';

/// CA (Credit Accounts) Report Screen for Petrol Pump
/// Shows credit sales history, customer ledger, and payment tracking
class CaReportScreen extends StatefulWidget {
  const CaReportScreen({super.key});

  @override
  State<CaReportScreen> createState() => _CaReportScreenState();
}

class _CaReportScreenState extends State<CaReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;

  // Summary data
  double _totalCreditSales = 0;
  double _totalCollections = 0;
  double _currentOutstanding = 0;
  int _activeAccounts = 0;

  // Transactions
  List<CreditTransaction> _transactions = [];
  List<CustomerAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = sl<AppDatabase>();

      // Get credit bills for date range
      final bills =
          await (db.select(db.bills)
                ..where((b) => b.paymentMode.equals('CREDIT'))
                ..where((b) => b.billDate.isBiggerOrEqualValue(_startDate))
                ..where((b) => b.billDate.isSmallerOrEqualValue(_endDate))
                ..orderBy([(b) => OrderingTerm.desc(b.billDate)]))
              .get();

      // Calculate totals
      double creditSales = 0;
      for (final bill in bills) {
        creditSales += bill.grandTotal;
      }

      // Get customers with credit balance
      final customers =
          await (db.select(db.customers)
                ..where((c) => c.totalDues.isBiggerThanValue(0))
                ..orderBy([(c) => OrderingTerm.desc(c.totalDues)]))
              .get();

      double outstanding = 0;
      final accounts = <CustomerAccount>[];
      for (final customer in customers) {
        outstanding += customer.totalDues;
        accounts.add(
          CustomerAccount(
            customerId: customer.id,
            customerName: customer.name,
            phone: customer.phone,
            creditLimit: customer.creditLimit,
            currentBalance: customer.totalDues,
            lastTransactionDate: customer.lastTransactionDate,
          ),
        );
      }

      // Get payment collections for date range
      final payments =
          await (db.select(db.payments)
                ..where((p) => p.paymentDate.isBiggerOrEqualValue(_startDate))
                ..where((p) => p.paymentDate.isSmallerOrEqualValue(_endDate))
                ..orderBy([(p) => OrderingTerm.desc(p.paymentDate)]))
              .get();

      double collections = 0;
      for (final payment in payments) {
        collections += payment.amount;
      }

      // Build transaction list
      final txns = <CreditTransaction>[];
      for (final bill in bills) {
        txns.add(
          CreditTransaction(
            date: bill.billDate,
            type: 'CREDIT_SALE',
            description: 'Bill #${bill.id}',
            amount: bill.grandTotal,
            customerId: bill.customerId,
            customerName: bill.customerName,
          ),
        );
      }
      for (final payment in payments) {
        txns.add(
          CreditTransaction(
            date: payment.paymentDate,
            type: 'COLLECTION',
            description: payment.paymentMode,
            amount: -payment.amount,
            customerId: payment.customerId,
            customerName: null,
          ),
        );
      }
      txns.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _totalCreditSales = creditSales;
        _totalCollections = collections;
        _currentOutstanding = outstanding;
        _activeAccounts = accounts.length;
        _transactions = txns;
        _accounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading CA report: $e')));
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
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Accounts (CA) Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Transactions'),
            Tab(text: 'Accounts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date Range Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(),
                      _buildTransactionsTab(),
                      _buildAccountsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Key Metrics Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
            childAspectRatio: 1.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildMetricCard(
                'Credit Sales',
                '₹${_totalCreditSales.toStringAsFixed(0)}',
                Icons.shopping_cart,
                Colors.blue,
              ),
              _buildMetricCard(
                'Collections',
                '₹${_totalCollections.toStringAsFixed(0)}',
                Icons.payments,
                Colors.green,
              ),
              _buildMetricCard(
                'Outstanding',
                '₹${_currentOutstanding.toStringAsFixed(0)}',
                Icons.pending,
                Colors.red,
              ),
              _buildMetricCard(
                'Active Accounts',
                '$_activeAccounts',
                Icons.people,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Summary Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Period Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildSummaryRow('Opening Outstanding', '₹--', Colors.grey),
                  _buildSummaryRow(
                    'Credit Sales',
                    '+₹${_totalCreditSales.toStringAsFixed(0)}',
                    Colors.blue,
                  ),
                  _buildSummaryRow(
                    'Collections',
                    '-₹${_totalCollections.toStringAsFixed(0)}',
                    Colors.green,
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Closing Outstanding',
                    '₹${_currentOutstanding.toStringAsFixed(0)}',
                    Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('No transactions found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final txn = _transactions[index];
        final dateFormat = DateFormat('dd MMM, hh:mm a');
        final isCredit = txn.type == 'CREDIT_SALE';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (isCredit ? Colors.red : Colors.green)
                  .withOpacity(0.1),
              child: Icon(
                isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                color: isCredit ? Colors.red : Colors.green,
              ),
            ),
            title: Text(txn.description),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (txn.customerName != null)
                  Text(
                    txn.customerName!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                Text(
                  dateFormat.format(txn.date),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            trailing: Text(
              '${isCredit ? '+' : ''}₹${txn.amount.abs().toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.red : Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountsTab() {
    if (_accounts.isEmpty) {
      return const Center(child: Text('No credit accounts found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _accounts.length,
      itemBuilder: (context, index) {
        final account = _accounts[index];
        final utilizationPercent = account.creditLimit > 0
            ? (account.currentBalance / account.creditLimit * 100).clamp(0, 100)
            : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (account.phone != null)
                            Text(
                              account.phone!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${account.currentBalance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        if (account.creditLimit > 0)
                          Text(
                            'Limit: ₹${account.creditLimit.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (account.creditLimit > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: utilizationPercent / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(
                      utilizationPercent > 80
                          ? Colors.red
                          : utilizationPercent > 50
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${utilizationPercent.toStringAsFixed(0)}% utilized',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Credit transaction data model
class CreditTransaction {
  final DateTime date;
  final String type;
  final String description;
  final double amount;
  final String? customerId;
  final String? customerName;

  CreditTransaction({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    this.customerId,
    this.customerName,
  });
}

/// Customer account data model
class CustomerAccount {
  final String customerId;
  final String customerName;
  final String? phone;
  final double creditLimit;
  final double currentBalance;
  final DateTime? lastTransactionDate;

  CustomerAccount({
    required this.customerId,
    required this.customerName,
    this.phone,
    required this.creditLimit,
    required this.currentBalance,
    this.lastTransactionDate,
  });
}
