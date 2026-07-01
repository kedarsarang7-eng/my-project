// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jewellery_certificate_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JewelleryCertificate {

// Core identifiers (RID pattern: {tenantId}-{timestamp_ms}-{uuid_v4_short})
@HiveField(0) String get id;@HiveField(1) String get tenantId;// Product/HUID link
@HiveField(2) String get productId;@HiveField(3) String? get huid;// Optional BIS HUID link
// Certificate details
@HiveField(4) CertificateType get type;@HiveField(5) String get issuer;// Issuing authority/organization
@HiveField(6) DateTime get issueDate;@HiveField(7) DateTime? get expiryDate;// Document reference
@HiveField(8) String? get documentUrl;// URL/path to certificate document
// Valuation in integer paise (Requirement 1.1: integer paise for money)
@HiveField(9) int get valuationPaisa;// Additional info
@HiveField(10) String? get notes;@HiveField(11) bool get isActive;// Metadata
@HiveField(12) DateTime get createdAt;// Sync tracking
@HiveField(13) bool get synced;@HiveField(14) DateTime? get lastSyncedAt;@HiveField(15) String? get pendingOperation;
/// Create a copy of JewelleryCertificate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JewelleryCertificateCopyWith<JewelleryCertificate> get copyWith => _$JewelleryCertificateCopyWithImpl<JewelleryCertificate>(this as JewelleryCertificate, _$identity);

  /// Serializes this JewelleryCertificate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JewelleryCertificate&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.huid, huid) || other.huid == huid)&&(identical(other.type, type) || other.type == type)&&(identical(other.issuer, issuer) || other.issuer == issuer)&&(identical(other.issueDate, issueDate) || other.issueDate == issueDate)&&(identical(other.expiryDate, expiryDate) || other.expiryDate == expiryDate)&&(identical(other.documentUrl, documentUrl) || other.documentUrl == documentUrl)&&(identical(other.valuationPaisa, valuationPaisa) || other.valuationPaisa == valuationPaisa)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,productId,huid,type,issuer,issueDate,expiryDate,documentUrl,valuationPaisa,notes,isActive,createdAt,synced,lastSyncedAt,pendingOperation);

@override
String toString() {
  return 'JewelleryCertificate(id: $id, tenantId: $tenantId, productId: $productId, huid: $huid, type: $type, issuer: $issuer, issueDate: $issueDate, expiryDate: $expiryDate, documentUrl: $documentUrl, valuationPaisa: $valuationPaisa, notes: $notes, isActive: $isActive, createdAt: $createdAt, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class $JewelleryCertificateCopyWith<$Res>  {
  factory $JewelleryCertificateCopyWith(JewelleryCertificate value, $Res Function(JewelleryCertificate) _then) = _$JewelleryCertificateCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String productId,@HiveField(3) String? huid,@HiveField(4) CertificateType type,@HiveField(5) String issuer,@HiveField(6) DateTime issueDate,@HiveField(7) DateTime? expiryDate,@HiveField(8) String? documentUrl,@HiveField(9) int valuationPaisa,@HiveField(10) String? notes,@HiveField(11) bool isActive,@HiveField(12) DateTime createdAt,@HiveField(13) bool synced,@HiveField(14) DateTime? lastSyncedAt,@HiveField(15) String? pendingOperation
});




}
/// @nodoc
class _$JewelleryCertificateCopyWithImpl<$Res>
    implements $JewelleryCertificateCopyWith<$Res> {
  _$JewelleryCertificateCopyWithImpl(this._self, this._then);

  final JewelleryCertificate _self;
  final $Res Function(JewelleryCertificate) _then;

/// Create a copy of JewelleryCertificate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? productId = null,Object? huid = freezed,Object? type = null,Object? issuer = null,Object? issueDate = null,Object? expiryDate = freezed,Object? documentUrl = freezed,Object? valuationPaisa = null,Object? notes = freezed,Object? isActive = null,Object? createdAt = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,huid: freezed == huid ? _self.huid : huid // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CertificateType,issuer: null == issuer ? _self.issuer : issuer // ignore: cast_nullable_to_non_nullable
as String,issueDate: null == issueDate ? _self.issueDate : issueDate // ignore: cast_nullable_to_non_nullable
as DateTime,expiryDate: freezed == expiryDate ? _self.expiryDate : expiryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,documentUrl: freezed == documentUrl ? _self.documentUrl : documentUrl // ignore: cast_nullable_to_non_nullable
as String?,valuationPaisa: null == valuationPaisa ? _self.valuationPaisa : valuationPaisa // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [JewelleryCertificate].
extension JewelleryCertificatePatterns on JewelleryCertificate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JewelleryCertificate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JewelleryCertificate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JewelleryCertificate value)  $default,){
final _that = this;
switch (_that) {
case _JewelleryCertificate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JewelleryCertificate value)?  $default,){
final _that = this;
switch (_that) {
case _JewelleryCertificate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String productId, @HiveField(3)  String? huid, @HiveField(4)  CertificateType type, @HiveField(5)  String issuer, @HiveField(6)  DateTime issueDate, @HiveField(7)  DateTime? expiryDate, @HiveField(8)  String? documentUrl, @HiveField(9)  int valuationPaisa, @HiveField(10)  String? notes, @HiveField(11)  bool isActive, @HiveField(12)  DateTime createdAt, @HiveField(13)  bool synced, @HiveField(14)  DateTime? lastSyncedAt, @HiveField(15)  String? pendingOperation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JewelleryCertificate() when $default != null:
return $default(_that.id,_that.tenantId,_that.productId,_that.huid,_that.type,_that.issuer,_that.issueDate,_that.expiryDate,_that.documentUrl,_that.valuationPaisa,_that.notes,_that.isActive,_that.createdAt,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String productId, @HiveField(3)  String? huid, @HiveField(4)  CertificateType type, @HiveField(5)  String issuer, @HiveField(6)  DateTime issueDate, @HiveField(7)  DateTime? expiryDate, @HiveField(8)  String? documentUrl, @HiveField(9)  int valuationPaisa, @HiveField(10)  String? notes, @HiveField(11)  bool isActive, @HiveField(12)  DateTime createdAt, @HiveField(13)  bool synced, @HiveField(14)  DateTime? lastSyncedAt, @HiveField(15)  String? pendingOperation)  $default,) {final _that = this;
switch (_that) {
case _JewelleryCertificate():
return $default(_that.id,_that.tenantId,_that.productId,_that.huid,_that.type,_that.issuer,_that.issueDate,_that.expiryDate,_that.documentUrl,_that.valuationPaisa,_that.notes,_that.isActive,_that.createdAt,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String productId, @HiveField(3)  String? huid, @HiveField(4)  CertificateType type, @HiveField(5)  String issuer, @HiveField(6)  DateTime issueDate, @HiveField(7)  DateTime? expiryDate, @HiveField(8)  String? documentUrl, @HiveField(9)  int valuationPaisa, @HiveField(10)  String? notes, @HiveField(11)  bool isActive, @HiveField(12)  DateTime createdAt, @HiveField(13)  bool synced, @HiveField(14)  DateTime? lastSyncedAt, @HiveField(15)  String? pendingOperation)?  $default,) {final _that = this;
switch (_that) {
case _JewelleryCertificate() when $default != null:
return $default(_that.id,_that.tenantId,_that.productId,_that.huid,_that.type,_that.issuer,_that.issueDate,_that.expiryDate,_that.documentUrl,_that.valuationPaisa,_that.notes,_that.isActive,_that.createdAt,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 71)
class _JewelleryCertificate extends JewelleryCertificate {
  const _JewelleryCertificate({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.productId, @HiveField(3) this.huid, @HiveField(4) required this.type, @HiveField(5) required this.issuer, @HiveField(6) required this.issueDate, @HiveField(7) this.expiryDate, @HiveField(8) this.documentUrl, @HiveField(9) this.valuationPaisa = 0, @HiveField(10) this.notes, @HiveField(11) this.isActive = true, @HiveField(12) required this.createdAt, @HiveField(13) this.synced = true, @HiveField(14) this.lastSyncedAt, @HiveField(15) this.pendingOperation}): super._();
  factory _JewelleryCertificate.fromJson(Map<String, dynamic> json) => _$JewelleryCertificateFromJson(json);

// Core identifiers (RID pattern: {tenantId}-{timestamp_ms}-{uuid_v4_short})
@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
// Product/HUID link
@override@HiveField(2) final  String productId;
@override@HiveField(3) final  String? huid;
// Optional BIS HUID link
// Certificate details
@override@HiveField(4) final  CertificateType type;
@override@HiveField(5) final  String issuer;
// Issuing authority/organization
@override@HiveField(6) final  DateTime issueDate;
@override@HiveField(7) final  DateTime? expiryDate;
// Document reference
@override@HiveField(8) final  String? documentUrl;
// URL/path to certificate document
// Valuation in integer paise (Requirement 1.1: integer paise for money)
@override@JsonKey()@HiveField(9) final  int valuationPaisa;
// Additional info
@override@HiveField(10) final  String? notes;
@override@JsonKey()@HiveField(11) final  bool isActive;
// Metadata
@override@HiveField(12) final  DateTime createdAt;
// Sync tracking
@override@JsonKey()@HiveField(13) final  bool synced;
@override@HiveField(14) final  DateTime? lastSyncedAt;
@override@HiveField(15) final  String? pendingOperation;

/// Create a copy of JewelleryCertificate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JewelleryCertificateCopyWith<_JewelleryCertificate> get copyWith => __$JewelleryCertificateCopyWithImpl<_JewelleryCertificate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JewelleryCertificateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JewelleryCertificate&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.huid, huid) || other.huid == huid)&&(identical(other.type, type) || other.type == type)&&(identical(other.issuer, issuer) || other.issuer == issuer)&&(identical(other.issueDate, issueDate) || other.issueDate == issueDate)&&(identical(other.expiryDate, expiryDate) || other.expiryDate == expiryDate)&&(identical(other.documentUrl, documentUrl) || other.documentUrl == documentUrl)&&(identical(other.valuationPaisa, valuationPaisa) || other.valuationPaisa == valuationPaisa)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tenantId,productId,huid,type,issuer,issueDate,expiryDate,documentUrl,valuationPaisa,notes,isActive,createdAt,synced,lastSyncedAt,pendingOperation);

@override
String toString() {
  return 'JewelleryCertificate(id: $id, tenantId: $tenantId, productId: $productId, huid: $huid, type: $type, issuer: $issuer, issueDate: $issueDate, expiryDate: $expiryDate, documentUrl: $documentUrl, valuationPaisa: $valuationPaisa, notes: $notes, isActive: $isActive, createdAt: $createdAt, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class _$JewelleryCertificateCopyWith<$Res> implements $JewelleryCertificateCopyWith<$Res> {
  factory _$JewelleryCertificateCopyWith(_JewelleryCertificate value, $Res Function(_JewelleryCertificate) _then) = __$JewelleryCertificateCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String productId,@HiveField(3) String? huid,@HiveField(4) CertificateType type,@HiveField(5) String issuer,@HiveField(6) DateTime issueDate,@HiveField(7) DateTime? expiryDate,@HiveField(8) String? documentUrl,@HiveField(9) int valuationPaisa,@HiveField(10) String? notes,@HiveField(11) bool isActive,@HiveField(12) DateTime createdAt,@HiveField(13) bool synced,@HiveField(14) DateTime? lastSyncedAt,@HiveField(15) String? pendingOperation
});




}
/// @nodoc
class __$JewelleryCertificateCopyWithImpl<$Res>
    implements _$JewelleryCertificateCopyWith<$Res> {
  __$JewelleryCertificateCopyWithImpl(this._self, this._then);

  final _JewelleryCertificate _self;
  final $Res Function(_JewelleryCertificate) _then;

/// Create a copy of JewelleryCertificate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? productId = null,Object? huid = freezed,Object? type = null,Object? issuer = null,Object? issueDate = null,Object? expiryDate = freezed,Object? documentUrl = freezed,Object? valuationPaisa = null,Object? notes = freezed,Object? isActive = null,Object? createdAt = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_JewelleryCertificate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String,huid: freezed == huid ? _self.huid : huid // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CertificateType,issuer: null == issuer ? _self.issuer : issuer // ignore: cast_nullable_to_non_nullable
as String,issueDate: null == issueDate ? _self.issueDate : issueDate // ignore: cast_nullable_to_non_nullable
as DateTime,expiryDate: freezed == expiryDate ? _self.expiryDate : expiryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,documentUrl: freezed == documentUrl ? _self.documentUrl : documentUrl // ignore: cast_nullable_to_non_nullable
as String?,valuationPaisa: null == valuationPaisa ? _self.valuationPaisa : valuationPaisa // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
