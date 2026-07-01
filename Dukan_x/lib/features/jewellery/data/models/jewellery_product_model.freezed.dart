// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jewellery_product_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JewelleryProduct {

// Core identifiers
@HiveField(0) String get id;@HiveField(1) String get tenantId;@HiveField(2) String get businessType;// Basic info
@HiveField(3) String get name;@HiveField(4) String? get description;@HiveField(5) String get category;@HiveField(6) String? get subCategory;// Ring, Necklace, Bracelet, etc.
// Jewellery-specific fields
@HiveField(7) MetalType get metalType;@HiveField(8) PurityStandard? get purityStandard;@HiveField(9) String? get purity;// Free-text purity if not standard
@HiveField(10) double get metalWeightGrams;@HiveField(11) double get grossWeightGrams;// Including stones
@HiveField(12) double get netWeightGrams;// Metal only
@HiveField(13) double get makingChargesPerGram;// In rupees
@HiveField(14) double get wastagePercent;@HiveField(15) double get stoneWeightGrams;@HiveField(16) double get stoneCharges;// In rupees
// Hallmark (HUID) - 6 digit unique ID
@HiveField(17) String? get huid;// Hallmark Unique ID
@HiveField(18) String? get hallmarkNumber;@HiveField(19) DateTime? get hallmarkDate;@HiveField(20) String? get assayingCenter;@HiveField(21) bool get isHallmarked;// Pricing (stored in paise for precision)
@HiveField(22) int get pricePerGramPaisa;// Metal rate at time of creation
@HiveField(23) int get totalMrpPaisa;// Final MRP including all charges
@HiveField(24) int? get costPricePaisa;// Purchase cost
// Stock
@HiveField(25) int get stockQuantity;@HiveField(26) int get reorderLevel;@HiveField(27) String get unit;// GST - 3% for jewellery
@HiveField(28) double get gstRate;@HiveField(29) String? get hsnCode;// Barcode/SKU
@HiveField(30) String? get barcode;@HiveField(31) String? get sku;// Images
@HiveField(32) String? get s3ImageKey;@HiveField(33) String? get s3ThumbnailKey;@HiveField(34) String? get presignedImageUrl;@HiveField(35) List<String>? get additionalImageKeys;// Metadata
@HiveField(36) bool get isActive;@HiveField(37) DateTime get createdAt;@HiveField(38) DateTime get updatedAt;@HiveField(39) String get createdBy;@HiveField(40) String get updatedBy;// Sync tracking for offline
@HiveField(41) bool get synced;@HiveField(42) DateTime? get lastSyncedAt;@HiveField(43) int get version;// Soft delete
@HiveField(44) bool get isDeleted;@HiveField(45) DateTime? get deletedAt;// Offline operation tracking
@HiveField(46) String? get pendingOperation;// 'create', 'update', 'delete'
@HiveField(47) DateTime? get pendingSince;
/// Create a copy of JewelleryProduct
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JewelleryProductCopyWith<JewelleryProduct> get copyWith => _$JewelleryProductCopyWithImpl<JewelleryProduct>(this as JewelleryProduct, _$identity);

  /// Serializes this JewelleryProduct to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JewelleryProduct&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.businessType, businessType) || other.businessType == businessType)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.subCategory, subCategory) || other.subCategory == subCategory)&&(identical(other.metalType, metalType) || other.metalType == metalType)&&(identical(other.purityStandard, purityStandard) || other.purityStandard == purityStandard)&&(identical(other.purity, purity) || other.purity == purity)&&(identical(other.metalWeightGrams, metalWeightGrams) || other.metalWeightGrams == metalWeightGrams)&&(identical(other.grossWeightGrams, grossWeightGrams) || other.grossWeightGrams == grossWeightGrams)&&(identical(other.netWeightGrams, netWeightGrams) || other.netWeightGrams == netWeightGrams)&&(identical(other.makingChargesPerGram, makingChargesPerGram) || other.makingChargesPerGram == makingChargesPerGram)&&(identical(other.wastagePercent, wastagePercent) || other.wastagePercent == wastagePercent)&&(identical(other.stoneWeightGrams, stoneWeightGrams) || other.stoneWeightGrams == stoneWeightGrams)&&(identical(other.stoneCharges, stoneCharges) || other.stoneCharges == stoneCharges)&&(identical(other.huid, huid) || other.huid == huid)&&(identical(other.hallmarkNumber, hallmarkNumber) || other.hallmarkNumber == hallmarkNumber)&&(identical(other.hallmarkDate, hallmarkDate) || other.hallmarkDate == hallmarkDate)&&(identical(other.assayingCenter, assayingCenter) || other.assayingCenter == assayingCenter)&&(identical(other.isHallmarked, isHallmarked) || other.isHallmarked == isHallmarked)&&(identical(other.pricePerGramPaisa, pricePerGramPaisa) || other.pricePerGramPaisa == pricePerGramPaisa)&&(identical(other.totalMrpPaisa, totalMrpPaisa) || other.totalMrpPaisa == totalMrpPaisa)&&(identical(other.costPricePaisa, costPricePaisa) || other.costPricePaisa == costPricePaisa)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.gstRate, gstRate) || other.gstRate == gstRate)&&(identical(other.hsnCode, hsnCode) || other.hsnCode == hsnCode)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.s3ImageKey, s3ImageKey) || other.s3ImageKey == s3ImageKey)&&(identical(other.s3ThumbnailKey, s3ThumbnailKey) || other.s3ThumbnailKey == s3ThumbnailKey)&&(identical(other.presignedImageUrl, presignedImageUrl) || other.presignedImageUrl == presignedImageUrl)&&const DeepCollectionEquality().equals(other.additionalImageKeys, additionalImageKeys)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.version, version) || other.version == version)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation)&&(identical(other.pendingSince, pendingSince) || other.pendingSince == pendingSince));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,businessType,name,description,category,subCategory,metalType,purityStandard,purity,metalWeightGrams,grossWeightGrams,netWeightGrams,makingChargesPerGram,wastagePercent,stoneWeightGrams,stoneCharges,huid,hallmarkNumber,hallmarkDate,assayingCenter,isHallmarked,pricePerGramPaisa,totalMrpPaisa,costPricePaisa,stockQuantity,reorderLevel,unit,gstRate,hsnCode,barcode,sku,s3ImageKey,s3ThumbnailKey,presignedImageUrl,const DeepCollectionEquality().hash(additionalImageKeys),isActive,createdAt,updatedAt,createdBy,updatedBy,synced,lastSyncedAt,version,isDeleted,deletedAt,pendingOperation,pendingSince]);

@override
String toString() {
  return 'JewelleryProduct(id: $id, tenantId: $tenantId, businessType: $businessType, name: $name, description: $description, category: $category, subCategory: $subCategory, metalType: $metalType, purityStandard: $purityStandard, purity: $purity, metalWeightGrams: $metalWeightGrams, grossWeightGrams: $grossWeightGrams, netWeightGrams: $netWeightGrams, makingChargesPerGram: $makingChargesPerGram, wastagePercent: $wastagePercent, stoneWeightGrams: $stoneWeightGrams, stoneCharges: $stoneCharges, huid: $huid, hallmarkNumber: $hallmarkNumber, hallmarkDate: $hallmarkDate, assayingCenter: $assayingCenter, isHallmarked: $isHallmarked, pricePerGramPaisa: $pricePerGramPaisa, totalMrpPaisa: $totalMrpPaisa, costPricePaisa: $costPricePaisa, stockQuantity: $stockQuantity, reorderLevel: $reorderLevel, unit: $unit, gstRate: $gstRate, hsnCode: $hsnCode, barcode: $barcode, sku: $sku, s3ImageKey: $s3ImageKey, s3ThumbnailKey: $s3ThumbnailKey, presignedImageUrl: $presignedImageUrl, additionalImageKeys: $additionalImageKeys, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, version: $version, isDeleted: $isDeleted, deletedAt: $deletedAt, pendingOperation: $pendingOperation, pendingSince: $pendingSince)';
}


}

/// @nodoc
abstract mixin class $JewelleryProductCopyWith<$Res>  {
  factory $JewelleryProductCopyWith(JewelleryProduct value, $Res Function(JewelleryProduct) _then) = _$JewelleryProductCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String businessType,@HiveField(3) String name,@HiveField(4) String? description,@HiveField(5) String category,@HiveField(6) String? subCategory,@HiveField(7) MetalType metalType,@HiveField(8) PurityStandard? purityStandard,@HiveField(9) String? purity,@HiveField(10) double metalWeightGrams,@HiveField(11) double grossWeightGrams,@HiveField(12) double netWeightGrams,@HiveField(13) double makingChargesPerGram,@HiveField(14) double wastagePercent,@HiveField(15) double stoneWeightGrams,@HiveField(16) double stoneCharges,@HiveField(17) String? huid,@HiveField(18) String? hallmarkNumber,@HiveField(19) DateTime? hallmarkDate,@HiveField(20) String? assayingCenter,@HiveField(21) bool isHallmarked,@HiveField(22) int pricePerGramPaisa,@HiveField(23) int totalMrpPaisa,@HiveField(24) int? costPricePaisa,@HiveField(25) int stockQuantity,@HiveField(26) int reorderLevel,@HiveField(27) String unit,@HiveField(28) double gstRate,@HiveField(29) String? hsnCode,@HiveField(30) String? barcode,@HiveField(31) String? sku,@HiveField(32) String? s3ImageKey,@HiveField(33) String? s3ThumbnailKey,@HiveField(34) String? presignedImageUrl,@HiveField(35) List<String>? additionalImageKeys,@HiveField(36) bool isActive,@HiveField(37) DateTime createdAt,@HiveField(38) DateTime updatedAt,@HiveField(39) String createdBy,@HiveField(40) String updatedBy,@HiveField(41) bool synced,@HiveField(42) DateTime? lastSyncedAt,@HiveField(43) int version,@HiveField(44) bool isDeleted,@HiveField(45) DateTime? deletedAt,@HiveField(46) String? pendingOperation,@HiveField(47) DateTime? pendingSince
});




}
/// @nodoc
class _$JewelleryProductCopyWithImpl<$Res>
    implements $JewelleryProductCopyWith<$Res> {
  _$JewelleryProductCopyWithImpl(this._self, this._then);

  final JewelleryProduct _self;
  final $Res Function(JewelleryProduct) _then;

/// Create a copy of JewelleryProduct
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? businessType = null,Object? name = null,Object? description = freezed,Object? category = null,Object? subCategory = freezed,Object? metalType = null,Object? purityStandard = freezed,Object? purity = freezed,Object? metalWeightGrams = null,Object? grossWeightGrams = null,Object? netWeightGrams = null,Object? makingChargesPerGram = null,Object? wastagePercent = null,Object? stoneWeightGrams = null,Object? stoneCharges = null,Object? huid = freezed,Object? hallmarkNumber = freezed,Object? hallmarkDate = freezed,Object? assayingCenter = freezed,Object? isHallmarked = null,Object? pricePerGramPaisa = null,Object? totalMrpPaisa = null,Object? costPricePaisa = freezed,Object? stockQuantity = null,Object? reorderLevel = null,Object? unit = null,Object? gstRate = null,Object? hsnCode = freezed,Object? barcode = freezed,Object? sku = freezed,Object? s3ImageKey = freezed,Object? s3ThumbnailKey = freezed,Object? presignedImageUrl = freezed,Object? additionalImageKeys = freezed,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,Object? createdBy = null,Object? updatedBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? version = null,Object? isDeleted = null,Object? deletedAt = freezed,Object? pendingOperation = freezed,Object? pendingSince = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,businessType: null == businessType ? _self.businessType : businessType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,subCategory: freezed == subCategory ? _self.subCategory : subCategory // ignore: cast_nullable_to_non_nullable
as String?,metalType: null == metalType ? _self.metalType : metalType // ignore: cast_nullable_to_non_nullable
as MetalType,purityStandard: freezed == purityStandard ? _self.purityStandard : purityStandard // ignore: cast_nullable_to_non_nullable
as PurityStandard?,purity: freezed == purity ? _self.purity : purity // ignore: cast_nullable_to_non_nullable
as String?,metalWeightGrams: null == metalWeightGrams ? _self.metalWeightGrams : metalWeightGrams // ignore: cast_nullable_to_non_nullable
as double,grossWeightGrams: null == grossWeightGrams ? _self.grossWeightGrams : grossWeightGrams // ignore: cast_nullable_to_non_nullable
as double,netWeightGrams: null == netWeightGrams ? _self.netWeightGrams : netWeightGrams // ignore: cast_nullable_to_non_nullable
as double,makingChargesPerGram: null == makingChargesPerGram ? _self.makingChargesPerGram : makingChargesPerGram // ignore: cast_nullable_to_non_nullable
as double,wastagePercent: null == wastagePercent ? _self.wastagePercent : wastagePercent // ignore: cast_nullable_to_non_nullable
as double,stoneWeightGrams: null == stoneWeightGrams ? _self.stoneWeightGrams : stoneWeightGrams // ignore: cast_nullable_to_non_nullable
as double,stoneCharges: null == stoneCharges ? _self.stoneCharges : stoneCharges // ignore: cast_nullable_to_non_nullable
as double,huid: freezed == huid ? _self.huid : huid // ignore: cast_nullable_to_non_nullable
as String?,hallmarkNumber: freezed == hallmarkNumber ? _self.hallmarkNumber : hallmarkNumber // ignore: cast_nullable_to_non_nullable
as String?,hallmarkDate: freezed == hallmarkDate ? _self.hallmarkDate : hallmarkDate // ignore: cast_nullable_to_non_nullable
as DateTime?,assayingCenter: freezed == assayingCenter ? _self.assayingCenter : assayingCenter // ignore: cast_nullable_to_non_nullable
as String?,isHallmarked: null == isHallmarked ? _self.isHallmarked : isHallmarked // ignore: cast_nullable_to_non_nullable
as bool,pricePerGramPaisa: null == pricePerGramPaisa ? _self.pricePerGramPaisa : pricePerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,totalMrpPaisa: null == totalMrpPaisa ? _self.totalMrpPaisa : totalMrpPaisa // ignore: cast_nullable_to_non_nullable
as int,costPricePaisa: freezed == costPricePaisa ? _self.costPricePaisa : costPricePaisa // ignore: cast_nullable_to_non_nullable
as int?,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,reorderLevel: null == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,gstRate: null == gstRate ? _self.gstRate : gstRate // ignore: cast_nullable_to_non_nullable
as double,hsnCode: freezed == hsnCode ? _self.hsnCode : hsnCode // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,s3ImageKey: freezed == s3ImageKey ? _self.s3ImageKey : s3ImageKey // ignore: cast_nullable_to_non_nullable
as String?,s3ThumbnailKey: freezed == s3ThumbnailKey ? _self.s3ThumbnailKey : s3ThumbnailKey // ignore: cast_nullable_to_non_nullable
as String?,presignedImageUrl: freezed == presignedImageUrl ? _self.presignedImageUrl : presignedImageUrl // ignore: cast_nullable_to_non_nullable
as String?,additionalImageKeys: freezed == additionalImageKeys ? _self.additionalImageKeys : additionalImageKeys // ignore: cast_nullable_to_non_nullable
as List<String>?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,pendingSince: freezed == pendingSince ? _self.pendingSince : pendingSince // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [JewelleryProduct].
extension JewelleryProductPatterns on JewelleryProduct {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JewelleryProduct value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JewelleryProduct() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JewelleryProduct value)  $default,){
final _that = this;
switch (_that) {
case _JewelleryProduct():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JewelleryProduct value)?  $default,){
final _that = this;
switch (_that) {
case _JewelleryProduct() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String businessType, @HiveField(3)  String name, @HiveField(4)  String? description, @HiveField(5)  String category, @HiveField(6)  String? subCategory, @HiveField(7)  MetalType metalType, @HiveField(8)  PurityStandard? purityStandard, @HiveField(9)  String? purity, @HiveField(10)  double metalWeightGrams, @HiveField(11)  double grossWeightGrams, @HiveField(12)  double netWeightGrams, @HiveField(13)  double makingChargesPerGram, @HiveField(14)  double wastagePercent, @HiveField(15)  double stoneWeightGrams, @HiveField(16)  double stoneCharges, @HiveField(17)  String? huid, @HiveField(18)  String? hallmarkNumber, @HiveField(19)  DateTime? hallmarkDate, @HiveField(20)  String? assayingCenter, @HiveField(21)  bool isHallmarked, @HiveField(22)  int pricePerGramPaisa, @HiveField(23)  int totalMrpPaisa, @HiveField(24)  int? costPricePaisa, @HiveField(25)  int stockQuantity, @HiveField(26)  int reorderLevel, @HiveField(27)  String unit, @HiveField(28)  double gstRate, @HiveField(29)  String? hsnCode, @HiveField(30)  String? barcode, @HiveField(31)  String? sku, @HiveField(32)  String? s3ImageKey, @HiveField(33)  String? s3ThumbnailKey, @HiveField(34)  String? presignedImageUrl, @HiveField(35)  List<String>? additionalImageKeys, @HiveField(36)  bool isActive, @HiveField(37)  DateTime createdAt, @HiveField(38)  DateTime updatedAt, @HiveField(39)  String createdBy, @HiveField(40)  String updatedBy, @HiveField(41)  bool synced, @HiveField(42)  DateTime? lastSyncedAt, @HiveField(43)  int version, @HiveField(44)  bool isDeleted, @HiveField(45)  DateTime? deletedAt, @HiveField(46)  String? pendingOperation, @HiveField(47)  DateTime? pendingSince)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JewelleryProduct() when $default != null:
return $default(_that.id,_that.tenantId,_that.businessType,_that.name,_that.description,_that.category,_that.subCategory,_that.metalType,_that.purityStandard,_that.purity,_that.metalWeightGrams,_that.grossWeightGrams,_that.netWeightGrams,_that.makingChargesPerGram,_that.wastagePercent,_that.stoneWeightGrams,_that.stoneCharges,_that.huid,_that.hallmarkNumber,_that.hallmarkDate,_that.assayingCenter,_that.isHallmarked,_that.pricePerGramPaisa,_that.totalMrpPaisa,_that.costPricePaisa,_that.stockQuantity,_that.reorderLevel,_that.unit,_that.gstRate,_that.hsnCode,_that.barcode,_that.sku,_that.s3ImageKey,_that.s3ThumbnailKey,_that.presignedImageUrl,_that.additionalImageKeys,_that.isActive,_that.createdAt,_that.updatedAt,_that.createdBy,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.version,_that.isDeleted,_that.deletedAt,_that.pendingOperation,_that.pendingSince);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String businessType, @HiveField(3)  String name, @HiveField(4)  String? description, @HiveField(5)  String category, @HiveField(6)  String? subCategory, @HiveField(7)  MetalType metalType, @HiveField(8)  PurityStandard? purityStandard, @HiveField(9)  String? purity, @HiveField(10)  double metalWeightGrams, @HiveField(11)  double grossWeightGrams, @HiveField(12)  double netWeightGrams, @HiveField(13)  double makingChargesPerGram, @HiveField(14)  double wastagePercent, @HiveField(15)  double stoneWeightGrams, @HiveField(16)  double stoneCharges, @HiveField(17)  String? huid, @HiveField(18)  String? hallmarkNumber, @HiveField(19)  DateTime? hallmarkDate, @HiveField(20)  String? assayingCenter, @HiveField(21)  bool isHallmarked, @HiveField(22)  int pricePerGramPaisa, @HiveField(23)  int totalMrpPaisa, @HiveField(24)  int? costPricePaisa, @HiveField(25)  int stockQuantity, @HiveField(26)  int reorderLevel, @HiveField(27)  String unit, @HiveField(28)  double gstRate, @HiveField(29)  String? hsnCode, @HiveField(30)  String? barcode, @HiveField(31)  String? sku, @HiveField(32)  String? s3ImageKey, @HiveField(33)  String? s3ThumbnailKey, @HiveField(34)  String? presignedImageUrl, @HiveField(35)  List<String>? additionalImageKeys, @HiveField(36)  bool isActive, @HiveField(37)  DateTime createdAt, @HiveField(38)  DateTime updatedAt, @HiveField(39)  String createdBy, @HiveField(40)  String updatedBy, @HiveField(41)  bool synced, @HiveField(42)  DateTime? lastSyncedAt, @HiveField(43)  int version, @HiveField(44)  bool isDeleted, @HiveField(45)  DateTime? deletedAt, @HiveField(46)  String? pendingOperation, @HiveField(47)  DateTime? pendingSince)  $default,) {final _that = this;
switch (_that) {
case _JewelleryProduct():
return $default(_that.id,_that.tenantId,_that.businessType,_that.name,_that.description,_that.category,_that.subCategory,_that.metalType,_that.purityStandard,_that.purity,_that.metalWeightGrams,_that.grossWeightGrams,_that.netWeightGrams,_that.makingChargesPerGram,_that.wastagePercent,_that.stoneWeightGrams,_that.stoneCharges,_that.huid,_that.hallmarkNumber,_that.hallmarkDate,_that.assayingCenter,_that.isHallmarked,_that.pricePerGramPaisa,_that.totalMrpPaisa,_that.costPricePaisa,_that.stockQuantity,_that.reorderLevel,_that.unit,_that.gstRate,_that.hsnCode,_that.barcode,_that.sku,_that.s3ImageKey,_that.s3ThumbnailKey,_that.presignedImageUrl,_that.additionalImageKeys,_that.isActive,_that.createdAt,_that.updatedAt,_that.createdBy,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.version,_that.isDeleted,_that.deletedAt,_that.pendingOperation,_that.pendingSince);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String businessType, @HiveField(3)  String name, @HiveField(4)  String? description, @HiveField(5)  String category, @HiveField(6)  String? subCategory, @HiveField(7)  MetalType metalType, @HiveField(8)  PurityStandard? purityStandard, @HiveField(9)  String? purity, @HiveField(10)  double metalWeightGrams, @HiveField(11)  double grossWeightGrams, @HiveField(12)  double netWeightGrams, @HiveField(13)  double makingChargesPerGram, @HiveField(14)  double wastagePercent, @HiveField(15)  double stoneWeightGrams, @HiveField(16)  double stoneCharges, @HiveField(17)  String? huid, @HiveField(18)  String? hallmarkNumber, @HiveField(19)  DateTime? hallmarkDate, @HiveField(20)  String? assayingCenter, @HiveField(21)  bool isHallmarked, @HiveField(22)  int pricePerGramPaisa, @HiveField(23)  int totalMrpPaisa, @HiveField(24)  int? costPricePaisa, @HiveField(25)  int stockQuantity, @HiveField(26)  int reorderLevel, @HiveField(27)  String unit, @HiveField(28)  double gstRate, @HiveField(29)  String? hsnCode, @HiveField(30)  String? barcode, @HiveField(31)  String? sku, @HiveField(32)  String? s3ImageKey, @HiveField(33)  String? s3ThumbnailKey, @HiveField(34)  String? presignedImageUrl, @HiveField(35)  List<String>? additionalImageKeys, @HiveField(36)  bool isActive, @HiveField(37)  DateTime createdAt, @HiveField(38)  DateTime updatedAt, @HiveField(39)  String createdBy, @HiveField(40)  String updatedBy, @HiveField(41)  bool synced, @HiveField(42)  DateTime? lastSyncedAt, @HiveField(43)  int version, @HiveField(44)  bool isDeleted, @HiveField(45)  DateTime? deletedAt, @HiveField(46)  String? pendingOperation, @HiveField(47)  DateTime? pendingSince)?  $default,) {final _that = this;
switch (_that) {
case _JewelleryProduct() when $default != null:
return $default(_that.id,_that.tenantId,_that.businessType,_that.name,_that.description,_that.category,_that.subCategory,_that.metalType,_that.purityStandard,_that.purity,_that.metalWeightGrams,_that.grossWeightGrams,_that.netWeightGrams,_that.makingChargesPerGram,_that.wastagePercent,_that.stoneWeightGrams,_that.stoneCharges,_that.huid,_that.hallmarkNumber,_that.hallmarkDate,_that.assayingCenter,_that.isHallmarked,_that.pricePerGramPaisa,_that.totalMrpPaisa,_that.costPricePaisa,_that.stockQuantity,_that.reorderLevel,_that.unit,_that.gstRate,_that.hsnCode,_that.barcode,_that.sku,_that.s3ImageKey,_that.s3ThumbnailKey,_that.presignedImageUrl,_that.additionalImageKeys,_that.isActive,_that.createdAt,_that.updatedAt,_that.createdBy,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.version,_that.isDeleted,_that.deletedAt,_that.pendingOperation,_that.pendingSince);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 51)
class _JewelleryProduct extends JewelleryProduct {
  const _JewelleryProduct({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) this.businessType = 'jewellery', @HiveField(3) required this.name, @HiveField(4) this.description, @HiveField(5) this.category = 'General', @HiveField(6) this.subCategory, @HiveField(7) this.metalType = MetalType.gold22k, @HiveField(8) this.purityStandard, @HiveField(9) this.purity, @HiveField(10) this.metalWeightGrams = 0.0, @HiveField(11) this.grossWeightGrams = 0.0, @HiveField(12) this.netWeightGrams = 0.0, @HiveField(13) this.makingChargesPerGram = 0, @HiveField(14) this.wastagePercent = 0, @HiveField(15) this.stoneWeightGrams = 0, @HiveField(16) this.stoneCharges = 0, @HiveField(17) this.huid, @HiveField(18) this.hallmarkNumber, @HiveField(19) this.hallmarkDate, @HiveField(20) this.assayingCenter, @HiveField(21) this.isHallmarked = false, @HiveField(22) required this.pricePerGramPaisa, @HiveField(23) required this.totalMrpPaisa, @HiveField(24) this.costPricePaisa, @HiveField(25) this.stockQuantity = 0, @HiveField(26) this.reorderLevel = 5, @HiveField(27) this.unit = 'pcs', @HiveField(28) this.gstRate = 3.0, @HiveField(29) this.hsnCode, @HiveField(30) this.barcode, @HiveField(31) this.sku, @HiveField(32) this.s3ImageKey, @HiveField(33) this.s3ThumbnailKey, @HiveField(34) this.presignedImageUrl, @HiveField(35) final  List<String>? additionalImageKeys, @HiveField(36) this.isActive = true, @HiveField(37) required this.createdAt, @HiveField(38) required this.updatedAt, @HiveField(39) required this.createdBy, @HiveField(40) required this.updatedBy, @HiveField(41) this.synced = true, @HiveField(42) this.lastSyncedAt, @HiveField(43) this.version = 1, @HiveField(44) this.isDeleted = false, @HiveField(45) this.deletedAt, @HiveField(46) this.pendingOperation, @HiveField(47) this.pendingSince}): _additionalImageKeys = additionalImageKeys,super._();
  factory _JewelleryProduct.fromJson(Map<String, dynamic> json) => _$JewelleryProductFromJson(json);

// Core identifiers
@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
@override@JsonKey()@HiveField(2) final  String businessType;
// Basic info
@override@HiveField(3) final  String name;
@override@HiveField(4) final  String? description;
@override@JsonKey()@HiveField(5) final  String category;
@override@HiveField(6) final  String? subCategory;
// Ring, Necklace, Bracelet, etc.
// Jewellery-specific fields
@override@JsonKey()@HiveField(7) final  MetalType metalType;
@override@HiveField(8) final  PurityStandard? purityStandard;
@override@HiveField(9) final  String? purity;
// Free-text purity if not standard
@override@JsonKey()@HiveField(10) final  double metalWeightGrams;
@override@JsonKey()@HiveField(11) final  double grossWeightGrams;
// Including stones
@override@JsonKey()@HiveField(12) final  double netWeightGrams;
// Metal only
@override@JsonKey()@HiveField(13) final  double makingChargesPerGram;
// In rupees
@override@JsonKey()@HiveField(14) final  double wastagePercent;
@override@JsonKey()@HiveField(15) final  double stoneWeightGrams;
@override@JsonKey()@HiveField(16) final  double stoneCharges;
// In rupees
// Hallmark (HUID) - 6 digit unique ID
@override@HiveField(17) final  String? huid;
// Hallmark Unique ID
@override@HiveField(18) final  String? hallmarkNumber;
@override@HiveField(19) final  DateTime? hallmarkDate;
@override@HiveField(20) final  String? assayingCenter;
@override@JsonKey()@HiveField(21) final  bool isHallmarked;
// Pricing (stored in paise for precision)
@override@HiveField(22) final  int pricePerGramPaisa;
// Metal rate at time of creation
@override@HiveField(23) final  int totalMrpPaisa;
// Final MRP including all charges
@override@HiveField(24) final  int? costPricePaisa;
// Purchase cost
// Stock
@override@JsonKey()@HiveField(25) final  int stockQuantity;
@override@JsonKey()@HiveField(26) final  int reorderLevel;
@override@JsonKey()@HiveField(27) final  String unit;
// GST - 3% for jewellery
@override@JsonKey()@HiveField(28) final  double gstRate;
@override@HiveField(29) final  String? hsnCode;
// Barcode/SKU
@override@HiveField(30) final  String? barcode;
@override@HiveField(31) final  String? sku;
// Images
@override@HiveField(32) final  String? s3ImageKey;
@override@HiveField(33) final  String? s3ThumbnailKey;
@override@HiveField(34) final  String? presignedImageUrl;
 final  List<String>? _additionalImageKeys;
@override@HiveField(35) List<String>? get additionalImageKeys {
  final value = _additionalImageKeys;
  if (value == null) return null;
  if (_additionalImageKeys is EqualUnmodifiableListView) return _additionalImageKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Metadata
@override@JsonKey()@HiveField(36) final  bool isActive;
@override@HiveField(37) final  DateTime createdAt;
@override@HiveField(38) final  DateTime updatedAt;
@override@HiveField(39) final  String createdBy;
@override@HiveField(40) final  String updatedBy;
// Sync tracking for offline
@override@JsonKey()@HiveField(41) final  bool synced;
@override@HiveField(42) final  DateTime? lastSyncedAt;
@override@JsonKey()@HiveField(43) final  int version;
// Soft delete
@override@JsonKey()@HiveField(44) final  bool isDeleted;
@override@HiveField(45) final  DateTime? deletedAt;
// Offline operation tracking
@override@HiveField(46) final  String? pendingOperation;
// 'create', 'update', 'delete'
@override@HiveField(47) final  DateTime? pendingSince;

/// Create a copy of JewelleryProduct
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JewelleryProductCopyWith<_JewelleryProduct> get copyWith => __$JewelleryProductCopyWithImpl<_JewelleryProduct>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JewelleryProductToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JewelleryProduct&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.businessType, businessType) || other.businessType == businessType)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.subCategory, subCategory) || other.subCategory == subCategory)&&(identical(other.metalType, metalType) || other.metalType == metalType)&&(identical(other.purityStandard, purityStandard) || other.purityStandard == purityStandard)&&(identical(other.purity, purity) || other.purity == purity)&&(identical(other.metalWeightGrams, metalWeightGrams) || other.metalWeightGrams == metalWeightGrams)&&(identical(other.grossWeightGrams, grossWeightGrams) || other.grossWeightGrams == grossWeightGrams)&&(identical(other.netWeightGrams, netWeightGrams) || other.netWeightGrams == netWeightGrams)&&(identical(other.makingChargesPerGram, makingChargesPerGram) || other.makingChargesPerGram == makingChargesPerGram)&&(identical(other.wastagePercent, wastagePercent) || other.wastagePercent == wastagePercent)&&(identical(other.stoneWeightGrams, stoneWeightGrams) || other.stoneWeightGrams == stoneWeightGrams)&&(identical(other.stoneCharges, stoneCharges) || other.stoneCharges == stoneCharges)&&(identical(other.huid, huid) || other.huid == huid)&&(identical(other.hallmarkNumber, hallmarkNumber) || other.hallmarkNumber == hallmarkNumber)&&(identical(other.hallmarkDate, hallmarkDate) || other.hallmarkDate == hallmarkDate)&&(identical(other.assayingCenter, assayingCenter) || other.assayingCenter == assayingCenter)&&(identical(other.isHallmarked, isHallmarked) || other.isHallmarked == isHallmarked)&&(identical(other.pricePerGramPaisa, pricePerGramPaisa) || other.pricePerGramPaisa == pricePerGramPaisa)&&(identical(other.totalMrpPaisa, totalMrpPaisa) || other.totalMrpPaisa == totalMrpPaisa)&&(identical(other.costPricePaisa, costPricePaisa) || other.costPricePaisa == costPricePaisa)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.gstRate, gstRate) || other.gstRate == gstRate)&&(identical(other.hsnCode, hsnCode) || other.hsnCode == hsnCode)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.s3ImageKey, s3ImageKey) || other.s3ImageKey == s3ImageKey)&&(identical(other.s3ThumbnailKey, s3ThumbnailKey) || other.s3ThumbnailKey == s3ThumbnailKey)&&(identical(other.presignedImageUrl, presignedImageUrl) || other.presignedImageUrl == presignedImageUrl)&&const DeepCollectionEquality().equals(other._additionalImageKeys, _additionalImageKeys)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.version, version) || other.version == version)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation)&&(identical(other.pendingSince, pendingSince) || other.pendingSince == pendingSince));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,businessType,name,description,category,subCategory,metalType,purityStandard,purity,metalWeightGrams,grossWeightGrams,netWeightGrams,makingChargesPerGram,wastagePercent,stoneWeightGrams,stoneCharges,huid,hallmarkNumber,hallmarkDate,assayingCenter,isHallmarked,pricePerGramPaisa,totalMrpPaisa,costPricePaisa,stockQuantity,reorderLevel,unit,gstRate,hsnCode,barcode,sku,s3ImageKey,s3ThumbnailKey,presignedImageUrl,const DeepCollectionEquality().hash(_additionalImageKeys),isActive,createdAt,updatedAt,createdBy,updatedBy,synced,lastSyncedAt,version,isDeleted,deletedAt,pendingOperation,pendingSince]);

@override
String toString() {
  return 'JewelleryProduct(id: $id, tenantId: $tenantId, businessType: $businessType, name: $name, description: $description, category: $category, subCategory: $subCategory, metalType: $metalType, purityStandard: $purityStandard, purity: $purity, metalWeightGrams: $metalWeightGrams, grossWeightGrams: $grossWeightGrams, netWeightGrams: $netWeightGrams, makingChargesPerGram: $makingChargesPerGram, wastagePercent: $wastagePercent, stoneWeightGrams: $stoneWeightGrams, stoneCharges: $stoneCharges, huid: $huid, hallmarkNumber: $hallmarkNumber, hallmarkDate: $hallmarkDate, assayingCenter: $assayingCenter, isHallmarked: $isHallmarked, pricePerGramPaisa: $pricePerGramPaisa, totalMrpPaisa: $totalMrpPaisa, costPricePaisa: $costPricePaisa, stockQuantity: $stockQuantity, reorderLevel: $reorderLevel, unit: $unit, gstRate: $gstRate, hsnCode: $hsnCode, barcode: $barcode, sku: $sku, s3ImageKey: $s3ImageKey, s3ThumbnailKey: $s3ThumbnailKey, presignedImageUrl: $presignedImageUrl, additionalImageKeys: $additionalImageKeys, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, version: $version, isDeleted: $isDeleted, deletedAt: $deletedAt, pendingOperation: $pendingOperation, pendingSince: $pendingSince)';
}


}

/// @nodoc
abstract mixin class _$JewelleryProductCopyWith<$Res> implements $JewelleryProductCopyWith<$Res> {
  factory _$JewelleryProductCopyWith(_JewelleryProduct value, $Res Function(_JewelleryProduct) _then) = __$JewelleryProductCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String businessType,@HiveField(3) String name,@HiveField(4) String? description,@HiveField(5) String category,@HiveField(6) String? subCategory,@HiveField(7) MetalType metalType,@HiveField(8) PurityStandard? purityStandard,@HiveField(9) String? purity,@HiveField(10) double metalWeightGrams,@HiveField(11) double grossWeightGrams,@HiveField(12) double netWeightGrams,@HiveField(13) double makingChargesPerGram,@HiveField(14) double wastagePercent,@HiveField(15) double stoneWeightGrams,@HiveField(16) double stoneCharges,@HiveField(17) String? huid,@HiveField(18) String? hallmarkNumber,@HiveField(19) DateTime? hallmarkDate,@HiveField(20) String? assayingCenter,@HiveField(21) bool isHallmarked,@HiveField(22) int pricePerGramPaisa,@HiveField(23) int totalMrpPaisa,@HiveField(24) int? costPricePaisa,@HiveField(25) int stockQuantity,@HiveField(26) int reorderLevel,@HiveField(27) String unit,@HiveField(28) double gstRate,@HiveField(29) String? hsnCode,@HiveField(30) String? barcode,@HiveField(31) String? sku,@HiveField(32) String? s3ImageKey,@HiveField(33) String? s3ThumbnailKey,@HiveField(34) String? presignedImageUrl,@HiveField(35) List<String>? additionalImageKeys,@HiveField(36) bool isActive,@HiveField(37) DateTime createdAt,@HiveField(38) DateTime updatedAt,@HiveField(39) String createdBy,@HiveField(40) String updatedBy,@HiveField(41) bool synced,@HiveField(42) DateTime? lastSyncedAt,@HiveField(43) int version,@HiveField(44) bool isDeleted,@HiveField(45) DateTime? deletedAt,@HiveField(46) String? pendingOperation,@HiveField(47) DateTime? pendingSince
});




}
/// @nodoc
class __$JewelleryProductCopyWithImpl<$Res>
    implements _$JewelleryProductCopyWith<$Res> {
  __$JewelleryProductCopyWithImpl(this._self, this._then);

  final _JewelleryProduct _self;
  final $Res Function(_JewelleryProduct) _then;

/// Create a copy of JewelleryProduct
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? businessType = null,Object? name = null,Object? description = freezed,Object? category = null,Object? subCategory = freezed,Object? metalType = null,Object? purityStandard = freezed,Object? purity = freezed,Object? metalWeightGrams = null,Object? grossWeightGrams = null,Object? netWeightGrams = null,Object? makingChargesPerGram = null,Object? wastagePercent = null,Object? stoneWeightGrams = null,Object? stoneCharges = null,Object? huid = freezed,Object? hallmarkNumber = freezed,Object? hallmarkDate = freezed,Object? assayingCenter = freezed,Object? isHallmarked = null,Object? pricePerGramPaisa = null,Object? totalMrpPaisa = null,Object? costPricePaisa = freezed,Object? stockQuantity = null,Object? reorderLevel = null,Object? unit = null,Object? gstRate = null,Object? hsnCode = freezed,Object? barcode = freezed,Object? sku = freezed,Object? s3ImageKey = freezed,Object? s3ThumbnailKey = freezed,Object? presignedImageUrl = freezed,Object? additionalImageKeys = freezed,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,Object? createdBy = null,Object? updatedBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? version = null,Object? isDeleted = null,Object? deletedAt = freezed,Object? pendingOperation = freezed,Object? pendingSince = freezed,}) {
  return _then(_JewelleryProduct(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,businessType: null == businessType ? _self.businessType : businessType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,subCategory: freezed == subCategory ? _self.subCategory : subCategory // ignore: cast_nullable_to_non_nullable
as String?,metalType: null == metalType ? _self.metalType : metalType // ignore: cast_nullable_to_non_nullable
as MetalType,purityStandard: freezed == purityStandard ? _self.purityStandard : purityStandard // ignore: cast_nullable_to_non_nullable
as PurityStandard?,purity: freezed == purity ? _self.purity : purity // ignore: cast_nullable_to_non_nullable
as String?,metalWeightGrams: null == metalWeightGrams ? _self.metalWeightGrams : metalWeightGrams // ignore: cast_nullable_to_non_nullable
as double,grossWeightGrams: null == grossWeightGrams ? _self.grossWeightGrams : grossWeightGrams // ignore: cast_nullable_to_non_nullable
as double,netWeightGrams: null == netWeightGrams ? _self.netWeightGrams : netWeightGrams // ignore: cast_nullable_to_non_nullable
as double,makingChargesPerGram: null == makingChargesPerGram ? _self.makingChargesPerGram : makingChargesPerGram // ignore: cast_nullable_to_non_nullable
as double,wastagePercent: null == wastagePercent ? _self.wastagePercent : wastagePercent // ignore: cast_nullable_to_non_nullable
as double,stoneWeightGrams: null == stoneWeightGrams ? _self.stoneWeightGrams : stoneWeightGrams // ignore: cast_nullable_to_non_nullable
as double,stoneCharges: null == stoneCharges ? _self.stoneCharges : stoneCharges // ignore: cast_nullable_to_non_nullable
as double,huid: freezed == huid ? _self.huid : huid // ignore: cast_nullable_to_non_nullable
as String?,hallmarkNumber: freezed == hallmarkNumber ? _self.hallmarkNumber : hallmarkNumber // ignore: cast_nullable_to_non_nullable
as String?,hallmarkDate: freezed == hallmarkDate ? _self.hallmarkDate : hallmarkDate // ignore: cast_nullable_to_non_nullable
as DateTime?,assayingCenter: freezed == assayingCenter ? _self.assayingCenter : assayingCenter // ignore: cast_nullable_to_non_nullable
as String?,isHallmarked: null == isHallmarked ? _self.isHallmarked : isHallmarked // ignore: cast_nullable_to_non_nullable
as bool,pricePerGramPaisa: null == pricePerGramPaisa ? _self.pricePerGramPaisa : pricePerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,totalMrpPaisa: null == totalMrpPaisa ? _self.totalMrpPaisa : totalMrpPaisa // ignore: cast_nullable_to_non_nullable
as int,costPricePaisa: freezed == costPricePaisa ? _self.costPricePaisa : costPricePaisa // ignore: cast_nullable_to_non_nullable
as int?,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,reorderLevel: null == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,gstRate: null == gstRate ? _self.gstRate : gstRate // ignore: cast_nullable_to_non_nullable
as double,hsnCode: freezed == hsnCode ? _self.hsnCode : hsnCode // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,s3ImageKey: freezed == s3ImageKey ? _self.s3ImageKey : s3ImageKey // ignore: cast_nullable_to_non_nullable
as String?,s3ThumbnailKey: freezed == s3ThumbnailKey ? _self.s3ThumbnailKey : s3ThumbnailKey // ignore: cast_nullable_to_non_nullable
as String?,presignedImageUrl: freezed == presignedImageUrl ? _self.presignedImageUrl : presignedImageUrl // ignore: cast_nullable_to_non_nullable
as String?,additionalImageKeys: freezed == additionalImageKeys ? _self._additionalImageKeys : additionalImageKeys // ignore: cast_nullable_to_non_nullable
as List<String>?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,pendingSince: freezed == pendingSince ? _self.pendingSince : pendingSince // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$GoldRateCard {

@HiveField(0) String get id;@HiveField(1) String get tenantId;@HiveField(2) String get date;// YYYY-MM-DD
@HiveField(3) int get gold24KPer10gPaisa;@HiveField(4) int get gold22KPer10gPaisa;@HiveField(5) int get gold18KPer10gPaisa;@HiveField(6) int get silverPerKgPaisa;@HiveField(7) int get platinumPerGramPaisa;@HiveField(8) String get source;// MANUAL, API, BANK
@HiveField(9) String? get notes;@HiveField(10) DateTime get createdAt;@HiveField(11) String get createdBy;@HiveField(12) bool get synced;@HiveField(13) DateTime? get lastSyncedAt;@HiveField(14) String? get pendingOperation;
/// Create a copy of GoldRateCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoldRateCardCopyWith<GoldRateCard> get copyWith => _$GoldRateCardCopyWithImpl<GoldRateCard>(this as GoldRateCard, _$identity);

  /// Serializes this GoldRateCard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoldRateCard&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.date, date) || other.date == date)&&(identical(other.gold24KPer10gPaisa, gold24KPer10gPaisa) || other.gold24KPer10gPaisa == gold24KPer10gPaisa)&&(identical(other.gold22KPer10gPaisa, gold22KPer10gPaisa) || other.gold22KPer10gPaisa == gold22KPer10gPaisa)&&(identical(other.gold18KPer10gPaisa, gold18KPer10gPaisa) || other.gold18KPer10gPaisa == gold18KPer10gPaisa)&&(identical(other.silverPerKgPaisa, silverPerKgPaisa) || other.silverPerKgPaisa == silverPerKgPaisa)&&(identical(other.platinumPerGramPaisa, platinumPerGramPaisa) || other.platinumPerGramPaisa == platinumPerGramPaisa)&&(identical(other.source, source) || other.source == source)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,date,gold24KPer10gPaisa,gold22KPer10gPaisa,gold18KPer10gPaisa,silverPerKgPaisa,platinumPerGramPaisa,source,notes,createdAt,createdBy,synced,lastSyncedAt,pendingOperation);

@override
String toString() {
  return 'GoldRateCard(id: $id, tenantId: $tenantId, date: $date, gold24KPer10gPaisa: $gold24KPer10gPaisa, gold22KPer10gPaisa: $gold22KPer10gPaisa, gold18KPer10gPaisa: $gold18KPer10gPaisa, silverPerKgPaisa: $silverPerKgPaisa, platinumPerGramPaisa: $platinumPerGramPaisa, source: $source, notes: $notes, createdAt: $createdAt, createdBy: $createdBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class $GoldRateCardCopyWith<$Res>  {
  factory $GoldRateCardCopyWith(GoldRateCard value, $Res Function(GoldRateCard) _then) = _$GoldRateCardCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String date,@HiveField(3) int gold24KPer10gPaisa,@HiveField(4) int gold22KPer10gPaisa,@HiveField(5) int gold18KPer10gPaisa,@HiveField(6) int silverPerKgPaisa,@HiveField(7) int platinumPerGramPaisa,@HiveField(8) String source,@HiveField(9) String? notes,@HiveField(10) DateTime createdAt,@HiveField(11) String createdBy,@HiveField(12) bool synced,@HiveField(13) DateTime? lastSyncedAt,@HiveField(14) String? pendingOperation
});




}
/// @nodoc
class _$GoldRateCardCopyWithImpl<$Res>
    implements $GoldRateCardCopyWith<$Res> {
  _$GoldRateCardCopyWithImpl(this._self, this._then);

  final GoldRateCard _self;
  final $Res Function(GoldRateCard) _then;

/// Create a copy of GoldRateCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? date = null,Object? gold24KPer10gPaisa = null,Object? gold22KPer10gPaisa = null,Object? gold18KPer10gPaisa = null,Object? silverPerKgPaisa = null,Object? platinumPerGramPaisa = null,Object? source = null,Object? notes = freezed,Object? createdAt = null,Object? createdBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,gold24KPer10gPaisa: null == gold24KPer10gPaisa ? _self.gold24KPer10gPaisa : gold24KPer10gPaisa // ignore: cast_nullable_to_non_nullable
as int,gold22KPer10gPaisa: null == gold22KPer10gPaisa ? _self.gold22KPer10gPaisa : gold22KPer10gPaisa // ignore: cast_nullable_to_non_nullable
as int,gold18KPer10gPaisa: null == gold18KPer10gPaisa ? _self.gold18KPer10gPaisa : gold18KPer10gPaisa // ignore: cast_nullable_to_non_nullable
as int,silverPerKgPaisa: null == silverPerKgPaisa ? _self.silverPerKgPaisa : silverPerKgPaisa // ignore: cast_nullable_to_non_nullable
as int,platinumPerGramPaisa: null == platinumPerGramPaisa ? _self.platinumPerGramPaisa : platinumPerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoldRateCard].
extension GoldRateCardPatterns on GoldRateCard {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoldRateCard value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoldRateCard() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoldRateCard value)  $default,){
final _that = this;
switch (_that) {
case _GoldRateCard():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoldRateCard value)?  $default,){
final _that = this;
switch (_that) {
case _GoldRateCard() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String date, @HiveField(3)  int gold24KPer10gPaisa, @HiveField(4)  int gold22KPer10gPaisa, @HiveField(5)  int gold18KPer10gPaisa, @HiveField(6)  int silverPerKgPaisa, @HiveField(7)  int platinumPerGramPaisa, @HiveField(8)  String source, @HiveField(9)  String? notes, @HiveField(10)  DateTime createdAt, @HiveField(11)  String createdBy, @HiveField(12)  bool synced, @HiveField(13)  DateTime? lastSyncedAt, @HiveField(14)  String? pendingOperation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoldRateCard() when $default != null:
return $default(_that.id,_that.tenantId,_that.date,_that.gold24KPer10gPaisa,_that.gold22KPer10gPaisa,_that.gold18KPer10gPaisa,_that.silverPerKgPaisa,_that.platinumPerGramPaisa,_that.source,_that.notes,_that.createdAt,_that.createdBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String date, @HiveField(3)  int gold24KPer10gPaisa, @HiveField(4)  int gold22KPer10gPaisa, @HiveField(5)  int gold18KPer10gPaisa, @HiveField(6)  int silverPerKgPaisa, @HiveField(7)  int platinumPerGramPaisa, @HiveField(8)  String source, @HiveField(9)  String? notes, @HiveField(10)  DateTime createdAt, @HiveField(11)  String createdBy, @HiveField(12)  bool synced, @HiveField(13)  DateTime? lastSyncedAt, @HiveField(14)  String? pendingOperation)  $default,) {final _that = this;
switch (_that) {
case _GoldRateCard():
return $default(_that.id,_that.tenantId,_that.date,_that.gold24KPer10gPaisa,_that.gold22KPer10gPaisa,_that.gold18KPer10gPaisa,_that.silverPerKgPaisa,_that.platinumPerGramPaisa,_that.source,_that.notes,_that.createdAt,_that.createdBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String date, @HiveField(3)  int gold24KPer10gPaisa, @HiveField(4)  int gold22KPer10gPaisa, @HiveField(5)  int gold18KPer10gPaisa, @HiveField(6)  int silverPerKgPaisa, @HiveField(7)  int platinumPerGramPaisa, @HiveField(8)  String source, @HiveField(9)  String? notes, @HiveField(10)  DateTime createdAt, @HiveField(11)  String createdBy, @HiveField(12)  bool synced, @HiveField(13)  DateTime? lastSyncedAt, @HiveField(14)  String? pendingOperation)?  $default,) {final _that = this;
switch (_that) {
case _GoldRateCard() when $default != null:
return $default(_that.id,_that.tenantId,_that.date,_that.gold24KPer10gPaisa,_that.gold22KPer10gPaisa,_that.gold18KPer10gPaisa,_that.silverPerKgPaisa,_that.platinumPerGramPaisa,_that.source,_that.notes,_that.createdAt,_that.createdBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 52)
class _GoldRateCard extends GoldRateCard {
  const _GoldRateCard({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.date, @HiveField(3) required this.gold24KPer10gPaisa, @HiveField(4) required this.gold22KPer10gPaisa, @HiveField(5) required this.gold18KPer10gPaisa, @HiveField(6) required this.silverPerKgPaisa, @HiveField(7) required this.platinumPerGramPaisa, @HiveField(8) this.source = 'MANUAL', @HiveField(9) this.notes, @HiveField(10) required this.createdAt, @HiveField(11) required this.createdBy, @HiveField(12) this.synced = true, @HiveField(13) this.lastSyncedAt, @HiveField(14) this.pendingOperation}): super._();
  factory _GoldRateCard.fromJson(Map<String, dynamic> json) => _$GoldRateCardFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
@override@HiveField(2) final  String date;
// YYYY-MM-DD
@override@HiveField(3) final  int gold24KPer10gPaisa;
@override@HiveField(4) final  int gold22KPer10gPaisa;
@override@HiveField(5) final  int gold18KPer10gPaisa;
@override@HiveField(6) final  int silverPerKgPaisa;
@override@HiveField(7) final  int platinumPerGramPaisa;
@override@JsonKey()@HiveField(8) final  String source;
// MANUAL, API, BANK
@override@HiveField(9) final  String? notes;
@override@HiveField(10) final  DateTime createdAt;
@override@HiveField(11) final  String createdBy;
@override@JsonKey()@HiveField(12) final  bool synced;
@override@HiveField(13) final  DateTime? lastSyncedAt;
@override@HiveField(14) final  String? pendingOperation;

/// Create a copy of GoldRateCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoldRateCardCopyWith<_GoldRateCard> get copyWith => __$GoldRateCardCopyWithImpl<_GoldRateCard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoldRateCardToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoldRateCard&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.date, date) || other.date == date)&&(identical(other.gold24KPer10gPaisa, gold24KPer10gPaisa) || other.gold24KPer10gPaisa == gold24KPer10gPaisa)&&(identical(other.gold22KPer10gPaisa, gold22KPer10gPaisa) || other.gold22KPer10gPaisa == gold22KPer10gPaisa)&&(identical(other.gold18KPer10gPaisa, gold18KPer10gPaisa) || other.gold18KPer10gPaisa == gold18KPer10gPaisa)&&(identical(other.silverPerKgPaisa, silverPerKgPaisa) || other.silverPerKgPaisa == silverPerKgPaisa)&&(identical(other.platinumPerGramPaisa, platinumPerGramPaisa) || other.platinumPerGramPaisa == platinumPerGramPaisa)&&(identical(other.source, source) || other.source == source)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,date,gold24KPer10gPaisa,gold22KPer10gPaisa,gold18KPer10gPaisa,silverPerKgPaisa,platinumPerGramPaisa,source,notes,createdAt,createdBy,synced,lastSyncedAt,pendingOperation);

@override
String toString() {
  return 'GoldRateCard(id: $id, tenantId: $tenantId, date: $date, gold24KPer10gPaisa: $gold24KPer10gPaisa, gold22KPer10gPaisa: $gold22KPer10gPaisa, gold18KPer10gPaisa: $gold18KPer10gPaisa, silverPerKgPaisa: $silverPerKgPaisa, platinumPerGramPaisa: $platinumPerGramPaisa, source: $source, notes: $notes, createdAt: $createdAt, createdBy: $createdBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class _$GoldRateCardCopyWith<$Res> implements $GoldRateCardCopyWith<$Res> {
  factory _$GoldRateCardCopyWith(_GoldRateCard value, $Res Function(_GoldRateCard) _then) = __$GoldRateCardCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String date,@HiveField(3) int gold24KPer10gPaisa,@HiveField(4) int gold22KPer10gPaisa,@HiveField(5) int gold18KPer10gPaisa,@HiveField(6) int silverPerKgPaisa,@HiveField(7) int platinumPerGramPaisa,@HiveField(8) String source,@HiveField(9) String? notes,@HiveField(10) DateTime createdAt,@HiveField(11) String createdBy,@HiveField(12) bool synced,@HiveField(13) DateTime? lastSyncedAt,@HiveField(14) String? pendingOperation
});




}
/// @nodoc
class __$GoldRateCardCopyWithImpl<$Res>
    implements _$GoldRateCardCopyWith<$Res> {
  __$GoldRateCardCopyWithImpl(this._self, this._then);

  final _GoldRateCard _self;
  final $Res Function(_GoldRateCard) _then;

/// Create a copy of GoldRateCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? date = null,Object? gold24KPer10gPaisa = null,Object? gold22KPer10gPaisa = null,Object? gold18KPer10gPaisa = null,Object? silverPerKgPaisa = null,Object? platinumPerGramPaisa = null,Object? source = null,Object? notes = freezed,Object? createdAt = null,Object? createdBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_GoldRateCard(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,gold24KPer10gPaisa: null == gold24KPer10gPaisa ? _self.gold24KPer10gPaisa : gold24KPer10gPaisa // ignore: cast_nullable_to_non_nullable
as int,gold22KPer10gPaisa: null == gold22KPer10gPaisa ? _self.gold22KPer10gPaisa : gold22KPer10gPaisa // ignore: cast_nullable_to_non_nullable
as int,gold18KPer10gPaisa: null == gold18KPer10gPaisa ? _self.gold18KPer10gPaisa : gold18KPer10gPaisa // ignore: cast_nullable_to_non_nullable
as int,silverPerKgPaisa: null == silverPerKgPaisa ? _self.silverPerKgPaisa : silverPerKgPaisa // ignore: cast_nullable_to_non_nullable
as int,platinumPerGramPaisa: null == platinumPerGramPaisa ? _self.platinumPerGramPaisa : platinumPerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OldGoldExchange {

@HiveField(0) String get id;@HiveField(1) String get tenantId;@HiveField(2) String get customerId;@HiveField(3) String get customerName;@HiveField(4) String? get customerPhone;// PML Act KYC Fields
@HiveField(5) String get customerIdType;// AADHAAR, PAN, PASSPORT, VOTER_ID
@HiveField(6) String get customerIdNumber;@HiveField(7) String? get customerPhotoUrl;@HiveField(8) String? get idDocumentUrl;// Old gold details
@HiveField(9) MetalType get oldGoldMetalType;@HiveField(10) double get oldGoldWeightGrams;@HiveField(11) int get oldGoldValuePaisa;// Calculated value
@HiveField(12) int get oldGoldRatePerGramPaisa;// Rate at exchange time
// Purity verification
@HiveField(13) String? get purityTestMethod;// XRF, ACID, TOUCHSTONE
@HiveField(14) double? get actualPurityPercentage;@HiveField(15) String? get purityTestReportUrl;// New item details (if exchanging)
@HiveField(16) String? get newItemDescription;@HiveField(17) MetalType? get newItemMetalType;@HiveField(18) double? get newItemWeightGrams;@HiveField(19) int? get newItemTotalPaisa; String? get newItemInvoiceId;// Exchange calculation
@HiveField(20) int get exchangeValuePaisa;@HiveField(21) int get cashAdjustmentPaisa;// Positive = customer pays
// Status
@HiveField(23) String get status;// PENDING, VERIFIED, COMPLETED, CANCELLED
@HiveField(24) String? get verifiedBy;@HiveField(25) DateTime? get verifiedAt;// Metadata
@HiveField(26) DateTime get createdAt;@HiveField(27) String get createdBy;@HiveField(28) bool get synced;@HiveField(29) DateTime? get lastSyncedAt;@HiveField(30) String? get pendingOperation;// PML Act compliance tracking
@HiveField(31) bool get pmlCompliant;@HiveField(32) String? get complianceNotes;
/// Create a copy of OldGoldExchange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OldGoldExchangeCopyWith<OldGoldExchange> get copyWith => _$OldGoldExchangeCopyWithImpl<OldGoldExchange>(this as OldGoldExchange, _$identity);

  /// Serializes this OldGoldExchange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OldGoldExchange&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerIdType, customerIdType) || other.customerIdType == customerIdType)&&(identical(other.customerIdNumber, customerIdNumber) || other.customerIdNumber == customerIdNumber)&&(identical(other.customerPhotoUrl, customerPhotoUrl) || other.customerPhotoUrl == customerPhotoUrl)&&(identical(other.idDocumentUrl, idDocumentUrl) || other.idDocumentUrl == idDocumentUrl)&&(identical(other.oldGoldMetalType, oldGoldMetalType) || other.oldGoldMetalType == oldGoldMetalType)&&(identical(other.oldGoldWeightGrams, oldGoldWeightGrams) || other.oldGoldWeightGrams == oldGoldWeightGrams)&&(identical(other.oldGoldValuePaisa, oldGoldValuePaisa) || other.oldGoldValuePaisa == oldGoldValuePaisa)&&(identical(other.oldGoldRatePerGramPaisa, oldGoldRatePerGramPaisa) || other.oldGoldRatePerGramPaisa == oldGoldRatePerGramPaisa)&&(identical(other.purityTestMethod, purityTestMethod) || other.purityTestMethod == purityTestMethod)&&(identical(other.actualPurityPercentage, actualPurityPercentage) || other.actualPurityPercentage == actualPurityPercentage)&&(identical(other.purityTestReportUrl, purityTestReportUrl) || other.purityTestReportUrl == purityTestReportUrl)&&(identical(other.newItemDescription, newItemDescription) || other.newItemDescription == newItemDescription)&&(identical(other.newItemMetalType, newItemMetalType) || other.newItemMetalType == newItemMetalType)&&(identical(other.newItemWeightGrams, newItemWeightGrams) || other.newItemWeightGrams == newItemWeightGrams)&&(identical(other.newItemTotalPaisa, newItemTotalPaisa) || other.newItemTotalPaisa == newItemTotalPaisa)&&(identical(other.newItemInvoiceId, newItemInvoiceId) || other.newItemInvoiceId == newItemInvoiceId)&&(identical(other.exchangeValuePaisa, exchangeValuePaisa) || other.exchangeValuePaisa == exchangeValuePaisa)&&(identical(other.cashAdjustmentPaisa, cashAdjustmentPaisa) || other.cashAdjustmentPaisa == cashAdjustmentPaisa)&&(identical(other.status, status) || other.status == status)&&(identical(other.verifiedBy, verifiedBy) || other.verifiedBy == verifiedBy)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation)&&(identical(other.pmlCompliant, pmlCompliant) || other.pmlCompliant == pmlCompliant)&&(identical(other.complianceNotes, complianceNotes) || other.complianceNotes == complianceNotes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,customerId,customerName,customerPhone,customerIdType,customerIdNumber,customerPhotoUrl,idDocumentUrl,oldGoldMetalType,oldGoldWeightGrams,oldGoldValuePaisa,oldGoldRatePerGramPaisa,purityTestMethod,actualPurityPercentage,purityTestReportUrl,newItemDescription,newItemMetalType,newItemWeightGrams,newItemTotalPaisa,newItemInvoiceId,exchangeValuePaisa,cashAdjustmentPaisa,status,verifiedBy,verifiedAt,createdAt,createdBy,synced,lastSyncedAt,pendingOperation,pmlCompliant,complianceNotes]);

@override
String toString() {
  return 'OldGoldExchange(id: $id, tenantId: $tenantId, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, customerIdType: $customerIdType, customerIdNumber: $customerIdNumber, customerPhotoUrl: $customerPhotoUrl, idDocumentUrl: $idDocumentUrl, oldGoldMetalType: $oldGoldMetalType, oldGoldWeightGrams: $oldGoldWeightGrams, oldGoldValuePaisa: $oldGoldValuePaisa, oldGoldRatePerGramPaisa: $oldGoldRatePerGramPaisa, purityTestMethod: $purityTestMethod, actualPurityPercentage: $actualPurityPercentage, purityTestReportUrl: $purityTestReportUrl, newItemDescription: $newItemDescription, newItemMetalType: $newItemMetalType, newItemWeightGrams: $newItemWeightGrams, newItemTotalPaisa: $newItemTotalPaisa, newItemInvoiceId: $newItemInvoiceId, exchangeValuePaisa: $exchangeValuePaisa, cashAdjustmentPaisa: $cashAdjustmentPaisa, status: $status, verifiedBy: $verifiedBy, verifiedAt: $verifiedAt, createdAt: $createdAt, createdBy: $createdBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation, pmlCompliant: $pmlCompliant, complianceNotes: $complianceNotes)';
}


}

/// @nodoc
abstract mixin class $OldGoldExchangeCopyWith<$Res>  {
  factory $OldGoldExchangeCopyWith(OldGoldExchange value, $Res Function(OldGoldExchange) _then) = _$OldGoldExchangeCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String customerId,@HiveField(3) String customerName,@HiveField(4) String? customerPhone,@HiveField(5) String customerIdType,@HiveField(6) String customerIdNumber,@HiveField(7) String? customerPhotoUrl,@HiveField(8) String? idDocumentUrl,@HiveField(9) MetalType oldGoldMetalType,@HiveField(10) double oldGoldWeightGrams,@HiveField(11) int oldGoldValuePaisa,@HiveField(12) int oldGoldRatePerGramPaisa,@HiveField(13) String? purityTestMethod,@HiveField(14) double? actualPurityPercentage,@HiveField(15) String? purityTestReportUrl,@HiveField(16) String? newItemDescription,@HiveField(17) MetalType? newItemMetalType,@HiveField(18) double? newItemWeightGrams,@HiveField(19) int? newItemTotalPaisa, String? newItemInvoiceId,@HiveField(20) int exchangeValuePaisa,@HiveField(21) int cashAdjustmentPaisa,@HiveField(23) String status,@HiveField(24) String? verifiedBy,@HiveField(25) DateTime? verifiedAt,@HiveField(26) DateTime createdAt,@HiveField(27) String createdBy,@HiveField(28) bool synced,@HiveField(29) DateTime? lastSyncedAt,@HiveField(30) String? pendingOperation,@HiveField(31) bool pmlCompliant,@HiveField(32) String? complianceNotes
});




}
/// @nodoc
class _$OldGoldExchangeCopyWithImpl<$Res>
    implements $OldGoldExchangeCopyWith<$Res> {
  _$OldGoldExchangeCopyWithImpl(this._self, this._then);

  final OldGoldExchange _self;
  final $Res Function(OldGoldExchange) _then;

/// Create a copy of OldGoldExchange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? customerId = null,Object? customerName = null,Object? customerPhone = freezed,Object? customerIdType = null,Object? customerIdNumber = null,Object? customerPhotoUrl = freezed,Object? idDocumentUrl = freezed,Object? oldGoldMetalType = null,Object? oldGoldWeightGrams = null,Object? oldGoldValuePaisa = null,Object? oldGoldRatePerGramPaisa = null,Object? purityTestMethod = freezed,Object? actualPurityPercentage = freezed,Object? purityTestReportUrl = freezed,Object? newItemDescription = freezed,Object? newItemMetalType = freezed,Object? newItemWeightGrams = freezed,Object? newItemTotalPaisa = freezed,Object? newItemInvoiceId = freezed,Object? exchangeValuePaisa = null,Object? cashAdjustmentPaisa = null,Object? status = null,Object? verifiedBy = freezed,Object? verifiedAt = freezed,Object? createdAt = null,Object? createdBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,Object? pmlCompliant = null,Object? complianceNotes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerIdType: null == customerIdType ? _self.customerIdType : customerIdType // ignore: cast_nullable_to_non_nullable
as String,customerIdNumber: null == customerIdNumber ? _self.customerIdNumber : customerIdNumber // ignore: cast_nullable_to_non_nullable
as String,customerPhotoUrl: freezed == customerPhotoUrl ? _self.customerPhotoUrl : customerPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,idDocumentUrl: freezed == idDocumentUrl ? _self.idDocumentUrl : idDocumentUrl // ignore: cast_nullable_to_non_nullable
as String?,oldGoldMetalType: null == oldGoldMetalType ? _self.oldGoldMetalType : oldGoldMetalType // ignore: cast_nullable_to_non_nullable
as MetalType,oldGoldWeightGrams: null == oldGoldWeightGrams ? _self.oldGoldWeightGrams : oldGoldWeightGrams // ignore: cast_nullable_to_non_nullable
as double,oldGoldValuePaisa: null == oldGoldValuePaisa ? _self.oldGoldValuePaisa : oldGoldValuePaisa // ignore: cast_nullable_to_non_nullable
as int,oldGoldRatePerGramPaisa: null == oldGoldRatePerGramPaisa ? _self.oldGoldRatePerGramPaisa : oldGoldRatePerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,purityTestMethod: freezed == purityTestMethod ? _self.purityTestMethod : purityTestMethod // ignore: cast_nullable_to_non_nullable
as String?,actualPurityPercentage: freezed == actualPurityPercentage ? _self.actualPurityPercentage : actualPurityPercentage // ignore: cast_nullable_to_non_nullable
as double?,purityTestReportUrl: freezed == purityTestReportUrl ? _self.purityTestReportUrl : purityTestReportUrl // ignore: cast_nullable_to_non_nullable
as String?,newItemDescription: freezed == newItemDescription ? _self.newItemDescription : newItemDescription // ignore: cast_nullable_to_non_nullable
as String?,newItemMetalType: freezed == newItemMetalType ? _self.newItemMetalType : newItemMetalType // ignore: cast_nullable_to_non_nullable
as MetalType?,newItemWeightGrams: freezed == newItemWeightGrams ? _self.newItemWeightGrams : newItemWeightGrams // ignore: cast_nullable_to_non_nullable
as double?,newItemTotalPaisa: freezed == newItemTotalPaisa ? _self.newItemTotalPaisa : newItemTotalPaisa // ignore: cast_nullable_to_non_nullable
as int?,newItemInvoiceId: freezed == newItemInvoiceId ? _self.newItemInvoiceId : newItemInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,exchangeValuePaisa: null == exchangeValuePaisa ? _self.exchangeValuePaisa : exchangeValuePaisa // ignore: cast_nullable_to_non_nullable
as int,cashAdjustmentPaisa: null == cashAdjustmentPaisa ? _self.cashAdjustmentPaisa : cashAdjustmentPaisa // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,verifiedBy: freezed == verifiedBy ? _self.verifiedBy : verifiedBy // ignore: cast_nullable_to_non_nullable
as String?,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,pmlCompliant: null == pmlCompliant ? _self.pmlCompliant : pmlCompliant // ignore: cast_nullable_to_non_nullable
as bool,complianceNotes: freezed == complianceNotes ? _self.complianceNotes : complianceNotes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OldGoldExchange].
extension OldGoldExchangePatterns on OldGoldExchange {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OldGoldExchange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OldGoldExchange() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OldGoldExchange value)  $default,){
final _that = this;
switch (_that) {
case _OldGoldExchange():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OldGoldExchange value)?  $default,){
final _that = this;
switch (_that) {
case _OldGoldExchange() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String customerId, @HiveField(3)  String customerName, @HiveField(4)  String? customerPhone, @HiveField(5)  String customerIdType, @HiveField(6)  String customerIdNumber, @HiveField(7)  String? customerPhotoUrl, @HiveField(8)  String? idDocumentUrl, @HiveField(9)  MetalType oldGoldMetalType, @HiveField(10)  double oldGoldWeightGrams, @HiveField(11)  int oldGoldValuePaisa, @HiveField(12)  int oldGoldRatePerGramPaisa, @HiveField(13)  String? purityTestMethod, @HiveField(14)  double? actualPurityPercentage, @HiveField(15)  String? purityTestReportUrl, @HiveField(16)  String? newItemDescription, @HiveField(17)  MetalType? newItemMetalType, @HiveField(18)  double? newItemWeightGrams, @HiveField(19)  int? newItemTotalPaisa,  String? newItemInvoiceId, @HiveField(20)  int exchangeValuePaisa, @HiveField(21)  int cashAdjustmentPaisa, @HiveField(23)  String status, @HiveField(24)  String? verifiedBy, @HiveField(25)  DateTime? verifiedAt, @HiveField(26)  DateTime createdAt, @HiveField(27)  String createdBy, @HiveField(28)  bool synced, @HiveField(29)  DateTime? lastSyncedAt, @HiveField(30)  String? pendingOperation, @HiveField(31)  bool pmlCompliant, @HiveField(32)  String? complianceNotes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OldGoldExchange() when $default != null:
return $default(_that.id,_that.tenantId,_that.customerId,_that.customerName,_that.customerPhone,_that.customerIdType,_that.customerIdNumber,_that.customerPhotoUrl,_that.idDocumentUrl,_that.oldGoldMetalType,_that.oldGoldWeightGrams,_that.oldGoldValuePaisa,_that.oldGoldRatePerGramPaisa,_that.purityTestMethod,_that.actualPurityPercentage,_that.purityTestReportUrl,_that.newItemDescription,_that.newItemMetalType,_that.newItemWeightGrams,_that.newItemTotalPaisa,_that.newItemInvoiceId,_that.exchangeValuePaisa,_that.cashAdjustmentPaisa,_that.status,_that.verifiedBy,_that.verifiedAt,_that.createdAt,_that.createdBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation,_that.pmlCompliant,_that.complianceNotes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String customerId, @HiveField(3)  String customerName, @HiveField(4)  String? customerPhone, @HiveField(5)  String customerIdType, @HiveField(6)  String customerIdNumber, @HiveField(7)  String? customerPhotoUrl, @HiveField(8)  String? idDocumentUrl, @HiveField(9)  MetalType oldGoldMetalType, @HiveField(10)  double oldGoldWeightGrams, @HiveField(11)  int oldGoldValuePaisa, @HiveField(12)  int oldGoldRatePerGramPaisa, @HiveField(13)  String? purityTestMethod, @HiveField(14)  double? actualPurityPercentage, @HiveField(15)  String? purityTestReportUrl, @HiveField(16)  String? newItemDescription, @HiveField(17)  MetalType? newItemMetalType, @HiveField(18)  double? newItemWeightGrams, @HiveField(19)  int? newItemTotalPaisa,  String? newItemInvoiceId, @HiveField(20)  int exchangeValuePaisa, @HiveField(21)  int cashAdjustmentPaisa, @HiveField(23)  String status, @HiveField(24)  String? verifiedBy, @HiveField(25)  DateTime? verifiedAt, @HiveField(26)  DateTime createdAt, @HiveField(27)  String createdBy, @HiveField(28)  bool synced, @HiveField(29)  DateTime? lastSyncedAt, @HiveField(30)  String? pendingOperation, @HiveField(31)  bool pmlCompliant, @HiveField(32)  String? complianceNotes)  $default,) {final _that = this;
switch (_that) {
case _OldGoldExchange():
return $default(_that.id,_that.tenantId,_that.customerId,_that.customerName,_that.customerPhone,_that.customerIdType,_that.customerIdNumber,_that.customerPhotoUrl,_that.idDocumentUrl,_that.oldGoldMetalType,_that.oldGoldWeightGrams,_that.oldGoldValuePaisa,_that.oldGoldRatePerGramPaisa,_that.purityTestMethod,_that.actualPurityPercentage,_that.purityTestReportUrl,_that.newItemDescription,_that.newItemMetalType,_that.newItemWeightGrams,_that.newItemTotalPaisa,_that.newItemInvoiceId,_that.exchangeValuePaisa,_that.cashAdjustmentPaisa,_that.status,_that.verifiedBy,_that.verifiedAt,_that.createdAt,_that.createdBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation,_that.pmlCompliant,_that.complianceNotes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String customerId, @HiveField(3)  String customerName, @HiveField(4)  String? customerPhone, @HiveField(5)  String customerIdType, @HiveField(6)  String customerIdNumber, @HiveField(7)  String? customerPhotoUrl, @HiveField(8)  String? idDocumentUrl, @HiveField(9)  MetalType oldGoldMetalType, @HiveField(10)  double oldGoldWeightGrams, @HiveField(11)  int oldGoldValuePaisa, @HiveField(12)  int oldGoldRatePerGramPaisa, @HiveField(13)  String? purityTestMethod, @HiveField(14)  double? actualPurityPercentage, @HiveField(15)  String? purityTestReportUrl, @HiveField(16)  String? newItemDescription, @HiveField(17)  MetalType? newItemMetalType, @HiveField(18)  double? newItemWeightGrams, @HiveField(19)  int? newItemTotalPaisa,  String? newItemInvoiceId, @HiveField(20)  int exchangeValuePaisa, @HiveField(21)  int cashAdjustmentPaisa, @HiveField(23)  String status, @HiveField(24)  String? verifiedBy, @HiveField(25)  DateTime? verifiedAt, @HiveField(26)  DateTime createdAt, @HiveField(27)  String createdBy, @HiveField(28)  bool synced, @HiveField(29)  DateTime? lastSyncedAt, @HiveField(30)  String? pendingOperation, @HiveField(31)  bool pmlCompliant, @HiveField(32)  String? complianceNotes)?  $default,) {final _that = this;
switch (_that) {
case _OldGoldExchange() when $default != null:
return $default(_that.id,_that.tenantId,_that.customerId,_that.customerName,_that.customerPhone,_that.customerIdType,_that.customerIdNumber,_that.customerPhotoUrl,_that.idDocumentUrl,_that.oldGoldMetalType,_that.oldGoldWeightGrams,_that.oldGoldValuePaisa,_that.oldGoldRatePerGramPaisa,_that.purityTestMethod,_that.actualPurityPercentage,_that.purityTestReportUrl,_that.newItemDescription,_that.newItemMetalType,_that.newItemWeightGrams,_that.newItemTotalPaisa,_that.newItemInvoiceId,_that.exchangeValuePaisa,_that.cashAdjustmentPaisa,_that.status,_that.verifiedBy,_that.verifiedAt,_that.createdAt,_that.createdBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation,_that.pmlCompliant,_that.complianceNotes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 53)
class _OldGoldExchange extends OldGoldExchange {
  const _OldGoldExchange({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.customerId, @HiveField(3) required this.customerName, @HiveField(4) this.customerPhone, @HiveField(5) required this.customerIdType, @HiveField(6) required this.customerIdNumber, @HiveField(7) this.customerPhotoUrl, @HiveField(8) this.idDocumentUrl, @HiveField(9) required this.oldGoldMetalType, @HiveField(10) required this.oldGoldWeightGrams, @HiveField(11) required this.oldGoldValuePaisa, @HiveField(12) required this.oldGoldRatePerGramPaisa, @HiveField(13) this.purityTestMethod, @HiveField(14) this.actualPurityPercentage, @HiveField(15) this.purityTestReportUrl, @HiveField(16) this.newItemDescription, @HiveField(17) this.newItemMetalType, @HiveField(18) this.newItemWeightGrams, @HiveField(19) this.newItemTotalPaisa, this.newItemInvoiceId, @HiveField(20) required this.exchangeValuePaisa, @HiveField(21) this.cashAdjustmentPaisa = 0, @HiveField(23) this.status = 'PENDING', @HiveField(24) this.verifiedBy, @HiveField(25) this.verifiedAt, @HiveField(26) required this.createdAt, @HiveField(27) required this.createdBy, @HiveField(28) this.synced = true, @HiveField(29) this.lastSyncedAt, @HiveField(30) this.pendingOperation, @HiveField(31) this.pmlCompliant = true, @HiveField(32) this.complianceNotes}): super._();
  factory _OldGoldExchange.fromJson(Map<String, dynamic> json) => _$OldGoldExchangeFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
@override@HiveField(2) final  String customerId;
@override@HiveField(3) final  String customerName;
@override@HiveField(4) final  String? customerPhone;
// PML Act KYC Fields
@override@HiveField(5) final  String customerIdType;
// AADHAAR, PAN, PASSPORT, VOTER_ID
@override@HiveField(6) final  String customerIdNumber;
@override@HiveField(7) final  String? customerPhotoUrl;
@override@HiveField(8) final  String? idDocumentUrl;
// Old gold details
@override@HiveField(9) final  MetalType oldGoldMetalType;
@override@HiveField(10) final  double oldGoldWeightGrams;
@override@HiveField(11) final  int oldGoldValuePaisa;
// Calculated value
@override@HiveField(12) final  int oldGoldRatePerGramPaisa;
// Rate at exchange time
// Purity verification
@override@HiveField(13) final  String? purityTestMethod;
// XRF, ACID, TOUCHSTONE
@override@HiveField(14) final  double? actualPurityPercentage;
@override@HiveField(15) final  String? purityTestReportUrl;
// New item details (if exchanging)
@override@HiveField(16) final  String? newItemDescription;
@override@HiveField(17) final  MetalType? newItemMetalType;
@override@HiveField(18) final  double? newItemWeightGrams;
@override@HiveField(19) final  int? newItemTotalPaisa;
@override final  String? newItemInvoiceId;
// Exchange calculation
@override@HiveField(20) final  int exchangeValuePaisa;
@override@JsonKey()@HiveField(21) final  int cashAdjustmentPaisa;
// Positive = customer pays
// Status
@override@JsonKey()@HiveField(23) final  String status;
// PENDING, VERIFIED, COMPLETED, CANCELLED
@override@HiveField(24) final  String? verifiedBy;
@override@HiveField(25) final  DateTime? verifiedAt;
// Metadata
@override@HiveField(26) final  DateTime createdAt;
@override@HiveField(27) final  String createdBy;
@override@JsonKey()@HiveField(28) final  bool synced;
@override@HiveField(29) final  DateTime? lastSyncedAt;
@override@HiveField(30) final  String? pendingOperation;
// PML Act compliance tracking
@override@JsonKey()@HiveField(31) final  bool pmlCompliant;
@override@HiveField(32) final  String? complianceNotes;

/// Create a copy of OldGoldExchange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OldGoldExchangeCopyWith<_OldGoldExchange> get copyWith => __$OldGoldExchangeCopyWithImpl<_OldGoldExchange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OldGoldExchangeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OldGoldExchange&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerIdType, customerIdType) || other.customerIdType == customerIdType)&&(identical(other.customerIdNumber, customerIdNumber) || other.customerIdNumber == customerIdNumber)&&(identical(other.customerPhotoUrl, customerPhotoUrl) || other.customerPhotoUrl == customerPhotoUrl)&&(identical(other.idDocumentUrl, idDocumentUrl) || other.idDocumentUrl == idDocumentUrl)&&(identical(other.oldGoldMetalType, oldGoldMetalType) || other.oldGoldMetalType == oldGoldMetalType)&&(identical(other.oldGoldWeightGrams, oldGoldWeightGrams) || other.oldGoldWeightGrams == oldGoldWeightGrams)&&(identical(other.oldGoldValuePaisa, oldGoldValuePaisa) || other.oldGoldValuePaisa == oldGoldValuePaisa)&&(identical(other.oldGoldRatePerGramPaisa, oldGoldRatePerGramPaisa) || other.oldGoldRatePerGramPaisa == oldGoldRatePerGramPaisa)&&(identical(other.purityTestMethod, purityTestMethod) || other.purityTestMethod == purityTestMethod)&&(identical(other.actualPurityPercentage, actualPurityPercentage) || other.actualPurityPercentage == actualPurityPercentage)&&(identical(other.purityTestReportUrl, purityTestReportUrl) || other.purityTestReportUrl == purityTestReportUrl)&&(identical(other.newItemDescription, newItemDescription) || other.newItemDescription == newItemDescription)&&(identical(other.newItemMetalType, newItemMetalType) || other.newItemMetalType == newItemMetalType)&&(identical(other.newItemWeightGrams, newItemWeightGrams) || other.newItemWeightGrams == newItemWeightGrams)&&(identical(other.newItemTotalPaisa, newItemTotalPaisa) || other.newItemTotalPaisa == newItemTotalPaisa)&&(identical(other.newItemInvoiceId, newItemInvoiceId) || other.newItemInvoiceId == newItemInvoiceId)&&(identical(other.exchangeValuePaisa, exchangeValuePaisa) || other.exchangeValuePaisa == exchangeValuePaisa)&&(identical(other.cashAdjustmentPaisa, cashAdjustmentPaisa) || other.cashAdjustmentPaisa == cashAdjustmentPaisa)&&(identical(other.status, status) || other.status == status)&&(identical(other.verifiedBy, verifiedBy) || other.verifiedBy == verifiedBy)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation)&&(identical(other.pmlCompliant, pmlCompliant) || other.pmlCompliant == pmlCompliant)&&(identical(other.complianceNotes, complianceNotes) || other.complianceNotes == complianceNotes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,customerId,customerName,customerPhone,customerIdType,customerIdNumber,customerPhotoUrl,idDocumentUrl,oldGoldMetalType,oldGoldWeightGrams,oldGoldValuePaisa,oldGoldRatePerGramPaisa,purityTestMethod,actualPurityPercentage,purityTestReportUrl,newItemDescription,newItemMetalType,newItemWeightGrams,newItemTotalPaisa,newItemInvoiceId,exchangeValuePaisa,cashAdjustmentPaisa,status,verifiedBy,verifiedAt,createdAt,createdBy,synced,lastSyncedAt,pendingOperation,pmlCompliant,complianceNotes]);

@override
String toString() {
  return 'OldGoldExchange(id: $id, tenantId: $tenantId, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, customerIdType: $customerIdType, customerIdNumber: $customerIdNumber, customerPhotoUrl: $customerPhotoUrl, idDocumentUrl: $idDocumentUrl, oldGoldMetalType: $oldGoldMetalType, oldGoldWeightGrams: $oldGoldWeightGrams, oldGoldValuePaisa: $oldGoldValuePaisa, oldGoldRatePerGramPaisa: $oldGoldRatePerGramPaisa, purityTestMethod: $purityTestMethod, actualPurityPercentage: $actualPurityPercentage, purityTestReportUrl: $purityTestReportUrl, newItemDescription: $newItemDescription, newItemMetalType: $newItemMetalType, newItemWeightGrams: $newItemWeightGrams, newItemTotalPaisa: $newItemTotalPaisa, newItemInvoiceId: $newItemInvoiceId, exchangeValuePaisa: $exchangeValuePaisa, cashAdjustmentPaisa: $cashAdjustmentPaisa, status: $status, verifiedBy: $verifiedBy, verifiedAt: $verifiedAt, createdAt: $createdAt, createdBy: $createdBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation, pmlCompliant: $pmlCompliant, complianceNotes: $complianceNotes)';
}


}

/// @nodoc
abstract mixin class _$OldGoldExchangeCopyWith<$Res> implements $OldGoldExchangeCopyWith<$Res> {
  factory _$OldGoldExchangeCopyWith(_OldGoldExchange value, $Res Function(_OldGoldExchange) _then) = __$OldGoldExchangeCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String customerId,@HiveField(3) String customerName,@HiveField(4) String? customerPhone,@HiveField(5) String customerIdType,@HiveField(6) String customerIdNumber,@HiveField(7) String? customerPhotoUrl,@HiveField(8) String? idDocumentUrl,@HiveField(9) MetalType oldGoldMetalType,@HiveField(10) double oldGoldWeightGrams,@HiveField(11) int oldGoldValuePaisa,@HiveField(12) int oldGoldRatePerGramPaisa,@HiveField(13) String? purityTestMethod,@HiveField(14) double? actualPurityPercentage,@HiveField(15) String? purityTestReportUrl,@HiveField(16) String? newItemDescription,@HiveField(17) MetalType? newItemMetalType,@HiveField(18) double? newItemWeightGrams,@HiveField(19) int? newItemTotalPaisa, String? newItemInvoiceId,@HiveField(20) int exchangeValuePaisa,@HiveField(21) int cashAdjustmentPaisa,@HiveField(23) String status,@HiveField(24) String? verifiedBy,@HiveField(25) DateTime? verifiedAt,@HiveField(26) DateTime createdAt,@HiveField(27) String createdBy,@HiveField(28) bool synced,@HiveField(29) DateTime? lastSyncedAt,@HiveField(30) String? pendingOperation,@HiveField(31) bool pmlCompliant,@HiveField(32) String? complianceNotes
});




}
/// @nodoc
class __$OldGoldExchangeCopyWithImpl<$Res>
    implements _$OldGoldExchangeCopyWith<$Res> {
  __$OldGoldExchangeCopyWithImpl(this._self, this._then);

  final _OldGoldExchange _self;
  final $Res Function(_OldGoldExchange) _then;

/// Create a copy of OldGoldExchange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? customerId = null,Object? customerName = null,Object? customerPhone = freezed,Object? customerIdType = null,Object? customerIdNumber = null,Object? customerPhotoUrl = freezed,Object? idDocumentUrl = freezed,Object? oldGoldMetalType = null,Object? oldGoldWeightGrams = null,Object? oldGoldValuePaisa = null,Object? oldGoldRatePerGramPaisa = null,Object? purityTestMethod = freezed,Object? actualPurityPercentage = freezed,Object? purityTestReportUrl = freezed,Object? newItemDescription = freezed,Object? newItemMetalType = freezed,Object? newItemWeightGrams = freezed,Object? newItemTotalPaisa = freezed,Object? newItemInvoiceId = freezed,Object? exchangeValuePaisa = null,Object? cashAdjustmentPaisa = null,Object? status = null,Object? verifiedBy = freezed,Object? verifiedAt = freezed,Object? createdAt = null,Object? createdBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,Object? pmlCompliant = null,Object? complianceNotes = freezed,}) {
  return _then(_OldGoldExchange(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerIdType: null == customerIdType ? _self.customerIdType : customerIdType // ignore: cast_nullable_to_non_nullable
as String,customerIdNumber: null == customerIdNumber ? _self.customerIdNumber : customerIdNumber // ignore: cast_nullable_to_non_nullable
as String,customerPhotoUrl: freezed == customerPhotoUrl ? _self.customerPhotoUrl : customerPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,idDocumentUrl: freezed == idDocumentUrl ? _self.idDocumentUrl : idDocumentUrl // ignore: cast_nullable_to_non_nullable
as String?,oldGoldMetalType: null == oldGoldMetalType ? _self.oldGoldMetalType : oldGoldMetalType // ignore: cast_nullable_to_non_nullable
as MetalType,oldGoldWeightGrams: null == oldGoldWeightGrams ? _self.oldGoldWeightGrams : oldGoldWeightGrams // ignore: cast_nullable_to_non_nullable
as double,oldGoldValuePaisa: null == oldGoldValuePaisa ? _self.oldGoldValuePaisa : oldGoldValuePaisa // ignore: cast_nullable_to_non_nullable
as int,oldGoldRatePerGramPaisa: null == oldGoldRatePerGramPaisa ? _self.oldGoldRatePerGramPaisa : oldGoldRatePerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,purityTestMethod: freezed == purityTestMethod ? _self.purityTestMethod : purityTestMethod // ignore: cast_nullable_to_non_nullable
as String?,actualPurityPercentage: freezed == actualPurityPercentage ? _self.actualPurityPercentage : actualPurityPercentage // ignore: cast_nullable_to_non_nullable
as double?,purityTestReportUrl: freezed == purityTestReportUrl ? _self.purityTestReportUrl : purityTestReportUrl // ignore: cast_nullable_to_non_nullable
as String?,newItemDescription: freezed == newItemDescription ? _self.newItemDescription : newItemDescription // ignore: cast_nullable_to_non_nullable
as String?,newItemMetalType: freezed == newItemMetalType ? _self.newItemMetalType : newItemMetalType // ignore: cast_nullable_to_non_nullable
as MetalType?,newItemWeightGrams: freezed == newItemWeightGrams ? _self.newItemWeightGrams : newItemWeightGrams // ignore: cast_nullable_to_non_nullable
as double?,newItemTotalPaisa: freezed == newItemTotalPaisa ? _self.newItemTotalPaisa : newItemTotalPaisa // ignore: cast_nullable_to_non_nullable
as int?,newItemInvoiceId: freezed == newItemInvoiceId ? _self.newItemInvoiceId : newItemInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,exchangeValuePaisa: null == exchangeValuePaisa ? _self.exchangeValuePaisa : exchangeValuePaisa // ignore: cast_nullable_to_non_nullable
as int,cashAdjustmentPaisa: null == cashAdjustmentPaisa ? _self.cashAdjustmentPaisa : cashAdjustmentPaisa // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,verifiedBy: freezed == verifiedBy ? _self.verifiedBy : verifiedBy // ignore: cast_nullable_to_non_nullable
as String?,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,pmlCompliant: null == pmlCompliant ? _self.pmlCompliant : pmlCompliant // ignore: cast_nullable_to_non_nullable
as bool,complianceNotes: freezed == complianceNotes ? _self.complianceNotes : complianceNotes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$JewelleryOrder {

@HiveField(0) String get id;@HiveField(1) String get tenantId;@HiveField(2) String get customerId;@HiveField(3) String get customerName;@HiveField(4) String? get customerPhone;// Order details
@HiveField(5) String get itemDescription;@HiveField(6) String? get designReference;// Image URL or design code
@HiveField(7) String? get designNotes;// Metal specifications
@HiveField(8) MetalType get metalType;@HiveField(9) double get estimatedWeightGrams;@HiveField(10) double? get actualWeightGrams;// After completion
// Pricing (estimated)
@HiveField(11) int get metalRatePerGramPaisa;// At order time
@HiveField(12) int get makingChargesPerGramPaisa;@HiveField(13) double get wastagePercent;@HiveField(14) int get stoneChargesPaisa;@HiveField(15) int get otherChargesPaisa;@HiveField(16) int get estimatedTotalPaisa;@HiveField(17) int? get actualTotalPaisa;// Final amount after completion
// Advance payment
@HiveField(18) int get advanceReceivedPaisa;@HiveField(19) String? get advancePaymentMode;// Timeline
@HiveField(20) DateTime get orderDate;@HiveField(21) String get promisedDeliveryDate;// YYYY-MM-DD
@HiveField(22) String? get actualDeliveryDate;// Status workflow
@HiveField(23) String get status;// PENDING -> DESIGN_APPROVAL -> IN_PROGRESS -> READY -> DELIVERED
// Or: CANCELLED at any point
// Status history
@HiveField(24) List<OrderStatusUpdate>? get statusHistory;// Work tracking
@HiveField(25) String? get assignedTo;// Craftsman/staff
@HiveField(26) List<WorkProgressUpdate>? get workProgress;// Final product
@HiveField(27) String? get finalProductId;// Link to inventory item
@HiveField(28) String? get invoiceId;// Metadata
@HiveField(29) DateTime get createdAt;@HiveField(30) String get createdBy;@HiveField(31) DateTime get updatedAt;@HiveField(32) String get updatedBy;@HiveField(33) bool get synced;@HiveField(34) DateTime? get lastSyncedAt;@HiveField(35) String? get pendingOperation;
/// Create a copy of JewelleryOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JewelleryOrderCopyWith<JewelleryOrder> get copyWith => _$JewelleryOrderCopyWithImpl<JewelleryOrder>(this as JewelleryOrder, _$identity);

  /// Serializes this JewelleryOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JewelleryOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.itemDescription, itemDescription) || other.itemDescription == itemDescription)&&(identical(other.designReference, designReference) || other.designReference == designReference)&&(identical(other.designNotes, designNotes) || other.designNotes == designNotes)&&(identical(other.metalType, metalType) || other.metalType == metalType)&&(identical(other.estimatedWeightGrams, estimatedWeightGrams) || other.estimatedWeightGrams == estimatedWeightGrams)&&(identical(other.actualWeightGrams, actualWeightGrams) || other.actualWeightGrams == actualWeightGrams)&&(identical(other.metalRatePerGramPaisa, metalRatePerGramPaisa) || other.metalRatePerGramPaisa == metalRatePerGramPaisa)&&(identical(other.makingChargesPerGramPaisa, makingChargesPerGramPaisa) || other.makingChargesPerGramPaisa == makingChargesPerGramPaisa)&&(identical(other.wastagePercent, wastagePercent) || other.wastagePercent == wastagePercent)&&(identical(other.stoneChargesPaisa, stoneChargesPaisa) || other.stoneChargesPaisa == stoneChargesPaisa)&&(identical(other.otherChargesPaisa, otherChargesPaisa) || other.otherChargesPaisa == otherChargesPaisa)&&(identical(other.estimatedTotalPaisa, estimatedTotalPaisa) || other.estimatedTotalPaisa == estimatedTotalPaisa)&&(identical(other.actualTotalPaisa, actualTotalPaisa) || other.actualTotalPaisa == actualTotalPaisa)&&(identical(other.advanceReceivedPaisa, advanceReceivedPaisa) || other.advanceReceivedPaisa == advanceReceivedPaisa)&&(identical(other.advancePaymentMode, advancePaymentMode) || other.advancePaymentMode == advancePaymentMode)&&(identical(other.orderDate, orderDate) || other.orderDate == orderDate)&&(identical(other.promisedDeliveryDate, promisedDeliveryDate) || other.promisedDeliveryDate == promisedDeliveryDate)&&(identical(other.actualDeliveryDate, actualDeliveryDate) || other.actualDeliveryDate == actualDeliveryDate)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.statusHistory, statusHistory)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&const DeepCollectionEquality().equals(other.workProgress, workProgress)&&(identical(other.finalProductId, finalProductId) || other.finalProductId == finalProductId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,customerId,customerName,customerPhone,itemDescription,designReference,designNotes,metalType,estimatedWeightGrams,actualWeightGrams,metalRatePerGramPaisa,makingChargesPerGramPaisa,wastagePercent,stoneChargesPaisa,otherChargesPaisa,estimatedTotalPaisa,actualTotalPaisa,advanceReceivedPaisa,advancePaymentMode,orderDate,promisedDeliveryDate,actualDeliveryDate,status,const DeepCollectionEquality().hash(statusHistory),assignedTo,const DeepCollectionEquality().hash(workProgress),finalProductId,invoiceId,createdAt,createdBy,updatedAt,updatedBy,synced,lastSyncedAt,pendingOperation]);

@override
String toString() {
  return 'JewelleryOrder(id: $id, tenantId: $tenantId, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, itemDescription: $itemDescription, designReference: $designReference, designNotes: $designNotes, metalType: $metalType, estimatedWeightGrams: $estimatedWeightGrams, actualWeightGrams: $actualWeightGrams, metalRatePerGramPaisa: $metalRatePerGramPaisa, makingChargesPerGramPaisa: $makingChargesPerGramPaisa, wastagePercent: $wastagePercent, stoneChargesPaisa: $stoneChargesPaisa, otherChargesPaisa: $otherChargesPaisa, estimatedTotalPaisa: $estimatedTotalPaisa, actualTotalPaisa: $actualTotalPaisa, advanceReceivedPaisa: $advanceReceivedPaisa, advancePaymentMode: $advancePaymentMode, orderDate: $orderDate, promisedDeliveryDate: $promisedDeliveryDate, actualDeliveryDate: $actualDeliveryDate, status: $status, statusHistory: $statusHistory, assignedTo: $assignedTo, workProgress: $workProgress, finalProductId: $finalProductId, invoiceId: $invoiceId, createdAt: $createdAt, createdBy: $createdBy, updatedAt: $updatedAt, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class $JewelleryOrderCopyWith<$Res>  {
  factory $JewelleryOrderCopyWith(JewelleryOrder value, $Res Function(JewelleryOrder) _then) = _$JewelleryOrderCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String customerId,@HiveField(3) String customerName,@HiveField(4) String? customerPhone,@HiveField(5) String itemDescription,@HiveField(6) String? designReference,@HiveField(7) String? designNotes,@HiveField(8) MetalType metalType,@HiveField(9) double estimatedWeightGrams,@HiveField(10) double? actualWeightGrams,@HiveField(11) int metalRatePerGramPaisa,@HiveField(12) int makingChargesPerGramPaisa,@HiveField(13) double wastagePercent,@HiveField(14) int stoneChargesPaisa,@HiveField(15) int otherChargesPaisa,@HiveField(16) int estimatedTotalPaisa,@HiveField(17) int? actualTotalPaisa,@HiveField(18) int advanceReceivedPaisa,@HiveField(19) String? advancePaymentMode,@HiveField(20) DateTime orderDate,@HiveField(21) String promisedDeliveryDate,@HiveField(22) String? actualDeliveryDate,@HiveField(23) String status,@HiveField(24) List<OrderStatusUpdate>? statusHistory,@HiveField(25) String? assignedTo,@HiveField(26) List<WorkProgressUpdate>? workProgress,@HiveField(27) String? finalProductId,@HiveField(28) String? invoiceId,@HiveField(29) DateTime createdAt,@HiveField(30) String createdBy,@HiveField(31) DateTime updatedAt,@HiveField(32) String updatedBy,@HiveField(33) bool synced,@HiveField(34) DateTime? lastSyncedAt,@HiveField(35) String? pendingOperation
});




}
/// @nodoc
class _$JewelleryOrderCopyWithImpl<$Res>
    implements $JewelleryOrderCopyWith<$Res> {
  _$JewelleryOrderCopyWithImpl(this._self, this._then);

  final JewelleryOrder _self;
  final $Res Function(JewelleryOrder) _then;

/// Create a copy of JewelleryOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? customerId = null,Object? customerName = null,Object? customerPhone = freezed,Object? itemDescription = null,Object? designReference = freezed,Object? designNotes = freezed,Object? metalType = null,Object? estimatedWeightGrams = null,Object? actualWeightGrams = freezed,Object? metalRatePerGramPaisa = null,Object? makingChargesPerGramPaisa = null,Object? wastagePercent = null,Object? stoneChargesPaisa = null,Object? otherChargesPaisa = null,Object? estimatedTotalPaisa = null,Object? actualTotalPaisa = freezed,Object? advanceReceivedPaisa = null,Object? advancePaymentMode = freezed,Object? orderDate = null,Object? promisedDeliveryDate = null,Object? actualDeliveryDate = freezed,Object? status = null,Object? statusHistory = freezed,Object? assignedTo = freezed,Object? workProgress = freezed,Object? finalProductId = freezed,Object? invoiceId = freezed,Object? createdAt = null,Object? createdBy = null,Object? updatedAt = null,Object? updatedBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,itemDescription: null == itemDescription ? _self.itemDescription : itemDescription // ignore: cast_nullable_to_non_nullable
as String,designReference: freezed == designReference ? _self.designReference : designReference // ignore: cast_nullable_to_non_nullable
as String?,designNotes: freezed == designNotes ? _self.designNotes : designNotes // ignore: cast_nullable_to_non_nullable
as String?,metalType: null == metalType ? _self.metalType : metalType // ignore: cast_nullable_to_non_nullable
as MetalType,estimatedWeightGrams: null == estimatedWeightGrams ? _self.estimatedWeightGrams : estimatedWeightGrams // ignore: cast_nullable_to_non_nullable
as double,actualWeightGrams: freezed == actualWeightGrams ? _self.actualWeightGrams : actualWeightGrams // ignore: cast_nullable_to_non_nullable
as double?,metalRatePerGramPaisa: null == metalRatePerGramPaisa ? _self.metalRatePerGramPaisa : metalRatePerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,makingChargesPerGramPaisa: null == makingChargesPerGramPaisa ? _self.makingChargesPerGramPaisa : makingChargesPerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,wastagePercent: null == wastagePercent ? _self.wastagePercent : wastagePercent // ignore: cast_nullable_to_non_nullable
as double,stoneChargesPaisa: null == stoneChargesPaisa ? _self.stoneChargesPaisa : stoneChargesPaisa // ignore: cast_nullable_to_non_nullable
as int,otherChargesPaisa: null == otherChargesPaisa ? _self.otherChargesPaisa : otherChargesPaisa // ignore: cast_nullable_to_non_nullable
as int,estimatedTotalPaisa: null == estimatedTotalPaisa ? _self.estimatedTotalPaisa : estimatedTotalPaisa // ignore: cast_nullable_to_non_nullable
as int,actualTotalPaisa: freezed == actualTotalPaisa ? _self.actualTotalPaisa : actualTotalPaisa // ignore: cast_nullable_to_non_nullable
as int?,advanceReceivedPaisa: null == advanceReceivedPaisa ? _self.advanceReceivedPaisa : advanceReceivedPaisa // ignore: cast_nullable_to_non_nullable
as int,advancePaymentMode: freezed == advancePaymentMode ? _self.advancePaymentMode : advancePaymentMode // ignore: cast_nullable_to_non_nullable
as String?,orderDate: null == orderDate ? _self.orderDate : orderDate // ignore: cast_nullable_to_non_nullable
as DateTime,promisedDeliveryDate: null == promisedDeliveryDate ? _self.promisedDeliveryDate : promisedDeliveryDate // ignore: cast_nullable_to_non_nullable
as String,actualDeliveryDate: freezed == actualDeliveryDate ? _self.actualDeliveryDate : actualDeliveryDate // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,statusHistory: freezed == statusHistory ? _self.statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<OrderStatusUpdate>?,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,workProgress: freezed == workProgress ? _self.workProgress : workProgress // ignore: cast_nullable_to_non_nullable
as List<WorkProgressUpdate>?,finalProductId: freezed == finalProductId ? _self.finalProductId : finalProductId // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [JewelleryOrder].
extension JewelleryOrderPatterns on JewelleryOrder {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JewelleryOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JewelleryOrder() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JewelleryOrder value)  $default,){
final _that = this;
switch (_that) {
case _JewelleryOrder():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JewelleryOrder value)?  $default,){
final _that = this;
switch (_that) {
case _JewelleryOrder() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String customerId, @HiveField(3)  String customerName, @HiveField(4)  String? customerPhone, @HiveField(5)  String itemDescription, @HiveField(6)  String? designReference, @HiveField(7)  String? designNotes, @HiveField(8)  MetalType metalType, @HiveField(9)  double estimatedWeightGrams, @HiveField(10)  double? actualWeightGrams, @HiveField(11)  int metalRatePerGramPaisa, @HiveField(12)  int makingChargesPerGramPaisa, @HiveField(13)  double wastagePercent, @HiveField(14)  int stoneChargesPaisa, @HiveField(15)  int otherChargesPaisa, @HiveField(16)  int estimatedTotalPaisa, @HiveField(17)  int? actualTotalPaisa, @HiveField(18)  int advanceReceivedPaisa, @HiveField(19)  String? advancePaymentMode, @HiveField(20)  DateTime orderDate, @HiveField(21)  String promisedDeliveryDate, @HiveField(22)  String? actualDeliveryDate, @HiveField(23)  String status, @HiveField(24)  List<OrderStatusUpdate>? statusHistory, @HiveField(25)  String? assignedTo, @HiveField(26)  List<WorkProgressUpdate>? workProgress, @HiveField(27)  String? finalProductId, @HiveField(28)  String? invoiceId, @HiveField(29)  DateTime createdAt, @HiveField(30)  String createdBy, @HiveField(31)  DateTime updatedAt, @HiveField(32)  String updatedBy, @HiveField(33)  bool synced, @HiveField(34)  DateTime? lastSyncedAt, @HiveField(35)  String? pendingOperation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JewelleryOrder() when $default != null:
return $default(_that.id,_that.tenantId,_that.customerId,_that.customerName,_that.customerPhone,_that.itemDescription,_that.designReference,_that.designNotes,_that.metalType,_that.estimatedWeightGrams,_that.actualWeightGrams,_that.metalRatePerGramPaisa,_that.makingChargesPerGramPaisa,_that.wastagePercent,_that.stoneChargesPaisa,_that.otherChargesPaisa,_that.estimatedTotalPaisa,_that.actualTotalPaisa,_that.advanceReceivedPaisa,_that.advancePaymentMode,_that.orderDate,_that.promisedDeliveryDate,_that.actualDeliveryDate,_that.status,_that.statusHistory,_that.assignedTo,_that.workProgress,_that.finalProductId,_that.invoiceId,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String customerId, @HiveField(3)  String customerName, @HiveField(4)  String? customerPhone, @HiveField(5)  String itemDescription, @HiveField(6)  String? designReference, @HiveField(7)  String? designNotes, @HiveField(8)  MetalType metalType, @HiveField(9)  double estimatedWeightGrams, @HiveField(10)  double? actualWeightGrams, @HiveField(11)  int metalRatePerGramPaisa, @HiveField(12)  int makingChargesPerGramPaisa, @HiveField(13)  double wastagePercent, @HiveField(14)  int stoneChargesPaisa, @HiveField(15)  int otherChargesPaisa, @HiveField(16)  int estimatedTotalPaisa, @HiveField(17)  int? actualTotalPaisa, @HiveField(18)  int advanceReceivedPaisa, @HiveField(19)  String? advancePaymentMode, @HiveField(20)  DateTime orderDate, @HiveField(21)  String promisedDeliveryDate, @HiveField(22)  String? actualDeliveryDate, @HiveField(23)  String status, @HiveField(24)  List<OrderStatusUpdate>? statusHistory, @HiveField(25)  String? assignedTo, @HiveField(26)  List<WorkProgressUpdate>? workProgress, @HiveField(27)  String? finalProductId, @HiveField(28)  String? invoiceId, @HiveField(29)  DateTime createdAt, @HiveField(30)  String createdBy, @HiveField(31)  DateTime updatedAt, @HiveField(32)  String updatedBy, @HiveField(33)  bool synced, @HiveField(34)  DateTime? lastSyncedAt, @HiveField(35)  String? pendingOperation)  $default,) {final _that = this;
switch (_that) {
case _JewelleryOrder():
return $default(_that.id,_that.tenantId,_that.customerId,_that.customerName,_that.customerPhone,_that.itemDescription,_that.designReference,_that.designNotes,_that.metalType,_that.estimatedWeightGrams,_that.actualWeightGrams,_that.metalRatePerGramPaisa,_that.makingChargesPerGramPaisa,_that.wastagePercent,_that.stoneChargesPaisa,_that.otherChargesPaisa,_that.estimatedTotalPaisa,_that.actualTotalPaisa,_that.advanceReceivedPaisa,_that.advancePaymentMode,_that.orderDate,_that.promisedDeliveryDate,_that.actualDeliveryDate,_that.status,_that.statusHistory,_that.assignedTo,_that.workProgress,_that.finalProductId,_that.invoiceId,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String customerId, @HiveField(3)  String customerName, @HiveField(4)  String? customerPhone, @HiveField(5)  String itemDescription, @HiveField(6)  String? designReference, @HiveField(7)  String? designNotes, @HiveField(8)  MetalType metalType, @HiveField(9)  double estimatedWeightGrams, @HiveField(10)  double? actualWeightGrams, @HiveField(11)  int metalRatePerGramPaisa, @HiveField(12)  int makingChargesPerGramPaisa, @HiveField(13)  double wastagePercent, @HiveField(14)  int stoneChargesPaisa, @HiveField(15)  int otherChargesPaisa, @HiveField(16)  int estimatedTotalPaisa, @HiveField(17)  int? actualTotalPaisa, @HiveField(18)  int advanceReceivedPaisa, @HiveField(19)  String? advancePaymentMode, @HiveField(20)  DateTime orderDate, @HiveField(21)  String promisedDeliveryDate, @HiveField(22)  String? actualDeliveryDate, @HiveField(23)  String status, @HiveField(24)  List<OrderStatusUpdate>? statusHistory, @HiveField(25)  String? assignedTo, @HiveField(26)  List<WorkProgressUpdate>? workProgress, @HiveField(27)  String? finalProductId, @HiveField(28)  String? invoiceId, @HiveField(29)  DateTime createdAt, @HiveField(30)  String createdBy, @HiveField(31)  DateTime updatedAt, @HiveField(32)  String updatedBy, @HiveField(33)  bool synced, @HiveField(34)  DateTime? lastSyncedAt, @HiveField(35)  String? pendingOperation)?  $default,) {final _that = this;
switch (_that) {
case _JewelleryOrder() when $default != null:
return $default(_that.id,_that.tenantId,_that.customerId,_that.customerName,_that.customerPhone,_that.itemDescription,_that.designReference,_that.designNotes,_that.metalType,_that.estimatedWeightGrams,_that.actualWeightGrams,_that.metalRatePerGramPaisa,_that.makingChargesPerGramPaisa,_that.wastagePercent,_that.stoneChargesPaisa,_that.otherChargesPaisa,_that.estimatedTotalPaisa,_that.actualTotalPaisa,_that.advanceReceivedPaisa,_that.advancePaymentMode,_that.orderDate,_that.promisedDeliveryDate,_that.actualDeliveryDate,_that.status,_that.statusHistory,_that.assignedTo,_that.workProgress,_that.finalProductId,_that.invoiceId,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 54)
class _JewelleryOrder extends JewelleryOrder {
  const _JewelleryOrder({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.customerId, @HiveField(3) required this.customerName, @HiveField(4) this.customerPhone, @HiveField(5) required this.itemDescription, @HiveField(6) this.designReference, @HiveField(7) this.designNotes, @HiveField(8) required this.metalType, @HiveField(9) required this.estimatedWeightGrams, @HiveField(10) this.actualWeightGrams, @HiveField(11) required this.metalRatePerGramPaisa, @HiveField(12) required this.makingChargesPerGramPaisa, @HiveField(13) this.wastagePercent = 0, @HiveField(14) this.stoneChargesPaisa = 0, @HiveField(15) this.otherChargesPaisa = 0, @HiveField(16) required this.estimatedTotalPaisa, @HiveField(17) this.actualTotalPaisa, @HiveField(18) this.advanceReceivedPaisa = 0, @HiveField(19) this.advancePaymentMode, @HiveField(20) required this.orderDate, @HiveField(21) required this.promisedDeliveryDate, @HiveField(22) this.actualDeliveryDate, @HiveField(23) this.status = 'PENDING', @HiveField(24) final  List<OrderStatusUpdate>? statusHistory, @HiveField(25) this.assignedTo, @HiveField(26) final  List<WorkProgressUpdate>? workProgress, @HiveField(27) this.finalProductId, @HiveField(28) this.invoiceId, @HiveField(29) required this.createdAt, @HiveField(30) required this.createdBy, @HiveField(31) required this.updatedAt, @HiveField(32) required this.updatedBy, @HiveField(33) this.synced = true, @HiveField(34) this.lastSyncedAt, @HiveField(35) this.pendingOperation}): _statusHistory = statusHistory,_workProgress = workProgress,super._();
  factory _JewelleryOrder.fromJson(Map<String, dynamic> json) => _$JewelleryOrderFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
@override@HiveField(2) final  String customerId;
@override@HiveField(3) final  String customerName;
@override@HiveField(4) final  String? customerPhone;
// Order details
@override@HiveField(5) final  String itemDescription;
@override@HiveField(6) final  String? designReference;
// Image URL or design code
@override@HiveField(7) final  String? designNotes;
// Metal specifications
@override@HiveField(8) final  MetalType metalType;
@override@HiveField(9) final  double estimatedWeightGrams;
@override@HiveField(10) final  double? actualWeightGrams;
// After completion
// Pricing (estimated)
@override@HiveField(11) final  int metalRatePerGramPaisa;
// At order time
@override@HiveField(12) final  int makingChargesPerGramPaisa;
@override@JsonKey()@HiveField(13) final  double wastagePercent;
@override@JsonKey()@HiveField(14) final  int stoneChargesPaisa;
@override@JsonKey()@HiveField(15) final  int otherChargesPaisa;
@override@HiveField(16) final  int estimatedTotalPaisa;
@override@HiveField(17) final  int? actualTotalPaisa;
// Final amount after completion
// Advance payment
@override@JsonKey()@HiveField(18) final  int advanceReceivedPaisa;
@override@HiveField(19) final  String? advancePaymentMode;
// Timeline
@override@HiveField(20) final  DateTime orderDate;
@override@HiveField(21) final  String promisedDeliveryDate;
// YYYY-MM-DD
@override@HiveField(22) final  String? actualDeliveryDate;
// Status workflow
@override@JsonKey()@HiveField(23) final  String status;
// PENDING -> DESIGN_APPROVAL -> IN_PROGRESS -> READY -> DELIVERED
// Or: CANCELLED at any point
// Status history
 final  List<OrderStatusUpdate>? _statusHistory;
// PENDING -> DESIGN_APPROVAL -> IN_PROGRESS -> READY -> DELIVERED
// Or: CANCELLED at any point
// Status history
@override@HiveField(24) List<OrderStatusUpdate>? get statusHistory {
  final value = _statusHistory;
  if (value == null) return null;
  if (_statusHistory is EqualUnmodifiableListView) return _statusHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Work tracking
@override@HiveField(25) final  String? assignedTo;
// Craftsman/staff
 final  List<WorkProgressUpdate>? _workProgress;
// Craftsman/staff
@override@HiveField(26) List<WorkProgressUpdate>? get workProgress {
  final value = _workProgress;
  if (value == null) return null;
  if (_workProgress is EqualUnmodifiableListView) return _workProgress;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Final product
@override@HiveField(27) final  String? finalProductId;
// Link to inventory item
@override@HiveField(28) final  String? invoiceId;
// Metadata
@override@HiveField(29) final  DateTime createdAt;
@override@HiveField(30) final  String createdBy;
@override@HiveField(31) final  DateTime updatedAt;
@override@HiveField(32) final  String updatedBy;
@override@JsonKey()@HiveField(33) final  bool synced;
@override@HiveField(34) final  DateTime? lastSyncedAt;
@override@HiveField(35) final  String? pendingOperation;

/// Create a copy of JewelleryOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JewelleryOrderCopyWith<_JewelleryOrder> get copyWith => __$JewelleryOrderCopyWithImpl<_JewelleryOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JewelleryOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JewelleryOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.itemDescription, itemDescription) || other.itemDescription == itemDescription)&&(identical(other.designReference, designReference) || other.designReference == designReference)&&(identical(other.designNotes, designNotes) || other.designNotes == designNotes)&&(identical(other.metalType, metalType) || other.metalType == metalType)&&(identical(other.estimatedWeightGrams, estimatedWeightGrams) || other.estimatedWeightGrams == estimatedWeightGrams)&&(identical(other.actualWeightGrams, actualWeightGrams) || other.actualWeightGrams == actualWeightGrams)&&(identical(other.metalRatePerGramPaisa, metalRatePerGramPaisa) || other.metalRatePerGramPaisa == metalRatePerGramPaisa)&&(identical(other.makingChargesPerGramPaisa, makingChargesPerGramPaisa) || other.makingChargesPerGramPaisa == makingChargesPerGramPaisa)&&(identical(other.wastagePercent, wastagePercent) || other.wastagePercent == wastagePercent)&&(identical(other.stoneChargesPaisa, stoneChargesPaisa) || other.stoneChargesPaisa == stoneChargesPaisa)&&(identical(other.otherChargesPaisa, otherChargesPaisa) || other.otherChargesPaisa == otherChargesPaisa)&&(identical(other.estimatedTotalPaisa, estimatedTotalPaisa) || other.estimatedTotalPaisa == estimatedTotalPaisa)&&(identical(other.actualTotalPaisa, actualTotalPaisa) || other.actualTotalPaisa == actualTotalPaisa)&&(identical(other.advanceReceivedPaisa, advanceReceivedPaisa) || other.advanceReceivedPaisa == advanceReceivedPaisa)&&(identical(other.advancePaymentMode, advancePaymentMode) || other.advancePaymentMode == advancePaymentMode)&&(identical(other.orderDate, orderDate) || other.orderDate == orderDate)&&(identical(other.promisedDeliveryDate, promisedDeliveryDate) || other.promisedDeliveryDate == promisedDeliveryDate)&&(identical(other.actualDeliveryDate, actualDeliveryDate) || other.actualDeliveryDate == actualDeliveryDate)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._statusHistory, _statusHistory)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&const DeepCollectionEquality().equals(other._workProgress, _workProgress)&&(identical(other.finalProductId, finalProductId) || other.finalProductId == finalProductId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,customerId,customerName,customerPhone,itemDescription,designReference,designNotes,metalType,estimatedWeightGrams,actualWeightGrams,metalRatePerGramPaisa,makingChargesPerGramPaisa,wastagePercent,stoneChargesPaisa,otherChargesPaisa,estimatedTotalPaisa,actualTotalPaisa,advanceReceivedPaisa,advancePaymentMode,orderDate,promisedDeliveryDate,actualDeliveryDate,status,const DeepCollectionEquality().hash(_statusHistory),assignedTo,const DeepCollectionEquality().hash(_workProgress),finalProductId,invoiceId,createdAt,createdBy,updatedAt,updatedBy,synced,lastSyncedAt,pendingOperation]);

@override
String toString() {
  return 'JewelleryOrder(id: $id, tenantId: $tenantId, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, itemDescription: $itemDescription, designReference: $designReference, designNotes: $designNotes, metalType: $metalType, estimatedWeightGrams: $estimatedWeightGrams, actualWeightGrams: $actualWeightGrams, metalRatePerGramPaisa: $metalRatePerGramPaisa, makingChargesPerGramPaisa: $makingChargesPerGramPaisa, wastagePercent: $wastagePercent, stoneChargesPaisa: $stoneChargesPaisa, otherChargesPaisa: $otherChargesPaisa, estimatedTotalPaisa: $estimatedTotalPaisa, actualTotalPaisa: $actualTotalPaisa, advanceReceivedPaisa: $advanceReceivedPaisa, advancePaymentMode: $advancePaymentMode, orderDate: $orderDate, promisedDeliveryDate: $promisedDeliveryDate, actualDeliveryDate: $actualDeliveryDate, status: $status, statusHistory: $statusHistory, assignedTo: $assignedTo, workProgress: $workProgress, finalProductId: $finalProductId, invoiceId: $invoiceId, createdAt: $createdAt, createdBy: $createdBy, updatedAt: $updatedAt, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class _$JewelleryOrderCopyWith<$Res> implements $JewelleryOrderCopyWith<$Res> {
  factory _$JewelleryOrderCopyWith(_JewelleryOrder value, $Res Function(_JewelleryOrder) _then) = __$JewelleryOrderCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String customerId,@HiveField(3) String customerName,@HiveField(4) String? customerPhone,@HiveField(5) String itemDescription,@HiveField(6) String? designReference,@HiveField(7) String? designNotes,@HiveField(8) MetalType metalType,@HiveField(9) double estimatedWeightGrams,@HiveField(10) double? actualWeightGrams,@HiveField(11) int metalRatePerGramPaisa,@HiveField(12) int makingChargesPerGramPaisa,@HiveField(13) double wastagePercent,@HiveField(14) int stoneChargesPaisa,@HiveField(15) int otherChargesPaisa,@HiveField(16) int estimatedTotalPaisa,@HiveField(17) int? actualTotalPaisa,@HiveField(18) int advanceReceivedPaisa,@HiveField(19) String? advancePaymentMode,@HiveField(20) DateTime orderDate,@HiveField(21) String promisedDeliveryDate,@HiveField(22) String? actualDeliveryDate,@HiveField(23) String status,@HiveField(24) List<OrderStatusUpdate>? statusHistory,@HiveField(25) String? assignedTo,@HiveField(26) List<WorkProgressUpdate>? workProgress,@HiveField(27) String? finalProductId,@HiveField(28) String? invoiceId,@HiveField(29) DateTime createdAt,@HiveField(30) String createdBy,@HiveField(31) DateTime updatedAt,@HiveField(32) String updatedBy,@HiveField(33) bool synced,@HiveField(34) DateTime? lastSyncedAt,@HiveField(35) String? pendingOperation
});




}
/// @nodoc
class __$JewelleryOrderCopyWithImpl<$Res>
    implements _$JewelleryOrderCopyWith<$Res> {
  __$JewelleryOrderCopyWithImpl(this._self, this._then);

  final _JewelleryOrder _self;
  final $Res Function(_JewelleryOrder) _then;

/// Create a copy of JewelleryOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? customerId = null,Object? customerName = null,Object? customerPhone = freezed,Object? itemDescription = null,Object? designReference = freezed,Object? designNotes = freezed,Object? metalType = null,Object? estimatedWeightGrams = null,Object? actualWeightGrams = freezed,Object? metalRatePerGramPaisa = null,Object? makingChargesPerGramPaisa = null,Object? wastagePercent = null,Object? stoneChargesPaisa = null,Object? otherChargesPaisa = null,Object? estimatedTotalPaisa = null,Object? actualTotalPaisa = freezed,Object? advanceReceivedPaisa = null,Object? advancePaymentMode = freezed,Object? orderDate = null,Object? promisedDeliveryDate = null,Object? actualDeliveryDate = freezed,Object? status = null,Object? statusHistory = freezed,Object? assignedTo = freezed,Object? workProgress = freezed,Object? finalProductId = freezed,Object? invoiceId = freezed,Object? createdAt = null,Object? createdBy = null,Object? updatedAt = null,Object? updatedBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_JewelleryOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,itemDescription: null == itemDescription ? _self.itemDescription : itemDescription // ignore: cast_nullable_to_non_nullable
as String,designReference: freezed == designReference ? _self.designReference : designReference // ignore: cast_nullable_to_non_nullable
as String?,designNotes: freezed == designNotes ? _self.designNotes : designNotes // ignore: cast_nullable_to_non_nullable
as String?,metalType: null == metalType ? _self.metalType : metalType // ignore: cast_nullable_to_non_nullable
as MetalType,estimatedWeightGrams: null == estimatedWeightGrams ? _self.estimatedWeightGrams : estimatedWeightGrams // ignore: cast_nullable_to_non_nullable
as double,actualWeightGrams: freezed == actualWeightGrams ? _self.actualWeightGrams : actualWeightGrams // ignore: cast_nullable_to_non_nullable
as double?,metalRatePerGramPaisa: null == metalRatePerGramPaisa ? _self.metalRatePerGramPaisa : metalRatePerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,makingChargesPerGramPaisa: null == makingChargesPerGramPaisa ? _self.makingChargesPerGramPaisa : makingChargesPerGramPaisa // ignore: cast_nullable_to_non_nullable
as int,wastagePercent: null == wastagePercent ? _self.wastagePercent : wastagePercent // ignore: cast_nullable_to_non_nullable
as double,stoneChargesPaisa: null == stoneChargesPaisa ? _self.stoneChargesPaisa : stoneChargesPaisa // ignore: cast_nullable_to_non_nullable
as int,otherChargesPaisa: null == otherChargesPaisa ? _self.otherChargesPaisa : otherChargesPaisa // ignore: cast_nullable_to_non_nullable
as int,estimatedTotalPaisa: null == estimatedTotalPaisa ? _self.estimatedTotalPaisa : estimatedTotalPaisa // ignore: cast_nullable_to_non_nullable
as int,actualTotalPaisa: freezed == actualTotalPaisa ? _self.actualTotalPaisa : actualTotalPaisa // ignore: cast_nullable_to_non_nullable
as int?,advanceReceivedPaisa: null == advanceReceivedPaisa ? _self.advanceReceivedPaisa : advanceReceivedPaisa // ignore: cast_nullable_to_non_nullable
as int,advancePaymentMode: freezed == advancePaymentMode ? _self.advancePaymentMode : advancePaymentMode // ignore: cast_nullable_to_non_nullable
as String?,orderDate: null == orderDate ? _self.orderDate : orderDate // ignore: cast_nullable_to_non_nullable
as DateTime,promisedDeliveryDate: null == promisedDeliveryDate ? _self.promisedDeliveryDate : promisedDeliveryDate // ignore: cast_nullable_to_non_nullable
as String,actualDeliveryDate: freezed == actualDeliveryDate ? _self.actualDeliveryDate : actualDeliveryDate // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,statusHistory: freezed == statusHistory ? _self._statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<OrderStatusUpdate>?,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,workProgress: freezed == workProgress ? _self._workProgress : workProgress // ignore: cast_nullable_to_non_nullable
as List<WorkProgressUpdate>?,finalProductId: freezed == finalProductId ? _self.finalProductId : finalProductId // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OrderStatusUpdate {

 String get status; DateTime get timestamp; String get updatedBy; String? get notes;
/// Create a copy of OrderStatusUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderStatusUpdateCopyWith<OrderStatusUpdate> get copyWith => _$OrderStatusUpdateCopyWithImpl<OrderStatusUpdate>(this as OrderStatusUpdate, _$identity);

  /// Serializes this OrderStatusUpdate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderStatusUpdate&&(identical(other.status, status) || other.status == status)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,timestamp,updatedBy,notes);

@override
String toString() {
  return 'OrderStatusUpdate(status: $status, timestamp: $timestamp, updatedBy: $updatedBy, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $OrderStatusUpdateCopyWith<$Res>  {
  factory $OrderStatusUpdateCopyWith(OrderStatusUpdate value, $Res Function(OrderStatusUpdate) _then) = _$OrderStatusUpdateCopyWithImpl;
@useResult
$Res call({
 String status, DateTime timestamp, String updatedBy, String? notes
});




}
/// @nodoc
class _$OrderStatusUpdateCopyWithImpl<$Res>
    implements $OrderStatusUpdateCopyWith<$Res> {
  _$OrderStatusUpdateCopyWithImpl(this._self, this._then);

  final OrderStatusUpdate _self;
  final $Res Function(OrderStatusUpdate) _then;

/// Create a copy of OrderStatusUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? timestamp = null,Object? updatedBy = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderStatusUpdate].
extension OrderStatusUpdatePatterns on OrderStatusUpdate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderStatusUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderStatusUpdate() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderStatusUpdate value)  $default,){
final _that = this;
switch (_that) {
case _OrderStatusUpdate():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderStatusUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _OrderStatusUpdate() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  DateTime timestamp,  String updatedBy,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderStatusUpdate() when $default != null:
return $default(_that.status,_that.timestamp,_that.updatedBy,_that.notes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  DateTime timestamp,  String updatedBy,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _OrderStatusUpdate():
return $default(_that.status,_that.timestamp,_that.updatedBy,_that.notes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  DateTime timestamp,  String updatedBy,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _OrderStatusUpdate() when $default != null:
return $default(_that.status,_that.timestamp,_that.updatedBy,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderStatusUpdate implements OrderStatusUpdate {
  const _OrderStatusUpdate({required this.status, required this.timestamp, required this.updatedBy, this.notes});
  factory _OrderStatusUpdate.fromJson(Map<String, dynamic> json) => _$OrderStatusUpdateFromJson(json);

@override final  String status;
@override final  DateTime timestamp;
@override final  String updatedBy;
@override final  String? notes;

/// Create a copy of OrderStatusUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderStatusUpdateCopyWith<_OrderStatusUpdate> get copyWith => __$OrderStatusUpdateCopyWithImpl<_OrderStatusUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderStatusUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderStatusUpdate&&(identical(other.status, status) || other.status == status)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,timestamp,updatedBy,notes);

@override
String toString() {
  return 'OrderStatusUpdate(status: $status, timestamp: $timestamp, updatedBy: $updatedBy, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$OrderStatusUpdateCopyWith<$Res> implements $OrderStatusUpdateCopyWith<$Res> {
  factory _$OrderStatusUpdateCopyWith(_OrderStatusUpdate value, $Res Function(_OrderStatusUpdate) _then) = __$OrderStatusUpdateCopyWithImpl;
@override @useResult
$Res call({
 String status, DateTime timestamp, String updatedBy, String? notes
});




}
/// @nodoc
class __$OrderStatusUpdateCopyWithImpl<$Res>
    implements _$OrderStatusUpdateCopyWith<$Res> {
  __$OrderStatusUpdateCopyWithImpl(this._self, this._then);

  final _OrderStatusUpdate _self;
  final $Res Function(_OrderStatusUpdate) _then;

/// Create a copy of OrderStatusUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? timestamp = null,Object? updatedBy = null,Object? notes = freezed,}) {
  return _then(_OrderStatusUpdate(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$WorkProgressUpdate {

 String get stage;// CASTING, FILING, SETTING, POLISHING, etc.
 DateTime get timestamp; String? get notes; List<String>? get imageUrls;
/// Create a copy of WorkProgressUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkProgressUpdateCopyWith<WorkProgressUpdate> get copyWith => _$WorkProgressUpdateCopyWithImpl<WorkProgressUpdate>(this as WorkProgressUpdate, _$identity);

  /// Serializes this WorkProgressUpdate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkProgressUpdate&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.imageUrls, imageUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stage,timestamp,notes,const DeepCollectionEquality().hash(imageUrls));

@override
String toString() {
  return 'WorkProgressUpdate(stage: $stage, timestamp: $timestamp, notes: $notes, imageUrls: $imageUrls)';
}


}

/// @nodoc
abstract mixin class $WorkProgressUpdateCopyWith<$Res>  {
  factory $WorkProgressUpdateCopyWith(WorkProgressUpdate value, $Res Function(WorkProgressUpdate) _then) = _$WorkProgressUpdateCopyWithImpl;
@useResult
$Res call({
 String stage, DateTime timestamp, String? notes, List<String>? imageUrls
});




}
/// @nodoc
class _$WorkProgressUpdateCopyWithImpl<$Res>
    implements $WorkProgressUpdateCopyWith<$Res> {
  _$WorkProgressUpdateCopyWithImpl(this._self, this._then);

  final WorkProgressUpdate _self;
  final $Res Function(WorkProgressUpdate) _then;

/// Create a copy of WorkProgressUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stage = null,Object? timestamp = null,Object? notes = freezed,Object? imageUrls = freezed,}) {
  return _then(_self.copyWith(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,imageUrls: freezed == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkProgressUpdate].
extension WorkProgressUpdatePatterns on WorkProgressUpdate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkProgressUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkProgressUpdate() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkProgressUpdate value)  $default,){
final _that = this;
switch (_that) {
case _WorkProgressUpdate():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkProgressUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _WorkProgressUpdate() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String stage,  DateTime timestamp,  String? notes,  List<String>? imageUrls)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkProgressUpdate() when $default != null:
return $default(_that.stage,_that.timestamp,_that.notes,_that.imageUrls);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String stage,  DateTime timestamp,  String? notes,  List<String>? imageUrls)  $default,) {final _that = this;
switch (_that) {
case _WorkProgressUpdate():
return $default(_that.stage,_that.timestamp,_that.notes,_that.imageUrls);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String stage,  DateTime timestamp,  String? notes,  List<String>? imageUrls)?  $default,) {final _that = this;
switch (_that) {
case _WorkProgressUpdate() when $default != null:
return $default(_that.stage,_that.timestamp,_that.notes,_that.imageUrls);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkProgressUpdate implements WorkProgressUpdate {
  const _WorkProgressUpdate({required this.stage, required this.timestamp, this.notes, final  List<String>? imageUrls}): _imageUrls = imageUrls;
  factory _WorkProgressUpdate.fromJson(Map<String, dynamic> json) => _$WorkProgressUpdateFromJson(json);

@override final  String stage;
// CASTING, FILING, SETTING, POLISHING, etc.
@override final  DateTime timestamp;
@override final  String? notes;
 final  List<String>? _imageUrls;
@override List<String>? get imageUrls {
  final value = _imageUrls;
  if (value == null) return null;
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of WorkProgressUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkProgressUpdateCopyWith<_WorkProgressUpdate> get copyWith => __$WorkProgressUpdateCopyWithImpl<_WorkProgressUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkProgressUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkProgressUpdate&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other._imageUrls, _imageUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stage,timestamp,notes,const DeepCollectionEquality().hash(_imageUrls));

@override
String toString() {
  return 'WorkProgressUpdate(stage: $stage, timestamp: $timestamp, notes: $notes, imageUrls: $imageUrls)';
}


}

/// @nodoc
abstract mixin class _$WorkProgressUpdateCopyWith<$Res> implements $WorkProgressUpdateCopyWith<$Res> {
  factory _$WorkProgressUpdateCopyWith(_WorkProgressUpdate value, $Res Function(_WorkProgressUpdate) _then) = __$WorkProgressUpdateCopyWithImpl;
@override @useResult
$Res call({
 String stage, DateTime timestamp, String? notes, List<String>? imageUrls
});




}
/// @nodoc
class __$WorkProgressUpdateCopyWithImpl<$Res>
    implements _$WorkProgressUpdateCopyWith<$Res> {
  __$WorkProgressUpdateCopyWithImpl(this._self, this._then);

  final _WorkProgressUpdate _self;
  final $Res Function(_WorkProgressUpdate) _then;

/// Create a copy of WorkProgressUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stage = null,Object? timestamp = null,Object? notes = freezed,Object? imageUrls = freezed,}) {
  return _then(_WorkProgressUpdate(
stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,imageUrls: freezed == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}


/// @nodoc
mixin _$HallmarkRegisterEntry {

@HiveField(0) String get id;@HiveField(1) String get tenantId;@HiveField(2) String get huid;// 6-digit Hallmark Unique ID
@HiveField(3) String get productId;@HiveField(4) String get productName;@HiveField(5) PurityStandard get purityStandard;@HiveField(6) double get weightGrams;@HiveField(7) String? get articleType;// Ring, Chain, etc.
// BIS details
@HiveField(8) String? get bisLogo;@HiveField(9) String? get purityMark;@HiveField(10) String? get assayingCenterMark;@HiveField(11) String? get jewelerMark;// Date
@HiveField(12) DateTime get hallmarkDate;@HiveField(13) String? get registrationNumber;// BIS registration
// Status
@HiveField(14) String get status;// ACTIVE, SOLD, RETURNED
@HiveField(15) String? get saleInvoiceId;@HiveField(16) DateTime? get soldDate;// Images
@HiveField(17) String? get hallmarkImageUrl;@HiveField(18) String? get productImageUrl;// Metadata
@HiveField(19) DateTime get createdAt;@HiveField(20) bool get synced;@HiveField(21) DateTime? get lastSyncedAt;
/// Create a copy of HallmarkRegisterEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HallmarkRegisterEntryCopyWith<HallmarkRegisterEntry> get copyWith => _$HallmarkRegisterEntryCopyWithImpl<HallmarkRegisterEntry>(this as HallmarkRegisterEntry, _$identity);

  /// Serializes this HallmarkRegisterEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HallmarkRegisterEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.huid, huid) || other.huid == huid)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.purityStandard, purityStandard) || other.purityStandard == purityStandard)&&(identical(other.weightGrams, weightGrams) || other.weightGrams == weightGrams)&&(identical(other.articleType, articleType) || other.articleType == articleType)&&(identical(other.bisLogo, bisLogo) || other.bisLogo == bisLogo)&&(identical(other.purityMark, purityMark) || other.purityMark == purityMark)&&(identical(other.assayingCenterMark, assayingCenterMark) || other.assayingCenterMark == assayingCenterMark)&&(identical(other.jewelerMark, jewelerMark) || other.jewelerMark == jewelerMark)&&(identical(other.hallmarkDate, hallmarkDate) || other.hallmarkDate == hallmarkDate)&&(identical(other.registrationNumber, registrationNumber) || other.registrationNumber == registrationNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.saleInvoiceId, saleInvoiceId) || other.saleInvoiceId == saleInvoiceId)&&(identical(other.soldDate, soldDate) || other.soldDate == soldDate)&&(identical(other.hallmarkImageUrl, hallmarkImageUrl) || other.hallmarkImageUrl == hallmarkImageUrl)&&(identical(other.productImageUrl, productImageUrl) || other.productImageUrl == productImageUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,huid,productId,productName,purityStandard,weightGrams,articleType,bisLogo,purityMark,assayingCenterMark,jewelerMark,hallmarkDate,registrationNumber,status,saleInvoiceId,soldDate,hallmarkImageUrl,productImageUrl,createdAt,synced,lastSyncedAt]);

@override
String toString() {
  return 'HallmarkRegisterEntry(id: $id, tenantId: $tenantId, huid: $huid, productId: $productId, productName: $productName, purityStandard: $purityStandard, weightGrams: $weightGrams, articleType: $articleType, bisLogo: $bisLogo, purityMark: $purityMark, assayingCenterMark: $assayingCenterMark, jewelerMark: $jewelerMark, hallmarkDate: $hallmarkDate, registrationNumber: $registrationNumber, status: $status, saleInvoiceId: $saleInvoiceId, soldDate: $soldDate, hallmarkImageUrl: $hallmarkImageUrl, productImageUrl: $productImageUrl, createdAt: $createdAt, synced: $synced, lastSyncedAt: $lastSyncedAt)';
}


}

/// @nodoc
abstract mixin class $HallmarkRegisterEntryCopyWith<$Res>  {
  factory $HallmarkRegisterEntryCopyWith(HallmarkRegisterEntry value, $Res Function(HallmarkRegisterEntry) _then) = _$HallmarkRegisterEntryCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String huid,@HiveField(3) String productId,@HiveField(4) String productName,@HiveField(5) PurityStandard purityStandard,@HiveField(6) double weightGrams,@HiveField(7) String? articleType,@HiveField(8) String? bisLogo,@HiveField(9) String? purityMark,@HiveField(10) String? assayingCenterMark,@HiveField(11) String? jewelerMark,@HiveField(12) DateTime hallmarkDate,@HiveField(13) String? registrationNumber,@HiveField(14) String status,@HiveField(15) String? saleInvoiceId,@HiveField(16) DateTime? soldDate,@HiveField(17) String? hallmarkImageUrl,@HiveField(18) String? productImageUrl,@HiveField(19) DateTime createdAt,@HiveField(20) bool synced,@HiveField(21) DateTime? lastSyncedAt
});




}
/// @nodoc
class _$HallmarkRegisterEntryCopyWithImpl<$Res>
    implements $HallmarkRegisterEntryCopyWith<$Res> {
  _$HallmarkRegisterEntryCopyWithImpl(this._self, this._then);

  final HallmarkRegisterEntry _self;
  final $Res Function(HallmarkRegisterEntry) _then;

/// Create a copy of HallmarkRegisterEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? huid = null,Object? productId = null,Object? productName = null,Object? purityStandard = null,Object? weightGrams = null,Object? articleType = freezed,Object? bisLogo = freezed,Object? purityMark = freezed,Object? assayingCenterMark = freezed,Object? jewelerMark = freezed,Object? hallmarkDate = null,Object? registrationNumber = freezed,Object? status = null,Object? saleInvoiceId = freezed,Object? soldDate = freezed,Object? hallmarkImageUrl = freezed,Object? productImageUrl = freezed,Object? createdAt = null,Object? synced = null,Object? lastSyncedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,huid: null == huid ? _self.huid : huid // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,purityStandard: null == purityStandard ? _self.purityStandard : purityStandard // ignore: cast_nullable_to_non_nullable
as PurityStandard,weightGrams: null == weightGrams ? _self.weightGrams : weightGrams // ignore: cast_nullable_to_non_nullable
as double,articleType: freezed == articleType ? _self.articleType : articleType // ignore: cast_nullable_to_non_nullable
as String?,bisLogo: freezed == bisLogo ? _self.bisLogo : bisLogo // ignore: cast_nullable_to_non_nullable
as String?,purityMark: freezed == purityMark ? _self.purityMark : purityMark // ignore: cast_nullable_to_non_nullable
as String?,assayingCenterMark: freezed == assayingCenterMark ? _self.assayingCenterMark : assayingCenterMark // ignore: cast_nullable_to_non_nullable
as String?,jewelerMark: freezed == jewelerMark ? _self.jewelerMark : jewelerMark // ignore: cast_nullable_to_non_nullable
as String?,hallmarkDate: null == hallmarkDate ? _self.hallmarkDate : hallmarkDate // ignore: cast_nullable_to_non_nullable
as DateTime,registrationNumber: freezed == registrationNumber ? _self.registrationNumber : registrationNumber // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,saleInvoiceId: freezed == saleInvoiceId ? _self.saleInvoiceId : saleInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,soldDate: freezed == soldDate ? _self.soldDate : soldDate // ignore: cast_nullable_to_non_nullable
as DateTime?,hallmarkImageUrl: freezed == hallmarkImageUrl ? _self.hallmarkImageUrl : hallmarkImageUrl // ignore: cast_nullable_to_non_nullable
as String?,productImageUrl: freezed == productImageUrl ? _self.productImageUrl : productImageUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [HallmarkRegisterEntry].
extension HallmarkRegisterEntryPatterns on HallmarkRegisterEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HallmarkRegisterEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HallmarkRegisterEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HallmarkRegisterEntry value)  $default,){
final _that = this;
switch (_that) {
case _HallmarkRegisterEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HallmarkRegisterEntry value)?  $default,){
final _that = this;
switch (_that) {
case _HallmarkRegisterEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String huid, @HiveField(3)  String productId, @HiveField(4)  String productName, @HiveField(5)  PurityStandard purityStandard, @HiveField(6)  double weightGrams, @HiveField(7)  String? articleType, @HiveField(8)  String? bisLogo, @HiveField(9)  String? purityMark, @HiveField(10)  String? assayingCenterMark, @HiveField(11)  String? jewelerMark, @HiveField(12)  DateTime hallmarkDate, @HiveField(13)  String? registrationNumber, @HiveField(14)  String status, @HiveField(15)  String? saleInvoiceId, @HiveField(16)  DateTime? soldDate, @HiveField(17)  String? hallmarkImageUrl, @HiveField(18)  String? productImageUrl, @HiveField(19)  DateTime createdAt, @HiveField(20)  bool synced, @HiveField(21)  DateTime? lastSyncedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HallmarkRegisterEntry() when $default != null:
return $default(_that.id,_that.tenantId,_that.huid,_that.productId,_that.productName,_that.purityStandard,_that.weightGrams,_that.articleType,_that.bisLogo,_that.purityMark,_that.assayingCenterMark,_that.jewelerMark,_that.hallmarkDate,_that.registrationNumber,_that.status,_that.saleInvoiceId,_that.soldDate,_that.hallmarkImageUrl,_that.productImageUrl,_that.createdAt,_that.synced,_that.lastSyncedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String huid, @HiveField(3)  String productId, @HiveField(4)  String productName, @HiveField(5)  PurityStandard purityStandard, @HiveField(6)  double weightGrams, @HiveField(7)  String? articleType, @HiveField(8)  String? bisLogo, @HiveField(9)  String? purityMark, @HiveField(10)  String? assayingCenterMark, @HiveField(11)  String? jewelerMark, @HiveField(12)  DateTime hallmarkDate, @HiveField(13)  String? registrationNumber, @HiveField(14)  String status, @HiveField(15)  String? saleInvoiceId, @HiveField(16)  DateTime? soldDate, @HiveField(17)  String? hallmarkImageUrl, @HiveField(18)  String? productImageUrl, @HiveField(19)  DateTime createdAt, @HiveField(20)  bool synced, @HiveField(21)  DateTime? lastSyncedAt)  $default,) {final _that = this;
switch (_that) {
case _HallmarkRegisterEntry():
return $default(_that.id,_that.tenantId,_that.huid,_that.productId,_that.productName,_that.purityStandard,_that.weightGrams,_that.articleType,_that.bisLogo,_that.purityMark,_that.assayingCenterMark,_that.jewelerMark,_that.hallmarkDate,_that.registrationNumber,_that.status,_that.saleInvoiceId,_that.soldDate,_that.hallmarkImageUrl,_that.productImageUrl,_that.createdAt,_that.synced,_that.lastSyncedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String huid, @HiveField(3)  String productId, @HiveField(4)  String productName, @HiveField(5)  PurityStandard purityStandard, @HiveField(6)  double weightGrams, @HiveField(7)  String? articleType, @HiveField(8)  String? bisLogo, @HiveField(9)  String? purityMark, @HiveField(10)  String? assayingCenterMark, @HiveField(11)  String? jewelerMark, @HiveField(12)  DateTime hallmarkDate, @HiveField(13)  String? registrationNumber, @HiveField(14)  String status, @HiveField(15)  String? saleInvoiceId, @HiveField(16)  DateTime? soldDate, @HiveField(17)  String? hallmarkImageUrl, @HiveField(18)  String? productImageUrl, @HiveField(19)  DateTime createdAt, @HiveField(20)  bool synced, @HiveField(21)  DateTime? lastSyncedAt)?  $default,) {final _that = this;
switch (_that) {
case _HallmarkRegisterEntry() when $default != null:
return $default(_that.id,_that.tenantId,_that.huid,_that.productId,_that.productName,_that.purityStandard,_that.weightGrams,_that.articleType,_that.bisLogo,_that.purityMark,_that.assayingCenterMark,_that.jewelerMark,_that.hallmarkDate,_that.registrationNumber,_that.status,_that.saleInvoiceId,_that.soldDate,_that.hallmarkImageUrl,_that.productImageUrl,_that.createdAt,_that.synced,_that.lastSyncedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 55)
class _HallmarkRegisterEntry extends HallmarkRegisterEntry {
  const _HallmarkRegisterEntry({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.huid, @HiveField(3) required this.productId, @HiveField(4) required this.productName, @HiveField(5) required this.purityStandard, @HiveField(6) required this.weightGrams, @HiveField(7) this.articleType, @HiveField(8) this.bisLogo, @HiveField(9) this.purityMark, @HiveField(10) this.assayingCenterMark, @HiveField(11) this.jewelerMark, @HiveField(12) required this.hallmarkDate, @HiveField(13) this.registrationNumber, @HiveField(14) this.status = 'ACTIVE', @HiveField(15) this.saleInvoiceId, @HiveField(16) this.soldDate, @HiveField(17) this.hallmarkImageUrl, @HiveField(18) this.productImageUrl, @HiveField(19) required this.createdAt, @HiveField(20) this.synced = true, @HiveField(21) this.lastSyncedAt}): super._();
  factory _HallmarkRegisterEntry.fromJson(Map<String, dynamic> json) => _$HallmarkRegisterEntryFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
@override@HiveField(2) final  String huid;
// 6-digit Hallmark Unique ID
@override@HiveField(3) final  String productId;
@override@HiveField(4) final  String productName;
@override@HiveField(5) final  PurityStandard purityStandard;
@override@HiveField(6) final  double weightGrams;
@override@HiveField(7) final  String? articleType;
// Ring, Chain, etc.
// BIS details
@override@HiveField(8) final  String? bisLogo;
@override@HiveField(9) final  String? purityMark;
@override@HiveField(10) final  String? assayingCenterMark;
@override@HiveField(11) final  String? jewelerMark;
// Date
@override@HiveField(12) final  DateTime hallmarkDate;
@override@HiveField(13) final  String? registrationNumber;
// BIS registration
// Status
@override@JsonKey()@HiveField(14) final  String status;
// ACTIVE, SOLD, RETURNED
@override@HiveField(15) final  String? saleInvoiceId;
@override@HiveField(16) final  DateTime? soldDate;
// Images
@override@HiveField(17) final  String? hallmarkImageUrl;
@override@HiveField(18) final  String? productImageUrl;
// Metadata
@override@HiveField(19) final  DateTime createdAt;
@override@JsonKey()@HiveField(20) final  bool synced;
@override@HiveField(21) final  DateTime? lastSyncedAt;

/// Create a copy of HallmarkRegisterEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HallmarkRegisterEntryCopyWith<_HallmarkRegisterEntry> get copyWith => __$HallmarkRegisterEntryCopyWithImpl<_HallmarkRegisterEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HallmarkRegisterEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HallmarkRegisterEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.huid, huid) || other.huid == huid)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.purityStandard, purityStandard) || other.purityStandard == purityStandard)&&(identical(other.weightGrams, weightGrams) || other.weightGrams == weightGrams)&&(identical(other.articleType, articleType) || other.articleType == articleType)&&(identical(other.bisLogo, bisLogo) || other.bisLogo == bisLogo)&&(identical(other.purityMark, purityMark) || other.purityMark == purityMark)&&(identical(other.assayingCenterMark, assayingCenterMark) || other.assayingCenterMark == assayingCenterMark)&&(identical(other.jewelerMark, jewelerMark) || other.jewelerMark == jewelerMark)&&(identical(other.hallmarkDate, hallmarkDate) || other.hallmarkDate == hallmarkDate)&&(identical(other.registrationNumber, registrationNumber) || other.registrationNumber == registrationNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.saleInvoiceId, saleInvoiceId) || other.saleInvoiceId == saleInvoiceId)&&(identical(other.soldDate, soldDate) || other.soldDate == soldDate)&&(identical(other.hallmarkImageUrl, hallmarkImageUrl) || other.hallmarkImageUrl == hallmarkImageUrl)&&(identical(other.productImageUrl, productImageUrl) || other.productImageUrl == productImageUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,huid,productId,productName,purityStandard,weightGrams,articleType,bisLogo,purityMark,assayingCenterMark,jewelerMark,hallmarkDate,registrationNumber,status,saleInvoiceId,soldDate,hallmarkImageUrl,productImageUrl,createdAt,synced,lastSyncedAt]);

@override
String toString() {
  return 'HallmarkRegisterEntry(id: $id, tenantId: $tenantId, huid: $huid, productId: $productId, productName: $productName, purityStandard: $purityStandard, weightGrams: $weightGrams, articleType: $articleType, bisLogo: $bisLogo, purityMark: $purityMark, assayingCenterMark: $assayingCenterMark, jewelerMark: $jewelerMark, hallmarkDate: $hallmarkDate, registrationNumber: $registrationNumber, status: $status, saleInvoiceId: $saleInvoiceId, soldDate: $soldDate, hallmarkImageUrl: $hallmarkImageUrl, productImageUrl: $productImageUrl, createdAt: $createdAt, synced: $synced, lastSyncedAt: $lastSyncedAt)';
}


}

/// @nodoc
abstract mixin class _$HallmarkRegisterEntryCopyWith<$Res> implements $HallmarkRegisterEntryCopyWith<$Res> {
  factory _$HallmarkRegisterEntryCopyWith(_HallmarkRegisterEntry value, $Res Function(_HallmarkRegisterEntry) _then) = __$HallmarkRegisterEntryCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String huid,@HiveField(3) String productId,@HiveField(4) String productName,@HiveField(5) PurityStandard purityStandard,@HiveField(6) double weightGrams,@HiveField(7) String? articleType,@HiveField(8) String? bisLogo,@HiveField(9) String? purityMark,@HiveField(10) String? assayingCenterMark,@HiveField(11) String? jewelerMark,@HiveField(12) DateTime hallmarkDate,@HiveField(13) String? registrationNumber,@HiveField(14) String status,@HiveField(15) String? saleInvoiceId,@HiveField(16) DateTime? soldDate,@HiveField(17) String? hallmarkImageUrl,@HiveField(18) String? productImageUrl,@HiveField(19) DateTime createdAt,@HiveField(20) bool synced,@HiveField(21) DateTime? lastSyncedAt
});




}
/// @nodoc
class __$HallmarkRegisterEntryCopyWithImpl<$Res>
    implements _$HallmarkRegisterEntryCopyWith<$Res> {
  __$HallmarkRegisterEntryCopyWithImpl(this._self, this._then);

  final _HallmarkRegisterEntry _self;
  final $Res Function(_HallmarkRegisterEntry) _then;

/// Create a copy of HallmarkRegisterEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? huid = null,Object? productId = null,Object? productName = null,Object? purityStandard = null,Object? weightGrams = null,Object? articleType = freezed,Object? bisLogo = freezed,Object? purityMark = freezed,Object? assayingCenterMark = freezed,Object? jewelerMark = freezed,Object? hallmarkDate = null,Object? registrationNumber = freezed,Object? status = null,Object? saleInvoiceId = freezed,Object? soldDate = freezed,Object? hallmarkImageUrl = freezed,Object? productImageUrl = freezed,Object? createdAt = null,Object? synced = null,Object? lastSyncedAt = freezed,}) {
  return _then(_HallmarkRegisterEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,huid: null == huid ? _self.huid : huid // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,productName: null == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String,purityStandard: null == purityStandard ? _self.purityStandard : purityStandard // ignore: cast_nullable_to_non_nullable
as PurityStandard,weightGrams: null == weightGrams ? _self.weightGrams : weightGrams // ignore: cast_nullable_to_non_nullable
as double,articleType: freezed == articleType ? _self.articleType : articleType // ignore: cast_nullable_to_non_nullable
as String?,bisLogo: freezed == bisLogo ? _self.bisLogo : bisLogo // ignore: cast_nullable_to_non_nullable
as String?,purityMark: freezed == purityMark ? _self.purityMark : purityMark // ignore: cast_nullable_to_non_nullable
as String?,assayingCenterMark: freezed == assayingCenterMark ? _self.assayingCenterMark : assayingCenterMark // ignore: cast_nullable_to_non_nullable
as String?,jewelerMark: freezed == jewelerMark ? _self.jewelerMark : jewelerMark // ignore: cast_nullable_to_non_nullable
as String?,hallmarkDate: null == hallmarkDate ? _self.hallmarkDate : hallmarkDate // ignore: cast_nullable_to_non_nullable
as DateTime,registrationNumber: freezed == registrationNumber ? _self.registrationNumber : registrationNumber // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,saleInvoiceId: freezed == saleInvoiceId ? _self.saleInvoiceId : saleInvoiceId // ignore: cast_nullable_to_non_nullable
as String?,soldDate: freezed == soldDate ? _self.soldDate : soldDate // ignore: cast_nullable_to_non_nullable
as DateTime?,hallmarkImageUrl: freezed == hallmarkImageUrl ? _self.hallmarkImageUrl : hallmarkImageUrl // ignore: cast_nullable_to_non_nullable
as String?,productImageUrl: freezed == productImageUrl ? _self.productImageUrl : productImageUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
