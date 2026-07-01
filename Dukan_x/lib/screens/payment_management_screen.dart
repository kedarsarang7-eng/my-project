import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/theme/futuristic_colors.dart';
import '../models/payment_history.dart';
import '../core/di/service_locator.dart';
import '../core/session/session_manager.dart';
import '../core/repository/bills_repository.dart';
import '../core/repository/customers_repository.dart';

class PaymentManagementScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final double currentDues;

  const PaymentManagementScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentDues,
  });

  @override
  State<PaymentManagementScreen> createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPaymentType = 'Cash';
  String _selectedFilter = 'All';
  List<PaymentHistory> _paymentHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoading = true);
    try {
      // Load from repository - uses bill payment records
      final ownerId = sl<SessionManager>().ownerId ?? '';
      if (ownerId.isEmpty) return;

      final billsResult = await sl<BillsRepository>().getAll(
        userId: ownerId,
        customerId: widget.customerId,
      );

      if (!billsResult.isSuccess || !mounted) return;

      // Extract payment history from bills
      final history = <PaymentHistory>[];
      for (var bill in billsResult.data!) {
        if (bill.paidAmount > 0) {
          history.add(
            PaymentHistory(
              id: bill.id,
              customerId: widget.customerId,
              paymentDate: bill.date,
              amount: bill.paidAmount,
              paymentType: bill.paymentType,
              status: 'Completed',
              description: 'Bill #${bill.id.substring(0, 8)}',
            ),
          );
        }
      }

      setState(() => _paymentHistory = history);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recordPayment() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter amount')));
      return;
    }

    try {
      final ownerId = sl<SessionManager>().ownerId ?? '';
      if (ownerId.isEmpty) return;

      // Use CustomersRepository to record payment against customer balance
      await sl<CustomersRepository>().recordPayment(
        customerId: widget.customerId,
        amount: double.parse(_amountController.text),
        userId: ownerId,
      );

      _amountController.clear();
      _descriptionController.clear();
      await _loadPaymentHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<PaymentHistory> _getFilteredHistory() {
    if (_selectedFilter == 'All') return _paymentHistory;
    return _paymentHistory
        .where((p) => p.paymentType == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final filteredHistory = _getFilteredHistory();
    double totalCashPaid = _paymentHistory
        .where((p) => p.paymentType == 'Cash')
        .fold(0.0, (sum, p) => sum + p.amount);
    double totalOnlinePaid = _paymentHistory
        .where((p) => p.paymentType == 'Online')
        .fold(0.0, (sum, p) => sum + p.amount);

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Info Card
        Card(
          elevation: 2,
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Dues',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '₹${widget.currentDues.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FuturisticColors.error,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💵 Cash Paid',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '₹${totalCashPaid.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: FuturisticColors.success,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💳 Online Paid',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '₹${totalOnlinePaid.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Record Payment Section
        const Text(
          'Record Payment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Amount Input
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Type Selection
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('💵 Cash'),
                          value: 'Cash',
                          groupValue: _selectedPaymentType,
                          onChanged: (value) {
                            setState(
                              () => _selectedPaymentType = value!,
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('💳 Online'),
                          value: 'Online',
                          groupValue: _selectedPaymentType,
                          onChanged: (value) {
                            setState(
                              () => _selectedPaymentType = value!,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Record Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _recordPayment,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Record Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FuturisticColors.success,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Section
        const Text(
          'Payment History',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Cash', 'Online']
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _selectedFilter == filter,
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Payment History List
        filteredHistory.isEmpty
            ? Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Text(
                  'No payment history',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredHistory.length,
                itemBuilder: (context, index) {
                  final payment = filteredHistory[index];
                  final icon = payment.paymentType == 'Cash'
                      ? '💵'
                      : '💳';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Text(
                        icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(payment.description),
                      subtitle: Text(
                        '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            payment.paymentType,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('💳 Payment Management'),
        backgroundColor: FuturisticColors.success,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leftColumn,
                          const SizedBox(height: 24),
                          rightColumn,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: leftColumn,
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 6,
                            child: rightColumn,
                          ),
                        ],
                      ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
