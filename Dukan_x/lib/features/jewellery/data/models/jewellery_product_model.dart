// Jewellery Product Model - With Offline Support
// Extends base Product with jewellery-specific fields

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import '../../utils/jewellery_business_rules.dart';

part 'jewellery_product_model.freezed.dart';
part 'jewellery_product_model.g.dart';

/// Metal types supported in jewellery
enum MetalType {
  gold24k,
  gold22k,
  gold18k,
  gold14k,
  gold9k,
  silver,
  platinum,
  diamond,
  other,
}

extension MetalTypeExtension on MetalType {
  String get displayName {
    switch (this) {
      case MetalType.gold24k:
        return '24K Gold';
      case MetalType.gold22k:
        return '22K Gold';
      case MetalType.gold18k:
        return '18K Gold';
      case MetalType.gold14k:
        return '14K Gold';
      case MetalType.gold9k:
        return '9K Gold';
      case MetalType.silver:
        return 'Silver';
      case MetalType.platinum:
        return 'Platinum';
      case MetalType.diamond:
        return 'Diamond';
      case MetalType.other:
        return 'Other';
    }
  }

  double get purityPercentage {
    switch (this) {
      case MetalType.gold24k:
        return 99.9;
      case MetalType.gold22k:
        return 91.6;
      case MetalType.gold18k:
        return 75.0;
      case MetalType.gold14k:
        return 58.5;
      case MetalType.gold9k:
        return 37.5;
      case MetalType.silver:
        return 92.5; // Sterling silver
      case MetalType.platinum:
        return 95.0;
      case MetalType.diamond:
        return 100.0;
      case MetalType.other:
        return 0.0;
    }
  }
}

/// Purity standards for hallmarking
enum PurityStandard {
  p999, // 24K
  p916, // 22K
  p750, // 18K
  p585, // 14K
  p375, // 9K
}

extension PurityStandardExtension on PurityStandard {
  String get code {
    switch (this) {
      case PurityStandard.p999:
        return '999';
      case PurityStandard.p916:
        return '916';
      case PurityStandard.p750:
        return '750';
      case PurityStandard.p585:
        return '585';
      case PurityStandard.p375:
        return '375';
    }
  }

  String get displayName {
    switch (this) {
      case PurityStandard.p999:
        return '999 (24K)';
      case PurityStandard.p916:
        return '916 (22K)';
      case PurityStandard.p750:
        return '750 (18K)';
      case PurityStandard.p585:
        return '585 (14K)';
      case PurityStandard.p375:
        return '375 (9K)';
    }
  }

  /// Converts this hallmarking [PurityStandard] to the pricing-engine
  /// [GoldPurity] enum.
  ///
  /// [PurityStandard.p375] (9K) has no [GoldPurity] equivalent — returns null.
  /// Requirement 15.6: ensures purity flows as typed enum between storage and
  /// pricing paths.
  GoldPurity? toGoldPurity() {
    switch (this) {
      case PurityStandard.p999:
        return GoldPurity.k24;
      case PurityStandard.p916:
        return GoldPurity.k22;
      case PurityStandard.p750:
        return GoldPurity.k18;
      case PurityStandard.p585:
        return GoldPurity.k14;
      case PurityStandard.p375:
        return null; // 9K not supported in pricing engine
    }
  }

  /// Creates a [PurityStandard] from a BIS fineness code string ('999', '916',
  /// '750', '585', '375'). Returns null if unrecognized.
  static PurityStandard? tryFromCode(String? code) {
    if (code == null) return null;
    switch (code.trim()) {
      case '999':
        return PurityStandard.p999;
      case '916':
        return PurityStandard.p916;
      case '750':
        return PurityStandard.p750;
      case '585':
        return PurityStandard.p585;
      case '375':
        return PurityStandard.p375;
      default:
        return null;
    }
  }

  /// Creates a [PurityStandard] from a [GoldPurity] enum value.
  static PurityStandard fromGoldPurity(GoldPurity purity) {
    switch (purity) {
      case GoldPurity.k24:
        return PurityStandard.p999;
      case GoldPurity.k22:
        return PurityStandard.p916;
      case GoldPurity.k18:
        return PurityStandard.p750;
      case GoldPurity.k14:
        return PurityStandard.p585;
    }
  }
}

/// Jewellery Product with all metal-specific fields
@freezed
abstract class JewelleryProduct with _$JewelleryProduct {
  @HiveType(typeId: 51)
  const factory JewelleryProduct({
    // Core identifiers
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,
    @HiveField(2) @Default('jewellery') String businessType,

    // Basic info
    @HiveField(3) required String name,
    @HiveField(4) String? description,
    @HiveField(5) @Default('General') String category,
    @HiveField(6) String? subCategory, // Ring, Necklace, Bracelet, etc.
    // Jewellery-specific fields
    @HiveField(7) @Default(MetalType.gold22k) MetalType metalType,
    @HiveField(8) PurityStandard? purityStandard,
    @HiveField(9) String? purity, // Free-text purity if not standard
    @HiveField(10) @Default(0.0) double metalWeightGrams,
    @HiveField(11) @Default(0.0) double grossWeightGrams, // Including stones
    @HiveField(12) @Default(0.0) double netWeightGrams, // Metal only
    @HiveField(13) @Default(0) double makingChargesPerGram, // In rupees
    @HiveField(14) @Default(0) double wastagePercent,
    @HiveField(15) @Default(0) double stoneWeightGrams,
    @HiveField(16) @Default(0) double stoneCharges, // In rupees
    // Hallmark (HUID) - 6 digit unique ID
    @HiveField(17) String? huid, // Hallmark Unique ID
    @HiveField(18) String? hallmarkNumber,
    @HiveField(19) DateTime? hallmarkDate,
    @HiveField(20) String? assayingCenter,
    @HiveField(21) @Default(false) bool isHallmarked,

    // Pricing (stored in paise for precision)
    @HiveField(22)
    required int pricePerGramPaisa, // Metal rate at time of creation
    @HiveField(23)
    required int totalMrpPaisa, // Final MRP including all charges
    @HiveField(24) int? costPricePaisa, // Purchase cost
    // Stock
    @HiveField(25) @Default(0) int stockQuantity,
    @HiveField(26) @Default(5) int reorderLevel,
    @HiveField(27) @Default('pcs') String unit,

    // GST - 3% for jewellery
    @HiveField(28) @Default(3.0) double gstRate,
    @HiveField(29) String? hsnCode,

    // Barcode/SKU
    @HiveField(30) String? barcode,
    @HiveField(31) String? sku,

    // Images
    @HiveField(32) String? s3ImageKey,
    @HiveField(33) String? s3ThumbnailKey,
    @HiveField(34) String? presignedImageUrl,
    @HiveField(35) List<String>? additionalImageKeys,

    // Metadata
    @HiveField(36) @Default(true) bool isActive,
    @HiveField(37) required DateTime createdAt,
    @HiveField(38) required DateTime updatedAt,
    @HiveField(39) required String createdBy,
    @HiveField(40) required String updatedBy,

    // Sync tracking for offline
    @HiveField(41) @Default(true) bool synced,
    @HiveField(42) DateTime? lastSyncedAt,
    @HiveField(43) @Default(1) int version,

    // Soft delete
    @HiveField(44) @Default(false) bool isDeleted,
    @HiveField(45) DateTime? deletedAt,

    // Offline operation tracking
    @HiveField(46) String? pendingOperation, // 'create', 'update', 'delete'
    @HiveField(47) DateTime? pendingSince,
  }) = _JewelleryProduct;

  const JewelleryProduct._();

  factory JewelleryProduct.fromJson(Map<String, dynamic> json) =>
      _$JewelleryProductFromJson(json);

  /// Helper to calculate MRP based on current gold rate
  int calculateMrp({
    required int currentGoldRatePerGramPaisa,
    int? diamondChargesPaisa,
  }) {
    final metalValue = (metalWeightGrams * currentGoldRatePerGramPaisa).round();
    final makingCharges = (metalWeightGrams * makingChargesPerGram * 100)
        .round();
    final wastageCharges = (metalValue * wastagePercent / 100).round();
    final stones = stoneCharges > 0
        ? (stoneCharges * 100).round()
        : (diamondChargesPaisa ?? 0);

    return metalValue + makingCharges + wastageCharges + stones;
  }

  /// Check if stock is low
  bool get isLowStock => stockQuantity <= reorderLevel;

  /// Check if product is out of stock
  bool get isOutOfStock => stockQuantity <= 0;

  /// Get display price in rupees
  double get displayPrice => totalMrpPaisa / 100;

  /// Get metal rate in rupees per gram
  double get displayMetalRate => pricePerGramPaisa / 100;

  /// Get making charges in rupees per gram
  double get displayMakingCharges => makingChargesPerGram;

  /// Resolves the canonical [GoldPurity] for this product.
  ///
  /// Priority:
  ///   1. [purityStandard] (typed enum) → converted via [toGoldPurity]
  ///   2. [purity] (free-text String) → parsed via [GoldPurity.tryFromString]
  ///   3. Derived from [metalType] if it encodes a karat (e.g., gold22k → k22)
  ///
  /// Returns null if purity cannot be resolved to a valid [GoldPurity].
  /// Requirement 15.6: ensures the product model exposes typed purity
  /// for the pricing engine.
  GoldPurity? get resolvedGoldPurity {
    // 1. Typed PurityStandard takes priority
    if (purityStandard != null) {
      return purityStandard!.toGoldPurity();
    }
    // 2. Parse free-text purity string
    final fromString = GoldPurity.tryFromString(purity);
    if (fromString != null) return fromString;
    // 3. Derive from metalType
    switch (metalType) {
      case MetalType.gold24k:
        return GoldPurity.k24;
      case MetalType.gold22k:
        return GoldPurity.k22;
      case MetalType.gold18k:
        return GoldPurity.k18;
      case MetalType.gold14k:
        return GoldPurity.k14;
      default:
        return null;
    }
  }
}

/// Gold Rate Card - Daily rates for different metals
@freezed
abstract class GoldRateCard with _$GoldRateCard {
  @HiveType(typeId: 52)
  const factory GoldRateCard({
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,
    @HiveField(2) required String date, // YYYY-MM-DD
    @HiveField(3) required int gold24KPer10gPaisa,
    @HiveField(4) required int gold22KPer10gPaisa,
    @HiveField(5) required int gold18KPer10gPaisa,
    @HiveField(6) required int silverPerKgPaisa,
    @HiveField(7) required int platinumPerGramPaisa,
    @HiveField(8) @Default('MANUAL') String source, // MANUAL, API, BANK
    @HiveField(9) String? notes,
    @HiveField(10) required DateTime createdAt,
    @HiveField(11) required String createdBy,
    @HiveField(12) @Default(true) bool synced,
    @HiveField(13) DateTime? lastSyncedAt,
    @HiveField(14) String? pendingOperation,
  }) = _GoldRateCard;

  const GoldRateCard._();

  factory GoldRateCard.fromJson(Map<String, dynamic> json) =>
      _$GoldRateCardFromJson(json);

  /// Get rate per gram (from per 10g)
  int getGoldRatePerGram(MetalType type) {
    switch (type) {
      case MetalType.gold24k:
        return (gold24KPer10gPaisa / 10).round();
      case MetalType.gold22k:
        return (gold22KPer10gPaisa / 10).round();
      case MetalType.gold18k:
        return (gold18KPer10gPaisa / 10).round();
      default:
        return 0;
    }
  }

  /// Display rates in rupees
  double get displayGold24K => gold24KPer10gPaisa / 100;
  double get displayGold22K => gold22KPer10gPaisa / 100;
  double get displayGold18K => gold18KPer10gPaisa / 100;
  double get displaySilver => silverPerKgPaisa / 100;
  double get displayPlatinum => platinumPerGramPaisa / 100;
}

/// Old Gold Exchange Record (PML Act Compliance)
@freezed
abstract class OldGoldExchange with _$OldGoldExchange {
  @HiveType(typeId: 53)
  const factory OldGoldExchange({
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,
    @HiveField(2) required String customerId,
    @HiveField(3) required String customerName,
    @HiveField(4) String? customerPhone,

    // PML Act KYC Fields
    @HiveField(5)
    required String customerIdType, // AADHAAR, PAN, PASSPORT, VOTER_ID
    @HiveField(6) required String customerIdNumber,
    @HiveField(7) String? customerPhotoUrl,
    @HiveField(8) String? idDocumentUrl,

    // Old gold details
    @HiveField(9) required MetalType oldGoldMetalType,
    @HiveField(10) required double oldGoldWeightGrams,
    @HiveField(11) required int oldGoldValuePaisa, // Calculated value
    @HiveField(12)
    required int oldGoldRatePerGramPaisa, // Rate at exchange time
    // Purity verification
    @HiveField(13) String? purityTestMethod, // XRF, ACID, TOUCHSTONE
    @HiveField(14) double? actualPurityPercentage,
    @HiveField(15) String? purityTestReportUrl,

    // New item details (if exchanging)
    @HiveField(16) String? newItemDescription,
    @HiveField(17) MetalType? newItemMetalType,
    @HiveField(18) double? newItemWeightGrams,
    @HiveField(19) int? newItemTotalPaisa,
    String? newItemInvoiceId,

    // Exchange calculation
    @HiveField(20) required int exchangeValuePaisa,
    @HiveField(21)
    @Default(0)
    int cashAdjustmentPaisa, // Positive = customer pays
    // Status
    @HiveField(23)
    @Default('PENDING')
    String status, // PENDING, VERIFIED, COMPLETED, CANCELLED
    @HiveField(24) String? verifiedBy,
    @HiveField(25) DateTime? verifiedAt,

    // Metadata
    @HiveField(26) required DateTime createdAt,
    @HiveField(27) required String createdBy,
    @HiveField(28) @Default(true) bool synced,
    @HiveField(29) DateTime? lastSyncedAt,
    @HiveField(30) String? pendingOperation,

    // PML Act compliance tracking
    @HiveField(31) @Default(true) bool pmlCompliant,
    @HiveField(32) String? complianceNotes,
  }) = _OldGoldExchange;

  const OldGoldExchange._();

  factory OldGoldExchange.fromJson(Map<String, dynamic> json) =>
      _$OldGoldExchangeFromJson(json);

  // Moved from factory constructor — getters cannot be inside freezed factory params
  int get finalAmountPaisa => exchangeValuePaisa + cashAdjustmentPaisa;

  double get displayExchangeValue => exchangeValuePaisa / 100;
  double get displayCashAdjustment => cashAdjustmentPaisa / 100;
  double get displayFinalAmount => finalAmountPaisa / 100;
}

/// Custom Jewellery Order
@freezed
abstract class JewelleryOrder with _$JewelleryOrder {
  @HiveType(typeId: 54)
  const factory JewelleryOrder({
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,
    @HiveField(2) required String customerId,
    @HiveField(3) required String customerName,
    @HiveField(4) String? customerPhone,

    // Order details
    @HiveField(5) required String itemDescription,
    @HiveField(6) String? designReference, // Image URL or design code
    @HiveField(7) String? designNotes,

    // Metal specifications
    @HiveField(8) required MetalType metalType,
    @HiveField(9) required double estimatedWeightGrams,
    @HiveField(10) double? actualWeightGrams, // After completion
    // Pricing (estimated)
    @HiveField(11) required int metalRatePerGramPaisa, // At order time
    @HiveField(12) required int makingChargesPerGramPaisa,
    @HiveField(13) @Default(0) double wastagePercent,
    @HiveField(14) @Default(0) int stoneChargesPaisa,
    @HiveField(15) @Default(0) int otherChargesPaisa,
    @HiveField(16) required int estimatedTotalPaisa,
    @HiveField(17) int? actualTotalPaisa, // Final amount after completion
    // Advance payment
    @HiveField(18) @Default(0) int advanceReceivedPaisa,
    @HiveField(19) String? advancePaymentMode,

    // Timeline
    @HiveField(20) required DateTime orderDate,
    @HiveField(21) required String promisedDeliveryDate, // YYYY-MM-DD
    @HiveField(22) String? actualDeliveryDate,

    // Status workflow
    @HiveField(23) @Default('PENDING') String status,
    // PENDING -> DESIGN_APPROVAL -> IN_PROGRESS -> READY -> DELIVERED
    // Or: CANCELLED at any point

    // Status history
    @HiveField(24) List<OrderStatusUpdate>? statusHistory,

    // Work tracking
    @HiveField(25) String? assignedTo, // Craftsman/staff
    @HiveField(26) List<WorkProgressUpdate>? workProgress,

    // Final product
    @HiveField(27) String? finalProductId, // Link to inventory item
    @HiveField(28) String? invoiceId,

    // Metadata
    @HiveField(29) required DateTime createdAt,
    @HiveField(30) required String createdBy,
    @HiveField(31) required DateTime updatedAt,
    @HiveField(32) required String updatedBy,
    @HiveField(33) @Default(true) bool synced,
    @HiveField(34) DateTime? lastSyncedAt,
    @HiveField(35) String? pendingOperation,
  }) = _JewelleryOrder;

  const JewelleryOrder._();

  factory JewelleryOrder.fromJson(Map<String, dynamic> json) =>
      _$JewelleryOrderFromJson(json);

  // Moved from factory constructor — getters cannot be inside freezed factory params
  int get balancePaisa =>
      (actualTotalPaisa ?? estimatedTotalPaisa) - advanceReceivedPaisa;

  double get displayEstimatedTotal => estimatedTotalPaisa / 100;
  double get displayActualTotal =>
      (actualTotalPaisa ?? estimatedTotalPaisa) / 100;
  double get displayAdvance => advanceReceivedPaisa / 100;
  double get displayBalance => balancePaisa / 100;
}

/// Order status update record
@freezed
abstract class OrderStatusUpdate with _$OrderStatusUpdate {
  const factory OrderStatusUpdate({
    required String status,
    required DateTime timestamp,
    required String updatedBy,
    String? notes,
  }) = _OrderStatusUpdate;

  factory OrderStatusUpdate.fromJson(Map<String, dynamic> json) =>
      _$OrderStatusUpdateFromJson(json);
}

/// Work progress update
@freezed
abstract class WorkProgressUpdate with _$WorkProgressUpdate {
  const factory WorkProgressUpdate({
    required String stage, // CASTING, FILING, SETTING, POLISHING, etc.
    required DateTime timestamp,
    String? notes,
    List<String>? imageUrls,
  }) = _WorkProgressUpdate;

  factory WorkProgressUpdate.fromJson(Map<String, dynamic> json) =>
      _$WorkProgressUpdateFromJson(json);
}

/// Hallmark Register Entry (Compliance)
@freezed
abstract class HallmarkRegisterEntry with _$HallmarkRegisterEntry {
  @HiveType(typeId: 55)
  const factory HallmarkRegisterEntry({
    @HiveField(0) required String id,
    @HiveField(1) required String tenantId,
    @HiveField(2) required String huid, // 6-digit Hallmark Unique ID
    @HiveField(3) required String productId,
    @HiveField(4) required String productName,
    @HiveField(5) required PurityStandard purityStandard,
    @HiveField(6) required double weightGrams,
    @HiveField(7) String? articleType, // Ring, Chain, etc.
    // BIS details
    @HiveField(8) String? bisLogo,
    @HiveField(9) String? purityMark,
    @HiveField(10) String? assayingCenterMark,
    @HiveField(11) String? jewelerMark,

    // Date
    @HiveField(12) required DateTime hallmarkDate,
    @HiveField(13) String? registrationNumber, // BIS registration
    // Status
    @HiveField(14) @Default('ACTIVE') String status, // ACTIVE, SOLD, RETURNED
    @HiveField(15) String? saleInvoiceId,
    @HiveField(16) DateTime? soldDate,

    // Images
    @HiveField(17) String? hallmarkImageUrl,
    @HiveField(18) String? productImageUrl,

    // Metadata
    @HiveField(19) required DateTime createdAt,
    @HiveField(20) @Default(true) bool synced,
    @HiveField(21) DateTime? lastSyncedAt,
  }) = _HallmarkRegisterEntry;

  const HallmarkRegisterEntry._();

  factory HallmarkRegisterEntry.fromJson(Map<String, dynamic> json) =>
      _$HallmarkRegisterEntryFromJson(json);
}

/// Request/Response models for API operations
class CreateJewelleryProductRequest {
  final String name;
  final String? description;
  final String category;
  final MetalType metalType;
  final double metalWeightGrams;
  final double? grossWeightGrams;
  final double makingChargesPerGram;
  final double wastagePercent;
  final int pricePerGramPaisa;
  final int totalMrpPaisa;
  final String? huid;
  final int stock;
  final String? barcode;
  final String? sku;

  CreateJewelleryProductRequest({
    required this.name,
    this.description,
    this.category = 'General',
    required this.metalType,
    required this.metalWeightGrams,
    this.grossWeightGrams,
    required this.makingChargesPerGram,
    this.wastagePercent = 0,
    required this.pricePerGramPaisa,
    required this.totalMrpPaisa,
    this.huid,
    this.stock = 0,
    this.barcode,
    this.sku,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'category': category,
    'metalType': metalType.name,
    'metalWeightGrams': metalWeightGrams,
    'grossWeightGrams': grossWeightGrams,
    'makingChargesPerGram': makingChargesPerGram,
    'wastagePercent': wastagePercent,
    'pricePerGramPaisa': pricePerGramPaisa,
    'totalMrpPaisa': totalMrpPaisa,
    'huid': huid,
    'stock': stock,
    'barcode': barcode,
    'sku': sku,
  };
}

class UpdateJewelleryProductRequest {
  final String? name;
  final String? description;
  final String? category;
  final MetalType? metalType;
  final double? metalWeightGrams;
  final double? makingChargesPerGram;
  final int? pricePerGramPaisa;
  final int? totalMrpPaisa;
  final int? stock;
  final bool? isActive;

  UpdateJewelleryProductRequest({
    this.name,
    this.description,
    this.category,
    this.metalType,
    this.metalWeightGrams,
    this.makingChargesPerGram,
    this.pricePerGramPaisa,
    this.totalMrpPaisa,
    this.stock,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (category != null) data['category'] = category;
    if (metalType != null) data['metalType'] = metalType!.name;
    if (metalWeightGrams != null) data['metalWeightGrams'] = metalWeightGrams;
    if (makingChargesPerGram != null)
      data['makingChargesPerGram'] = makingChargesPerGram;
    if (pricePerGramPaisa != null)
      data['pricePerGramPaisa'] = pricePerGramPaisa;
    if (totalMrpPaisa != null) data['totalMrpPaisa'] = totalMrpPaisa;
    if (stock != null) data['stock'] = stock;
    if (isActive != null) data['isActive'] = isActive;
    return data;
  }
}
