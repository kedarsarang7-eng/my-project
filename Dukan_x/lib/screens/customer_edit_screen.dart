import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:collection/collection.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/repository/customers_repository.dart';
import '../core/repository/products_repository.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';
import '../widgets/glass_morphism.dart';
import '../widgets/modern_ui_components.dart'; // Includes ModernCard, EmptyStateWidget
import '../models/customer.dart' as ui_cust;
import '../services/pdf_service.dart';

class CustomerEditScreen extends StatefulWidget {
  final ui_cust.Customer customer;

  const CustomerEditScreen({super.key, required this.customer});

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController discountCtrl;
  late TextEditingController marketTicketCtrl;

  bool isLoading = false;
  bool hasChanges = false;

  // Vegetable calculator
  List<Map<String, dynamic>> addedVegetablesSession = [];
  List<Product> availableVegetables = []; // Changed to Product
  bool vegLoading = false;
  String? _ownerId;

  late ui_cust.Customer localCustomer;

  @override
  void initState() {
    super.initState();
    _ownerId = sl<SessionManager>().ownerId;

    // Create a copy of customer for local mutations
    localCustomer = widget.customer
        .copyWith(); // Use copyWith if available or manual

    nameCtrl = TextEditingController(text: localCustomer.name);
    phoneCtrl = TextEditingController(text: localCustomer.phone);
    addressCtrl = TextEditingController(text: localCustomer.address);
    discountCtrl = TextEditingController(
      text: localCustomer.discountPercent.toString(),
    );
    marketTicketCtrl = TextEditingController(
      text: localCustomer.marketTicketAmount.toString(),
    );

    // Track changes
    nameCtrl.addListener(() => setState(() => hasChanges = true));
    phoneCtrl.addListener(() => setState(() => hasChanges = true));
    addressCtrl.addListener(() => setState(() => hasChanges = true));
    discountCtrl.addListener(() => setState(() => hasChanges = true));
    marketTicketCtrl.addListener(() => setState(() => hasChanges = true));

    // Load available vegetables
    _loadAvailableVegetables();
  }

  Future<void> _loadAvailableVegetables() async {
    if (_ownerId == null) return;
    setState(() => vegLoading = true);
    try {
      final result = await sl<ProductsRepository>().getAll(userId: _ownerId!);
      if (result.isSuccess) {
        setState(() => availableVegetables = result.data ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
      }
    } finally {
      if (mounted) setState(() => vegLoading = false);
    }
  }

  void _showAddVegetableDialog() {
    if (availableVegetables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add products first',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: FuturisticColors.error,
        ),
      );
      return;
    }

    String selectedVegId = '';
    List<Product> filteredVegetables = List.from(availableVegetables);
    final TextEditingController qtyCtrl = TextEditingController();
    final TextEditingController priceCtrl = TextEditingController();
    final TextEditingController searchCtrl = TextEditingController();
    bool dialogAdding = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Vegetable (Creates Bill)',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: FuturisticColors.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      style: AppTypography.bodyMedium.copyWith(
                        color: FuturisticColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Search Vegetable',
                        labelStyle: TextStyle(
                          color: FuturisticColors.textMuted,
                        ),
                        hintText: 'Type vegetable name...',
                        hintStyle: TextStyle(
                          color: FuturisticColors.textMuted.withOpacity(0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: FuturisticColors.accent,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: FuturisticColors.textMuted,
                                ),
                                onPressed: () {
                                  searchCtrl.clear();
                                  dialogSetState(() {
                                    filteredVegetables = List.from(
                                      availableVegetables,
                                    );
                                    selectedVegId = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        dialogSetState(() {
                          if (val.isEmpty) {
                            filteredVegetables = List.from(availableVegetables);
                          } else {
                            filteredVegetables = availableVegetables
                                .where(
                                  (v) => (v.name).toLowerCase().contains(
                                    val.toLowerCase(),
                                  ),
                                )
                                .toList();
                          }
                          selectedVegId = '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Vegetable Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: FuturisticColors.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FuturisticColors.glassBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedVegId.isEmpty ? null : selectedVegId,
                        hint: Text(
                          'Select Vegetable',
                          style: TextStyle(color: FuturisticColors.textMuted),
                        ),
                        dropdownColor: FuturisticColors.surface,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: FuturisticColors.textPrimary,
                        ),
                        items: filteredVegetables.map((veg) {
                          final vegId = veg.id;
                          final vegName = veg.name;
                          // Use sellingPrice as pricePerKg
                          final vegPrice = veg.sellingPrice.toStringAsFixed(2);
                          return DropdownMenuItem<String>(
                            value: vegId,
                            child: Text(
                              '$vegName (₹$vegPrice/unit)',
                              style: TextStyle(
                                color: FuturisticColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          dialogSetState(() {
                            selectedVegId = val ?? '';
                            // Prefill price
                            final veg = availableVegetables.firstWhereOrNull(
                              (v) => v.id == selectedVegId,
                            );
                            if (veg != null) {
                              priceCtrl.text = veg.sellingPrice.toString();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantity Input
                  _buildGlassTextField(
                    controller: qtyCtrl,
                    label: 'Quantity',
                    icon: Icons.scale,
                    suffixText: 'unit',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price per unit
                  _buildGlassTextField(
                    controller: priceCtrl,
                    label: 'Price per unit',
                    icon: Icons.currency_rupee,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      EnterpriseButton(
                        onPressed: dialogAdding
                            ? () {}
                            : () => Navigator.pop(context),
                        label: 'Cancel',
                        backgroundColor: Colors.transparent,
                        textColor: FuturisticColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EnterpriseButton(
                          onPressed: dialogAdding
                              ? () {}
                              : () async {
                                  final qty =
                                      double.tryParse(qtyCtrl.text.trim()) ??
                                      0.0;
                                  final price =
                                      double.tryParse(priceCtrl.text.trim()) ??
                                      0.0;

                                  if (selectedVegId.isEmpty ||
                                      qty <= 0 ||
                                      price <= 0) {
                                    return;
                                  }

                                  final vegMatch = availableVegetables
                                      .firstWhereOrNull(
                                        (v) => v.id == selectedVegId,
                                      );
                                  if (vegMatch == null) return;

                                  if (_ownerId == null) return;

                                  dialogSetState(() => dialogAdding = true);

                                  final total = qty * price;

                                  // Create Bill for this interaction
                                  final billId = DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString();

                                  final billItem = BillItem(
                                    productId: vegMatch.id,
                                    productName: vegMatch.name,
                                    qty: qty,
                                    price: price,
                                    unit: vegMatch.unit,
                                    gstRate: 0,
                                  );

                                  final bill = Bill(
                                    id: billId,
                                    invoiceNumber:
                                        'VEG-${billId.substring(billId.length - 6)}',
                                    customerId: widget.customer.id,
                                    customerName: widget.customer.name,
                                    customerPhone: widget.customer.phone,
                                    date: DateTime.now(),
                                    items: [billItem],
                                    subtotal: total.toDouble(),
                                    grandTotal: total.toDouble(),
                                    paidAmount: 0,
                                    status: 'Unpaid',
                                    ownerId: _ownerId!,
                                    shopName: '', // Optional
                                  );

                                  // Save Bill
                                  final result = await sl<BillsRepository>()
                                      .createBill(bill);

                                  if (mounted) {
                                    dialogSetState(() => dialogAdding = false);

                                    if (result.isSuccess) {
                                      setState(() {
                                        addedVegetablesSession.add({
                                          'vegName': vegMatch.name,
                                          'quantityKg': qty,
                                          'pricePerKg': price,
                                          'total': total,
                                        });
                                        // Optimistically update local customer due for display
                                        localCustomer.totalDues += total;
                                      });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✅ Bill created for ${vegMatch.name} ₹${total.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor:
                                              FuturisticColors.success,
                                        ),
                                      );
                                      Navigator.pop(context);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error creating bill: ${result.error}',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor:
                                              FuturisticColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          label: dialogAdding ? 'Creating...' : 'Create Bill',
                          icon: dialogAdding ? null : Icons.check,
                          backgroundColor: FuturisticColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? suffixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FuturisticColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FuturisticColors.glassBorder.withOpacity(0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        style: AppTypography.bodyMedium.copyWith(
          color: FuturisticColors.textPrimary,
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: FuturisticColors.textMuted),
          prefixIcon: Icon(icon, color: FuturisticColors.accent),
          suffixText: suffixText,
          suffixStyle: TextStyle(color: FuturisticColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (nameCtrl.text.isEmpty ||
        phoneCtrl.text.isEmpty ||
        addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_ownerId == null) return;

    setState(() => isLoading = true);
    try {
      // NOTE: We only update basic info. Logic for "adding vegetables"
      // is now handled via creating BILLS in real-time in the dialog.
      // We do NOT update vegetableHistory on customer object as it is being deprecated/moved to Bills.

      final updatedCustomer = localCustomer.copyWith(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        discountPercent: double.tryParse(discountCtrl.text) ?? 0.0,
        marketTicketAmount: double.tryParse(marketTicketCtrl.text) ?? 0.0,
      );

      final repoCustomer = Customer(
        id: updatedCustomer.id,
        odId: updatedCustomer.linkedOwnerId ?? _ownerId!,
        name: updatedCustomer.name,
        phone: updatedCustomer.phone,
        address: updatedCustomer.address,
        // Map other fields as needed, defaulting others
        createdAt:
            DateTime.now(), // Should preserve if available, but ui_cust might not have it
        updatedAt: DateTime.now(),
      );

      final result = await sl<CustomersRepository>().updateCustomer(
        repoCustomer,
        userId: _ownerId!,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Customer profile updated successfully!'),
          ),
        );
        setState(() => hasChanges = false);
        Navigator.pop(context, result.data);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${result.error}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: FuturisticColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildGlassTextField(
          controller: nameCtrl,
          label: 'Customer Name *',
          icon: Icons.person,
        ),
        const SizedBox(height: 12),
        _buildGlassTextField(
          controller: phoneCtrl,
          label: 'Phone Number *',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _buildGlassTextField(
          controller: addressCtrl,
          label: 'Address *',
          icon: Icons.location_on,
          maxLines: 2,
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModernCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: FuturisticColors.warningGradient,
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: FuturisticColors.surface,
                  child: Text(
                    widget.customer.name.isNotEmpty
                        ? widget.customer.name[0].toUpperCase()
                        : 'C',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer ID',
                      style: TextStyle(
                        fontSize: 12,
                        color: FuturisticColors.textMuted,
                      ),
                    ),
                    Text(
                      widget.customer.id.substring(0, 8),
                      style: TextStyle(
                        fontSize: 14,
                        color: FuturisticColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.customer.isBlacklisted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: FuturisticColors.errorGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '⛔ Blacklisted',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Business Settings',
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: FuturisticColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildGlassTextField(
          controller: discountCtrl,
          label: 'Discount Percentage (%)',
          icon: Icons.percent,
          suffixText: '%',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildGlassTextField(
          controller: marketTicketCtrl,
          label: 'Market Ticket Amount',
          icon: Icons.local_offer,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🥦 Veg Calc (Quick Bill)',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.textPrimary,
                    ),
                  ),
                  EnterpriseButton(
                    onPressed: vegLoading
                        ? () {}
                        : _showAddVegetableDialog,
                    icon: Icons.add,
                    label: 'Add Veg',
                    backgroundColor: FuturisticColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (addedVegetablesSession.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Text(
                      'Add vegetables to create instant bills.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: FuturisticColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    ...addedVegetablesSession.asMap().entries.map((
                      entry,
                    ) {
                      final veg = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FuturisticColors.surface
                                .withOpacity(0.5),
                            border: Border.all(
                              color: FuturisticColors.success
                                  .withOpacity(0.4),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      veg['vegName'],
                                      style: AppTypography
                                          .bodyMedium
                                          .copyWith(
                                            fontWeight:
                                                FontWeight.bold,
                                            color: FuturisticColors
                                                .textPrimary,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${veg['quantityKg']} unit × ₹${veg['pricePerKg']} = ₹${veg['total'].toStringAsFixed(2)}',
                                      style: AppTypography.bodySmall
                                          .copyWith(
                                            color: FuturisticColors
                                                .textMuted,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: FuturisticColors.success,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
            ],
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: FuturisticColors.lightBackgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'Edit Customer',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: FuturisticColors.textPrimary),
            onPressed: () {
              if (hasChanges) {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Discard changes?',
                            style: AppTypography.headlineSmall.copyWith(
                              color: FuturisticColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You have unsaved changes. Are you sure you want to discard them?',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: FuturisticColors.textMuted),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: EnterpriseButton(
                                  onPressed: () => Navigator.pop(context),
                                  label: 'Cancel',
                                  backgroundColor: Colors.transparent,
                                  textColor: FuturisticColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: EnterpriseButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  label: 'Discard',
                                  backgroundColor: FuturisticColors.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Export purchases PDF',
              icon: Icon(Icons.picture_as_pdf, color: FuturisticColors.accent),
              onPressed: () async {
                try {
                  await PdfService().shareCustomerPdf(widget.customer);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error exporting PDF: $e')),
                    );
                  }
                }
              },
            ),
            if (hasChanges)
              IconButton(
                icon: Icon(Icons.save, color: FuturisticColors.primary),
                onPressed: isLoading ? null : _saveChanges,
              ),
          ],
        ),
        body: ResponsiveContainer(
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: FuturisticColors.primary,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            rightColumn,
                            const SizedBox(height: 24),
                            leftColumn,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: leftColumn),
                            const SizedBox(width: 32),
                            Expanded(flex: 6, child: rightColumn),
                          ],
                        ),
                ),
        ),
      ),
    );
  }
}
