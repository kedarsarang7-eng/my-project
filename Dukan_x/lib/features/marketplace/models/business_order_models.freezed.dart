// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'business_order_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OnlineCustomer {

 String get customerId; String get name; String get phone; String? get email; int get totalOrders; double get totalSpent; String get connectedAt;
/// Create a copy of OnlineCustomer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnlineCustomerCopyWith<OnlineCustomer> get copyWith => _$OnlineCustomerCopyWithImpl<OnlineCustomer>(this as OnlineCustomer, _$identity);

  /// Serializes this OnlineCustomer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnlineCustomer&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.totalOrders, totalOrders) || other.totalOrders == totalOrders)&&(identical(other.totalSpent, totalSpent) || other.totalSpent == totalSpent)&&(identical(other.connectedAt, connectedAt) || other.connectedAt == connectedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,customerId,name,phone,email,totalOrders,totalSpent,connectedAt);

@override
String toString() {
  return 'OnlineCustomer(customerId: $customerId, name: $name, phone: $phone, email: $email, totalOrders: $totalOrders, totalSpent: $totalSpent, connectedAt: $connectedAt)';
}


}

/// @nodoc
abstract mixin class $OnlineCustomerCopyWith<$Res>  {
  factory $OnlineCustomerCopyWith(OnlineCustomer value, $Res Function(OnlineCustomer) _then) = _$OnlineCustomerCopyWithImpl;
@useResult
$Res call({
 String customerId, String name, String phone, String? email, int totalOrders, double totalSpent, String connectedAt
});




}
/// @nodoc
class _$OnlineCustomerCopyWithImpl<$Res>
    implements $OnlineCustomerCopyWith<$Res> {
  _$OnlineCustomerCopyWithImpl(this._self, this._then);

  final OnlineCustomer _self;
  final $Res Function(OnlineCustomer) _then;

/// Create a copy of OnlineCustomer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? customerId = null,Object? name = null,Object? phone = null,Object? email = freezed,Object? totalOrders = null,Object? totalSpent = null,Object? connectedAt = null,}) {
  return _then(_self.copyWith(
customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,totalOrders: null == totalOrders ? _self.totalOrders : totalOrders // ignore: cast_nullable_to_non_nullable
as int,totalSpent: null == totalSpent ? _self.totalSpent : totalSpent // ignore: cast_nullable_to_non_nullable
as double,connectedAt: null == connectedAt ? _self.connectedAt : connectedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OnlineCustomer].
extension OnlineCustomerPatterns on OnlineCustomer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnlineCustomer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnlineCustomer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnlineCustomer value)  $default,){
final _that = this;
switch (_that) {
case _OnlineCustomer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnlineCustomer value)?  $default,){
final _that = this;
switch (_that) {
case _OnlineCustomer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String customerId,  String name,  String phone,  String? email,  int totalOrders,  double totalSpent,  String connectedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnlineCustomer() when $default != null:
return $default(_that.customerId,_that.name,_that.phone,_that.email,_that.totalOrders,_that.totalSpent,_that.connectedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String customerId,  String name,  String phone,  String? email,  int totalOrders,  double totalSpent,  String connectedAt)  $default,) {final _that = this;
switch (_that) {
case _OnlineCustomer():
return $default(_that.customerId,_that.name,_that.phone,_that.email,_that.totalOrders,_that.totalSpent,_that.connectedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String customerId,  String name,  String phone,  String? email,  int totalOrders,  double totalSpent,  String connectedAt)?  $default,) {final _that = this;
switch (_that) {
case _OnlineCustomer() when $default != null:
return $default(_that.customerId,_that.name,_that.phone,_that.email,_that.totalOrders,_that.totalSpent,_that.connectedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OnlineCustomer implements OnlineCustomer {
  const _OnlineCustomer({required this.customerId, required this.name, required this.phone, this.email, required this.totalOrders, required this.totalSpent, required this.connectedAt});
  factory _OnlineCustomer.fromJson(Map<String, dynamic> json) => _$OnlineCustomerFromJson(json);

@override final  String customerId;
@override final  String name;
@override final  String phone;
@override final  String? email;
@override final  int totalOrders;
@override final  double totalSpent;
@override final  String connectedAt;

/// Create a copy of OnlineCustomer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnlineCustomerCopyWith<_OnlineCustomer> get copyWith => __$OnlineCustomerCopyWithImpl<_OnlineCustomer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OnlineCustomerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnlineCustomer&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.totalOrders, totalOrders) || other.totalOrders == totalOrders)&&(identical(other.totalSpent, totalSpent) || other.totalSpent == totalSpent)&&(identical(other.connectedAt, connectedAt) || other.connectedAt == connectedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,customerId,name,phone,email,totalOrders,totalSpent,connectedAt);

@override
String toString() {
  return 'OnlineCustomer(customerId: $customerId, name: $name, phone: $phone, email: $email, totalOrders: $totalOrders, totalSpent: $totalSpent, connectedAt: $connectedAt)';
}


}

/// @nodoc
abstract mixin class _$OnlineCustomerCopyWith<$Res> implements $OnlineCustomerCopyWith<$Res> {
  factory _$OnlineCustomerCopyWith(_OnlineCustomer value, $Res Function(_OnlineCustomer) _then) = __$OnlineCustomerCopyWithImpl;
@override @useResult
$Res call({
 String customerId, String name, String phone, String? email, int totalOrders, double totalSpent, String connectedAt
});




}
/// @nodoc
class __$OnlineCustomerCopyWithImpl<$Res>
    implements _$OnlineCustomerCopyWith<$Res> {
  __$OnlineCustomerCopyWithImpl(this._self, this._then);

  final _OnlineCustomer _self;
  final $Res Function(_OnlineCustomer) _then;

/// Create a copy of OnlineCustomer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? customerId = null,Object? name = null,Object? phone = null,Object? email = freezed,Object? totalOrders = null,Object? totalSpent = null,Object? connectedAt = null,}) {
  return _then(_OnlineCustomer(
customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,totalOrders: null == totalOrders ? _self.totalOrders : totalOrders // ignore: cast_nullable_to_non_nullable
as int,totalSpent: null == totalSpent ? _self.totalSpent : totalSpent // ignore: cast_nullable_to_non_nullable
as double,connectedAt: null == connectedAt ? _self.connectedAt : connectedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$BusinessOrderItem {

 String get productId; String get name; String? get image; int get quantity; int? get stockQuantity; String get unit; double get mrp; double get sellingPrice; double get itemTotal; String? get prescriptionUrl; String? get cookingInstructions; bool? get warrantyRequired;// For preparation tracking
 bool? get isPrepared; String? get preparedAt; String? get preparedBy;
/// Create a copy of BusinessOrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessOrderItemCopyWith<BusinessOrderItem> get copyWith => _$BusinessOrderItemCopyWithImpl<BusinessOrderItem>(this as BusinessOrderItem, _$identity);

  /// Serializes this BusinessOrderItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessOrderItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.name, name) || other.name == name)&&(identical(other.image, image) || other.image == image)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.sellingPrice, sellingPrice) || other.sellingPrice == sellingPrice)&&(identical(other.itemTotal, itemTotal) || other.itemTotal == itemTotal)&&(identical(other.prescriptionUrl, prescriptionUrl) || other.prescriptionUrl == prescriptionUrl)&&(identical(other.cookingInstructions, cookingInstructions) || other.cookingInstructions == cookingInstructions)&&(identical(other.warrantyRequired, warrantyRequired) || other.warrantyRequired == warrantyRequired)&&(identical(other.isPrepared, isPrepared) || other.isPrepared == isPrepared)&&(identical(other.preparedAt, preparedAt) || other.preparedAt == preparedAt)&&(identical(other.preparedBy, preparedBy) || other.preparedBy == preparedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productId,name,image,quantity,stockQuantity,unit,mrp,sellingPrice,itemTotal,prescriptionUrl,cookingInstructions,warrantyRequired,isPrepared,preparedAt,preparedBy);

@override
String toString() {
  return 'BusinessOrderItem(productId: $productId, name: $name, image: $image, quantity: $quantity, stockQuantity: $stockQuantity, unit: $unit, mrp: $mrp, sellingPrice: $sellingPrice, itemTotal: $itemTotal, prescriptionUrl: $prescriptionUrl, cookingInstructions: $cookingInstructions, warrantyRequired: $warrantyRequired, isPrepared: $isPrepared, preparedAt: $preparedAt, preparedBy: $preparedBy)';
}


}

/// @nodoc
abstract mixin class $BusinessOrderItemCopyWith<$Res>  {
  factory $BusinessOrderItemCopyWith(BusinessOrderItem value, $Res Function(BusinessOrderItem) _then) = _$BusinessOrderItemCopyWithImpl;
@useResult
$Res call({
 String productId, String name, String? image, int quantity, int? stockQuantity, String unit, double mrp, double sellingPrice, double itemTotal, String? prescriptionUrl, String? cookingInstructions, bool? warrantyRequired, bool? isPrepared, String? preparedAt, String? preparedBy
});




}
/// @nodoc
class _$BusinessOrderItemCopyWithImpl<$Res>
    implements $BusinessOrderItemCopyWith<$Res> {
  _$BusinessOrderItemCopyWithImpl(this._self, this._then);

  final BusinessOrderItem _self;
  final $Res Function(BusinessOrderItem) _then;

/// Create a copy of BusinessOrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? name = null,Object? image = freezed,Object? quantity = null,Object? stockQuantity = freezed,Object? unit = null,Object? mrp = null,Object? sellingPrice = null,Object? itemTotal = null,Object? prescriptionUrl = freezed,Object? cookingInstructions = freezed,Object? warrantyRequired = freezed,Object? isPrepared = freezed,Object? preparedAt = freezed,Object? preparedBy = freezed,}) {
  return _then(_self.copyWith(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: freezed == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int?,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,mrp: null == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double,sellingPrice: null == sellingPrice ? _self.sellingPrice : sellingPrice // ignore: cast_nullable_to_non_nullable
as double,itemTotal: null == itemTotal ? _self.itemTotal : itemTotal // ignore: cast_nullable_to_non_nullable
as double,prescriptionUrl: freezed == prescriptionUrl ? _self.prescriptionUrl : prescriptionUrl // ignore: cast_nullable_to_non_nullable
as String?,cookingInstructions: freezed == cookingInstructions ? _self.cookingInstructions : cookingInstructions // ignore: cast_nullable_to_non_nullable
as String?,warrantyRequired: freezed == warrantyRequired ? _self.warrantyRequired : warrantyRequired // ignore: cast_nullable_to_non_nullable
as bool?,isPrepared: freezed == isPrepared ? _self.isPrepared : isPrepared // ignore: cast_nullable_to_non_nullable
as bool?,preparedAt: freezed == preparedAt ? _self.preparedAt : preparedAt // ignore: cast_nullable_to_non_nullable
as String?,preparedBy: freezed == preparedBy ? _self.preparedBy : preparedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessOrderItem].
extension BusinessOrderItemPatterns on BusinessOrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessOrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessOrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessOrderItem value)  $default,){
final _that = this;
switch (_that) {
case _BusinessOrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessOrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessOrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  String name,  String? image,  int quantity,  int? stockQuantity,  String unit,  double mrp,  double sellingPrice,  double itemTotal,  String? prescriptionUrl,  String? cookingInstructions,  bool? warrantyRequired,  bool? isPrepared,  String? preparedAt,  String? preparedBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessOrderItem() when $default != null:
return $default(_that.productId,_that.name,_that.image,_that.quantity,_that.stockQuantity,_that.unit,_that.mrp,_that.sellingPrice,_that.itemTotal,_that.prescriptionUrl,_that.cookingInstructions,_that.warrantyRequired,_that.isPrepared,_that.preparedAt,_that.preparedBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  String name,  String? image,  int quantity,  int? stockQuantity,  String unit,  double mrp,  double sellingPrice,  double itemTotal,  String? prescriptionUrl,  String? cookingInstructions,  bool? warrantyRequired,  bool? isPrepared,  String? preparedAt,  String? preparedBy)  $default,) {final _that = this;
switch (_that) {
case _BusinessOrderItem():
return $default(_that.productId,_that.name,_that.image,_that.quantity,_that.stockQuantity,_that.unit,_that.mrp,_that.sellingPrice,_that.itemTotal,_that.prescriptionUrl,_that.cookingInstructions,_that.warrantyRequired,_that.isPrepared,_that.preparedAt,_that.preparedBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  String name,  String? image,  int quantity,  int? stockQuantity,  String unit,  double mrp,  double sellingPrice,  double itemTotal,  String? prescriptionUrl,  String? cookingInstructions,  bool? warrantyRequired,  bool? isPrepared,  String? preparedAt,  String? preparedBy)?  $default,) {final _that = this;
switch (_that) {
case _BusinessOrderItem() when $default != null:
return $default(_that.productId,_that.name,_that.image,_that.quantity,_that.stockQuantity,_that.unit,_that.mrp,_that.sellingPrice,_that.itemTotal,_that.prescriptionUrl,_that.cookingInstructions,_that.warrantyRequired,_that.isPrepared,_that.preparedAt,_that.preparedBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusinessOrderItem implements BusinessOrderItem {
  const _BusinessOrderItem({required this.productId, required this.name, this.image, required this.quantity, required this.stockQuantity, required this.unit, required this.mrp, required this.sellingPrice, required this.itemTotal, this.prescriptionUrl, this.cookingInstructions, this.warrantyRequired, this.isPrepared, this.preparedAt, this.preparedBy});
  factory _BusinessOrderItem.fromJson(Map<String, dynamic> json) => _$BusinessOrderItemFromJson(json);

@override final  String productId;
@override final  String name;
@override final  String? image;
@override final  int quantity;
@override final  int? stockQuantity;
@override final  String unit;
@override final  double mrp;
@override final  double sellingPrice;
@override final  double itemTotal;
@override final  String? prescriptionUrl;
@override final  String? cookingInstructions;
@override final  bool? warrantyRequired;
// For preparation tracking
@override final  bool? isPrepared;
@override final  String? preparedAt;
@override final  String? preparedBy;

/// Create a copy of BusinessOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessOrderItemCopyWith<_BusinessOrderItem> get copyWith => __$BusinessOrderItemCopyWithImpl<_BusinessOrderItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusinessOrderItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessOrderItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.name, name) || other.name == name)&&(identical(other.image, image) || other.image == image)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.sellingPrice, sellingPrice) || other.sellingPrice == sellingPrice)&&(identical(other.itemTotal, itemTotal) || other.itemTotal == itemTotal)&&(identical(other.prescriptionUrl, prescriptionUrl) || other.prescriptionUrl == prescriptionUrl)&&(identical(other.cookingInstructions, cookingInstructions) || other.cookingInstructions == cookingInstructions)&&(identical(other.warrantyRequired, warrantyRequired) || other.warrantyRequired == warrantyRequired)&&(identical(other.isPrepared, isPrepared) || other.isPrepared == isPrepared)&&(identical(other.preparedAt, preparedAt) || other.preparedAt == preparedAt)&&(identical(other.preparedBy, preparedBy) || other.preparedBy == preparedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productId,name,image,quantity,stockQuantity,unit,mrp,sellingPrice,itemTotal,prescriptionUrl,cookingInstructions,warrantyRequired,isPrepared,preparedAt,preparedBy);

@override
String toString() {
  return 'BusinessOrderItem(productId: $productId, name: $name, image: $image, quantity: $quantity, stockQuantity: $stockQuantity, unit: $unit, mrp: $mrp, sellingPrice: $sellingPrice, itemTotal: $itemTotal, prescriptionUrl: $prescriptionUrl, cookingInstructions: $cookingInstructions, warrantyRequired: $warrantyRequired, isPrepared: $isPrepared, preparedAt: $preparedAt, preparedBy: $preparedBy)';
}


}

/// @nodoc
abstract mixin class _$BusinessOrderItemCopyWith<$Res> implements $BusinessOrderItemCopyWith<$Res> {
  factory _$BusinessOrderItemCopyWith(_BusinessOrderItem value, $Res Function(_BusinessOrderItem) _then) = __$BusinessOrderItemCopyWithImpl;
@override @useResult
$Res call({
 String productId, String name, String? image, int quantity, int? stockQuantity, String unit, double mrp, double sellingPrice, double itemTotal, String? prescriptionUrl, String? cookingInstructions, bool? warrantyRequired, bool? isPrepared, String? preparedAt, String? preparedBy
});




}
/// @nodoc
class __$BusinessOrderItemCopyWithImpl<$Res>
    implements _$BusinessOrderItemCopyWith<$Res> {
  __$BusinessOrderItemCopyWithImpl(this._self, this._then);

  final _BusinessOrderItem _self;
  final $Res Function(_BusinessOrderItem) _then;

/// Create a copy of BusinessOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? name = null,Object? image = freezed,Object? quantity = null,Object? stockQuantity = freezed,Object? unit = null,Object? mrp = null,Object? sellingPrice = null,Object? itemTotal = null,Object? prescriptionUrl = freezed,Object? cookingInstructions = freezed,Object? warrantyRequired = freezed,Object? isPrepared = freezed,Object? preparedAt = freezed,Object? preparedBy = freezed,}) {
  return _then(_BusinessOrderItem(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: freezed == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int?,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,mrp: null == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double,sellingPrice: null == sellingPrice ? _self.sellingPrice : sellingPrice // ignore: cast_nullable_to_non_nullable
as double,itemTotal: null == itemTotal ? _self.itemTotal : itemTotal // ignore: cast_nullable_to_non_nullable
as double,prescriptionUrl: freezed == prescriptionUrl ? _self.prescriptionUrl : prescriptionUrl // ignore: cast_nullable_to_non_nullable
as String?,cookingInstructions: freezed == cookingInstructions ? _self.cookingInstructions : cookingInstructions // ignore: cast_nullable_to_non_nullable
as String?,warrantyRequired: freezed == warrantyRequired ? _self.warrantyRequired : warrantyRequired // ignore: cast_nullable_to_non_nullable
as bool?,isPrepared: freezed == isPrepared ? _self.isPrepared : isPrepared // ignore: cast_nullable_to_non_nullable
as bool?,preparedAt: freezed == preparedAt ? _self.preparedAt : preparedAt // ignore: cast_nullable_to_non_nullable
as String?,preparedBy: freezed == preparedBy ? _self.preparedBy : preparedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$BusinessDeliveryAddress {

 String get id; String get label; String get addressLine1; String? get addressLine2; String? get landmark; String get city; String get state; String get pincode; String get contactName; String get contactPhone; Map<String, double>? get location;
/// Create a copy of BusinessDeliveryAddress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessDeliveryAddressCopyWith<BusinessDeliveryAddress> get copyWith => _$BusinessDeliveryAddressCopyWithImpl<BusinessDeliveryAddress>(this as BusinessDeliveryAddress, _$identity);

  /// Serializes this BusinessDeliveryAddress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessDeliveryAddress&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.addressLine1, addressLine1) || other.addressLine1 == addressLine1)&&(identical(other.addressLine2, addressLine2) || other.addressLine2 == addressLine2)&&(identical(other.landmark, landmark) || other.landmark == landmark)&&(identical(other.city, city) || other.city == city)&&(identical(other.state, state) || other.state == state)&&(identical(other.pincode, pincode) || other.pincode == pincode)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.contactPhone, contactPhone) || other.contactPhone == contactPhone)&&const DeepCollectionEquality().equals(other.location, location));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,addressLine1,addressLine2,landmark,city,state,pincode,contactName,contactPhone,const DeepCollectionEquality().hash(location));

@override
String toString() {
  return 'BusinessDeliveryAddress(id: $id, label: $label, addressLine1: $addressLine1, addressLine2: $addressLine2, landmark: $landmark, city: $city, state: $state, pincode: $pincode, contactName: $contactName, contactPhone: $contactPhone, location: $location)';
}


}

/// @nodoc
abstract mixin class $BusinessDeliveryAddressCopyWith<$Res>  {
  factory $BusinessDeliveryAddressCopyWith(BusinessDeliveryAddress value, $Res Function(BusinessDeliveryAddress) _then) = _$BusinessDeliveryAddressCopyWithImpl;
@useResult
$Res call({
 String id, String label, String addressLine1, String? addressLine2, String? landmark, String city, String state, String pincode, String contactName, String contactPhone, Map<String, double>? location
});




}
/// @nodoc
class _$BusinessDeliveryAddressCopyWithImpl<$Res>
    implements $BusinessDeliveryAddressCopyWith<$Res> {
  _$BusinessDeliveryAddressCopyWithImpl(this._self, this._then);

  final BusinessDeliveryAddress _self;
  final $Res Function(BusinessDeliveryAddress) _then;

/// Create a copy of BusinessDeliveryAddress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? addressLine1 = null,Object? addressLine2 = freezed,Object? landmark = freezed,Object? city = null,Object? state = null,Object? pincode = null,Object? contactName = null,Object? contactPhone = null,Object? location = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,addressLine1: null == addressLine1 ? _self.addressLine1 : addressLine1 // ignore: cast_nullable_to_non_nullable
as String,addressLine2: freezed == addressLine2 ? _self.addressLine2 : addressLine2 // ignore: cast_nullable_to_non_nullable
as String?,landmark: freezed == landmark ? _self.landmark : landmark // ignore: cast_nullable_to_non_nullable
as String?,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,pincode: null == pincode ? _self.pincode : pincode // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,contactPhone: null == contactPhone ? _self.contactPhone : contactPhone // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as Map<String, double>?,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessDeliveryAddress].
extension BusinessDeliveryAddressPatterns on BusinessDeliveryAddress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessDeliveryAddress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessDeliveryAddress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessDeliveryAddress value)  $default,){
final _that = this;
switch (_that) {
case _BusinessDeliveryAddress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessDeliveryAddress value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessDeliveryAddress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  String addressLine1,  String? addressLine2,  String? landmark,  String city,  String state,  String pincode,  String contactName,  String contactPhone,  Map<String, double>? location)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessDeliveryAddress() when $default != null:
return $default(_that.id,_that.label,_that.addressLine1,_that.addressLine2,_that.landmark,_that.city,_that.state,_that.pincode,_that.contactName,_that.contactPhone,_that.location);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  String addressLine1,  String? addressLine2,  String? landmark,  String city,  String state,  String pincode,  String contactName,  String contactPhone,  Map<String, double>? location)  $default,) {final _that = this;
switch (_that) {
case _BusinessDeliveryAddress():
return $default(_that.id,_that.label,_that.addressLine1,_that.addressLine2,_that.landmark,_that.city,_that.state,_that.pincode,_that.contactName,_that.contactPhone,_that.location);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  String addressLine1,  String? addressLine2,  String? landmark,  String city,  String state,  String pincode,  String contactName,  String contactPhone,  Map<String, double>? location)?  $default,) {final _that = this;
switch (_that) {
case _BusinessDeliveryAddress() when $default != null:
return $default(_that.id,_that.label,_that.addressLine1,_that.addressLine2,_that.landmark,_that.city,_that.state,_that.pincode,_that.contactName,_that.contactPhone,_that.location);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusinessDeliveryAddress implements BusinessDeliveryAddress {
  const _BusinessDeliveryAddress({required this.id, required this.label, required this.addressLine1, this.addressLine2, this.landmark, required this.city, required this.state, required this.pincode, required this.contactName, required this.contactPhone, final  Map<String, double>? location}): _location = location;
  factory _BusinessDeliveryAddress.fromJson(Map<String, dynamic> json) => _$BusinessDeliveryAddressFromJson(json);

@override final  String id;
@override final  String label;
@override final  String addressLine1;
@override final  String? addressLine2;
@override final  String? landmark;
@override final  String city;
@override final  String state;
@override final  String pincode;
@override final  String contactName;
@override final  String contactPhone;
 final  Map<String, double>? _location;
@override Map<String, double>? get location {
  final value = _location;
  if (value == null) return null;
  if (_location is EqualUnmodifiableMapView) return _location;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of BusinessDeliveryAddress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessDeliveryAddressCopyWith<_BusinessDeliveryAddress> get copyWith => __$BusinessDeliveryAddressCopyWithImpl<_BusinessDeliveryAddress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusinessDeliveryAddressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessDeliveryAddress&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.addressLine1, addressLine1) || other.addressLine1 == addressLine1)&&(identical(other.addressLine2, addressLine2) || other.addressLine2 == addressLine2)&&(identical(other.landmark, landmark) || other.landmark == landmark)&&(identical(other.city, city) || other.city == city)&&(identical(other.state, state) || other.state == state)&&(identical(other.pincode, pincode) || other.pincode == pincode)&&(identical(other.contactName, contactName) || other.contactName == contactName)&&(identical(other.contactPhone, contactPhone) || other.contactPhone == contactPhone)&&const DeepCollectionEquality().equals(other._location, _location));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,addressLine1,addressLine2,landmark,city,state,pincode,contactName,contactPhone,const DeepCollectionEquality().hash(_location));

@override
String toString() {
  return 'BusinessDeliveryAddress(id: $id, label: $label, addressLine1: $addressLine1, addressLine2: $addressLine2, landmark: $landmark, city: $city, state: $state, pincode: $pincode, contactName: $contactName, contactPhone: $contactPhone, location: $location)';
}


}

/// @nodoc
abstract mixin class _$BusinessDeliveryAddressCopyWith<$Res> implements $BusinessDeliveryAddressCopyWith<$Res> {
  factory _$BusinessDeliveryAddressCopyWith(_BusinessDeliveryAddress value, $Res Function(_BusinessDeliveryAddress) _then) = __$BusinessDeliveryAddressCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, String addressLine1, String? addressLine2, String? landmark, String city, String state, String pincode, String contactName, String contactPhone, Map<String, double>? location
});




}
/// @nodoc
class __$BusinessDeliveryAddressCopyWithImpl<$Res>
    implements _$BusinessDeliveryAddressCopyWith<$Res> {
  __$BusinessDeliveryAddressCopyWithImpl(this._self, this._then);

  final _BusinessDeliveryAddress _self;
  final $Res Function(_BusinessDeliveryAddress) _then;

/// Create a copy of BusinessDeliveryAddress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? addressLine1 = null,Object? addressLine2 = freezed,Object? landmark = freezed,Object? city = null,Object? state = null,Object? pincode = null,Object? contactName = null,Object? contactPhone = null,Object? location = freezed,}) {
  return _then(_BusinessDeliveryAddress(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,addressLine1: null == addressLine1 ? _self.addressLine1 : addressLine1 // ignore: cast_nullable_to_non_nullable
as String,addressLine2: freezed == addressLine2 ? _self.addressLine2 : addressLine2 // ignore: cast_nullable_to_non_nullable
as String?,landmark: freezed == landmark ? _self.landmark : landmark // ignore: cast_nullable_to_non_nullable
as String?,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,pincode: null == pincode ? _self.pincode : pincode // ignore: cast_nullable_to_non_nullable
as String,contactName: null == contactName ? _self.contactName : contactName // ignore: cast_nullable_to_non_nullable
as String,contactPhone: null == contactPhone ? _self.contactPhone : contactPhone // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self._location : location // ignore: cast_nullable_to_non_nullable
as Map<String, double>?,
  ));
}


}


/// @nodoc
mixin _$BusinessOrderTimelineEvent {

 BusinessOrderStatus get status; String get timestamp; String? get note; String get updatedBy;
/// Create a copy of BusinessOrderTimelineEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessOrderTimelineEventCopyWith<BusinessOrderTimelineEvent> get copyWith => _$BusinessOrderTimelineEventCopyWithImpl<BusinessOrderTimelineEvent>(this as BusinessOrderTimelineEvent, _$identity);

  /// Serializes this BusinessOrderTimelineEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessOrderTimelineEvent&&(identical(other.status, status) || other.status == status)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.note, note) || other.note == note)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,timestamp,note,updatedBy);

@override
String toString() {
  return 'BusinessOrderTimelineEvent(status: $status, timestamp: $timestamp, note: $note, updatedBy: $updatedBy)';
}


}

/// @nodoc
abstract mixin class $BusinessOrderTimelineEventCopyWith<$Res>  {
  factory $BusinessOrderTimelineEventCopyWith(BusinessOrderTimelineEvent value, $Res Function(BusinessOrderTimelineEvent) _then) = _$BusinessOrderTimelineEventCopyWithImpl;
@useResult
$Res call({
 BusinessOrderStatus status, String timestamp, String? note, String updatedBy
});




}
/// @nodoc
class _$BusinessOrderTimelineEventCopyWithImpl<$Res>
    implements $BusinessOrderTimelineEventCopyWith<$Res> {
  _$BusinessOrderTimelineEventCopyWithImpl(this._self, this._then);

  final BusinessOrderTimelineEvent _self;
  final $Res Function(BusinessOrderTimelineEvent) _then;

/// Create a copy of BusinessOrderTimelineEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? timestamp = null,Object? note = freezed,Object? updatedBy = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BusinessOrderStatus,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessOrderTimelineEvent].
extension BusinessOrderTimelineEventPatterns on BusinessOrderTimelineEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessOrderTimelineEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessOrderTimelineEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessOrderTimelineEvent value)  $default,){
final _that = this;
switch (_that) {
case _BusinessOrderTimelineEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessOrderTimelineEvent value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessOrderTimelineEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BusinessOrderStatus status,  String timestamp,  String? note,  String updatedBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessOrderTimelineEvent() when $default != null:
return $default(_that.status,_that.timestamp,_that.note,_that.updatedBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BusinessOrderStatus status,  String timestamp,  String? note,  String updatedBy)  $default,) {final _that = this;
switch (_that) {
case _BusinessOrderTimelineEvent():
return $default(_that.status,_that.timestamp,_that.note,_that.updatedBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BusinessOrderStatus status,  String timestamp,  String? note,  String updatedBy)?  $default,) {final _that = this;
switch (_that) {
case _BusinessOrderTimelineEvent() when $default != null:
return $default(_that.status,_that.timestamp,_that.note,_that.updatedBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusinessOrderTimelineEvent implements BusinessOrderTimelineEvent {
  const _BusinessOrderTimelineEvent({required this.status, required this.timestamp, this.note, required this.updatedBy});
  factory _BusinessOrderTimelineEvent.fromJson(Map<String, dynamic> json) => _$BusinessOrderTimelineEventFromJson(json);

@override final  BusinessOrderStatus status;
@override final  String timestamp;
@override final  String? note;
@override final  String updatedBy;

/// Create a copy of BusinessOrderTimelineEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessOrderTimelineEventCopyWith<_BusinessOrderTimelineEvent> get copyWith => __$BusinessOrderTimelineEventCopyWithImpl<_BusinessOrderTimelineEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusinessOrderTimelineEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessOrderTimelineEvent&&(identical(other.status, status) || other.status == status)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.note, note) || other.note == note)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,timestamp,note,updatedBy);

@override
String toString() {
  return 'BusinessOrderTimelineEvent(status: $status, timestamp: $timestamp, note: $note, updatedBy: $updatedBy)';
}


}

/// @nodoc
abstract mixin class _$BusinessOrderTimelineEventCopyWith<$Res> implements $BusinessOrderTimelineEventCopyWith<$Res> {
  factory _$BusinessOrderTimelineEventCopyWith(_BusinessOrderTimelineEvent value, $Res Function(_BusinessOrderTimelineEvent) _then) = __$BusinessOrderTimelineEventCopyWithImpl;
@override @useResult
$Res call({
 BusinessOrderStatus status, String timestamp, String? note, String updatedBy
});




}
/// @nodoc
class __$BusinessOrderTimelineEventCopyWithImpl<$Res>
    implements _$BusinessOrderTimelineEventCopyWith<$Res> {
  __$BusinessOrderTimelineEventCopyWithImpl(this._self, this._then);

  final _BusinessOrderTimelineEvent _self;
  final $Res Function(_BusinessOrderTimelineEvent) _then;

/// Create a copy of BusinessOrderTimelineEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? timestamp = null,Object? note = freezed,Object? updatedBy = null,}) {
  return _then(_BusinessOrderTimelineEvent(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BusinessOrderStatus,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$BusinessOrder {

 String get orderId; BusinessOrderStatus get status; OnlineCustomer get customer; int get itemCount; double get total; BusinessPaymentMethod get paymentMethod; BusinessPaymentStatus get paymentStatus; bool? get isExpress; String? get scheduledFor; String? get estimatedDeliveryTime; String get createdAt; String? get updatedAt;
/// Create a copy of BusinessOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessOrderCopyWith<BusinessOrder> get copyWith => _$BusinessOrderCopyWithImpl<BusinessOrder>(this as BusinessOrder, _$identity);

  /// Serializes this BusinessOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessOrder&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.status, status) || other.status == status)&&(identical(other.customer, customer) || other.customer == customer)&&(identical(other.itemCount, itemCount) || other.itemCount == itemCount)&&(identical(other.total, total) || other.total == total)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.isExpress, isExpress) || other.isExpress == isExpress)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.estimatedDeliveryTime, estimatedDeliveryTime) || other.estimatedDeliveryTime == estimatedDeliveryTime)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderId,status,customer,itemCount,total,paymentMethod,paymentStatus,isExpress,scheduledFor,estimatedDeliveryTime,createdAt,updatedAt);

@override
String toString() {
  return 'BusinessOrder(orderId: $orderId, status: $status, customer: $customer, itemCount: $itemCount, total: $total, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, isExpress: $isExpress, scheduledFor: $scheduledFor, estimatedDeliveryTime: $estimatedDeliveryTime, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $BusinessOrderCopyWith<$Res>  {
  factory $BusinessOrderCopyWith(BusinessOrder value, $Res Function(BusinessOrder) _then) = _$BusinessOrderCopyWithImpl;
@useResult
$Res call({
 String orderId, BusinessOrderStatus status, OnlineCustomer customer, int itemCount, double total, BusinessPaymentMethod paymentMethod, BusinessPaymentStatus paymentStatus, bool? isExpress, String? scheduledFor, String? estimatedDeliveryTime, String createdAt, String? updatedAt
});


$OnlineCustomerCopyWith<$Res> get customer;

}
/// @nodoc
class _$BusinessOrderCopyWithImpl<$Res>
    implements $BusinessOrderCopyWith<$Res> {
  _$BusinessOrderCopyWithImpl(this._self, this._then);

  final BusinessOrder _self;
  final $Res Function(BusinessOrder) _then;

/// Create a copy of BusinessOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderId = null,Object? status = null,Object? customer = null,Object? itemCount = null,Object? total = null,Object? paymentMethod = null,Object? paymentStatus = null,Object? isExpress = freezed,Object? scheduledFor = freezed,Object? estimatedDeliveryTime = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BusinessOrderStatus,customer: null == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as OnlineCustomer,itemCount: null == itemCount ? _self.itemCount : itemCount // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as BusinessPaymentMethod,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as BusinessPaymentStatus,isExpress: freezed == isExpress ? _self.isExpress : isExpress // ignore: cast_nullable_to_non_nullable
as bool?,scheduledFor: freezed == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as String?,estimatedDeliveryTime: freezed == estimatedDeliveryTime ? _self.estimatedDeliveryTime : estimatedDeliveryTime // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of BusinessOrder
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineCustomerCopyWith<$Res> get customer {
  
  return $OnlineCustomerCopyWith<$Res>(_self.customer, (value) {
    return _then(_self.copyWith(customer: value));
  });
}
}


/// Adds pattern-matching-related methods to [BusinessOrder].
extension BusinessOrderPatterns on BusinessOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessOrder value)  $default,){
final _that = this;
switch (_that) {
case _BusinessOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessOrder value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderId,  BusinessOrderStatus status,  OnlineCustomer customer,  int itemCount,  double total,  BusinessPaymentMethod paymentMethod,  BusinessPaymentStatus paymentStatus,  bool? isExpress,  String? scheduledFor,  String? estimatedDeliveryTime,  String createdAt,  String? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessOrder() when $default != null:
return $default(_that.orderId,_that.status,_that.customer,_that.itemCount,_that.total,_that.paymentMethod,_that.paymentStatus,_that.isExpress,_that.scheduledFor,_that.estimatedDeliveryTime,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderId,  BusinessOrderStatus status,  OnlineCustomer customer,  int itemCount,  double total,  BusinessPaymentMethod paymentMethod,  BusinessPaymentStatus paymentStatus,  bool? isExpress,  String? scheduledFor,  String? estimatedDeliveryTime,  String createdAt,  String? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _BusinessOrder():
return $default(_that.orderId,_that.status,_that.customer,_that.itemCount,_that.total,_that.paymentMethod,_that.paymentStatus,_that.isExpress,_that.scheduledFor,_that.estimatedDeliveryTime,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderId,  BusinessOrderStatus status,  OnlineCustomer customer,  int itemCount,  double total,  BusinessPaymentMethod paymentMethod,  BusinessPaymentStatus paymentStatus,  bool? isExpress,  String? scheduledFor,  String? estimatedDeliveryTime,  String createdAt,  String? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _BusinessOrder() when $default != null:
return $default(_that.orderId,_that.status,_that.customer,_that.itemCount,_that.total,_that.paymentMethod,_that.paymentStatus,_that.isExpress,_that.scheduledFor,_that.estimatedDeliveryTime,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusinessOrder implements BusinessOrder {
  const _BusinessOrder({required this.orderId, required this.status, required this.customer, required this.itemCount, required this.total, required this.paymentMethod, required this.paymentStatus, this.isExpress, this.scheduledFor, this.estimatedDeliveryTime, required this.createdAt, this.updatedAt});
  factory _BusinessOrder.fromJson(Map<String, dynamic> json) => _$BusinessOrderFromJson(json);

@override final  String orderId;
@override final  BusinessOrderStatus status;
@override final  OnlineCustomer customer;
@override final  int itemCount;
@override final  double total;
@override final  BusinessPaymentMethod paymentMethod;
@override final  BusinessPaymentStatus paymentStatus;
@override final  bool? isExpress;
@override final  String? scheduledFor;
@override final  String? estimatedDeliveryTime;
@override final  String createdAt;
@override final  String? updatedAt;

/// Create a copy of BusinessOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessOrderCopyWith<_BusinessOrder> get copyWith => __$BusinessOrderCopyWithImpl<_BusinessOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusinessOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessOrder&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.status, status) || other.status == status)&&(identical(other.customer, customer) || other.customer == customer)&&(identical(other.itemCount, itemCount) || other.itemCount == itemCount)&&(identical(other.total, total) || other.total == total)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.isExpress, isExpress) || other.isExpress == isExpress)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.estimatedDeliveryTime, estimatedDeliveryTime) || other.estimatedDeliveryTime == estimatedDeliveryTime)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderId,status,customer,itemCount,total,paymentMethod,paymentStatus,isExpress,scheduledFor,estimatedDeliveryTime,createdAt,updatedAt);

@override
String toString() {
  return 'BusinessOrder(orderId: $orderId, status: $status, customer: $customer, itemCount: $itemCount, total: $total, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, isExpress: $isExpress, scheduledFor: $scheduledFor, estimatedDeliveryTime: $estimatedDeliveryTime, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BusinessOrderCopyWith<$Res> implements $BusinessOrderCopyWith<$Res> {
  factory _$BusinessOrderCopyWith(_BusinessOrder value, $Res Function(_BusinessOrder) _then) = __$BusinessOrderCopyWithImpl;
@override @useResult
$Res call({
 String orderId, BusinessOrderStatus status, OnlineCustomer customer, int itemCount, double total, BusinessPaymentMethod paymentMethod, BusinessPaymentStatus paymentStatus, bool? isExpress, String? scheduledFor, String? estimatedDeliveryTime, String createdAt, String? updatedAt
});


@override $OnlineCustomerCopyWith<$Res> get customer;

}
/// @nodoc
class __$BusinessOrderCopyWithImpl<$Res>
    implements _$BusinessOrderCopyWith<$Res> {
  __$BusinessOrderCopyWithImpl(this._self, this._then);

  final _BusinessOrder _self;
  final $Res Function(_BusinessOrder) _then;

/// Create a copy of BusinessOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderId = null,Object? status = null,Object? customer = null,Object? itemCount = null,Object? total = null,Object? paymentMethod = null,Object? paymentStatus = null,Object? isExpress = freezed,Object? scheduledFor = freezed,Object? estimatedDeliveryTime = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_BusinessOrder(
orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BusinessOrderStatus,customer: null == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as OnlineCustomer,itemCount: null == itemCount ? _self.itemCount : itemCount // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as BusinessPaymentMethod,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as BusinessPaymentStatus,isExpress: freezed == isExpress ? _self.isExpress : isExpress // ignore: cast_nullable_to_non_nullable
as bool?,scheduledFor: freezed == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as String?,estimatedDeliveryTime: freezed == estimatedDeliveryTime ? _self.estimatedDeliveryTime : estimatedDeliveryTime // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of BusinessOrder
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineCustomerCopyWith<$Res> get customer {
  
  return $OnlineCustomerCopyWith<$Res>(_self.customer, (value) {
    return _then(_self.copyWith(customer: value));
  });
}
}


/// @nodoc
mixin _$BusinessOrderDetail {

 String get orderId; BusinessOrderStatus get status; OnlineCustomer get customer; List<BusinessOrderItem> get items; BusinessDeliveryAddress get deliveryAddress; double get subtotal; double get taxAmount; double get deliveryCharge; double get discountAmount; String? get couponCode; double get total; BusinessPaymentMethod get paymentMethod; BusinessPaymentStatus get paymentStatus; bool? get isExpress; String? get scheduledFor; String? get estimatedDeliveryTime; List<BusinessOrderTimelineEvent> get timeline; String? get notes; String? get prescriptionUrl; String? get createdAt; String? get updatedAt;// Assignment
 DeliveryPartnerInfo? get assignedPartner;
/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessOrderDetailCopyWith<BusinessOrderDetail> get copyWith => _$BusinessOrderDetailCopyWithImpl<BusinessOrderDetail>(this as BusinessOrderDetail, _$identity);

  /// Serializes this BusinessOrderDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessOrderDetail&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.status, status) || other.status == status)&&(identical(other.customer, customer) || other.customer == customer)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.deliveryAddress, deliveryAddress) || other.deliveryAddress == deliveryAddress)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.taxAmount, taxAmount) || other.taxAmount == taxAmount)&&(identical(other.deliveryCharge, deliveryCharge) || other.deliveryCharge == deliveryCharge)&&(identical(other.discountAmount, discountAmount) || other.discountAmount == discountAmount)&&(identical(other.couponCode, couponCode) || other.couponCode == couponCode)&&(identical(other.total, total) || other.total == total)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.isExpress, isExpress) || other.isExpress == isExpress)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.estimatedDeliveryTime, estimatedDeliveryTime) || other.estimatedDeliveryTime == estimatedDeliveryTime)&&const DeepCollectionEquality().equals(other.timeline, timeline)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.prescriptionUrl, prescriptionUrl) || other.prescriptionUrl == prescriptionUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.assignedPartner, assignedPartner) || other.assignedPartner == assignedPartner));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,orderId,status,customer,const DeepCollectionEquality().hash(items),deliveryAddress,subtotal,taxAmount,deliveryCharge,discountAmount,couponCode,total,paymentMethod,paymentStatus,isExpress,scheduledFor,estimatedDeliveryTime,const DeepCollectionEquality().hash(timeline),notes,prescriptionUrl,createdAt,updatedAt,assignedPartner]);

@override
String toString() {
  return 'BusinessOrderDetail(orderId: $orderId, status: $status, customer: $customer, items: $items, deliveryAddress: $deliveryAddress, subtotal: $subtotal, taxAmount: $taxAmount, deliveryCharge: $deliveryCharge, discountAmount: $discountAmount, couponCode: $couponCode, total: $total, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, isExpress: $isExpress, scheduledFor: $scheduledFor, estimatedDeliveryTime: $estimatedDeliveryTime, timeline: $timeline, notes: $notes, prescriptionUrl: $prescriptionUrl, createdAt: $createdAt, updatedAt: $updatedAt, assignedPartner: $assignedPartner)';
}


}

/// @nodoc
abstract mixin class $BusinessOrderDetailCopyWith<$Res>  {
  factory $BusinessOrderDetailCopyWith(BusinessOrderDetail value, $Res Function(BusinessOrderDetail) _then) = _$BusinessOrderDetailCopyWithImpl;
@useResult
$Res call({
 String orderId, BusinessOrderStatus status, OnlineCustomer customer, List<BusinessOrderItem> items, BusinessDeliveryAddress deliveryAddress, double subtotal, double taxAmount, double deliveryCharge, double discountAmount, String? couponCode, double total, BusinessPaymentMethod paymentMethod, BusinessPaymentStatus paymentStatus, bool? isExpress, String? scheduledFor, String? estimatedDeliveryTime, List<BusinessOrderTimelineEvent> timeline, String? notes, String? prescriptionUrl, String? createdAt, String? updatedAt, DeliveryPartnerInfo? assignedPartner
});


$OnlineCustomerCopyWith<$Res> get customer;$BusinessDeliveryAddressCopyWith<$Res> get deliveryAddress;$DeliveryPartnerInfoCopyWith<$Res>? get assignedPartner;

}
/// @nodoc
class _$BusinessOrderDetailCopyWithImpl<$Res>
    implements $BusinessOrderDetailCopyWith<$Res> {
  _$BusinessOrderDetailCopyWithImpl(this._self, this._then);

  final BusinessOrderDetail _self;
  final $Res Function(BusinessOrderDetail) _then;

/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderId = null,Object? status = null,Object? customer = null,Object? items = null,Object? deliveryAddress = null,Object? subtotal = null,Object? taxAmount = null,Object? deliveryCharge = null,Object? discountAmount = null,Object? couponCode = freezed,Object? total = null,Object? paymentMethod = null,Object? paymentStatus = null,Object? isExpress = freezed,Object? scheduledFor = freezed,Object? estimatedDeliveryTime = freezed,Object? timeline = null,Object? notes = freezed,Object? prescriptionUrl = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? assignedPartner = freezed,}) {
  return _then(_self.copyWith(
orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BusinessOrderStatus,customer: null == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as OnlineCustomer,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<BusinessOrderItem>,deliveryAddress: null == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as BusinessDeliveryAddress,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as double,taxAmount: null == taxAmount ? _self.taxAmount : taxAmount // ignore: cast_nullable_to_non_nullable
as double,deliveryCharge: null == deliveryCharge ? _self.deliveryCharge : deliveryCharge // ignore: cast_nullable_to_non_nullable
as double,discountAmount: null == discountAmount ? _self.discountAmount : discountAmount // ignore: cast_nullable_to_non_nullable
as double,couponCode: freezed == couponCode ? _self.couponCode : couponCode // ignore: cast_nullable_to_non_nullable
as String?,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as BusinessPaymentMethod,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as BusinessPaymentStatus,isExpress: freezed == isExpress ? _self.isExpress : isExpress // ignore: cast_nullable_to_non_nullable
as bool?,scheduledFor: freezed == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as String?,estimatedDeliveryTime: freezed == estimatedDeliveryTime ? _self.estimatedDeliveryTime : estimatedDeliveryTime // ignore: cast_nullable_to_non_nullable
as String?,timeline: null == timeline ? _self.timeline : timeline // ignore: cast_nullable_to_non_nullable
as List<BusinessOrderTimelineEvent>,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,prescriptionUrl: freezed == prescriptionUrl ? _self.prescriptionUrl : prescriptionUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,assignedPartner: freezed == assignedPartner ? _self.assignedPartner : assignedPartner // ignore: cast_nullable_to_non_nullable
as DeliveryPartnerInfo?,
  ));
}
/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineCustomerCopyWith<$Res> get customer {
  
  return $OnlineCustomerCopyWith<$Res>(_self.customer, (value) {
    return _then(_self.copyWith(customer: value));
  });
}/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BusinessDeliveryAddressCopyWith<$Res> get deliveryAddress {
  
  return $BusinessDeliveryAddressCopyWith<$Res>(_self.deliveryAddress, (value) {
    return _then(_self.copyWith(deliveryAddress: value));
  });
}/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeliveryPartnerInfoCopyWith<$Res>? get assignedPartner {
    if (_self.assignedPartner == null) {
    return null;
  }

  return $DeliveryPartnerInfoCopyWith<$Res>(_self.assignedPartner!, (value) {
    return _then(_self.copyWith(assignedPartner: value));
  });
}
}


/// Adds pattern-matching-related methods to [BusinessOrderDetail].
extension BusinessOrderDetailPatterns on BusinessOrderDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessOrderDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessOrderDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessOrderDetail value)  $default,){
final _that = this;
switch (_that) {
case _BusinessOrderDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessOrderDetail value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessOrderDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderId,  BusinessOrderStatus status,  OnlineCustomer customer,  List<BusinessOrderItem> items,  BusinessDeliveryAddress deliveryAddress,  double subtotal,  double taxAmount,  double deliveryCharge,  double discountAmount,  String? couponCode,  double total,  BusinessPaymentMethod paymentMethod,  BusinessPaymentStatus paymentStatus,  bool? isExpress,  String? scheduledFor,  String? estimatedDeliveryTime,  List<BusinessOrderTimelineEvent> timeline,  String? notes,  String? prescriptionUrl,  String? createdAt,  String? updatedAt,  DeliveryPartnerInfo? assignedPartner)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessOrderDetail() when $default != null:
return $default(_that.orderId,_that.status,_that.customer,_that.items,_that.deliveryAddress,_that.subtotal,_that.taxAmount,_that.deliveryCharge,_that.discountAmount,_that.couponCode,_that.total,_that.paymentMethod,_that.paymentStatus,_that.isExpress,_that.scheduledFor,_that.estimatedDeliveryTime,_that.timeline,_that.notes,_that.prescriptionUrl,_that.createdAt,_that.updatedAt,_that.assignedPartner);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderId,  BusinessOrderStatus status,  OnlineCustomer customer,  List<BusinessOrderItem> items,  BusinessDeliveryAddress deliveryAddress,  double subtotal,  double taxAmount,  double deliveryCharge,  double discountAmount,  String? couponCode,  double total,  BusinessPaymentMethod paymentMethod,  BusinessPaymentStatus paymentStatus,  bool? isExpress,  String? scheduledFor,  String? estimatedDeliveryTime,  List<BusinessOrderTimelineEvent> timeline,  String? notes,  String? prescriptionUrl,  String? createdAt,  String? updatedAt,  DeliveryPartnerInfo? assignedPartner)  $default,) {final _that = this;
switch (_that) {
case _BusinessOrderDetail():
return $default(_that.orderId,_that.status,_that.customer,_that.items,_that.deliveryAddress,_that.subtotal,_that.taxAmount,_that.deliveryCharge,_that.discountAmount,_that.couponCode,_that.total,_that.paymentMethod,_that.paymentStatus,_that.isExpress,_that.scheduledFor,_that.estimatedDeliveryTime,_that.timeline,_that.notes,_that.prescriptionUrl,_that.createdAt,_that.updatedAt,_that.assignedPartner);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderId,  BusinessOrderStatus status,  OnlineCustomer customer,  List<BusinessOrderItem> items,  BusinessDeliveryAddress deliveryAddress,  double subtotal,  double taxAmount,  double deliveryCharge,  double discountAmount,  String? couponCode,  double total,  BusinessPaymentMethod paymentMethod,  BusinessPaymentStatus paymentStatus,  bool? isExpress,  String? scheduledFor,  String? estimatedDeliveryTime,  List<BusinessOrderTimelineEvent> timeline,  String? notes,  String? prescriptionUrl,  String? createdAt,  String? updatedAt,  DeliveryPartnerInfo? assignedPartner)?  $default,) {final _that = this;
switch (_that) {
case _BusinessOrderDetail() when $default != null:
return $default(_that.orderId,_that.status,_that.customer,_that.items,_that.deliveryAddress,_that.subtotal,_that.taxAmount,_that.deliveryCharge,_that.discountAmount,_that.couponCode,_that.total,_that.paymentMethod,_that.paymentStatus,_that.isExpress,_that.scheduledFor,_that.estimatedDeliveryTime,_that.timeline,_that.notes,_that.prescriptionUrl,_that.createdAt,_that.updatedAt,_that.assignedPartner);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusinessOrderDetail implements BusinessOrderDetail {
  const _BusinessOrderDetail({required this.orderId, required this.status, required this.customer, final  List<BusinessOrderItem> items = const [], required this.deliveryAddress, required this.subtotal, required this.taxAmount, required this.deliveryCharge, required this.discountAmount, this.couponCode, required this.total, required this.paymentMethod, required this.paymentStatus, this.isExpress, this.scheduledFor, this.estimatedDeliveryTime, final  List<BusinessOrderTimelineEvent> timeline = const [], this.notes, this.prescriptionUrl, this.createdAt, this.updatedAt, this.assignedPartner}): _items = items,_timeline = timeline;
  factory _BusinessOrderDetail.fromJson(Map<String, dynamic> json) => _$BusinessOrderDetailFromJson(json);

@override final  String orderId;
@override final  BusinessOrderStatus status;
@override final  OnlineCustomer customer;
 final  List<BusinessOrderItem> _items;
@override@JsonKey() List<BusinessOrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  BusinessDeliveryAddress deliveryAddress;
@override final  double subtotal;
@override final  double taxAmount;
@override final  double deliveryCharge;
@override final  double discountAmount;
@override final  String? couponCode;
@override final  double total;
@override final  BusinessPaymentMethod paymentMethod;
@override final  BusinessPaymentStatus paymentStatus;
@override final  bool? isExpress;
@override final  String? scheduledFor;
@override final  String? estimatedDeliveryTime;
 final  List<BusinessOrderTimelineEvent> _timeline;
@override@JsonKey() List<BusinessOrderTimelineEvent> get timeline {
  if (_timeline is EqualUnmodifiableListView) return _timeline;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_timeline);
}

@override final  String? notes;
@override final  String? prescriptionUrl;
@override final  String? createdAt;
@override final  String? updatedAt;
// Assignment
@override final  DeliveryPartnerInfo? assignedPartner;

/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessOrderDetailCopyWith<_BusinessOrderDetail> get copyWith => __$BusinessOrderDetailCopyWithImpl<_BusinessOrderDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusinessOrderDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessOrderDetail&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.status, status) || other.status == status)&&(identical(other.customer, customer) || other.customer == customer)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.deliveryAddress, deliveryAddress) || other.deliveryAddress == deliveryAddress)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.taxAmount, taxAmount) || other.taxAmount == taxAmount)&&(identical(other.deliveryCharge, deliveryCharge) || other.deliveryCharge == deliveryCharge)&&(identical(other.discountAmount, discountAmount) || other.discountAmount == discountAmount)&&(identical(other.couponCode, couponCode) || other.couponCode == couponCode)&&(identical(other.total, total) || other.total == total)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.isExpress, isExpress) || other.isExpress == isExpress)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.estimatedDeliveryTime, estimatedDeliveryTime) || other.estimatedDeliveryTime == estimatedDeliveryTime)&&const DeepCollectionEquality().equals(other._timeline, _timeline)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.prescriptionUrl, prescriptionUrl) || other.prescriptionUrl == prescriptionUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.assignedPartner, assignedPartner) || other.assignedPartner == assignedPartner));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,orderId,status,customer,const DeepCollectionEquality().hash(_items),deliveryAddress,subtotal,taxAmount,deliveryCharge,discountAmount,couponCode,total,paymentMethod,paymentStatus,isExpress,scheduledFor,estimatedDeliveryTime,const DeepCollectionEquality().hash(_timeline),notes,prescriptionUrl,createdAt,updatedAt,assignedPartner]);

@override
String toString() {
  return 'BusinessOrderDetail(orderId: $orderId, status: $status, customer: $customer, items: $items, deliveryAddress: $deliveryAddress, subtotal: $subtotal, taxAmount: $taxAmount, deliveryCharge: $deliveryCharge, discountAmount: $discountAmount, couponCode: $couponCode, total: $total, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, isExpress: $isExpress, scheduledFor: $scheduledFor, estimatedDeliveryTime: $estimatedDeliveryTime, timeline: $timeline, notes: $notes, prescriptionUrl: $prescriptionUrl, createdAt: $createdAt, updatedAt: $updatedAt, assignedPartner: $assignedPartner)';
}


}

/// @nodoc
abstract mixin class _$BusinessOrderDetailCopyWith<$Res> implements $BusinessOrderDetailCopyWith<$Res> {
  factory _$BusinessOrderDetailCopyWith(_BusinessOrderDetail value, $Res Function(_BusinessOrderDetail) _then) = __$BusinessOrderDetailCopyWithImpl;
@override @useResult
$Res call({
 String orderId, BusinessOrderStatus status, OnlineCustomer customer, List<BusinessOrderItem> items, BusinessDeliveryAddress deliveryAddress, double subtotal, double taxAmount, double deliveryCharge, double discountAmount, String? couponCode, double total, BusinessPaymentMethod paymentMethod, BusinessPaymentStatus paymentStatus, bool? isExpress, String? scheduledFor, String? estimatedDeliveryTime, List<BusinessOrderTimelineEvent> timeline, String? notes, String? prescriptionUrl, String? createdAt, String? updatedAt, DeliveryPartnerInfo? assignedPartner
});


@override $OnlineCustomerCopyWith<$Res> get customer;@override $BusinessDeliveryAddressCopyWith<$Res> get deliveryAddress;@override $DeliveryPartnerInfoCopyWith<$Res>? get assignedPartner;

}
/// @nodoc
class __$BusinessOrderDetailCopyWithImpl<$Res>
    implements _$BusinessOrderDetailCopyWith<$Res> {
  __$BusinessOrderDetailCopyWithImpl(this._self, this._then);

  final _BusinessOrderDetail _self;
  final $Res Function(_BusinessOrderDetail) _then;

/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderId = null,Object? status = null,Object? customer = null,Object? items = null,Object? deliveryAddress = null,Object? subtotal = null,Object? taxAmount = null,Object? deliveryCharge = null,Object? discountAmount = null,Object? couponCode = freezed,Object? total = null,Object? paymentMethod = null,Object? paymentStatus = null,Object? isExpress = freezed,Object? scheduledFor = freezed,Object? estimatedDeliveryTime = freezed,Object? timeline = null,Object? notes = freezed,Object? prescriptionUrl = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? assignedPartner = freezed,}) {
  return _then(_BusinessOrderDetail(
orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BusinessOrderStatus,customer: null == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as OnlineCustomer,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<BusinessOrderItem>,deliveryAddress: null == deliveryAddress ? _self.deliveryAddress : deliveryAddress // ignore: cast_nullable_to_non_nullable
as BusinessDeliveryAddress,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as double,taxAmount: null == taxAmount ? _self.taxAmount : taxAmount // ignore: cast_nullable_to_non_nullable
as double,deliveryCharge: null == deliveryCharge ? _self.deliveryCharge : deliveryCharge // ignore: cast_nullable_to_non_nullable
as double,discountAmount: null == discountAmount ? _self.discountAmount : discountAmount // ignore: cast_nullable_to_non_nullable
as double,couponCode: freezed == couponCode ? _self.couponCode : couponCode // ignore: cast_nullable_to_non_nullable
as String?,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as BusinessPaymentMethod,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as BusinessPaymentStatus,isExpress: freezed == isExpress ? _self.isExpress : isExpress // ignore: cast_nullable_to_non_nullable
as bool?,scheduledFor: freezed == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as String?,estimatedDeliveryTime: freezed == estimatedDeliveryTime ? _self.estimatedDeliveryTime : estimatedDeliveryTime // ignore: cast_nullable_to_non_nullable
as String?,timeline: null == timeline ? _self._timeline : timeline // ignore: cast_nullable_to_non_nullable
as List<BusinessOrderTimelineEvent>,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,prescriptionUrl: freezed == prescriptionUrl ? _self.prescriptionUrl : prescriptionUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,assignedPartner: freezed == assignedPartner ? _self.assignedPartner : assignedPartner // ignore: cast_nullable_to_non_nullable
as DeliveryPartnerInfo?,
  ));
}

/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OnlineCustomerCopyWith<$Res> get customer {
  
  return $OnlineCustomerCopyWith<$Res>(_self.customer, (value) {
    return _then(_self.copyWith(customer: value));
  });
}/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BusinessDeliveryAddressCopyWith<$Res> get deliveryAddress {
  
  return $BusinessDeliveryAddressCopyWith<$Res>(_self.deliveryAddress, (value) {
    return _then(_self.copyWith(deliveryAddress: value));
  });
}/// Create a copy of BusinessOrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeliveryPartnerInfoCopyWith<$Res>? get assignedPartner {
    if (_self.assignedPartner == null) {
    return null;
  }

  return $DeliveryPartnerInfoCopyWith<$Res>(_self.assignedPartner!, (value) {
    return _then(_self.copyWith(assignedPartner: value));
  });
}
}


/// @nodoc
mixin _$DeliveryPartnerInfo {

 String get partnerId; String get name; String get phone; Map<String, double>? get currentLocation; String? get vehicleType; String? get vehicleNumber; bool? get isActive;
/// Create a copy of DeliveryPartnerInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryPartnerInfoCopyWith<DeliveryPartnerInfo> get copyWith => _$DeliveryPartnerInfoCopyWithImpl<DeliveryPartnerInfo>(this as DeliveryPartnerInfo, _$identity);

  /// Serializes this DeliveryPartnerInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryPartnerInfo&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&const DeepCollectionEquality().equals(other.currentLocation, currentLocation)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.vehicleNumber, vehicleNumber) || other.vehicleNumber == vehicleNumber)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,partnerId,name,phone,const DeepCollectionEquality().hash(currentLocation),vehicleType,vehicleNumber,isActive);

@override
String toString() {
  return 'DeliveryPartnerInfo(partnerId: $partnerId, name: $name, phone: $phone, currentLocation: $currentLocation, vehicleType: $vehicleType, vehicleNumber: $vehicleNumber, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $DeliveryPartnerInfoCopyWith<$Res>  {
  factory $DeliveryPartnerInfoCopyWith(DeliveryPartnerInfo value, $Res Function(DeliveryPartnerInfo) _then) = _$DeliveryPartnerInfoCopyWithImpl;
@useResult
$Res call({
 String partnerId, String name, String phone, Map<String, double>? currentLocation, String? vehicleType, String? vehicleNumber, bool? isActive
});




}
/// @nodoc
class _$DeliveryPartnerInfoCopyWithImpl<$Res>
    implements $DeliveryPartnerInfoCopyWith<$Res> {
  _$DeliveryPartnerInfoCopyWithImpl(this._self, this._then);

  final DeliveryPartnerInfo _self;
  final $Res Function(DeliveryPartnerInfo) _then;

/// Create a copy of DeliveryPartnerInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? partnerId = null,Object? name = null,Object? phone = null,Object? currentLocation = freezed,Object? vehicleType = freezed,Object? vehicleNumber = freezed,Object? isActive = freezed,}) {
  return _then(_self.copyWith(
partnerId: null == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,currentLocation: freezed == currentLocation ? _self.currentLocation : currentLocation // ignore: cast_nullable_to_non_nullable
as Map<String, double>?,vehicleType: freezed == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as String?,vehicleNumber: freezed == vehicleNumber ? _self.vehicleNumber : vehicleNumber // ignore: cast_nullable_to_non_nullable
as String?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliveryPartnerInfo].
extension DeliveryPartnerInfoPatterns on DeliveryPartnerInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryPartnerInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryPartnerInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryPartnerInfo value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryPartnerInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryPartnerInfo value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryPartnerInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String partnerId,  String name,  String phone,  Map<String, double>? currentLocation,  String? vehicleType,  String? vehicleNumber,  bool? isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryPartnerInfo() when $default != null:
return $default(_that.partnerId,_that.name,_that.phone,_that.currentLocation,_that.vehicleType,_that.vehicleNumber,_that.isActive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String partnerId,  String name,  String phone,  Map<String, double>? currentLocation,  String? vehicleType,  String? vehicleNumber,  bool? isActive)  $default,) {final _that = this;
switch (_that) {
case _DeliveryPartnerInfo():
return $default(_that.partnerId,_that.name,_that.phone,_that.currentLocation,_that.vehicleType,_that.vehicleNumber,_that.isActive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String partnerId,  String name,  String phone,  Map<String, double>? currentLocation,  String? vehicleType,  String? vehicleNumber,  bool? isActive)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryPartnerInfo() when $default != null:
return $default(_that.partnerId,_that.name,_that.phone,_that.currentLocation,_that.vehicleType,_that.vehicleNumber,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliveryPartnerInfo implements DeliveryPartnerInfo {
  const _DeliveryPartnerInfo({required this.partnerId, required this.name, required this.phone, final  Map<String, double>? currentLocation, this.vehicleType, this.vehicleNumber, this.isActive}): _currentLocation = currentLocation;
  factory _DeliveryPartnerInfo.fromJson(Map<String, dynamic> json) => _$DeliveryPartnerInfoFromJson(json);

@override final  String partnerId;
@override final  String name;
@override final  String phone;
 final  Map<String, double>? _currentLocation;
@override Map<String, double>? get currentLocation {
  final value = _currentLocation;
  if (value == null) return null;
  if (_currentLocation is EqualUnmodifiableMapView) return _currentLocation;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? vehicleType;
@override final  String? vehicleNumber;
@override final  bool? isActive;

/// Create a copy of DeliveryPartnerInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryPartnerInfoCopyWith<_DeliveryPartnerInfo> get copyWith => __$DeliveryPartnerInfoCopyWithImpl<_DeliveryPartnerInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryPartnerInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryPartnerInfo&&(identical(other.partnerId, partnerId) || other.partnerId == partnerId)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&const DeepCollectionEquality().equals(other._currentLocation, _currentLocation)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.vehicleNumber, vehicleNumber) || other.vehicleNumber == vehicleNumber)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,partnerId,name,phone,const DeepCollectionEquality().hash(_currentLocation),vehicleType,vehicleNumber,isActive);

@override
String toString() {
  return 'DeliveryPartnerInfo(partnerId: $partnerId, name: $name, phone: $phone, currentLocation: $currentLocation, vehicleType: $vehicleType, vehicleNumber: $vehicleNumber, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$DeliveryPartnerInfoCopyWith<$Res> implements $DeliveryPartnerInfoCopyWith<$Res> {
  factory _$DeliveryPartnerInfoCopyWith(_DeliveryPartnerInfo value, $Res Function(_DeliveryPartnerInfo) _then) = __$DeliveryPartnerInfoCopyWithImpl;
@override @useResult
$Res call({
 String partnerId, String name, String phone, Map<String, double>? currentLocation, String? vehicleType, String? vehicleNumber, bool? isActive
});




}
/// @nodoc
class __$DeliveryPartnerInfoCopyWithImpl<$Res>
    implements _$DeliveryPartnerInfoCopyWith<$Res> {
  __$DeliveryPartnerInfoCopyWithImpl(this._self, this._then);

  final _DeliveryPartnerInfo _self;
  final $Res Function(_DeliveryPartnerInfo) _then;

/// Create a copy of DeliveryPartnerInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? partnerId = null,Object? name = null,Object? phone = null,Object? currentLocation = freezed,Object? vehicleType = freezed,Object? vehicleNumber = freezed,Object? isActive = freezed,}) {
  return _then(_DeliveryPartnerInfo(
partnerId: null == partnerId ? _self.partnerId : partnerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,currentLocation: freezed == currentLocation ? _self._currentLocation : currentLocation // ignore: cast_nullable_to_non_nullable
as Map<String, double>?,vehicleType: freezed == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as String?,vehicleNumber: freezed == vehicleNumber ? _self.vehicleNumber : vehicleNumber // ignore: cast_nullable_to_non_nullable
as String?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$OrderStats {

 int get totalOrders; double get totalRevenue; int get pendingOrders; int get preparingOrders; int get outForDeliveryOrders; int get deliveredToday; double get avgOrderValue; int get newCustomers; int get repeatCustomers;
/// Create a copy of OrderStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderStatsCopyWith<OrderStats> get copyWith => _$OrderStatsCopyWithImpl<OrderStats>(this as OrderStats, _$identity);

  /// Serializes this OrderStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderStats&&(identical(other.totalOrders, totalOrders) || other.totalOrders == totalOrders)&&(identical(other.totalRevenue, totalRevenue) || other.totalRevenue == totalRevenue)&&(identical(other.pendingOrders, pendingOrders) || other.pendingOrders == pendingOrders)&&(identical(other.preparingOrders, preparingOrders) || other.preparingOrders == preparingOrders)&&(identical(other.outForDeliveryOrders, outForDeliveryOrders) || other.outForDeliveryOrders == outForDeliveryOrders)&&(identical(other.deliveredToday, deliveredToday) || other.deliveredToday == deliveredToday)&&(identical(other.avgOrderValue, avgOrderValue) || other.avgOrderValue == avgOrderValue)&&(identical(other.newCustomers, newCustomers) || other.newCustomers == newCustomers)&&(identical(other.repeatCustomers, repeatCustomers) || other.repeatCustomers == repeatCustomers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalOrders,totalRevenue,pendingOrders,preparingOrders,outForDeliveryOrders,deliveredToday,avgOrderValue,newCustomers,repeatCustomers);

@override
String toString() {
  return 'OrderStats(totalOrders: $totalOrders, totalRevenue: $totalRevenue, pendingOrders: $pendingOrders, preparingOrders: $preparingOrders, outForDeliveryOrders: $outForDeliveryOrders, deliveredToday: $deliveredToday, avgOrderValue: $avgOrderValue, newCustomers: $newCustomers, repeatCustomers: $repeatCustomers)';
}


}

/// @nodoc
abstract mixin class $OrderStatsCopyWith<$Res>  {
  factory $OrderStatsCopyWith(OrderStats value, $Res Function(OrderStats) _then) = _$OrderStatsCopyWithImpl;
@useResult
$Res call({
 int totalOrders, double totalRevenue, int pendingOrders, int preparingOrders, int outForDeliveryOrders, int deliveredToday, double avgOrderValue, int newCustomers, int repeatCustomers
});




}
/// @nodoc
class _$OrderStatsCopyWithImpl<$Res>
    implements $OrderStatsCopyWith<$Res> {
  _$OrderStatsCopyWithImpl(this._self, this._then);

  final OrderStats _self;
  final $Res Function(OrderStats) _then;

/// Create a copy of OrderStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalOrders = null,Object? totalRevenue = null,Object? pendingOrders = null,Object? preparingOrders = null,Object? outForDeliveryOrders = null,Object? deliveredToday = null,Object? avgOrderValue = null,Object? newCustomers = null,Object? repeatCustomers = null,}) {
  return _then(_self.copyWith(
totalOrders: null == totalOrders ? _self.totalOrders : totalOrders // ignore: cast_nullable_to_non_nullable
as int,totalRevenue: null == totalRevenue ? _self.totalRevenue : totalRevenue // ignore: cast_nullable_to_non_nullable
as double,pendingOrders: null == pendingOrders ? _self.pendingOrders : pendingOrders // ignore: cast_nullable_to_non_nullable
as int,preparingOrders: null == preparingOrders ? _self.preparingOrders : preparingOrders // ignore: cast_nullable_to_non_nullable
as int,outForDeliveryOrders: null == outForDeliveryOrders ? _self.outForDeliveryOrders : outForDeliveryOrders // ignore: cast_nullable_to_non_nullable
as int,deliveredToday: null == deliveredToday ? _self.deliveredToday : deliveredToday // ignore: cast_nullable_to_non_nullable
as int,avgOrderValue: null == avgOrderValue ? _self.avgOrderValue : avgOrderValue // ignore: cast_nullable_to_non_nullable
as double,newCustomers: null == newCustomers ? _self.newCustomers : newCustomers // ignore: cast_nullable_to_non_nullable
as int,repeatCustomers: null == repeatCustomers ? _self.repeatCustomers : repeatCustomers // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderStats].
extension OrderStatsPatterns on OrderStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderStats value)  $default,){
final _that = this;
switch (_that) {
case _OrderStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderStats value)?  $default,){
final _that = this;
switch (_that) {
case _OrderStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalOrders,  double totalRevenue,  int pendingOrders,  int preparingOrders,  int outForDeliveryOrders,  int deliveredToday,  double avgOrderValue,  int newCustomers,  int repeatCustomers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderStats() when $default != null:
return $default(_that.totalOrders,_that.totalRevenue,_that.pendingOrders,_that.preparingOrders,_that.outForDeliveryOrders,_that.deliveredToday,_that.avgOrderValue,_that.newCustomers,_that.repeatCustomers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalOrders,  double totalRevenue,  int pendingOrders,  int preparingOrders,  int outForDeliveryOrders,  int deliveredToday,  double avgOrderValue,  int newCustomers,  int repeatCustomers)  $default,) {final _that = this;
switch (_that) {
case _OrderStats():
return $default(_that.totalOrders,_that.totalRevenue,_that.pendingOrders,_that.preparingOrders,_that.outForDeliveryOrders,_that.deliveredToday,_that.avgOrderValue,_that.newCustomers,_that.repeatCustomers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalOrders,  double totalRevenue,  int pendingOrders,  int preparingOrders,  int outForDeliveryOrders,  int deliveredToday,  double avgOrderValue,  int newCustomers,  int repeatCustomers)?  $default,) {final _that = this;
switch (_that) {
case _OrderStats() when $default != null:
return $default(_that.totalOrders,_that.totalRevenue,_that.pendingOrders,_that.preparingOrders,_that.outForDeliveryOrders,_that.deliveredToday,_that.avgOrderValue,_that.newCustomers,_that.repeatCustomers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderStats implements OrderStats {
  const _OrderStats({required this.totalOrders, required this.totalRevenue, required this.pendingOrders, required this.preparingOrders, required this.outForDeliveryOrders, required this.deliveredToday, required this.avgOrderValue, required this.newCustomers, required this.repeatCustomers});
  factory _OrderStats.fromJson(Map<String, dynamic> json) => _$OrderStatsFromJson(json);

@override final  int totalOrders;
@override final  double totalRevenue;
@override final  int pendingOrders;
@override final  int preparingOrders;
@override final  int outForDeliveryOrders;
@override final  int deliveredToday;
@override final  double avgOrderValue;
@override final  int newCustomers;
@override final  int repeatCustomers;

/// Create a copy of OrderStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderStatsCopyWith<_OrderStats> get copyWith => __$OrderStatsCopyWithImpl<_OrderStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderStats&&(identical(other.totalOrders, totalOrders) || other.totalOrders == totalOrders)&&(identical(other.totalRevenue, totalRevenue) || other.totalRevenue == totalRevenue)&&(identical(other.pendingOrders, pendingOrders) || other.pendingOrders == pendingOrders)&&(identical(other.preparingOrders, preparingOrders) || other.preparingOrders == preparingOrders)&&(identical(other.outForDeliveryOrders, outForDeliveryOrders) || other.outForDeliveryOrders == outForDeliveryOrders)&&(identical(other.deliveredToday, deliveredToday) || other.deliveredToday == deliveredToday)&&(identical(other.avgOrderValue, avgOrderValue) || other.avgOrderValue == avgOrderValue)&&(identical(other.newCustomers, newCustomers) || other.newCustomers == newCustomers)&&(identical(other.repeatCustomers, repeatCustomers) || other.repeatCustomers == repeatCustomers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalOrders,totalRevenue,pendingOrders,preparingOrders,outForDeliveryOrders,deliveredToday,avgOrderValue,newCustomers,repeatCustomers);

@override
String toString() {
  return 'OrderStats(totalOrders: $totalOrders, totalRevenue: $totalRevenue, pendingOrders: $pendingOrders, preparingOrders: $preparingOrders, outForDeliveryOrders: $outForDeliveryOrders, deliveredToday: $deliveredToday, avgOrderValue: $avgOrderValue, newCustomers: $newCustomers, repeatCustomers: $repeatCustomers)';
}


}

/// @nodoc
abstract mixin class _$OrderStatsCopyWith<$Res> implements $OrderStatsCopyWith<$Res> {
  factory _$OrderStatsCopyWith(_OrderStats value, $Res Function(_OrderStats) _then) = __$OrderStatsCopyWithImpl;
@override @useResult
$Res call({
 int totalOrders, double totalRevenue, int pendingOrders, int preparingOrders, int outForDeliveryOrders, int deliveredToday, double avgOrderValue, int newCustomers, int repeatCustomers
});




}
/// @nodoc
class __$OrderStatsCopyWithImpl<$Res>
    implements _$OrderStatsCopyWith<$Res> {
  __$OrderStatsCopyWithImpl(this._self, this._then);

  final _OrderStats _self;
  final $Res Function(_OrderStats) _then;

/// Create a copy of OrderStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalOrders = null,Object? totalRevenue = null,Object? pendingOrders = null,Object? preparingOrders = null,Object? outForDeliveryOrders = null,Object? deliveredToday = null,Object? avgOrderValue = null,Object? newCustomers = null,Object? repeatCustomers = null,}) {
  return _then(_OrderStats(
totalOrders: null == totalOrders ? _self.totalOrders : totalOrders // ignore: cast_nullable_to_non_nullable
as int,totalRevenue: null == totalRevenue ? _self.totalRevenue : totalRevenue // ignore: cast_nullable_to_non_nullable
as double,pendingOrders: null == pendingOrders ? _self.pendingOrders : pendingOrders // ignore: cast_nullable_to_non_nullable
as int,preparingOrders: null == preparingOrders ? _self.preparingOrders : preparingOrders // ignore: cast_nullable_to_non_nullable
as int,outForDeliveryOrders: null == outForDeliveryOrders ? _self.outForDeliveryOrders : outForDeliveryOrders // ignore: cast_nullable_to_non_nullable
as int,deliveredToday: null == deliveredToday ? _self.deliveredToday : deliveredToday // ignore: cast_nullable_to_non_nullable
as int,avgOrderValue: null == avgOrderValue ? _self.avgOrderValue : avgOrderValue // ignore: cast_nullable_to_non_nullable
as double,newCustomers: null == newCustomers ? _self.newCustomers : newCustomers // ignore: cast_nullable_to_non_nullable
as int,repeatCustomers: null == repeatCustomers ? _self.repeatCustomers : repeatCustomers // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$OrderFilters {

 BusinessOrderStatus? get status; DateTime? get dateFrom; DateTime? get dateTo; String? get searchQuery; String? get sortBy; bool? get isExpress;
/// Create a copy of OrderFilters
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderFiltersCopyWith<OrderFilters> get copyWith => _$OrderFiltersCopyWithImpl<OrderFilters>(this as OrderFilters, _$identity);

  /// Serializes this OrderFilters to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderFilters&&(identical(other.status, status) || other.status == status)&&(identical(other.dateFrom, dateFrom) || other.dateFrom == dateFrom)&&(identical(other.dateTo, dateTo) || other.dateTo == dateTo)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.sortBy, sortBy) || other.sortBy == sortBy)&&(identical(other.isExpress, isExpress) || other.isExpress == isExpress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,dateFrom,dateTo,searchQuery,sortBy,isExpress);

@override
String toString() {
  return 'OrderFilters(status: $status, dateFrom: $dateFrom, dateTo: $dateTo, searchQuery: $searchQuery, sortBy: $sortBy, isExpress: $isExpress)';
}


}

/// @nodoc
abstract mixin class $OrderFiltersCopyWith<$Res>  {
  factory $OrderFiltersCopyWith(OrderFilters value, $Res Function(OrderFilters) _then) = _$OrderFiltersCopyWithImpl;
@useResult
$Res call({
 BusinessOrderStatus? status, DateTime? dateFrom, DateTime? dateTo, String? searchQuery, String? sortBy, bool? isExpress
});




}
/// @nodoc
class _$OrderFiltersCopyWithImpl<$Res>
    implements $OrderFiltersCopyWith<$Res> {
  _$OrderFiltersCopyWithImpl(this._self, this._then);

  final OrderFilters _self;
  final $Res Function(OrderFilters) _then;

/// Create a copy of OrderFilters
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = freezed,Object? dateFrom = freezed,Object? dateTo = freezed,Object? searchQuery = freezed,Object? sortBy = freezed,Object? isExpress = freezed,}) {
  return _then(_self.copyWith(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BusinessOrderStatus?,dateFrom: freezed == dateFrom ? _self.dateFrom : dateFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,dateTo: freezed == dateTo ? _self.dateTo : dateTo // ignore: cast_nullable_to_non_nullable
as DateTime?,searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,sortBy: freezed == sortBy ? _self.sortBy : sortBy // ignore: cast_nullable_to_non_nullable
as String?,isExpress: freezed == isExpress ? _self.isExpress : isExpress // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderFilters].
extension OrderFiltersPatterns on OrderFilters {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderFilters value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderFilters() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderFilters value)  $default,){
final _that = this;
switch (_that) {
case _OrderFilters():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderFilters value)?  $default,){
final _that = this;
switch (_that) {
case _OrderFilters() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BusinessOrderStatus? status,  DateTime? dateFrom,  DateTime? dateTo,  String? searchQuery,  String? sortBy,  bool? isExpress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderFilters() when $default != null:
return $default(_that.status,_that.dateFrom,_that.dateTo,_that.searchQuery,_that.sortBy,_that.isExpress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BusinessOrderStatus? status,  DateTime? dateFrom,  DateTime? dateTo,  String? searchQuery,  String? sortBy,  bool? isExpress)  $default,) {final _that = this;
switch (_that) {
case _OrderFilters():
return $default(_that.status,_that.dateFrom,_that.dateTo,_that.searchQuery,_that.sortBy,_that.isExpress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BusinessOrderStatus? status,  DateTime? dateFrom,  DateTime? dateTo,  String? searchQuery,  String? sortBy,  bool? isExpress)?  $default,) {final _that = this;
switch (_that) {
case _OrderFilters() when $default != null:
return $default(_that.status,_that.dateFrom,_that.dateTo,_that.searchQuery,_that.sortBy,_that.isExpress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderFilters implements OrderFilters {
  const _OrderFilters({this.status, this.dateFrom, this.dateTo, this.searchQuery, this.sortBy, this.isExpress});
  factory _OrderFilters.fromJson(Map<String, dynamic> json) => _$OrderFiltersFromJson(json);

@override final  BusinessOrderStatus? status;
@override final  DateTime? dateFrom;
@override final  DateTime? dateTo;
@override final  String? searchQuery;
@override final  String? sortBy;
@override final  bool? isExpress;

/// Create a copy of OrderFilters
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderFiltersCopyWith<_OrderFilters> get copyWith => __$OrderFiltersCopyWithImpl<_OrderFilters>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderFiltersToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderFilters&&(identical(other.status, status) || other.status == status)&&(identical(other.dateFrom, dateFrom) || other.dateFrom == dateFrom)&&(identical(other.dateTo, dateTo) || other.dateTo == dateTo)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.sortBy, sortBy) || other.sortBy == sortBy)&&(identical(other.isExpress, isExpress) || other.isExpress == isExpress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,dateFrom,dateTo,searchQuery,sortBy,isExpress);

@override
String toString() {
  return 'OrderFilters(status: $status, dateFrom: $dateFrom, dateTo: $dateTo, searchQuery: $searchQuery, sortBy: $sortBy, isExpress: $isExpress)';
}


}

/// @nodoc
abstract mixin class _$OrderFiltersCopyWith<$Res> implements $OrderFiltersCopyWith<$Res> {
  factory _$OrderFiltersCopyWith(_OrderFilters value, $Res Function(_OrderFilters) _then) = __$OrderFiltersCopyWithImpl;
@override @useResult
$Res call({
 BusinessOrderStatus? status, DateTime? dateFrom, DateTime? dateTo, String? searchQuery, String? sortBy, bool? isExpress
});




}
/// @nodoc
class __$OrderFiltersCopyWithImpl<$Res>
    implements _$OrderFiltersCopyWith<$Res> {
  __$OrderFiltersCopyWithImpl(this._self, this._then);

  final _OrderFilters _self;
  final $Res Function(_OrderFilters) _then;

/// Create a copy of OrderFilters
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = freezed,Object? dateFrom = freezed,Object? dateTo = freezed,Object? searchQuery = freezed,Object? sortBy = freezed,Object? isExpress = freezed,}) {
  return _then(_OrderFilters(
status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BusinessOrderStatus?,dateFrom: freezed == dateFrom ? _self.dateFrom : dateFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,dateTo: freezed == dateTo ? _self.dateTo : dateTo // ignore: cast_nullable_to_non_nullable
as DateTime?,searchQuery: freezed == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String?,sortBy: freezed == sortBy ? _self.sortBy : sortBy // ignore: cast_nullable_to_non_nullable
as String?,isExpress: freezed == isExpress ? _self.isExpress : isExpress // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$PaginatedOrders {

 List<BusinessOrder> get orders; int get total; int get page; int get limit; bool get hasMore;
/// Create a copy of PaginatedOrders
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginatedOrdersCopyWith<PaginatedOrders> get copyWith => _$PaginatedOrdersCopyWithImpl<PaginatedOrders>(this as PaginatedOrders, _$identity);

  /// Serializes this PaginatedOrders to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginatedOrders&&const DeepCollectionEquality().equals(other.orders, orders)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(orders),total,page,limit,hasMore);

@override
String toString() {
  return 'PaginatedOrders(orders: $orders, total: $total, page: $page, limit: $limit, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class $PaginatedOrdersCopyWith<$Res>  {
  factory $PaginatedOrdersCopyWith(PaginatedOrders value, $Res Function(PaginatedOrders) _then) = _$PaginatedOrdersCopyWithImpl;
@useResult
$Res call({
 List<BusinessOrder> orders, int total, int page, int limit, bool hasMore
});




}
/// @nodoc
class _$PaginatedOrdersCopyWithImpl<$Res>
    implements $PaginatedOrdersCopyWith<$Res> {
  _$PaginatedOrdersCopyWithImpl(this._self, this._then);

  final PaginatedOrders _self;
  final $Res Function(PaginatedOrders) _then;

/// Create a copy of PaginatedOrders
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orders = null,Object? total = null,Object? page = null,Object? limit = null,Object? hasMore = null,}) {
  return _then(_self.copyWith(
orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as List<BusinessOrder>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PaginatedOrders].
extension PaginatedOrdersPatterns on PaginatedOrders {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaginatedOrders value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaginatedOrders() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaginatedOrders value)  $default,){
final _that = this;
switch (_that) {
case _PaginatedOrders():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaginatedOrders value)?  $default,){
final _that = this;
switch (_that) {
case _PaginatedOrders() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<BusinessOrder> orders,  int total,  int page,  int limit,  bool hasMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaginatedOrders() when $default != null:
return $default(_that.orders,_that.total,_that.page,_that.limit,_that.hasMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<BusinessOrder> orders,  int total,  int page,  int limit,  bool hasMore)  $default,) {final _that = this;
switch (_that) {
case _PaginatedOrders():
return $default(_that.orders,_that.total,_that.page,_that.limit,_that.hasMore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<BusinessOrder> orders,  int total,  int page,  int limit,  bool hasMore)?  $default,) {final _that = this;
switch (_that) {
case _PaginatedOrders() when $default != null:
return $default(_that.orders,_that.total,_that.page,_that.limit,_that.hasMore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaginatedOrders implements PaginatedOrders {
  const _PaginatedOrders({final  List<BusinessOrder> orders = const [], required this.total, required this.page, required this.limit, required this.hasMore}): _orders = orders;
  factory _PaginatedOrders.fromJson(Map<String, dynamic> json) => _$PaginatedOrdersFromJson(json);

 final  List<BusinessOrder> _orders;
@override@JsonKey() List<BusinessOrder> get orders {
  if (_orders is EqualUnmodifiableListView) return _orders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_orders);
}

@override final  int total;
@override final  int page;
@override final  int limit;
@override final  bool hasMore;

/// Create a copy of PaginatedOrders
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaginatedOrdersCopyWith<_PaginatedOrders> get copyWith => __$PaginatedOrdersCopyWithImpl<_PaginatedOrders>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaginatedOrdersToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaginatedOrders&&const DeepCollectionEquality().equals(other._orders, _orders)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_orders),total,page,limit,hasMore);

@override
String toString() {
  return 'PaginatedOrders(orders: $orders, total: $total, page: $page, limit: $limit, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class _$PaginatedOrdersCopyWith<$Res> implements $PaginatedOrdersCopyWith<$Res> {
  factory _$PaginatedOrdersCopyWith(_PaginatedOrders value, $Res Function(_PaginatedOrders) _then) = __$PaginatedOrdersCopyWithImpl;
@override @useResult
$Res call({
 List<BusinessOrder> orders, int total, int page, int limit, bool hasMore
});




}
/// @nodoc
class __$PaginatedOrdersCopyWithImpl<$Res>
    implements _$PaginatedOrdersCopyWith<$Res> {
  __$PaginatedOrdersCopyWithImpl(this._self, this._then);

  final _PaginatedOrders _self;
  final $Res Function(_PaginatedOrders) _then;

/// Create a copy of PaginatedOrders
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orders = null,Object? total = null,Object? page = null,Object? limit = null,Object? hasMore = null,}) {
  return _then(_PaginatedOrders(
orders: null == orders ? _self._orders : orders // ignore: cast_nullable_to_non_nullable
as List<BusinessOrder>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$InventorySyncItem {

 String get productId; String get name; String get category; double? get mrp; double? get sellingPrice; int? get stockQuantity; bool? get isActive; bool? get isAvailableForOnline; String? get barcode; String? get hsnCode; double? get gstPercent;// Industry-specific
 String? get expiryDate; String? get drugSchedule;
/// Create a copy of InventorySyncItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventorySyncItemCopyWith<InventorySyncItem> get copyWith => _$InventorySyncItemCopyWithImpl<InventorySyncItem>(this as InventorySyncItem, _$identity);

  /// Serializes this InventorySyncItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventorySyncItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.sellingPrice, sellingPrice) || other.sellingPrice == sellingPrice)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isAvailableForOnline, isAvailableForOnline) || other.isAvailableForOnline == isAvailableForOnline)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.hsnCode, hsnCode) || other.hsnCode == hsnCode)&&(identical(other.gstPercent, gstPercent) || other.gstPercent == gstPercent)&&(identical(other.expiryDate, expiryDate) || other.expiryDate == expiryDate)&&(identical(other.drugSchedule, drugSchedule) || other.drugSchedule == drugSchedule));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productId,name,category,mrp,sellingPrice,stockQuantity,isActive,isAvailableForOnline,barcode,hsnCode,gstPercent,expiryDate,drugSchedule);

@override
String toString() {
  return 'InventorySyncItem(productId: $productId, name: $name, category: $category, mrp: $mrp, sellingPrice: $sellingPrice, stockQuantity: $stockQuantity, isActive: $isActive, isAvailableForOnline: $isAvailableForOnline, barcode: $barcode, hsnCode: $hsnCode, gstPercent: $gstPercent, expiryDate: $expiryDate, drugSchedule: $drugSchedule)';
}


}

/// @nodoc
abstract mixin class $InventorySyncItemCopyWith<$Res>  {
  factory $InventorySyncItemCopyWith(InventorySyncItem value, $Res Function(InventorySyncItem) _then) = _$InventorySyncItemCopyWithImpl;
@useResult
$Res call({
 String productId, String name, String category, double? mrp, double? sellingPrice, int? stockQuantity, bool? isActive, bool? isAvailableForOnline, String? barcode, String? hsnCode, double? gstPercent, String? expiryDate, String? drugSchedule
});




}
/// @nodoc
class _$InventorySyncItemCopyWithImpl<$Res>
    implements $InventorySyncItemCopyWith<$Res> {
  _$InventorySyncItemCopyWithImpl(this._self, this._then);

  final InventorySyncItem _self;
  final $Res Function(InventorySyncItem) _then;

/// Create a copy of InventorySyncItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? name = null,Object? category = null,Object? mrp = freezed,Object? sellingPrice = freezed,Object? stockQuantity = freezed,Object? isActive = freezed,Object? isAvailableForOnline = freezed,Object? barcode = freezed,Object? hsnCode = freezed,Object? gstPercent = freezed,Object? expiryDate = freezed,Object? drugSchedule = freezed,}) {
  return _then(_self.copyWith(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,mrp: freezed == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double?,sellingPrice: freezed == sellingPrice ? _self.sellingPrice : sellingPrice // ignore: cast_nullable_to_non_nullable
as double?,stockQuantity: freezed == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,isAvailableForOnline: freezed == isAvailableForOnline ? _self.isAvailableForOnline : isAvailableForOnline // ignore: cast_nullable_to_non_nullable
as bool?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,hsnCode: freezed == hsnCode ? _self.hsnCode : hsnCode // ignore: cast_nullable_to_non_nullable
as String?,gstPercent: freezed == gstPercent ? _self.gstPercent : gstPercent // ignore: cast_nullable_to_non_nullable
as double?,expiryDate: freezed == expiryDate ? _self.expiryDate : expiryDate // ignore: cast_nullable_to_non_nullable
as String?,drugSchedule: freezed == drugSchedule ? _self.drugSchedule : drugSchedule // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [InventorySyncItem].
extension InventorySyncItemPatterns on InventorySyncItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventorySyncItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventorySyncItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventorySyncItem value)  $default,){
final _that = this;
switch (_that) {
case _InventorySyncItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventorySyncItem value)?  $default,){
final _that = this;
switch (_that) {
case _InventorySyncItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productId,  String name,  String category,  double? mrp,  double? sellingPrice,  int? stockQuantity,  bool? isActive,  bool? isAvailableForOnline,  String? barcode,  String? hsnCode,  double? gstPercent,  String? expiryDate,  String? drugSchedule)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventorySyncItem() when $default != null:
return $default(_that.productId,_that.name,_that.category,_that.mrp,_that.sellingPrice,_that.stockQuantity,_that.isActive,_that.isAvailableForOnline,_that.barcode,_that.hsnCode,_that.gstPercent,_that.expiryDate,_that.drugSchedule);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productId,  String name,  String category,  double? mrp,  double? sellingPrice,  int? stockQuantity,  bool? isActive,  bool? isAvailableForOnline,  String? barcode,  String? hsnCode,  double? gstPercent,  String? expiryDate,  String? drugSchedule)  $default,) {final _that = this;
switch (_that) {
case _InventorySyncItem():
return $default(_that.productId,_that.name,_that.category,_that.mrp,_that.sellingPrice,_that.stockQuantity,_that.isActive,_that.isAvailableForOnline,_that.barcode,_that.hsnCode,_that.gstPercent,_that.expiryDate,_that.drugSchedule);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productId,  String name,  String category,  double? mrp,  double? sellingPrice,  int? stockQuantity,  bool? isActive,  bool? isAvailableForOnline,  String? barcode,  String? hsnCode,  double? gstPercent,  String? expiryDate,  String? drugSchedule)?  $default,) {final _that = this;
switch (_that) {
case _InventorySyncItem() when $default != null:
return $default(_that.productId,_that.name,_that.category,_that.mrp,_that.sellingPrice,_that.stockQuantity,_that.isActive,_that.isAvailableForOnline,_that.barcode,_that.hsnCode,_that.gstPercent,_that.expiryDate,_that.drugSchedule);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventorySyncItem implements InventorySyncItem {
  const _InventorySyncItem({required this.productId, required this.name, required this.category, this.mrp, this.sellingPrice, this.stockQuantity, this.isActive, this.isAvailableForOnline, this.barcode, this.hsnCode, this.gstPercent, this.expiryDate, this.drugSchedule});
  factory _InventorySyncItem.fromJson(Map<String, dynamic> json) => _$InventorySyncItemFromJson(json);

@override final  String productId;
@override final  String name;
@override final  String category;
@override final  double? mrp;
@override final  double? sellingPrice;
@override final  int? stockQuantity;
@override final  bool? isActive;
@override final  bool? isAvailableForOnline;
@override final  String? barcode;
@override final  String? hsnCode;
@override final  double? gstPercent;
// Industry-specific
@override final  String? expiryDate;
@override final  String? drugSchedule;

/// Create a copy of InventorySyncItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventorySyncItemCopyWith<_InventorySyncItem> get copyWith => __$InventorySyncItemCopyWithImpl<_InventorySyncItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventorySyncItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventorySyncItem&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.mrp, mrp) || other.mrp == mrp)&&(identical(other.sellingPrice, sellingPrice) || other.sellingPrice == sellingPrice)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isAvailableForOnline, isAvailableForOnline) || other.isAvailableForOnline == isAvailableForOnline)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.hsnCode, hsnCode) || other.hsnCode == hsnCode)&&(identical(other.gstPercent, gstPercent) || other.gstPercent == gstPercent)&&(identical(other.expiryDate, expiryDate) || other.expiryDate == expiryDate)&&(identical(other.drugSchedule, drugSchedule) || other.drugSchedule == drugSchedule));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productId,name,category,mrp,sellingPrice,stockQuantity,isActive,isAvailableForOnline,barcode,hsnCode,gstPercent,expiryDate,drugSchedule);

@override
String toString() {
  return 'InventorySyncItem(productId: $productId, name: $name, category: $category, mrp: $mrp, sellingPrice: $sellingPrice, stockQuantity: $stockQuantity, isActive: $isActive, isAvailableForOnline: $isAvailableForOnline, barcode: $barcode, hsnCode: $hsnCode, gstPercent: $gstPercent, expiryDate: $expiryDate, drugSchedule: $drugSchedule)';
}


}

/// @nodoc
abstract mixin class _$InventorySyncItemCopyWith<$Res> implements $InventorySyncItemCopyWith<$Res> {
  factory _$InventorySyncItemCopyWith(_InventorySyncItem value, $Res Function(_InventorySyncItem) _then) = __$InventorySyncItemCopyWithImpl;
@override @useResult
$Res call({
 String productId, String name, String category, double? mrp, double? sellingPrice, int? stockQuantity, bool? isActive, bool? isAvailableForOnline, String? barcode, String? hsnCode, double? gstPercent, String? expiryDate, String? drugSchedule
});




}
/// @nodoc
class __$InventorySyncItemCopyWithImpl<$Res>
    implements _$InventorySyncItemCopyWith<$Res> {
  __$InventorySyncItemCopyWithImpl(this._self, this._then);

  final _InventorySyncItem _self;
  final $Res Function(_InventorySyncItem) _then;

/// Create a copy of InventorySyncItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? name = null,Object? category = null,Object? mrp = freezed,Object? sellingPrice = freezed,Object? stockQuantity = freezed,Object? isActive = freezed,Object? isAvailableForOnline = freezed,Object? barcode = freezed,Object? hsnCode = freezed,Object? gstPercent = freezed,Object? expiryDate = freezed,Object? drugSchedule = freezed,}) {
  return _then(_InventorySyncItem(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,mrp: freezed == mrp ? _self.mrp : mrp // ignore: cast_nullable_to_non_nullable
as double?,sellingPrice: freezed == sellingPrice ? _self.sellingPrice : sellingPrice // ignore: cast_nullable_to_non_nullable
as double?,stockQuantity: freezed == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,isAvailableForOnline: freezed == isAvailableForOnline ? _self.isAvailableForOnline : isAvailableForOnline // ignore: cast_nullable_to_non_nullable
as bool?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,hsnCode: freezed == hsnCode ? _self.hsnCode : hsnCode // ignore: cast_nullable_to_non_nullable
as String?,gstPercent: freezed == gstPercent ? _self.gstPercent : gstPercent // ignore: cast_nullable_to_non_nullable
as double?,expiryDate: freezed == expiryDate ? _self.expiryDate : expiryDate // ignore: cast_nullable_to_non_nullable
as String?,drugSchedule: freezed == drugSchedule ? _self.drugSchedule : drugSchedule // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
