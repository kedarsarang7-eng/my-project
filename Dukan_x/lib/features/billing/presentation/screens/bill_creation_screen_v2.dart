// ============================================================================
// BILL CREATION SCREEN V2 - HIGH PERFORMANCE & PRODUCTION READY
// ============================================================================
// Fully persistent, offline-first billing interface
// Uses sl<BillsRepository> for all data operations
//
// Author: DukanX Engineering
// Version: 2.1.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/invoice_number_service.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../models/transaction_model.dart';
import '../../../../features/ai_assistant/services/recommendation_service.dart';
import '../widgets/product_search_sheet.dart';
import '../widgets/customer_search_sheet.dart';
import '../widgets/smart_voice_bill_sheet.dart';
import '../widgets/payment_qr_dialog.dart';
import '../widgets/adaptive_item_card.dart'; // Added
import '../widgets/adaptive_bill_header.dart'; // Added
import '../widgets/manual_item_entry_sheet.dart';
import '../../domain/entities/voice_bill_intent.dart';
import '../../../../core/billing/feature_resolver.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../restaurant/utils/restaurant_business_rules.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../services/barcode_scanner_service.dart'; // Import scanner
import '../../../../core/config/business_capabilities.dart'; // Import config
import '../../../../core/billing/business_type_config.dart'; // Grocery unitOptions (kg/gm) source of truth
import '../../../../widgets/weighing_scale_widget.dart'; // Grocery loose-weight (kg/gm) capture
import 'package:image_picker/image_picker.dart'; // Import Image Picker
import '../../../../features/ml/ml_services/ocr_router.dart'; // Import OCR Router
import '../../../invoice/screens/invoice_preview_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/gmail_service.dart';
import '../../../../services/email_repository.dart';
import '../../../../services/invoice_pdf_service.dart';
import '../../../../features/billing/services/broker_billing_service.dart'; // Mandi
import '../../../../features/billing/services/mandi_sale_validator.dart'; // Mandi input validation (R8.1–8.5)
import '../../../../features/service/services/service_job_service.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/pharmacy_dao.dart';
// Pharmacy compliance: prescription capture (R7) + MRP ceiling (R8) wiring.
import '../../../prescriptions/presentation/widgets/prescription_gate_dialog.dart';
import '../../../inventory/services/drug_schedule_service.dart'
    show DrugSchedule;
import '../../../pharmacy/utils/drug_schedule_resolver.dart';
import '../../../pharmacy/utils/prescription_id.dart';
import '../../../../utils/mrp_enforcement_validator.dart';
import '../../../../core/pharmacy/paise.dart';
// Pharmacy salt/substitute search embedded in billing (Requirement 25).
import '../../../pharmacy/screens/salt_search_screen.dart';

import '../../../../widgets/desktop/desktop_content_container.dart';
// Keyboard Architecture - Tally-Style Shortcuts
import '../../../../core/keyboard/global_keyboard_handler.dart';
import '../../../../widgets/ui/shortcut_pill.dart';
import '../../../dashboard/v2/providers/dashboard_v2_providers.dart';
import 'package:go_router/go_router.dart';

class BillCreationScreenV2 extends ConsumerStatefulWidget {
  final Customer? initialCustomer;
  final List<BillItem>? initialItems;
  final TransactionType transactionType;
  final String? serviceJobId;

  const BillCreationScreenV2({
    super.key,
    this.initialCustomer,
    this.initialItems,
    this.transactionType = TransactionType.sale,
    this.serviceJobId,
  });

  @override
  ConsumerState<BillCreationScreenV2> createState() =>
      _BillCreationScreenV2State();
}

class _BillCreationScreenV2State extends ConsumerState<BillCreationScreenV2>
    with TickerProviderStateMixin {
  // Repositories
  final _billsRepo = sl<BillsRepository>();
  final _session = sl<SessionManager>();

  // Bill State
  Customer? _selectedCustomer;
  FarmerEntity? _selectedFarmer; // Mandi: Supplier
  final List<BillItem> _items = []; // Removed final to allow clear inside
  String _invoiceNumber = '';
  List<Product> _recommendations = []; // AI Suggestions
  String? _prescriptionId; // Pharmacy: Rx gate result

  // Pharmacy: per-product MRP ceiling in integer paise (Requirement 8). Captured
  // from the FEFO batch when a pharmacy line item is added; used to enforce the
  // MRP ceiling at line-item price entry (R8.1–R8.2). Empty for non-pharmacy.
  final Map<String, int> _mrpPaiseByProductId = {};

  // Bill Header State (Table No, Vehicle No, etc.)
  Bill _headerBill = Bill.empty();

  // Restaurant Service Charge State (dine-in only, default 5%)
  bool _serviceChargeEnabled = true;
  double _serviceChargePercent = 5.0;

  // Restaurant Tip State (optional, not included in taxable subtotal or GST)
  double _tipAmount = 0.0;
  final TextEditingController _tipController = TextEditingController();

  // Happy Hour Pricing State (restaurant only)
  // Default window: 4 PM – 7 PM; discount: 10%
  bool _happyHourEnabled = true;
  double _happyHourDiscountPercent = 10.0;
  static const int _happyHourStart = 16; // 4 PM
  static const int _happyHourEnd = 19; // 7 PM

  // Controllers
  bool _isLoading = false;
  bool _sendEmail = false;

  // Keyboard Focus Nodes for Tally-style navigation
  final FocusNode _customerFocusNode = FocusNode();
  final FocusNode _itemSearchFocusNode = FocusNode();

  // Walk-in Customer (fallback when no customer selected)
  // Stable constant ID — must NOT vary per screen mount or session, otherwise
  // multiple walk-in bills within the same session link to different phantom customers.
  static const _walkInCustomerId = 'walk-in-customer';
  static final _walkInCustomer = Customer(
    id: _walkInCustomerId,
    odId: 'walk-in',
    name: 'Walk-in Customer',
    phone: null,
    createdAt: DateTime.utc(2020),
    updatedAt: DateTime.utc(2020),
  );

  // Computed Properties
  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.total);
  double get _totalTax => _items.fold(0.0, (sum, item) => sum + item.taxAmount);

  /// Service charge amount for restaurant dine-in bills.
  /// Returns 0 when disabled or when business type is not restaurant.
  double get _serviceChargeAmount {
    if (!_serviceChargeEnabled) return 0.0;
    return RestaurantBusinessRules.serviceCharge(
      _subtotal,
      rate: _serviceChargePercent / 100,
    );
  }

  /// Whether service charge applies: restaurant business, dine-in (not all items parcel).
  bool get _isRestaurantDineIn {
    if (_items.isEmpty) return false;
    // If every item is marked parcel, it's a takeaway/parcel order — no service charge.
    final allParcel = _items.every((item) => item.isParcel == true);
    return !allParcel;
  }

  double get _grandTotal {
    final base = _subtotal + _totalTax;
    // Add service charge only for restaurant dine-in bills
    if (_isRestaurantBill && _isRestaurantDineIn) {
      return base + _serviceChargeAmount;
    }
    return base;
  }

  /// Helper to check if the current business type is restaurant.
  bool get _isRestaurantBill {
    try {
      return ref.read(businessTypeProvider).type == BusinessType.restaurant;
    } catch (_) {
      return false;
    }
  }

  /// Whether happy hour is currently active (restaurant only).
  /// Uses the configured window and checks via RestaurantBusinessRules.
  bool get _isHappyHourActive {
    if (!_isRestaurantBill || !_happyHourEnabled) return false;
    return RestaurantBusinessRules.isInHappyHour(
      now: DateTime.now(),
      startHour24: _happyHourStart,
      endHour24: _happyHourEnd,
    );
  }

  /// Total happy-hour discount applied across all items in the current bill.
  double get _happyHourDiscountTotal {
    if (!_isHappyHourActive) return 0.0;
    // The discount is already embedded in each item's `discount` field when
    // added during happy hour. Sum up what was applied.
    return _items.fold(0.0, (sum, item) => sum + item.discount);
  }

  // Payment State
  String _paymentMode = 'Cash';
  double get _paidAmount => _paymentMode == 'Unpaid' ? 0.0 : _grandTotal;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
    if (widget.initialItems != null) {
      _items.addAll(widget.initialItems!);
    }
    _generateInvoiceNumber();
    _updateRecommendations();

    // Auto-focus customer field after build (Tally-style F8 behavior)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedCustomer == null) {
        _customerFocusNode.requestFocus();
      } else {
        _itemSearchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _customerFocusNode.dispose();
    _itemSearchFocusNode.dispose();
    _tipController.dispose();
    super.dispose();
  }

  /// Listen for keyboard intents from GlobalKeyboardHandler
  void _handleKeyboardIntent(KeyboardIntentState intent) {
    if (intent.lastIntent == null) return;

    switch (intent.lastIntent) {
      case 'SAVE':
        _handleSave();
        break;
      case 'ADD_ITEM':
        _showProductSearch();
        break;
      case 'PRINT':
        if (_items.isNotEmpty) {
          _handleSave(); // Save first, then print
        }
        break;
      case 'SEARCH':
        _showProductSearch();
        break;
    }
  }

  Future<void> _generateInvoiceNumber() async {
    try {
      final userId = _session.ownerId ?? '';
      if (userId.isEmpty) {
        // Fallback for unauthenticated state (should not happen)
        final now = DateTime.now();
        final dateStr =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        _invoiceNumber = 'INV-$dateStr-0000';
        return;
      }

      // Use the centralized InvoiceNumberService for atomic, collision-free generation
      final invoiceService = InvoiceNumberService(AppDatabase.instance);
      final number = await invoiceService.getNextInvoiceNumber(userId: userId);

      if (mounted) {
        setState(() {
          _invoiceNumber = number;
        });
      }
    } catch (e) {
      debugPrint('[BillCreationV2] Invoice number generation failed: $e');
      // Fallback: timestamp-based (unique but not sequential)
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      _invoiceNumber =
          'INV-$dateStr-${now.millisecondsSinceEpoch.toString().substring(8)}';
    }
  }

  Future<void> _updateRecommendations() async {
    try {
      final recService = sl<RecommendationService>();
      final suggestions = await recService.getRecommendations(_items);
      if (mounted) {
        setState(() {
          _recommendations = suggestions;
        });
      }
    } catch (e) {
      // Silently ignore recommendation errors
    }
  }

  /// Pharmacy prescription gate (Requirement 7).
  ///
  /// When a pharmacy item whose resolved Drug_Schedule ∈ {H, H1, X} is being
  /// added, this opens [PrescriptionGateDialog] to capture a prescription
  /// BEFORE the item is added to the bill (R7.1). On a completed, valid capture
  /// the prescription identifier is assigned to the bill (R7.2) and `true` is
  /// returned so the caller proceeds to add the line. On cancel (or an
  /// out-of-bounds identifier) `false` is returned and the caller must NOT add
  /// the scheduled line, leaving the bill content unchanged (R7.3).
  ///
  /// Null/unset/non-scheduled items return `true` immediately — they are not
  /// gated and continue through the normal validation path (R7.4).
  Future<bool> _ensurePrescriptionForProduct(
    BusinessType businessType,
    Product product,
  ) async {
    if (businessType != BusinessType.pharmacy) return true;

    final canonical = DrugScheduleResolver.fromRaw(product.drugSchedule);
    if (!DrugScheduleResolver.isScheduled(canonical)) {
      return true; // OTC / null / unset — no gate (R7.4).
    }

    final result = await PrescriptionGateDialog.showRich(
      context,
      productName: product.name,
      schedule: _toInventorySchedule(canonical),
    );

    // Cancelled — do not add the scheduled line; bill content stays intact.
    if (result == null) return false;

    // A valid prescription requires a non-empty id of 1..100 chars (R7.2).
    final rxId = PrescriptionId.normalize(result.prescriptionId);
    if (rxId == null) return false;

    setState(() => _prescriptionId = rxId);
    return true;
  }

  /// Map the canonical schedule onto the inventory [DrugSchedule] the
  /// prescription gate expects. `unrecognized`/`nonScheduled` map to `none`;
  /// callers only invoke the gate for the scheduled values, so the default is
  /// effectively unreachable for the H/H1/X cases.
  DrugSchedule _toInventorySchedule(CanonicalDrugSchedule canonical) {
    switch (canonical) {
      case CanonicalDrugSchedule.scheduleH:
        return DrugSchedule.scheduleH;
      case CanonicalDrugSchedule.scheduleH1:
        return DrugSchedule.scheduleH1;
      case CanonicalDrugSchedule.scheduleX:
        return DrugSchedule.scheduleX;
      case CanonicalDrugSchedule.nonScheduled:
      case CanonicalDrugSchedule.unrecognized:
        return DrugSchedule.none;
    }
  }

  /// Defensive FEFO (First-Expiry-First-Out) ordering applied in the Pharmacy
  /// POS as a safety net over [PharmacyDao]'s SQL ordering (Requirement 17.4).
  ///
  /// Batches are ordered by expiry date ascending (earliest first); batches
  /// with no expiry date sort after all dated batches; ties are broken by batch
  /// identifier ascending so selection is deterministic and repeatable. The
  /// input list is not mutated — a new sorted list is returned, whose first
  /// element is the earliest-expiry batch to auto-select (Requirement 17.5).
  List<ProductBatchEntity> _fefoSorted(List<ProductBatchEntity> batches) {
    final sorted = List<ProductBatchEntity>.of(batches);
    sorted.sort((a, b) {
      final aExp = a.expiryDate;
      final bExp = b.expiryDate;
      if (aExp == null && bExp == null) return a.id.compareTo(b.id);
      if (aExp == null) return 1; // null expiry sorts last
      if (bExp == null) return -1;
      final cmp = aExp.compareTo(bExp);
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    });
    return sorted;
  }

  Future<void> _addItem(Product product) async {
    if (product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} is out of stock (Qty: ${product.stockQuantity})',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'CONTINUE ANYWAY',
            textColor: Colors.white,
            onPressed: () => _addItemWithStockWarning(product),
          ),
        ),
      );
      return;
    }

    // Check if adding more would exceed available stock
    final existingItemIndex = _items.indexWhere(
      (i) => i.productId == product.id,
    );
    if (existingItemIndex != -1) {
      final existingItem = _items[existingItemIndex];
      final newTotalQty = existingItem.qty + 1;
      if (newTotalQty > product.stockQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient stock for ${product.name}. Available: ${product.stockQuantity}, Requested: $newTotalQty',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    final businessType = ref.read(businessTypeProvider).type;
    final features = FeatureResolver(businessType);

    if (features.isMandiMode) {
      _showMandiEntrySheet(product);
      return;
    }
    // Grocery loose-weight (kg/gm): capture weight on the scale, then add the
    // line via the SAME add-line-item path manual entry uses.
    if (businessType == BusinessType.grocery &&
        _isGroceryWeightUnit(product.unit)) {
      _showGroceryWeightSheet(product);
      return;
    }
    // For pharmacy: auto-select FEFO (first-expiry) batch
    String? fefosBatchNo;
    DateTime? fefoBatchExpiry;
    if (businessType == BusinessType.pharmacy && product.id.isNotEmpty) {
      try {
        final userId = _session.ownerId ?? '';
        final dao = PharmacyDao(AppDatabase.instance);
        // Inline expiry-ascending defensive sort over the DAO result, then pick
        // the earliest-expiry batch (Requirements 17.4–17.5).
        final batches = _fefoSorted(
          await dao.getBatchesForProduct(userId, product.id),
        );
        if (batches.isNotEmpty) {
          fefosBatchNo = batches.first.batchNumber;
          fefoBatchExpiry = batches.first.expiryDate;
          // Capture the FEFO batch MRP (rupees) as the integer-paise ceiling
          // used for MRP enforcement at price entry (R8.1–R8.2).
          final batchMrp = batches.first.mrp;
          if (batchMrp > 0) {
            _mrpPaiseByProductId[product.id] = Paise.fromRupees(batchMrp);
          }
        }
      } catch (_) {
        // Non-blocking: proceed without batch auto-selection
      }
    }

    // Pharmacy prescription gate (R7): scheduled drugs (H/H1/X) must capture a
    // prescription before being added. Cancel leaves the bill unchanged.
    if (!await _ensurePrescriptionForProduct(businessType, product)) {
      return;
    }
    if (!mounted) return;

    setState(() {
      // Happy-hour per-unit discount (restaurant only, auto-applied).
      final double happyHourPerUnit = _isHappyHourActive
          ? product.sellingPrice * (_happyHourDiscountPercent / 100)
          : 0.0;

      final existingIndex = _items.indexWhere((i) => i.productId == product.id);
      if (existingIndex != -1) {
        final existing = _items[existingIndex];
        final newQty = existing.qty + 1;
        final perUnitDiscount = existing.qty > 0
            ? existing.discount / existing.qty
            : 0.0;
        final taxableBase = (existing.price - perUnitDiscount).clamp(
          0.0,
          double.infinity,
        );
        _items[existingIndex] = BillItem(
          productId: existing.productId,
          productName: existing.productName,
          qty: newQty,
          price: existing.price,
          unit: existing.unit,
          gstRate: existing.gstRate,
          discount: perUnitDiscount * newQty,
          cgst: newQty * (taxableBase * (existing.gstRate / 200)),
          sgst: newQty * (taxableBase * (existing.gstRate / 200)),
        );
      } else {
        // Compute taxable base after happy-hour discount for GST calculation.
        final taxablePrice = (product.sellingPrice - happyHourPerUnit).clamp(
          0.0,
          double.infinity,
        );
        _items.add(
          BillItem(
            productId: product.id,
            productName: product.name,
            qty: 1,
            price: product.sellingPrice,
            unit: product.unit,
            gstRate: product.taxRate,
            discount: happyHourPerUnit,
            cgst: taxablePrice * (product.taxRate / 200),
            sgst: taxablePrice * (product.taxRate / 200),
            size: product.size,
            color: product.color,
            drugSchedule: product.drugSchedule,
            batchNo: fefosBatchNo, // FEFO batch auto-filled
            expiryDate: fefoBatchExpiry, // FEFO expiry auto-filled
            notes: happyHourPerUnit > 0 ? 'Happy Hour Discount' : null,
          ),
        );
      }
    });

    _updateRecommendations(); // Refresh suggestions

    // Tally Style: Auto-return focus to search for rapid entry
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _itemSearchFocusNode.requestFocus();
    });
  }

  /// Helper to add item even when out of stock (with warning acknowledged)
  Future<void> _addItemWithStockWarning(Product product) async {
    final businessType = ref.read(businessTypeProvider).type;
    final features = FeatureResolver(businessType);

    // Log the override for audit trail
    debugPrint(
      '[AUDIT] Stock warning overridden for product ${product.id} (${product.name})',
    );

    if (features.isMandiMode) {
      _showMandiEntrySheet(product);
      return;
    }

    // Grocery loose-weight (kg/gm): same scale-driven path, even after a stock
    // warning override (reuses the standard add-line-item logic).
    if (businessType == BusinessType.grocery &&
        _isGroceryWeightUnit(product.unit)) {
      _showGroceryWeightSheet(product);
      return;
    }

    // For pharmacy: auto-select FEFO (first-expiry) batch
    String? fefosBatchNo;
    DateTime? fefoBatchExpiry;
    if (businessType == BusinessType.pharmacy && product.id.isNotEmpty) {
      try {
        final userId = _session.ownerId ?? '';
        final dao = PharmacyDao(AppDatabase.instance);
        // Inline expiry-ascending defensive sort over the DAO result, then pick
        // the earliest-expiry batch (Requirements 17.4–17.5).
        final batches = _fefoSorted(
          await dao.getBatchesForProduct(userId, product.id),
        );
        if (batches.isNotEmpty) {
          fefosBatchNo = batches.first.batchNumber;
          fefoBatchExpiry = batches.first.expiryDate;
          // Capture the FEFO batch MRP (rupees) as the integer-paise ceiling
          // used for MRP enforcement at price entry (R8.1–R8.2).
          final batchMrp = batches.first.mrp;
          if (batchMrp > 0) {
            _mrpPaiseByProductId[product.id] = Paise.fromRupees(batchMrp);
          }
        }
      } catch (_) {
        // Non-blocking: proceed without batch auto-selection
      }
    }

    // Pharmacy prescription gate (R7): scheduled drugs (H/H1/X) must capture a
    // prescription before being added. Cancel leaves the bill unchanged.
    if (!await _ensurePrescriptionForProduct(businessType, product)) {
      return;
    }
    if (!mounted) return;

    setState(() {
      // Happy-hour per-unit discount (restaurant only, auto-applied).
      final double happyHourPerUnit = _isHappyHourActive
          ? product.sellingPrice * (_happyHourDiscountPercent / 100)
          : 0.0;

      final existingIndex = _items.indexWhere((i) => i.productId == product.id);
      if (existingIndex != -1) {
        final existing = _items[existingIndex];
        final newQty = existing.qty + 1;
        final perUnitDiscount = existing.qty > 0
            ? existing.discount / existing.qty
            : 0.0;
        final taxableBase = (existing.price - perUnitDiscount).clamp(
          0.0,
          double.infinity,
        );
        _items[existingIndex] = BillItem(
          productId: existing.productId,
          productName: existing.productName,
          qty: newQty,
          price: existing.price,
          unit: existing.unit,
          gstRate: existing.gstRate,
          discount: perUnitDiscount * newQty,
          cgst: newQty * (taxableBase * (existing.gstRate / 200)),
          sgst: newQty * (taxableBase * (existing.gstRate / 200)),
        );
      } else {
        final taxablePrice = (product.sellingPrice - happyHourPerUnit).clamp(
          0.0,
          double.infinity,
        );
        _items.add(
          BillItem(
            productId: product.id,
            productName: product.name,
            qty: 1,
            price: product.sellingPrice,
            unit: product.unit,
            gstRate: product.taxRate,
            discount: happyHourPerUnit,
            cgst: taxablePrice * (product.taxRate / 200),
            sgst: taxablePrice * (product.taxRate / 200),
            size: product.size,
            color: product.color,
            drugSchedule: product.drugSchedule,
            batchNo: fefosBatchNo,
            expiryDate: fefoBatchExpiry,
            notes: happyHourPerUnit > 0 ? 'Happy Hour Discount' : null,
          ),
        );
      }
    });

    _updateRecommendations();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _itemSearchFocusNode.requestFocus();
    });
  }

  // ... inside _updateQuantity

  void _updateQuantity(int index, double newQty) {
    if (newQty <= 0) {
      setState(() => _items.removeAt(index));
      _updateRecommendations(); // Refresh suggestions when item removed
      return;
    }
    // ... existing update logic ...
    setState(() {
      final item = _items[index];
      // GST on taxable base (price minus per-unit discount)
      final perUnitDiscount = item.qty > 0 ? item.discount / item.qty : 0.0;
      final taxableBase = (item.price - perUnitDiscount).clamp(
        0.0,
        double.infinity,
      );
      _items[index] = BillItem(
        productId: item.productId,
        productName: item.productName,
        qty: newQty,
        price: item.price,
        unit: item.unit,
        gstRate: item.gstRate,
        discount: perUnitDiscount * newQty,
        cgst: newQty * (taxableBase * (item.gstRate / 200)),
        sgst: newQty * (taxableBase * (item.gstRate / 200)),
        // Mandi: Update Net Weight if applicable
        netWeight: (item.grossWeight ?? 0) > 0
            ? ((item.grossWeight ?? 0) - (item.tareWeight ?? 0)).clamp(
                0,
                double.infinity,
              )
            : item.netWeight,
        commission: item.commission, // Preserve commission
      );
    });
  }

  // Mandi: Show Farmer Selection
  void _showFarmerSearch() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildFarmerList(),
    );
  }

  Widget _buildFarmerList() {
    final brokerService = BrokerBillingService(
      sl<AppDatabase>(),
      sl(),
      sl(),
    ); // Temp instantiation
    final userId = _session.ownerId ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "Select Supplier (Farmer)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<FarmerEntity>>(
              stream: brokerService.watchFarmers(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final farmers = snapshot.data!;
                if (farmers.isEmpty) {
                  return const Center(child: Text("No Farmers Found"));
                }
                return ListView.builder(
                  itemCount: farmers.length,
                  itemBuilder: (context, index) {
                    final f = farmers[index];
                    return ListTile(
                      leading: const Icon(Icons.agriculture),
                      title: Text(f.name),
                      subtitle: Text(f.village ?? ''),
                      onTap: () {
                        setState(() => _selectedFarmer = f);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Quick Add Farmer Dialog
              _showAddFarmerDialog(brokerService);
            },
            icon: const Icon(Icons.add),
            label: const Text("Add New Farmer"),
          ),
        ],
      ),
    );
  }

  void _showAddFarmerDialog(BrokerBillingService service) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final villageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Farmer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
            TextField(
              controller: villageCtrl,
              decoration: const InputDecoration(labelText: "Village"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final ownerId = _session.ownerId ?? '';
                if (ownerId.isEmpty) return;
                await service.createFarmer(
                  ownerId,
                  nameCtrl.text,
                  phoneCtrl.text,
                  villageCtrl.text,
                );
                Navigator.pop(ctx);
                // Auto select?
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _applyVoiceIntent(VoiceBillIntent intent) {
    setState(() {
      // 1. Map Items
      for (final domainItem in intent.items) {
        // Check if item already exists to merge?
        final existingIndex = _items.indexWhere(
          (i) => i.productId == domainItem.productId && i.productId.isNotEmpty,
        );

        if (existingIndex != -1) {
          final existing = _items[existingIndex];
          final newQty = existing.qty + domainItem.quantity;
          _items[existingIndex] = existing.copyWith(qty: newQty);
        } else {
          _items.add(
            BillItem(
              productId: domainItem.productId,
              productName: domainItem.name,
              qty: domainItem.quantity,
              price: domainItem.rate,
              unit: domainItem.unit,
              gstRate: 0, // Default
            ),
          );
        }
      }

      // 2. Map Customer (Simplified: Logic to find customer is async, so we do it separate or skip for now)
      // If intent.customerName is present, we could try to find it.

      // 3. Payment Mode
      if (intent.paymentMode != VoicePaymentMode.unknown) {
        if (intent.paymentMode == VoicePaymentMode.credit) {
          _paymentMode = 'Unpaid';
        } else {
          _paymentMode = intent.paymentMode == VoicePaymentMode.online
              ? 'Online'
              : 'Cash';
        }
      }
    });

    _updateRecommendations();
  }

  void _openVoiceAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartVoiceBillSheet(
        onConfirmed: (intent) {
          Navigator.pop(context);
          _applyVoiceIntent(intent);
        },
      ),
    );
  }

  void _showMandiEntrySheet(Product product, {BillItem? existingItem}) {
    // Mandi Entry Logic: Weight First
    // Retain raw string values for validation (Requirements 8.1–8.5).
    String grossStr =
        existingItem?.grossWeight != null && existingItem!.grossWeight != 0.0
        ? existingItem.grossWeight.toString()
        : '';
    String tareStr =
        existingItem?.tareWeight != null && existingItem!.tareWeight != 0.0
        ? existingItem.tareWeight.toString()
        : '';
    String rateStr = (existingItem?.price ?? product.sellingPrice).toString();
    String commissionStr =
        existingItem?.commission != null && existingItem!.commission != 0.0
        ? existingItem.commission.toString()
        : '';
    String lotId = existingItem?.lotId ?? '';

    // Validation error state — field-specific errors retained until the field
    // is modified (Requirement 15.5).
    Map<String, String> validationErrors = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Compute a preview net weight for display (non-authoritative;
          // the validator computes the real one on confirm).
          final grossPreview = double.tryParse(grossStr) ?? 0.0;
          final tarePreview = double.tryParse(tareStr) ?? 0.0;
          final netPreview = (grossPreview - tarePreview).clamp(
            0.0,
            double.infinity,
          );

          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Entry for ${product.name}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: lotId,
                        decoration: const InputDecoration(
                          labelText: "Lot ID (Optional)",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => lotId = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: commissionStr,
                        decoration: InputDecoration(
                          labelText: "Commission (₹)",
                          border: const OutlineInputBorder(),
                          errorText: validationErrors['commission'],
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) {
                          commissionStr = v;
                          // Clear field-specific error on modification
                          if (validationErrors.containsKey('commission')) {
                            validationErrors.remove('commission');
                            setSheetState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: grossStr,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: "Gross Wt (Kg)",
                          border: const OutlineInputBorder(),
                          errorText: validationErrors['gross weight'],
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) {
                          grossStr = v;
                          if (validationErrors.containsKey('gross weight')) {
                            validationErrors.remove('gross weight');
                          }
                          // Sale amount depends on gross weight; clear its
                          // error when the user modifies this field (R15.5).
                          validationErrors.remove('sale amount');
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: tareStr,
                        decoration: InputDecoration(
                          labelText: "Tare Wt (Kg)",
                          border: const OutlineInputBorder(),
                          errorText: validationErrors['tare weight'],
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (v) {
                          tareStr = v;
                          if (validationErrors.containsKey('tare weight')) {
                            validationErrors.remove('tare weight');
                          }
                          // Sale amount depends on tare weight; clear its
                          // error when the user modifies this field (R15.5).
                          validationErrors.remove('sale amount');
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Net Weight: ${netPreview.toStringAsFixed(2)} Kg",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: rateStr,
                  decoration: InputDecoration(
                    labelText: "Rate (₹/Kg)",
                    border: const OutlineInputBorder(),
                    errorText: validationErrors['rate'],
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) {
                    rateStr = v;
                    if (validationErrors.containsKey('rate')) {
                      validationErrors.remove('rate');
                    }
                    // Sale amount depends on rate; clear its error when the
                    // user modifies this field (R15.5).
                    validationErrors.remove('sale amount');
                    setSheetState(() {});
                  },
                ),
                // Show sale amount error below rate if present
                if (validationErrors.containsKey('sale amount'))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      validationErrors['sale amount']!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    // Validate using MandiSaleValidator (Requirements 8.1–8.5)
                    final result = MandiSaleValidator.validate(
                      grossStr: grossStr,
                      tareStr: tareStr,
                      rateStr: rateStr,
                      commissionStr: commissionStr.isEmpty
                          ? '0'
                          : commissionStr,
                    );

                    if (result.isInvalid) {
                      final failure = result as MandiSaleValidationFailure;
                      // Retain entered values; show field-specific errors.
                      validationErrors = Map<String, String>.from(
                        failure.errors,
                      );
                      setSheetState(() {});
                      return;
                    }

                    final success = result as MandiSaleValidationSuccess;

                    // Validation passed — save item
                    setState(() {
                      if (existingItem != null) {
                        _items.removeWhere(
                          (i) => i.productId == existingItem.productId,
                        );
                      }

                      _items.add(
                        BillItem(
                          productId: product.id,
                          productName: product.name,
                          qty: success.netWeight, // For Mandi, Qty = Net Weight
                          price: success.rate,
                          unit: 'kg',
                          grossWeight: success.gross,
                          tareWeight: success.tare,
                          netWeight: success.netWeight,
                          commission: success.commission,
                          lotId: lotId,
                          gstRate: 0, // Mandi usually exempt
                        ),
                      );
                    });
                    _updateRecommendations();
                    Navigator.pop(ctx);
                  },
                  child: const Text("Add to Bill"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // GROCERY LOOSE-WEIGHT (kg/gm) ENTRY — wires WeighingScaleWidget into billing
  // ==========================================================================

  /// True when [unit] is a weight-based unit that grocery's configured
  /// `unitOptions` (pcs, kg, gm, ltr, nos) actually offers. Grocery config is
  /// the single source of truth for when the scale entry applies.
  bool _isGroceryWeightUnit(String unit) {
    final config = BusinessTypeRegistry.getConfig(BusinessType.grocery);
    final u = unit.trim().toLowerCase();
    UnitType? matched;
    if (u == 'kg' || u == 'kgs' || u == 'kilogram' || u == 'kilograms') {
      matched = UnitType.kg;
    } else if (u == 'g' ||
        u == 'gm' ||
        u == 'gms' ||
        u == 'gram' ||
        u == 'grams') {
      matched = UnitType.gm;
    }
    if (matched == null) return false;
    return config.unitOptions.contains(matched);
  }

  /// Presents the [WeighingScaleWidget] for a grocery loose-weight product and,
  /// on confirmation, adds a bill line via the standard add-line-item path.
  void _showGroceryWeightSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: WeighingScaleWidget(
            productName: product.name,
            pricePerKg: product.sellingPrice, // rate per kg
            onWeightConfirmed: (weight, unit, tare) {
              Navigator.pop(ctx);
              _addWeighedGroceryItem(product, weight, tare);
            },
          ),
        ),
      ),
    );
  }

  /// Adds a weighed grocery line item using the SAME computation the manual /
  /// product-search path uses: quantity = net weight (kg), unit price = rate
  /// per kg, line total = weight × rate, GST from the per-product `taxRate`
  /// (NOT the config defaultGstRate), split into equal CGST/SGST halves.
  ///
  /// [netWeightKg] is the net weight the scale reports (always kilograms).
  void _addWeighedGroceryItem(
    Product product,
    double netWeightKg,
    double tareKg,
  ) {
    if (netWeightKg <= 0) return;

    final double qty = netWeightKg; // weight as quantity (kg)
    final double price = product.sellingPrice; // rate per kg
    final double taxRate = product.taxRate; // per-product GST
    // Mirror the existing line-item tax math: half-GST each side on the
    // per-unit taxable base, scaled by quantity (price - perUnitDiscount; no
    // discount on a weighed entry).
    final double halfGst = qty * (price * (taxRate / 200));

    setState(() {
      final existingIndex = _items.indexWhere((i) => i.productId == product.id);
      if (existingIndex != -1) {
        // Accumulate onto the existing weighed line.
        final existing = _items[existingIndex];
        final double newQty = existing.qty + qty;
        final double newHalfGst =
            newQty * (existing.price * (existing.gstRate / 200));
        _items[existingIndex] = existing.copyWith(
          qty: newQty,
          cgst: newHalfGst,
          sgst: newHalfGst,
          netWeight: newQty,
        );
      } else {
        _items.add(
          BillItem(
            productId: product.id,
            productName: product.name,
            qty: qty,
            price: price,
            unit: 'kg',
            gstRate: taxRate,
            cgst: halfGst,
            sgst: halfGst,
            netWeight: qty,
            size: product.size,
            color: product.color,
          ),
        );
      }
    });

    _updateRecommendations();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _itemSearchFocusNode.requestFocus();
    });
  }

  // ... UI Build methods

  Widget _buildItemsList(AppColorPalette palette, bool isDark) {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Insert Empty State Recommendations here if desired
            if (_recommendations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildSmartSuggestions(palette, isDark),
              ),

            // Using EmptyStateWidget
            EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No items added yet',
              description: 'Start adding products to create a bill',
            ),
            const SizedBox(height: 24),
            EnterpriseButton(
              label: 'Add Items',
              icon: Icons.add,
              onPressed: _showProductSearch,
              backgroundColor: FuturisticColors.primary,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _handleBarcodeScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Component'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FuturisticColors.primary,
                side: BorderSide(color: FuturisticColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _handleCameraOcr,
              icon: const Icon(Icons.camera_alt, size: 20),
              label: const Text("Camera OCR"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // AI SMART SUGGESTIONS
        if (_recommendations.isNotEmpty)
          _buildSmartSuggestions(palette, isDark),

        Expanded(
          child: ListView.builder(
            itemCount: _items.length + 1,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32),
                    child: TextButton.icon(
                      onPressed: _showProductSearch,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: FuturisticColors.primary,
                      ),
                      label: Text(
                        'Add More Items',
                        style: TextStyle(color: FuturisticColors.primary),
                      ),
                    ),
                  ),
                );
              }
              // Add a handy Scan Button as the very first item (index -1 effectively, but logically here)
              // Actually, better to have a floating action button or header?
              // Let's stick to the "Add More" area or maybe a persistent FAB?
              // For now, let's put it next to Add More in a Row
              if (index == _items.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _showProductSearch,
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: FuturisticColors.primary,
                          ),
                          label: Text(
                            'Add Items',
                            style: TextStyle(color: FuturisticColors.primary),
                          ),
                        ),
                        const SizedBox(width: 20),
                        TextButton.icon(
                          onPressed: _handleBarcodeScan,
                          icon: Icon(
                            Icons.qr_code_scanner,
                            color: FuturisticColors.secondary,
                          ),
                          label: Text(
                            'Scan',
                            style: TextStyle(color: FuturisticColors.secondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: _handleCameraOcr,
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.blueGrey,
                          ),
                          tooltip: 'OCR',
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = _items[index];
              return _buildItemCard(item, index, palette, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSmartSuggestions(AppColorPalette palette, bool isDark) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendations.length,
        itemBuilder: (context, index) {
          final product = _recommendations[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.amber,
              ),
              label: Text("Add ${product.name}"),
              backgroundColor: isDark
                  ? Colors.white10
                  : Colors.blue.withValues(alpha: 0.05),
              side: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
              labelStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.blue[800],
              ),
              onPressed: () {
                _addItem(product);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(
    BillItem item,
    int index,
    AppColorPalette palette,
    bool isDark,
  ) {
    final businessType = ref.watch(businessTypeProvider).type;
    return AdaptiveItemCard(
      item: item,
      index: index,
      businessType: businessType,
      isDarkMode: isDark,
      accentColor: FuturisticColors.primary,
      onUpdate: (updatedItem) {
        // MRP ceiling enforcement at line-item price entry (R8.1–R8.2):
        // pharmacy line items may not be sold above their MRP. On violation we
        // block the change, retain the previously valid price (by not applying
        // the update), and surface a message naming the item and its MRP.
        if (businessType == BusinessType.pharmacy) {
          final mrpPaise = _mrpPaiseByProductId[updatedItem.productId];
          final sellingPaise = Paise.fromRupees(updatedItem.price);
          if (!MrpEnforcementValidator.isMrpCompliant(sellingPaise, mrpPaise)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${updatedItem.productName} priced at '
                  '₹${Paise.toDisplay(sellingPaise)} exceeds its MRP of '
                  '₹${Paise.toDisplay(mrpPaise!)}.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            // Rebuild so the card reflects the retained (prior valid) line item.
            setState(() {});
            return;
          }
        }
        setState(() => _items[index] = updatedItem);
        _updateRecommendations();
      },
      onRemove: () {
        setState(() => _items.removeAt(index));
        _updateRecommendations();
      },
    );
  }

  Future<void> _handleBarcodeScan() async {
    final businessType = ref.read(businessTypeProvider).type;
    final capabilities = BusinessCapabilities.get(businessType);

    if (!capabilities.supportsBarcodeScan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcode scanning not enabled for this business type'),
        ),
      );
      return;
    }

    final barcode = await sl<BarcodeScannerService>().scanBarcode(context);
    if (barcode == null) return; // User cancelled or failed

    setState(() => _isLoading = true);
    try {
      final ownerId = _session.ownerId;
      if (ownerId == null) throw Exception('User not logged in');

      // 1. Search for product
      // We need to access ProductsRepository directly to search by barcode
      // The current _addItem method takes a Product object
      final products = await sl<ProductsRepository>().search(
        barcode,
        userId: ownerId,
      );

      if (products.data != null && products.data!.isNotEmpty) {
        // Exact match found!
        // If multiple found (rare but possible with exact match on name vs barcode), pick first exact barcode match
        final exactMatch = products.data!.firstWhere(
          (p) => p.barcode == barcode || p.altBarcodes.contains(barcode),
          orElse: () => products.data!.first,
        );

        _addItem(exactMatch);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added ${exactMatch.name}')));
      } else {
        // 2. Not found -> Prompt to Add
        if (mounted) {
          _showProductNotFoundDialog(barcode);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error scanning: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCameraOcr() async {
    final businessType = ref.read(businessTypeProvider).type;
    final capabilities = BusinessCapabilities.get(businessType);

    if (!capabilities.supportsTextOCR) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR not enabled for this business type')),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) return;

      setState(() => _isLoading = true);

      final router = sl<OcrRouter>();
      final result = await router.processForBusinessType(
        imagePath: image.path,
        businessType: businessType.name, // Enum to string
      );

      if (mounted) {
        _showOcrResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOcrResultDialog(OcrRouterResult result) {
    // Extract best guess for name and price
    final parsed = result.parsedResult ?? {};
    String name = parsed['detectedName'] ?? '';
    double price = parsed['detectedPrice'] ?? 0.0;

    // Pharmacy specifics
    String? batch =
        result.medicineResult?.batchNumber; // or result.parsedResult['batchNo']
    String? expiry = result.medicineResult?.expiryDate
        ?.toString(); // Simplify date format later

    if (!result.isPharmacyType) {
      batch = parsed['batchNo'];
      expiry = parsed['expiryDate'];
    }

    final nameController = TextEditingController(text: name);
    final priceController = TextEditingController(
      text: price > 0 ? price.toString() : '',
    );
    final qtyController = TextEditingController(text: '1');
    // ... add more controllers for other fields if needed

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OCR Result'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              if (result.isPharmacyType || batch != null) ...[
                const SizedBox(height: 8),
                Text('Batch: $batch \nExpiry: $expiry'),
              ],
              const SizedBox(height: 10),
              if (result.genericResult.rawText.isNotEmpty)
                ExpansionTile(
                  title: const Text('View Raw Text'),
                  children: [
                    Text(
                      result.genericResult.rawText,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // 4d (Req 7.4): respect the business config instead of hardcoded
              // `unit:'pcs'` / `gstRate:0`. The unit defaults from the active
              // business type's configured unitOptions (grocery →
              // pcs/kg/gm/ltr/nos, defaulting to pcs); when the entered name
              // matches an existing product, inherit that product's own unit
              // and tax rate (split into equal CGST/SGST halves) rather than
              // always zeroing GST.
              final businessType = ref.read(businessTypeProvider).type;
              final enteredName = nameController.text.trim();
              final qty = double.tryParse(qtyController.text) ?? 1;
              final price = double.tryParse(priceController.text) ?? 0;

              final matched = await _findProductByName(enteredName);
              final double gstRate = matched?.taxRate ?? 0;
              final double taxableBase = qty * price;
              final double halfGst = taxableBase * (gstRate / 200);
              final String unit =
                  matched?.unit ?? _defaultManualUnit(businessType);

              final newItem = BillItem(
                productId: '', // No ID for ad-hoc OCR items
                productName: enteredName,
                qty: qty,
                price: price,
                unit: unit,
                gstRate: gstRate,
                cgst: halfGst,
                sgst: halfGst,
              );

              if (!mounted) return;
              setState(() => _items.add(newItem));
              Navigator.pop(ctx);
              _updateRecommendations();
            },
            child: const Text('Add to Bill'),
          ),
        ],
      ),
    );
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Text(
          'No product found for barcode: $barcode.\nDo you want to add it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Open Manual Entry but pre-fill barcode if we had a field (ManualItemEntrySheet might need update)
              // For now, just open manual entry
              _showManualItemEntry();
              //Ideally pass barcode to pre-fill
            },
            child: const Text('Add Manually'),
          ),
        ],
      ),
    );
  }

  void _showProductSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSearchSheet(
        onProductSelected: _addItem,
        onManualEntry: _showManualItemEntry,
      ),
    );
  }

  /// Pharmacy salt/substitute search embedded in billing (Requirement 25).
  ///
  /// Opens [SaltSearchScreen] wired with its `onProductSelected` callback
  /// (R25.1). When a branded alternative is selected, the screen is closed and
  /// the chosen product is routed through [_addItem] — which adds a new line at
  /// quantity 1, or increments the existing matching line, and recomputes the
  /// bill total via its setState-driven getters (R25.2, R25.3, R25.5). If the
  /// pharmacist dismisses the screen without selecting (back navigation), the
  /// route resolves to `null` and the current bill is left unchanged (R25.4).
  ///
  /// This action is invoked only from the pharmacy-gated UI, so the other
  /// verticals are unaffected.
  Future<void> _showSaltSearch() async {
    final selected = await Navigator.of(context).push<BrandedAlternative>(
      MaterialPageRoute(
        builder: (sheetContext) => SaltSearchScreen(
          onProductSelected: (brand) => Navigator.of(sheetContext).pop(brand),
        ),
      ),
    );

    // Dismissed without a selection — leave the bill untouched (R25.4).
    if (selected == null || !mounted) return;

    await _addItem(_brandedAlternativeToProduct(selected));
  }

  /// Adapt a salt-search [BrandedAlternative] into the billing [Product] shape
  /// so substitute selection reuses the standard add-line-item path (FEFO batch
  /// selection, prescription gate, MRP ceiling, and total recalculation).
  Product _brandedAlternativeToProduct(BrandedAlternative brand) {
    final now = DateTime.now();
    return Product(
      id: brand.productId,
      userId: _session.ownerId ?? '',
      name: brand.productName,
      sellingPrice: brand.mrp ?? 0,
      stockQuantity: brand.stockQuantity,
      brand: brand.manufacturer,
      drugSchedule: brand.drugSchedule,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Show manual item entry sheet
  void _showManualItemEntry() {
    final businessType = ref.read(businessTypeProvider).type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualItemEntrySheet(
        businessType: businessType,
        onItemAdded: (item) async {
          // 4d (Req 7.4): when the manually entered item matches an existing
          // product and the user left GST at 0, inherit the product's own tax
          // rate (split into equal CGST/SGST halves) instead of zeroing it.
          // A user-entered GST is always respected.
          BillItem finalItem = item;
          if (item.gstRate == 0) {
            final matched = await _findProductByName(item.productName);
            if (matched != null && matched.taxRate > 0) {
              final double taxableBase =
                  (item.qty * item.price) - item.discount;
              final double halfGst = taxableBase * (matched.taxRate / 200);
              finalItem = item.copyWith(
                gstRate: matched.taxRate,
                cgst: halfGst,
                sgst: halfGst,
              );
            }
          }

          if (!mounted) return;
          setState(() {
            // Check if we need to merge with existing item (by name)
            // For manual entry, we usually treat them as distinct unless name matches exactly
            final existingIndex = _items.indexWhere(
              (i) =>
                  i.productId.isEmpty && i.productName == finalItem.productName,
            );

            if (existingIndex != -1) {
              final existing = _items[existingIndex];
              _items[existingIndex] = existing.copyWith(
                qty: existing.qty + finalItem.qty,
                // Business specific fields logic: if new item has them, overwrite or merge?
                // Simple strategy: Overwrite for now
                batchNo: finalItem.batchNo,
                expiryDate: finalItem.expiryDate,
                serialNo: finalItem.serialNo,
                warrantyMonths: finalItem.warrantyMonths,
                size: finalItem.size,
                color: finalItem.color,
              );
            } else {
              _items.add(finalItem);
            }
          });
          _updateRecommendations();
        },
      ),
    );
  }

  /// Looks up an existing product by an exact (case-insensitive) name match so
  /// a manually entered / OCR ad-hoc line can inherit the product's own unit
  /// and tax rate. Returns null when there is no confident exact-name match.
  Future<Product?> _findProductByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final ownerId = _session.ownerId;
    if (ownerId == null) return null;

    final result = await sl<ProductsRepository>().search(
      trimmed,
      userId: ownerId,
    );
    final matches = result.data ?? const <Product>[];
    for (final p in matches) {
      if (p.name.trim().toLowerCase() == trimmed.toLowerCase()) return p;
    }
    return null;
  }

  /// Default unit for a manually entered line. Grocery sources the default from
  /// its configured `unitOptions` (pcs, kg, gm, ltr, nos — defaulting to the
  /// first, pcs); other business types keep the legacy 'pcs' default so their
  /// behavior is unchanged.
  String _defaultManualUnit(BusinessType businessType) {
    if (businessType == BusinessType.grocery) {
      final config = BusinessTypeRegistry.getConfig(businessType);
      if (config.unitOptions.isNotEmpty) {
        return config.unitOptions.first.label.toLowerCase();
      }
    }
    return 'pcs';
  }

  Widget _buildSummaryFooter(AppColorPalette palette, bool isDark) {
    return GlassContainer(
      borderRadius: 30,
      padding: const EdgeInsets.all(24),
      blur: 20,
      opacity: 0.1,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items',
                  style: GoogleFonts.inter(
                    color: FuturisticColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${_items.length}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: FuturisticColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Happy Hour indicator — restaurant only (mobile footer)
            if (_isRestaurantBill && _isHappyHourActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.15),
                      Colors.orange.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'Happy Hour! ${_happyHourDiscountPercent.toStringAsFixed(0)}% off',
                          style: GoogleFonts.inter(
                            color: Colors.amber.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '-₹${_happyHourDiscountTotal.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: Colors.amber.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Checkbox(
                            value: _happyHourEnabled,
                            onChanged: (v) => _toggleHappyHour(v ?? false),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: Colors.amber.shade600),
                            activeColor: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Service Charge row — restaurant dine-in only (mobile footer)
            if (_isRestaurantBill && _isRestaurantDineIn) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Service (${_serviceChargePercent.toStringAsFixed(0)}%)',
                        style: GoogleFonts.inter(
                          color: FuturisticColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: _serviceChargeEnabled,
                          onChanged: (v) =>
                              setState(() => _serviceChargeEnabled = v ?? true),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(
                            color: FuturisticColors.textSecondary,
                          ),
                          activeColor: FuturisticColors.primary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showServiceChargeEditor,
                    child: Text(
                      '₹${_serviceChargeAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grand Total',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: FuturisticColors.textPrimary,
                  ),
                ),
                Text(
                  '₹${_grandTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: FuturisticColors.success,
                  ),
                ),
              ],
            ),
            // Tip input — restaurant only (shown after grand total, not included in taxable subtotal)
            if (_isRestaurantBill) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.volunteer_activism,
                    size: 16,
                    color: FuturisticColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tip (optional)',
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 100,
                    height: 32,
                    child: TextField(
                      controller: _tipController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: GoogleFonts.inter(
                          color: FuturisticColors.textSecondary,
                          fontSize: 13,
                        ),
                        hintText: '0',
                        hintStyle: GoogleFonts.inter(
                          color: FuturisticColors.textSecondary.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 13,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: FuturisticColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: FuturisticColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: FuturisticColors.primary,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _tipAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // Split Bill action — restaurant only
            if (_isRestaurantBill) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _items.isEmpty ? null : _showSplitBillDialog,
                  icon: const Icon(Icons.call_split, size: 18),
                  label: const Text('Split Bill'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FuturisticColors.primary,
                    side: BorderSide(
                      color: FuturisticColors.primary.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Send Email Toggle
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ), // Compact padding
              decoration: BoxDecoration(
                color: _sendEmail
                    ? FuturisticColors.primary.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _sendEmail
                      ? FuturisticColors.primary.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  "Send Invoice via Email",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: _sendEmail
                    ? Text(
                        GmailService().userEmail ?? "Connected via Gmail",
                        style: TextStyle(
                          color: FuturisticColors.primary,
                          fontSize: 11,
                        ),
                      )
                    : const Text(
                        "Requires Gmail Sign-in",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                value: _sendEmail,
                onChanged: (val) async {
                  if (val) {
                    final gmail = GmailService();
                    if (!await gmail.isAuthenticated()) {
                      try {
                        setState(() => _isLoading = true);
                        await gmail.signIn();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Gmail Connected!")),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to connect Gmail: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return; // Do not enable if failed
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  }
                  setState(() => _sendEmail = val);
                },
                activeColor: FuturisticColors.primary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),

            // Payment Mode Selection
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _PaymentModeChip(
                      label: 'Cash',
                      icon: Icons.money,
                      isSelected: _paymentMode == 'Cash',
                      onTap: () => setState(() => _paymentMode = 'Cash'),
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _PaymentModeChip(
                      label: 'UPI QR',
                      icon: Icons.qr_code_scanner,
                      isSelected: _paymentMode == 'Online',
                      onTap: () => setState(() => _paymentMode = 'Online'),
                      palette: palette,
                    ),
                  ),
                  if (FeatureResolver(
                    ref.read(businessTypeProvider).type,
                  ).showCreditLedger) ...[
                    const SizedBox(width: 4),
                    Expanded(
                      child: _PaymentModeChip(
                        label: 'Credit',
                        icon: Icons.book_online,
                        isSelected: _paymentMode == 'Unpaid',
                        onTap: () => setState(() => _paymentMode = 'Unpaid'),
                        palette: palette,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: FuturisticColors.primaryGradient,
                  boxShadow: FuturisticColors.neonShadow(
                    FuturisticColors.primary,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _paymentMode == 'Online'
                            ? 'PAY & GENERATE'
                            : 'GENERATE BILL',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ShortcutPill(
                        shortcut: 'Ctrl+S',
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    // DEBOUNCE: Prevent duplicate saves during async operation
    if (_isLoading) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    // Use Walk-in customer as fallback - allow billing without customer database
    // This is CRITICAL for kirana stores, hardware shops, etc.
    _selectedCustomer ??= _walkInCustomer;

    // Validate item quantities > 0
    if (_items.any((item) => item.qty <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items must have quantity > 0')),
      );
      return;
    }

    // Validate item prices > 0
    final zeroPriceItems = _items.where((item) => item.price <= 0).toList();
    if (zeroPriceItems.isNotEmpty) {
      final itemNames = zeroPriceItems.map((i) => i.productName).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Items with zero/negative price: $itemNames'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'PROCEED ANYWAY',
            textColor: Colors.white,
            onPressed: () {
              // Continue with save - this will be handled by the outer function
              // We need to use a flag to bypass this check
            },
          ),
        ),
      );
      // For now, block zero price sales
      return;
    }

    // Pharmacy: block save while a scheduled-drug line has no captured
    // prescription (R7.1). The gate normally captures the id at add-time; this
    // is the save-time guard that keeps an unresolved scheduled sale unsaved.
    final saveBusinessType = ref.read(businessTypeProvider).type;
    if (saveBusinessType == BusinessType.pharmacy) {
      final scheduledItems = _items.where((item) {
        final schedule = DrugScheduleResolver.fromRaw(item.drugSchedule);
        return DrugScheduleResolver.isScheduled(schedule);
      }).toList();
      final hasPrescription =
          _prescriptionId != null && _prescriptionId!.trim().isNotEmpty;
      if (scheduledItems.isNotEmpty && !hasPrescription) {
        final names = scheduledItems.map((i) => i.productName).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prescription required before saving scheduled drug(s): $names',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // Stock availability check
    final ownerId = _session.ownerId;
    if (ownerId != null) {
      final businessType = ref.read(businessTypeProvider).type;
      final isPharmacy = businessType == BusinessType.pharmacy;
      final blockedItems = <String>[];
      final lowStockItems = <String>[];
      for (final item in _items) {
        if (item.productId.isEmpty) continue;
        final result = await sl<ProductsRepository>().getById(item.productId);
        final product = result.data;
        if (product != null && product.stockQuantity < item.qty) {
          final desc =
              '${item.productName} (available: ${product.stockQuantity.toStringAsFixed(0)}, requested: ${item.qty.toStringAsFixed(0)})';
          if (isPharmacy) {
            blockedItems.add(desc);
          } else {
            lowStockItems.add(desc);
          }
        }
      }
      // Pharmacy: hard block — cannot sell what doesn't exist
      if (blockedItems.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Insufficient Stock — Sale Blocked'),
            content: Text(
              'The following items have zero or insufficient stock.\n'
              'Dispensing is not allowed until stock is replenished:\n\n'
              '${blockedItems.join('\n')}',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return; // Hard stop
      }
      // Non-pharmacy: soft warn
      if (lowStockItems.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Low Stock Warning'),
            content: Text(
              'The following items have insufficient stock:\n\n${lowStockItems.join('\n')}\n\nProceed anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Proceed'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      // FIFO Batch Warning — warn if item has multiple batches but no batch selected
      // Prevents selling from a later (newer) batch while older stock exists.
      final unbatchedMultiBatchItems = <String>[];
      final db = AppDatabase.instance;
      if (isPharmacy) {
        // Pharmacy: batched FEFO retrieval (Requirement 21). Adding/saving a
        // bill with 2+ items must not issue one DB round-trip per item. Collect
        // every unbatched item and fetch all their batches in a single bulk
        // PharmacyDao query (bounded round-trip count, R21.1). On retrieval
        // failure, reject the operation and preserve the prior bill state
        // without adding partial batch data (R21.3).
        final pharmacyItems = _items
            .where((i) => i.productId.isNotEmpty && i.batchNo == null)
            .toList();
        if (pharmacyItems.isNotEmpty) {
          final Map<String, List<ProductBatchEntity>> batchesByProduct;
          try {
            final dao = PharmacyDao(db);
            batchesByProduct = await dao.getBatchesForProducts(
              ownerId,
              pharmacyItems.map((i) => i.productId).toList(),
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Batch data retrieval failed. The bill was not saved — '
                    'please try again.',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return; // Reject; prior bill state is left unchanged (R21.3).
          }
          for (final item in pharmacyItems) {
            // Selection per item matches per-item FEFO (R21.2, R17.4–17.5):
            // defensive expiry-ascending sort, earliest-expiry batch first.
            final batches = _fefoSorted(
              batchesByProduct[item.productId] ?? const [],
            );
            if (batches.length > 1) {
              final oldest = batches.first;
              unbatchedMultiBatchItems.add(
                '${item.productName} — oldest batch: ${oldest.batchNumber} (expires ${oldest.expiryDate?.toLocal().toString().split(' ').first ?? 'N/A'})',
              );
            }
          }
        }
      } else {
        for (final item in _items) {
          if (item.productId.isEmpty || item.batchNo != null) continue;
          final batches =
              await (db.select(db.productBatches)..where(
                    (t) =>
                        t.productId.equals(item.productId) &
                        t.stockQuantity.isBiggerThanValue(0.0) &
                        t.status.equals('ACTIVE'),
                  ))
                  .get();
          if (batches.length > 1) {
            final oldest =
                (batches..sort((a, b) {
                      final aExp = a.expiryDate;
                      final bExp = b.expiryDate;
                      if (aExp == null && bExp == null) return 0;
                      if (aExp == null) return 1;
                      if (bExp == null) return -1;
                      return aExp.compareTo(bExp);
                    }))
                    .first;
            unbatchedMultiBatchItems.add(
              '${item.productName} — oldest batch: ${oldest.batchNumber} (expires ${oldest.expiryDate?.toLocal().toString().split(' ').first ?? 'N/A'})',
            );
          }
        }
      }
      if (unbatchedMultiBatchItems.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('FIFO Batch Warning'),
            content: Text(
              'These items have multiple batches in stock. Oldest batch should be sold first:\n\n'
              '${unbatchedMultiBatchItems.join('\n')}\n\n'
              'No batch is selected on the bill. Proceed anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Go Back & Select Batch'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Proceed Without Batch'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    // Dynamic QR Flow
    final tempBillId = const Uuid().v4();
    if (_paymentMode == 'Online') {
      final success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PaymentQrDialog(
          billId: tempBillId,
          amount: _grandTotal,
          customerName: _selectedCustomer!.name,
        ),
      );

      if (success != true) {
        // Payment cancelled or failed
        return;
      }
      // If success, proceed to save as PAID
    }

    setState(() => _isLoading = true);

    try {
      final ownerId = _session.ownerId;
      if (ownerId == null) throw Exception('User not logged in');

      final newBill = Bill(
        id: tempBillId, // Use the same ID generated for QR
        ownerId: ownerId,
        invoiceNumber: _invoiceNumber,
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        customerPhone: _selectedCustomer!.phone ?? '',
        customerEmail: _selectedCustomer!.email, // Populate Email
        date: DateTime.now(),
        items: _items
            .map(
              (e) => BillItem(
                productId: e.productId,
                productName: e.productName,
                qty: e.quantity,
                price: e.unitPrice,
                unit: e.unit,
                hsn: e.hsn,
                gstRate: e.gstRate,
                cgst: e.cgst,
                sgst: e.sgst,
                igst: e.igst,
                discount: e.discount,
                // Copy business specific fields if needed
                batchNo: e.batchNo,
                expiryDate: e.expiryDate,
              ),
            )
            .toList(),
        subtotal: _subtotal,
        discountApplied: _items.fold(0.0, (sum, item) => sum + item.discount),
        grandTotal: _grandTotal,
        paidAmount:
            _paidAmount, // This is calculated via get _paidAmount which checks _paymentMode
        cashPaid: _paymentMode == 'Cash' ? _paidAmount : 0,
        onlinePaid: _paymentMode == 'Online' ? _paidAmount : 0,
        status: _paidAmount >= _grandTotal ? 'Paid' : 'Unpaid',
        paymentType: _paymentMode,
        prescriptionId: _prescriptionId,
        // Business Specific Headers
        tableNumber: _headerBill.tableNumber,
        waiterId: _headerBill.waiterId,
        vehicleNumber: _headerBill.vehicleNumber,
        driverName: _headerBill.driverName,
        fuelType: _headerBill.fuelType,
        // Hardware Transport Details
        // Note: lrNumber, transporterName, ewayBillNumber, transportMode
        // stored in header metadata, not directly on Bill
        // Mandi Logic
        brokerId: _selectedFarmer?.id, // Mapping Farmer ID to brokerId field
        commissionAmount: _items.fold(
          0,
          (sum, item) => sum + (item.commission ?? 0),
        ),
        // Restaurant service charge (dine-in only)
        serviceCharge: (_isRestaurantBill && _isRestaurantDineIn)
            ? _serviceChargeAmount
            : 0.0,
        // Restaurant tip (optional, not included in taxable subtotal or GST)
        tipAmount: _isRestaurantBill ? _tipAmount : 0.0,
      );

      await _billsRepo.createBill(newBill);

      // Invalidate dashboard KPI providers so revenue/sales update immediately
      ref.invalidate(dashboardV2SummaryProvider);
      ref.invalidate(dashboardV2RevenueChartProvider);

      // Link to Service Job if applicable
      if (widget.serviceJobId != null) {
        try {
          final serviceJobService = ServiceJobService(AppDatabase.instance);
          await serviceJobService.linkBillToJob(
            widget.serviceJobId!,
            tempBillId,
            userId: ownerId,
          );
        } catch (e) {
          debugPrint("Failed to link bill to service job: $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill generated successfully!')),
        );

        // --- EMAIL INTEGRATION ---
        if (_sendEmail) {
          try {
            // 1. Prepare Data for PDF
            // Note: Images are passed as null for speed/simplicity initially
            final invoiceConfig = InvoiceConfig(
              shopName: newBill.shopName,
              ownerName: _session.currentSession.displayName ?? '',
              address: newBill.shopAddress,
              mobile: newBill.shopContact,
              gstin: newBill.shopGst,
              email: _session.currentSession.email,
              isGstBill: newBill.totalTax > 0,
              showTax: newBill.totalTax > 0,
            );

            final invoiceCustomer = InvoiceCustomer(
              name: newBill.customerName,
              mobile: newBill.customerPhone,
              address: newBill.customerAddress,
              gstin: newBill.customerGst,
            );

            final invoiceItems = newBill.items
                .map(
                  (i) => InvoiceItem(
                    name: i.productName,
                    quantity: i.qty,
                    unit: i.unit,
                    unitPrice: i.price,
                    taxPercent: i.gstRate,
                    // Convert per-item discount amount to percent for PDF rendering
                    discountPercent: (i.price > 0 && i.qty > 0)
                        ? ((i.discount / i.qty) / i.price) * 100
                        : 0.0,
                  ),
                )
                .toList();

            // 2. Generate PDF
            final pdfBytes = await InvoicePdfService().generateInvoicePdf(
              config: invoiceConfig,
              customer: invoiceCustomer,
              items: invoiceItems,
              invoiceNumber: newBill.invoiceNumber,
              invoiceDate: newBill.date,
              discount: newBill.totalDiscount,
            );

            // 3. Send Email
            await EmailRepository().sendInvoiceEmail(
              pdfBytes: pdfBytes,
              bill:
                  newBill, // Using newBill which has customerEmail (if customer had it)
              // Wait, newBill was created using _selectedCustomer!.id etc.
              // Does newBill have customerEmail? I added it to Bill model.
              // I need to populate it in newBill constructor above!
              businessName: newBill.shopName,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invoice sent via Email!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            debugPrint("Email sending failed: $e");
            if (mounted) {
              // Non-blocking error
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Bill saved, but Email failed: $e'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
        // -------------------------

        // Navigate to Invoice Preview instead of just popping
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InvoicePreviewScreen(bill: newBill),
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
    // Listen for keyboard intents (Ctrl+S, Ctrl+A, etc.)
    ref.listen<KeyboardIntentState>(keyboardIntentProvider, (previous, next) {
      if (next.lastIntent != previous?.lastIntent && next.lastIntent != null) {
        _handleKeyboardIntent(next);
      }
    });

    if (MediaQuery.of(context).size.width > 900) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  // ===========================================================================
  // DESKTOP LAYOUT
  // ===========================================================================
  Widget _buildDesktopLayout() {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;

    return DesktopContentContainer(
      // POS needs full screen space
      maxWidth: double.infinity,
      padding: EdgeInsets.zero,
      showScrollbar: false,
      child: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(
            gradient: FuturisticColors.darkBackgroundGradient,
          ),
          child: Row(
            children: [
              // LEFT PANEL: Product Selection (60%)
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildDesktopHeader(isDark),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildDesktopProductBrowser(palette, isDark),
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT PANEL: Cart & Checkout (40%)
              Expanded(
                flex: 4,
                child: GlassContainer(
                  margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  borderRadius: 24,
                  child: Column(
                    children: [
                      _buildDesktopCustomerSection(isDark),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      // Adaptive Header (Table No, etc.)
                      AdaptiveBillHeader(
                        businessType: ref.watch(businessTypeProvider).type,
                        bill: _headerBill,
                        onUpdate: (updated) =>
                            setState(() => _headerBill = updated),
                        isDark: isDark,
                      ),
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      Expanded(child: _buildDesktopCartList(isDark)),
                      _buildDesktopCheckoutSection(isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 16,
      child: Row(
        children: [
          Icon(Icons.search, color: FuturisticColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search products (Ctrl+F)",
                hintStyle: GoogleFonts.inter(
                  color: FuturisticColors.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              focusNode: _itemSearchFocusNode,
              style: GoogleFonts.inter(
                color: FuturisticColors.textPrimary,
                fontSize: 16,
              ),
              onTap: _showProductSearch,
            ),
          ),
          Container(
            height: 24,
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner,
              color: FuturisticColors.accent1,
            ),
            onPressed: _handleBarcodeScan,
            tooltip: "Scan Barcode (F2)",
          ),
          IconButton(
            icon: const Icon(Icons.mic, color: FuturisticColors.primary),
            onPressed: _openVoiceAssistant,
            tooltip: "Voice Bill (F3)",
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopProductBrowser(AppColorPalette palette, bool isDark) {
    final businessType = ref.watch(businessTypeProvider).type;
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Quick Suggestions",
                  style: GoogleFonts.outfit(
                    color: FuturisticColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              // Mandi: Show Farmer Selection Button
              if (businessType == BusinessType.vegetablesBroker)
                TextButton.icon(
                  icon: const Icon(Icons.agriculture, size: 16),
                  label: Text(
                    _selectedFarmer?.name ?? "Select Supplier",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _showFarmerSearch,
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),

              TextButton.icon(
                icon: const Icon(Icons.grid_view, size: 16),
                label: const Text("View Catalog"),
                onPressed: _showProductSearch,
                style: TextButton.styleFrom(
                  foregroundColor: FuturisticColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSmartSuggestions(palette, isDark),
          const SizedBox(height: 20),
          // Suggestions and "Add Item" flow
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: FuturisticColors.textSecondary.withValues(
                      alpha: 0.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Ready to Bill",
                    style: GoogleFonts.outfit(
                      color: FuturisticColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Search, Scan or Speak to add items",
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions Grid
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildQuickActionButton(
                        Icons.search,
                        "Search",
                        _showProductSearch,
                      ),
                      _buildQuickActionButton(
                        Icons.qr_code_scanner,
                        "Scan",
                        _handleBarcodeScan,
                      ),
                      _buildQuickActionButton(
                        Icons.mic,
                        "Voice",
                        _openVoiceAssistant,
                      ),
                      _buildQuickActionButton(
                        Icons.edit_note,
                        "Manual",
                        _showManualItemEntry,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: FuturisticColors.accent1, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: FuturisticColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCustomerSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: FuturisticColors.surface,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: FuturisticColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: FuturisticColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCustomer?.name ?? "Walk-in Customer",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _selectedCustomer?.phone ?? "No Phone Linked",
                  style: TextStyle(
                    color: FuturisticColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            focusNode: _customerFocusNode,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CustomerSearchSheet(
                  onCustomerSelected: (c) {
                    setState(() => _selectedCustomer = c);
                    // Move focus to item search after selecting customer
                    Future.delayed(const Duration(milliseconds: 300), () {
                      _itemSearchFocusNode.requestFocus();
                    });
                  },
                ),
              );
            },
            child: const Text("Change (F4)"),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCartList(bool isDark) {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: FuturisticColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "Cart is empty",
              style: TextStyle(color: FuturisticColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final businessType = ref.watch(businessTypeProvider).type;
    final config = BusinessTypeRegistry.getConfig(businessType);
    final showHalfToggle =
        businessType == BusinessType.restaurant &&
        config.optionalFields.contains(ItemField.isHalf);
    final showParcelToggle =
        businessType == BusinessType.restaurant &&
        config.optionalFields.contains(ItemField.isParcel);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FuturisticColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "₹${item.price.toStringAsFixed(1)} / ${item.unit}",
                      style: TextStyle(
                        color: FuturisticColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Half-portion toggle for restaurant
              if (showHalfToggle) ...[
                _HalfPortionChip(
                  isHalf: item.isHalf ?? false,
                  onToggle: () {
                    _toggleHalfPortion(index);
                  },
                  accentColor: FuturisticColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
              ],

              // Parcel/takeaway toggle for restaurant
              if (showParcelToggle) ...[
                _ParcelChip(
                  isParcel: item.isParcel ?? false,
                  onToggle: () {
                    _toggleParcel(index);
                  },
                  accentColor: FuturisticColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
              ],

              // Qty Control
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      size: 20,
                      color: FuturisticColors.textSecondary,
                    ),
                    onPressed: () => _updateQuantity(index, item.qty - 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${item.qty}",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: FuturisticColors.textSecondary,
                    ),
                    onPressed: () => _updateQuantity(index, item.qty + 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(width: 16),
              SizedBox(
                width: 60,
                child: Text(
                  "₹${item.total.toStringAsFixed(0)}",
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Toggles the half-portion flag on a line item and adjusts the price accordingly.
  /// When switching to half, price is halved. When switching back to full, price is doubled.
  void _toggleHalfPortion(int index) {
    setState(() {
      final item = _items[index];
      final currentlyHalf = item.isHalf ?? false;
      final newIsHalf = !currentlyHalf;

      // Adjust price: half the price when toggling ON, double when toggling OFF.
      final newPrice = newIsHalf ? item.price / 2.0 : item.price * 2.0;

      // Recalculate tax on the new price.
      final perUnitDiscount = item.qty > 0 ? item.discount / item.qty : 0.0;
      final taxableBase = (newPrice - perUnitDiscount).clamp(
        0.0,
        double.infinity,
      );
      final halfGst = item.qty * (taxableBase * (item.gstRate / 200));

      _items[index] = item.copyWith(
        isHalf: newIsHalf,
        price: newPrice,
        cgst: halfGst,
        sgst: halfGst,
      );
    });
  }

  /// Toggles the parcel/takeaway flag on a line item.
  void _toggleParcel(int index) {
    setState(() {
      final item = _items[index];
      final currentlyParcel = item.isParcel ?? false;
      _items[index] = item.copyWith(isParcel: !currentlyParcel);
    });
  }

  /// Toggles happy-hour auto-discount. When disabled, removes all happy-hour
  /// discounts from existing items. When re-enabled, applies discounts to
  /// eligible items currently in the bill.
  void _toggleHappyHour(bool enabled) {
    setState(() {
      _happyHourEnabled = enabled;
      if (!enabled) {
        // Remove happy-hour discounts from items that have them.
        for (int i = 0; i < _items.length; i++) {
          final item = _items[i];
          if (item.notes == 'Happy Hour Discount' && item.discount > 0) {
            final taxableBase = item.price; // full price, no discount
            _items[i] = item.copyWith(
              discount: 0.0,
              notes: null,
              cgst: item.qty * (taxableBase * (item.gstRate / 200)),
              sgst: item.qty * (taxableBase * (item.gstRate / 200)),
            );
          }
        }
      } else {
        // Re-apply happy-hour discount to items that don't already have one.
        final isActive = RestaurantBusinessRules.isInHappyHour(
          now: DateTime.now(),
          startHour24: _happyHourStart,
          endHour24: _happyHourEnd,
        );
        if (isActive) {
          for (int i = 0; i < _items.length; i++) {
            final item = _items[i];
            if (item.discount == 0 && item.notes != 'Happy Hour Discount') {
              final perUnitDiscount =
                  item.price * (_happyHourDiscountPercent / 100);
              final taxableBase = (item.price - perUnitDiscount).clamp(
                0.0,
                double.infinity,
              );
              _items[i] = item.copyWith(
                discount: perUnitDiscount * item.qty,
                notes: 'Happy Hour Discount',
                cgst: item.qty * (taxableBase * (item.gstRate / 200)),
                sgst: item.qty * (taxableBase * (item.gstRate / 200)),
              );
            }
          }
        }
      }
    });
  }

  /// Shows a dialog to adjust the service charge percentage for restaurant dine-in bills.
  void _showServiceChargeEditor() {
    final controller = TextEditingController(
      text: _serviceChargePercent.toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Service Charge'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Service Charge %',
            suffixText: '%',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0 && value <= 100) {
                setState(() => _serviceChargePercent = value);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  /// Shows a dialog to split the current bill total among multiple guests.
  /// Informational only — does not create separate bills.
  void _showSplitBillDialog() {
    final controller = TextEditingController(text: '2');
    List<double>? splitAmounts;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Split Bill'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total: ₹${_grandTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of guests',
                    hintText: 'Minimum 2',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  autofocus: true,
                  onChanged: (value) {
                    final count = int.tryParse(value);
                    if (count != null && count >= 2) {
                      setDialogState(() {
                        splitAmounts = RestaurantBusinessRules.splitBill(
                          _grandTotal,
                          count,
                        );
                      });
                    } else {
                      setDialogState(() => splitAmounts = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (splitAmounts != null && splitAmounts!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FuturisticColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FuturisticColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Per Guest:',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...splitAmounts!.asMap().entries.map((entry) {
                          final guestNum = entry.key + 1;
                          final amount = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Guest $guestNum',
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                                Text(
                                  '₹${amount.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ] else if (controller.text.isNotEmpty) ...[
                  Text(
                    'Enter at least 2 guests',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    ).then((_) => controller.dispose());
  }

  Widget _buildDesktopCheckoutSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Subtotal",
                style: GoogleFonts.inter(color: FuturisticColors.textSecondary),
              ),
              Text(
                "₹${_subtotal.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                  color: FuturisticColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tax (GST)",
                style: GoogleFonts.inter(color: FuturisticColors.textSecondary),
              ),
              Text(
                "₹${_totalTax.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                  color: FuturisticColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // Happy Hour indicator — restaurant only (desktop panel)
          if (_isRestaurantBill && _isHappyHourActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.15),
                    Colors.orange.withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        'Happy Hour! ${_happyHourDiscountPercent.toStringAsFixed(0)}% off',
                        style: GoogleFonts.inter(
                          color: Colors.amber.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '-₹${_happyHourDiscountTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          color: Colors.amber.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _happyHourEnabled,
                          onChanged: (v) => _toggleHappyHour(v ?? false),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: Colors.amber.shade600),
                          activeColor: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // Service Charge row — restaurant dine-in only
          if (_isRestaurantBill && _isRestaurantDineIn) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Service Charge (${_serviceChargePercent.toStringAsFixed(0)}%)",
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _serviceChargeEnabled,
                        onChanged: (v) =>
                            setState(() => _serviceChargeEnabled = v ?? true),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: FuturisticColors.textSecondary),
                        activeColor: FuturisticColors.primary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showServiceChargeEditor,
                  child: Text(
                    "₹${_serviceChargeAmount.toStringAsFixed(2)}",
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 32, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Grand Total",
                style: GoogleFonts.outfit(
                  color: FuturisticColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "₹${_grandTotal.toStringAsFixed(2)}",
                style: GoogleFonts.outfit(
                  color: FuturisticColors.success,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: FuturisticColors.success.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Tip input — restaurant only (desktop, shown after grand total)
          if (_isRestaurantBill) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.volunteer_activism,
                  size: 16,
                  color: FuturisticColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tip (optional)',
                  style: GoogleFonts.inter(
                    color: FuturisticColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 120,
                  height: 36,
                  child: TextField(
                    controller: _tipController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.inter(
                        color: FuturisticColors.textSecondary,
                        fontSize: 14,
                      ),
                      hintText: '0',
                      hintStyle: GoogleFonts.inter(
                        color: FuturisticColors.textSecondary.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: FuturisticColors.textSecondary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: FuturisticColors.textSecondary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: FuturisticColors.primary),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _tipAmount = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
          // Split Bill action — restaurant only (desktop)
          if (_isRestaurantBill) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _items.isEmpty ? null : _showSplitBillDialog,
                icon: const Icon(Icons.call_split, size: 18),
                label: const Text('Split Bill'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FuturisticColors.primary,
                  side: BorderSide(
                    color: FuturisticColors.primary.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: FuturisticColors.primaryGradient,
                boxShadow: FuturisticColors.neonShadow(
                  FuturisticColors.primary,
                ),
              ),
              child: ElevatedButton(
                onPressed: _items.isEmpty ? null : () => _showPaymentDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "PROCEED TO PAY",
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

  void _showPaymentDialog() {
    // Wrapper to call existing save/payment logic
    // In mobile layout, this is handled by _handleSave which does QR or direct save.
    // We can reuse _handleSave();
    _handleSave();
  }

  Widget _buildMobileLayout() {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.transactionType == TransactionType.sale
                  ? 'New Sale'
                  : 'New Estimate',
              style: AppTypography.headlineSmall.copyWith(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _invoiceNumber,
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          // Clothing: "Take Measurements" action (Phase 4 — Requirement 9.1, 9.2, 9.7).
          // Opens TailoringMeasurementsScreen with customerId/invoiceId context.
          // Visible only for clothing merchants; validates context before navigating.
          if (ref.watch(businessTypeProvider).type == BusinessType.clothing)
            IconButton(
              icon: Icon(Icons.straighten, color: FuturisticColors.accent1),
              tooltip: 'Take Measurements',
              onPressed: () {
                final customerId = _selectedCustomer?.id;
                final invoiceId = _invoiceNumber;

                if (customerId == null ||
                    customerId.isEmpty ||
                    customerId == _walkInCustomerId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cannot take measurements: please select a customer first.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (invoiceId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cannot take measurements: invoice number not yet generated.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                context.go(
                  '/clothing/tailoring',
                  extra: <String, String>{
                    'customerId': customerId,
                    'invoiceId': invoiceId,
                  },
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.person_add_alt_1, color: FuturisticColors.primary),
            tooltip: 'Select Customer',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CustomerSearchSheet(
                  onCustomerSelected: (c) =>
                      setState(() => _selectedCustomer = c),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? FuturisticColors.darkBackgroundGradient
              : FuturisticColors.lightBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Customer Header
              if (_selectedCustomer != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ModernCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: FuturisticColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          _selectedCustomer!.name[0].toUpperCase(),
                          style: TextStyle(color: FuturisticColors.primary),
                        ),
                      ),
                      title: Text(
                        _selectedCustomer!.name,
                        style: AppTypography.bodyLarge.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _selectedCustomer!.phone ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove Customer',
                            onPressed: () => setState(() {
                              _selectedCustomer = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ModernCard(
                    // Using ModernCard instead of plain ListTile
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        Icons.person_outline,
                        color: FuturisticColors.primary,
                      ),
                      title: const Text('Select Customer'),
                      subtitle: const Text('Required for billing'),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => CustomerSearchSheet(
                            onCustomerSelected: (c) =>
                                setState(() => _selectedCustomer = c),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const Divider(height: 1),

              // Adaptive Header (Table No, etc.)
              AdaptiveBillHeader(
                businessType: ref.watch(businessTypeProvider).type,
                bill: _headerBill,
                onUpdate: (updated) => setState(() => _headerBill = updated),
                isDark: isDark,
              ),

              const Divider(height: 1),

              // Items List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildItemsList(palette, isDark),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildSummaryFooter(palette, isDark),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pharmacy-only: Find Substitute (salt/generic search) — R25.
          if (ref.watch(businessTypeProvider).type ==
              BusinessType.pharmacy) ...[
            FloatingActionButton.small(
              heroTag: 'salt_search',
              onPressed: _showSaltSearch,
              backgroundColor: Colors.teal,
              tooltip: 'Find Substitute',
              child: const Icon(Icons.science_outlined, color: Colors.white),
            ),
            const SizedBox(height: 10),
          ],
          // Product Search FAB
          FloatingActionButton.small(
            heroTag: 'product_search',
            onPressed: _showProductSearch,
            backgroundColor: FuturisticColors.accent, // Sky-like
            tooltip: 'Search Products',
            child: const Icon(Icons.search, color: Colors.white),
          ),
          const SizedBox(height: 10),
          // Manual Entry FAB
          FloatingActionButton.small(
            heroTag: 'manual_entry',
            onPressed: _showManualItemEntry,
            backgroundColor: FuturisticColors.primary, // Indigo
            tooltip: 'Manual Entry',
            child: const Icon(Icons.edit_note, color: Colors.white),
          ),
          const SizedBox(height: 10),
          // Voice FAB
          FloatingActionButton(
            heroTag: 'voice_bill',
            onPressed: _openVoiceAssistant,
            backgroundColor: const Color(0xFF8B5CF6), // Purple
            tooltip: 'Voice Bill',
            child: const Icon(Icons.mic, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PaymentModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final AppColorPalette palette;

  const _PaymentModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? FuturisticColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? FuturisticColors.primary : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? FuturisticColors.primary : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? FuturisticColors.primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact "½" chip that toggles the half-portion flag on a restaurant line item.
/// Only rendered when businessType == restaurant and optionalFields contains isHalf.
class _HalfPortionChip extends StatelessWidget {
  final bool isHalf;
  final VoidCallback onToggle;
  final Color accentColor;
  final bool isDark;

  const _HalfPortionChip({
    required this.isHalf,
    required this.onToggle,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isHalf
          ? 'Half portion (tap for full)'
          : 'Full portion (tap for half)',
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHalf
                ? accentColor
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHalf ? accentColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            isHalf ? '½' : 'Full',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isHalf
                  ? Colors.white
                  : (isDark ? Colors.white54 : Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact parcel/takeaway chip that toggles the isParcel flag on a restaurant line item.
/// Only rendered when businessType == restaurant and optionalFields contains isParcel.
class _ParcelChip extends StatelessWidget {
  final bool isParcel;
  final VoidCallback onToggle;
  final Color accentColor;
  final bool isDark;

  const _ParcelChip({
    required this.isParcel,
    required this.onToggle,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isParcel
          ? 'Parcel (tap for dine-in)'
          : 'Dine-in (tap for parcel)',
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isParcel
                ? accentColor
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isParcel ? accentColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isParcel ? Icons.takeout_dining : Icons.restaurant,
                size: 12,
                color: isParcel
                    ? Colors.white
                    : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
              const SizedBox(width: 4),
              Text(
                isParcel ? 'Parcel' : 'Dine-In',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isParcel
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
