import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/app_state_providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../core/repository/customers_repository.dart';
import '../../../widgets/glass_morphism.dart';
import '../models/revenue_models.dart';
import '../services/revenue_service.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ReceiptEntryScreen extends ConsumerStatefulWidget {
  final String? preselectedCustomerId;
  final String? preselectedBillId;

  const ReceiptEntryScreen({
    super.key,
    this.preselectedCustomerId,
    this.preselectedBillId,
  });

  @override
  ConsumerState<ReceiptEntryScreen> createState() => _ReceiptEntryScreenState();
}

class _ReceiptEntryScreenState extends ConsumerState<ReceiptEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _revenueService = RevenueService();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _chequeController = TextEditingController();
  final _upiController = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedBillId;
  String? _selectedBillNumber;
  double? _selectedBillAmount;
  double? _selectedBillRemaining;

  String _paymentMode = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _isAdvancePayment = false;
  bool _isSaving = false;

  final List<String> _paymentModes = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Card',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCustomerId != null) {
      _selectedCustomerId = widget.preselectedCustomerId;
      _loadCustomerDetails();
    }
    if (widget.preselectedBillId != null) {
      _selectedBillId = widget.preselectedBillId;
      _loadBillDetails();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _chequeController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerDetails() async {
    if (_selectedCustomerId == null) return;

    final result = await sl<CustomersRepository>().getById(
      _selectedCustomerId!,
    );
    final customer = result.data;

    if (customer != null && mounted) {
      setState(() {
        _selectedCustomerName = customer.name;
      });
    }
  }

  Future<void> _loadBillDetails() async {
    if (_selectedBillId == null) return;

    final result = await sl<BillsRepository>().getById(_selectedBillId!);
    final bill = result.data;

    if (bill != null && mounted) {
      setState(() {
        _selectedBillNumber = bill.invoiceNumber;
        _selectedBillAmount = bill.grandTotal;
        _selectedBillRemaining = bill.grandTotal - bill.paidAmount;
        _selectedCustomerId = bill.customerId;
        _selectedCustomerName = bill.customerName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final ownerId = sl<SessionManager>().ownerId ?? '';

    return DesktopContentContainer(
      title: 'Receipt Entry',
      actions: [
        if (_selectedCustomerId != null)
          DesktopIconButton(
            icon: Icons.history,
            tooltip: 'History',
            onPressed: _viewHistory,
          ),
      ],
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            if (isDesktop) {
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT COLUMN
                        Expanded(
                          child: Column(
                            children: [
                              _buildCustomerCard(ownerId, isDark),
                              const SizedBox(height: 16),
                              if (_selectedCustomerId != null &&
                                  !_isAdvancePayment)
                                _buildBillCard(ownerId, isDark),
                              if (_selectedCustomerId != null &&
                                  !_isAdvancePayment)
                                const SizedBox(height: 16),
                              if (_selectedCustomerId != null)
                                _buildAdvanceSwitch(isDark),
                              if (_selectedCustomerId != null)
                                const SizedBox(height: 16),
                              _buildAmountCard(isDark),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // RIGHT COLUMN
                        Expanded(
                          child: Column(
                            children: [
                              _buildPaymentModeCard(isDark),
                              const SizedBox(height: 16),
                              _buildDateNotesCard(isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 16),
                ],
              );
            }

            // Mobile Layout
            return Column(
              children: [
                _buildCustomerCard(ownerId, isDark),
                const SizedBox(height: 16),
                if (_selectedCustomerId != null && !_isAdvancePayment)
                  _buildBillCard(ownerId, isDark),
                if (_selectedCustomerId != null && !_isAdvancePayment)
                  const SizedBox(height: 16),
                if (_selectedCustomerId != null) _buildAdvanceSwitch(isDark),
                if (_selectedCustomerId != null) const SizedBox(height: 16),
                _buildAmountCard(isDark),
                const SizedBox(height: 16),
                _buildPaymentModeCard(isDark),
                const SizedBox(height: 16),
                _buildDateNotesCard(isDark),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerCard(String ownerId, bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Customer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _selectCustomer(ownerId, isDark),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedCustomerId != null
                      ? Colors.green
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCustomerName ?? 'Tap to select customer',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedCustomerName != null
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(String ownerId, bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Link to Bill (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_selectedBillId != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.red),
                  onPressed: () => setState(() {
                    _selectedBillId = null;
                    _selectedBillNumber = null;
                    _selectedBillAmount = null;
                    _selectedBillRemaining = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _selectBill(ownerId, isDark),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _selectedBillNumber != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bill $_selectedBillNumber',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹${_selectedBillRemaining?.toStringAsFixed(0)} due',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: ₹${_selectedBillAmount?.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.add_circle_outline,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Select a pending bill to link',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceSwitch(bool isDark) {
    return GlassCard(
      child: SwitchListTile(
        title: Text(
          'Advance Payment',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          'Record payment without linking to a bill',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
        ),
        value: _isAdvancePayment,
        onChanged: (val) => setState(() {
          _isAdvancePayment = val;
          if (val) {
            _selectedBillId = null;
            _selectedBillNumber = null;
          }
        }),
        activeColor: Colors.green,
      ),
    );
  }

  Widget _buildAmountCard(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_rupee, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 24,
              ),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 24,
                ),
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              hintText: '0.00',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Enter amount';
              final amount = double.tryParse(val);
              if (amount == null || amount <= 0) {
                return 'Enter valid amount';
              }
              return null;
            },
          ),
          if (_selectedBillRemaining != null && _selectedBillRemaining! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  _buildQuickAmountChip(
                    'Full',
                    _selectedBillRemaining!,
                    isDark,
                  ),
                  if (_selectedBillRemaining! > 100)
                    _buildQuickAmountChip('₹100', 100, isDark),
                  if (_selectedBillRemaining! > 500)
                    _buildQuickAmountChip('₹500', 500, isDark),
                  if (_selectedBillRemaining! > 1000)
                    _buildQuickAmountChip('₹1000', 1000, isDark),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeCard(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Mode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentModes.map((mode) {
              final isSelected = _paymentMode == mode;
              return ChoiceChip(
                label: Text(mode),
                selected: isSelected,
                onSelected: (_) => setState(() => _paymentMode = mode),
                selectedColor: Colors.blue,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              );
            }).toList(),
          ),
          if (_paymentMode == 'Cheque')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextFormField(
                controller: _chequeController,
                decoration: InputDecoration(
                  labelText: 'Cheque Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_paymentMode == 'UPI')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextFormField(
                controller: _upiController,
                decoration: InputDecoration(
                  labelText: 'UPI Transaction ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateNotesCard(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                const Text('Change', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          const Divider(height: 24),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any reference or notes',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _selectedCustomerId != null && !_isSaving
            ? _saveReceipt
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  Text(
                    'Record Receipt',
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
                ],
              ),
      ),
    );
  }

  Widget _buildQuickAmountChip(String label, double amount, bool isDark) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _amountController.text = amount.toStringAsFixed(0);
      },
      backgroundColor: isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.grey.withOpacity(0.2),
    );
  }

  Future<void> _selectCustomer(String ownerId, bool isDark) async {
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _CustomerSelectionSheet(ownerId: ownerId, isDark: isDark),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCustomerId = selected.id;
        _selectedCustomerName = selected.name;
        _selectedBillId = null;
        _selectedBillNumber = null;
        _selectedBillAmount = null;
        _selectedBillRemaining = null;
      });
    }
  }

  Future<void> _selectBill(String ownerId, bool isDark) async {
    if (_selectedCustomerId == null) return;

    final selected = await showModalBottomSheet<Bill>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BillSelectionSheet(
        ownerId: ownerId,
        customerId: _selectedCustomerId!,
        isDark: isDark,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedBillId = selected.id;
        _selectedBillNumber = selected.invoiceNumber;
        _selectedBillAmount = selected.grandTotal;
        _selectedBillRemaining = selected.grandTotal - selected.paidAmount;
      });
    }
  }

  void _viewHistory() {
    // Navigate to receipt history for this customer
    context.push('/payment-history');
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ownerId = sl<SessionManager>().ownerId!;
      final amount = double.parse(_amountController.text);

      final receipt = Receipt(
        id: '',
        ownerId: ownerId,
        customerId: _selectedCustomerId!,
        customerName: _selectedCustomerName ?? '',
        billId: _selectedBillId,
        billNumber: _selectedBillNumber,
        amount: amount,
        billAmount: _selectedBillAmount,
        paymentMode: _paymentMode,
        chequeNumber: _paymentMode == 'Cheque' ? _chequeController.text : null,
        upiTransactionId: _paymentMode == 'UPI' ? _upiController.text : null,
        notes: _notesController.text,
        date: _selectedDate,
        createdAt: DateTime.now(),
        isAdvancePayment: _isAdvancePayment,
      );

      await _revenueService.addReceipt(ownerId, receipt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt of ₹${amount.toStringAsFixed(0)} recorded!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// Customer Selection Sheet
class _CustomerSelectionSheet extends StatelessWidget {
  final String ownerId;
  final bool isDark;

  const _CustomerSelectionSheet({required this.ownerId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Customer',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: sl<CustomersRepository>().watchAll(userId: ownerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customers = snapshot.data ?? [];
                if (customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No customers yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final totalDue = customer.totalDues;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        child: Text(
                          (customer.name)[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        customer.phone ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      trailing: totalDue > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹${totalDue.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context, customer);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Bill Selection Sheet
class _BillSelectionSheet extends StatelessWidget {
  final String ownerId;
  final String customerId;
  final bool isDark;

  const _BillSelectionSheet({
    required this.ownerId,
    required this.customerId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Pending Bill',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Bill>>(
              stream: sl<BillsRepository>().watchAll(
                userId: ownerId,
                customerId: customerId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var bills = snapshot.data ?? [];
                // Filter for pending bills
                bills = bills
                    .where((b) => b.status.toLowerCase() != 'paid')
                    .toList();

                if (bills.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No pending bills!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: bills.length,
                  itemBuilder: (context, index) {
                    final bill = bills[index];
                    final totalAmount = bill.grandTotal;
                    final remaining = totalAmount - bill.paidAmount;

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt, color: Colors.orange),
                      ),
                      title: Text(
                        bill.invoiceNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('dd MMM yyyy').format(bill.date),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${remaining.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'of ₹${totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context, bill);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
