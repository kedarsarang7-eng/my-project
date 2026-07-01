// ============================================================================
// CREDIT NOTE SCREEN - SALES RETURN
// ============================================================================
// "Desktop-First" screen for handling sales returns and issuing credit notes.
// Mirrors BillCreationScreenV2 in layout but mirrors logic (Refunds).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_container.dart';
import '../../domain/entities/bill_item.dart' as billing;
import '../widgets/product_search_sheet.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/revenue_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../models/bill.dart' as model;
import 'package:dukanx/core/responsive/responsive.dart';

// Reuse components from billing feature where possible, or recreate variants
// For now, defining local variants to ensure "Red/Warning" theme integration

class CreditNoteScreen extends ConsumerStatefulWidget {
  final model.Bill? originalBill; // Optional: If returning from a specific bill

  const CreditNoteScreen({super.key, this.originalBill});

  @override
  ConsumerState<CreditNoteScreen> createState() => _CreditNoteScreenState();
}

class _CreditNoteScreenState extends ConsumerState<CreditNoteScreen> {
  // State
  final List<billing.BillItem> _returnItems = [];
  List<billing.BillItem> _availableItems = [];
  String _originalInvoiceNumber = '';
  Customer? _customer;
  bool _isLoading = false;

  // Controllers
  final TextEditingController _invoiceSearchController =
      TextEditingController();

  // Dependencies

  @override
  void initState() {
    super.initState();

    if (widget.originalBill != null) {
      _loadBill(widget.originalBill!);
    }
  }

  void _loadBill(model.Bill bill) {
    setState(() {
      _originalInvoiceNumber = bill.id;
      _customer = Customer(
        id: bill.customerId,
        name: bill.customerName,
        phone: bill.customerPhone,
      );
      _availableItems = bill.items.map((item) => billing.BillItem(
        productId: item.productId,
        name: item.productName,
        quantity: item.qty,
        rate: item.price,
        amount: item.total,
        unit: item.unit,
      )).toList();
    });
    _invoiceSearchController.text = bill.id;
  }

  // Calculate totals
  double get _totalRefundAmount =>
      _returnItems.fold(0, (sum, item) => sum + (item.rate * item.quantity));

  @override
  Widget build(BuildContext context) {
    // Theme: Credit Notes use "Warning/Error" colors (Red/Orange) to distinguish from Sales
    const accentColor = FuturisticColors.error;

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: FuturisticColors.darkBackgroundGradient,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = context.isMobile;

            if (isMobile) {
              return Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildHeader(accentColor),
                          const SizedBox(height: 16),
                          Expanded(child: _buildReturnItemBrowser(accentColor)),
                        ],
                      ),
                    ),
                  ),
                  if (_returnItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        border: Border(top: BorderSide(color: accentColor.withOpacity(0.2))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${_returnItems.length} items to return",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  "Refund: ₹${_totalRefundAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (ctx) => DraggableScrollableSheet(
                                  initialChildSize: 0.8,
                                  minChildSize: 0.5,
                                  maxChildSize: 0.95,
                                  builder: (_, scrollController) {
                                    return StatefulBuilder(
                                      builder: (context, setSheetState) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: FuturisticColors.surface,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                            border: Border.all(color: accentColor.withOpacity(0.3)),
                                          ),
                                          child: Column(
                                            children: [
                                              const SizedBox(height: 12),
                                              Container(
                                                width: 40,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: Colors.white24,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              _buildCustomerSection(accentColor),
                                              Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                                              Expanded(
                                                child: ListView.builder(
                                                  controller: scrollController,
                                                  padding: const EdgeInsets.all(16),
                                                  itemCount: _returnItems.length,
                                                  itemBuilder: (context, index) {
                                                    final item = _returnItems[index];
                                                    return Container(
                                                      margin: const EdgeInsets.only(bottom: 8),
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.03),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: accentColor.withOpacity(0.2)),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  item.name,
                                                                  style: GoogleFonts.inter(
                                                                    color: FuturisticColors.textPrimary,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "Return Qty: ${item.quantity} @ ₹${item.rate}",
                                                                  style: GoogleFonts.inter(
                                                                    color: FuturisticColors.textSecondary,
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Text(
                                                            "-₹${(item.quantity * item.rate).toStringAsFixed(0)}",
                                                            style: GoogleFonts.inter(
                                                              color: accentColor,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                                            onPressed: () {
                                                              _returnItems.removeAt(index);
                                                              setSheetState(() {});
                                                              if (_returnItems.isEmpty) {
                                                                Navigator.pop(context);
                                                              }
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              _buildRefundSection(accentColor),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("PROCEED"),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }

            // Desktop view
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildHeader(accentColor),
                        const SizedBox(height: 16),
                        Expanded(child: _buildReturnItemBrowser(accentColor)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: GlassContainer(
                    margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                    child: Column(
                      children: [
                        _buildCustomerSection(accentColor),
                        Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                        Expanded(child: _buildReturnList(accentColor)),
                        _buildRefundSection(accentColor),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withOpacity(0.2)),
      child: Row(
        children: [
          Icon(Icons.assignment_return, color: accent),
          const SizedBox(height: 12),
          Text(
            "CREDIT NOTE",
            style: GoogleFonts.outfit(
              color: accent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              controller: _invoiceSearchController,
              decoration: InputDecoration(
                hintText: "Enter Original Invoice #",
                hintStyle: GoogleFonts.inter(
                  color: FuturisticColors.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: FuturisticColors.textSecondary,
                  ),
                  onPressed: _searchInvoice,
                ),
              ),
              style: GoogleFonts.inter(color: FuturisticColors.textPrimary),
              onSubmitted: (_) => _searchInvoice(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnItemBrowser(Color accent) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      child: _originalInvoiceNumber.isEmpty
          ? _buildEmptyState(accent)
          : _buildInvoiceItemsList(accent),
    );
  }

  Widget _buildEmptyState(Color accent) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.remove_shopping_cart_outlined,
          size: 64,
          color: accent.withOpacity(0.2),
        ),
        const SizedBox(height: 16),
        Text(
          "Start Return Process",
          style: GoogleFonts.outfit(
            color: FuturisticColors.textPrimary,
            fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Search for an invoice to select items for return",
          style: GoogleFonts.inter(color: FuturisticColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text("Add Manual Return Item"),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent.withOpacity(0.2),
            foregroundColor: accent,
          ),
          onPressed: _showManualReturnSheet,
        ),
      ],
    );
  }

  Widget _buildInvoiceItemsList(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Items in Invoice #$_originalInvoiceNumber",
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: _showManualReturnSheet,
              child: const Text("Item not listed?"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_availableItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Text(
              "No items in this invoice",
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          )
        else
          ..._availableItems.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.name,
                style: GoogleFonts.inter(color: Colors.white),
              ),
              subtitle: Text(
                "Qty: ${item.quantity}  Rate: ₹${item.rate}",
                style: GoogleFonts.inter(color: Colors.white54),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.withOpacity(0.2),
                  foregroundColor: accent,
                ),
                onPressed: () {
                  setState(() {
                    _returnItems.add(item);
                  });
                },
                child: const Text("Return"),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerSection(Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: accent.withOpacity(0.1),
            child: Icon(Icons.person, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customer?.name ?? "No Customer Selected",
                  style: GoogleFonts.inter(
                    color: FuturisticColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _originalInvoiceNumber.isEmpty
                      ? "Returning: Walk-in / Manual"
                      : "Ref: $_originalInvoiceNumber",
                  style: GoogleFonts.inter(
                    color: FuturisticColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnList(Color accent) {
    if (_returnItems.isEmpty) {
      return Center(
        child: Text(
          "No items to return",
          style: GoogleFonts.inter(color: FuturisticColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _returnItems.length,
      itemBuilder: (context, index) {
        final item = _returnItems[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textPrimary,
                      ),
                    ),
                    Text(
                      "Return Qty: ${item.quantity} @ ₹${item.rate}",
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "-₹${(item.quantity * item.rate).toStringAsFixed(0)}",
                style: GoogleFonts.inter(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                onPressed: () => setState(() => _returnItems.removeAt(index)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefundSection(Color accent) {
    return Container(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(top: BorderSide(color: accent.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Refund Total",
                style: GoogleFonts.outfit(
                  color: FuturisticColors.textPrimary,
                  fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${sl<CurrencyService>().symbol}${_totalRefundAmount.toStringAsFixed(2)}",
                style: GoogleFonts.outfit(
                  color: accent,
                  fontSize: responsiveValue<double>(context, mobile: 22, tablet: 24, desktop: 28),
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: accent.withOpacity(0.5), blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [accent.withOpacity(0.8), accent.withOpacity(0.4)],
                ),
                boxShadow: FuturisticColors.neonShadow(accent),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _returnItems.isEmpty ? null : _processCreditNote,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            "ISSUE CREDIT NOTE",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualReturnSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSearchSheet(
        onProductSelected: (product) {
          setState(() {
            _returnItems.add(
              billing.BillItem(
                productId: product.id,
                name: product.name,
                quantity: 1,
                rate: product.sellingPrice,
                amount: product.sellingPrice, // Initial amount for qty 1
                unit: product.unit,
                // gstRate: product.gstRate, // If available in product model
              ),
            );
          });
        },
        onManualEntry: () {
          // Add a generic manual item if not found in catalog
          setState(() {
            _returnItems.add(
              const billing.BillItem(
                productId: 'manual_return',
                name: 'Manual Return Item',
                quantity: 1,
                rate: 0,
                amount: 0,
                unit: 'pcs',
              ),
            );
          });
        },
      ),
    );
  }

  Future<void> _searchInvoice() async {
    final query = _invoiceSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final billsRepo = sl<BillsRepository>();
      final result = await billsRepo.getById(query);

      if (result.isSuccess && result.data != null) {
        final bill = result.data!;
        setState(() {
          _originalInvoiceNumber = bill.id;
          _customer = Customer(
            id: bill.customerId,
            name: bill.customerName.isEmpty ? 'Walk-in' : bill.customerName,
            phone: bill.customerPhone,
          );
          _invoiceSearchController.text = bill.invoiceNumber;
          _availableItems = bill.items.map((item) => billing.BillItem(
            productId: item.productId,
            name: item.productName,
            quantity: item.qty,
            rate: item.price,
            amount: item.total,
            unit: item.unit,
          )).toList();
        });

        // Auto-show items from bill for selection
        _showBillItemsSelection(bill);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invoice Found!")));
      } else {
        // Try searching by invoice number if ID failed
        // Note: Repository currently supports getById. Search might be needed if by invoice number.
        // For now, assume ID or exact match.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invoice not found")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error searching invoice: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBillItemsSelection(model.Bill bill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: FuturisticColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Items to Return',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: bill.items.length,
                separatorBuilder: (_, _) =>
                    const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final item = bill.items[index];
                  // item is model.BillItem (from models/bill.dart)
                  return ListTile(
                    title: Text(
                      item.productName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Qty: ${item.qty} • ₹${item.total}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        setState(
                          () => _returnItems.add(
                            billing.BillItem(
                              productId: item.productId,
                              name: item.productName,
                              quantity: item.qty,
                              rate: item.price,
                              amount: item.total, // or item.qty * item.price
                              unit: item.unit,
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FuturisticColors.error.withOpacity(
                          0.2,
                        ),
                        foregroundColor: FuturisticColors.error,
                      ),
                      child: const Text('Return'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processCreditNote() async {
    setState(() => _isLoading = true);

    try {
      final userId = sl<SessionManager>().ownerId ?? '';
      if (userId.isEmpty) throw Exception('User not authenticated');

      final revenueRepo = sl<RevenueRepository>();

      // Convert BillItem to map for repository
      final returnItemsMap = _returnItems
          .map(
            (item) => {
              'itemId': item.productId,
              'itemName': item.name,
              'quantity': item.quantity,
              'rate': item.rate,
              'amount': item.quantity * item.rate,
            },
          )
          .toList();

      final result = await revenueRepo.addReturnInward(
        userId: userId,
        customerId: _customer?.id ?? '',
        items: returnItemsMap,
        totalReturnAmount: _totalRefundAmount,
        billId: _originalInvoiceNumber.isNotEmpty
            ? _originalInvoiceNumber
            : null,
        billNumber: _invoiceSearchController.text,
        reason: 'Customer Return',
      );

      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Credit Note Generated Successfully")),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(
          result.errorMessage ?? 'Failed to generate credit note',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error processing return: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// Simple customer model if not already imported from core
class Customer {
  final String id;
  final String name;
  final String? phone;
  Customer({required this.id, required this.name, this.phone});
}
