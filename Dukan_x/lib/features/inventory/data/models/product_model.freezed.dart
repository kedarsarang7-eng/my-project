// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductImage {

 String get s3Key; String get s3ThumbnailKey; int get uploadedAt; int get fileSize;
/// Create a copy of ProductImage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductImageCopyWith<ProductImage> get copyWith => _$ProductImageCopyWithImpl<ProductImage>(this as ProductImage, _$identity);

  /// Serializes this ProductImage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductImage&&(identical(other.s3Key, s3Key) || other.s3Key == s3Key)&&(identical(other.s3ThumbnailKey, s3ThumbnailKey) || other.s3ThumbnailKey == s3ThumbnailKey)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,s3Key,s3ThumbnailKey,uploadedAt,fileSize);

@override
String toString() {
  return 'ProductImage(s3Key: $s3Key, s3ThumbnailKey: $s3ThumbnailKey, uploadedAt: $uploadedAt, fileSize: $fileSize)';
}


}

/// @nodoc
abstract mixin class $ProductImageCopyWith<$Res>  {
  factory $ProductImageCopyWith(ProductImage value, $Res Function(ProductImage) _then) = _$ProductImageCopyWithImpl;
@useResult
$Res call({
 String s3Key, String s3ThumbnailKey, int uploadedAt, int fileSize
});




}
/// @nodoc
class _$ProductImageCopyWithImpl<$Res>
    implements $ProductImageCopyWith<$Res> {
  _$ProductImageCopyWithImpl(this._self, this._then);

  final ProductImage _self;
  final $Res Function(ProductImage) _then;

/// Create a copy of ProductImage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? s3Key = null,Object? s3ThumbnailKey = null,Object? uploadedAt = null,Object? fileSize = null,}) {
  return _then(_self.copyWith(
s3Key: null == s3Key ? _self.s3Key : s3Key // ignore: cast_nullable_to_non_nullable
as String,s3ThumbnailKey: null == s3ThumbnailKey ? _self.s3ThumbnailKey : s3ThumbnailKey // ignore: cast_nullable_to_non_nullable
as String,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as int,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductImage].
extension ProductImagePatterns on ProductImage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductImage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductImage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductImage value)  $default,){
final _that = this;
switch (_that) {
case _ProductImage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductImage value)?  $default,){
final _that = this;
switch (_that) {
case _ProductImage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String s3Key,  String s3ThumbnailKey,  int uploadedAt,  int fileSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductImage() when $default != null:
return $default(_that.s3Key,_that.s3ThumbnailKey,_that.uploadedAt,_that.fileSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String s3Key,  String s3ThumbnailKey,  int uploadedAt,  int fileSize)  $default,) {final _that = this;
switch (_that) {
case _ProductImage():
return $default(_that.s3Key,_that.s3ThumbnailKey,_that.uploadedAt,_that.fileSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String s3Key,  String s3ThumbnailKey,  int uploadedAt,  int fileSize)?  $default,) {final _that = this;
switch (_that) {
case _ProductImage() when $default != null:
return $default(_that.s3Key,_that.s3ThumbnailKey,_that.uploadedAt,_that.fileSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductImage implements ProductImage {
  const _ProductImage({required this.s3Key, required this.s3ThumbnailKey, required this.uploadedAt, required this.fileSize});
  factory _ProductImage.fromJson(Map<String, dynamic> json) => _$ProductImageFromJson(json);

@override final  String s3Key;
@override final  String s3ThumbnailKey;
@override final  int uploadedAt;
@override final  int fileSize;

/// Create a copy of ProductImage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductImageCopyWith<_ProductImage> get copyWith => __$ProductImageCopyWithImpl<_ProductImage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductImageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductImage&&(identical(other.s3Key, s3Key) || other.s3Key == s3Key)&&(identical(other.s3ThumbnailKey, s3ThumbnailKey) || other.s3ThumbnailKey == s3ThumbnailKey)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,s3Key,s3ThumbnailKey,uploadedAt,fileSize);

@override
String toString() {
  return 'ProductImage(s3Key: $s3Key, s3ThumbnailKey: $s3ThumbnailKey, uploadedAt: $uploadedAt, fileSize: $fileSize)';
}


}

/// @nodoc
abstract mixin class _$ProductImageCopyWith<$Res> implements $ProductImageCopyWith<$Res> {
  factory _$ProductImageCopyWith(_ProductImage value, $Res Function(_ProductImage) _then) = __$ProductImageCopyWithImpl;
@override @useResult
$Res call({
 String s3Key, String s3ThumbnailKey, int uploadedAt, int fileSize
});




}
/// @nodoc
class __$ProductImageCopyWithImpl<$Res>
    implements _$ProductImageCopyWith<$Res> {
  __$ProductImageCopyWithImpl(this._self, this._then);

  final _ProductImage _self;
  final $Res Function(_ProductImage) _then;

/// Create a copy of ProductImage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? s3Key = null,Object? s3ThumbnailKey = null,Object? uploadedAt = null,Object? fileSize = null,}) {
  return _then(_ProductImage(
s3Key: null == s3Key ? _self.s3Key : s3Key // ignore: cast_nullable_to_non_nullable
as String,s3ThumbnailKey: null == s3ThumbnailKey ? _self.s3ThumbnailKey : s3ThumbnailKey // ignore: cast_nullable_to_non_nullable
as String,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as int,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ProductVariant {

 String get id; String get name; String? get sku; double? get price; int? get stock; String? get strength;
/// Create a copy of ProductVariant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductVariantCopyWith<ProductVariant> get copyWith => _$ProductVariantCopyWithImpl<ProductVariant>(this as ProductVariant, _$identity);

  /// Serializes this ProductVariant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductVariant&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.price, price) || other.price == price)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.strength, strength) || other.strength == strength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sku,price,stock,strength);

@override
String toString() {
  return 'ProductVariant(id: $id, name: $name, sku: $sku, price: $price, stock: $stock, strength: $strength)';
}


}

/// @nodoc
abstract mixin class $ProductVariantCopyWith<$Res>  {
  factory $ProductVariantCopyWith(ProductVariant value, $Res Function(ProductVariant) _then) = _$ProductVariantCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? sku, double? price, int? stock, String? strength
});




}
/// @nodoc
class _$ProductVariantCopyWithImpl<$Res>
    implements $ProductVariantCopyWith<$Res> {
  _$ProductVariantCopyWithImpl(this._self, this._then);

  final ProductVariant _self;
  final $Res Function(ProductVariant) _then;

/// Create a copy of ProductVariant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sku = freezed,Object? price = freezed,Object? stock = freezed,Object? strength = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double?,stock: freezed == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int?,strength: freezed == strength ? _self.strength : strength // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductVariant].
extension ProductVariantPatterns on ProductVariant {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductVariant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductVariant() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductVariant value)  $default,){
final _that = this;
switch (_that) {
case _ProductVariant():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductVariant value)?  $default,){
final _that = this;
switch (_that) {
case _ProductVariant() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? sku,  double? price,  int? stock,  String? strength)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductVariant() when $default != null:
return $default(_that.id,_that.name,_that.sku,_that.price,_that.stock,_that.strength);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? sku,  double? price,  int? stock,  String? strength)  $default,) {final _that = this;
switch (_that) {
case _ProductVariant():
return $default(_that.id,_that.name,_that.sku,_that.price,_that.stock,_that.strength);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? sku,  double? price,  int? stock,  String? strength)?  $default,) {final _that = this;
switch (_that) {
case _ProductVariant() when $default != null:
return $default(_that.id,_that.name,_that.sku,_that.price,_that.stock,_that.strength);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductVariant implements ProductVariant {
  const _ProductVariant({required this.id, required this.name, this.sku, this.price, this.stock, this.strength});
  factory _ProductVariant.fromJson(Map<String, dynamic> json) => _$ProductVariantFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? sku;
@override final  double? price;
@override final  int? stock;
@override final  String? strength;

/// Create a copy of ProductVariant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductVariantCopyWith<_ProductVariant> get copyWith => __$ProductVariantCopyWithImpl<_ProductVariant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductVariantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductVariant&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.price, price) || other.price == price)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.strength, strength) || other.strength == strength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sku,price,stock,strength);

@override
String toString() {
  return 'ProductVariant(id: $id, name: $name, sku: $sku, price: $price, stock: $stock, strength: $strength)';
}


}

/// @nodoc
abstract mixin class _$ProductVariantCopyWith<$Res> implements $ProductVariantCopyWith<$Res> {
  factory _$ProductVariantCopyWith(_ProductVariant value, $Res Function(_ProductVariant) _then) = __$ProductVariantCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? sku, double? price, int? stock, String? strength
});




}
/// @nodoc
class __$ProductVariantCopyWithImpl<$Res>
    implements _$ProductVariantCopyWith<$Res> {
  __$ProductVariantCopyWithImpl(this._self, this._then);

  final _ProductVariant _self;
  final $Res Function(_ProductVariant) _then;

/// Create a copy of ProductVariant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sku = freezed,Object? price = freezed,Object? stock = freezed,Object? strength = freezed,}) {
  return _then(_ProductVariant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double?,stock: freezed == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int?,strength: freezed == strength ? _self.strength : strength // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Product {

// Core identifiers
 String get id; String get tenantId; String get businessType;// Product metadata
 String get name; String? get description; String? get category; String? get brand;// Image data
 ProductImage? get mainImage; List<ProductImage>? get images;// Product specifications
 double get price; double? get mrp; double? get cost; double get gstRate; String? get hsn;// Barcode / identifiers
 String? get barcode; String? get sku;// Pharmacy-specific fields
 String? get batchNo; int? get expiryDate; String? get drugSchedule; String? get strength; String? get formulation; String? get manufacturer;// Stock & variants
 int get stock; int? get reorderLevel; int? get maxStock; String? get unit; List<ProductVariant>? get variants;// Metadata
 bool get isActive; int get createdAt; int get updatedAt; String get createdBy; String get updatedBy;// Sync tracking
 bool? get synced; int? get lastSyncedAt; int? get version;// Soft delete
 bool? get isDeleted; int? get deletedAt;
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCopyWith<Product> get copyWith => _$ProductCopyWithImpl<Product>(this as Product, _$identity);

  /// Serializes this Product to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Product&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.businessType, businessType) || other.businessType == businessType)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.mainImage, mainImage) || other.mainImage == mainImage)&&const DeepCollectionEquality().equals(other.images, images)&&(identical(other.price, price) || other.price == price)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.gstRate, gstRate) || other.gstRate == gstRate)&&(identical(other.hsn, hsn) || other.hsn == hsn)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.batchNo, batchNo) || other.batchNo == batchNo)&&(identical(other.expiryDate, expiryDate) || other.expiryDate == expiryDate)&&(identical(other.drugSchedule, drugSchedule) || other.drugSchedule == drugSchedule)&&(identical(other.strength, strength) || other.strength == strength)&&(identical(other.formulation, formulation) || other.formulation == formulation)&&(identical(other.manufacturer, manufacturer) || other.manufacturer == manufacturer)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.maxStock, maxStock) || other.maxStock == maxStock)&&(identical(other.unit, unit) || other.unit == unit)&&const DeepCollectionEquality().equals(other.variants, variants)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.version, version) || other.version == version)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,businessType,name,description,category,brand,mainImage,const DeepCollectionEquality().hash(images),price,mrp,cost,gstRate,hsn,barcode,sku,batchNo,expiryDate,drugSchedule,strength,formulation,manufacturer,stock,reorderLevel,maxStock,unit,const DeepCollectionEquality().hash(variants),isActive,createdAt,updatedAt,createdBy,updatedBy,synced,lastSyncedAt,version,isDeleted,deletedAt]);

@override
String toString() {
  return 'Product(id: $id, tenantId: $tenantId, businessType: $businessType, name: $name, description: $description, category: $category, brand: $brand, mainImage: $mainImage, images: $images, price: $price, mrp: $mrp, cost: $cost, gstRate: $gstRate, hsn: $hsn, barcode: $barcode, sku: $sku, batchNo: $batchNo, expiryDate: $expiryDate, drugSchedule: $drugSchedule, strength: $strength, formulation: $formulation, manufacturer: $manufacturer, stock: $stock, reorderLevel: $reorderLevel, maxStock: $maxStock, unit: $unit, variants: $variants, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, version: $version, isDeleted: $isDeleted, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $ProductCopyWith<$Res>  {
  factory $ProductCopyWith(Product value, $Res Function(Product) _then) = _$ProductCopyWithImpl;
@useResult
$Res call({
 String id, String tenantId, String businessType, String name, String? description, String? category, String? brand, ProductImage? mainImage, List<ProductImage>? images, double price, double? mrp, double? cost, double gstRate, String? hsn, String? barcode, String? sku, String? batchNo, int? expiryDate, String? drugSchedule, String? strength, String? formulation, String? manufacturer, int stock, int? reorderLevel, int? maxStock, String? unit, List<ProductVariant>? variants, bool isActive, int createdAt, int updatedAt, String createdBy, String updatedBy, bool? synced, int? lastSyncedAt, int? version, bool? isDeleted, int? deletedAt
});


$ProductImageCopyWith<$Res>? get mainImage;

}
/// @nodoc
class _$ProductCopyWithImpl<$Res>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._self, this._then);

  final Product _self;
  final $Res Function(Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? businessType = null,Object? name = null,Object? description = freezed,Object? category = freezed,Object? brand = freezed,Object? mainImage = freezed,Object? images = freezed,Object? price = null,Object? mrp = freezed,Object? cost = freezed,Object? gstRate = null,Object? hsn = freezed,Object? barcode = freezed,Object? sku = freezed,Object? batchNo = freezed,Object? expiryDate = freezed,Object? drugSchedule = freezed,Object? strength = freezed,Object? formulation = freezed,Object? manufacturer = freezed,Object? stock = null,Object? reorderLevel = freezed,Object? maxStock = freezed,Object? unit = freezed,Object? variants = freezed,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,Object? createdBy = null,Object? updatedBy = null,Object? synced = freezed,Object? lastSyncedAt = freezed,Object? version = freezed,Object? isDeleted = freezed,Object? deletedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,businessType: null == businessType ? _self.businessType : businessType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,mainImage: freezed == mainImage ? _self.mainImage : mainImage // ignore: cast_nullable_to_non_nullable
as ProductImage?,images: freezed == images ? _self.images : images // ignore: cast_nullable_to_non_nullable
as List<ProductImage>?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,mrp: freezed == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,gstRate: null == gstRate ? _self.gstRate : gstRate // ignore: cast_nullable_to_non_nullable
as double,hsn: freezed == hsn ? _self.hsn : hsn // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,batchNo: freezed == batchNo ? _self.batchNo : batchNo // ignore: cast_nullable_to_non_nullable
as String?,expiryDate: freezed == expiryDate ? _self.expiryDate : expiryDate // ignore: cast_nullable_to_non_nullable
as int?,drugSchedule: freezed == drugSchedule ? _self.drugSchedule : drugSchedule // ignore: cast_nullable_to_non_nullable
as String?,strength: freezed == strength ? _self.strength : strength // ignore: cast_nullable_to_non_nullable
as String?,formulation: freezed == formulation ? _self.formulation : formulation // ignore: cast_nullable_to_non_nullable
as String?,manufacturer: freezed == manufacturer ? _self.manufacturer : manufacturer // ignore: cast_nullable_to_non_nullable
as String?,stock: null == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int,reorderLevel: freezed == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int?,maxStock: freezed == maxStock ? _self.maxStock : maxStock // ignore: cast_nullable_to_non_nullable
as int?,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String?,variants: freezed == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,synced: freezed == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool?,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as int?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,isDeleted: freezed == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProductImageCopyWith<$Res>? get mainImage {
    if (_self.mainImage == null) {
    return null;
  }

  return $ProductImageCopyWith<$Res>(_self.mainImage!, (value) {
    return _then(_self.copyWith(mainImage: value));
  });
}
}


/// Adds pattern-matching-related methods to [Product].
extension ProductPatterns on Product {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Product value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Product value)  $default,){
final _that = this;
switch (_that) {
case _Product():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Product value)?  $default,){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String tenantId,  String businessType,  String name,  String? description,  String? category,  String? brand,  ProductImage? mainImage,  List<ProductImage>? images,  double price,  double? mrp,  double? cost,  double gstRate,  String? hsn,  String? barcode,  String? sku,  String? batchNo,  int? expiryDate,  String? drugSchedule,  String? strength,  String? formulation,  String? manufacturer,  int stock,  int? reorderLevel,  int? maxStock,  String? unit,  List<ProductVariant>? variants,  bool isActive,  int createdAt,  int updatedAt,  String createdBy,  String updatedBy,  bool? synced,  int? lastSyncedAt,  int? version,  bool? isDeleted,  int? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.tenantId,_that.businessType,_that.name,_that.description,_that.category,_that.brand,_that.mainImage,_that.images,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.batchNo,_that.expiryDate,_that.drugSchedule,_that.strength,_that.formulation,_that.manufacturer,_that.stock,_that.reorderLevel,_that.maxStock,_that.unit,_that.variants,_that.isActive,_that.createdAt,_that.updatedAt,_that.createdBy,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.version,_that.isDeleted,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String tenantId,  String businessType,  String name,  String? description,  String? category,  String? brand,  ProductImage? mainImage,  List<ProductImage>? images,  double price,  double? mrp,  double? cost,  double gstRate,  String? hsn,  String? barcode,  String? sku,  String? batchNo,  int? expiryDate,  String? drugSchedule,  String? strength,  String? formulation,  String? manufacturer,  int stock,  int? reorderLevel,  int? maxStock,  String? unit,  List<ProductVariant>? variants,  bool isActive,  int createdAt,  int updatedAt,  String createdBy,  String updatedBy,  bool? synced,  int? lastSyncedAt,  int? version,  bool? isDeleted,  int? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _Product():
return $default(_that.id,_that.tenantId,_that.businessType,_that.name,_that.description,_that.category,_that.brand,_that.mainImage,_that.images,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.batchNo,_that.expiryDate,_that.drugSchedule,_that.strength,_that.formulation,_that.manufacturer,_that.stock,_that.reorderLevel,_that.maxStock,_that.unit,_that.variants,_that.isActive,_that.createdAt,_that.updatedAt,_that.createdBy,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.version,_that.isDeleted,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String tenantId,  String businessType,  String name,  String? description,  String? category,  String? brand,  ProductImage? mainImage,  List<ProductImage>? images,  double price,  double? mrp,  double? cost,  double gstRate,  String? hsn,  String? barcode,  String? sku,  String? batchNo,  int? expiryDate,  String? drugSchedule,  String? strength,  String? formulation,  String? manufacturer,  int stock,  int? reorderLevel,  int? maxStock,  String? unit,  List<ProductVariant>? variants,  bool isActive,  int createdAt,  int updatedAt,  String createdBy,  String updatedBy,  bool? synced,  int? lastSyncedAt,  int? version,  bool? isDeleted,  int? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.tenantId,_that.businessType,_that.name,_that.description,_that.category,_that.brand,_that.mainImage,_that.images,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.batchNo,_that.expiryDate,_that.drugSchedule,_that.strength,_that.formulation,_that.manufacturer,_that.stock,_that.reorderLevel,_that.maxStock,_that.unit,_that.variants,_that.isActive,_that.createdAt,_that.updatedAt,_that.createdBy,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.version,_that.isDeleted,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Product implements Product {
  const _Product({required this.id, required this.tenantId, required this.businessType, required this.name, this.description, this.category, this.brand, this.mainImage, final  List<ProductImage>? images, required this.price, this.mrp, this.cost, this.gstRate = 0, this.hsn, this.barcode, this.sku, this.batchNo, this.expiryDate, this.drugSchedule, this.strength, this.formulation, this.manufacturer, this.stock = 0, this.reorderLevel, this.maxStock, this.unit, final  List<ProductVariant>? variants, this.isActive = true, required this.createdAt, required this.updatedAt, required this.createdBy, required this.updatedBy, this.synced, this.lastSyncedAt, this.version, this.isDeleted, this.deletedAt}): _images = images,_variants = variants;
  factory _Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

// Core identifiers
@override final  String id;
@override final  String tenantId;
@override final  String businessType;
// Product metadata
@override final  String name;
@override final  String? description;
@override final  String? category;
@override final  String? brand;
// Image data
@override final  ProductImage? mainImage;
 final  List<ProductImage>? _images;
@override List<ProductImage>? get images {
  final value = _images;
  if (value == null) return null;
  if (_images is EqualUnmodifiableListView) return _images;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Product specifications
@override final  double price;
@override final  double? mrp;
@override final  double? cost;
@override@JsonKey() final  double gstRate;
@override final  String? hsn;
// Barcode / identifiers
@override final  String? barcode;
@override final  String? sku;
// Pharmacy-specific fields
@override final  String? batchNo;
@override final  int? expiryDate;
@override final  String? drugSchedule;
@override final  String? strength;
@override final  String? formulation;
@override final  String? manufacturer;
// Stock & variants
@override@JsonKey() final  int stock;
@override final  int? reorderLevel;
@override final  int? maxStock;
@override final  String? unit;
 final  List<ProductVariant>? _variants;
@override List<ProductVariant>? get variants {
  final value = _variants;
  if (value == null) return null;
  if (_variants is EqualUnmodifiableListView) return _variants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Metadata
@override@JsonKey() final  bool isActive;
@override final  int createdAt;
@override final  int updatedAt;
@override final  String createdBy;
@override final  String updatedBy;
// Sync tracking
@override final  bool? synced;
@override final  int? lastSyncedAt;
@override final  int? version;
// Soft delete
@override final  bool? isDeleted;
@override final  int? deletedAt;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCopyWith<_Product> get copyWith => __$ProductCopyWithImpl<_Product>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Product&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.businessType, businessType) || other.businessType == businessType)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.mainImage, mainImage) || other.mainImage == mainImage)&&const DeepCollectionEquality().equals(other._images, _images)&&(identical(other.price, price) || other.price == price)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.gstRate, gstRate) || other.gstRate == gstRate)&&(identical(other.hsn, hsn) || other.hsn == hsn)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.batchNo, batchNo) || other.batchNo == batchNo)&&(identical(other.expiryDate, expiryDate) || other.expiryDate == expiryDate)&&(identical(other.drugSchedule, drugSchedule) || other.drugSchedule == drugSchedule)&&(identical(other.strength, strength) || other.strength == strength)&&(identical(other.formulation, formulation) || other.formulation == formulation)&&(identical(other.manufacturer, manufacturer) || other.manufacturer == manufacturer)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.maxStock, maxStock) || other.maxStock == maxStock)&&(identical(other.unit, unit) || other.unit == unit)&&const DeepCollectionEquality().equals(other._variants, _variants)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.version, version) || other.version == version)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,businessType,name,description,category,brand,mainImage,const DeepCollectionEquality().hash(_images),price,mrp,cost,gstRate,hsn,barcode,sku,batchNo,expiryDate,drugSchedule,strength,formulation,manufacturer,stock,reorderLevel,maxStock,unit,const DeepCollectionEquality().hash(_variants),isActive,createdAt,updatedAt,createdBy,updatedBy,synced,lastSyncedAt,version,isDeleted,deletedAt]);

@override
String toString() {
  return 'Product(id: $id, tenantId: $tenantId, businessType: $businessType, name: $name, description: $description, category: $category, brand: $brand, mainImage: $mainImage, images: $images, price: $price, mrp: $mrp, cost: $cost, gstRate: $gstRate, hsn: $hsn, barcode: $barcode, sku: $sku, batchNo: $batchNo, expiryDate: $expiryDate, drugSchedule: $drugSchedule, strength: $strength, formulation: $formulation, manufacturer: $manufacturer, stock: $stock, reorderLevel: $reorderLevel, maxStock: $maxStock, unit: $unit, variants: $variants, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, version: $version, isDeleted: $isDeleted, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$ProductCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$ProductCopyWith(_Product value, $Res Function(_Product) _then) = __$ProductCopyWithImpl;
@override @useResult
$Res call({
 String id, String tenantId, String businessType, String name, String? description, String? category, String? brand, ProductImage? mainImage, List<ProductImage>? images, double price, double? mrp, double? cost, double gstRate, String? hsn, String? barcode, String? sku, String? batchNo, int? expiryDate, String? drugSchedule, String? strength, String? formulation, String? manufacturer, int stock, int? reorderLevel, int? maxStock, String? unit, List<ProductVariant>? variants, bool isActive, int createdAt, int updatedAt, String createdBy, String updatedBy, bool? synced, int? lastSyncedAt, int? version, bool? isDeleted, int? deletedAt
});


@override $ProductImageCopyWith<$Res>? get mainImage;

}
/// @nodoc
class __$ProductCopyWithImpl<$Res>
    implements _$ProductCopyWith<$Res> {
  __$ProductCopyWithImpl(this._self, this._then);

  final _Product _self;
  final $Res Function(_Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? businessType = null,Object? name = null,Object? description = freezed,Object? category = freezed,Object? brand = freezed,Object? mainImage = freezed,Object? images = freezed,Object? price = null,Object? mrp = freezed,Object? cost = freezed,Object? gstRate = null,Object? hsn = freezed,Object? barcode = freezed,Object? sku = freezed,Object? batchNo = freezed,Object? expiryDate = freezed,Object? drugSchedule = freezed,Object? strength = freezed,Object? formulation = freezed,Object? manufacturer = freezed,Object? stock = null,Object? reorderLevel = freezed,Object? maxStock = freezed,Object? unit = freezed,Object? variants = freezed,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,Object? createdBy = null,Object? updatedBy = null,Object? synced = freezed,Object? lastSyncedAt = freezed,Object? version = freezed,Object? isDeleted = freezed,Object? deletedAt = freezed,}) {
  return _then(_Product(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,businessType: null == businessType ? _self.businessType : businessType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,mainImage: freezed == mainImage ? _self.mainImage : mainImage // ignore: cast_nullable_to_non_nullable
as ProductImage?,images: freezed == images ? _self._images : images // ignore: cast_nullable_to_non_nullable
as List<ProductImage>?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,mrp: freezed == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,gstRate: null == gstRate ? _self.gstRate : gstRate // ignore: cast_nullable_to_non_nullable
as double,hsn: freezed == hsn ? _self.hsn : hsn // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,batchNo: freezed == batchNo ? _self.batchNo : batchNo // ignore: cast_nullable_to_non_nullable
as String?,expiryDate: freezed == expiryDate ? _self.expiryDate : expiryDate // ignore: cast_nullable_to_non_nullable
as int?,drugSchedule: freezed == drugSchedule ? _self.drugSchedule : drugSchedule // ignore: cast_nullable_to_non_nullable
as String?,strength: freezed == strength ? _self.strength : strength // ignore: cast_nullable_to_non_nullable
as String?,formulation: freezed == formulation ? _self.formulation : formulation // ignore: cast_nullable_to_non_nullable
as String?,manufacturer: freezed == manufacturer ? _self.manufacturer : manufacturer // ignore: cast_nullable_to_non_nullable
as String?,stock: null == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int,reorderLevel: freezed == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int?,maxStock: freezed == maxStock ? _self.maxStock : maxStock // ignore: cast_nullable_to_non_nullable
as int?,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String?,variants: freezed == variants ? _self._variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,synced: freezed == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool?,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as int?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,isDeleted: freezed == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProductImageCopyWith<$Res>? get mainImage {
    if (_self.mainImage == null) {
    return null;
  }

  return $ProductImageCopyWith<$Res>(_self.mainImage!, (value) {
    return _then(_self.copyWith(mainImage: value));
  });
}
}


/// @nodoc
mixin _$ProductListResponse {

 List<Product> get items; int get total; int get page; int get limit; String? get nextToken;
/// Create a copy of ProductListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductListResponseCopyWith<ProductListResponse> get copyWith => _$ProductListResponseCopyWithImpl<ProductListResponse>(this as ProductListResponse, _$identity);

  /// Serializes this ProductListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductListResponse&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.nextToken, nextToken) || other.nextToken == nextToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,limit,nextToken);

@override
String toString() {
  return 'ProductListResponse(items: $items, total: $total, page: $page, limit: $limit, nextToken: $nextToken)';
}


}

/// @nodoc
abstract mixin class $ProductListResponseCopyWith<$Res>  {
  factory $ProductListResponseCopyWith(ProductListResponse value, $Res Function(ProductListResponse) _then) = _$ProductListResponseCopyWithImpl;
@useResult
$Res call({
 List<Product> items, int total, int page, int limit, String? nextToken
});




}
/// @nodoc
class _$ProductListResponseCopyWithImpl<$Res>
    implements $ProductListResponseCopyWith<$Res> {
  _$ProductListResponseCopyWithImpl(this._self, this._then);

  final ProductListResponse _self;
  final $Res Function(ProductListResponse) _then;

/// Create a copy of ProductListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? limit = null,Object? nextToken = freezed,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Product>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,nextToken: freezed == nextToken ? _self.nextToken : nextToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductListResponse].
extension ProductListResponsePatterns on ProductListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductListResponse value)  $default,){
final _that = this;
switch (_that) {
case _ProductListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ProductListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Product> items,  int total,  int page,  int limit,  String? nextToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductListResponse() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.limit,_that.nextToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Product> items,  int total,  int page,  int limit,  String? nextToken)  $default,) {final _that = this;
switch (_that) {
case _ProductListResponse():
return $default(_that.items,_that.total,_that.page,_that.limit,_that.nextToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Product> items,  int total,  int page,  int limit,  String? nextToken)?  $default,) {final _that = this;
switch (_that) {
case _ProductListResponse() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.limit,_that.nextToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductListResponse implements ProductListResponse {
  const _ProductListResponse({required final  List<Product> items, required this.total, required this.page, required this.limit, this.nextToken}): _items = items;
  factory _ProductListResponse.fromJson(Map<String, dynamic> json) => _$ProductListResponseFromJson(json);

 final  List<Product> _items;
@override List<Product> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int total;
@override final  int page;
@override final  int limit;
@override final  String? nextToken;

/// Create a copy of ProductListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductListResponseCopyWith<_ProductListResponse> get copyWith => __$ProductListResponseCopyWithImpl<_ProductListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductListResponse&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.nextToken, nextToken) || other.nextToken == nextToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,limit,nextToken);

@override
String toString() {
  return 'ProductListResponse(items: $items, total: $total, page: $page, limit: $limit, nextToken: $nextToken)';
}


}

/// @nodoc
abstract mixin class _$ProductListResponseCopyWith<$Res> implements $ProductListResponseCopyWith<$Res> {
  factory _$ProductListResponseCopyWith(_ProductListResponse value, $Res Function(_ProductListResponse) _then) = __$ProductListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<Product> items, int total, int page, int limit, String? nextToken
});




}
/// @nodoc
class __$ProductListResponseCopyWithImpl<$Res>
    implements _$ProductListResponseCopyWith<$Res> {
  __$ProductListResponseCopyWithImpl(this._self, this._then);

  final _ProductListResponse _self;
  final $Res Function(_ProductListResponse) _then;

/// Create a copy of ProductListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? limit = null,Object? nextToken = freezed,}) {
  return _then(_ProductListResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Product>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,nextToken: freezed == nextToken ? _self.nextToken : nextToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProductFilters {

 String? get category; String? get brand; double? get minPrice; double? get maxPrice; bool? get inStock; String? get searchTerm; String? get barcode; bool? get lowStock; bool? get expiringSoon;
/// Create a copy of ProductFilters
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductFiltersCopyWith<ProductFilters> get copyWith => _$ProductFiltersCopyWithImpl<ProductFilters>(this as ProductFilters, _$identity);

  /// Serializes this ProductFilters to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductFilters&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.minPrice, minPrice) || other.minPrice == minPrice)&&(identical(other.maxPrice, maxPrice) || other.maxPrice == maxPrice)&&(identical(other.inStock, inStock) || other.inStock == inStock)&&(identical(other.searchTerm, searchTerm) || other.searchTerm == searchTerm)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.lowStock, lowStock) || other.lowStock == lowStock)&&(identical(other.expiringSoon, expiringSoon) || other.expiringSoon == expiringSoon));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,category,brand,minPrice,maxPrice,inStock,searchTerm,barcode,lowStock,expiringSoon);

@override
String toString() {
  return 'ProductFilters(category: $category, brand: $brand, minPrice: $minPrice, maxPrice: $maxPrice, inStock: $inStock, searchTerm: $searchTerm, barcode: $barcode, lowStock: $lowStock, expiringSoon: $expiringSoon)';
}


}

/// @nodoc
abstract mixin class $ProductFiltersCopyWith<$Res>  {
  factory $ProductFiltersCopyWith(ProductFilters value, $Res Function(ProductFilters) _then) = _$ProductFiltersCopyWithImpl;
@useResult
$Res call({
 String? category, String? brand, double? minPrice, double? maxPrice, bool? inStock, String? searchTerm, String? barcode, bool? lowStock, bool? expiringSoon
});




}
/// @nodoc
class _$ProductFiltersCopyWithImpl<$Res>
    implements $ProductFiltersCopyWith<$Res> {
  _$ProductFiltersCopyWithImpl(this._self, this._then);

  final ProductFilters _self;
  final $Res Function(ProductFilters) _then;

/// Create a copy of ProductFilters
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? category = freezed,Object? brand = freezed,Object? minPrice = freezed,Object? maxPrice = freezed,Object? inStock = freezed,Object? searchTerm = freezed,Object? barcode = freezed,Object? lowStock = freezed,Object? expiringSoon = freezed,}) {
  return _then(_self.copyWith(
category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,minPrice: freezed == minPrice ? _self.minPrice : minPrice // ignore: cast_nullable_to_non_nullable
as double?,maxPrice: freezed == maxPrice ? _self.maxPrice : maxPrice // ignore: cast_nullable_to_non_nullable
as double?,inStock: freezed == inStock ? _self.inStock : inStock // ignore: cast_nullable_to_non_nullable
as bool?,searchTerm: freezed == searchTerm ? _self.searchTerm : searchTerm // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,lowStock: freezed == lowStock ? _self.lowStock : lowStock // ignore: cast_nullable_to_non_nullable
as bool?,expiringSoon: freezed == expiringSoon ? _self.expiringSoon : expiringSoon // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductFilters].
extension ProductFiltersPatterns on ProductFilters {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductFilters value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductFilters() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductFilters value)  $default,){
final _that = this;
switch (_that) {
case _ProductFilters():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductFilters value)?  $default,){
final _that = this;
switch (_that) {
case _ProductFilters() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? category,  String? brand,  double? minPrice,  double? maxPrice,  bool? inStock,  String? searchTerm,  String? barcode,  bool? lowStock,  bool? expiringSoon)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductFilters() when $default != null:
return $default(_that.category,_that.brand,_that.minPrice,_that.maxPrice,_that.inStock,_that.searchTerm,_that.barcode,_that.lowStock,_that.expiringSoon);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? category,  String? brand,  double? minPrice,  double? maxPrice,  bool? inStock,  String? searchTerm,  String? barcode,  bool? lowStock,  bool? expiringSoon)  $default,) {final _that = this;
switch (_that) {
case _ProductFilters():
return $default(_that.category,_that.brand,_that.minPrice,_that.maxPrice,_that.inStock,_that.searchTerm,_that.barcode,_that.lowStock,_that.expiringSoon);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? category,  String? brand,  double? minPrice,  double? maxPrice,  bool? inStock,  String? searchTerm,  String? barcode,  bool? lowStock,  bool? expiringSoon)?  $default,) {final _that = this;
switch (_that) {
case _ProductFilters() when $default != null:
return $default(_that.category,_that.brand,_that.minPrice,_that.maxPrice,_that.inStock,_that.searchTerm,_that.barcode,_that.lowStock,_that.expiringSoon);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductFilters implements ProductFilters {
  const _ProductFilters({this.category, this.brand, this.minPrice, this.maxPrice, this.inStock, this.searchTerm, this.barcode, this.lowStock, this.expiringSoon});
  factory _ProductFilters.fromJson(Map<String, dynamic> json) => _$ProductFiltersFromJson(json);

@override final  String? category;
@override final  String? brand;
@override final  double? minPrice;
@override final  double? maxPrice;
@override final  bool? inStock;
@override final  String? searchTerm;
@override final  String? barcode;
@override final  bool? lowStock;
@override final  bool? expiringSoon;

/// Create a copy of ProductFilters
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductFiltersCopyWith<_ProductFilters> get copyWith => __$ProductFiltersCopyWithImpl<_ProductFilters>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductFiltersToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductFilters&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.minPrice, minPrice) || other.minPrice == minPrice)&&(identical(other.maxPrice, maxPrice) || other.maxPrice == maxPrice)&&(identical(other.inStock, inStock) || other.inStock == inStock)&&(identical(other.searchTerm, searchTerm) || other.searchTerm == searchTerm)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.lowStock, lowStock) || other.lowStock == lowStock)&&(identical(other.expiringSoon, expiringSoon) || other.expiringSoon == expiringSoon));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,category,brand,minPrice,maxPrice,inStock,searchTerm,barcode,lowStock,expiringSoon);

@override
String toString() {
  return 'ProductFilters(category: $category, brand: $brand, minPrice: $minPrice, maxPrice: $maxPrice, inStock: $inStock, searchTerm: $searchTerm, barcode: $barcode, lowStock: $lowStock, expiringSoon: $expiringSoon)';
}


}

/// @nodoc
abstract mixin class _$ProductFiltersCopyWith<$Res> implements $ProductFiltersCopyWith<$Res> {
  factory _$ProductFiltersCopyWith(_ProductFilters value, $Res Function(_ProductFilters) _then) = __$ProductFiltersCopyWithImpl;
@override @useResult
$Res call({
 String? category, String? brand, double? minPrice, double? maxPrice, bool? inStock, String? searchTerm, String? barcode, bool? lowStock, bool? expiringSoon
});




}
/// @nodoc
class __$ProductFiltersCopyWithImpl<$Res>
    implements _$ProductFiltersCopyWith<$Res> {
  __$ProductFiltersCopyWithImpl(this._self, this._then);

  final _ProductFilters _self;
  final $Res Function(_ProductFilters) _then;

/// Create a copy of ProductFilters
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? category = freezed,Object? brand = freezed,Object? minPrice = freezed,Object? maxPrice = freezed,Object? inStock = freezed,Object? searchTerm = freezed,Object? barcode = freezed,Object? lowStock = freezed,Object? expiringSoon = freezed,}) {
  return _then(_ProductFilters(
category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,minPrice: freezed == minPrice ? _self.minPrice : minPrice // ignore: cast_nullable_to_non_nullable
as double?,maxPrice: freezed == maxPrice ? _self.maxPrice : maxPrice // ignore: cast_nullable_to_non_nullable
as double?,inStock: freezed == inStock ? _self.inStock : inStock // ignore: cast_nullable_to_non_nullable
as bool?,searchTerm: freezed == searchTerm ? _self.searchTerm : searchTerm // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,lowStock: freezed == lowStock ? _self.lowStock : lowStock // ignore: cast_nullable_to_non_nullable
as bool?,expiringSoon: freezed == expiringSoon ? _self.expiringSoon : expiringSoon // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$CreateProductRequest {

 String get name; String? get description; String? get category; String? get brand; double get price; double? get mrp; double? get cost; double? get gstRate; String? get hsn; String? get barcode; String? get sku; int? get stock; int? get reorderLevel; String? get unit; List<ProductVariant>? get variants;
/// Create a copy of CreateProductRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateProductRequestCopyWith<CreateProductRequest> get copyWith => _$CreateProductRequestCopyWithImpl<CreateProductRequest>(this as CreateProductRequest, _$identity);

  /// Serializes this CreateProductRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateProductRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.price, price) || other.price == price)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.gstRate, gstRate) || other.gstRate == gstRate)&&(identical(other.hsn, hsn) || other.hsn == hsn)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.unit, unit) || other.unit == unit)&&const DeepCollectionEquality().equals(other.variants, variants));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,category,brand,price,mrp,cost,gstRate,hsn,barcode,sku,stock,reorderLevel,unit,const DeepCollectionEquality().hash(variants));

@override
String toString() {
  return 'CreateProductRequest(name: $name, description: $description, category: $category, brand: $brand, price: $price, mrp: $mrp, cost: $cost, gstRate: $gstRate, hsn: $hsn, barcode: $barcode, sku: $sku, stock: $stock, reorderLevel: $reorderLevel, unit: $unit, variants: $variants)';
}


}

/// @nodoc
abstract mixin class $CreateProductRequestCopyWith<$Res>  {
  factory $CreateProductRequestCopyWith(CreateProductRequest value, $Res Function(CreateProductRequest) _then) = _$CreateProductRequestCopyWithImpl;
@useResult
$Res call({
 String name, String? description, String? category, String? brand, double price, double? mrp, double? cost, double? gstRate, String? hsn, String? barcode, String? sku, int? stock, int? reorderLevel, String? unit, List<ProductVariant>? variants
});




}
/// @nodoc
class _$CreateProductRequestCopyWithImpl<$Res>
    implements $CreateProductRequestCopyWith<$Res> {
  _$CreateProductRequestCopyWithImpl(this._self, this._then);

  final CreateProductRequest _self;
  final $Res Function(CreateProductRequest) _then;

/// Create a copy of CreateProductRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? category = freezed,Object? brand = freezed,Object? price = null,Object? mrp = freezed,Object? cost = freezed,Object? gstRate = freezed,Object? hsn = freezed,Object? barcode = freezed,Object? sku = freezed,Object? stock = freezed,Object? reorderLevel = freezed,Object? unit = freezed,Object? variants = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,mrp: freezed == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,gstRate: freezed == gstRate ? _self.gstRate : gstRate // ignore: cast_nullable_to_non_nullable
as double?,hsn: freezed == hsn ? _self.hsn : hsn // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,stock: freezed == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int?,reorderLevel: freezed == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int?,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String?,variants: freezed == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>?,
  ));
}

}


/// Adds pattern-matching-related methods to [CreateProductRequest].
extension CreateProductRequestPatterns on CreateProductRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreateProductRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreateProductRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreateProductRequest value)  $default,){
final _that = this;
switch (_that) {
case _CreateProductRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreateProductRequest value)?  $default,){
final _that = this;
switch (_that) {
case _CreateProductRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? description,  String? category,  String? brand,  double price,  double? mrp,  double? cost,  double? gstRate,  String? hsn,  String? barcode,  String? sku,  int? stock,  int? reorderLevel,  String? unit,  List<ProductVariant>? variants)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreateProductRequest() when $default != null:
return $default(_that.name,_that.description,_that.category,_that.brand,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.stock,_that.reorderLevel,_that.unit,_that.variants);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? description,  String? category,  String? brand,  double price,  double? mrp,  double? cost,  double? gstRate,  String? hsn,  String? barcode,  String? sku,  int? stock,  int? reorderLevel,  String? unit,  List<ProductVariant>? variants)  $default,) {final _that = this;
switch (_that) {
case _CreateProductRequest():
return $default(_that.name,_that.description,_that.category,_that.brand,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.stock,_that.reorderLevel,_that.unit,_that.variants);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? description,  String? category,  String? brand,  double price,  double? mrp,  double? cost,  double? gstRate,  String? hsn,  String? barcode,  String? sku,  int? stock,  int? reorderLevel,  String? unit,  List<ProductVariant>? variants)?  $default,) {final _that = this;
switch (_that) {
case _CreateProductRequest() when $default != null:
return $default(_that.name,_that.description,_that.category,_that.brand,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.stock,_that.reorderLevel,_that.unit,_that.variants);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CreateProductRequest implements CreateProductRequest {
  const _CreateProductRequest({required this.name, this.description, this.category, this.brand, required this.price, this.mrp, this.cost, this.gstRate, this.hsn, this.barcode, this.sku, this.stock, this.reorderLevel, this.unit, final  List<ProductVariant>? variants}): _variants = variants;
  factory _CreateProductRequest.fromJson(Map<String, dynamic> json) => _$CreateProductRequestFromJson(json);

@override final  String name;
@override final  String? description;
@override final  String? category;
@override final  String? brand;
@override final  double price;
@override final  double? mrp;
@override final  double? cost;
@override final  double? gstRate;
@override final  String? hsn;
@override final  String? barcode;
@override final  String? sku;
@override final  int? stock;
@override final  int? reorderLevel;
@override final  String? unit;
 final  List<ProductVariant>? _variants;
@override List<ProductVariant>? get variants {
  final value = _variants;
  if (value == null) return null;
  if (_variants is EqualUnmodifiableListView) return _variants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of CreateProductRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateProductRequestCopyWith<_CreateProductRequest> get copyWith => __$CreateProductRequestCopyWithImpl<_CreateProductRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateProductRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateProductRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.price, price) || other.price == price)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.gstRate, gstRate) || other.gstRate == gstRate)&&(identical(other.hsn, hsn) || other.hsn == hsn)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.unit, unit) || other.unit == unit)&&const DeepCollectionEquality().equals(other._variants, _variants));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,category,brand,price,mrp,cost,gstRate,hsn,barcode,sku,stock,reorderLevel,unit,const DeepCollectionEquality().hash(_variants));

@override
String toString() {
  return 'CreateProductRequest(name: $name, description: $description, category: $category, brand: $brand, price: $price, mrp: $mrp, cost: $cost, gstRate: $gstRate, hsn: $hsn, barcode: $barcode, sku: $sku, stock: $stock, reorderLevel: $reorderLevel, unit: $unit, variants: $variants)';
}


}

/// @nodoc
abstract mixin class _$CreateProductRequestCopyWith<$Res> implements $CreateProductRequestCopyWith<$Res> {
  factory _$CreateProductRequestCopyWith(_CreateProductRequest value, $Res Function(_CreateProductRequest) _then) = __$CreateProductRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, String? category, String? brand, double price, double? mrp, double? cost, double? gstRate, String? hsn, String? barcode, String? sku, int? stock, int? reorderLevel, String? unit, List<ProductVariant>? variants
});




}
/// @nodoc
class __$CreateProductRequestCopyWithImpl<$Res>
    implements _$CreateProductRequestCopyWith<$Res> {
  __$CreateProductRequestCopyWithImpl(this._self, this._then);

  final _CreateProductRequest _self;
  final $Res Function(_CreateProductRequest) _then;

/// Create a copy of CreateProductRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? category = freezed,Object? brand = freezed,Object? price = null,Object? mrp = freezed,Object? cost = freezed,Object? gstRate = freezed,Object? hsn = freezed,Object? barcode = freezed,Object? sku = freezed,Object? stock = freezed,Object? reorderLevel = freezed,Object? unit = freezed,Object? variants = freezed,}) {
  return _then(_CreateProductRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,mrp: freezed == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,gstRate: freezed == gstRate ? _self.gstRate : gstRate // ignore: cast_nullable_to_non_nullable
as double?,hsn: freezed == hsn ? _self.hsn : hsn // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,stock: freezed == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int?,reorderLevel: freezed == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int?,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String?,variants: freezed == variants ? _self._variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>?,
  ));
}


}


/// @nodoc
mixin _$UpdateProductRequest {

 String? get name; String? get description; String? get category; String? get brand; double? get price; double? get mrp; double? get cost; double? get gstRate; String? get hsn; String? get barcode; String? get sku; int? get stock; int? get reorderLevel; String? get unit; bool? get isActive; List<ProductVariant>? get variants;
/// Create a copy of UpdateProductRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateProductRequestCopyWith<UpdateProductRequest> get copyWith => _$UpdateProductRequestCopyWithImpl<UpdateProductRequest>(this as UpdateProductRequest, _$identity);

  /// Serializes this UpdateProductRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateProductRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.price, price) || other.price == price)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.gstRate, gstRate) || other.gstRate == gstRate)&&(identical(other.hsn, hsn) || other.hsn == hsn)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&const DeepCollectionEquality().equals(other.variants, variants));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,category,brand,price,mrp,cost,gstRate,hsn,barcode,sku,stock,reorderLevel,unit,isActive,const DeepCollectionEquality().hash(variants));

@override
String toString() {
  return 'UpdateProductRequest(name: $name, description: $description, category: $category, brand: $brand, price: $price, mrp: $mrp, cost: $cost, gstRate: $gstRate, hsn: $hsn, barcode: $barcode, sku: $sku, stock: $stock, reorderLevel: $reorderLevel, unit: $unit, isActive: $isActive, variants: $variants)';
}


}

/// @nodoc
abstract mixin class $UpdateProductRequestCopyWith<$Res>  {
  factory $UpdateProductRequestCopyWith(UpdateProductRequest value, $Res Function(UpdateProductRequest) _then) = _$UpdateProductRequestCopyWithImpl;
@useResult
$Res call({
 String? name, String? description, String? category, String? brand, double? price, double? mrp, double? cost, double? gstRate, String? hsn, String? barcode, String? sku, int? stock, int? reorderLevel, String? unit, bool? isActive, List<ProductVariant>? variants
});




}
/// @nodoc
class _$UpdateProductRequestCopyWithImpl<$Res>
    implements $UpdateProductRequestCopyWith<$Res> {
  _$UpdateProductRequestCopyWithImpl(this._self, this._then);

  final UpdateProductRequest _self;
  final $Res Function(UpdateProductRequest) _then;

/// Create a copy of UpdateProductRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? description = freezed,Object? category = freezed,Object? brand = freezed,Object? price = freezed,Object? mrp = freezed,Object? cost = freezed,Object? gstRate = freezed,Object? hsn = freezed,Object? barcode = freezed,Object? sku = freezed,Object? stock = freezed,Object? reorderLevel = freezed,Object? unit = freezed,Object? isActive = freezed,Object? variants = freezed,}) {
  return _then(_self.copyWith(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double?,mrp: freezed == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,gstRate: freezed == gstRate ? _self.gstRate : gstRate // ignore: cast_nullable_to_non_nullable
as double?,hsn: freezed == hsn ? _self.hsn : hsn // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,stock: freezed == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int?,reorderLevel: freezed == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int?,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,variants: freezed == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>?,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateProductRequest].
extension UpdateProductRequestPatterns on UpdateProductRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateProductRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateProductRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateProductRequest value)  $default,){
final _that = this;
switch (_that) {
case _UpdateProductRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateProductRequest value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateProductRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name,  String? description,  String? category,  String? brand,  double? price,  double? mrp,  double? cost,  double? gstRate,  String? hsn,  String? barcode,  String? sku,  int? stock,  int? reorderLevel,  String? unit,  bool? isActive,  List<ProductVariant>? variants)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateProductRequest() when $default != null:
return $default(_that.name,_that.description,_that.category,_that.brand,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.stock,_that.reorderLevel,_that.unit,_that.isActive,_that.variants);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name,  String? description,  String? category,  String? brand,  double? price,  double? mrp,  double? cost,  double? gstRate,  String? hsn,  String? barcode,  String? sku,  int? stock,  int? reorderLevel,  String? unit,  bool? isActive,  List<ProductVariant>? variants)  $default,) {final _that = this;
switch (_that) {
case _UpdateProductRequest():
return $default(_that.name,_that.description,_that.category,_that.brand,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.stock,_that.reorderLevel,_that.unit,_that.isActive,_that.variants);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name,  String? description,  String? category,  String? brand,  double? price,  double? mrp,  double? cost,  double? gstRate,  String? hsn,  String? barcode,  String? sku,  int? stock,  int? reorderLevel,  String? unit,  bool? isActive,  List<ProductVariant>? variants)?  $default,) {final _that = this;
switch (_that) {
case _UpdateProductRequest() when $default != null:
return $default(_that.name,_that.description,_that.category,_that.brand,_that.price,_that.mrp,_that.cost,_that.gstRate,_that.hsn,_that.barcode,_that.sku,_that.stock,_that.reorderLevel,_that.unit,_that.isActive,_that.variants);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UpdateProductRequest implements UpdateProductRequest {
  const _UpdateProductRequest({this.name, this.description, this.category, this.brand, this.price, this.mrp, this.cost, this.gstRate, this.hsn, this.barcode, this.sku, this.stock, this.reorderLevel, this.unit, this.isActive, final  List<ProductVariant>? variants}): _variants = variants;
  factory _UpdateProductRequest.fromJson(Map<String, dynamic> json) => _$UpdateProductRequestFromJson(json);

@override final  String? name;
@override final  String? description;
@override final  String? category;
@override final  String? brand;
@override final  double? price;
@override final  double? mrp;
@override final  double? cost;
@override final  double? gstRate;
@override final  String? hsn;
@override final  String? barcode;
@override final  String? sku;
@override final  int? stock;
@override final  int? reorderLevel;
@override final  String? unit;
@override final  bool? isActive;
 final  List<ProductVariant>? _variants;
@override List<ProductVariant>? get variants {
  final value = _variants;
  if (value == null) return null;
  if (_variants is EqualUnmodifiableListView) return _variants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of UpdateProductRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateProductRequestCopyWith<_UpdateProductRequest> get copyWith => __$UpdateProductRequestCopyWithImpl<_UpdateProductRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateProductRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateProductRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.price, price) || other.price == price)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.gstRate, gstRate) || other.gstRate == gstRate)&&(identical(other.hsn, hsn) || other.hsn == hsn)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.reorderLevel, reorderLevel) || other.reorderLevel == reorderLevel)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&const DeepCollectionEquality().equals(other._variants, _variants));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,category,brand,price,mrp,cost,gstRate,hsn,barcode,sku,stock,reorderLevel,unit,isActive,const DeepCollectionEquality().hash(_variants));

@override
String toString() {
  return 'UpdateProductRequest(name: $name, description: $description, category: $category, brand: $brand, price: $price, mrp: $mrp, cost: $cost, gstRate: $gstRate, hsn: $hsn, barcode: $barcode, sku: $sku, stock: $stock, reorderLevel: $reorderLevel, unit: $unit, isActive: $isActive, variants: $variants)';
}


}

/// @nodoc
abstract mixin class _$UpdateProductRequestCopyWith<$Res> implements $UpdateProductRequestCopyWith<$Res> {
  factory _$UpdateProductRequestCopyWith(_UpdateProductRequest value, $Res Function(_UpdateProductRequest) _then) = __$UpdateProductRequestCopyWithImpl;
@override @useResult
$Res call({
 String? name, String? description, String? category, String? brand, double? price, double? mrp, double? cost, double? gstRate, String? hsn, String? barcode, String? sku, int? stock, int? reorderLevel, String? unit, bool? isActive, List<ProductVariant>? variants
});




}
/// @nodoc
class __$UpdateProductRequestCopyWithImpl<$Res>
    implements _$UpdateProductRequestCopyWith<$Res> {
  __$UpdateProductRequestCopyWithImpl(this._self, this._then);

  final _UpdateProductRequest _self;
  final $Res Function(_UpdateProductRequest) _then;

/// Create a copy of UpdateProductRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? description = freezed,Object? category = freezed,Object? brand = freezed,Object? price = freezed,Object? mrp = freezed,Object? cost = freezed,Object? gstRate = freezed,Object? hsn = freezed,Object? barcode = freezed,Object? sku = freezed,Object? stock = freezed,Object? reorderLevel = freezed,Object? unit = freezed,Object? isActive = freezed,Object? variants = freezed,}) {
  return _then(_UpdateProductRequest(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double?,mrp: freezed == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,gstRate: freezed == gstRate ? _self.gstRate : gstRate // ignore: cast_nullable_to_non_nullable
as double?,hsn: freezed == hsn ? _self.hsn : hsn // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,stock: freezed == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int?,reorderLevel: freezed == reorderLevel ? _self.reorderLevel : reorderLevel // ignore: cast_nullable_to_non_nullable
as int?,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,variants: freezed == variants ? _self._variants : variants // ignore: cast_nullable_to_non_nullable
as List<ProductVariant>?,
  ));
}


}

// dart format on
