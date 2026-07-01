// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'making_charges_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TieredRate {

@HiveField(0) double get minWeightGrams;@HiveField(1) double get maxWeightGrams;@HiveField(2) int get ratePaisaPerGram;@HiveField(3) String? get description;
/// Create a copy of TieredRate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TieredRateCopyWith<TieredRate> get copyWith => _$TieredRateCopyWithImpl<TieredRate>(this as TieredRate, _$identity);

  /// Serializes this TieredRate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TieredRate&&(identical(other.minWeightGrams, minWeightGrams) || other.minWeightGrams == minWeightGrams)&&(identical(other.maxWeightGrams, maxWeightGrams) || other.maxWeightGrams == maxWeightGrams)&&(identical(other.ratePaisaPerGram, ratePaisaPerGram) || other.ratePaisaPerGram == ratePaisaPerGram)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minWeightGrams,maxWeightGrams,ratePaisaPerGram,description);

@override
String toString() {
  return 'TieredRate(minWeightGrams: $minWeightGrams, maxWeightGrams: $maxWeightGrams, ratePaisaPerGram: $ratePaisaPerGram, description: $description)';
}


}

/// @nodoc
abstract mixin class $TieredRateCopyWith<$Res>  {
  factory $TieredRateCopyWith(TieredRate value, $Res Function(TieredRate) _then) = _$TieredRateCopyWithImpl;
@useResult
$Res call({
@HiveField(0) double minWeightGrams,@HiveField(1) double maxWeightGrams,@HiveField(2) int ratePaisaPerGram,@HiveField(3) String? description
});




}
/// @nodoc
class _$TieredRateCopyWithImpl<$Res>
    implements $TieredRateCopyWith<$Res> {
  _$TieredRateCopyWithImpl(this._self, this._then);

  final TieredRate _self;
  final $Res Function(TieredRate) _then;

/// Create a copy of TieredRate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minWeightGrams = null,Object? maxWeightGrams = null,Object? ratePaisaPerGram = null,Object? description = freezed,}) {
  return _then(_self.copyWith(
minWeightGrams: null == minWeightGrams ? _self.minWeightGrams : minWeightGrams // ignore: cast_nullable_to_non_nullable
as double,maxWeightGrams: null == maxWeightGrams ? _self.maxWeightGrams : maxWeightGrams // ignore: cast_nullable_to_non_nullable
as double,ratePaisaPerGram: null == ratePaisaPerGram ? _self.ratePaisaPerGram : ratePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TieredRate].
extension TieredRatePatterns on TieredRate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TieredRate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TieredRate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TieredRate value)  $default,){
final _that = this;
switch (_that) {
case _TieredRate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TieredRate value)?  $default,){
final _that = this;
switch (_that) {
case _TieredRate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  double minWeightGrams, @HiveField(1)  double maxWeightGrams, @HiveField(2)  int ratePaisaPerGram, @HiveField(3)  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TieredRate() when $default != null:
return $default(_that.minWeightGrams,_that.maxWeightGrams,_that.ratePaisaPerGram,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  double minWeightGrams, @HiveField(1)  double maxWeightGrams, @HiveField(2)  int ratePaisaPerGram, @HiveField(3)  String? description)  $default,) {final _that = this;
switch (_that) {
case _TieredRate():
return $default(_that.minWeightGrams,_that.maxWeightGrams,_that.ratePaisaPerGram,_that.description);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  double minWeightGrams, @HiveField(1)  double maxWeightGrams, @HiveField(2)  int ratePaisaPerGram, @HiveField(3)  String? description)?  $default,) {final _that = this;
switch (_that) {
case _TieredRate() when $default != null:
return $default(_that.minWeightGrams,_that.maxWeightGrams,_that.ratePaisaPerGram,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 59)
class _TieredRate extends TieredRate {
  const _TieredRate({@HiveField(0) required this.minWeightGrams, @HiveField(1) required this.maxWeightGrams, @HiveField(2) required this.ratePaisaPerGram, @HiveField(3) this.description}): super._();
  factory _TieredRate.fromJson(Map<String, dynamic> json) => _$TieredRateFromJson(json);

@override@HiveField(0) final  double minWeightGrams;
@override@HiveField(1) final  double maxWeightGrams;
@override@HiveField(2) final  int ratePaisaPerGram;
@override@HiveField(3) final  String? description;

/// Create a copy of TieredRate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TieredRateCopyWith<_TieredRate> get copyWith => __$TieredRateCopyWithImpl<_TieredRate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TieredRateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TieredRate&&(identical(other.minWeightGrams, minWeightGrams) || other.minWeightGrams == minWeightGrams)&&(identical(other.maxWeightGrams, maxWeightGrams) || other.maxWeightGrams == maxWeightGrams)&&(identical(other.ratePaisaPerGram, ratePaisaPerGram) || other.ratePaisaPerGram == ratePaisaPerGram)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minWeightGrams,maxWeightGrams,ratePaisaPerGram,description);

@override
String toString() {
  return 'TieredRate(minWeightGrams: $minWeightGrams, maxWeightGrams: $maxWeightGrams, ratePaisaPerGram: $ratePaisaPerGram, description: $description)';
}


}

/// @nodoc
abstract mixin class _$TieredRateCopyWith<$Res> implements $TieredRateCopyWith<$Res> {
  factory _$TieredRateCopyWith(_TieredRate value, $Res Function(_TieredRate) _then) = __$TieredRateCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) double minWeightGrams,@HiveField(1) double maxWeightGrams,@HiveField(2) int ratePaisaPerGram,@HiveField(3) String? description
});




}
/// @nodoc
class __$TieredRateCopyWithImpl<$Res>
    implements _$TieredRateCopyWith<$Res> {
  __$TieredRateCopyWithImpl(this._self, this._then);

  final _TieredRate _self;
  final $Res Function(_TieredRate) _then;

/// Create a copy of TieredRate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minWeightGrams = null,Object? maxWeightGrams = null,Object? ratePaisaPerGram = null,Object? description = freezed,}) {
  return _then(_TieredRate(
minWeightGrams: null == minWeightGrams ? _self.minWeightGrams : minWeightGrams // ignore: cast_nullable_to_non_nullable
as double,maxWeightGrams: null == maxWeightGrams ? _self.maxWeightGrams : maxWeightGrams // ignore: cast_nullable_to_non_nullable
as double,ratePaisaPerGram: null == ratePaisaPerGram ? _self.ratePaisaPerGram : ratePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ComplexityRate {

@HiveField(0) JewelleryComplexity get complexity;@HiveField(1) int get ratePaisaPerGram;@HiveField(2) String? get description;
/// Create a copy of ComplexityRate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComplexityRateCopyWith<ComplexityRate> get copyWith => _$ComplexityRateCopyWithImpl<ComplexityRate>(this as ComplexityRate, _$identity);

  /// Serializes this ComplexityRate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComplexityRate&&(identical(other.complexity, complexity) || other.complexity == complexity)&&(identical(other.ratePaisaPerGram, ratePaisaPerGram) || other.ratePaisaPerGram == ratePaisaPerGram)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,complexity,ratePaisaPerGram,description);

@override
String toString() {
  return 'ComplexityRate(complexity: $complexity, ratePaisaPerGram: $ratePaisaPerGram, description: $description)';
}


}

/// @nodoc
abstract mixin class $ComplexityRateCopyWith<$Res>  {
  factory $ComplexityRateCopyWith(ComplexityRate value, $Res Function(ComplexityRate) _then) = _$ComplexityRateCopyWithImpl;
@useResult
$Res call({
@HiveField(0) JewelleryComplexity complexity,@HiveField(1) int ratePaisaPerGram,@HiveField(2) String? description
});




}
/// @nodoc
class _$ComplexityRateCopyWithImpl<$Res>
    implements $ComplexityRateCopyWith<$Res> {
  _$ComplexityRateCopyWithImpl(this._self, this._then);

  final ComplexityRate _self;
  final $Res Function(ComplexityRate) _then;

/// Create a copy of ComplexityRate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? complexity = null,Object? ratePaisaPerGram = null,Object? description = freezed,}) {
  return _then(_self.copyWith(
complexity: null == complexity ? _self.complexity : complexity // ignore: cast_nullable_to_non_nullable
as JewelleryComplexity,ratePaisaPerGram: null == ratePaisaPerGram ? _self.ratePaisaPerGram : ratePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ComplexityRate].
extension ComplexityRatePatterns on ComplexityRate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ComplexityRate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ComplexityRate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ComplexityRate value)  $default,){
final _that = this;
switch (_that) {
case _ComplexityRate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ComplexityRate value)?  $default,){
final _that = this;
switch (_that) {
case _ComplexityRate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  JewelleryComplexity complexity, @HiveField(1)  int ratePaisaPerGram, @HiveField(2)  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ComplexityRate() when $default != null:
return $default(_that.complexity,_that.ratePaisaPerGram,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  JewelleryComplexity complexity, @HiveField(1)  int ratePaisaPerGram, @HiveField(2)  String? description)  $default,) {final _that = this;
switch (_that) {
case _ComplexityRate():
return $default(_that.complexity,_that.ratePaisaPerGram,_that.description);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  JewelleryComplexity complexity, @HiveField(1)  int ratePaisaPerGram, @HiveField(2)  String? description)?  $default,) {final _that = this;
switch (_that) {
case _ComplexityRate() when $default != null:
return $default(_that.complexity,_that.ratePaisaPerGram,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 60)
class _ComplexityRate extends ComplexityRate {
  const _ComplexityRate({@HiveField(0) required this.complexity, @HiveField(1) required this.ratePaisaPerGram, @HiveField(2) this.description}): super._();
  factory _ComplexityRate.fromJson(Map<String, dynamic> json) => _$ComplexityRateFromJson(json);

@override@HiveField(0) final  JewelleryComplexity complexity;
@override@HiveField(1) final  int ratePaisaPerGram;
@override@HiveField(2) final  String? description;

/// Create a copy of ComplexityRate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComplexityRateCopyWith<_ComplexityRate> get copyWith => __$ComplexityRateCopyWithImpl<_ComplexityRate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ComplexityRateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComplexityRate&&(identical(other.complexity, complexity) || other.complexity == complexity)&&(identical(other.ratePaisaPerGram, ratePaisaPerGram) || other.ratePaisaPerGram == ratePaisaPerGram)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,complexity,ratePaisaPerGram,description);

@override
String toString() {
  return 'ComplexityRate(complexity: $complexity, ratePaisaPerGram: $ratePaisaPerGram, description: $description)';
}


}

/// @nodoc
abstract mixin class _$ComplexityRateCopyWith<$Res> implements $ComplexityRateCopyWith<$Res> {
  factory _$ComplexityRateCopyWith(_ComplexityRate value, $Res Function(_ComplexityRate) _then) = __$ComplexityRateCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) JewelleryComplexity complexity,@HiveField(1) int ratePaisaPerGram,@HiveField(2) String? description
});




}
/// @nodoc
class __$ComplexityRateCopyWithImpl<$Res>
    implements _$ComplexityRateCopyWith<$Res> {
  __$ComplexityRateCopyWithImpl(this._self, this._then);

  final _ComplexityRate _self;
  final $Res Function(_ComplexityRate) _then;

/// Create a copy of ComplexityRate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? complexity = null,Object? ratePaisaPerGram = null,Object? description = freezed,}) {
  return _then(_ComplexityRate(
complexity: null == complexity ? _self.complexity : complexity // ignore: cast_nullable_to_non_nullable
as JewelleryComplexity,ratePaisaPerGram: null == ratePaisaPerGram ? _self.ratePaisaPerGram : ratePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MakingChargesConfig {

// Core identifiers
@HiveField(0) String get id;@HiveField(1) String get tenantId;// Configuration name
@HiveField(2) String get name;@HiveField(3) String? get description;// Charge type
@HiveField(4) MakingChargeType get type;// For perGram type
@HiveField(5) int? get ratePaisaPerGram;// For percentage type
@HiveField(6) double? get percentageOfMetalValue;// For fixed type
@HiveField(7) int? get fixedAmountPaisa;// For tiered type
@HiveField(8) List<TieredRate>? get tieredRates;// For complexity type
@HiveField(9) List<ComplexityRate>? get complexityRates;// For combination type
@HiveField(10) int? get baseAmountPaisa;@HiveField(11) double? get additionalPercentage;// Common settings
@HiveField(12) int? get minimumChargePaisa;@HiveField(13) int? get maximumChargePaisa;@HiveField(14) bool get applyOnWastage;@HiveField(15) bool get includeStoneWeight;// Stone settings (if making charges apply to stones)
@HiveField(16) int? get stoneMakingChargePaisa;@HiveField(17) double get stoneWeightPercentage;// % of total weight considered for stone making charges
// Metadata
@HiveField(18) bool get isActive;@HiveField(19) DateTime get createdAt;@HiveField(20) DateTime get updatedAt;// Sync tracking
@HiveField(21) bool get synced;@HiveField(22) DateTime? get lastSyncedAt;
/// Create a copy of MakingChargesConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MakingChargesConfigCopyWith<MakingChargesConfig> get copyWith => _$MakingChargesConfigCopyWithImpl<MakingChargesConfig>(this as MakingChargesConfig, _$identity);

  /// Serializes this MakingChargesConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MakingChargesConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.ratePaisaPerGram, ratePaisaPerGram) || other.ratePaisaPerGram == ratePaisaPerGram)&&(identical(other.percentageOfMetalValue, percentageOfMetalValue) || other.percentageOfMetalValue == percentageOfMetalValue)&&(identical(other.fixedAmountPaisa, fixedAmountPaisa) || other.fixedAmountPaisa == fixedAmountPaisa)&&const DeepCollectionEquality().equals(other.tieredRates, tieredRates)&&const DeepCollectionEquality().equals(other.complexityRates, complexityRates)&&(identical(other.baseAmountPaisa, baseAmountPaisa) || other.baseAmountPaisa == baseAmountPaisa)&&(identical(other.additionalPercentage, additionalPercentage) || other.additionalPercentage == additionalPercentage)&&(identical(other.minimumChargePaisa, minimumChargePaisa) || other.minimumChargePaisa == minimumChargePaisa)&&(identical(other.maximumChargePaisa, maximumChargePaisa) || other.maximumChargePaisa == maximumChargePaisa)&&(identical(other.applyOnWastage, applyOnWastage) || other.applyOnWastage == applyOnWastage)&&(identical(other.includeStoneWeight, includeStoneWeight) || other.includeStoneWeight == includeStoneWeight)&&(identical(other.stoneMakingChargePaisa, stoneMakingChargePaisa) || other.stoneMakingChargePaisa == stoneMakingChargePaisa)&&(identical(other.stoneWeightPercentage, stoneWeightPercentage) || other.stoneWeightPercentage == stoneWeightPercentage)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,name,description,type,ratePaisaPerGram,percentageOfMetalValue,fixedAmountPaisa,const DeepCollectionEquality().hash(tieredRates),const DeepCollectionEquality().hash(complexityRates),baseAmountPaisa,additionalPercentage,minimumChargePaisa,maximumChargePaisa,applyOnWastage,includeStoneWeight,stoneMakingChargePaisa,stoneWeightPercentage,isActive,createdAt,updatedAt,synced,lastSyncedAt]);

@override
String toString() {
  return 'MakingChargesConfig(id: $id, tenantId: $tenantId, name: $name, description: $description, type: $type, ratePaisaPerGram: $ratePaisaPerGram, percentageOfMetalValue: $percentageOfMetalValue, fixedAmountPaisa: $fixedAmountPaisa, tieredRates: $tieredRates, complexityRates: $complexityRates, baseAmountPaisa: $baseAmountPaisa, additionalPercentage: $additionalPercentage, minimumChargePaisa: $minimumChargePaisa, maximumChargePaisa: $maximumChargePaisa, applyOnWastage: $applyOnWastage, includeStoneWeight: $includeStoneWeight, stoneMakingChargePaisa: $stoneMakingChargePaisa, stoneWeightPercentage: $stoneWeightPercentage, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, synced: $synced, lastSyncedAt: $lastSyncedAt)';
}


}

/// @nodoc
abstract mixin class $MakingChargesConfigCopyWith<$Res>  {
  factory $MakingChargesConfigCopyWith(MakingChargesConfig value, $Res Function(MakingChargesConfig) _then) = _$MakingChargesConfigCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String name,@HiveField(3) String? description,@HiveField(4) MakingChargeType type,@HiveField(5) int? ratePaisaPerGram,@HiveField(6) double? percentageOfMetalValue,@HiveField(7) int? fixedAmountPaisa,@HiveField(8) List<TieredRate>? tieredRates,@HiveField(9) List<ComplexityRate>? complexityRates,@HiveField(10) int? baseAmountPaisa,@HiveField(11) double? additionalPercentage,@HiveField(12) int? minimumChargePaisa,@HiveField(13) int? maximumChargePaisa,@HiveField(14) bool applyOnWastage,@HiveField(15) bool includeStoneWeight,@HiveField(16) int? stoneMakingChargePaisa,@HiveField(17) double stoneWeightPercentage,@HiveField(18) bool isActive,@HiveField(19) DateTime createdAt,@HiveField(20) DateTime updatedAt,@HiveField(21) bool synced,@HiveField(22) DateTime? lastSyncedAt
});




}
/// @nodoc
class _$MakingChargesConfigCopyWithImpl<$Res>
    implements $MakingChargesConfigCopyWith<$Res> {
  _$MakingChargesConfigCopyWithImpl(this._self, this._then);

  final MakingChargesConfig _self;
  final $Res Function(MakingChargesConfig) _then;

/// Create a copy of MakingChargesConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? name = null,Object? description = freezed,Object? type = null,Object? ratePaisaPerGram = freezed,Object? percentageOfMetalValue = freezed,Object? fixedAmountPaisa = freezed,Object? tieredRates = freezed,Object? complexityRates = freezed,Object? baseAmountPaisa = freezed,Object? additionalPercentage = freezed,Object? minimumChargePaisa = freezed,Object? maximumChargePaisa = freezed,Object? applyOnWastage = null,Object? includeStoneWeight = null,Object? stoneMakingChargePaisa = freezed,Object? stoneWeightPercentage = null,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,Object? synced = null,Object? lastSyncedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MakingChargeType,ratePaisaPerGram: freezed == ratePaisaPerGram ? _self.ratePaisaPerGram : ratePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int?,percentageOfMetalValue: freezed == percentageOfMetalValue ? _self.percentageOfMetalValue : percentageOfMetalValue // ignore: cast_nullable_to_non_nullable
as double?,fixedAmountPaisa: freezed == fixedAmountPaisa ? _self.fixedAmountPaisa : fixedAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,tieredRates: freezed == tieredRates ? _self.tieredRates : tieredRates // ignore: cast_nullable_to_non_nullable
as List<TieredRate>?,complexityRates: freezed == complexityRates ? _self.complexityRates : complexityRates // ignore: cast_nullable_to_non_nullable
as List<ComplexityRate>?,baseAmountPaisa: freezed == baseAmountPaisa ? _self.baseAmountPaisa : baseAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,additionalPercentage: freezed == additionalPercentage ? _self.additionalPercentage : additionalPercentage // ignore: cast_nullable_to_non_nullable
as double?,minimumChargePaisa: freezed == minimumChargePaisa ? _self.minimumChargePaisa : minimumChargePaisa // ignore: cast_nullable_to_non_nullable
as int?,maximumChargePaisa: freezed == maximumChargePaisa ? _self.maximumChargePaisa : maximumChargePaisa // ignore: cast_nullable_to_non_nullable
as int?,applyOnWastage: null == applyOnWastage ? _self.applyOnWastage : applyOnWastage // ignore: cast_nullable_to_non_nullable
as bool,includeStoneWeight: null == includeStoneWeight ? _self.includeStoneWeight : includeStoneWeight // ignore: cast_nullable_to_non_nullable
as bool,stoneMakingChargePaisa: freezed == stoneMakingChargePaisa ? _self.stoneMakingChargePaisa : stoneMakingChargePaisa // ignore: cast_nullable_to_non_nullable
as int?,stoneWeightPercentage: null == stoneWeightPercentage ? _self.stoneWeightPercentage : stoneWeightPercentage // ignore: cast_nullable_to_non_nullable
as double,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [MakingChargesConfig].
extension MakingChargesConfigPatterns on MakingChargesConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MakingChargesConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MakingChargesConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MakingChargesConfig value)  $default,){
final _that = this;
switch (_that) {
case _MakingChargesConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MakingChargesConfig value)?  $default,){
final _that = this;
switch (_that) {
case _MakingChargesConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String name, @HiveField(3)  String? description, @HiveField(4)  MakingChargeType type, @HiveField(5)  int? ratePaisaPerGram, @HiveField(6)  double? percentageOfMetalValue, @HiveField(7)  int? fixedAmountPaisa, @HiveField(8)  List<TieredRate>? tieredRates, @HiveField(9)  List<ComplexityRate>? complexityRates, @HiveField(10)  int? baseAmountPaisa, @HiveField(11)  double? additionalPercentage, @HiveField(12)  int? minimumChargePaisa, @HiveField(13)  int? maximumChargePaisa, @HiveField(14)  bool applyOnWastage, @HiveField(15)  bool includeStoneWeight, @HiveField(16)  int? stoneMakingChargePaisa, @HiveField(17)  double stoneWeightPercentage, @HiveField(18)  bool isActive, @HiveField(19)  DateTime createdAt, @HiveField(20)  DateTime updatedAt, @HiveField(21)  bool synced, @HiveField(22)  DateTime? lastSyncedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MakingChargesConfig() when $default != null:
return $default(_that.id,_that.tenantId,_that.name,_that.description,_that.type,_that.ratePaisaPerGram,_that.percentageOfMetalValue,_that.fixedAmountPaisa,_that.tieredRates,_that.complexityRates,_that.baseAmountPaisa,_that.additionalPercentage,_that.minimumChargePaisa,_that.maximumChargePaisa,_that.applyOnWastage,_that.includeStoneWeight,_that.stoneMakingChargePaisa,_that.stoneWeightPercentage,_that.isActive,_that.createdAt,_that.updatedAt,_that.synced,_that.lastSyncedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String name, @HiveField(3)  String? description, @HiveField(4)  MakingChargeType type, @HiveField(5)  int? ratePaisaPerGram, @HiveField(6)  double? percentageOfMetalValue, @HiveField(7)  int? fixedAmountPaisa, @HiveField(8)  List<TieredRate>? tieredRates, @HiveField(9)  List<ComplexityRate>? complexityRates, @HiveField(10)  int? baseAmountPaisa, @HiveField(11)  double? additionalPercentage, @HiveField(12)  int? minimumChargePaisa, @HiveField(13)  int? maximumChargePaisa, @HiveField(14)  bool applyOnWastage, @HiveField(15)  bool includeStoneWeight, @HiveField(16)  int? stoneMakingChargePaisa, @HiveField(17)  double stoneWeightPercentage, @HiveField(18)  bool isActive, @HiveField(19)  DateTime createdAt, @HiveField(20)  DateTime updatedAt, @HiveField(21)  bool synced, @HiveField(22)  DateTime? lastSyncedAt)  $default,) {final _that = this;
switch (_that) {
case _MakingChargesConfig():
return $default(_that.id,_that.tenantId,_that.name,_that.description,_that.type,_that.ratePaisaPerGram,_that.percentageOfMetalValue,_that.fixedAmountPaisa,_that.tieredRates,_that.complexityRates,_that.baseAmountPaisa,_that.additionalPercentage,_that.minimumChargePaisa,_that.maximumChargePaisa,_that.applyOnWastage,_that.includeStoneWeight,_that.stoneMakingChargePaisa,_that.stoneWeightPercentage,_that.isActive,_that.createdAt,_that.updatedAt,_that.synced,_that.lastSyncedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String name, @HiveField(3)  String? description, @HiveField(4)  MakingChargeType type, @HiveField(5)  int? ratePaisaPerGram, @HiveField(6)  double? percentageOfMetalValue, @HiveField(7)  int? fixedAmountPaisa, @HiveField(8)  List<TieredRate>? tieredRates, @HiveField(9)  List<ComplexityRate>? complexityRates, @HiveField(10)  int? baseAmountPaisa, @HiveField(11)  double? additionalPercentage, @HiveField(12)  int? minimumChargePaisa, @HiveField(13)  int? maximumChargePaisa, @HiveField(14)  bool applyOnWastage, @HiveField(15)  bool includeStoneWeight, @HiveField(16)  int? stoneMakingChargePaisa, @HiveField(17)  double stoneWeightPercentage, @HiveField(18)  bool isActive, @HiveField(19)  DateTime createdAt, @HiveField(20)  DateTime updatedAt, @HiveField(21)  bool synced, @HiveField(22)  DateTime? lastSyncedAt)?  $default,) {final _that = this;
switch (_that) {
case _MakingChargesConfig() when $default != null:
return $default(_that.id,_that.tenantId,_that.name,_that.description,_that.type,_that.ratePaisaPerGram,_that.percentageOfMetalValue,_that.fixedAmountPaisa,_that.tieredRates,_that.complexityRates,_that.baseAmountPaisa,_that.additionalPercentage,_that.minimumChargePaisa,_that.maximumChargePaisa,_that.applyOnWastage,_that.includeStoneWeight,_that.stoneMakingChargePaisa,_that.stoneWeightPercentage,_that.isActive,_that.createdAt,_that.updatedAt,_that.synced,_that.lastSyncedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 61)
class _MakingChargesConfig extends MakingChargesConfig {
  const _MakingChargesConfig({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.name, @HiveField(3) this.description, @HiveField(4) this.type = MakingChargeType.perGram, @HiveField(5) this.ratePaisaPerGram, @HiveField(6) this.percentageOfMetalValue, @HiveField(7) this.fixedAmountPaisa, @HiveField(8) final  List<TieredRate>? tieredRates, @HiveField(9) final  List<ComplexityRate>? complexityRates, @HiveField(10) this.baseAmountPaisa, @HiveField(11) this.additionalPercentage, @HiveField(12) this.minimumChargePaisa, @HiveField(13) this.maximumChargePaisa, @HiveField(14) this.applyOnWastage = false, @HiveField(15) this.includeStoneWeight = false, @HiveField(16) this.stoneMakingChargePaisa, @HiveField(17) this.stoneWeightPercentage = 0, @HiveField(18) this.isActive = true, @HiveField(19) required this.createdAt, @HiveField(20) required this.updatedAt, @HiveField(21) this.synced = true, @HiveField(22) this.lastSyncedAt}): _tieredRates = tieredRates,_complexityRates = complexityRates,super._();
  factory _MakingChargesConfig.fromJson(Map<String, dynamic> json) => _$MakingChargesConfigFromJson(json);

// Core identifiers
@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
// Configuration name
@override@HiveField(2) final  String name;
@override@HiveField(3) final  String? description;
// Charge type
@override@JsonKey()@HiveField(4) final  MakingChargeType type;
// For perGram type
@override@HiveField(5) final  int? ratePaisaPerGram;
// For percentage type
@override@HiveField(6) final  double? percentageOfMetalValue;
// For fixed type
@override@HiveField(7) final  int? fixedAmountPaisa;
// For tiered type
 final  List<TieredRate>? _tieredRates;
// For tiered type
@override@HiveField(8) List<TieredRate>? get tieredRates {
  final value = _tieredRates;
  if (value == null) return null;
  if (_tieredRates is EqualUnmodifiableListView) return _tieredRates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// For complexity type
 final  List<ComplexityRate>? _complexityRates;
// For complexity type
@override@HiveField(9) List<ComplexityRate>? get complexityRates {
  final value = _complexityRates;
  if (value == null) return null;
  if (_complexityRates is EqualUnmodifiableListView) return _complexityRates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// For combination type
@override@HiveField(10) final  int? baseAmountPaisa;
@override@HiveField(11) final  double? additionalPercentage;
// Common settings
@override@HiveField(12) final  int? minimumChargePaisa;
@override@HiveField(13) final  int? maximumChargePaisa;
@override@JsonKey()@HiveField(14) final  bool applyOnWastage;
@override@JsonKey()@HiveField(15) final  bool includeStoneWeight;
// Stone settings (if making charges apply to stones)
@override@HiveField(16) final  int? stoneMakingChargePaisa;
@override@JsonKey()@HiveField(17) final  double stoneWeightPercentage;
// % of total weight considered for stone making charges
// Metadata
@override@JsonKey()@HiveField(18) final  bool isActive;
@override@HiveField(19) final  DateTime createdAt;
@override@HiveField(20) final  DateTime updatedAt;
// Sync tracking
@override@JsonKey()@HiveField(21) final  bool synced;
@override@HiveField(22) final  DateTime? lastSyncedAt;

/// Create a copy of MakingChargesConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MakingChargesConfigCopyWith<_MakingChargesConfig> get copyWith => __$MakingChargesConfigCopyWithImpl<_MakingChargesConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MakingChargesConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MakingChargesConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.ratePaisaPerGram, ratePaisaPerGram) || other.ratePaisaPerGram == ratePaisaPerGram)&&(identical(other.percentageOfMetalValue, percentageOfMetalValue) || other.percentageOfMetalValue == percentageOfMetalValue)&&(identical(other.fixedAmountPaisa, fixedAmountPaisa) || other.fixedAmountPaisa == fixedAmountPaisa)&&const DeepCollectionEquality().equals(other._tieredRates, _tieredRates)&&const DeepCollectionEquality().equals(other._complexityRates, _complexityRates)&&(identical(other.baseAmountPaisa, baseAmountPaisa) || other.baseAmountPaisa == baseAmountPaisa)&&(identical(other.additionalPercentage, additionalPercentage) || other.additionalPercentage == additionalPercentage)&&(identical(other.minimumChargePaisa, minimumChargePaisa) || other.minimumChargePaisa == minimumChargePaisa)&&(identical(other.maximumChargePaisa, maximumChargePaisa) || other.maximumChargePaisa == maximumChargePaisa)&&(identical(other.applyOnWastage, applyOnWastage) || other.applyOnWastage == applyOnWastage)&&(identical(other.includeStoneWeight, includeStoneWeight) || other.includeStoneWeight == includeStoneWeight)&&(identical(other.stoneMakingChargePaisa, stoneMakingChargePaisa) || other.stoneMakingChargePaisa == stoneMakingChargePaisa)&&(identical(other.stoneWeightPercentage, stoneWeightPercentage) || other.stoneWeightPercentage == stoneWeightPercentage)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,name,description,type,ratePaisaPerGram,percentageOfMetalValue,fixedAmountPaisa,const DeepCollectionEquality().hash(_tieredRates),const DeepCollectionEquality().hash(_complexityRates),baseAmountPaisa,additionalPercentage,minimumChargePaisa,maximumChargePaisa,applyOnWastage,includeStoneWeight,stoneMakingChargePaisa,stoneWeightPercentage,isActive,createdAt,updatedAt,synced,lastSyncedAt]);

@override
String toString() {
  return 'MakingChargesConfig(id: $id, tenantId: $tenantId, name: $name, description: $description, type: $type, ratePaisaPerGram: $ratePaisaPerGram, percentageOfMetalValue: $percentageOfMetalValue, fixedAmountPaisa: $fixedAmountPaisa, tieredRates: $tieredRates, complexityRates: $complexityRates, baseAmountPaisa: $baseAmountPaisa, additionalPercentage: $additionalPercentage, minimumChargePaisa: $minimumChargePaisa, maximumChargePaisa: $maximumChargePaisa, applyOnWastage: $applyOnWastage, includeStoneWeight: $includeStoneWeight, stoneMakingChargePaisa: $stoneMakingChargePaisa, stoneWeightPercentage: $stoneWeightPercentage, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, synced: $synced, lastSyncedAt: $lastSyncedAt)';
}


}

/// @nodoc
abstract mixin class _$MakingChargesConfigCopyWith<$Res> implements $MakingChargesConfigCopyWith<$Res> {
  factory _$MakingChargesConfigCopyWith(_MakingChargesConfig value, $Res Function(_MakingChargesConfig) _then) = __$MakingChargesConfigCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String name,@HiveField(3) String? description,@HiveField(4) MakingChargeType type,@HiveField(5) int? ratePaisaPerGram,@HiveField(6) double? percentageOfMetalValue,@HiveField(7) int? fixedAmountPaisa,@HiveField(8) List<TieredRate>? tieredRates,@HiveField(9) List<ComplexityRate>? complexityRates,@HiveField(10) int? baseAmountPaisa,@HiveField(11) double? additionalPercentage,@HiveField(12) int? minimumChargePaisa,@HiveField(13) int? maximumChargePaisa,@HiveField(14) bool applyOnWastage,@HiveField(15) bool includeStoneWeight,@HiveField(16) int? stoneMakingChargePaisa,@HiveField(17) double stoneWeightPercentage,@HiveField(18) bool isActive,@HiveField(19) DateTime createdAt,@HiveField(20) DateTime updatedAt,@HiveField(21) bool synced,@HiveField(22) DateTime? lastSyncedAt
});




}
/// @nodoc
class __$MakingChargesConfigCopyWithImpl<$Res>
    implements _$MakingChargesConfigCopyWith<$Res> {
  __$MakingChargesConfigCopyWithImpl(this._self, this._then);

  final _MakingChargesConfig _self;
  final $Res Function(_MakingChargesConfig) _then;

/// Create a copy of MakingChargesConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? name = null,Object? description = freezed,Object? type = null,Object? ratePaisaPerGram = freezed,Object? percentageOfMetalValue = freezed,Object? fixedAmountPaisa = freezed,Object? tieredRates = freezed,Object? complexityRates = freezed,Object? baseAmountPaisa = freezed,Object? additionalPercentage = freezed,Object? minimumChargePaisa = freezed,Object? maximumChargePaisa = freezed,Object? applyOnWastage = null,Object? includeStoneWeight = null,Object? stoneMakingChargePaisa = freezed,Object? stoneWeightPercentage = null,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,Object? synced = null,Object? lastSyncedAt = freezed,}) {
  return _then(_MakingChargesConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MakingChargeType,ratePaisaPerGram: freezed == ratePaisaPerGram ? _self.ratePaisaPerGram : ratePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int?,percentageOfMetalValue: freezed == percentageOfMetalValue ? _self.percentageOfMetalValue : percentageOfMetalValue // ignore: cast_nullable_to_non_nullable
as double?,fixedAmountPaisa: freezed == fixedAmountPaisa ? _self.fixedAmountPaisa : fixedAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,tieredRates: freezed == tieredRates ? _self._tieredRates : tieredRates // ignore: cast_nullable_to_non_nullable
as List<TieredRate>?,complexityRates: freezed == complexityRates ? _self._complexityRates : complexityRates // ignore: cast_nullable_to_non_nullable
as List<ComplexityRate>?,baseAmountPaisa: freezed == baseAmountPaisa ? _self.baseAmountPaisa : baseAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,additionalPercentage: freezed == additionalPercentage ? _self.additionalPercentage : additionalPercentage // ignore: cast_nullable_to_non_nullable
as double?,minimumChargePaisa: freezed == minimumChargePaisa ? _self.minimumChargePaisa : minimumChargePaisa // ignore: cast_nullable_to_non_nullable
as int?,maximumChargePaisa: freezed == maximumChargePaisa ? _self.maximumChargePaisa : maximumChargePaisa // ignore: cast_nullable_to_non_nullable
as int?,applyOnWastage: null == applyOnWastage ? _self.applyOnWastage : applyOnWastage // ignore: cast_nullable_to_non_nullable
as bool,includeStoneWeight: null == includeStoneWeight ? _self.includeStoneWeight : includeStoneWeight // ignore: cast_nullable_to_non_nullable
as bool,stoneMakingChargePaisa: freezed == stoneMakingChargePaisa ? _self.stoneMakingChargePaisa : stoneMakingChargePaisa // ignore: cast_nullable_to_non_nullable
as int?,stoneWeightPercentage: null == stoneWeightPercentage ? _self.stoneWeightPercentage : stoneWeightPercentage // ignore: cast_nullable_to_non_nullable
as double,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$MakingChargeResult {

 int get totalChargePaisa; int get metalChargePaisa; int? get stoneChargePaisa; double get metalWeightGrams; double? get stoneWeightGrams; int get metalRatePaisaPerGram; MakingChargeType get appliedType; String get calculationBreakdown; List<CalculationStep> get steps; DateTime? get calculatedAt;/// Validation error flag (Requirement 15.2).
/// When true, the result represents a rejected invalid input.
/// The previous valid value should be retained by the caller.
 bool get isError;/// Human-readable validation error message when [isError] is true.
 String? get errorMessage;
/// Create a copy of MakingChargeResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MakingChargeResultCopyWith<MakingChargeResult> get copyWith => _$MakingChargeResultCopyWithImpl<MakingChargeResult>(this as MakingChargeResult, _$identity);

  /// Serializes this MakingChargeResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MakingChargeResult&&(identical(other.totalChargePaisa, totalChargePaisa) || other.totalChargePaisa == totalChargePaisa)&&(identical(other.metalChargePaisa, metalChargePaisa) || other.metalChargePaisa == metalChargePaisa)&&(identical(other.stoneChargePaisa, stoneChargePaisa) || other.stoneChargePaisa == stoneChargePaisa)&&(identical(other.metalWeightGrams, metalWeightGrams) || other.metalWeightGrams == metalWeightGrams)&&(identical(other.stoneWeightGrams, stoneWeightGrams) || other.stoneWeightGrams == stoneWeightGrams)&&(identical(other.metalRatePaisaPerGram, metalRatePaisaPerGram) || other.metalRatePaisaPerGram == metalRatePaisaPerGram)&&(identical(other.appliedType, appliedType) || other.appliedType == appliedType)&&(identical(other.calculationBreakdown, calculationBreakdown) || other.calculationBreakdown == calculationBreakdown)&&const DeepCollectionEquality().equals(other.steps, steps)&&(identical(other.calculatedAt, calculatedAt) || other.calculatedAt == calculatedAt)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalChargePaisa,metalChargePaisa,stoneChargePaisa,metalWeightGrams,stoneWeightGrams,metalRatePaisaPerGram,appliedType,calculationBreakdown,const DeepCollectionEquality().hash(steps),calculatedAt,isError,errorMessage);

@override
String toString() {
  return 'MakingChargeResult(totalChargePaisa: $totalChargePaisa, metalChargePaisa: $metalChargePaisa, stoneChargePaisa: $stoneChargePaisa, metalWeightGrams: $metalWeightGrams, stoneWeightGrams: $stoneWeightGrams, metalRatePaisaPerGram: $metalRatePaisaPerGram, appliedType: $appliedType, calculationBreakdown: $calculationBreakdown, steps: $steps, calculatedAt: $calculatedAt, isError: $isError, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $MakingChargeResultCopyWith<$Res>  {
  factory $MakingChargeResultCopyWith(MakingChargeResult value, $Res Function(MakingChargeResult) _then) = _$MakingChargeResultCopyWithImpl;
@useResult
$Res call({
 int totalChargePaisa, int metalChargePaisa, int? stoneChargePaisa, double metalWeightGrams, double? stoneWeightGrams, int metalRatePaisaPerGram, MakingChargeType appliedType, String calculationBreakdown, List<CalculationStep> steps, DateTime? calculatedAt, bool isError, String? errorMessage
});




}
/// @nodoc
class _$MakingChargeResultCopyWithImpl<$Res>
    implements $MakingChargeResultCopyWith<$Res> {
  _$MakingChargeResultCopyWithImpl(this._self, this._then);

  final MakingChargeResult _self;
  final $Res Function(MakingChargeResult) _then;

/// Create a copy of MakingChargeResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalChargePaisa = null,Object? metalChargePaisa = null,Object? stoneChargePaisa = freezed,Object? metalWeightGrams = null,Object? stoneWeightGrams = freezed,Object? metalRatePaisaPerGram = null,Object? appliedType = null,Object? calculationBreakdown = null,Object? steps = null,Object? calculatedAt = freezed,Object? isError = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
totalChargePaisa: null == totalChargePaisa ? _self.totalChargePaisa : totalChargePaisa // ignore: cast_nullable_to_non_nullable
as int,metalChargePaisa: null == metalChargePaisa ? _self.metalChargePaisa : metalChargePaisa // ignore: cast_nullable_to_non_nullable
as int,stoneChargePaisa: freezed == stoneChargePaisa ? _self.stoneChargePaisa : stoneChargePaisa // ignore: cast_nullable_to_non_nullable
as int?,metalWeightGrams: null == metalWeightGrams ? _self.metalWeightGrams : metalWeightGrams // ignore: cast_nullable_to_non_nullable
as double,stoneWeightGrams: freezed == stoneWeightGrams ? _self.stoneWeightGrams : stoneWeightGrams // ignore: cast_nullable_to_non_nullable
as double?,metalRatePaisaPerGram: null == metalRatePaisaPerGram ? _self.metalRatePaisaPerGram : metalRatePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,appliedType: null == appliedType ? _self.appliedType : appliedType // ignore: cast_nullable_to_non_nullable
as MakingChargeType,calculationBreakdown: null == calculationBreakdown ? _self.calculationBreakdown : calculationBreakdown // ignore: cast_nullable_to_non_nullable
as String,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as List<CalculationStep>,calculatedAt: freezed == calculatedAt ? _self.calculatedAt : calculatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MakingChargeResult].
extension MakingChargeResultPatterns on MakingChargeResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MakingChargeResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MakingChargeResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MakingChargeResult value)  $default,){
final _that = this;
switch (_that) {
case _MakingChargeResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MakingChargeResult value)?  $default,){
final _that = this;
switch (_that) {
case _MakingChargeResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalChargePaisa,  int metalChargePaisa,  int? stoneChargePaisa,  double metalWeightGrams,  double? stoneWeightGrams,  int metalRatePaisaPerGram,  MakingChargeType appliedType,  String calculationBreakdown,  List<CalculationStep> steps,  DateTime? calculatedAt,  bool isError,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MakingChargeResult() when $default != null:
return $default(_that.totalChargePaisa,_that.metalChargePaisa,_that.stoneChargePaisa,_that.metalWeightGrams,_that.stoneWeightGrams,_that.metalRatePaisaPerGram,_that.appliedType,_that.calculationBreakdown,_that.steps,_that.calculatedAt,_that.isError,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalChargePaisa,  int metalChargePaisa,  int? stoneChargePaisa,  double metalWeightGrams,  double? stoneWeightGrams,  int metalRatePaisaPerGram,  MakingChargeType appliedType,  String calculationBreakdown,  List<CalculationStep> steps,  DateTime? calculatedAt,  bool isError,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _MakingChargeResult():
return $default(_that.totalChargePaisa,_that.metalChargePaisa,_that.stoneChargePaisa,_that.metalWeightGrams,_that.stoneWeightGrams,_that.metalRatePaisaPerGram,_that.appliedType,_that.calculationBreakdown,_that.steps,_that.calculatedAt,_that.isError,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalChargePaisa,  int metalChargePaisa,  int? stoneChargePaisa,  double metalWeightGrams,  double? stoneWeightGrams,  int metalRatePaisaPerGram,  MakingChargeType appliedType,  String calculationBreakdown,  List<CalculationStep> steps,  DateTime? calculatedAt,  bool isError,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _MakingChargeResult() when $default != null:
return $default(_that.totalChargePaisa,_that.metalChargePaisa,_that.stoneChargePaisa,_that.metalWeightGrams,_that.stoneWeightGrams,_that.metalRatePaisaPerGram,_that.appliedType,_that.calculationBreakdown,_that.steps,_that.calculatedAt,_that.isError,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MakingChargeResult extends MakingChargeResult {
  const _MakingChargeResult({required this.totalChargePaisa, required this.metalChargePaisa, required this.stoneChargePaisa, required this.metalWeightGrams, required this.stoneWeightGrams, required this.metalRatePaisaPerGram, required this.appliedType, required this.calculationBreakdown, required final  List<CalculationStep> steps, this.calculatedAt, this.isError = false, this.errorMessage}): _steps = steps,super._();
  factory _MakingChargeResult.fromJson(Map<String, dynamic> json) => _$MakingChargeResultFromJson(json);

@override final  int totalChargePaisa;
@override final  int metalChargePaisa;
@override final  int? stoneChargePaisa;
@override final  double metalWeightGrams;
@override final  double? stoneWeightGrams;
@override final  int metalRatePaisaPerGram;
@override final  MakingChargeType appliedType;
@override final  String calculationBreakdown;
 final  List<CalculationStep> _steps;
@override List<CalculationStep> get steps {
  if (_steps is EqualUnmodifiableListView) return _steps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_steps);
}

@override final  DateTime? calculatedAt;
/// Validation error flag (Requirement 15.2).
/// When true, the result represents a rejected invalid input.
/// The previous valid value should be retained by the caller.
@override@JsonKey() final  bool isError;
/// Human-readable validation error message when [isError] is true.
@override final  String? errorMessage;

/// Create a copy of MakingChargeResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MakingChargeResultCopyWith<_MakingChargeResult> get copyWith => __$MakingChargeResultCopyWithImpl<_MakingChargeResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MakingChargeResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MakingChargeResult&&(identical(other.totalChargePaisa, totalChargePaisa) || other.totalChargePaisa == totalChargePaisa)&&(identical(other.metalChargePaisa, metalChargePaisa) || other.metalChargePaisa == metalChargePaisa)&&(identical(other.stoneChargePaisa, stoneChargePaisa) || other.stoneChargePaisa == stoneChargePaisa)&&(identical(other.metalWeightGrams, metalWeightGrams) || other.metalWeightGrams == metalWeightGrams)&&(identical(other.stoneWeightGrams, stoneWeightGrams) || other.stoneWeightGrams == stoneWeightGrams)&&(identical(other.metalRatePaisaPerGram, metalRatePaisaPerGram) || other.metalRatePaisaPerGram == metalRatePaisaPerGram)&&(identical(other.appliedType, appliedType) || other.appliedType == appliedType)&&(identical(other.calculationBreakdown, calculationBreakdown) || other.calculationBreakdown == calculationBreakdown)&&const DeepCollectionEquality().equals(other._steps, _steps)&&(identical(other.calculatedAt, calculatedAt) || other.calculatedAt == calculatedAt)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalChargePaisa,metalChargePaisa,stoneChargePaisa,metalWeightGrams,stoneWeightGrams,metalRatePaisaPerGram,appliedType,calculationBreakdown,const DeepCollectionEquality().hash(_steps),calculatedAt,isError,errorMessage);

@override
String toString() {
  return 'MakingChargeResult(totalChargePaisa: $totalChargePaisa, metalChargePaisa: $metalChargePaisa, stoneChargePaisa: $stoneChargePaisa, metalWeightGrams: $metalWeightGrams, stoneWeightGrams: $stoneWeightGrams, metalRatePaisaPerGram: $metalRatePaisaPerGram, appliedType: $appliedType, calculationBreakdown: $calculationBreakdown, steps: $steps, calculatedAt: $calculatedAt, isError: $isError, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$MakingChargeResultCopyWith<$Res> implements $MakingChargeResultCopyWith<$Res> {
  factory _$MakingChargeResultCopyWith(_MakingChargeResult value, $Res Function(_MakingChargeResult) _then) = __$MakingChargeResultCopyWithImpl;
@override @useResult
$Res call({
 int totalChargePaisa, int metalChargePaisa, int? stoneChargePaisa, double metalWeightGrams, double? stoneWeightGrams, int metalRatePaisaPerGram, MakingChargeType appliedType, String calculationBreakdown, List<CalculationStep> steps, DateTime? calculatedAt, bool isError, String? errorMessage
});




}
/// @nodoc
class __$MakingChargeResultCopyWithImpl<$Res>
    implements _$MakingChargeResultCopyWith<$Res> {
  __$MakingChargeResultCopyWithImpl(this._self, this._then);

  final _MakingChargeResult _self;
  final $Res Function(_MakingChargeResult) _then;

/// Create a copy of MakingChargeResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalChargePaisa = null,Object? metalChargePaisa = null,Object? stoneChargePaisa = freezed,Object? metalWeightGrams = null,Object? stoneWeightGrams = freezed,Object? metalRatePaisaPerGram = null,Object? appliedType = null,Object? calculationBreakdown = null,Object? steps = null,Object? calculatedAt = freezed,Object? isError = null,Object? errorMessage = freezed,}) {
  return _then(_MakingChargeResult(
totalChargePaisa: null == totalChargePaisa ? _self.totalChargePaisa : totalChargePaisa // ignore: cast_nullable_to_non_nullable
as int,metalChargePaisa: null == metalChargePaisa ? _self.metalChargePaisa : metalChargePaisa // ignore: cast_nullable_to_non_nullable
as int,stoneChargePaisa: freezed == stoneChargePaisa ? _self.stoneChargePaisa : stoneChargePaisa // ignore: cast_nullable_to_non_nullable
as int?,metalWeightGrams: null == metalWeightGrams ? _self.metalWeightGrams : metalWeightGrams // ignore: cast_nullable_to_non_nullable
as double,stoneWeightGrams: freezed == stoneWeightGrams ? _self.stoneWeightGrams : stoneWeightGrams // ignore: cast_nullable_to_non_nullable
as double?,metalRatePaisaPerGram: null == metalRatePaisaPerGram ? _self.metalRatePaisaPerGram : metalRatePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,appliedType: null == appliedType ? _self.appliedType : appliedType // ignore: cast_nullable_to_non_nullable
as MakingChargeType,calculationBreakdown: null == calculationBreakdown ? _self.calculationBreakdown : calculationBreakdown // ignore: cast_nullable_to_non_nullable
as String,steps: null == steps ? _self._steps : steps // ignore: cast_nullable_to_non_nullable
as List<CalculationStep>,calculatedAt: freezed == calculatedAt ? _self.calculatedAt : calculatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CalculationStep {

 String get description; String get formula; int get resultPaisa;
/// Create a copy of CalculationStep
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalculationStepCopyWith<CalculationStep> get copyWith => _$CalculationStepCopyWithImpl<CalculationStep>(this as CalculationStep, _$identity);

  /// Serializes this CalculationStep to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalculationStep&&(identical(other.description, description) || other.description == description)&&(identical(other.formula, formula) || other.formula == formula)&&(identical(other.resultPaisa, resultPaisa) || other.resultPaisa == resultPaisa));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,description,formula,resultPaisa);

@override
String toString() {
  return 'CalculationStep(description: $description, formula: $formula, resultPaisa: $resultPaisa)';
}


}

/// @nodoc
abstract mixin class $CalculationStepCopyWith<$Res>  {
  factory $CalculationStepCopyWith(CalculationStep value, $Res Function(CalculationStep) _then) = _$CalculationStepCopyWithImpl;
@useResult
$Res call({
 String description, String formula, int resultPaisa
});




}
/// @nodoc
class _$CalculationStepCopyWithImpl<$Res>
    implements $CalculationStepCopyWith<$Res> {
  _$CalculationStepCopyWithImpl(this._self, this._then);

  final CalculationStep _self;
  final $Res Function(CalculationStep) _then;

/// Create a copy of CalculationStep
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? description = null,Object? formula = null,Object? resultPaisa = null,}) {
  return _then(_self.copyWith(
description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,formula: null == formula ? _self.formula : formula // ignore: cast_nullable_to_non_nullable
as String,resultPaisa: null == resultPaisa ? _self.resultPaisa : resultPaisa // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CalculationStep].
extension CalculationStepPatterns on CalculationStep {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalculationStep value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalculationStep() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalculationStep value)  $default,){
final _that = this;
switch (_that) {
case _CalculationStep():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalculationStep value)?  $default,){
final _that = this;
switch (_that) {
case _CalculationStep() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String description,  String formula,  int resultPaisa)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CalculationStep() when $default != null:
return $default(_that.description,_that.formula,_that.resultPaisa);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String description,  String formula,  int resultPaisa)  $default,) {final _that = this;
switch (_that) {
case _CalculationStep():
return $default(_that.description,_that.formula,_that.resultPaisa);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String description,  String formula,  int resultPaisa)?  $default,) {final _that = this;
switch (_that) {
case _CalculationStep() when $default != null:
return $default(_that.description,_that.formula,_that.resultPaisa);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CalculationStep implements CalculationStep {
  const _CalculationStep({required this.description, required this.formula, required this.resultPaisa});
  factory _CalculationStep.fromJson(Map<String, dynamic> json) => _$CalculationStepFromJson(json);

@override final  String description;
@override final  String formula;
@override final  int resultPaisa;

/// Create a copy of CalculationStep
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalculationStepCopyWith<_CalculationStep> get copyWith => __$CalculationStepCopyWithImpl<_CalculationStep>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CalculationStepToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalculationStep&&(identical(other.description, description) || other.description == description)&&(identical(other.formula, formula) || other.formula == formula)&&(identical(other.resultPaisa, resultPaisa) || other.resultPaisa == resultPaisa));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,description,formula,resultPaisa);

@override
String toString() {
  return 'CalculationStep(description: $description, formula: $formula, resultPaisa: $resultPaisa)';
}


}

/// @nodoc
abstract mixin class _$CalculationStepCopyWith<$Res> implements $CalculationStepCopyWith<$Res> {
  factory _$CalculationStepCopyWith(_CalculationStep value, $Res Function(_CalculationStep) _then) = __$CalculationStepCopyWithImpl;
@override @useResult
$Res call({
 String description, String formula, int resultPaisa
});




}
/// @nodoc
class __$CalculationStepCopyWithImpl<$Res>
    implements _$CalculationStepCopyWith<$Res> {
  __$CalculationStepCopyWithImpl(this._self, this._then);

  final _CalculationStep _self;
  final $Res Function(_CalculationStep) _then;

/// Create a copy of CalculationStep
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? description = null,Object? formula = null,Object? resultPaisa = null,}) {
  return _then(_CalculationStep(
description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,formula: null == formula ? _self.formula : formula // ignore: cast_nullable_to_non_nullable
as String,resultPaisa: null == resultPaisa ? _self.resultPaisa : resultPaisa // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
