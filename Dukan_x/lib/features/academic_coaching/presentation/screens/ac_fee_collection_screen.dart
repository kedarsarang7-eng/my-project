// ============================================================================
// ACADEMIC COACHING — FEE COLLECTION SCREEN
// ============================================================================
// Invoice generation and payment recording with professional UI

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../utils/ac_validators.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AcFeeCollectionScreen extends StatefulWidget {
  final AcStudent? student;

  const AcFeeCollectionScreen({super.key, this.student});

  @override
  State<AcFeeCollectionScreen> createState() => _AcFeeCollectionScreenState();
}

class _AcFeeCollectionScreenState extends State<AcFeeCollectionScreen> {
  late AcRepository _repository;

  // State
  List<AcStudent> _students = [];
  List<AcInvoice> _invoices = [];
  bool _isLoading = false;
  String? _error;

  // Selection
  AcStudent? _selectedStudent;
  AcInvoice? _selectedInvoice;

  // Search
  final _searchCtrl = TextEditingController();

  // Payment form
  final _amountCtrl = TextEditingController();
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _transactionRefCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _paymentDate = DateTime.now();

  // Validation error state (retained on rejection per Req 10.6)
  String? _amountError;
  String? _linkageError;

  @override
  void initState() {
    super.initState();
    _repository = sl<AcRepository>();
    _selectedStudent = widget.student;
    if (_selectedStudent != null) {
      _loadStudentFees(_selectedStudent!.id);
    } else {
      _loadStudents();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _transactionRefCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await _repository.listStudents();
      setState(() {
        _students = students.items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentFees(String studentId) async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _repository.getStudentFees(studentId);
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _recordPayment() async {
    // ── Validation gate (Req 10.3, 10.4, 10.5, 10.6) ──
    // Route through AcValidators before any persistence. On failure: persist
    // nothing, retain entered values, show error on the invalid field.

    // 1. Fee-linkage validation: student AND class must be linked.
    final linkageError = AcValidators.validateFeeLinkage(
      studentId: _selectedStudent?.id,
      classId: _selectedStudent?.currentClass,
    );
    if (linkageError != null) {
      setState(() {
        _linkageError = linkageError;
        _amountError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(linkageError), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Strict integer-Paise fee amount validation (> 0 required).
    final amountError = AcValidators.validateFeeAmountPaiseFromText(
      _amountCtrl.text,
    );
    if (amountError != null) {
      setState(() {
        _amountError = amountError;
        _linkageError = null;
      });
      return;
    }

    // 3. Invoice selection check.
    if (_selectedInvoice == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an invoice')));
      return;
    }

    // Clear validation errors on successful validation.
    setState(() {
      _amountError = null;
      _linkageError = null;
      _isLoading = true;
    });

    final amountPaise = int.parse(_amountCtrl.text.replaceAll(',', '').trim());

    try {
      await _repository.recordPayment({
        'invoiceId': _selectedInvoice!.id,
        'studentId': _selectedStudent!.id,
        'amountPaise': amountPaise,
        'paymentMethod': _paymentMethod.name,
        'transactionRef': _transactionRefCtrl.text.isEmpty
            ? null
            : _transactionRefCtrl.text,
        'paymentDate': _paymentDate.toIso8601String(),
        'remarks': _remarksCtrl.text.isEmpty ? null : _remarksCtrl.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        _loadStudentFees(_selectedStudent!.id);
        _clearPaymentForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearPaymentForm() {
    _amountCtrl.clear();
    _transactionRefCtrl.clear();
    _remarksCtrl.clear();
    _paymentMethod = PaymentMethod.cash;
    _paymentDate = DateTime.now();
    _selectedInvoice = null;
    _amountError = null;
    _linkageError = null;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 12,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: isMobile
              ? (_selectedStudent == null
                    ? _buildStudentSelectionPanel()
                    : _buildMobileFeeAndPaymentPanel())
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Panel - Student Selection
                    Expanded(flex: 2, child: _buildStudentSelectionPanel()),
                    const SizedBox(width: 20),
                    // Right Panel - Fee Details & Payment
                    Expanded(
                      flex: 3,
                      child: _selectedStudent == null
                          ? _buildEmptySelectionPanel()
                          : _buildFeeAndPaymentPanel(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMobileFeeAndPaymentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() {
            _selectedStudent = null;
            _selectedInvoice = null;
          }),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Student List'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildFeeAndPaymentPanel()),
      ],
    );
  }

  Widget _buildStudentSelectionPanel() {
    final filteredStudents = _students.where((s) {
      if (_searchCtrl.text.isEmpty) return true;
      final query = _searchCtrl.text.toLowerCase();
      return s.fullName.toLowerCase().contains(query) ||
          s.phone.contains(query) ||
          s.studentId.toLowerCase().contains(query);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Student',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF64748B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading && _students.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                ? const Center(
                    child: Text(
                      'No students found',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredStudents.length,
                    itemBuilder: (ctx, i) {
                      final student = filteredStudents[i];
                      final isSelected = _selectedStudent?.id == student.id;

                      return InkWell(
                        onTap: () {
                          setState(() => _selectedStudent = student);
                          _loadStudentFees(student.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFEEF2FF)
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFFE2E8F0),
                                child: Text(
                                  student.firstName[0],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.fullName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF4F46E5)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${student.studentId} • ${student.phone}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    if (student.balance != null &&
                                        student.balance! > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'Due: ₹${student.balance!.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF4F46E5),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySelectionPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a student to view fee details',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentHeaderCard(
    bool isMobile,
    NumberFormat fmt,
    double totalDue,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        _selectedStudent!.firstName[0],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedStudent!.fullName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${_selectedStudent!.studentId} • ${_selectedStudent!.phone}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Due:',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      fmt.format(totalDue),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    _selectedStudent!.firstName[0],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedStudent!.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedStudent!.studentId} • ${_selectedStudent!.phone}',
                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Due',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      fmt.format(totalDue),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFeeAndPaymentPanel() {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
    );

    final pendingInvoices = _invoices.where((i) => i.balance > 0).toList();
    final totalDue = pendingInvoices.fold(0.0, (sum, i) => sum + i.balance);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Student Header Card
          _buildStudentHeaderCard(context.isMobile, fmt, totalDue),
          const SizedBox(height: 20),
          // Pending Invoices
          if (pendingInvoices.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pending Invoices',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showCreateInvoiceDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Invoice'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...pendingInvoices.map(
                    (invoice) => _buildInvoiceCard(invoice, fmt),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // Payment Form
          Container(
            padding: EdgeInsets.all(
              responsiveValue<double>(
                context,
                mobile: 16,
                tablet: 20,
                desktop: 24,
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record Payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                // Select Invoice
                if (pendingInvoices.isNotEmpty)
                  DropdownButtonFormField<AcInvoice?>(
                    value: _selectedInvoice,
                    decoration: InputDecoration(
                      labelText: 'Select Invoice',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Select an invoice'),
                      ),
                      ...pendingInvoices.map(
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i.invoiceNumber} - Due: ₹${i.balance.toStringAsFixed(0)}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedInvoice = v;
                        if (v != null) {
                          _amountCtrl.text = v.balance.toStringAsFixed(0);
                        }
                      });
                    },
                  ),
                if (pendingInvoices.isNotEmpty) const SizedBox(height: 16),
                // Amount
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Amount (Paise) *',
                    prefixText: '₹ ',
                    errorText: _amountError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (_) {
                    // Clear error on user input to allow re-submission
                    if (_amountError != null) {
                      setState(() => _amountError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Payment Method
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Payment Method:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    ...PaymentMethod.values.map(
                      (m) => ChoiceChip(
                        label: Text(_getPaymentMethodLabel(m)),
                        selected: _paymentMethod == m,
                        onSelected: (s) {
                          if (s) setState(() => _paymentMethod = m);
                        },
                        selectedColor: const Color(0xFFEEF2FF),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: _paymentMethod == m
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF64748B),
                          fontWeight: _paymentMethod == m
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Transaction Ref (for non-cash)
                if (_paymentMethod != PaymentMethod.cash)
                  TextField(
                    controller: _transactionRefCtrl,
                    decoration: InputDecoration(
                      labelText: 'Transaction Reference',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                if (_paymentMethod != PaymentMethod.cash)
                  const SizedBox(height: 16),
                // Date
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _paymentDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Payment Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(_paymentDate)),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Remarks
                TextField(
                  controller: _remarksCtrl,
                  decoration: InputDecoration(
                    labelText: 'Remarks (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _recordPayment,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(
                      _isLoading ? 'Processing...' : 'Record Payment',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildInvoiceCard(AcInvoice invoice, NumberFormat fmt) {
    final isSelected = _selectedInvoice?.id == invoice.id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedInvoice = invoice;
          _amountCtrl.text = invoice.balance.toStringAsFixed(0);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: invoice.isOverdue
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                invoice.isOverdue ? Icons.warning : Icons.receipt,
                color: invoice.isOverdue
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due: ${DateFormat('dd MMM yyyy').format(DateTime.parse(invoice.dueDate!))}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${invoice.balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: invoice.isOverdue
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: invoice.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    invoice.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: invoice.statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.bankTransfer:
        return 'Bank';
      case PaymentMethod.online:
        return 'Online';
    }
  }

  void _showCreateInvoiceDialog() {
    // ── Validation gate for invoice creation (Req 10.3, 10.4, 10.5, 10.6) ──
    // Validate fee-linkage (student + class) before allowing invoice creation.
    final linkageError = AcValidators.validateFeeLinkage(
      studentId: _selectedStudent?.id,
      classId: _selectedStudent?.currentClass,
    );
    if (linkageError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(linkageError), backgroundColor: Colors.red),
      );
      return;
    }
    // Pending: Implement invoice creation dialog (behind fee-linkage + amount validation gates)
  }
}
