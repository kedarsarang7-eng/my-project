// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gold_scheme_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SchemePayment {

@HiveField(0) String get id;@HiveField(1) int get installmentNumber;@HiveField(2) int get amountPaisa;@HiveField(3) DateTime get dueDate;@HiveField(4) DateTime? get paidDate;@HiveField(5) int? get paidAmountPaisa;@HiveField(6) bool get isPaid;@HiveField(7) bool get isLate;@HiveField(8) int? get lateFeePaisa;@HiveField(9) String? get paymentMode;// Cash, UPI, Card, etc.
@HiveField(10) String? get transactionId;@HiveField(11) String? get notes;@HiveField(12) String? get receivedBy;@HiveField(13) List<String>? get reminderSentDates;
/// Create a copy of SchemePayment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchemePaymentCopyWith<SchemePayment> get copyWith => _$SchemePaymentCopyWithImpl<SchemePayment>(this as SchemePayment, _$identity);

  /// Serializes this SchemePayment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchemePayment&&(identical(other.id, id) || other.id == id)&&(identical(other.installmentNumber, installmentNumber) || other.installmentNumber == installmentNumber)&&(identical(other.amountPaisa, amountPaisa) || other.amountPaisa == amountPaisa)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.paidDate, paidDate) || other.paidDate == paidDate)&&(identical(other.paidAmountPaisa, paidAmountPaisa) || other.paidAmountPaisa == paidAmountPaisa)&&(identical(other.isPaid, isPaid) || other.isPaid == isPaid)&&(identical(other.isLate, isLate) || other.isLate == isLate)&&(identical(other.lateFeePaisa, lateFeePaisa) || other.lateFeePaisa == lateFeePaisa)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.receivedBy, receivedBy) || other.receivedBy == receivedBy)&&const DeepCollectionEquality().equals(other.reminderSentDates, reminderSentDates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,installmentNumber,amountPaisa,dueDate,paidDate,paidAmountPaisa,isPaid,isLate,lateFeePaisa,paymentMode,transactionId,notes,receivedBy,const DeepCollectionEquality().hash(reminderSentDates));

@override
String toString() {
  return 'SchemePayment(id: $id, installmentNumber: $installmentNumber, amountPaisa: $amountPaisa, dueDate: $dueDate, paidDate: $paidDate, paidAmountPaisa: $paidAmountPaisa, isPaid: $isPaid, isLate: $isLate, lateFeePaisa: $lateFeePaisa, paymentMode: $paymentMode, transactionId: $transactionId, notes: $notes, receivedBy: $receivedBy, reminderSentDates: $reminderSentDates)';
}


}

/// @nodoc
abstract mixin class $SchemePaymentCopyWith<$Res>  {
  factory $SchemePaymentCopyWith(SchemePayment value, $Res Function(SchemePayment) _then) = _$SchemePaymentCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) int installmentNumber,@HiveField(2) int amountPaisa,@HiveField(3) DateTime dueDate,@HiveField(4) DateTime? paidDate,@HiveField(5) int? paidAmountPaisa,@HiveField(6) bool isPaid,@HiveField(7) bool isLate,@HiveField(8) int? lateFeePaisa,@HiveField(9) String? paymentMode,@HiveField(10) String? transactionId,@HiveField(11) String? notes,@HiveField(12) String? receivedBy,@HiveField(13) List<String>? reminderSentDates
});




}
/// @nodoc
class _$SchemePaymentCopyWithImpl<$Res>
    implements $SchemePaymentCopyWith<$Res> {
  _$SchemePaymentCopyWithImpl(this._self, this._then);

  final SchemePayment _self;
  final $Res Function(SchemePayment) _then;

/// Create a copy of SchemePayment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? installmentNumber = null,Object? amountPaisa = null,Object? dueDate = null,Object? paidDate = freezed,Object? paidAmountPaisa = freezed,Object? isPaid = null,Object? isLate = null,Object? lateFeePaisa = freezed,Object? paymentMode = freezed,Object? transactionId = freezed,Object? notes = freezed,Object? receivedBy = freezed,Object? reminderSentDates = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,installmentNumber: null == installmentNumber ? _self.installmentNumber : installmentNumber // ignore: cast_nullable_to_non_nullable
as int,amountPaisa: null == amountPaisa ? _self.amountPaisa : amountPaisa // ignore: cast_nullable_to_non_nullable
as int,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime,paidDate: freezed == paidDate ? _self.paidDate : paidDate // ignore: cast_nullable_to_non_nullable
as DateTime?,paidAmountPaisa: freezed == paidAmountPaisa ? _self.paidAmountPaisa : paidAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,isPaid: null == isPaid ? _self.isPaid : isPaid // ignore: cast_nullable_to_non_nullable
as bool,isLate: null == isLate ? _self.isLate : isLate // ignore: cast_nullable_to_non_nullable
as bool,lateFeePaisa: freezed == lateFeePaisa ? _self.lateFeePaisa : lateFeePaisa // ignore: cast_nullable_to_non_nullable
as int?,paymentMode: freezed == paymentMode ? _self.paymentMode : paymentMode // ignore: cast_nullable_to_non_nullable
as String?,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,receivedBy: freezed == receivedBy ? _self.receivedBy : receivedBy // ignore: cast_nullable_to_non_nullable
as String?,reminderSentDates: freezed == reminderSentDates ? _self.reminderSentDates : reminderSentDates // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [SchemePayment].
extension SchemePaymentPatterns on SchemePayment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchemePayment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchemePayment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchemePayment value)  $default,){
final _that = this;
switch (_that) {
case _SchemePayment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchemePayment value)?  $default,){
final _that = this;
switch (_that) {
case _SchemePayment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  int installmentNumber, @HiveField(2)  int amountPaisa, @HiveField(3)  DateTime dueDate, @HiveField(4)  DateTime? paidDate, @HiveField(5)  int? paidAmountPaisa, @HiveField(6)  bool isPaid, @HiveField(7)  bool isLate, @HiveField(8)  int? lateFeePaisa, @HiveField(9)  String? paymentMode, @HiveField(10)  String? transactionId, @HiveField(11)  String? notes, @HiveField(12)  String? receivedBy, @HiveField(13)  List<String>? reminderSentDates)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchemePayment() when $default != null:
return $default(_that.id,_that.installmentNumber,_that.amountPaisa,_that.dueDate,_that.paidDate,_that.paidAmountPaisa,_that.isPaid,_that.isLate,_that.lateFeePaisa,_that.paymentMode,_that.transactionId,_that.notes,_that.receivedBy,_that.reminderSentDates);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  int installmentNumber, @HiveField(2)  int amountPaisa, @HiveField(3)  DateTime dueDate, @HiveField(4)  DateTime? paidDate, @HiveField(5)  int? paidAmountPaisa, @HiveField(6)  bool isPaid, @HiveField(7)  bool isLate, @HiveField(8)  int? lateFeePaisa, @HiveField(9)  String? paymentMode, @HiveField(10)  String? transactionId, @HiveField(11)  String? notes, @HiveField(12)  String? receivedBy, @HiveField(13)  List<String>? reminderSentDates)  $default,) {final _that = this;
switch (_that) {
case _SchemePayment():
return $default(_that.id,_that.installmentNumber,_that.amountPaisa,_that.dueDate,_that.paidDate,_that.paidAmountPaisa,_that.isPaid,_that.isLate,_that.lateFeePaisa,_that.paymentMode,_that.transactionId,_that.notes,_that.receivedBy,_that.reminderSentDates);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  int installmentNumber, @HiveField(2)  int amountPaisa, @HiveField(3)  DateTime dueDate, @HiveField(4)  DateTime? paidDate, @HiveField(5)  int? paidAmountPaisa, @HiveField(6)  bool isPaid, @HiveField(7)  bool isLate, @HiveField(8)  int? lateFeePaisa, @HiveField(9)  String? paymentMode, @HiveField(10)  String? transactionId, @HiveField(11)  String? notes, @HiveField(12)  String? receivedBy, @HiveField(13)  List<String>? reminderSentDates)?  $default,) {final _that = this;
switch (_that) {
case _SchemePayment() when $default != null:
return $default(_that.id,_that.installmentNumber,_that.amountPaisa,_that.dueDate,_that.paidDate,_that.paidAmountPaisa,_that.isPaid,_that.isLate,_that.lateFeePaisa,_that.paymentMode,_that.transactionId,_that.notes,_that.receivedBy,_that.reminderSentDates);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 66)
class _SchemePayment extends SchemePayment {
  const _SchemePayment({@HiveField(0) required this.id, @HiveField(1) required this.installmentNumber, @HiveField(2) required this.amountPaisa, @HiveField(3) required this.dueDate, @HiveField(4) this.paidDate, @HiveField(5) this.paidAmountPaisa, @HiveField(6) this.isPaid = false, @HiveField(7) this.isLate = false, @HiveField(8) this.lateFeePaisa, @HiveField(9) this.paymentMode, @HiveField(10) this.transactionId, @HiveField(11) this.notes, @HiveField(12) this.receivedBy, @HiveField(13) final  List<String>? reminderSentDates}): _reminderSentDates = reminderSentDates,super._();
  factory _SchemePayment.fromJson(Map<String, dynamic> json) => _$SchemePaymentFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  int installmentNumber;
@override@HiveField(2) final  int amountPaisa;
@override@HiveField(3) final  DateTime dueDate;
@override@HiveField(4) final  DateTime? paidDate;
@override@HiveField(5) final  int? paidAmountPaisa;
@override@JsonKey()@HiveField(6) final  bool isPaid;
@override@JsonKey()@HiveField(7) final  bool isLate;
@override@HiveField(8) final  int? lateFeePaisa;
@override@HiveField(9) final  String? paymentMode;
// Cash, UPI, Card, etc.
@override@HiveField(10) final  String? transactionId;
@override@HiveField(11) final  String? notes;
@override@HiveField(12) final  String? receivedBy;
 final  List<String>? _reminderSentDates;
@override@HiveField(13) List<String>? get reminderSentDates {
  final value = _reminderSentDates;
  if (value == null) return null;
  if (_reminderSentDates is EqualUnmodifiableListView) return _reminderSentDates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of SchemePayment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchemePaymentCopyWith<_SchemePayment> get copyWith => __$SchemePaymentCopyWithImpl<_SchemePayment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SchemePaymentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchemePayment&&(identical(other.id, id) || other.id == id)&&(identical(other.installmentNumber, installmentNumber) || other.installmentNumber == installmentNumber)&&(identical(other.amountPaisa, amountPaisa) || other.amountPaisa == amountPaisa)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.paidDate, paidDate) || other.paidDate == paidDate)&&(identical(other.paidAmountPaisa, paidAmountPaisa) || other.paidAmountPaisa == paidAmountPaisa)&&(identical(other.isPaid, isPaid) || other.isPaid == isPaid)&&(identical(other.isLate, isLate) || other.isLate == isLate)&&(identical(other.lateFeePaisa, lateFeePaisa) || other.lateFeePaisa == lateFeePaisa)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.receivedBy, receivedBy) || other.receivedBy == receivedBy)&&const DeepCollectionEquality().equals(other._reminderSentDates, _reminderSentDates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,installmentNumber,amountPaisa,dueDate,paidDate,paidAmountPaisa,isPaid,isLate,lateFeePaisa,paymentMode,transactionId,notes,receivedBy,const DeepCollectionEquality().hash(_reminderSentDates));

@override
String toString() {
  return 'SchemePayment(id: $id, installmentNumber: $installmentNumber, amountPaisa: $amountPaisa, dueDate: $dueDate, paidDate: $paidDate, paidAmountPaisa: $paidAmountPaisa, isPaid: $isPaid, isLate: $isLate, lateFeePaisa: $lateFeePaisa, paymentMode: $paymentMode, transactionId: $transactionId, notes: $notes, receivedBy: $receivedBy, reminderSentDates: $reminderSentDates)';
}


}

/// @nodoc
abstract mixin class _$SchemePaymentCopyWith<$Res> implements $SchemePaymentCopyWith<$Res> {
  factory _$SchemePaymentCopyWith(_SchemePayment value, $Res Function(_SchemePayment) _then) = __$SchemePaymentCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) int installmentNumber,@HiveField(2) int amountPaisa,@HiveField(3) DateTime dueDate,@HiveField(4) DateTime? paidDate,@HiveField(5) int? paidAmountPaisa,@HiveField(6) bool isPaid,@HiveField(7) bool isLate,@HiveField(8) int? lateFeePaisa,@HiveField(9) String? paymentMode,@HiveField(10) String? transactionId,@HiveField(11) String? notes,@HiveField(12) String? receivedBy,@HiveField(13) List<String>? reminderSentDates
});




}
/// @nodoc
class __$SchemePaymentCopyWithImpl<$Res>
    implements _$SchemePaymentCopyWith<$Res> {
  __$SchemePaymentCopyWithImpl(this._self, this._then);

  final _SchemePayment _self;
  final $Res Function(_SchemePayment) _then;

/// Create a copy of SchemePayment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? installmentNumber = null,Object? amountPaisa = null,Object? dueDate = null,Object? paidDate = freezed,Object? paidAmountPaisa = freezed,Object? isPaid = null,Object? isLate = null,Object? lateFeePaisa = freezed,Object? paymentMode = freezed,Object? transactionId = freezed,Object? notes = freezed,Object? receivedBy = freezed,Object? reminderSentDates = freezed,}) {
  return _then(_SchemePayment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,installmentNumber: null == installmentNumber ? _self.installmentNumber : installmentNumber // ignore: cast_nullable_to_non_nullable
as int,amountPaisa: null == amountPaisa ? _self.amountPaisa : amountPaisa // ignore: cast_nullable_to_non_nullable
as int,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime,paidDate: freezed == paidDate ? _self.paidDate : paidDate // ignore: cast_nullable_to_non_nullable
as DateTime?,paidAmountPaisa: freezed == paidAmountPaisa ? _self.paidAmountPaisa : paidAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,isPaid: null == isPaid ? _self.isPaid : isPaid // ignore: cast_nullable_to_non_nullable
as bool,isLate: null == isLate ? _self.isLate : isLate // ignore: cast_nullable_to_non_nullable
as bool,lateFeePaisa: freezed == lateFeePaisa ? _self.lateFeePaisa : lateFeePaisa // ignore: cast_nullable_to_non_nullable
as int?,paymentMode: freezed == paymentMode ? _self.paymentMode : paymentMode // ignore: cast_nullable_to_non_nullable
as String?,transactionId: freezed == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,receivedBy: freezed == receivedBy ? _self.receivedBy : receivedBy // ignore: cast_nullable_to_non_nullable
as String?,reminderSentDates: freezed == reminderSentDates ? _self._reminderSentDates : reminderSentDates // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}


/// @nodoc
mixin _$GoldWeightRecord {

@HiveField(0) DateTime get date;@HiveField(1) double get goldRatePerGramPaisa;@HiveField(2) double get goldWeightGrams;@HiveField(3) int get amountPaisa;@HiveField(4) String? get notes;
/// Create a copy of GoldWeightRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoldWeightRecordCopyWith<GoldWeightRecord> get copyWith => _$GoldWeightRecordCopyWithImpl<GoldWeightRecord>(this as GoldWeightRecord, _$identity);

  /// Serializes this GoldWeightRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoldWeightRecord&&(identical(other.date, date) || other.date == date)&&(identical(other.goldRatePerGramPaisa, goldRatePerGramPaisa) || other.goldRatePerGramPaisa == goldRatePerGramPaisa)&&(identical(other.goldWeightGrams, goldWeightGrams) || other.goldWeightGrams == goldWeightGrams)&&(identical(other.amountPaisa, amountPaisa) || other.amountPaisa == amountPaisa)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,goldRatePerGramPaisa,goldWeightGrams,amountPaisa,notes);

@override
String toString() {
  return 'GoldWeightRecord(date: $date, goldRatePerGramPaisa: $goldRatePerGramPaisa, goldWeightGrams: $goldWeightGrams, amountPaisa: $amountPaisa, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $GoldWeightRecordCopyWith<$Res>  {
  factory $GoldWeightRecordCopyWith(GoldWeightRecord value, $Res Function(GoldWeightRecord) _then) = _$GoldWeightRecordCopyWithImpl;
@useResult
$Res call({
@HiveField(0) DateTime date,@HiveField(1) double goldRatePerGramPaisa,@HiveField(2) double goldWeightGrams,@HiveField(3) int amountPaisa,@HiveField(4) String? notes
});




}
/// @nodoc
class _$GoldWeightRecordCopyWithImpl<$Res>
    implements $GoldWeightRecordCopyWith<$Res> {
  _$GoldWeightRecordCopyWithImpl(this._self, this._then);

  final GoldWeightRecord _self;
  final $Res Function(GoldWeightRecord) _then;

/// Create a copy of GoldWeightRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? goldRatePerGramPaisa = null,Object? goldWeightGrams = null,Object? amountPaisa = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,goldRatePerGramPaisa: null == goldRatePerGramPaisa ? _self.goldRatePerGramPaisa : goldRatePerGramPaisa // ignore: cast_nullable_to_non_nullable
as double,goldWeightGrams: null == goldWeightGrams ? _self.goldWeightGrams : goldWeightGrams // ignore: cast_nullable_to_non_nullable
as double,amountPaisa: null == amountPaisa ? _self.amountPaisa : amountPaisa // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoldWeightRecord].
extension GoldWeightRecordPatterns on GoldWeightRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoldWeightRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoldWeightRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoldWeightRecord value)  $default,){
final _that = this;
switch (_that) {
case _GoldWeightRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoldWeightRecord value)?  $default,){
final _that = this;
switch (_that) {
case _GoldWeightRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  DateTime date, @HiveField(1)  double goldRatePerGramPaisa, @HiveField(2)  double goldWeightGrams, @HiveField(3)  int amountPaisa, @HiveField(4)  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoldWeightRecord() when $default != null:
return $default(_that.date,_that.goldRatePerGramPaisa,_that.goldWeightGrams,_that.amountPaisa,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  DateTime date, @HiveField(1)  double goldRatePerGramPaisa, @HiveField(2)  double goldWeightGrams, @HiveField(3)  int amountPaisa, @HiveField(4)  String? notes)  $default,) {final _that = this;
switch (_that) {
case _GoldWeightRecord():
return $default(_that.date,_that.goldRatePerGramPaisa,_that.goldWeightGrams,_that.amountPaisa,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  DateTime date, @HiveField(1)  double goldRatePerGramPaisa, @HiveField(2)  double goldWeightGrams, @HiveField(3)  int amountPaisa, @HiveField(4)  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _GoldWeightRecord() when $default != null:
return $default(_that.date,_that.goldRatePerGramPaisa,_that.goldWeightGrams,_that.amountPaisa,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 67)
class _GoldWeightRecord extends GoldWeightRecord {
  const _GoldWeightRecord({@HiveField(0) required this.date, @HiveField(1) required this.goldRatePerGramPaisa, @HiveField(2) required this.goldWeightGrams, @HiveField(3) required this.amountPaisa, @HiveField(4) this.notes}): super._();
  factory _GoldWeightRecord.fromJson(Map<String, dynamic> json) => _$GoldWeightRecordFromJson(json);

@override@HiveField(0) final  DateTime date;
@override@HiveField(1) final  double goldRatePerGramPaisa;
@override@HiveField(2) final  double goldWeightGrams;
@override@HiveField(3) final  int amountPaisa;
@override@HiveField(4) final  String? notes;

/// Create a copy of GoldWeightRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoldWeightRecordCopyWith<_GoldWeightRecord> get copyWith => __$GoldWeightRecordCopyWithImpl<_GoldWeightRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoldWeightRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoldWeightRecord&&(identical(other.date, date) || other.date == date)&&(identical(other.goldRatePerGramPaisa, goldRatePerGramPaisa) || other.goldRatePerGramPaisa == goldRatePerGramPaisa)&&(identical(other.goldWeightGrams, goldWeightGrams) || other.goldWeightGrams == goldWeightGrams)&&(identical(other.amountPaisa, amountPaisa) || other.amountPaisa == amountPaisa)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,goldRatePerGramPaisa,goldWeightGrams,amountPaisa,notes);

@override
String toString() {
  return 'GoldWeightRecord(date: $date, goldRatePerGramPaisa: $goldRatePerGramPaisa, goldWeightGrams: $goldWeightGrams, amountPaisa: $amountPaisa, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$GoldWeightRecordCopyWith<$Res> implements $GoldWeightRecordCopyWith<$Res> {
  factory _$GoldWeightRecordCopyWith(_GoldWeightRecord value, $Res Function(_GoldWeightRecord) _then) = __$GoldWeightRecordCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) DateTime date,@HiveField(1) double goldRatePerGramPaisa,@HiveField(2) double goldWeightGrams,@HiveField(3) int amountPaisa,@HiveField(4) String? notes
});




}
/// @nodoc
class __$GoldWeightRecordCopyWithImpl<$Res>
    implements _$GoldWeightRecordCopyWith<$Res> {
  __$GoldWeightRecordCopyWithImpl(this._self, this._then);

  final _GoldWeightRecord _self;
  final $Res Function(_GoldWeightRecord) _then;

/// Create a copy of GoldWeightRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? goldRatePerGramPaisa = null,Object? goldWeightGrams = null,Object? amountPaisa = null,Object? notes = freezed,}) {
  return _then(_GoldWeightRecord(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,goldRatePerGramPaisa: null == goldRatePerGramPaisa ? _self.goldRatePerGramPaisa : goldRatePerGramPaisa // ignore: cast_nullable_to_non_nullable
as double,goldWeightGrams: null == goldWeightGrams ? _self.goldWeightGrams : goldWeightGrams // ignore: cast_nullable_to_non_nullable
as double,amountPaisa: null == amountPaisa ? _self.amountPaisa : amountPaisa // ignore: cast_nullable_to_non_nullable
as int,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SchemeRedemption {

@HiveField(0) String get id;@HiveField(1) RedemptionType get type;@HiveField(2) DateTime get redemptionDate;@HiveField(3) int get totalAmountPaisa;@HiveField(4) int? get bonusAmountPaisa;@HiveField(5) int? get discountAmountPaisa;@HiveField(6) int? get finalAmountPaisa;// For gold redemption
@HiveField(7) double? get goldWeightGrams;@HiveField(8) double? get goldRateAtRedemptionPaisa;@HiveField(9) String? get purity;// For jewellery redemption
@HiveField(10) String? get productId;@HiveField(11) String? get productName;@HiveField(12) String? get invoiceId;// For cash/bank redemption
@HiveField(13) String? get bankAccountNumber;@HiveField(14) String? get bankIfsc;@HiveField(15) String? get upiId;@HiveField(16) DateTime? get payoutDate;@HiveField(17) String? get notes;@HiveField(18) String? get processedBy;
/// Create a copy of SchemeRedemption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchemeRedemptionCopyWith<SchemeRedemption> get copyWith => _$SchemeRedemptionCopyWithImpl<SchemeRedemption>(this as SchemeRedemption, _$identity);

  /// Serializes this SchemeRedemption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchemeRedemption&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.redemptionDate, redemptionDate) || other.redemptionDate == redemptionDate)&&(identical(other.totalAmountPaisa, totalAmountPaisa) || other.totalAmountPaisa == totalAmountPaisa)&&(identical(other.bonusAmountPaisa, bonusAmountPaisa) || other.bonusAmountPaisa == bonusAmountPaisa)&&(identical(other.discountAmountPaisa, discountAmountPaisa) || other.discountAmountPaisa == discountAmountPaisa)&&(identical(other.finalAmountPaisa, finalAmountPaisa) || other.finalAmountPaisa == finalAmountPaisa)&&(identical(other.goldWeightGrams, goldWeightGrams) || other.goldWeightGrams == goldWeightGrams)&&(identical(other.goldRateAtRedemptionPaisa, goldRateAtRedemptionPaisa) || other.goldRateAtRedemptionPaisa == goldRateAtRedemptionPaisa)&&(identical(other.purity, purity) || other.purity == purity)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.bankAccountNumber, bankAccountNumber) || other.bankAccountNumber == bankAccountNumber)&&(identical(other.bankIfsc, bankIfsc) || other.bankIfsc == bankIfsc)&&(identical(other.upiId, upiId) || other.upiId == upiId)&&(identical(other.payoutDate, payoutDate) || other.payoutDate == payoutDate)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.processedBy, processedBy) || other.processedBy == processedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,type,redemptionDate,totalAmountPaisa,bonusAmountPaisa,discountAmountPaisa,finalAmountPaisa,goldWeightGrams,goldRateAtRedemptionPaisa,purity,productId,productName,invoiceId,bankAccountNumber,bankIfsc,upiId,payoutDate,notes,processedBy]);

@override
String toString() {
  return 'SchemeRedemption(id: $id, type: $type, redemptionDate: $redemptionDate, totalAmountPaisa: $totalAmountPaisa, bonusAmountPaisa: $bonusAmountPaisa, discountAmountPaisa: $discountAmountPaisa, finalAmountPaisa: $finalAmountPaisa, goldWeightGrams: $goldWeightGrams, goldRateAtRedemptionPaisa: $goldRateAtRedemptionPaisa, purity: $purity, productId: $productId, productName: $productName, invoiceId: $invoiceId, bankAccountNumber: $bankAccountNumber, bankIfsc: $bankIfsc, upiId: $upiId, payoutDate: $payoutDate, notes: $notes, processedBy: $processedBy)';
}


}

/// @nodoc
abstract mixin class $SchemeRedemptionCopyWith<$Res>  {
  factory $SchemeRedemptionCopyWith(SchemeRedemption value, $Res Function(SchemeRedemption) _then) = _$SchemeRedemptionCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) RedemptionType type,@HiveField(2) DateTime redemptionDate,@HiveField(3) int totalAmountPaisa,@HiveField(4) int? bonusAmountPaisa,@HiveField(5) int? discountAmountPaisa,@HiveField(6) int? finalAmountPaisa,@HiveField(7) double? goldWeightGrams,@HiveField(8) double? goldRateAtRedemptionPaisa,@HiveField(9) String? purity,@HiveField(10) String? productId,@HiveField(11) String? productName,@HiveField(12) String? invoiceId,@HiveField(13) String? bankAccountNumber,@HiveField(14) String? bankIfsc,@HiveField(15) String? upiId,@HiveField(16) DateTime? payoutDate,@HiveField(17) String? notes,@HiveField(18) String? processedBy
});




}
/// @nodoc
class _$SchemeRedemptionCopyWithImpl<$Res>
    implements $SchemeRedemptionCopyWith<$Res> {
  _$SchemeRedemptionCopyWithImpl(this._self, this._then);

  final SchemeRedemption _self;
  final $Res Function(SchemeRedemption) _then;

/// Create a copy of SchemeRedemption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? redemptionDate = null,Object? totalAmountPaisa = null,Object? bonusAmountPaisa = freezed,Object? discountAmountPaisa = freezed,Object? finalAmountPaisa = freezed,Object? goldWeightGrams = freezed,Object? goldRateAtRedemptionPaisa = freezed,Object? purity = freezed,Object? productId = freezed,Object? productName = freezed,Object? invoiceId = freezed,Object? bankAccountNumber = freezed,Object? bankIfsc = freezed,Object? upiId = freezed,Object? payoutDate = freezed,Object? notes = freezed,Object? processedBy = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RedemptionType,redemptionDate: null == redemptionDate ? _self.redemptionDate : redemptionDate // ignore: cast_nullable_to_non_nullable
as DateTime,totalAmountPaisa: null == totalAmountPaisa ? _self.totalAmountPaisa : totalAmountPaisa // ignore: cast_nullable_to_non_nullable
as int,bonusAmountPaisa: freezed == bonusAmountPaisa ? _self.bonusAmountPaisa : bonusAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,discountAmountPaisa: freezed == discountAmountPaisa ? _self.discountAmountPaisa : discountAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,finalAmountPaisa: freezed == finalAmountPaisa ? _self.finalAmountPaisa : finalAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,goldWeightGrams: freezed == goldWeightGrams ? _self.goldWeightGrams : goldWeightGrams // ignore: cast_nullable_to_non_nullable
as double?,goldRateAtRedemptionPaisa: freezed == goldRateAtRedemptionPaisa ? _self.goldRateAtRedemptionPaisa : goldRateAtRedemptionPaisa // ignore: cast_nullable_to_non_nullable
as double?,purity: freezed == purity ? _self.purity : purity // ignore: cast_nullable_to_non_nullable
as String?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,bankAccountNumber: freezed == bankAccountNumber ? _self.bankAccountNumber : bankAccountNumber // ignore: cast_nullable_to_non_nullable
as String?,bankIfsc: freezed == bankIfsc ? _self.bankIfsc : bankIfsc // ignore: cast_nullable_to_non_nullable
as String?,upiId: freezed == upiId ? _self.upiId : upiId // ignore: cast_nullable_to_non_nullable
as String?,payoutDate: freezed == payoutDate ? _self.payoutDate : payoutDate // ignore: cast_nullable_to_non_nullable
as DateTime?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,processedBy: freezed == processedBy ? _self.processedBy : processedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SchemeRedemption].
extension SchemeRedemptionPatterns on SchemeRedemption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchemeRedemption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchemeRedemption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchemeRedemption value)  $default,){
final _that = this;
switch (_that) {
case _SchemeRedemption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchemeRedemption value)?  $default,){
final _that = this;
switch (_that) {
case _SchemeRedemption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  RedemptionType type, @HiveField(2)  DateTime redemptionDate, @HiveField(3)  int totalAmountPaisa, @HiveField(4)  int? bonusAmountPaisa, @HiveField(5)  int? discountAmountPaisa, @HiveField(6)  int? finalAmountPaisa, @HiveField(7)  double? goldWeightGrams, @HiveField(8)  double? goldRateAtRedemptionPaisa, @HiveField(9)  String? purity, @HiveField(10)  String? productId, @HiveField(11)  String? productName, @HiveField(12)  String? invoiceId, @HiveField(13)  String? bankAccountNumber, @HiveField(14)  String? bankIfsc, @HiveField(15)  String? upiId, @HiveField(16)  DateTime? payoutDate, @HiveField(17)  String? notes, @HiveField(18)  String? processedBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchemeRedemption() when $default != null:
return $default(_that.id,_that.type,_that.redemptionDate,_that.totalAmountPaisa,_that.bonusAmountPaisa,_that.discountAmountPaisa,_that.finalAmountPaisa,_that.goldWeightGrams,_that.goldRateAtRedemptionPaisa,_that.purity,_that.productId,_that.productName,_that.invoiceId,_that.bankAccountNumber,_that.bankIfsc,_that.upiId,_that.payoutDate,_that.notes,_that.processedBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  RedemptionType type, @HiveField(2)  DateTime redemptionDate, @HiveField(3)  int totalAmountPaisa, @HiveField(4)  int? bonusAmountPaisa, @HiveField(5)  int? discountAmountPaisa, @HiveField(6)  int? finalAmountPaisa, @HiveField(7)  double? goldWeightGrams, @HiveField(8)  double? goldRateAtRedemptionPaisa, @HiveField(9)  String? purity, @HiveField(10)  String? productId, @HiveField(11)  String? productName, @HiveField(12)  String? invoiceId, @HiveField(13)  String? bankAccountNumber, @HiveField(14)  String? bankIfsc, @HiveField(15)  String? upiId, @HiveField(16)  DateTime? payoutDate, @HiveField(17)  String? notes, @HiveField(18)  String? processedBy)  $default,) {final _that = this;
switch (_that) {
case _SchemeRedemption():
return $default(_that.id,_that.type,_that.redemptionDate,_that.totalAmountPaisa,_that.bonusAmountPaisa,_that.discountAmountPaisa,_that.finalAmountPaisa,_that.goldWeightGrams,_that.goldRateAtRedemptionPaisa,_that.purity,_that.productId,_that.productName,_that.invoiceId,_that.bankAccountNumber,_that.bankIfsc,_that.upiId,_that.payoutDate,_that.notes,_that.processedBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  RedemptionType type, @HiveField(2)  DateTime redemptionDate, @HiveField(3)  int totalAmountPaisa, @HiveField(4)  int? bonusAmountPaisa, @HiveField(5)  int? discountAmountPaisa, @HiveField(6)  int? finalAmountPaisa, @HiveField(7)  double? goldWeightGrams, @HiveField(8)  double? goldRateAtRedemptionPaisa, @HiveField(9)  String? purity, @HiveField(10)  String? productId, @HiveField(11)  String? productName, @HiveField(12)  String? invoiceId, @HiveField(13)  String? bankAccountNumber, @HiveField(14)  String? bankIfsc, @HiveField(15)  String? upiId, @HiveField(16)  DateTime? payoutDate, @HiveField(17)  String? notes, @HiveField(18)  String? processedBy)?  $default,) {final _that = this;
switch (_that) {
case _SchemeRedemption() when $default != null:
return $default(_that.id,_that.type,_that.redemptionDate,_that.totalAmountPaisa,_that.bonusAmountPaisa,_that.discountAmountPaisa,_that.finalAmountPaisa,_that.goldWeightGrams,_that.goldRateAtRedemptionPaisa,_that.purity,_that.productId,_that.productName,_that.invoiceId,_that.bankAccountNumber,_that.bankIfsc,_that.upiId,_that.payoutDate,_that.notes,_that.processedBy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 68)
class _SchemeRedemption extends SchemeRedemption {
  const _SchemeRedemption({@HiveField(0) required this.id, @HiveField(1) required this.type, @HiveField(2) required this.redemptionDate, @HiveField(3) required this.totalAmountPaisa, @HiveField(4) this.bonusAmountPaisa, @HiveField(5) this.discountAmountPaisa, @HiveField(6) this.finalAmountPaisa, @HiveField(7) this.goldWeightGrams, @HiveField(8) this.goldRateAtRedemptionPaisa, @HiveField(9) this.purity, @HiveField(10) this.productId, @HiveField(11) this.productName, @HiveField(12) this.invoiceId, @HiveField(13) this.bankAccountNumber, @HiveField(14) this.bankIfsc, @HiveField(15) this.upiId, @HiveField(16) this.payoutDate, @HiveField(17) this.notes, @HiveField(18) this.processedBy}): super._();
  factory _SchemeRedemption.fromJson(Map<String, dynamic> json) => _$SchemeRedemptionFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  RedemptionType type;
@override@HiveField(2) final  DateTime redemptionDate;
@override@HiveField(3) final  int totalAmountPaisa;
@override@HiveField(4) final  int? bonusAmountPaisa;
@override@HiveField(5) final  int? discountAmountPaisa;
@override@HiveField(6) final  int? finalAmountPaisa;
// For gold redemption
@override@HiveField(7) final  double? goldWeightGrams;
@override@HiveField(8) final  double? goldRateAtRedemptionPaisa;
@override@HiveField(9) final  String? purity;
// For jewellery redemption
@override@HiveField(10) final  String? productId;
@override@HiveField(11) final  String? productName;
@override@HiveField(12) final  String? invoiceId;
// For cash/bank redemption
@override@HiveField(13) final  String? bankAccountNumber;
@override@HiveField(14) final  String? bankIfsc;
@override@HiveField(15) final  String? upiId;
@override@HiveField(16) final  DateTime? payoutDate;
@override@HiveField(17) final  String? notes;
@override@HiveField(18) final  String? processedBy;

/// Create a copy of SchemeRedemption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchemeRedemptionCopyWith<_SchemeRedemption> get copyWith => __$SchemeRedemptionCopyWithImpl<_SchemeRedemption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SchemeRedemptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchemeRedemption&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.redemptionDate, redemptionDate) || other.redemptionDate == redemptionDate)&&(identical(other.totalAmountPaisa, totalAmountPaisa) || other.totalAmountPaisa == totalAmountPaisa)&&(identical(other.bonusAmountPaisa, bonusAmountPaisa) || other.bonusAmountPaisa == bonusAmountPaisa)&&(identical(other.discountAmountPaisa, discountAmountPaisa) || other.discountAmountPaisa == discountAmountPaisa)&&(identical(other.finalAmountPaisa, finalAmountPaisa) || other.finalAmountPaisa == finalAmountPaisa)&&(identical(other.goldWeightGrams, goldWeightGrams) || other.goldWeightGrams == goldWeightGrams)&&(identical(other.goldRateAtRedemptionPaisa, goldRateAtRedemptionPaisa) || other.goldRateAtRedemptionPaisa == goldRateAtRedemptionPaisa)&&(identical(other.purity, purity) || other.purity == purity)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.bankAccountNumber, bankAccountNumber) || other.bankAccountNumber == bankAccountNumber)&&(identical(other.bankIfsc, bankIfsc) || other.bankIfsc == bankIfsc)&&(identical(other.upiId, upiId) || other.upiId == upiId)&&(identical(other.payoutDate, payoutDate) || other.payoutDate == payoutDate)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.processedBy, processedBy) || other.processedBy == processedBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,type,redemptionDate,totalAmountPaisa,bonusAmountPaisa,discountAmountPaisa,finalAmountPaisa,goldWeightGrams,goldRateAtRedemptionPaisa,purity,productId,productName,invoiceId,bankAccountNumber,bankIfsc,upiId,payoutDate,notes,processedBy]);

@override
String toString() {
  return 'SchemeRedemption(id: $id, type: $type, redemptionDate: $redemptionDate, totalAmountPaisa: $totalAmountPaisa, bonusAmountPaisa: $bonusAmountPaisa, discountAmountPaisa: $discountAmountPaisa, finalAmountPaisa: $finalAmountPaisa, goldWeightGrams: $goldWeightGrams, goldRateAtRedemptionPaisa: $goldRateAtRedemptionPaisa, purity: $purity, productId: $productId, productName: $productName, invoiceId: $invoiceId, bankAccountNumber: $bankAccountNumber, bankIfsc: $bankIfsc, upiId: $upiId, payoutDate: $payoutDate, notes: $notes, processedBy: $processedBy)';
}


}

/// @nodoc
abstract mixin class _$SchemeRedemptionCopyWith<$Res> implements $SchemeRedemptionCopyWith<$Res> {
  factory _$SchemeRedemptionCopyWith(_SchemeRedemption value, $Res Function(_SchemeRedemption) _then) = __$SchemeRedemptionCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) RedemptionType type,@HiveField(2) DateTime redemptionDate,@HiveField(3) int totalAmountPaisa,@HiveField(4) int? bonusAmountPaisa,@HiveField(5) int? discountAmountPaisa,@HiveField(6) int? finalAmountPaisa,@HiveField(7) double? goldWeightGrams,@HiveField(8) double? goldRateAtRedemptionPaisa,@HiveField(9) String? purity,@HiveField(10) String? productId,@HiveField(11) String? productName,@HiveField(12) String? invoiceId,@HiveField(13) String? bankAccountNumber,@HiveField(14) String? bankIfsc,@HiveField(15) String? upiId,@HiveField(16) DateTime? payoutDate,@HiveField(17) String? notes,@HiveField(18) String? processedBy
});




}
/// @nodoc
class __$SchemeRedemptionCopyWithImpl<$Res>
    implements _$SchemeRedemptionCopyWith<$Res> {
  __$SchemeRedemptionCopyWithImpl(this._self, this._then);

  final _SchemeRedemption _self;
  final $Res Function(_SchemeRedemption) _then;

/// Create a copy of SchemeRedemption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? redemptionDate = null,Object? totalAmountPaisa = null,Object? bonusAmountPaisa = freezed,Object? discountAmountPaisa = freezed,Object? finalAmountPaisa = freezed,Object? goldWeightGrams = freezed,Object? goldRateAtRedemptionPaisa = freezed,Object? purity = freezed,Object? productId = freezed,Object? productName = freezed,Object? invoiceId = freezed,Object? bankAccountNumber = freezed,Object? bankIfsc = freezed,Object? upiId = freezed,Object? payoutDate = freezed,Object? notes = freezed,Object? processedBy = freezed,}) {
  return _then(_SchemeRedemption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RedemptionType,redemptionDate: null == redemptionDate ? _self.redemptionDate : redemptionDate // ignore: cast_nullable_to_non_nullable
as DateTime,totalAmountPaisa: null == totalAmountPaisa ? _self.totalAmountPaisa : totalAmountPaisa // ignore: cast_nullable_to_non_nullable
as int,bonusAmountPaisa: freezed == bonusAmountPaisa ? _self.bonusAmountPaisa : bonusAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,discountAmountPaisa: freezed == discountAmountPaisa ? _self.discountAmountPaisa : discountAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,finalAmountPaisa: freezed == finalAmountPaisa ? _self.finalAmountPaisa : finalAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,goldWeightGrams: freezed == goldWeightGrams ? _self.goldWeightGrams : goldWeightGrams // ignore: cast_nullable_to_non_nullable
as double?,goldRateAtRedemptionPaisa: freezed == goldRateAtRedemptionPaisa ? _self.goldRateAtRedemptionPaisa : goldRateAtRedemptionPaisa // ignore: cast_nullable_to_non_nullable
as double?,purity: freezed == purity ? _self.purity : purity // ignore: cast_nullable_to_non_nullable
as String?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,bankAccountNumber: freezed == bankAccountNumber ? _self.bankAccountNumber : bankAccountNumber // ignore: cast_nullable_to_non_nullable
as String?,bankIfsc: freezed == bankIfsc ? _self.bankIfsc : bankIfsc // ignore: cast_nullable_to_non_nullable
as String?,upiId: freezed == upiId ? _self.upiId : upiId // ignore: cast_nullable_to_non_nullable
as String?,payoutDate: freezed == payoutDate ? _self.payoutDate : payoutDate // ignore: cast_nullable_to_non_nullable
as DateTime?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,processedBy: freezed == processedBy ? _self.processedBy : processedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GoldScheme {

// Core identifiers
@HiveField(0) String get id;@HiveField(1) String get tenantId;@HiveField(2) String get schemeNumber;// e.g., GS-2024-0001
// Customer info
@HiveField(3) String get customerId;@HiveField(4) String get customerName;@HiveField(5) String? get customerPhone;@HiveField(6) String? get customerEmail;@HiveField(7) String? get customerAddress;// Scheme configuration
@HiveField(8) String get schemeName;@HiveField(9) String? get schemeDescription;@HiveField(10) int get installmentAmountPaisa;@HiveField(11) int get totalInstallments;@HiveField(12) PaymentFrequency get frequency;@HiveField(13) int? get minimumInstallmentsForRedemption;// Bonus/Vendor contribution
@HiveField(14) int? get vendorBonusPaisa;// Jeweller contributes this amount
@HiveField(15) double? get bonusPercentage;// Or as percentage
@HiveField(16) String? get bonusDescription;// "Pay for 11 months, get 12th free"
// Gold-linked scheme (optional)
@HiveField(17) bool get isGoldLinked;@HiveField(18) MetalType? get linkedMetalType;@HiveField(19) List<GoldWeightRecord>? get goldWeightHistory;// Current status
@HiveField(20) SchemeStatus get status;@HiveField(21) DateTime get startDate;@HiveField(22) DateTime? get endDate;@HiveField(23) DateTime? get promisedRedemptionDate;// Payments
@HiveField(24) List<SchemePayment> get payments;@HiveField(25) int get completedInstallments;@HiveField(26) int get missedInstallments;@HiveField(27) int get lateInstallments;// Financial summary
@HiveField(28) int get totalPaidPaisa;@HiveField(29) int get totalLateFeesPaisa;@HiveField(30) int? get accumulatedGoldWeightGrams;// For gold-linked schemes
// Redemption
@HiveField(31) SchemeRedemption? get redemption;@HiveField(32) RedemptionType? get plannedRedemptionType;// Defaults handling
@HiveField(33) int? get defaultAfterMissedInstallments;@HiveField(34) int? get foreclosureChargePercent;@HiveField(35) DateTime? get defaultedDate;@HiveField(36) String? get defaultReason;// Cancellation
@HiveField(37) DateTime? get cancelledDate;@HiveField(38) String? get cancellationReason;@HiveField(39) int? get cancellationChargesPaisa;@HiveField(40) int? get refundAmountPaisa;// Referral
@HiveField(41) String? get referredByCustomerId;@HiveField(42) String? get referralCode;// Metadata
@HiveField(43) DateTime get createdAt;@HiveField(44) String get createdBy;@HiveField(45) DateTime get updatedAt;@HiveField(46) String get updatedBy;// Sync
@HiveField(47) bool get synced;@HiveField(48) DateTime? get lastSyncedAt;@HiveField(49) String? get pendingOperation;
/// Create a copy of GoldScheme
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoldSchemeCopyWith<GoldScheme> get copyWith => _$GoldSchemeCopyWithImpl<GoldScheme>(this as GoldScheme, _$identity);

  /// Serializes this GoldScheme to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoldScheme&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.schemeNumber, schemeNumber) || other.schemeNumber == schemeNumber)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerEmail, customerEmail) || other.customerEmail == customerEmail)&&(identical(other.customerAddress, customerAddress) || other.customerAddress == customerAddress)&&(identical(other.schemeName, schemeName) || other.schemeName == schemeName)&&(identical(other.schemeDescription, schemeDescription) || other.schemeDescription == schemeDescription)&&(identical(other.installmentAmountPaisa, installmentAmountPaisa) || other.installmentAmountPaisa == installmentAmountPaisa)&&(identical(other.totalInstallments, totalInstallments) || other.totalInstallments == totalInstallments)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.minimumInstallmentsForRedemption, minimumInstallmentsForRedemption) || other.minimumInstallmentsForRedemption == minimumInstallmentsForRedemption)&&(identical(other.vendorBonusPaisa, vendorBonusPaisa) || other.vendorBonusPaisa == vendorBonusPaisa)&&(identical(other.bonusPercentage, bonusPercentage) || other.bonusPercentage == bonusPercentage)&&(identical(other.bonusDescription, bonusDescription) || other.bonusDescription == bonusDescription)&&(identical(other.isGoldLinked, isGoldLinked) || other.isGoldLinked == isGoldLinked)&&(identical(other.linkedMetalType, linkedMetalType) || other.linkedMetalType == linkedMetalType)&&const DeepCollectionEquality().equals(other.goldWeightHistory, goldWeightHistory)&&(identical(other.status, status) || other.status == status)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.promisedRedemptionDate, promisedRedemptionDate) || other.promisedRedemptionDate == promisedRedemptionDate)&&const DeepCollectionEquality().equals(other.payments, payments)&&(identical(other.completedInstallments, completedInstallments) || other.completedInstallments == completedInstallments)&&(identical(other.missedInstallments, missedInstallments) || other.missedInstallments == missedInstallments)&&(identical(other.lateInstallments, lateInstallments) || other.lateInstallments == lateInstallments)&&(identical(other.totalPaidPaisa, totalPaidPaisa) || other.totalPaidPaisa == totalPaidPaisa)&&(identical(other.totalLateFeesPaisa, totalLateFeesPaisa) || other.totalLateFeesPaisa == totalLateFeesPaisa)&&(identical(other.accumulatedGoldWeightGrams, accumulatedGoldWeightGrams) || other.accumulatedGoldWeightGrams == accumulatedGoldWeightGrams)&&(identical(other.redemption, redemption) || other.redemption == redemption)&&(identical(other.plannedRedemptionType, plannedRedemptionType) || other.plannedRedemptionType == plannedRedemptionType)&&(identical(other.defaultAfterMissedInstallments, defaultAfterMissedInstallments) || other.defaultAfterMissedInstallments == defaultAfterMissedInstallments)&&(identical(other.foreclosureChargePercent, foreclosureChargePercent) || other.foreclosureChargePercent == foreclosureChargePercent)&&(identical(other.defaultedDate, defaultedDate) || other.defaultedDate == defaultedDate)&&(identical(other.defaultReason, defaultReason) || other.defaultReason == defaultReason)&&(identical(other.cancelledDate, cancelledDate) || other.cancelledDate == cancelledDate)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.cancellationChargesPaisa, cancellationChargesPaisa) || other.cancellationChargesPaisa == cancellationChargesPaisa)&&(identical(other.refundAmountPaisa, refundAmountPaisa) || other.refundAmountPaisa == refundAmountPaisa)&&(identical(other.referredByCustomerId, referredByCustomerId) || other.referredByCustomerId == referredByCustomerId)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,schemeNumber,customerId,customerName,customerPhone,customerEmail,customerAddress,schemeName,schemeDescription,installmentAmountPaisa,totalInstallments,frequency,minimumInstallmentsForRedemption,vendorBonusPaisa,bonusPercentage,bonusDescription,isGoldLinked,linkedMetalType,const DeepCollectionEquality().hash(goldWeightHistory),status,startDate,endDate,promisedRedemptionDate,const DeepCollectionEquality().hash(payments),completedInstallments,missedInstallments,lateInstallments,totalPaidPaisa,totalLateFeesPaisa,accumulatedGoldWeightGrams,redemption,plannedRedemptionType,defaultAfterMissedInstallments,foreclosureChargePercent,defaultedDate,defaultReason,cancelledDate,cancellationReason,cancellationChargesPaisa,refundAmountPaisa,referredByCustomerId,referralCode,createdAt,createdBy,updatedAt,updatedBy,synced,lastSyncedAt,pendingOperation]);

@override
String toString() {
  return 'GoldScheme(id: $id, tenantId: $tenantId, schemeNumber: $schemeNumber, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, customerEmail: $customerEmail, customerAddress: $customerAddress, schemeName: $schemeName, schemeDescription: $schemeDescription, installmentAmountPaisa: $installmentAmountPaisa, totalInstallments: $totalInstallments, frequency: $frequency, minimumInstallmentsForRedemption: $minimumInstallmentsForRedemption, vendorBonusPaisa: $vendorBonusPaisa, bonusPercentage: $bonusPercentage, bonusDescription: $bonusDescription, isGoldLinked: $isGoldLinked, linkedMetalType: $linkedMetalType, goldWeightHistory: $goldWeightHistory, status: $status, startDate: $startDate, endDate: $endDate, promisedRedemptionDate: $promisedRedemptionDate, payments: $payments, completedInstallments: $completedInstallments, missedInstallments: $missedInstallments, lateInstallments: $lateInstallments, totalPaidPaisa: $totalPaidPaisa, totalLateFeesPaisa: $totalLateFeesPaisa, accumulatedGoldWeightGrams: $accumulatedGoldWeightGrams, redemption: $redemption, plannedRedemptionType: $plannedRedemptionType, defaultAfterMissedInstallments: $defaultAfterMissedInstallments, foreclosureChargePercent: $foreclosureChargePercent, defaultedDate: $defaultedDate, defaultReason: $defaultReason, cancelledDate: $cancelledDate, cancellationReason: $cancellationReason, cancellationChargesPaisa: $cancellationChargesPaisa, refundAmountPaisa: $refundAmountPaisa, referredByCustomerId: $referredByCustomerId, referralCode: $referralCode, createdAt: $createdAt, createdBy: $createdBy, updatedAt: $updatedAt, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class $GoldSchemeCopyWith<$Res>  {
  factory $GoldSchemeCopyWith(GoldScheme value, $Res Function(GoldScheme) _then) = _$GoldSchemeCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String schemeNumber,@HiveField(3) String customerId,@HiveField(4) String customerName,@HiveField(5) String? customerPhone,@HiveField(6) String? customerEmail,@HiveField(7) String? customerAddress,@HiveField(8) String schemeName,@HiveField(9) String? schemeDescription,@HiveField(10) int installmentAmountPaisa,@HiveField(11) int totalInstallments,@HiveField(12) PaymentFrequency frequency,@HiveField(13) int? minimumInstallmentsForRedemption,@HiveField(14) int? vendorBonusPaisa,@HiveField(15) double? bonusPercentage,@HiveField(16) String? bonusDescription,@HiveField(17) bool isGoldLinked,@HiveField(18) MetalType? linkedMetalType,@HiveField(19) List<GoldWeightRecord>? goldWeightHistory,@HiveField(20) SchemeStatus status,@HiveField(21) DateTime startDate,@HiveField(22) DateTime? endDate,@HiveField(23) DateTime? promisedRedemptionDate,@HiveField(24) List<SchemePayment> payments,@HiveField(25) int completedInstallments,@HiveField(26) int missedInstallments,@HiveField(27) int lateInstallments,@HiveField(28) int totalPaidPaisa,@HiveField(29) int totalLateFeesPaisa,@HiveField(30) int? accumulatedGoldWeightGrams,@HiveField(31) SchemeRedemption? redemption,@HiveField(32) RedemptionType? plannedRedemptionType,@HiveField(33) int? defaultAfterMissedInstallments,@HiveField(34) int? foreclosureChargePercent,@HiveField(35) DateTime? defaultedDate,@HiveField(36) String? defaultReason,@HiveField(37) DateTime? cancelledDate,@HiveField(38) String? cancellationReason,@HiveField(39) int? cancellationChargesPaisa,@HiveField(40) int? refundAmountPaisa,@HiveField(41) String? referredByCustomerId,@HiveField(42) String? referralCode,@HiveField(43) DateTime createdAt,@HiveField(44) String createdBy,@HiveField(45) DateTime updatedAt,@HiveField(46) String updatedBy,@HiveField(47) bool synced,@HiveField(48) DateTime? lastSyncedAt,@HiveField(49) String? pendingOperation
});


$SchemeRedemptionCopyWith<$Res>? get redemption;

}
/// @nodoc
class _$GoldSchemeCopyWithImpl<$Res>
    implements $GoldSchemeCopyWith<$Res> {
  _$GoldSchemeCopyWithImpl(this._self, this._then);

  final GoldScheme _self;
  final $Res Function(GoldScheme) _then;

/// Create a copy of GoldScheme
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? schemeNumber = null,Object? customerId = null,Object? customerName = null,Object? customerPhone = freezed,Object? customerEmail = freezed,Object? customerAddress = freezed,Object? schemeName = null,Object? schemeDescription = freezed,Object? installmentAmountPaisa = null,Object? totalInstallments = null,Object? frequency = null,Object? minimumInstallmentsForRedemption = freezed,Object? vendorBonusPaisa = freezed,Object? bonusPercentage = freezed,Object? bonusDescription = freezed,Object? isGoldLinked = null,Object? linkedMetalType = freezed,Object? goldWeightHistory = freezed,Object? status = null,Object? startDate = null,Object? endDate = freezed,Object? promisedRedemptionDate = freezed,Object? payments = null,Object? completedInstallments = null,Object? missedInstallments = null,Object? lateInstallments = null,Object? totalPaidPaisa = null,Object? totalLateFeesPaisa = null,Object? accumulatedGoldWeightGrams = freezed,Object? redemption = freezed,Object? plannedRedemptionType = freezed,Object? defaultAfterMissedInstallments = freezed,Object? foreclosureChargePercent = freezed,Object? defaultedDate = freezed,Object? defaultReason = freezed,Object? cancelledDate = freezed,Object? cancellationReason = freezed,Object? cancellationChargesPaisa = freezed,Object? refundAmountPaisa = freezed,Object? referredByCustomerId = freezed,Object? referralCode = freezed,Object? createdAt = null,Object? createdBy = null,Object? updatedAt = null,Object? updatedBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,schemeNumber: null == schemeNumber ? _self.schemeNumber : schemeNumber // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerEmail: freezed == customerEmail ? _self.customerEmail : customerEmail // ignore: cast_nullable_to_non_nullable
as String?,customerAddress: freezed == customerAddress ? _self.customerAddress : customerAddress // ignore: cast_nullable_to_non_nullable
as String?,schemeName: null == schemeName ? _self.schemeName : schemeName // ignore: cast_nullable_to_non_nullable
as String,schemeDescription: freezed == schemeDescription ? _self.schemeDescription : schemeDescription // ignore: cast_nullable_to_non_nullable
as String?,installmentAmountPaisa: null == installmentAmountPaisa ? _self.installmentAmountPaisa : installmentAmountPaisa // ignore: cast_nullable_to_non_nullable
as int,totalInstallments: null == totalInstallments ? _self.totalInstallments : totalInstallments // ignore: cast_nullable_to_non_nullable
as int,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as PaymentFrequency,minimumInstallmentsForRedemption: freezed == minimumInstallmentsForRedemption ? _self.minimumInstallmentsForRedemption : minimumInstallmentsForRedemption // ignore: cast_nullable_to_non_nullable
as int?,vendorBonusPaisa: freezed == vendorBonusPaisa ? _self.vendorBonusPaisa : vendorBonusPaisa // ignore: cast_nullable_to_non_nullable
as int?,bonusPercentage: freezed == bonusPercentage ? _self.bonusPercentage : bonusPercentage // ignore: cast_nullable_to_non_nullable
as double?,bonusDescription: freezed == bonusDescription ? _self.bonusDescription : bonusDescription // ignore: cast_nullable_to_non_nullable
as String?,isGoldLinked: null == isGoldLinked ? _self.isGoldLinked : isGoldLinked // ignore: cast_nullable_to_non_nullable
as bool,linkedMetalType: freezed == linkedMetalType ? _self.linkedMetalType : linkedMetalType // ignore: cast_nullable_to_non_nullable
as MetalType?,goldWeightHistory: freezed == goldWeightHistory ? _self.goldWeightHistory : goldWeightHistory // ignore: cast_nullable_to_non_nullable
as List<GoldWeightRecord>?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SchemeStatus,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,promisedRedemptionDate: freezed == promisedRedemptionDate ? _self.promisedRedemptionDate : promisedRedemptionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,payments: null == payments ? _self.payments : payments // ignore: cast_nullable_to_non_nullable
as List<SchemePayment>,completedInstallments: null == completedInstallments ? _self.completedInstallments : completedInstallments // ignore: cast_nullable_to_non_nullable
as int,missedInstallments: null == missedInstallments ? _self.missedInstallments : missedInstallments // ignore: cast_nullable_to_non_nullable
as int,lateInstallments: null == lateInstallments ? _self.lateInstallments : lateInstallments // ignore: cast_nullable_to_non_nullable
as int,totalPaidPaisa: null == totalPaidPaisa ? _self.totalPaidPaisa : totalPaidPaisa // ignore: cast_nullable_to_non_nullable
as int,totalLateFeesPaisa: null == totalLateFeesPaisa ? _self.totalLateFeesPaisa : totalLateFeesPaisa // ignore: cast_nullable_to_non_nullable
as int,accumulatedGoldWeightGrams: freezed == accumulatedGoldWeightGrams ? _self.accumulatedGoldWeightGrams : accumulatedGoldWeightGrams // ignore: cast_nullable_to_non_nullable
as int?,redemption: freezed == redemption ? _self.redemption : redemption // ignore: cast_nullable_to_non_nullable
as SchemeRedemption?,plannedRedemptionType: freezed == plannedRedemptionType ? _self.plannedRedemptionType : plannedRedemptionType // ignore: cast_nullable_to_non_nullable
as RedemptionType?,defaultAfterMissedInstallments: freezed == defaultAfterMissedInstallments ? _self.defaultAfterMissedInstallments : defaultAfterMissedInstallments // ignore: cast_nullable_to_non_nullable
as int?,foreclosureChargePercent: freezed == foreclosureChargePercent ? _self.foreclosureChargePercent : foreclosureChargePercent // ignore: cast_nullable_to_non_nullable
as int?,defaultedDate: freezed == defaultedDate ? _self.defaultedDate : defaultedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,defaultReason: freezed == defaultReason ? _self.defaultReason : defaultReason // ignore: cast_nullable_to_non_nullable
as String?,cancelledDate: freezed == cancelledDate ? _self.cancelledDate : cancelledDate // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,cancellationChargesPaisa: freezed == cancellationChargesPaisa ? _self.cancellationChargesPaisa : cancellationChargesPaisa // ignore: cast_nullable_to_non_nullable
as int?,refundAmountPaisa: freezed == refundAmountPaisa ? _self.refundAmountPaisa : refundAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,referredByCustomerId: freezed == referredByCustomerId ? _self.referredByCustomerId : referredByCustomerId // ignore: cast_nullable_to_non_nullable
as String?,referralCode: freezed == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
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
/// Create a copy of GoldScheme
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SchemeRedemptionCopyWith<$Res>? get redemption {
    if (_self.redemption == null) {
    return null;
  }

  return $SchemeRedemptionCopyWith<$Res>(_self.redemption!, (value) {
    return _then(_self.copyWith(redemption: value));
  });
}
}


/// Adds pattern-matching-related methods to [GoldScheme].
extension GoldSchemePatterns on GoldScheme {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoldScheme value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoldScheme() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoldScheme value)  $default,){
final _that = this;
switch (_that) {
case _GoldScheme():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoldScheme value)?  $default,){
final _that = this;
switch (_that) {
case _GoldScheme() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String schemeNumber, @HiveField(3)  String customerId, @HiveField(4)  String customerName, @HiveField(5)  String? customerPhone, @HiveField(6)  String? customerEmail, @HiveField(7)  String? customerAddress, @HiveField(8)  String schemeName, @HiveField(9)  String? schemeDescription, @HiveField(10)  int installmentAmountPaisa, @HiveField(11)  int totalInstallments, @HiveField(12)  PaymentFrequency frequency, @HiveField(13)  int? minimumInstallmentsForRedemption, @HiveField(14)  int? vendorBonusPaisa, @HiveField(15)  double? bonusPercentage, @HiveField(16)  String? bonusDescription, @HiveField(17)  bool isGoldLinked, @HiveField(18)  MetalType? linkedMetalType, @HiveField(19)  List<GoldWeightRecord>? goldWeightHistory, @HiveField(20)  SchemeStatus status, @HiveField(21)  DateTime startDate, @HiveField(22)  DateTime? endDate, @HiveField(23)  DateTime? promisedRedemptionDate, @HiveField(24)  List<SchemePayment> payments, @HiveField(25)  int completedInstallments, @HiveField(26)  int missedInstallments, @HiveField(27)  int lateInstallments, @HiveField(28)  int totalPaidPaisa, @HiveField(29)  int totalLateFeesPaisa, @HiveField(30)  int? accumulatedGoldWeightGrams, @HiveField(31)  SchemeRedemption? redemption, @HiveField(32)  RedemptionType? plannedRedemptionType, @HiveField(33)  int? defaultAfterMissedInstallments, @HiveField(34)  int? foreclosureChargePercent, @HiveField(35)  DateTime? defaultedDate, @HiveField(36)  String? defaultReason, @HiveField(37)  DateTime? cancelledDate, @HiveField(38)  String? cancellationReason, @HiveField(39)  int? cancellationChargesPaisa, @HiveField(40)  int? refundAmountPaisa, @HiveField(41)  String? referredByCustomerId, @HiveField(42)  String? referralCode, @HiveField(43)  DateTime createdAt, @HiveField(44)  String createdBy, @HiveField(45)  DateTime updatedAt, @HiveField(46)  String updatedBy, @HiveField(47)  bool synced, @HiveField(48)  DateTime? lastSyncedAt, @HiveField(49)  String? pendingOperation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoldScheme() when $default != null:
return $default(_that.id,_that.tenantId,_that.schemeNumber,_that.customerId,_that.customerName,_that.customerPhone,_that.customerEmail,_that.customerAddress,_that.schemeName,_that.schemeDescription,_that.installmentAmountPaisa,_that.totalInstallments,_that.frequency,_that.minimumInstallmentsForRedemption,_that.vendorBonusPaisa,_that.bonusPercentage,_that.bonusDescription,_that.isGoldLinked,_that.linkedMetalType,_that.goldWeightHistory,_that.status,_that.startDate,_that.endDate,_that.promisedRedemptionDate,_that.payments,_that.completedInstallments,_that.missedInstallments,_that.lateInstallments,_that.totalPaidPaisa,_that.totalLateFeesPaisa,_that.accumulatedGoldWeightGrams,_that.redemption,_that.plannedRedemptionType,_that.defaultAfterMissedInstallments,_that.foreclosureChargePercent,_that.defaultedDate,_that.defaultReason,_that.cancelledDate,_that.cancellationReason,_that.cancellationChargesPaisa,_that.refundAmountPaisa,_that.referredByCustomerId,_that.referralCode,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String schemeNumber, @HiveField(3)  String customerId, @HiveField(4)  String customerName, @HiveField(5)  String? customerPhone, @HiveField(6)  String? customerEmail, @HiveField(7)  String? customerAddress, @HiveField(8)  String schemeName, @HiveField(9)  String? schemeDescription, @HiveField(10)  int installmentAmountPaisa, @HiveField(11)  int totalInstallments, @HiveField(12)  PaymentFrequency frequency, @HiveField(13)  int? minimumInstallmentsForRedemption, @HiveField(14)  int? vendorBonusPaisa, @HiveField(15)  double? bonusPercentage, @HiveField(16)  String? bonusDescription, @HiveField(17)  bool isGoldLinked, @HiveField(18)  MetalType? linkedMetalType, @HiveField(19)  List<GoldWeightRecord>? goldWeightHistory, @HiveField(20)  SchemeStatus status, @HiveField(21)  DateTime startDate, @HiveField(22)  DateTime? endDate, @HiveField(23)  DateTime? promisedRedemptionDate, @HiveField(24)  List<SchemePayment> payments, @HiveField(25)  int completedInstallments, @HiveField(26)  int missedInstallments, @HiveField(27)  int lateInstallments, @HiveField(28)  int totalPaidPaisa, @HiveField(29)  int totalLateFeesPaisa, @HiveField(30)  int? accumulatedGoldWeightGrams, @HiveField(31)  SchemeRedemption? redemption, @HiveField(32)  RedemptionType? plannedRedemptionType, @HiveField(33)  int? defaultAfterMissedInstallments, @HiveField(34)  int? foreclosureChargePercent, @HiveField(35)  DateTime? defaultedDate, @HiveField(36)  String? defaultReason, @HiveField(37)  DateTime? cancelledDate, @HiveField(38)  String? cancellationReason, @HiveField(39)  int? cancellationChargesPaisa, @HiveField(40)  int? refundAmountPaisa, @HiveField(41)  String? referredByCustomerId, @HiveField(42)  String? referralCode, @HiveField(43)  DateTime createdAt, @HiveField(44)  String createdBy, @HiveField(45)  DateTime updatedAt, @HiveField(46)  String updatedBy, @HiveField(47)  bool synced, @HiveField(48)  DateTime? lastSyncedAt, @HiveField(49)  String? pendingOperation)  $default,) {final _that = this;
switch (_that) {
case _GoldScheme():
return $default(_that.id,_that.tenantId,_that.schemeNumber,_that.customerId,_that.customerName,_that.customerPhone,_that.customerEmail,_that.customerAddress,_that.schemeName,_that.schemeDescription,_that.installmentAmountPaisa,_that.totalInstallments,_that.frequency,_that.minimumInstallmentsForRedemption,_that.vendorBonusPaisa,_that.bonusPercentage,_that.bonusDescription,_that.isGoldLinked,_that.linkedMetalType,_that.goldWeightHistory,_that.status,_that.startDate,_that.endDate,_that.promisedRedemptionDate,_that.payments,_that.completedInstallments,_that.missedInstallments,_that.lateInstallments,_that.totalPaidPaisa,_that.totalLateFeesPaisa,_that.accumulatedGoldWeightGrams,_that.redemption,_that.plannedRedemptionType,_that.defaultAfterMissedInstallments,_that.foreclosureChargePercent,_that.defaultedDate,_that.defaultReason,_that.cancelledDate,_that.cancellationReason,_that.cancellationChargesPaisa,_that.refundAmountPaisa,_that.referredByCustomerId,_that.referralCode,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String schemeNumber, @HiveField(3)  String customerId, @HiveField(4)  String customerName, @HiveField(5)  String? customerPhone, @HiveField(6)  String? customerEmail, @HiveField(7)  String? customerAddress, @HiveField(8)  String schemeName, @HiveField(9)  String? schemeDescription, @HiveField(10)  int installmentAmountPaisa, @HiveField(11)  int totalInstallments, @HiveField(12)  PaymentFrequency frequency, @HiveField(13)  int? minimumInstallmentsForRedemption, @HiveField(14)  int? vendorBonusPaisa, @HiveField(15)  double? bonusPercentage, @HiveField(16)  String? bonusDescription, @HiveField(17)  bool isGoldLinked, @HiveField(18)  MetalType? linkedMetalType, @HiveField(19)  List<GoldWeightRecord>? goldWeightHistory, @HiveField(20)  SchemeStatus status, @HiveField(21)  DateTime startDate, @HiveField(22)  DateTime? endDate, @HiveField(23)  DateTime? promisedRedemptionDate, @HiveField(24)  List<SchemePayment> payments, @HiveField(25)  int completedInstallments, @HiveField(26)  int missedInstallments, @HiveField(27)  int lateInstallments, @HiveField(28)  int totalPaidPaisa, @HiveField(29)  int totalLateFeesPaisa, @HiveField(30)  int? accumulatedGoldWeightGrams, @HiveField(31)  SchemeRedemption? redemption, @HiveField(32)  RedemptionType? plannedRedemptionType, @HiveField(33)  int? defaultAfterMissedInstallments, @HiveField(34)  int? foreclosureChargePercent, @HiveField(35)  DateTime? defaultedDate, @HiveField(36)  String? defaultReason, @HiveField(37)  DateTime? cancelledDate, @HiveField(38)  String? cancellationReason, @HiveField(39)  int? cancellationChargesPaisa, @HiveField(40)  int? refundAmountPaisa, @HiveField(41)  String? referredByCustomerId, @HiveField(42)  String? referralCode, @HiveField(43)  DateTime createdAt, @HiveField(44)  String createdBy, @HiveField(45)  DateTime updatedAt, @HiveField(46)  String updatedBy, @HiveField(47)  bool synced, @HiveField(48)  DateTime? lastSyncedAt, @HiveField(49)  String? pendingOperation)?  $default,) {final _that = this;
switch (_that) {
case _GoldScheme() when $default != null:
return $default(_that.id,_that.tenantId,_that.schemeNumber,_that.customerId,_that.customerName,_that.customerPhone,_that.customerEmail,_that.customerAddress,_that.schemeName,_that.schemeDescription,_that.installmentAmountPaisa,_that.totalInstallments,_that.frequency,_that.minimumInstallmentsForRedemption,_that.vendorBonusPaisa,_that.bonusPercentage,_that.bonusDescription,_that.isGoldLinked,_that.linkedMetalType,_that.goldWeightHistory,_that.status,_that.startDate,_that.endDate,_that.promisedRedemptionDate,_that.payments,_that.completedInstallments,_that.missedInstallments,_that.lateInstallments,_that.totalPaidPaisa,_that.totalLateFeesPaisa,_that.accumulatedGoldWeightGrams,_that.redemption,_that.plannedRedemptionType,_that.defaultAfterMissedInstallments,_that.foreclosureChargePercent,_that.defaultedDate,_that.defaultReason,_that.cancelledDate,_that.cancellationReason,_that.cancellationChargesPaisa,_that.refundAmountPaisa,_that.referredByCustomerId,_that.referralCode,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 69)
class _GoldScheme extends GoldScheme {
  const _GoldScheme({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.schemeNumber, @HiveField(3) required this.customerId, @HiveField(4) required this.customerName, @HiveField(5) this.customerPhone, @HiveField(6) this.customerEmail, @HiveField(7) this.customerAddress, @HiveField(8) required this.schemeName, @HiveField(9) this.schemeDescription, @HiveField(10) required this.installmentAmountPaisa, @HiveField(11) required this.totalInstallments, @HiveField(12) this.frequency = PaymentFrequency.monthly, @HiveField(13) this.minimumInstallmentsForRedemption, @HiveField(14) this.vendorBonusPaisa, @HiveField(15) this.bonusPercentage, @HiveField(16) this.bonusDescription, @HiveField(17) this.isGoldLinked = false, @HiveField(18) this.linkedMetalType, @HiveField(19) final  List<GoldWeightRecord>? goldWeightHistory, @HiveField(20) this.status = SchemeStatus.active, @HiveField(21) required this.startDate, @HiveField(22) this.endDate, @HiveField(23) this.promisedRedemptionDate, @HiveField(24) required final  List<SchemePayment> payments, @HiveField(25) this.completedInstallments = 0, @HiveField(26) this.missedInstallments = 0, @HiveField(27) this.lateInstallments = 0, @HiveField(28) this.totalPaidPaisa = 0, @HiveField(29) this.totalLateFeesPaisa = 0, @HiveField(30) this.accumulatedGoldWeightGrams, @HiveField(31) this.redemption, @HiveField(32) this.plannedRedemptionType, @HiveField(33) this.defaultAfterMissedInstallments, @HiveField(34) this.foreclosureChargePercent, @HiveField(35) this.defaultedDate, @HiveField(36) this.defaultReason, @HiveField(37) this.cancelledDate, @HiveField(38) this.cancellationReason, @HiveField(39) this.cancellationChargesPaisa, @HiveField(40) this.refundAmountPaisa, @HiveField(41) this.referredByCustomerId, @HiveField(42) this.referralCode, @HiveField(43) required this.createdAt, @HiveField(44) required this.createdBy, @HiveField(45) required this.updatedAt, @HiveField(46) required this.updatedBy, @HiveField(47) this.synced = true, @HiveField(48) this.lastSyncedAt, @HiveField(49) this.pendingOperation}): _goldWeightHistory = goldWeightHistory,_payments = payments,super._();
  factory _GoldScheme.fromJson(Map<String, dynamic> json) => _$GoldSchemeFromJson(json);

// Core identifiers
@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
@override@HiveField(2) final  String schemeNumber;
// e.g., GS-2024-0001
// Customer info
@override@HiveField(3) final  String customerId;
@override@HiveField(4) final  String customerName;
@override@HiveField(5) final  String? customerPhone;
@override@HiveField(6) final  String? customerEmail;
@override@HiveField(7) final  String? customerAddress;
// Scheme configuration
@override@HiveField(8) final  String schemeName;
@override@HiveField(9) final  String? schemeDescription;
@override@HiveField(10) final  int installmentAmountPaisa;
@override@HiveField(11) final  int totalInstallments;
@override@JsonKey()@HiveField(12) final  PaymentFrequency frequency;
@override@HiveField(13) final  int? minimumInstallmentsForRedemption;
// Bonus/Vendor contribution
@override@HiveField(14) final  int? vendorBonusPaisa;
// Jeweller contributes this amount
@override@HiveField(15) final  double? bonusPercentage;
// Or as percentage
@override@HiveField(16) final  String? bonusDescription;
// "Pay for 11 months, get 12th free"
// Gold-linked scheme (optional)
@override@JsonKey()@HiveField(17) final  bool isGoldLinked;
@override@HiveField(18) final  MetalType? linkedMetalType;
 final  List<GoldWeightRecord>? _goldWeightHistory;
@override@HiveField(19) List<GoldWeightRecord>? get goldWeightHistory {
  final value = _goldWeightHistory;
  if (value == null) return null;
  if (_goldWeightHistory is EqualUnmodifiableListView) return _goldWeightHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Current status
@override@JsonKey()@HiveField(20) final  SchemeStatus status;
@override@HiveField(21) final  DateTime startDate;
@override@HiveField(22) final  DateTime? endDate;
@override@HiveField(23) final  DateTime? promisedRedemptionDate;
// Payments
 final  List<SchemePayment> _payments;
// Payments
@override@HiveField(24) List<SchemePayment> get payments {
  if (_payments is EqualUnmodifiableListView) return _payments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_payments);
}

@override@JsonKey()@HiveField(25) final  int completedInstallments;
@override@JsonKey()@HiveField(26) final  int missedInstallments;
@override@JsonKey()@HiveField(27) final  int lateInstallments;
// Financial summary
@override@JsonKey()@HiveField(28) final  int totalPaidPaisa;
@override@JsonKey()@HiveField(29) final  int totalLateFeesPaisa;
@override@HiveField(30) final  int? accumulatedGoldWeightGrams;
// For gold-linked schemes
// Redemption
@override@HiveField(31) final  SchemeRedemption? redemption;
@override@HiveField(32) final  RedemptionType? plannedRedemptionType;
// Defaults handling
@override@HiveField(33) final  int? defaultAfterMissedInstallments;
@override@HiveField(34) final  int? foreclosureChargePercent;
@override@HiveField(35) final  DateTime? defaultedDate;
@override@HiveField(36) final  String? defaultReason;
// Cancellation
@override@HiveField(37) final  DateTime? cancelledDate;
@override@HiveField(38) final  String? cancellationReason;
@override@HiveField(39) final  int? cancellationChargesPaisa;
@override@HiveField(40) final  int? refundAmountPaisa;
// Referral
@override@HiveField(41) final  String? referredByCustomerId;
@override@HiveField(42) final  String? referralCode;
// Metadata
@override@HiveField(43) final  DateTime createdAt;
@override@HiveField(44) final  String createdBy;
@override@HiveField(45) final  DateTime updatedAt;
@override@HiveField(46) final  String updatedBy;
// Sync
@override@JsonKey()@HiveField(47) final  bool synced;
@override@HiveField(48) final  DateTime? lastSyncedAt;
@override@HiveField(49) final  String? pendingOperation;

/// Create a copy of GoldScheme
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoldSchemeCopyWith<_GoldScheme> get copyWith => __$GoldSchemeCopyWithImpl<_GoldScheme>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoldSchemeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoldScheme&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.schemeNumber, schemeNumber) || other.schemeNumber == schemeNumber)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerEmail, customerEmail) || other.customerEmail == customerEmail)&&(identical(other.customerAddress, customerAddress) || other.customerAddress == customerAddress)&&(identical(other.schemeName, schemeName) || other.schemeName == schemeName)&&(identical(other.schemeDescription, schemeDescription) || other.schemeDescription == schemeDescription)&&(identical(other.installmentAmountPaisa, installmentAmountPaisa) || other.installmentAmountPaisa == installmentAmountPaisa)&&(identical(other.totalInstallments, totalInstallments) || other.totalInstallments == totalInstallments)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.minimumInstallmentsForRedemption, minimumInstallmentsForRedemption) || other.minimumInstallmentsForRedemption == minimumInstallmentsForRedemption)&&(identical(other.vendorBonusPaisa, vendorBonusPaisa) || other.vendorBonusPaisa == vendorBonusPaisa)&&(identical(other.bonusPercentage, bonusPercentage) || other.bonusPercentage == bonusPercentage)&&(identical(other.bonusDescription, bonusDescription) || other.bonusDescription == bonusDescription)&&(identical(other.isGoldLinked, isGoldLinked) || other.isGoldLinked == isGoldLinked)&&(identical(other.linkedMetalType, linkedMetalType) || other.linkedMetalType == linkedMetalType)&&const DeepCollectionEquality().equals(other._goldWeightHistory, _goldWeightHistory)&&(identical(other.status, status) || other.status == status)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.promisedRedemptionDate, promisedRedemptionDate) || other.promisedRedemptionDate == promisedRedemptionDate)&&const DeepCollectionEquality().equals(other._payments, _payments)&&(identical(other.completedInstallments, completedInstallments) || other.completedInstallments == completedInstallments)&&(identical(other.missedInstallments, missedInstallments) || other.missedInstallments == missedInstallments)&&(identical(other.lateInstallments, lateInstallments) || other.lateInstallments == lateInstallments)&&(identical(other.totalPaidPaisa, totalPaidPaisa) || other.totalPaidPaisa == totalPaidPaisa)&&(identical(other.totalLateFeesPaisa, totalLateFeesPaisa) || other.totalLateFeesPaisa == totalLateFeesPaisa)&&(identical(other.accumulatedGoldWeightGrams, accumulatedGoldWeightGrams) || other.accumulatedGoldWeightGrams == accumulatedGoldWeightGrams)&&(identical(other.redemption, redemption) || other.redemption == redemption)&&(identical(other.plannedRedemptionType, plannedRedemptionType) || other.plannedRedemptionType == plannedRedemptionType)&&(identical(other.defaultAfterMissedInstallments, defaultAfterMissedInstallments) || other.defaultAfterMissedInstallments == defaultAfterMissedInstallments)&&(identical(other.foreclosureChargePercent, foreclosureChargePercent) || other.foreclosureChargePercent == foreclosureChargePercent)&&(identical(other.defaultedDate, defaultedDate) || other.defaultedDate == defaultedDate)&&(identical(other.defaultReason, defaultReason) || other.defaultReason == defaultReason)&&(identical(other.cancelledDate, cancelledDate) || other.cancelledDate == cancelledDate)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.cancellationChargesPaisa, cancellationChargesPaisa) || other.cancellationChargesPaisa == cancellationChargesPaisa)&&(identical(other.refundAmountPaisa, refundAmountPaisa) || other.refundAmountPaisa == refundAmountPaisa)&&(identical(other.referredByCustomerId, referredByCustomerId) || other.referredByCustomerId == referredByCustomerId)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,schemeNumber,customerId,customerName,customerPhone,customerEmail,customerAddress,schemeName,schemeDescription,installmentAmountPaisa,totalInstallments,frequency,minimumInstallmentsForRedemption,vendorBonusPaisa,bonusPercentage,bonusDescription,isGoldLinked,linkedMetalType,const DeepCollectionEquality().hash(_goldWeightHistory),status,startDate,endDate,promisedRedemptionDate,const DeepCollectionEquality().hash(_payments),completedInstallments,missedInstallments,lateInstallments,totalPaidPaisa,totalLateFeesPaisa,accumulatedGoldWeightGrams,redemption,plannedRedemptionType,defaultAfterMissedInstallments,foreclosureChargePercent,defaultedDate,defaultReason,cancelledDate,cancellationReason,cancellationChargesPaisa,refundAmountPaisa,referredByCustomerId,referralCode,createdAt,createdBy,updatedAt,updatedBy,synced,lastSyncedAt,pendingOperation]);

@override
String toString() {
  return 'GoldScheme(id: $id, tenantId: $tenantId, schemeNumber: $schemeNumber, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, customerEmail: $customerEmail, customerAddress: $customerAddress, schemeName: $schemeName, schemeDescription: $schemeDescription, installmentAmountPaisa: $installmentAmountPaisa, totalInstallments: $totalInstallments, frequency: $frequency, minimumInstallmentsForRedemption: $minimumInstallmentsForRedemption, vendorBonusPaisa: $vendorBonusPaisa, bonusPercentage: $bonusPercentage, bonusDescription: $bonusDescription, isGoldLinked: $isGoldLinked, linkedMetalType: $linkedMetalType, goldWeightHistory: $goldWeightHistory, status: $status, startDate: $startDate, endDate: $endDate, promisedRedemptionDate: $promisedRedemptionDate, payments: $payments, completedInstallments: $completedInstallments, missedInstallments: $missedInstallments, lateInstallments: $lateInstallments, totalPaidPaisa: $totalPaidPaisa, totalLateFeesPaisa: $totalLateFeesPaisa, accumulatedGoldWeightGrams: $accumulatedGoldWeightGrams, redemption: $redemption, plannedRedemptionType: $plannedRedemptionType, defaultAfterMissedInstallments: $defaultAfterMissedInstallments, foreclosureChargePercent: $foreclosureChargePercent, defaultedDate: $defaultedDate, defaultReason: $defaultReason, cancelledDate: $cancelledDate, cancellationReason: $cancellationReason, cancellationChargesPaisa: $cancellationChargesPaisa, refundAmountPaisa: $refundAmountPaisa, referredByCustomerId: $referredByCustomerId, referralCode: $referralCode, createdAt: $createdAt, createdBy: $createdBy, updatedAt: $updatedAt, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class _$GoldSchemeCopyWith<$Res> implements $GoldSchemeCopyWith<$Res> {
  factory _$GoldSchemeCopyWith(_GoldScheme value, $Res Function(_GoldScheme) _then) = __$GoldSchemeCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String schemeNumber,@HiveField(3) String customerId,@HiveField(4) String customerName,@HiveField(5) String? customerPhone,@HiveField(6) String? customerEmail,@HiveField(7) String? customerAddress,@HiveField(8) String schemeName,@HiveField(9) String? schemeDescription,@HiveField(10) int installmentAmountPaisa,@HiveField(11) int totalInstallments,@HiveField(12) PaymentFrequency frequency,@HiveField(13) int? minimumInstallmentsForRedemption,@HiveField(14) int? vendorBonusPaisa,@HiveField(15) double? bonusPercentage,@HiveField(16) String? bonusDescription,@HiveField(17) bool isGoldLinked,@HiveField(18) MetalType? linkedMetalType,@HiveField(19) List<GoldWeightRecord>? goldWeightHistory,@HiveField(20) SchemeStatus status,@HiveField(21) DateTime startDate,@HiveField(22) DateTime? endDate,@HiveField(23) DateTime? promisedRedemptionDate,@HiveField(24) List<SchemePayment> payments,@HiveField(25) int completedInstallments,@HiveField(26) int missedInstallments,@HiveField(27) int lateInstallments,@HiveField(28) int totalPaidPaisa,@HiveField(29) int totalLateFeesPaisa,@HiveField(30) int? accumulatedGoldWeightGrams,@HiveField(31) SchemeRedemption? redemption,@HiveField(32) RedemptionType? plannedRedemptionType,@HiveField(33) int? defaultAfterMissedInstallments,@HiveField(34) int? foreclosureChargePercent,@HiveField(35) DateTime? defaultedDate,@HiveField(36) String? defaultReason,@HiveField(37) DateTime? cancelledDate,@HiveField(38) String? cancellationReason,@HiveField(39) int? cancellationChargesPaisa,@HiveField(40) int? refundAmountPaisa,@HiveField(41) String? referredByCustomerId,@HiveField(42) String? referralCode,@HiveField(43) DateTime createdAt,@HiveField(44) String createdBy,@HiveField(45) DateTime updatedAt,@HiveField(46) String updatedBy,@HiveField(47) bool synced,@HiveField(48) DateTime? lastSyncedAt,@HiveField(49) String? pendingOperation
});


@override $SchemeRedemptionCopyWith<$Res>? get redemption;

}
/// @nodoc
class __$GoldSchemeCopyWithImpl<$Res>
    implements _$GoldSchemeCopyWith<$Res> {
  __$GoldSchemeCopyWithImpl(this._self, this._then);

  final _GoldScheme _self;
  final $Res Function(_GoldScheme) _then;

/// Create a copy of GoldScheme
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? schemeNumber = null,Object? customerId = null,Object? customerName = null,Object? customerPhone = freezed,Object? customerEmail = freezed,Object? customerAddress = freezed,Object? schemeName = null,Object? schemeDescription = freezed,Object? installmentAmountPaisa = null,Object? totalInstallments = null,Object? frequency = null,Object? minimumInstallmentsForRedemption = freezed,Object? vendorBonusPaisa = freezed,Object? bonusPercentage = freezed,Object? bonusDescription = freezed,Object? isGoldLinked = null,Object? linkedMetalType = freezed,Object? goldWeightHistory = freezed,Object? status = null,Object? startDate = null,Object? endDate = freezed,Object? promisedRedemptionDate = freezed,Object? payments = null,Object? completedInstallments = null,Object? missedInstallments = null,Object? lateInstallments = null,Object? totalPaidPaisa = null,Object? totalLateFeesPaisa = null,Object? accumulatedGoldWeightGrams = freezed,Object? redemption = freezed,Object? plannedRedemptionType = freezed,Object? defaultAfterMissedInstallments = freezed,Object? foreclosureChargePercent = freezed,Object? defaultedDate = freezed,Object? defaultReason = freezed,Object? cancelledDate = freezed,Object? cancellationReason = freezed,Object? cancellationChargesPaisa = freezed,Object? refundAmountPaisa = freezed,Object? referredByCustomerId = freezed,Object? referralCode = freezed,Object? createdAt = null,Object? createdBy = null,Object? updatedAt = null,Object? updatedBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_GoldScheme(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,schemeNumber: null == schemeNumber ? _self.schemeNumber : schemeNumber // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerEmail: freezed == customerEmail ? _self.customerEmail : customerEmail // ignore: cast_nullable_to_non_nullable
as String?,customerAddress: freezed == customerAddress ? _self.customerAddress : customerAddress // ignore: cast_nullable_to_non_nullable
as String?,schemeName: null == schemeName ? _self.schemeName : schemeName // ignore: cast_nullable_to_non_nullable
as String,schemeDescription: freezed == schemeDescription ? _self.schemeDescription : schemeDescription // ignore: cast_nullable_to_non_nullable
as String?,installmentAmountPaisa: null == installmentAmountPaisa ? _self.installmentAmountPaisa : installmentAmountPaisa // ignore: cast_nullable_to_non_nullable
as int,totalInstallments: null == totalInstallments ? _self.totalInstallments : totalInstallments // ignore: cast_nullable_to_non_nullable
as int,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as PaymentFrequency,minimumInstallmentsForRedemption: freezed == minimumInstallmentsForRedemption ? _self.minimumInstallmentsForRedemption : minimumInstallmentsForRedemption // ignore: cast_nullable_to_non_nullable
as int?,vendorBonusPaisa: freezed == vendorBonusPaisa ? _self.vendorBonusPaisa : vendorBonusPaisa // ignore: cast_nullable_to_non_nullable
as int?,bonusPercentage: freezed == bonusPercentage ? _self.bonusPercentage : bonusPercentage // ignore: cast_nullable_to_non_nullable
as double?,bonusDescription: freezed == bonusDescription ? _self.bonusDescription : bonusDescription // ignore: cast_nullable_to_non_nullable
as String?,isGoldLinked: null == isGoldLinked ? _self.isGoldLinked : isGoldLinked // ignore: cast_nullable_to_non_nullable
as bool,linkedMetalType: freezed == linkedMetalType ? _self.linkedMetalType : linkedMetalType // ignore: cast_nullable_to_non_nullable
as MetalType?,goldWeightHistory: freezed == goldWeightHistory ? _self._goldWeightHistory : goldWeightHistory // ignore: cast_nullable_to_non_nullable
as List<GoldWeightRecord>?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SchemeStatus,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,promisedRedemptionDate: freezed == promisedRedemptionDate ? _self.promisedRedemptionDate : promisedRedemptionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,payments: null == payments ? _self._payments : payments // ignore: cast_nullable_to_non_nullable
as List<SchemePayment>,completedInstallments: null == completedInstallments ? _self.completedInstallments : completedInstallments // ignore: cast_nullable_to_non_nullable
as int,missedInstallments: null == missedInstallments ? _self.missedInstallments : missedInstallments // ignore: cast_nullable_to_non_nullable
as int,lateInstallments: null == lateInstallments ? _self.lateInstallments : lateInstallments // ignore: cast_nullable_to_non_nullable
as int,totalPaidPaisa: null == totalPaidPaisa ? _self.totalPaidPaisa : totalPaidPaisa // ignore: cast_nullable_to_non_nullable
as int,totalLateFeesPaisa: null == totalLateFeesPaisa ? _self.totalLateFeesPaisa : totalLateFeesPaisa // ignore: cast_nullable_to_non_nullable
as int,accumulatedGoldWeightGrams: freezed == accumulatedGoldWeightGrams ? _self.accumulatedGoldWeightGrams : accumulatedGoldWeightGrams // ignore: cast_nullable_to_non_nullable
as int?,redemption: freezed == redemption ? _self.redemption : redemption // ignore: cast_nullable_to_non_nullable
as SchemeRedemption?,plannedRedemptionType: freezed == plannedRedemptionType ? _self.plannedRedemptionType : plannedRedemptionType // ignore: cast_nullable_to_non_nullable
as RedemptionType?,defaultAfterMissedInstallments: freezed == defaultAfterMissedInstallments ? _self.defaultAfterMissedInstallments : defaultAfterMissedInstallments // ignore: cast_nullable_to_non_nullable
as int?,foreclosureChargePercent: freezed == foreclosureChargePercent ? _self.foreclosureChargePercent : foreclosureChargePercent // ignore: cast_nullable_to_non_nullable
as int?,defaultedDate: freezed == defaultedDate ? _self.defaultedDate : defaultedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,defaultReason: freezed == defaultReason ? _self.defaultReason : defaultReason // ignore: cast_nullable_to_non_nullable
as String?,cancelledDate: freezed == cancelledDate ? _self.cancelledDate : cancelledDate // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,cancellationChargesPaisa: freezed == cancellationChargesPaisa ? _self.cancellationChargesPaisa : cancellationChargesPaisa // ignore: cast_nullable_to_non_nullable
as int?,refundAmountPaisa: freezed == refundAmountPaisa ? _self.refundAmountPaisa : refundAmountPaisa // ignore: cast_nullable_to_non_nullable
as int?,referredByCustomerId: freezed == referredByCustomerId ? _self.referredByCustomerId : referredByCustomerId // ignore: cast_nullable_to_non_nullable
as String?,referralCode: freezed == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
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

/// Create a copy of GoldScheme
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SchemeRedemptionCopyWith<$Res>? get redemption {
    if (_self.redemption == null) {
    return null;
  }

  return $SchemeRedemptionCopyWith<$Res>(_self.redemption!, (value) {
    return _then(_self.copyWith(redemption: value));
  });
}
}


/// @nodoc
mixin _$SchemeTemplate {

@HiveField(0) String get id;@HiveField(1) String get name;@HiveField(2) String? get description;@HiveField(3) int get installmentAmountPaisa;@HiveField(4) int get totalInstallments;@HiveField(5) PaymentFrequency get frequency;@HiveField(6) int? get vendorBonusPaisa;@HiveField(7) double? get bonusPercentage;@HiveField(8) String? get bonusDescription;@HiveField(9) int? get minimumInstallmentsForRedemption;@HiveField(10) bool get isGoldLinked;@HiveField(11) MetalType? get linkedMetalType;@HiveField(12) int? get defaultAfterMissedInstallments;@HiveField(13) int? get foreclosureChargePercent;@HiveField(14) bool get isActive;
/// Create a copy of SchemeTemplate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchemeTemplateCopyWith<SchemeTemplate> get copyWith => _$SchemeTemplateCopyWithImpl<SchemeTemplate>(this as SchemeTemplate, _$identity);

  /// Serializes this SchemeTemplate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchemeTemplate&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.installmentAmountPaisa, installmentAmountPaisa) || other.installmentAmountPaisa == installmentAmountPaisa)&&(identical(other.totalInstallments, totalInstallments) || other.totalInstallments == totalInstallments)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.vendorBonusPaisa, vendorBonusPaisa) || other.vendorBonusPaisa == vendorBonusPaisa)&&(identical(other.bonusPercentage, bonusPercentage) || other.bonusPercentage == bonusPercentage)&&(identical(other.bonusDescription, bonusDescription) || other.bonusDescription == bonusDescription)&&(identical(other.minimumInstallmentsForRedemption, minimumInstallmentsForRedemption) || other.minimumInstallmentsForRedemption == minimumInstallmentsForRedemption)&&(identical(other.isGoldLinked, isGoldLinked) || other.isGoldLinked == isGoldLinked)&&(identical(other.linkedMetalType, linkedMetalType) || other.linkedMetalType == linkedMetalType)&&(identical(other.defaultAfterMissedInstallments, defaultAfterMissedInstallments) || other.defaultAfterMissedInstallments == defaultAfterMissedInstallments)&&(identical(other.foreclosureChargePercent, foreclosureChargePercent) || other.foreclosureChargePercent == foreclosureChargePercent)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,installmentAmountPaisa,totalInstallments,frequency,vendorBonusPaisa,bonusPercentage,bonusDescription,minimumInstallmentsForRedemption,isGoldLinked,linkedMetalType,defaultAfterMissedInstallments,foreclosureChargePercent,isActive);

@override
String toString() {
  return 'SchemeTemplate(id: $id, name: $name, description: $description, installmentAmountPaisa: $installmentAmountPaisa, totalInstallments: $totalInstallments, frequency: $frequency, vendorBonusPaisa: $vendorBonusPaisa, bonusPercentage: $bonusPercentage, bonusDescription: $bonusDescription, minimumInstallmentsForRedemption: $minimumInstallmentsForRedemption, isGoldLinked: $isGoldLinked, linkedMetalType: $linkedMetalType, defaultAfterMissedInstallments: $defaultAfterMissedInstallments, foreclosureChargePercent: $foreclosureChargePercent, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $SchemeTemplateCopyWith<$Res>  {
  factory $SchemeTemplateCopyWith(SchemeTemplate value, $Res Function(SchemeTemplate) _then) = _$SchemeTemplateCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String name,@HiveField(2) String? description,@HiveField(3) int installmentAmountPaisa,@HiveField(4) int totalInstallments,@HiveField(5) PaymentFrequency frequency,@HiveField(6) int? vendorBonusPaisa,@HiveField(7) double? bonusPercentage,@HiveField(8) String? bonusDescription,@HiveField(9) int? minimumInstallmentsForRedemption,@HiveField(10) bool isGoldLinked,@HiveField(11) MetalType? linkedMetalType,@HiveField(12) int? defaultAfterMissedInstallments,@HiveField(13) int? foreclosureChargePercent,@HiveField(14) bool isActive
});




}
/// @nodoc
class _$SchemeTemplateCopyWithImpl<$Res>
    implements $SchemeTemplateCopyWith<$Res> {
  _$SchemeTemplateCopyWithImpl(this._self, this._then);

  final SchemeTemplate _self;
  final $Res Function(SchemeTemplate) _then;

/// Create a copy of SchemeTemplate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? installmentAmountPaisa = null,Object? totalInstallments = null,Object? frequency = null,Object? vendorBonusPaisa = freezed,Object? bonusPercentage = freezed,Object? bonusDescription = freezed,Object? minimumInstallmentsForRedemption = freezed,Object? isGoldLinked = null,Object? linkedMetalType = freezed,Object? defaultAfterMissedInstallments = freezed,Object? foreclosureChargePercent = freezed,Object? isActive = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,installmentAmountPaisa: null == installmentAmountPaisa ? _self.installmentAmountPaisa : installmentAmountPaisa // ignore: cast_nullable_to_non_nullable
as int,totalInstallments: null == totalInstallments ? _self.totalInstallments : totalInstallments // ignore: cast_nullable_to_non_nullable
as int,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as PaymentFrequency,vendorBonusPaisa: freezed == vendorBonusPaisa ? _self.vendorBonusPaisa : vendorBonusPaisa // ignore: cast_nullable_to_non_nullable
as int?,bonusPercentage: freezed == bonusPercentage ? _self.bonusPercentage : bonusPercentage // ignore: cast_nullable_to_non_nullable
as double?,bonusDescription: freezed == bonusDescription ? _self.bonusDescription : bonusDescription // ignore: cast_nullable_to_non_nullable
as String?,minimumInstallmentsForRedemption: freezed == minimumInstallmentsForRedemption ? _self.minimumInstallmentsForRedemption : minimumInstallmentsForRedemption // ignore: cast_nullable_to_non_nullable
as int?,isGoldLinked: null == isGoldLinked ? _self.isGoldLinked : isGoldLinked // ignore: cast_nullable_to_non_nullable
as bool,linkedMetalType: freezed == linkedMetalType ? _self.linkedMetalType : linkedMetalType // ignore: cast_nullable_to_non_nullable
as MetalType?,defaultAfterMissedInstallments: freezed == defaultAfterMissedInstallments ? _self.defaultAfterMissedInstallments : defaultAfterMissedInstallments // ignore: cast_nullable_to_non_nullable
as int?,foreclosureChargePercent: freezed == foreclosureChargePercent ? _self.foreclosureChargePercent : foreclosureChargePercent // ignore: cast_nullable_to_non_nullable
as int?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SchemeTemplate].
extension SchemeTemplatePatterns on SchemeTemplate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchemeTemplate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchemeTemplate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchemeTemplate value)  $default,){
final _that = this;
switch (_that) {
case _SchemeTemplate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchemeTemplate value)?  $default,){
final _that = this;
switch (_that) {
case _SchemeTemplate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String name, @HiveField(2)  String? description, @HiveField(3)  int installmentAmountPaisa, @HiveField(4)  int totalInstallments, @HiveField(5)  PaymentFrequency frequency, @HiveField(6)  int? vendorBonusPaisa, @HiveField(7)  double? bonusPercentage, @HiveField(8)  String? bonusDescription, @HiveField(9)  int? minimumInstallmentsForRedemption, @HiveField(10)  bool isGoldLinked, @HiveField(11)  MetalType? linkedMetalType, @HiveField(12)  int? defaultAfterMissedInstallments, @HiveField(13)  int? foreclosureChargePercent, @HiveField(14)  bool isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchemeTemplate() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.installmentAmountPaisa,_that.totalInstallments,_that.frequency,_that.vendorBonusPaisa,_that.bonusPercentage,_that.bonusDescription,_that.minimumInstallmentsForRedemption,_that.isGoldLinked,_that.linkedMetalType,_that.defaultAfterMissedInstallments,_that.foreclosureChargePercent,_that.isActive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String name, @HiveField(2)  String? description, @HiveField(3)  int installmentAmountPaisa, @HiveField(4)  int totalInstallments, @HiveField(5)  PaymentFrequency frequency, @HiveField(6)  int? vendorBonusPaisa, @HiveField(7)  double? bonusPercentage, @HiveField(8)  String? bonusDescription, @HiveField(9)  int? minimumInstallmentsForRedemption, @HiveField(10)  bool isGoldLinked, @HiveField(11)  MetalType? linkedMetalType, @HiveField(12)  int? defaultAfterMissedInstallments, @HiveField(13)  int? foreclosureChargePercent, @HiveField(14)  bool isActive)  $default,) {final _that = this;
switch (_that) {
case _SchemeTemplate():
return $default(_that.id,_that.name,_that.description,_that.installmentAmountPaisa,_that.totalInstallments,_that.frequency,_that.vendorBonusPaisa,_that.bonusPercentage,_that.bonusDescription,_that.minimumInstallmentsForRedemption,_that.isGoldLinked,_that.linkedMetalType,_that.defaultAfterMissedInstallments,_that.foreclosureChargePercent,_that.isActive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String name, @HiveField(2)  String? description, @HiveField(3)  int installmentAmountPaisa, @HiveField(4)  int totalInstallments, @HiveField(5)  PaymentFrequency frequency, @HiveField(6)  int? vendorBonusPaisa, @HiveField(7)  double? bonusPercentage, @HiveField(8)  String? bonusDescription, @HiveField(9)  int? minimumInstallmentsForRedemption, @HiveField(10)  bool isGoldLinked, @HiveField(11)  MetalType? linkedMetalType, @HiveField(12)  int? defaultAfterMissedInstallments, @HiveField(13)  int? foreclosureChargePercent, @HiveField(14)  bool isActive)?  $default,) {final _that = this;
switch (_that) {
case _SchemeTemplate() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.installmentAmountPaisa,_that.totalInstallments,_that.frequency,_that.vendorBonusPaisa,_that.bonusPercentage,_that.bonusDescription,_that.minimumInstallmentsForRedemption,_that.isGoldLinked,_that.linkedMetalType,_that.defaultAfterMissedInstallments,_that.foreclosureChargePercent,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 70)
class _SchemeTemplate extends SchemeTemplate {
  const _SchemeTemplate({@HiveField(0) required this.id, @HiveField(1) required this.name, @HiveField(2) this.description, @HiveField(3) required this.installmentAmountPaisa, @HiveField(4) required this.totalInstallments, @HiveField(5) this.frequency = PaymentFrequency.monthly, @HiveField(6) this.vendorBonusPaisa, @HiveField(7) this.bonusPercentage, @HiveField(8) this.bonusDescription, @HiveField(9) this.minimumInstallmentsForRedemption, @HiveField(10) this.isGoldLinked = false, @HiveField(11) this.linkedMetalType, @HiveField(12) this.defaultAfterMissedInstallments, @HiveField(13) this.foreclosureChargePercent, @HiveField(14) this.isActive = true}): super._();
  factory _SchemeTemplate.fromJson(Map<String, dynamic> json) => _$SchemeTemplateFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  String name;
@override@HiveField(2) final  String? description;
@override@HiveField(3) final  int installmentAmountPaisa;
@override@HiveField(4) final  int totalInstallments;
@override@JsonKey()@HiveField(5) final  PaymentFrequency frequency;
@override@HiveField(6) final  int? vendorBonusPaisa;
@override@HiveField(7) final  double? bonusPercentage;
@override@HiveField(8) final  String? bonusDescription;
@override@HiveField(9) final  int? minimumInstallmentsForRedemption;
@override@JsonKey()@HiveField(10) final  bool isGoldLinked;
@override@HiveField(11) final  MetalType? linkedMetalType;
@override@HiveField(12) final  int? defaultAfterMissedInstallments;
@override@HiveField(13) final  int? foreclosureChargePercent;
@override@JsonKey()@HiveField(14) final  bool isActive;

/// Create a copy of SchemeTemplate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchemeTemplateCopyWith<_SchemeTemplate> get copyWith => __$SchemeTemplateCopyWithImpl<_SchemeTemplate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SchemeTemplateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchemeTemplate&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.installmentAmountPaisa, installmentAmountPaisa) || other.installmentAmountPaisa == installmentAmountPaisa)&&(identical(other.totalInstallments, totalInstallments) || other.totalInstallments == totalInstallments)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.vendorBonusPaisa, vendorBonusPaisa) || other.vendorBonusPaisa == vendorBonusPaisa)&&(identical(other.bonusPercentage, bonusPercentage) || other.bonusPercentage == bonusPercentage)&&(identical(other.bonusDescription, bonusDescription) || other.bonusDescription == bonusDescription)&&(identical(other.minimumInstallmentsForRedemption, minimumInstallmentsForRedemption) || other.minimumInstallmentsForRedemption == minimumInstallmentsForRedemption)&&(identical(other.isGoldLinked, isGoldLinked) || other.isGoldLinked == isGoldLinked)&&(identical(other.linkedMetalType, linkedMetalType) || other.linkedMetalType == linkedMetalType)&&(identical(other.defaultAfterMissedInstallments, defaultAfterMissedInstallments) || other.defaultAfterMissedInstallments == defaultAfterMissedInstallments)&&(identical(other.foreclosureChargePercent, foreclosureChargePercent) || other.foreclosureChargePercent == foreclosureChargePercent)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,installmentAmountPaisa,totalInstallments,frequency,vendorBonusPaisa,bonusPercentage,bonusDescription,minimumInstallmentsForRedemption,isGoldLinked,linkedMetalType,defaultAfterMissedInstallments,foreclosureChargePercent,isActive);

@override
String toString() {
  return 'SchemeTemplate(id: $id, name: $name, description: $description, installmentAmountPaisa: $installmentAmountPaisa, totalInstallments: $totalInstallments, frequency: $frequency, vendorBonusPaisa: $vendorBonusPaisa, bonusPercentage: $bonusPercentage, bonusDescription: $bonusDescription, minimumInstallmentsForRedemption: $minimumInstallmentsForRedemption, isGoldLinked: $isGoldLinked, linkedMetalType: $linkedMetalType, defaultAfterMissedInstallments: $defaultAfterMissedInstallments, foreclosureChargePercent: $foreclosureChargePercent, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$SchemeTemplateCopyWith<$Res> implements $SchemeTemplateCopyWith<$Res> {
  factory _$SchemeTemplateCopyWith(_SchemeTemplate value, $Res Function(_SchemeTemplate) _then) = __$SchemeTemplateCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String name,@HiveField(2) String? description,@HiveField(3) int installmentAmountPaisa,@HiveField(4) int totalInstallments,@HiveField(5) PaymentFrequency frequency,@HiveField(6) int? vendorBonusPaisa,@HiveField(7) double? bonusPercentage,@HiveField(8) String? bonusDescription,@HiveField(9) int? minimumInstallmentsForRedemption,@HiveField(10) bool isGoldLinked,@HiveField(11) MetalType? linkedMetalType,@HiveField(12) int? defaultAfterMissedInstallments,@HiveField(13) int? foreclosureChargePercent,@HiveField(14) bool isActive
});




}
/// @nodoc
class __$SchemeTemplateCopyWithImpl<$Res>
    implements _$SchemeTemplateCopyWith<$Res> {
  __$SchemeTemplateCopyWithImpl(this._self, this._then);

  final _SchemeTemplate _self;
  final $Res Function(_SchemeTemplate) _then;

/// Create a copy of SchemeTemplate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? installmentAmountPaisa = null,Object? totalInstallments = null,Object? frequency = null,Object? vendorBonusPaisa = freezed,Object? bonusPercentage = freezed,Object? bonusDescription = freezed,Object? minimumInstallmentsForRedemption = freezed,Object? isGoldLinked = null,Object? linkedMetalType = freezed,Object? defaultAfterMissedInstallments = freezed,Object? foreclosureChargePercent = freezed,Object? isActive = null,}) {
  return _then(_SchemeTemplate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,installmentAmountPaisa: null == installmentAmountPaisa ? _self.installmentAmountPaisa : installmentAmountPaisa // ignore: cast_nullable_to_non_nullable
as int,totalInstallments: null == totalInstallments ? _self.totalInstallments : totalInstallments // ignore: cast_nullable_to_non_nullable
as int,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as PaymentFrequency,vendorBonusPaisa: freezed == vendorBonusPaisa ? _self.vendorBonusPaisa : vendorBonusPaisa // ignore: cast_nullable_to_non_nullable
as int?,bonusPercentage: freezed == bonusPercentage ? _self.bonusPercentage : bonusPercentage // ignore: cast_nullable_to_non_nullable
as double?,bonusDescription: freezed == bonusDescription ? _self.bonusDescription : bonusDescription // ignore: cast_nullable_to_non_nullable
as String?,minimumInstallmentsForRedemption: freezed == minimumInstallmentsForRedemption ? _self.minimumInstallmentsForRedemption : minimumInstallmentsForRedemption // ignore: cast_nullable_to_non_nullable
as int?,isGoldLinked: null == isGoldLinked ? _self.isGoldLinked : isGoldLinked // ignore: cast_nullable_to_non_nullable
as bool,linkedMetalType: freezed == linkedMetalType ? _self.linkedMetalType : linkedMetalType // ignore: cast_nullable_to_non_nullable
as MetalType?,defaultAfterMissedInstallments: freezed == defaultAfterMissedInstallments ? _self.defaultAfterMissedInstallments : defaultAfterMissedInstallments // ignore: cast_nullable_to_non_nullable
as int?,foreclosureChargePercent: freezed == foreclosureChargePercent ? _self.foreclosureChargePercent : foreclosureChargePercent // ignore: cast_nullable_to_non_nullable
as int?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GoldSchemeStatistics {

 int get totalSchemes; int get activeSchemes; int get completedSchemes; int get redeemedSchemes; int get defaultedSchemes; int get totalCustomers; int get totalPaidPaisa; int get totalBonusPaisa; int get totalOutstandingPaisa; int get totalOverduePaisa; double get averageSchemeDuration; int get schemesDueThisMonth; int get schemesOverdue;
/// Create a copy of GoldSchemeStatistics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoldSchemeStatisticsCopyWith<GoldSchemeStatistics> get copyWith => _$GoldSchemeStatisticsCopyWithImpl<GoldSchemeStatistics>(this as GoldSchemeStatistics, _$identity);

  /// Serializes this GoldSchemeStatistics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoldSchemeStatistics&&(identical(other.totalSchemes, totalSchemes) || other.totalSchemes == totalSchemes)&&(identical(other.activeSchemes, activeSchemes) || other.activeSchemes == activeSchemes)&&(identical(other.completedSchemes, completedSchemes) || other.completedSchemes == completedSchemes)&&(identical(other.redeemedSchemes, redeemedSchemes) || other.redeemedSchemes == redeemedSchemes)&&(identical(other.defaultedSchemes, defaultedSchemes) || other.defaultedSchemes == defaultedSchemes)&&(identical(other.totalCustomers, totalCustomers) || other.totalCustomers == totalCustomers)&&(identical(other.totalPaidPaisa, totalPaidPaisa) || other.totalPaidPaisa == totalPaidPaisa)&&(identical(other.totalBonusPaisa, totalBonusPaisa) || other.totalBonusPaisa == totalBonusPaisa)&&(identical(other.totalOutstandingPaisa, totalOutstandingPaisa) || other.totalOutstandingPaisa == totalOutstandingPaisa)&&(identical(other.totalOverduePaisa, totalOverduePaisa) || other.totalOverduePaisa == totalOverduePaisa)&&(identical(other.averageSchemeDuration, averageSchemeDuration) || other.averageSchemeDuration == averageSchemeDuration)&&(identical(other.schemesDueThisMonth, schemesDueThisMonth) || other.schemesDueThisMonth == schemesDueThisMonth)&&(identical(other.schemesOverdue, schemesOverdue) || other.schemesOverdue == schemesOverdue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalSchemes,activeSchemes,completedSchemes,redeemedSchemes,defaultedSchemes,totalCustomers,totalPaidPaisa,totalBonusPaisa,totalOutstandingPaisa,totalOverduePaisa,averageSchemeDuration,schemesDueThisMonth,schemesOverdue);

@override
String toString() {
  return 'GoldSchemeStatistics(totalSchemes: $totalSchemes, activeSchemes: $activeSchemes, completedSchemes: $completedSchemes, redeemedSchemes: $redeemedSchemes, defaultedSchemes: $defaultedSchemes, totalCustomers: $totalCustomers, totalPaidPaisa: $totalPaidPaisa, totalBonusPaisa: $totalBonusPaisa, totalOutstandingPaisa: $totalOutstandingPaisa, totalOverduePaisa: $totalOverduePaisa, averageSchemeDuration: $averageSchemeDuration, schemesDueThisMonth: $schemesDueThisMonth, schemesOverdue: $schemesOverdue)';
}


}

/// @nodoc
abstract mixin class $GoldSchemeStatisticsCopyWith<$Res>  {
  factory $GoldSchemeStatisticsCopyWith(GoldSchemeStatistics value, $Res Function(GoldSchemeStatistics) _then) = _$GoldSchemeStatisticsCopyWithImpl;
@useResult
$Res call({
 int totalSchemes, int activeSchemes, int completedSchemes, int redeemedSchemes, int defaultedSchemes, int totalCustomers, int totalPaidPaisa, int totalBonusPaisa, int totalOutstandingPaisa, int totalOverduePaisa, double averageSchemeDuration, int schemesDueThisMonth, int schemesOverdue
});




}
/// @nodoc
class _$GoldSchemeStatisticsCopyWithImpl<$Res>
    implements $GoldSchemeStatisticsCopyWith<$Res> {
  _$GoldSchemeStatisticsCopyWithImpl(this._self, this._then);

  final GoldSchemeStatistics _self;
  final $Res Function(GoldSchemeStatistics) _then;

/// Create a copy of GoldSchemeStatistics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalSchemes = null,Object? activeSchemes = null,Object? completedSchemes = null,Object? redeemedSchemes = null,Object? defaultedSchemes = null,Object? totalCustomers = null,Object? totalPaidPaisa = null,Object? totalBonusPaisa = null,Object? totalOutstandingPaisa = null,Object? totalOverduePaisa = null,Object? averageSchemeDuration = null,Object? schemesDueThisMonth = null,Object? schemesOverdue = null,}) {
  return _then(_self.copyWith(
totalSchemes: null == totalSchemes ? _self.totalSchemes : totalSchemes // ignore: cast_nullable_to_non_nullable
as int,activeSchemes: null == activeSchemes ? _self.activeSchemes : activeSchemes // ignore: cast_nullable_to_non_nullable
as int,completedSchemes: null == completedSchemes ? _self.completedSchemes : completedSchemes // ignore: cast_nullable_to_non_nullable
as int,redeemedSchemes: null == redeemedSchemes ? _self.redeemedSchemes : redeemedSchemes // ignore: cast_nullable_to_non_nullable
as int,defaultedSchemes: null == defaultedSchemes ? _self.defaultedSchemes : defaultedSchemes // ignore: cast_nullable_to_non_nullable
as int,totalCustomers: null == totalCustomers ? _self.totalCustomers : totalCustomers // ignore: cast_nullable_to_non_nullable
as int,totalPaidPaisa: null == totalPaidPaisa ? _self.totalPaidPaisa : totalPaidPaisa // ignore: cast_nullable_to_non_nullable
as int,totalBonusPaisa: null == totalBonusPaisa ? _self.totalBonusPaisa : totalBonusPaisa // ignore: cast_nullable_to_non_nullable
as int,totalOutstandingPaisa: null == totalOutstandingPaisa ? _self.totalOutstandingPaisa : totalOutstandingPaisa // ignore: cast_nullable_to_non_nullable
as int,totalOverduePaisa: null == totalOverduePaisa ? _self.totalOverduePaisa : totalOverduePaisa // ignore: cast_nullable_to_non_nullable
as int,averageSchemeDuration: null == averageSchemeDuration ? _self.averageSchemeDuration : averageSchemeDuration // ignore: cast_nullable_to_non_nullable
as double,schemesDueThisMonth: null == schemesDueThisMonth ? _self.schemesDueThisMonth : schemesDueThisMonth // ignore: cast_nullable_to_non_nullable
as int,schemesOverdue: null == schemesOverdue ? _self.schemesOverdue : schemesOverdue // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GoldSchemeStatistics].
extension GoldSchemeStatisticsPatterns on GoldSchemeStatistics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoldSchemeStatistics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoldSchemeStatistics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoldSchemeStatistics value)  $default,){
final _that = this;
switch (_that) {
case _GoldSchemeStatistics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoldSchemeStatistics value)?  $default,){
final _that = this;
switch (_that) {
case _GoldSchemeStatistics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalSchemes,  int activeSchemes,  int completedSchemes,  int redeemedSchemes,  int defaultedSchemes,  int totalCustomers,  int totalPaidPaisa,  int totalBonusPaisa,  int totalOutstandingPaisa,  int totalOverduePaisa,  double averageSchemeDuration,  int schemesDueThisMonth,  int schemesOverdue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoldSchemeStatistics() when $default != null:
return $default(_that.totalSchemes,_that.activeSchemes,_that.completedSchemes,_that.redeemedSchemes,_that.defaultedSchemes,_that.totalCustomers,_that.totalPaidPaisa,_that.totalBonusPaisa,_that.totalOutstandingPaisa,_that.totalOverduePaisa,_that.averageSchemeDuration,_that.schemesDueThisMonth,_that.schemesOverdue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalSchemes,  int activeSchemes,  int completedSchemes,  int redeemedSchemes,  int defaultedSchemes,  int totalCustomers,  int totalPaidPaisa,  int totalBonusPaisa,  int totalOutstandingPaisa,  int totalOverduePaisa,  double averageSchemeDuration,  int schemesDueThisMonth,  int schemesOverdue)  $default,) {final _that = this;
switch (_that) {
case _GoldSchemeStatistics():
return $default(_that.totalSchemes,_that.activeSchemes,_that.completedSchemes,_that.redeemedSchemes,_that.defaultedSchemes,_that.totalCustomers,_that.totalPaidPaisa,_that.totalBonusPaisa,_that.totalOutstandingPaisa,_that.totalOverduePaisa,_that.averageSchemeDuration,_that.schemesDueThisMonth,_that.schemesOverdue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalSchemes,  int activeSchemes,  int completedSchemes,  int redeemedSchemes,  int defaultedSchemes,  int totalCustomers,  int totalPaidPaisa,  int totalBonusPaisa,  int totalOutstandingPaisa,  int totalOverduePaisa,  double averageSchemeDuration,  int schemesDueThisMonth,  int schemesOverdue)?  $default,) {final _that = this;
switch (_that) {
case _GoldSchemeStatistics() when $default != null:
return $default(_that.totalSchemes,_that.activeSchemes,_that.completedSchemes,_that.redeemedSchemes,_that.defaultedSchemes,_that.totalCustomers,_that.totalPaidPaisa,_that.totalBonusPaisa,_that.totalOutstandingPaisa,_that.totalOverduePaisa,_that.averageSchemeDuration,_that.schemesDueThisMonth,_that.schemesOverdue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoldSchemeStatistics extends GoldSchemeStatistics {
  const _GoldSchemeStatistics({this.totalSchemes = 0, this.activeSchemes = 0, this.completedSchemes = 0, this.redeemedSchemes = 0, this.defaultedSchemes = 0, this.totalCustomers = 0, this.totalPaidPaisa = 0, this.totalBonusPaisa = 0, this.totalOutstandingPaisa = 0, this.totalOverduePaisa = 0, this.averageSchemeDuration = 0.0, this.schemesDueThisMonth = 0, this.schemesOverdue = 0}): super._();
  factory _GoldSchemeStatistics.fromJson(Map<String, dynamic> json) => _$GoldSchemeStatisticsFromJson(json);

@override@JsonKey() final  int totalSchemes;
@override@JsonKey() final  int activeSchemes;
@override@JsonKey() final  int completedSchemes;
@override@JsonKey() final  int redeemedSchemes;
@override@JsonKey() final  int defaultedSchemes;
@override@JsonKey() final  int totalCustomers;
@override@JsonKey() final  int totalPaidPaisa;
@override@JsonKey() final  int totalBonusPaisa;
@override@JsonKey() final  int totalOutstandingPaisa;
@override@JsonKey() final  int totalOverduePaisa;
@override@JsonKey() final  double averageSchemeDuration;
@override@JsonKey() final  int schemesDueThisMonth;
@override@JsonKey() final  int schemesOverdue;

/// Create a copy of GoldSchemeStatistics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoldSchemeStatisticsCopyWith<_GoldSchemeStatistics> get copyWith => __$GoldSchemeStatisticsCopyWithImpl<_GoldSchemeStatistics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoldSchemeStatisticsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoldSchemeStatistics&&(identical(other.totalSchemes, totalSchemes) || other.totalSchemes == totalSchemes)&&(identical(other.activeSchemes, activeSchemes) || other.activeSchemes == activeSchemes)&&(identical(other.completedSchemes, completedSchemes) || other.completedSchemes == completedSchemes)&&(identical(other.redeemedSchemes, redeemedSchemes) || other.redeemedSchemes == redeemedSchemes)&&(identical(other.defaultedSchemes, defaultedSchemes) || other.defaultedSchemes == defaultedSchemes)&&(identical(other.totalCustomers, totalCustomers) || other.totalCustomers == totalCustomers)&&(identical(other.totalPaidPaisa, totalPaidPaisa) || other.totalPaidPaisa == totalPaidPaisa)&&(identical(other.totalBonusPaisa, totalBonusPaisa) || other.totalBonusPaisa == totalBonusPaisa)&&(identical(other.totalOutstandingPaisa, totalOutstandingPaisa) || other.totalOutstandingPaisa == totalOutstandingPaisa)&&(identical(other.totalOverduePaisa, totalOverduePaisa) || other.totalOverduePaisa == totalOverduePaisa)&&(identical(other.averageSchemeDuration, averageSchemeDuration) || other.averageSchemeDuration == averageSchemeDuration)&&(identical(other.schemesDueThisMonth, schemesDueThisMonth) || other.schemesDueThisMonth == schemesDueThisMonth)&&(identical(other.schemesOverdue, schemesOverdue) || other.schemesOverdue == schemesOverdue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalSchemes,activeSchemes,completedSchemes,redeemedSchemes,defaultedSchemes,totalCustomers,totalPaidPaisa,totalBonusPaisa,totalOutstandingPaisa,totalOverduePaisa,averageSchemeDuration,schemesDueThisMonth,schemesOverdue);

@override
String toString() {
  return 'GoldSchemeStatistics(totalSchemes: $totalSchemes, activeSchemes: $activeSchemes, completedSchemes: $completedSchemes, redeemedSchemes: $redeemedSchemes, defaultedSchemes: $defaultedSchemes, totalCustomers: $totalCustomers, totalPaidPaisa: $totalPaidPaisa, totalBonusPaisa: $totalBonusPaisa, totalOutstandingPaisa: $totalOutstandingPaisa, totalOverduePaisa: $totalOverduePaisa, averageSchemeDuration: $averageSchemeDuration, schemesDueThisMonth: $schemesDueThisMonth, schemesOverdue: $schemesOverdue)';
}


}

/// @nodoc
abstract mixin class _$GoldSchemeStatisticsCopyWith<$Res> implements $GoldSchemeStatisticsCopyWith<$Res> {
  factory _$GoldSchemeStatisticsCopyWith(_GoldSchemeStatistics value, $Res Function(_GoldSchemeStatistics) _then) = __$GoldSchemeStatisticsCopyWithImpl;
@override @useResult
$Res call({
 int totalSchemes, int activeSchemes, int completedSchemes, int redeemedSchemes, int defaultedSchemes, int totalCustomers, int totalPaidPaisa, int totalBonusPaisa, int totalOutstandingPaisa, int totalOverduePaisa, double averageSchemeDuration, int schemesDueThisMonth, int schemesOverdue
});




}
/// @nodoc
class __$GoldSchemeStatisticsCopyWithImpl<$Res>
    implements _$GoldSchemeStatisticsCopyWith<$Res> {
  __$GoldSchemeStatisticsCopyWithImpl(this._self, this._then);

  final _GoldSchemeStatistics _self;
  final $Res Function(_GoldSchemeStatistics) _then;

/// Create a copy of GoldSchemeStatistics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalSchemes = null,Object? activeSchemes = null,Object? completedSchemes = null,Object? redeemedSchemes = null,Object? defaultedSchemes = null,Object? totalCustomers = null,Object? totalPaidPaisa = null,Object? totalBonusPaisa = null,Object? totalOutstandingPaisa = null,Object? totalOverduePaisa = null,Object? averageSchemeDuration = null,Object? schemesDueThisMonth = null,Object? schemesOverdue = null,}) {
  return _then(_GoldSchemeStatistics(
totalSchemes: null == totalSchemes ? _self.totalSchemes : totalSchemes // ignore: cast_nullable_to_non_nullable
as int,activeSchemes: null == activeSchemes ? _self.activeSchemes : activeSchemes // ignore: cast_nullable_to_non_nullable
as int,completedSchemes: null == completedSchemes ? _self.completedSchemes : completedSchemes // ignore: cast_nullable_to_non_nullable
as int,redeemedSchemes: null == redeemedSchemes ? _self.redeemedSchemes : redeemedSchemes // ignore: cast_nullable_to_non_nullable
as int,defaultedSchemes: null == defaultedSchemes ? _self.defaultedSchemes : defaultedSchemes // ignore: cast_nullable_to_non_nullable
as int,totalCustomers: null == totalCustomers ? _self.totalCustomers : totalCustomers // ignore: cast_nullable_to_non_nullable
as int,totalPaidPaisa: null == totalPaidPaisa ? _self.totalPaidPaisa : totalPaidPaisa // ignore: cast_nullable_to_non_nullable
as int,totalBonusPaisa: null == totalBonusPaisa ? _self.totalBonusPaisa : totalBonusPaisa // ignore: cast_nullable_to_non_nullable
as int,totalOutstandingPaisa: null == totalOutstandingPaisa ? _self.totalOutstandingPaisa : totalOutstandingPaisa // ignore: cast_nullable_to_non_nullable
as int,totalOverduePaisa: null == totalOverduePaisa ? _self.totalOverduePaisa : totalOverduePaisa // ignore: cast_nullable_to_non_nullable
as int,averageSchemeDuration: null == averageSchemeDuration ? _self.averageSchemeDuration : averageSchemeDuration // ignore: cast_nullable_to_non_nullable
as double,schemesDueThisMonth: null == schemesDueThisMonth ? _self.schemesDueThisMonth : schemesDueThisMonth // ignore: cast_nullable_to_non_nullable
as int,schemesOverdue: null == schemesOverdue ? _self.schemesOverdue : schemesOverdue // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
