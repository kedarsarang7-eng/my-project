import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/app_state_providers.dart';
import '../../../utils/app_styles.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/neo_gradient_card.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/purchase_repository.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';

class AddPurchaseScreen extends ConsumerStatefulWidget {
  final PurchaseOrder? initialBill;
  const AddPurchaseScreen({super.key, this.initialBill});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _billNoController = TextEditingController();
  final _session = sl<SessionManager>();
  final PurchaseRepository _purchaseRepository = sl<PurchaseRepository>();

  List<PurchaseItem> _items = [];
  String _paymentMode = 'Credit'; // Default
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    if (widget.initialBill != null) {
      _supplierController.text = widget.initialBill!.vendorName ?? '';
      _billNoController.text = widget.initialBill!.invoiceNumber ?? '';
      _items = List.from(widget.initialBill!.items);
      _paymentMode = widget.initialBill!.paymentMode ?? 'Credit';
    }
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _billNoController.dispose();
    super.dispose();
  }

  void _showAddItemSheet() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');
    final batchCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? selectedExpiry;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add Item",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: responsiveValue<double>(
                          context,
                          mobile: 16,
                          tablet: 18,
                          desktop: 20,
                        ),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Item Name
                    TextFormField(
                      controller: nameCtrl,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: _inputDecoration(
                        "Item Name",
                        Icons.inventory,
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(color: Colors.white),
                            decoration: _inputDecoration(
                              "Quantity",
                              Icons.numbers,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Required";
                              if (double.tryParse(v) == null) return "Invalid";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: rateCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(color: Colors.white),
                            decoration: _inputDecoration(
                              "Rate",
                              Icons.currency_rupee,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Required";
                              if (double.tryParse(v) == null) return "Invalid";
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Unit
                    TextFormField(
                      controller: unitCtrl,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: _inputDecoration(
                        "Unit (e.g. pcs, kg, ltr)",
                        Icons.straighten,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Batch Number (optional)
                    TextFormField(
                      controller: batchCtrl,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: _inputDecoration(
                        "Batch Number (optional)",
                        Icons.qr_code,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Expiry Date (optional)
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 10),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedExpiry = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event,
                              color: Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              selectedExpiry != null
                                  ? "Expiry: ${selectedExpiry!.day}/${selectedExpiry!.month}/${selectedExpiry!.year}"
                                  : "Expiry Date (optional)",
                              style: GoogleFonts.inter(
                                color: selectedExpiry != null
                                    ? Colors.white
                                    : Colors.white54,
                              ),
                            ),
                            const Spacer(),
                            if (selectedExpiry != null)
                              GestureDetector(
                                onTap: () =>
                                    setSheetState(() => selectedExpiry = null),
                                child: const Icon(
                                  Icons.clear,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final qty = double.parse(qtyCtrl.text);
                            final rate = double.parse(rateCtrl.text);
                            final unit = unitCtrl.text.trim().isEmpty
                                ? 'pcs'
                                : unitCtrl.text.trim();

                            setState(() {
                              _items.add(
                                PurchaseItem(
                                  id: const Uuid().v4(),
                                  productId: null,
                                  productName: nameCtrl.text.trim(),
                                  quantity: qty,
                                  unit: unit,
                                  costPrice: rate,
                                  taxRate: 0,
                                  totalAmount: qty * rate,
                                  batchNumber: batchCtrl.text.trim().isEmpty
                                      ? null
                                      : batchCtrl.text.trim(),
                                  expiryDate: selectedExpiry,
                                ),
                              );
                            });
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("ADD TO INVOICE"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green),
      ),
      filled: true,
      fillColor: Colors.black12,
    );
  }

  Future<void> _saveBill(String ownerId) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one item")),
      );
      return;
    }
    if (_supplierController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter supplier name")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.initialBill != null) {
        await _purchaseRepository.updatePurchaseOrder(
          id: widget.initialBill!.id,
          userId: ownerId,
          vendorName: _supplierController.text,
          invoiceNumber: _billNoController.text,
          totalAmount: _totalAmount,
          paidAmount: _paymentMode == 'Credit' ? 0.0 : _totalAmount,
          paymentMode: _paymentMode,
          items: _items,
        );
      } else {
        await _purchaseRepository.createPurchaseOrder(
          userId: ownerId,
          vendorName: _supplierController.text,
          invoiceNumber: _billNoController.text,
          totalAmount: _totalAmount,
          paidAmount: _paymentMode == 'Credit' ? 0.0 : _totalAmount,
          paymentMode: _paymentMode,
          items: _items,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invoice Saved!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String msg = "Error: $e";
        if (e.toString().toLowerCase().contains('offline') ||
            e.toString().toLowerCase().contains('unavailable')) {
          msg = "You are offline. Cannot save vendor invoice.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final ownerId = _session.ownerId ?? '';

    return Scaffold(
      // Match the active theme's scaffold background (light off-white / dark
      // slate) instead of forcing a dark navy (palette.mutedGray) that made the
      // screen render dark even in light theme.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "New Vendor Invoice",
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: context.isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSupplierSection(),
                        const SizedBox(height: 20),
                        _buildItemsSection(palette),
                        const SizedBox(height: 20),
                        _buildPaymentSection(palette),
                        const SizedBox(height: 100),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSupplierSection(),
                              const SizedBox(height: 20),
                              _buildPaymentSection(palette),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [_buildItemsSection(palette)],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomBar(palette, ownerId),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Supplier Details",
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _supplierController,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: _inputDecoration("Supplier Name", Icons.person_outline),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _billNoController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: _inputDecoration(
                    "Invoice No",
                    Icons.receipt_long,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Today",
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(AppColorPalette palette) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Items (${_items.length})",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _showAddItemSheet,
              icon: Icon(Icons.add_circle, color: palette.leafGreen),
              label: Text(
                "Add Item",
                style: TextStyle(color: palette.leafGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GlassContainer(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "${item.quantity} x ₹${item.costPrice}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${sl<CurrencyService>().symbol}${item.totalAmount}",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "No items added yet",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white24),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentSection(AppColorPalette palette) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Mode",
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModeChip("Cash", "Cash", palette),
              _buildModeChip("UPI", "UPI", palette),
              _buildModeChip("Credit", "Credit", palette),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, String value, AppColorPalette palette) {
    final isSelected = _paymentMode == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.leafGreen
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? palette.leafGreen
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(AppColorPalette palette, String ownerId) {
    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      padding: const EdgeInsets.all(20),
      gradient: AppGradients.darkGlass,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Payable",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  "${sl<CurrencyService>().symbol}${_totalAmount.toStringAsFixed(0)}",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 24,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _items.isEmpty || _isLoading
                ? null
                : () => _saveBill(ownerId),
            child: NeoGradientCard(
              gradient: (_items.isEmpty || _isLoading)
                  ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                  : AppGradients.emerald,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              borderRadius: BorderRadius.circular(30),
              child: Row(
                children: [
                  const Icon(Icons.check, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    "SAVE INVOICE",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
