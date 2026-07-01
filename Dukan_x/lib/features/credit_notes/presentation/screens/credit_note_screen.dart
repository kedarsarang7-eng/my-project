// Credit Note Screen
//
// UI for creating credit notes from existing invoices
// with item selection, quantity adjustment, and preview.
//
// Author: DukanX Team
// Created: 2026-01-17

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../data/repositories/credit_note_repository.dart';
import '../../services/credit_note_service.dart';
import '../../data/models/credit_note_model.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/desktop/empty_state.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Credit Note Creation Screen
class CreateCreditNoteScreen extends ConsumerStatefulWidget {
  final String billId;
  final Bill bill;

  const CreateCreditNoteScreen({
    super.key,
    required this.billId,
    required this.bill,
  });

  @override
  ConsumerState<CreateCreditNoteScreen> createState() =>
      _CreateCreditNoteScreenState();
}

class _CreateCreditNoteScreenState
    extends ConsumerState<CreateCreditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late CreditNoteService _service;
  bool _isLoading = false;
  bool _shouldReturnStock = true;

  // Track selected items and quantities
  final Map<String, double> _returnQuantities = {};
  final Set<String> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _service = CreditNoteService(
      CreditNoteRepository(sl<AppDatabase>()),
      sl<BillsRepository>(),
      sl(),
    );

    // Initialize all items as selected with full quantity
    for (final item in widget.bill.items) {
      _selectedItems.add(item.productId);
      _returnQuantities[item.productId] = item.qty;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  double get _totalReturnAmount {
    double total = 0;
    for (final item in widget.bill.items) {
      if (_selectedItems.contains(item.productId)) {
        final qty = _returnQuantities[item.productId] ?? 0;
        // discount is an amount, calculate discount ratio
        final baseAmount = item.unitPrice * item.qty;
        final discountRatio = baseAmount > 0 ? item.discount / baseAmount : 0;
        final itemTotal = item.unitPrice * qty * (1 - discountRatio);
        final gst = itemTotal * item.gstRate / 100;
        total += itemTotal + gst;
      }
    }
    return total;
  }

  Future<void> _createCreditNote() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final returnItems = <CreditNoteItemInput>[];
      for (final item in widget.bill.items) {
        if (_selectedItems.contains(item.productId)) {
          returnItems.add(
            CreditNoteItemInput(
              productId: item.productId,
              returnQuantity: _returnQuantities[item.productId] ?? 0,
            ),
          );
        }
      }

      final creditNote = await _service.createCreditNote(
        billId: widget.billId,
        returnItems: returnItems,
        reason: _reasonController.text.trim(),
        shouldReturnStock: _shouldReturnStock,
      );

      if (creditNote != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Credit Note ${creditNote.creditNoteNumber} created!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(creditNote);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create credit note'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'â‚¹');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Create Credit Note'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Original Invoice Info
            GlassContainer(
              blur: 10,
              opacity: isDark ? 0.2 : 0.1,
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Original Invoice',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Invoice #',
                      widget.bill.invoiceNumber,
                      isDark,
                    ),
                    _buildInfoRow(
                      'Date',
                      DateFormat('dd MMM yyyy').format(widget.bill.date),
                      isDark,
                    ),
                    _buildInfoRow('Customer', widget.bill.customerName, isDark),
                    _buildInfoRow(
                      'Total Amount',
                      currencyFormat.format(widget.bill.grandTotal),
                      isDark,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Select Items
            Text(
              'Select Items to Return',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            ...widget.bill.items.map(
              (item) => _buildItemCard(item, isDark, currencyFormat),
            ),

            const SizedBox(height: 16),

            // Reason
            GlassContainer(
              blur: 10,
              opacity: isDark ? 0.2 : 0.1,
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason for Return',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for return...',
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reason';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stock Return Option
            GlassContainer(
              blur: 10,
              opacity: isDark ? 0.2 : 0.1,
              borderRadius: 16,
              child: SwitchListTile(
                title: Text(
                  'Return items to inventory',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Stock quantities will be increased',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                value: _shouldReturnStock,
                onChanged: (value) =>
                    setState(() => _shouldReturnStock = value),
                activeColor: Colors.green,
              ),
            ),

            const SizedBox(height: 24),

            // Summary
            GlassContainer(
              blur: 10,
              opacity: isDark ? 0.2 : 0.1,
              borderRadius: 16,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Credit Note Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          currencyFormat.format(_totalReturnAmount),
                          style: TextStyle(
                  fontSize: responsiveValue<double>(context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,  // PRESERVED: Desktop uses exactly 20 as before
                  ),
                            fontWeight: FontWeight.bold,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This amount will be credited to customer account',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Create Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createCreditNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Credit Note',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    BillItem item,
    bool isDark,
    NumberFormat currencyFormat,
  ) {
    final isSelected = _selectedItems.contains(item.productId);
    final returnQty = _returnQuantities[item.productId] ?? 0;

    return GlassContainer(
      blur: 10,
      opacity: isDark ? 0.2 : 0.1,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedItems.add(item.productId);
                        _returnQuantities[item.productId] = item.qty;
                      } else {
                        _selectedItems.remove(item.productId);
                      }
                    });
                  },
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${item.qty} ${item.unit} Ã— ${currencyFormat.format(item.price)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(item.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 48),
                  Text(
                    'Return Qty:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 20,
                    onPressed: returnQty > 1
                        ? () => setState(() {
                            _returnQuantities[item.productId] = returnQty - 1;
                          })
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      returnQty.toStringAsFixed(
                        returnQty == returnQty.roundToDouble() ? 0 : 2,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 20,
                    onPressed: returnQty < item.qty
                        ? () => setState(() {
                            _returnQuantities[item.productId] = returnQty + 1;
                          })
                        : null,
                  ),
                  Text(
                    '/ ${item.qty.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Credit Notes List Screen
class CreditNotesListScreen extends ConsumerStatefulWidget {
  const CreditNotesListScreen({super.key});

  @override
  ConsumerState<CreditNotesListScreen> createState() =>
      _CreditNotesListScreenState();
}

class _CreditNotesListScreenState extends ConsumerState<CreditNotesListScreen> {
  late CreditNoteService _service;
  List<CreditNote> _creditNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = CreditNoteService(
      CreditNoteRepository(sl<AppDatabase>()),
      sl<BillsRepository>(),
      sl(),
    );
    _loadCreditNotes();
  }

  Future<void> _loadCreditNotes() async {
    setState(() => _isLoading = true);
    try {
      _creditNotes = await _service.getAllCreditNotes();
    } catch (e) {
      debugPrint('Error loading credit notes: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'â‚¹');

    return DesktopContentContainer(
      title: 'Credit Notes',
      subtitle: 'Manage sales returns and adjustments',
      actions: [
        DesktopActionButton(
          icon: Icons.add_rounded,
          label: 'Create New',
          onPressed: () {
            // Logic to pick a bill first?
            // Usually we create CN from a bill.
            // Showing a tooltip or snackbar that they need to go to Bills
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please go to Invoices to create a Credit Note'),
              ),
            );
          },
        ),
      ],
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: FuturisticColors.premiumBlue,
              ),
            )
          : _creditNotes.isEmpty
          ? EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No Credit Notes',
              description:
                  'Credit notes created from invoices will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _loadCreditNotes,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _creditNotes.length,
                itemBuilder: (context, index) {
                  final cn = _creditNotes[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      borderRadius: 16,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: FuturisticColors.premiumBlue
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.description,
                                        color: FuturisticColors.premiumBlue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cn.creditNoteNumber,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(cn.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                FuturisticColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                _buildStatusChip(cn.status),
                              ],
                            ),
                            const Divider(height: 24, color: Colors.white10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Customer',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: FuturisticColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      cn.customerName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Amount',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: FuturisticColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormat.format(cn.grandTotal),
                                      style: TextStyle(
                                        fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                                        fontWeight: FontWeight.bold,
                                        color: FuturisticColors.success,
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
                  );
                },
              ),
            ),
    );
  }

  Widget _buildStatusChip(CreditNoteStatus status) {
    Color color;
    String label;

    switch (status) {
      case CreditNoteStatus.draft:
        color = Colors.orange;
        label = 'Draft';
        break;
      case CreditNoteStatus.confirmed:
        color = FuturisticColors.success;
        label = 'Confirmed';
        break;
      case CreditNoteStatus.cancelled:
        color = FuturisticColors.error;
        label = 'Cancelled';
        break;
      case CreditNoteStatus.adjusted:
        color = FuturisticColors.premiumBlue;
        label = 'Adjusted';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
