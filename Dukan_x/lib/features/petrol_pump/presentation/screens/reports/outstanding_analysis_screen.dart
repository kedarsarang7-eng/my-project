import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../../core/di/service_locator.dart';
import '../../../../../core/database/app_database.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Outstanding Analysis Screen for Petrol Pump
/// Shows credit customers with outstanding dues and ageing analysis
class OutstandingAnalysisScreen extends StatefulWidget {
  const OutstandingAnalysisScreen({super.key});

  @override
  State<OutstandingAnalysisScreen> createState() =>
      _OutstandingAnalysisScreenState();
}

class _OutstandingAnalysisScreenState extends State<OutstandingAnalysisScreen> {
  bool _isLoading = true;
  List<CustomerOutstanding> _customers = [];
  double _totalOutstanding = 0;
  String _sortBy = 'amount'; // 'amount', 'name', 'days'

  @override
  void initState() {
    super.initState();
    _loadOutstanding();
  }

  Future<void> _loadOutstanding() async {
    setState(() => _isLoading = true);
    try {
      final db = sl<AppDatabase>();

      // Get all customers with outstanding dues
      final customers =
          await (db.select(db.customers)
                ..where((c) => c.totalDues.isBiggerThanValue(0))
                ..where((c) => c.isActive.equals(true))
                ..orderBy([(c) => OrderingTerm.desc(c.totalDues)]))
              .get();

      final outstandingList = <CustomerOutstanding>[];
      double total = 0;

      for (final customer in customers) {
        final outstanding = CustomerOutstanding(
          customerId: customer.id,
          customerName: customer.name,
          phone: customer.phone,
          totalDues: customer.totalDues,
          lastTransactionDate: customer.lastTransactionDate,
          overdueDays: customer.lastTransactionDate != null
              ? DateTime.now().difference(customer.lastTransactionDate!).inDays
              : 0,
        );
        outstandingList.add(outstanding);
        total += customer.totalDues;
      }

      setState(() {
        _customers = outstandingList;
        _totalOutstanding = total;
        _isLoading = false;
      });

      _sortCustomers();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading outstanding: $e')),
        );
      }
    }
  }

  void _sortCustomers() {
    setState(() {
      switch (_sortBy) {
        case 'name':
          _customers.sort((a, b) => a.customerName.compareTo(b.customerName));
          break;
        case 'days':
          _customers.sort((a, b) => b.overdueDays.compareTo(a.overdueDays));
          break;
        case 'amount':
        default:
          _customers.sort((a, b) => b.totalDues.compareTo(a.totalDues));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outstanding Analysis'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _sortCustomers();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'amount',
                child: Text('Sort by Amount'),
              ),
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(
                value: 'days',
                child: Text('Sort by Overdue Days'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOutstanding,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                _buildSummaryCard(),

                // Ageing Summary
                _buildAgeingSummary(),

                // Customer List
                Expanded(
                  child: _customers.isEmpty
                      ? const Center(child: Text('No outstanding dues found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            return _buildCustomerCard(_customers[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('Total Outstanding', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '₹${_totalOutstanding.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const Text('Credit Customers', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '${_customers.length}',
                  style: const TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeingSummary() {
    // Calculate ageing buckets
    double current = 0, days30 = 0, days60 = 0, days90Plus = 0;

    for (final c in _customers) {
      final days = c.overdueDays;
      if (days <= 30) {
        current += c.totalDues;
      } else if (days <= 60) {
        days30 += c.totalDues;
      } else if (days <= 90) {
        days60 += c.totalDues;
      } else {
        days90Plus += c.totalDues;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildAgeingBox('0-30 Days', current, Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: _buildAgeingBox('31-60 Days', days30, Colors.orange)),
          const SizedBox(width: 8),
          Expanded(
            child: _buildAgeingBox('61-90 Days', days60, Colors.deepOrange),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildAgeingBox('90+ Days', days90Plus, Colors.red)),
        ],
      ),
    );
  }

  Widget _buildAgeingBox(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(CustomerOutstanding customer) {
    final dateFormat = DateFormat('dd MMM');
    final color = _getOverdueColor(customer.overdueDays);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Text(
            customer.customerName.isNotEmpty
                ? customer.customerName[0].toUpperCase()
                : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          customer.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone != null)
              Text(customer.phone!, style: const TextStyle(fontSize: 12)),
            if (customer.lastTransactionDate != null)
              Text(
                'Last: ${dateFormat.format(customer.lastTransactionDate!)} (${customer.overdueDays} days ago)',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${customer.totalDues.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (customer.overdueDays > 30)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Overdue',
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ),
          ],
        ),
        onTap: () => _showCustomerActions(customer),
      ),
    );
  }

  Color _getOverdueColor(int days) {
    if (days <= 30) return Colors.green;
    if (days <= 60) return Colors.orange;
    if (days <= 90) return Colors.deepOrange;
    return Colors.red;
  }

  void _showCustomerActions(CustomerOutstanding customer) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call Customer'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening phone dialer...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Send Payment Reminder'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sending payment reminder...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Record Payment'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment recording feature coming soon'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View Transaction History'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ledger view feature coming soon'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Customer outstanding data model
class CustomerOutstanding {
  final String customerId;
  final String customerName;
  final String? phone;
  final double totalDues;
  final DateTime? lastTransactionDate;
  final int overdueDays;

  CustomerOutstanding({
    required this.customerId,
    required this.customerName,
    this.phone,
    required this.totalDues,
    this.lastTransactionDate,
    required this.overdueDays,
  });
}
