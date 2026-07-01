// ============================================================================
// Scan Bill Supplier Screen
// ============================================================================
// Fourth screen in the scan bill flow:
// - Supplier selection (search existing or enter new)
// - Bill number input
// - Bill date picker
// - Payment status selection
// - Business-specific fields (pharmacy prescription, wholesale credit terms)
// - Final confirmation and submission
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
import '../../models/scan_bill_models.dart';
import '../../services/purchase_receipt_pdf.dart';
import '../../providers/scan_bill_session_provider.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ScanBillSupplierScreen extends ConsumerStatefulWidget {
  final String verticalType;

  const ScanBillSupplierScreen({
    super.key,
    required this.verticalType,
  });

  @override
  ConsumerState<ScanBillSupplierScreen> createState() => 
      _ScanBillSupplierScreenState();
}

class _ScanBillSupplierScreenState extends ConsumerState<ScanBillSupplierScreen> {
  final LoggerService _logger = sl<LoggerService>();
  final _formKey = GlobalKey<FormState>();
  
  final _supplierController = TextEditingController();
  final _billNoController = TextEditingController();
  final _creditTermsController = TextEditingController();
  
  DateTime _billDate = DateTime.now();
  String _paymentStatus = 'unpaid';
  bool _isLoading = false;

  @override
  void dispose() {
    _supplierController.dispose();
    _billNoController.dispose();
    _creditTermsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    
    if (picked != null && mounted) {
      setState(() => _billDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Update supplier details in session
      final supplierDetails = SupplierDetails(
        supplierName: _supplierController.text.trim(),
        billNumber: _billNoController.text.trim(),
        billDate: _billDate,
        paymentStatus: _paymentStatus,
        creditTerms: _creditTermsController.text.trim(),
      );

      ref.read(scanBillSessionProvider(widget.verticalType).notifier)
          .setSupplierDetails(supplierDetails);

      // Submit the entry
      final success = await ref.read(
        scanBillSessionProvider(widget.verticalType).notifier
      ).submitEntry();

      if (success && mounted) {
        _showSuccessDialog();
      } else if (mounted) {
        final error = ref.read(scanBillSessionProvider(widget.verticalType)).error;
        _showErrorDialog(error ?? 'Failed to submit entry');
      }
    } catch (e) {
      _logger.error('Submission error', {'error': e.toString()});
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle, size: 64, color: Colors.green[600]),
        title: const Text('Purchase Entry Created'),
        content: const Text(
          'The purchase entry has been created successfully. '
          'Stock levels have been updated.'
        ),
        actions: [
          // Print Receipt Button
          OutlinedButton.icon(
            onPressed: () async {
              // Create a temporary entry for printing
              final sessionState = ref.read(scanBillSessionProvider(widget.verticalType));
              final entry = PurchaseEntry(
                rid: sessionState.rid,
                supplierName: _supplierController.text,
                billNumber: _billNoController.text.isEmpty ? null : _billNoController.text,
                billDate: _billDate.toIso8601String(),
                billImageS3Key: sessionState.s3ImageKey ?? '',
                lineItems: sessionState.reviewLineItems
                    ?.where((i) => !i.isDeleted && i.isValid)
                    .map((i) => i.toJson())
                    .toList() ?? [],
                totalAmount: sessionState.totalAmount,
                paymentStatus: _paymentStatus,
                verticalType: widget.verticalType,
                entryMethod: 'scan',
                createdBy: 'current_user',
                createdAt: DateTime.now().toIso8601String(),
              );
              
              final pdfService = PurchaseReceiptPdf();
              try {
                await pdfService.generateAndPrint(entry);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Print failed: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.print),
            label: const Text('Print Receipt'),
          ),
          // Done Button
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => 
                route.settings.name == '/purchase' || 
                route.isFirst
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.error_outline, size: 64, color: Colors.red[600]),
        title: const Text('Submission Failed'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final sessionState = ref.watch(scanBillSessionProvider(widget.verticalType));
    final itemCount = sessionState.validItemCount;
    final totalAmount = sessionState.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier & Bill Details'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary card
            _buildSummaryCard(itemCount, totalAmount, colorScheme),
            const SizedBox(height: 24),
            
            // Section: Supplier
            _buildSectionTitle('Supplier Information'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supplierController,
              decoration: InputDecoration(
                labelText: 'Supplier Name *',
                hintText: 'Enter supplier name',
                prefixIcon: const Icon(Icons.business_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Supplier name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Section: Bill Details
            _buildSectionTitle('Bill Details'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _billNoController,
              decoration: InputDecoration(
                labelText: 'Bill / Invoice Number',
                hintText: 'Enter bill number (optional)',
                prefixIcon: const Icon(Icons.receipt_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Bill date
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Bill Date *',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy').format(_billDate),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Section: Payment
            _buildSectionTitle('Payment'),
            const SizedBox(height: 12),
            _buildPaymentStatusSelector(colorScheme),
            const SizedBox(height: 24),
            
            // Section: Additional Info (Vertical-specific)
            if (widget.verticalType == 'wholesale') ...[
              _buildSectionTitle('Credit Terms'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _creditTermsController,
                decoration: InputDecoration(
                  labelText: 'Credit Period',
                  hintText: 'e.g., 30 days net',
                  prefixIcon: const Icon(Icons.schedule_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            if (widget.verticalType == 'pharmacy') ...[
              _buildSectionTitle('Compliance'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: false,
                onChanged: (v) {},
                title: const Text('Prescription / Drug License attached'),
                subtitle: const Text(
                  'Required for Schedule H drugs',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
            ],
            
            // Submit button
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isLoading 
                    ? 'Creating Entry...' 
                    : 'Confirm & Create Entry',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Back button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Review'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int itemCount, double totalAmount, ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.shopping_cart_checkout,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$itemCount Items Ready',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Review complete. Ready to create entry.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }

  Widget _buildPaymentStatusSelector(ColorScheme colorScheme) {
    final options = [
      ('unpaid', 'Unpaid', Icons.pending_outlined, Colors.orange),
      ('partial', 'Partially Paid', Icons.timelapse_outlined, Colors.blue),
      ('paid', 'Fully Paid', Icons.check_circle_outline, Colors.green),
    ];

    return Column(
      children: options.map((option) {
        final (value, label, icon, color) = option;
        final isSelected = _paymentStatus == value;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 2 : 0,
          color: isSelected ? color.withOpacity(0.1) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _paymentStatus = value),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: isSelected ? color : Colors.grey[600]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? color : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: color),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
