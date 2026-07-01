// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gold_rate_alert_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GoldRateAlert {

// Core identifiers
@HiveField(0) String get id;@HiveField(1) String get tenantId;@HiveField(2) String get userId;// User who created the alert
// Alert configuration
@HiveField(3) MetalType get metalType;@HiveField(4) int get thresholdRatePaisaPerGram;// Rate threshold
@HiveField(5) AlertDirection get direction;@HiveField(6) NotificationMethod get method;// Optional settings
@HiveField(7) String? get note;// User note about why they set this alert
@HiveField(8) bool get isRecurring;// Reset after trigger?
@HiveField(9) int? get recurrenceHours;// How many hours before re-alerting
// Expiration
@HiveField(10) DateTime? get expiryDate;// When alert should expire
// Alert status
@HiveField(11) AlertStatus get status;// Trigger tracking (real data from actual rate checks)
@HiveField(12) DateTime? get lastTriggeredAt;@HiveField(13) int? get triggeredRatePaisa;// The actual rate when triggered
@HiveField(14) int get triggerCount;// How many times this alert has triggered
// Rate history for this alert (last checked rates)
@HiveField(15) List<AlertRateCheck>? get rateHistory;// Notification history
@HiveField(16) List<AlertNotificationLog>? get notificationHistory;// Metadata
@HiveField(17) DateTime get createdAt;@HiveField(18) DateTime get updatedAt;// Sync tracking
@HiveField(19) bool get synced;@HiveField(20) DateTime? get lastSyncedAt;@HiveField(21) String? get pendingOperation;
/// Create a copy of GoldRateAlert
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoldRateAlertCopyWith<GoldRateAlert> get copyWith => _$GoldRateAlertCopyWithImpl<GoldRateAlert>(this as GoldRateAlert, _$identity);

  /// Serializes this GoldRateAlert to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoldRateAlert&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.metalType, metalType) || other.metalType == metalType)&&(identical(other.thresholdRatePaisaPerGram, thresholdRatePaisaPerGram) || other.thresholdRatePaisaPerGram == thresholdRatePaisaPerGram)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.method, method) || other.method == method)&&(identical(other.note, note) || other.note == note)&&(identical(other.isRecurring, isRecurring) || other.isRecurring == isRecurring)&&(identical(other.recurrenceHours, recurrenceHours) || other.recurrenceHours == recurrenceHours)&&(identical(other.expiryDate, expiryDate) || other.expiryDate == expiryDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastTriggeredAt, lastTriggeredAt) || other.lastTriggeredAt == lastTriggeredAt)&&(identical(other.triggeredRatePaisa, triggeredRatePaisa) || other.triggeredRatePaisa == triggeredRatePaisa)&&(identical(other.triggerCount, triggerCount) || other.triggerCount == triggerCount)&&const DeepCollectionEquality().equals(other.rateHistory, rateHistory)&&const DeepCollectionEquality().equals(other.notificationHistory, notificationHistory)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,userId,metalType,thresholdRatePaisaPerGram,direction,method,note,isRecurring,recurrenceHours,expiryDate,status,lastTriggeredAt,triggeredRatePaisa,triggerCount,const DeepCollectionEquality().hash(rateHistory),const DeepCollectionEquality().hash(notificationHistory),createdAt,updatedAt,synced,lastSyncedAt,pendingOperation]);

@override
String toString() {
  return 'GoldRateAlert(id: $id, tenantId: $tenantId, userId: $userId, metalType: $metalType, thresholdRatePaisaPerGram: $thresholdRatePaisaPerGram, direction: $direction, method: $method, note: $note, isRecurring: $isRecurring, recurrenceHours: $recurrenceHours, expiryDate: $expiryDate, status: $status, lastTriggeredAt: $lastTriggeredAt, triggeredRatePaisa: $triggeredRatePaisa, triggerCount: $triggerCount, rateHistory: $rateHistory, notificationHistory: $notificationHistory, createdAt: $createdAt, updatedAt: $updatedAt, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class $GoldRateAlertCopyWith<$Res>  {
  factory $GoldRateAlertCopyWith(GoldRateAlert value, $Res Function(GoldRateAlert) _then) = _$GoldRateAlertCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String userId,@HiveField(3) MetalType metalType,@HiveField(4) int thresholdRatePaisaPerGram,@HiveField(5) AlertDirection direction,@HiveField(6) NotificationMethod method,@HiveField(7) String? note,@HiveField(8) bool isRecurring,@HiveField(9) int? recurrenceHours,@HiveField(10) DateTime? expiryDate,@HiveField(11) AlertStatus status,@HiveField(12) DateTime? lastTriggeredAt,@HiveField(13) int? triggeredRatePaisa,@HiveField(14) int triggerCount,@HiveField(15) List<AlertRateCheck>? rateHistory,@HiveField(16) List<AlertNotificationLog>? notificationHistory,@HiveField(17) DateTime createdAt,@HiveField(18) DateTime updatedAt,@HiveField(19) bool synced,@HiveField(20) DateTime? lastSyncedAt,@HiveField(21) String? pendingOperation
});




}
/// @nodoc
class _$GoldRateAlertCopyWithImpl<$Res>
    implements $GoldRateAlertCopyWith<$Res> {
  _$GoldRateAlertCopyWithImpl(this._self, this._then);

  final GoldRateAlert _self;
  final $Res Function(GoldRateAlert) _then;

/// Create a copy of GoldRateAlert
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? userId = null,Object? metalType = null,Object? thresholdRatePaisaPerGram = null,Object? direction = null,Object? method = null,Object? note = freezed,Object? isRecurring = null,Object? recurrenceHours = freezed,Object? expiryDate = freezed,Object? status = null,Object? lastTriggeredAt = freezed,Object? triggeredRatePaisa = freezed,Object? triggerCount = null,Object? rateHistory = freezed,Object? notificationHistory = freezed,Object? createdAt = null,Object? updatedAt = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,metalType: null == metalType ? _self.metalType : metalType // ignore: cast_nullable_to_non_nullable
as MetalType,thresholdRatePaisaPerGram: null == thresholdRatePaisaPerGram ? _self.thresholdRatePaisaPerGram : thresholdRatePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as AlertDirection,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as NotificationMethod,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,isRecurring: null == isRecurring ? _self.isRecurring : isRecurring // ignore: cast_nullable_to_non_nullable
as bool,recurrenceHours: freezed == recurrenceHours ? _self.recurrenceHours : recurrenceHours // ignore: cast_nullable_to_non_nullable
as int?,expiryDate: freezed == expiryDate ? _self.expiryDate : expiryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AlertStatus,lastTriggeredAt: freezed == lastTriggeredAt ? _self.lastTriggeredAt : lastTriggeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,triggeredRatePaisa: freezed == triggeredRatePaisa ? _self.triggeredRatePaisa : triggeredRatePaisa // ignore: cast_nullable_to_non_nullable
as int?,triggerCount: null == triggerCount ? _self.triggerCount : triggerCount // ignore: cast_nullable_to_non_nullable
as int,rateHistory: freezed == rateHistory ? _self.rateHistory : rateHistory // ignore: cast_nullable_to_non_nullable
as List<AlertRateCheck>?,notificationHistory: freezed == notificationHistory ? _self.notificationHistory : notificationHistory // ignore: cast_nullable_to_non_nullable
as List<AlertNotificationLog>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoldRateAlert].
extension GoldRateAlertPatterns on GoldRateAlert {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoldRateAlert value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoldRateAlert() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoldRateAlert value)  $default,){
final _that = this;
switch (_that) {
case _GoldRateAlert():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoldRateAlert value)?  $default,){
final _that = this;
switch (_that) {
case _GoldRateAlert() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String userId, @HiveField(3)  MetalType metalType, @HiveField(4)  int thresholdRatePaisaPerGram, @HiveField(5)  AlertDirection direction, @HiveField(6)  NotificationMethod method, @HiveField(7)  String? note, @HiveField(8)  bool isRecurring, @HiveField(9)  int? recurrenceHours, @HiveField(10)  DateTime? expiryDate, @HiveField(11)  AlertStatus status, @HiveField(12)  DateTime? lastTriggeredAt, @HiveField(13)  int? triggeredRatePaisa, @HiveField(14)  int triggerCount, @HiveField(15)  List<AlertRateCheck>? rateHistory, @HiveField(16)  List<AlertNotificationLog>? notificationHistory, @HiveField(17)  DateTime createdAt, @HiveField(18)  DateTime updatedAt, @HiveField(19)  bool synced, @HiveField(20)  DateTime? lastSyncedAt, @HiveField(21)  String? pendingOperation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoldRateAlert() when $default != null:
return $default(_that.id,_that.tenantId,_that.userId,_that.metalType,_that.thresholdRatePaisaPerGram,_that.direction,_that.method,_that.note,_that.isRecurring,_that.recurrenceHours,_that.expiryDate,_that.status,_that.lastTriggeredAt,_that.triggeredRatePaisa,_that.triggerCount,_that.rateHistory,_that.notificationHistory,_that.createdAt,_that.updatedAt,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String userId, @HiveField(3)  MetalType metalType, @HiveField(4)  int thresholdRatePaisaPerGram, @HiveField(5)  AlertDirection direction, @HiveField(6)  NotificationMethod method, @HiveField(7)  String? note, @HiveField(8)  bool isRecurring, @HiveField(9)  int? recurrenceHours, @HiveField(10)  DateTime? expiryDate, @HiveField(11)  AlertStatus status, @HiveField(12)  DateTime? lastTriggeredAt, @HiveField(13)  int? triggeredRatePaisa, @HiveField(14)  int triggerCount, @HiveField(15)  List<AlertRateCheck>? rateHistory, @HiveField(16)  List<AlertNotificationLog>? notificationHistory, @HiveField(17)  DateTime createdAt, @HiveField(18)  DateTime updatedAt, @HiveField(19)  bool synced, @HiveField(20)  DateTime? lastSyncedAt, @HiveField(21)  String? pendingOperation)  $default,) {final _that = this;
switch (_that) {
case _GoldRateAlert():
return $default(_that.id,_that.tenantId,_that.userId,_that.metalType,_that.thresholdRatePaisaPerGram,_that.direction,_that.method,_that.note,_that.isRecurring,_that.recurrenceHours,_that.expiryDate,_that.status,_that.lastTriggeredAt,_that.triggeredRatePaisa,_that.triggerCount,_that.rateHistory,_that.notificationHistory,_that.createdAt,_that.updatedAt,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String userId, @HiveField(3)  MetalType metalType, @HiveField(4)  int thresholdRatePaisaPerGram, @HiveField(5)  AlertDirection direction, @HiveField(6)  NotificationMethod method, @HiveField(7)  String? note, @HiveField(8)  bool isRecurring, @HiveField(9)  int? recurrenceHours, @HiveField(10)  DateTime? expiryDate, @HiveField(11)  AlertStatus status, @HiveField(12)  DateTime? lastTriggeredAt, @HiveField(13)  int? triggeredRatePaisa, @HiveField(14)  int triggerCount, @HiveField(15)  List<AlertRateCheck>? rateHistory, @HiveField(16)  List<AlertNotificationLog>? notificationHistory, @HiveField(17)  DateTime createdAt, @HiveField(18)  DateTime updatedAt, @HiveField(19)  bool synced, @HiveField(20)  DateTime? lastSyncedAt, @HiveField(21)  String? pendingOperation)?  $default,) {final _that = this;
switch (_that) {
case _GoldRateAlert() when $default != null:
return $default(_that.id,_that.tenantId,_that.userId,_that.metalType,_that.thresholdRatePaisaPerGram,_that.direction,_that.method,_that.note,_that.isRecurring,_that.recurrenceHours,_that.expiryDate,_that.status,_that.lastTriggeredAt,_that.triggeredRatePaisa,_that.triggerCount,_that.rateHistory,_that.notificationHistory,_that.createdAt,_that.updatedAt,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 56)
class _GoldRateAlert extends GoldRateAlert {
  const _GoldRateAlert({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.userId, @HiveField(3) required this.metalType, @HiveField(4) required this.thresholdRatePaisaPerGram, @HiveField(5) this.direction = AlertDirection.above, @HiveField(6) this.method = NotificationMethod.push, @HiveField(7) this.note, @HiveField(8) this.isRecurring = false, @HiveField(9) this.recurrenceHours, @HiveField(10) this.expiryDate, @HiveField(11) this.status = AlertStatus.active, @HiveField(12) this.lastTriggeredAt, @HiveField(13) this.triggeredRatePaisa, @HiveField(14) this.triggerCount = 0, @HiveField(15) final  List<AlertRateCheck>? rateHistory, @HiveField(16) final  List<AlertNotificationLog>? notificationHistory, @HiveField(17) required this.createdAt, @HiveField(18) required this.updatedAt, @HiveField(19) this.synced = true, @HiveField(20) this.lastSyncedAt, @HiveField(21) this.pendingOperation}): _rateHistory = rateHistory,_notificationHistory = notificationHistory,super._();
  factory _GoldRateAlert.fromJson(Map<String, dynamic> json) => _$GoldRateAlertFromJson(json);

// Core identifiers
@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
@override@HiveField(2) final  String userId;
// User who created the alert
// Alert configuration
@override@HiveField(3) final  MetalType metalType;
@override@HiveField(4) final  int thresholdRatePaisaPerGram;
// Rate threshold
@override@JsonKey()@HiveField(5) final  AlertDirection direction;
@override@JsonKey()@HiveField(6) final  NotificationMethod method;
// Optional settings
@override@HiveField(7) final  String? note;
// User note about why they set this alert
@override@JsonKey()@HiveField(8) final  bool isRecurring;
// Reset after trigger?
@override@HiveField(9) final  int? recurrenceHours;
// How many hours before re-alerting
// Expiration
@override@HiveField(10) final  DateTime? expiryDate;
// When alert should expire
// Alert status
@override@JsonKey()@HiveField(11) final  AlertStatus status;
// Trigger tracking (real data from actual rate checks)
@override@HiveField(12) final  DateTime? lastTriggeredAt;
@override@HiveField(13) final  int? triggeredRatePaisa;
// The actual rate when triggered
@override@JsonKey()@HiveField(14) final  int triggerCount;
// How many times this alert has triggered
// Rate history for this alert (last checked rates)
 final  List<AlertRateCheck>? _rateHistory;
// How many times this alert has triggered
// Rate history for this alert (last checked rates)
@override@HiveField(15) List<AlertRateCheck>? get rateHistory {
  final value = _rateHistory;
  if (value == null) return null;
  if (_rateHistory is EqualUnmodifiableListView) return _rateHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Notification history
 final  List<AlertNotificationLog>? _notificationHistory;
// Notification history
@override@HiveField(16) List<AlertNotificationLog>? get notificationHistory {
  final value = _notificationHistory;
  if (value == null) return null;
  if (_notificationHistory is EqualUnmodifiableListView) return _notificationHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Metadata
@override@HiveField(17) final  DateTime createdAt;
@override@HiveField(18) final  DateTime updatedAt;
// Sync tracking
@override@JsonKey()@HiveField(19) final  bool synced;
@override@HiveField(20) final  DateTime? lastSyncedAt;
@override@HiveField(21) final  String? pendingOperation;

/// Create a copy of GoldRateAlert
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoldRateAlertCopyWith<_GoldRateAlert> get copyWith => __$GoldRateAlertCopyWithImpl<_GoldRateAlert>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoldRateAlertToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoldRateAlert&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.metalType, metalType) || other.metalType == metalType)&&(identical(other.thresholdRatePaisaPerGram, thresholdRatePaisaPerGram) || other.thresholdRatePaisaPerGram == thresholdRatePaisaPerGram)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.method, method) || other.method == method)&&(identical(other.note, note) || other.note == note)&&(identical(other.isRecurring, isRecurring) || other.isRecurring == isRecurring)&&(identical(other.recurrenceHours, recurrenceHours) || other.recurrenceHours == recurrenceHours)&&(identical(other.expiryDate, expiryDate) || other.expiryDate == expiryDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastTriggeredAt, lastTriggeredAt) || other.lastTriggeredAt == lastTriggeredAt)&&(identical(other.triggeredRatePaisa, triggeredRatePaisa) || other.triggeredRatePaisa == triggeredRatePaisa)&&(identical(other.triggerCount, triggerCount) || other.triggerCount == triggerCount)&&const DeepCollectionEquality().equals(other._rateHistory, _rateHistory)&&const DeepCollectionEquality().equals(other._notificationHistory, _notificationHistory)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,userId,metalType,thresholdRatePaisaPerGram,direction,method,note,isRecurring,recurrenceHours,expiryDate,status,lastTriggeredAt,triggeredRatePaisa,triggerCount,const DeepCollectionEquality().hash(_rateHistory),const DeepCollectionEquality().hash(_notificationHistory),createdAt,updatedAt,synced,lastSyncedAt,pendingOperation]);

@override
String toString() {
  return 'GoldRateAlert(id: $id, tenantId: $tenantId, userId: $userId, metalType: $metalType, thresholdRatePaisaPerGram: $thresholdRatePaisaPerGram, direction: $direction, method: $method, note: $note, isRecurring: $isRecurring, recurrenceHours: $recurrenceHours, expiryDate: $expiryDate, status: $status, lastTriggeredAt: $lastTriggeredAt, triggeredRatePaisa: $triggeredRatePaisa, triggerCount: $triggerCount, rateHistory: $rateHistory, notificationHistory: $notificationHistory, createdAt: $createdAt, updatedAt: $updatedAt, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class _$GoldRateAlertCopyWith<$Res> implements $GoldRateAlertCopyWith<$Res> {
  factory _$GoldRateAlertCopyWith(_GoldRateAlert value, $Res Function(_GoldRateAlert) _then) = __$GoldRateAlertCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String userId,@HiveField(3) MetalType metalType,@HiveField(4) int thresholdRatePaisaPerGram,@HiveField(5) AlertDirection direction,@HiveField(6) NotificationMethod method,@HiveField(7) String? note,@HiveField(8) bool isRecurring,@HiveField(9) int? recurrenceHours,@HiveField(10) DateTime? expiryDate,@HiveField(11) AlertStatus status,@HiveField(12) DateTime? lastTriggeredAt,@HiveField(13) int? triggeredRatePaisa,@HiveField(14) int triggerCount,@HiveField(15) List<AlertRateCheck>? rateHistory,@HiveField(16) List<AlertNotificationLog>? notificationHistory,@HiveField(17) DateTime createdAt,@HiveField(18) DateTime updatedAt,@HiveField(19) bool synced,@HiveField(20) DateTime? lastSyncedAt,@HiveField(21) String? pendingOperation
});




}
/// @nodoc
class __$GoldRateAlertCopyWithImpl<$Res>
    implements _$GoldRateAlertCopyWith<$Res> {
  __$GoldRateAlertCopyWithImpl(this._self, this._then);

  final _GoldRateAlert _self;
  final $Res Function(_GoldRateAlert) _then;

/// Create a copy of GoldRateAlert
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? userId = null,Object? metalType = null,Object? thresholdRatePaisaPerGram = null,Object? direction = null,Object? method = null,Object? note = freezed,Object? isRecurring = null,Object? recurrenceHours = freezed,Object? expiryDate = freezed,Object? status = null,Object? lastTriggeredAt = freezed,Object? triggeredRatePaisa = freezed,Object? triggerCount = null,Object? rateHistory = freezed,Object? notificationHistory = freezed,Object? createdAt = null,Object? updatedAt = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_GoldRateAlert(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,metalType: null == metalType ? _self.metalType : metalType // ignore: cast_nullable_to_non_nullable
as MetalType,thresholdRatePaisaPerGram: null == thresholdRatePaisaPerGram ? _self.thresholdRatePaisaPerGram : thresholdRatePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as AlertDirection,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as NotificationMethod,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,isRecurring: null == isRecurring ? _self.isRecurring : isRecurring // ignore: cast_nullable_to_non_nullable
as bool,recurrenceHours: freezed == recurrenceHours ? _self.recurrenceHours : recurrenceHours // ignore: cast_nullable_to_non_nullable
as int?,expiryDate: freezed == expiryDate ? _self.expiryDate : expiryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AlertStatus,lastTriggeredAt: freezed == lastTriggeredAt ? _self.lastTriggeredAt : lastTriggeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,triggeredRatePaisa: freezed == triggeredRatePaisa ? _self.triggeredRatePaisa : triggeredRatePaisa // ignore: cast_nullable_to_non_nullable
as int?,triggerCount: null == triggerCount ? _self.triggerCount : triggerCount // ignore: cast_nullable_to_non_nullable
as int,rateHistory: freezed == rateHistory ? _self._rateHistory : rateHistory // ignore: cast_nullable_to_non_nullable
as List<AlertRateCheck>?,notificationHistory: freezed == notificationHistory ? _self._notificationHistory : notificationHistory // ignore: cast_nullable_to_non_nullable
as List<AlertNotificationLog>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,synced: null == synced ? _self.synced : synced // ignore: cast_nullable_to_non_nullable
as bool,lastSyncedAt: freezed == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pendingOperation: freezed == pendingOperation ? _self.pendingOperation : pendingOperation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AlertRateCheck {

@HiveField(0) DateTime get checkedAt;@HiveField(1) int get ratePaisaPerGram;@HiveField(2) bool get wouldTrigger;
/// Create a copy of AlertRateCheck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlertRateCheckCopyWith<AlertRateCheck> get copyWith => _$AlertRateCheckCopyWithImpl<AlertRateCheck>(this as AlertRateCheck, _$identity);

  /// Serializes this AlertRateCheck to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlertRateCheck&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt)&&(identical(other.ratePaisaPerGram, ratePaisaPerGram) || other.ratePaisaPerGram == ratePaisaPerGram)&&(identical(other.wouldTrigger, wouldTrigger) || other.wouldTrigger == wouldTrigger));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,checkedAt,ratePaisaPerGram,wouldTrigger);

@override
String toString() {
  return 'AlertRateCheck(checkedAt: $checkedAt, ratePaisaPerGram: $ratePaisaPerGram, wouldTrigger: $wouldTrigger)';
}


}

/// @nodoc
abstract mixin class $AlertRateCheckCopyWith<$Res>  {
  factory $AlertRateCheckCopyWith(AlertRateCheck value, $Res Function(AlertRateCheck) _then) = _$AlertRateCheckCopyWithImpl;
@useResult
$Res call({
@HiveField(0) DateTime checkedAt,@HiveField(1) int ratePaisaPerGram,@HiveField(2) bool wouldTrigger
});




}
/// @nodoc
class _$AlertRateCheckCopyWithImpl<$Res>
    implements $AlertRateCheckCopyWith<$Res> {
  _$AlertRateCheckCopyWithImpl(this._self, this._then);

  final AlertRateCheck _self;
  final $Res Function(AlertRateCheck) _then;

/// Create a copy of AlertRateCheck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? checkedAt = null,Object? ratePaisaPerGram = null,Object? wouldTrigger = null,}) {
  return _then(_self.copyWith(
checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,ratePaisaPerGram: null == ratePaisaPerGram ? _self.ratePaisaPerGram : ratePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,wouldTrigger: null == wouldTrigger ? _self.wouldTrigger : wouldTrigger // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AlertRateCheck].
extension AlertRateCheckPatterns on AlertRateCheck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlertRateCheck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlertRateCheck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlertRateCheck value)  $default,){
final _that = this;
switch (_that) {
case _AlertRateCheck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlertRateCheck value)?  $default,){
final _that = this;
switch (_that) {
case _AlertRateCheck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  DateTime checkedAt, @HiveField(1)  int ratePaisaPerGram, @HiveField(2)  bool wouldTrigger)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlertRateCheck() when $default != null:
return $default(_that.checkedAt,_that.ratePaisaPerGram,_that.wouldTrigger);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  DateTime checkedAt, @HiveField(1)  int ratePaisaPerGram, @HiveField(2)  bool wouldTrigger)  $default,) {final _that = this;
switch (_that) {
case _AlertRateCheck():
return $default(_that.checkedAt,_that.ratePaisaPerGram,_that.wouldTrigger);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  DateTime checkedAt, @HiveField(1)  int ratePaisaPerGram, @HiveField(2)  bool wouldTrigger)?  $default,) {final _that = this;
switch (_that) {
case _AlertRateCheck() when $default != null:
return $default(_that.checkedAt,_that.ratePaisaPerGram,_that.wouldTrigger);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 57)
class _AlertRateCheck implements AlertRateCheck {
  const _AlertRateCheck({@HiveField(0) required this.checkedAt, @HiveField(1) required this.ratePaisaPerGram, @HiveField(2) required this.wouldTrigger});
  factory _AlertRateCheck.fromJson(Map<String, dynamic> json) => _$AlertRateCheckFromJson(json);

@override@HiveField(0) final  DateTime checkedAt;
@override@HiveField(1) final  int ratePaisaPerGram;
@override@HiveField(2) final  bool wouldTrigger;

/// Create a copy of AlertRateCheck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlertRateCheckCopyWith<_AlertRateCheck> get copyWith => __$AlertRateCheckCopyWithImpl<_AlertRateCheck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlertRateCheckToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlertRateCheck&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt)&&(identical(other.ratePaisaPerGram, ratePaisaPerGram) || other.ratePaisaPerGram == ratePaisaPerGram)&&(identical(other.wouldTrigger, wouldTrigger) || other.wouldTrigger == wouldTrigger));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,checkedAt,ratePaisaPerGram,wouldTrigger);

@override
String toString() {
  return 'AlertRateCheck(checkedAt: $checkedAt, ratePaisaPerGram: $ratePaisaPerGram, wouldTrigger: $wouldTrigger)';
}


}

/// @nodoc
abstract mixin class _$AlertRateCheckCopyWith<$Res> implements $AlertRateCheckCopyWith<$Res> {
  factory _$AlertRateCheckCopyWith(_AlertRateCheck value, $Res Function(_AlertRateCheck) _then) = __$AlertRateCheckCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) DateTime checkedAt,@HiveField(1) int ratePaisaPerGram,@HiveField(2) bool wouldTrigger
});




}
/// @nodoc
class __$AlertRateCheckCopyWithImpl<$Res>
    implements _$AlertRateCheckCopyWith<$Res> {
  __$AlertRateCheckCopyWithImpl(this._self, this._then);

  final _AlertRateCheck _self;
  final $Res Function(_AlertRateCheck) _then;

/// Create a copy of AlertRateCheck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? checkedAt = null,Object? ratePaisaPerGram = null,Object? wouldTrigger = null,}) {
  return _then(_AlertRateCheck(
checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,ratePaisaPerGram: null == ratePaisaPerGram ? _self.ratePaisaPerGram : ratePaisaPerGram // ignore: cast_nullable_to_non_nullable
as int,wouldTrigger: null == wouldTrigger ? _self.wouldTrigger : wouldTrigger // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AlertNotificationLog {

@HiveField(0) DateTime get sentAt;@HiveField(1) NotificationMethod get method;@HiveField(2) int get ratePaisaAtNotification;@HiveField(3) String get message;@HiveField(4) bool get delivered;@HiveField(5) String? get errorMessage;
/// Create a copy of AlertNotificationLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlertNotificationLogCopyWith<AlertNotificationLog> get copyWith => _$AlertNotificationLogCopyWithImpl<AlertNotificationLog>(this as AlertNotificationLog, _$identity);

  /// Serializes this AlertNotificationLog to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlertNotificationLog&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.method, method) || other.method == method)&&(identical(other.ratePaisaAtNotification, ratePaisaAtNotification) || other.ratePaisaAtNotification == ratePaisaAtNotification)&&(identical(other.message, message) || other.message == message)&&(identical(other.delivered, delivered) || other.delivered == delivered)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sentAt,method,ratePaisaAtNotification,message,delivered,errorMessage);

@override
String toString() {
  return 'AlertNotificationLog(sentAt: $sentAt, method: $method, ratePaisaAtNotification: $ratePaisaAtNotification, message: $message, delivered: $delivered, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $AlertNotificationLogCopyWith<$Res>  {
  factory $AlertNotificationLogCopyWith(AlertNotificationLog value, $Res Function(AlertNotificationLog) _then) = _$AlertNotificationLogCopyWithImpl;
@useResult
$Res call({
@HiveField(0) DateTime sentAt,@HiveField(1) NotificationMethod method,@HiveField(2) int ratePaisaAtNotification,@HiveField(3) String message,@HiveField(4) bool delivered,@HiveField(5) String? errorMessage
});




}
/// @nodoc
class _$AlertNotificationLogCopyWithImpl<$Res>
    implements $AlertNotificationLogCopyWith<$Res> {
  _$AlertNotificationLogCopyWithImpl(this._self, this._then);

  final AlertNotificationLog _self;
  final $Res Function(AlertNotificationLog) _then;

/// Create a copy of AlertNotificationLog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sentAt = null,Object? method = null,Object? ratePaisaAtNotification = null,Object? message = null,Object? delivered = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as NotificationMethod,ratePaisaAtNotification: null == ratePaisaAtNotification ? _self.ratePaisaAtNotification : ratePaisaAtNotification // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,delivered: null == delivered ? _self.delivered : delivered // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AlertNotificationLog].
extension AlertNotificationLogPatterns on AlertNotificationLog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlertNotificationLog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlertNotificationLog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlertNotificationLog value)  $default,){
final _that = this;
switch (_that) {
case _AlertNotificationLog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlertNotificationLog value)?  $default,){
final _that = this;
switch (_that) {
case _AlertNotificationLog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  DateTime sentAt, @HiveField(1)  NotificationMethod method, @HiveField(2)  int ratePaisaAtNotification, @HiveField(3)  String message, @HiveField(4)  bool delivered, @HiveField(5)  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlertNotificationLog() when $default != null:
return $default(_that.sentAt,_that.method,_that.ratePaisaAtNotification,_that.message,_that.delivered,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  DateTime sentAt, @HiveField(1)  NotificationMethod method, @HiveField(2)  int ratePaisaAtNotification, @HiveField(3)  String message, @HiveField(4)  bool delivered, @HiveField(5)  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _AlertNotificationLog():
return $default(_that.sentAt,_that.method,_that.ratePaisaAtNotification,_that.message,_that.delivered,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  DateTime sentAt, @HiveField(1)  NotificationMethod method, @HiveField(2)  int ratePaisaAtNotification, @HiveField(3)  String message, @HiveField(4)  bool delivered, @HiveField(5)  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _AlertNotificationLog() when $default != null:
return $default(_that.sentAt,_that.method,_that.ratePaisaAtNotification,_that.message,_that.delivered,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 58)
class _AlertNotificationLog implements AlertNotificationLog {
  const _AlertNotificationLog({@HiveField(0) required this.sentAt, @HiveField(1) required this.method, @HiveField(2) required this.ratePaisaAtNotification, @HiveField(3) required this.message, @HiveField(4) this.delivered = true, @HiveField(5) this.errorMessage});
  factory _AlertNotificationLog.fromJson(Map<String, dynamic> json) => _$AlertNotificationLogFromJson(json);

@override@HiveField(0) final  DateTime sentAt;
@override@HiveField(1) final  NotificationMethod method;
@override@HiveField(2) final  int ratePaisaAtNotification;
@override@HiveField(3) final  String message;
@override@JsonKey()@HiveField(4) final  bool delivered;
@override@HiveField(5) final  String? errorMessage;

/// Create a copy of AlertNotificationLog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlertNotificationLogCopyWith<_AlertNotificationLog> get copyWith => __$AlertNotificationLogCopyWithImpl<_AlertNotificationLog>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlertNotificationLogToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlertNotificationLog&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.method, method) || other.method == method)&&(identical(other.ratePaisaAtNotification, ratePaisaAtNotification) || other.ratePaisaAtNotification == ratePaisaAtNotification)&&(identical(other.message, message) || other.message == message)&&(identical(other.delivered, delivered) || other.delivered == delivered)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sentAt,method,ratePaisaAtNotification,message,delivered,errorMessage);

@override
String toString() {
  return 'AlertNotificationLog(sentAt: $sentAt, method: $method, ratePaisaAtNotification: $ratePaisaAtNotification, message: $message, delivered: $delivered, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$AlertNotificationLogCopyWith<$Res> implements $AlertNotificationLogCopyWith<$Res> {
  factory _$AlertNotificationLogCopyWith(_AlertNotificationLog value, $Res Function(_AlertNotificationLog) _then) = __$AlertNotificationLogCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) DateTime sentAt,@HiveField(1) NotificationMethod method,@HiveField(2) int ratePaisaAtNotification,@HiveField(3) String message,@HiveField(4) bool delivered,@HiveField(5) String? errorMessage
});




}
/// @nodoc
class __$AlertNotificationLogCopyWithImpl<$Res>
    implements _$AlertNotificationLogCopyWith<$Res> {
  __$AlertNotificationLogCopyWithImpl(this._self, this._then);

  final _AlertNotificationLog _self;
  final $Res Function(_AlertNotificationLog) _then;

/// Create a copy of AlertNotificationLog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sentAt = null,Object? method = null,Object? ratePaisaAtNotification = null,Object? message = null,Object? delivered = null,Object? errorMessage = freezed,}) {
  return _then(_AlertNotificationLog(
sentAt: null == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as NotificationMethod,ratePaisaAtNotification: null == ratePaisaAtNotification ? _self.ratePaisaAtNotification : ratePaisaAtNotification // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,delivered: null == delivered ? _self.delivered : delivered // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AlertStatistics {

 int get totalAlerts; int get activeAlerts; int get triggeredAlerts; int get expiredAlerts; int get totalTriggers; GoldRateAlert? get mostTriggeredAlert; GoldRateAlert? get recentlyTriggeredAlert;
/// Create a copy of AlertStatistics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AlertStatisticsCopyWith<AlertStatistics> get copyWith => _$AlertStatisticsCopyWithImpl<AlertStatistics>(this as AlertStatistics, _$identity);

  /// Serializes this AlertStatistics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AlertStatistics&&(identical(other.totalAlerts, totalAlerts) || other.totalAlerts == totalAlerts)&&(identical(other.activeAlerts, activeAlerts) || other.activeAlerts == activeAlerts)&&(identical(other.triggeredAlerts, triggeredAlerts) || other.triggeredAlerts == triggeredAlerts)&&(identical(other.expiredAlerts, expiredAlerts) || other.expiredAlerts == expiredAlerts)&&(identical(other.totalTriggers, totalTriggers) || other.totalTriggers == totalTriggers)&&(identical(other.mostTriggeredAlert, mostTriggeredAlert) || other.mostTriggeredAlert == mostTriggeredAlert)&&(identical(other.recentlyTriggeredAlert, recentlyTriggeredAlert) || other.recentlyTriggeredAlert == recentlyTriggeredAlert));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalAlerts,activeAlerts,triggeredAlerts,expiredAlerts,totalTriggers,mostTriggeredAlert,recentlyTriggeredAlert);

@override
String toString() {
  return 'AlertStatistics(totalAlerts: $totalAlerts, activeAlerts: $activeAlerts, triggeredAlerts: $triggeredAlerts, expiredAlerts: $expiredAlerts, totalTriggers: $totalTriggers, mostTriggeredAlert: $mostTriggeredAlert, recentlyTriggeredAlert: $recentlyTriggeredAlert)';
}


}

/// @nodoc
abstract mixin class $AlertStatisticsCopyWith<$Res>  {
  factory $AlertStatisticsCopyWith(AlertStatistics value, $Res Function(AlertStatistics) _then) = _$AlertStatisticsCopyWithImpl;
@useResult
$Res call({
 int totalAlerts, int activeAlerts, int triggeredAlerts, int expiredAlerts, int totalTriggers, GoldRateAlert? mostTriggeredAlert, GoldRateAlert? recentlyTriggeredAlert
});


$GoldRateAlertCopyWith<$Res>? get mostTriggeredAlert;$GoldRateAlertCopyWith<$Res>? get recentlyTriggeredAlert;

}
/// @nodoc
class _$AlertStatisticsCopyWithImpl<$Res>
    implements $AlertStatisticsCopyWith<$Res> {
  _$AlertStatisticsCopyWithImpl(this._self, this._then);

  final AlertStatistics _self;
  final $Res Function(AlertStatistics) _then;

/// Create a copy of AlertStatistics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalAlerts = null,Object? activeAlerts = null,Object? triggeredAlerts = null,Object? expiredAlerts = null,Object? totalTriggers = null,Object? mostTriggeredAlert = freezed,Object? recentlyTriggeredAlert = freezed,}) {
  return _then(_self.copyWith(
totalAlerts: null == totalAlerts ? _self.totalAlerts : totalAlerts // ignore: cast_nullable_to_non_nullable
as int,activeAlerts: null == activeAlerts ? _self.activeAlerts : activeAlerts // ignore: cast_nullable_to_non_nullable
as int,triggeredAlerts: null == triggeredAlerts ? _self.triggeredAlerts : triggeredAlerts // ignore: cast_nullable_to_non_nullable
as int,expiredAlerts: null == expiredAlerts ? _self.expiredAlerts : expiredAlerts // ignore: cast_nullable_to_non_nullable
as int,totalTriggers: null == totalTriggers ? _self.totalTriggers : totalTriggers // ignore: cast_nullable_to_non_nullable
as int,mostTriggeredAlert: freezed == mostTriggeredAlert ? _self.mostTriggeredAlert : mostTriggeredAlert // ignore: cast_nullable_to_non_nullable
as GoldRateAlert?,recentlyTriggeredAlert: freezed == recentlyTriggeredAlert ? _self.recentlyTriggeredAlert : recentlyTriggeredAlert // ignore: cast_nullable_to_non_nullable
as GoldRateAlert?,
  ));
}
/// Create a copy of AlertStatistics
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoldRateAlertCopyWith<$Res>? get mostTriggeredAlert {
    if (_self.mostTriggeredAlert == null) {
    return null;
  }

  return $GoldRateAlertCopyWith<$Res>(_self.mostTriggeredAlert!, (value) {
    return _then(_self.copyWith(mostTriggeredAlert: value));
  });
}/// Create a copy of AlertStatistics
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoldRateAlertCopyWith<$Res>? get recentlyTriggeredAlert {
    if (_self.recentlyTriggeredAlert == null) {
    return null;
  }

  return $GoldRateAlertCopyWith<$Res>(_self.recentlyTriggeredAlert!, (value) {
    return _then(_self.copyWith(recentlyTriggeredAlert: value));
  });
}
}


/// Adds pattern-matching-related methods to [AlertStatistics].
extension AlertStatisticsPatterns on AlertStatistics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AlertStatistics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AlertStatistics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AlertStatistics value)  $default,){
final _that = this;
switch (_that) {
case _AlertStatistics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AlertStatistics value)?  $default,){
final _that = this;
switch (_that) {
case _AlertStatistics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalAlerts,  int activeAlerts,  int triggeredAlerts,  int expiredAlerts,  int totalTriggers,  GoldRateAlert? mostTriggeredAlert,  GoldRateAlert? recentlyTriggeredAlert)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AlertStatistics() when $default != null:
return $default(_that.totalAlerts,_that.activeAlerts,_that.triggeredAlerts,_that.expiredAlerts,_that.totalTriggers,_that.mostTriggeredAlert,_that.recentlyTriggeredAlert);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalAlerts,  int activeAlerts,  int triggeredAlerts,  int expiredAlerts,  int totalTriggers,  GoldRateAlert? mostTriggeredAlert,  GoldRateAlert? recentlyTriggeredAlert)  $default,) {final _that = this;
switch (_that) {
case _AlertStatistics():
return $default(_that.totalAlerts,_that.activeAlerts,_that.triggeredAlerts,_that.expiredAlerts,_that.totalTriggers,_that.mostTriggeredAlert,_that.recentlyTriggeredAlert);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalAlerts,  int activeAlerts,  int triggeredAlerts,  int expiredAlerts,  int totalTriggers,  GoldRateAlert? mostTriggeredAlert,  GoldRateAlert? recentlyTriggeredAlert)?  $default,) {final _that = this;
switch (_that) {
case _AlertStatistics() when $default != null:
return $default(_that.totalAlerts,_that.activeAlerts,_that.triggeredAlerts,_that.expiredAlerts,_that.totalTriggers,_that.mostTriggeredAlert,_that.recentlyTriggeredAlert);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AlertStatistics implements AlertStatistics {
  const _AlertStatistics({this.totalAlerts = 0, this.activeAlerts = 0, this.triggeredAlerts = 0, this.expiredAlerts = 0, this.totalTriggers = 0, this.mostTriggeredAlert, this.recentlyTriggeredAlert});
  factory _AlertStatistics.fromJson(Map<String, dynamic> json) => _$AlertStatisticsFromJson(json);

@override@JsonKey() final  int totalAlerts;
@override@JsonKey() final  int activeAlerts;
@override@JsonKey() final  int triggeredAlerts;
@override@JsonKey() final  int expiredAlerts;
@override@JsonKey() final  int totalTriggers;
@override final  GoldRateAlert? mostTriggeredAlert;
@override final  GoldRateAlert? recentlyTriggeredAlert;

/// Create a copy of AlertStatistics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AlertStatisticsCopyWith<_AlertStatistics> get copyWith => __$AlertStatisticsCopyWithImpl<_AlertStatistics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AlertStatisticsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AlertStatistics&&(identical(other.totalAlerts, totalAlerts) || other.totalAlerts == totalAlerts)&&(identical(other.activeAlerts, activeAlerts) || other.activeAlerts == activeAlerts)&&(identical(other.triggeredAlerts, triggeredAlerts) || other.triggeredAlerts == triggeredAlerts)&&(identical(other.expiredAlerts, expiredAlerts) || other.expiredAlerts == expiredAlerts)&&(identical(other.totalTriggers, totalTriggers) || other.totalTriggers == totalTriggers)&&(identical(other.mostTriggeredAlert, mostTriggeredAlert) || other.mostTriggeredAlert == mostTriggeredAlert)&&(identical(other.recentlyTriggeredAlert, recentlyTriggeredAlert) || other.recentlyTriggeredAlert == recentlyTriggeredAlert));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalAlerts,activeAlerts,triggeredAlerts,expiredAlerts,totalTriggers,mostTriggeredAlert,recentlyTriggeredAlert);

@override
String toString() {
  return 'AlertStatistics(totalAlerts: $totalAlerts, activeAlerts: $activeAlerts, triggeredAlerts: $triggeredAlerts, expiredAlerts: $expiredAlerts, totalTriggers: $totalTriggers, mostTriggeredAlert: $mostTriggeredAlert, recentlyTriggeredAlert: $recentlyTriggeredAlert)';
}


}

/// @nodoc
abstract mixin class _$AlertStatisticsCopyWith<$Res> implements $AlertStatisticsCopyWith<$Res> {
  factory _$AlertStatisticsCopyWith(_AlertStatistics value, $Res Function(_AlertStatistics) _then) = __$AlertStatisticsCopyWithImpl;
@override @useResult
$Res call({
 int totalAlerts, int activeAlerts, int triggeredAlerts, int expiredAlerts, int totalTriggers, GoldRateAlert? mostTriggeredAlert, GoldRateAlert? recentlyTriggeredAlert
});


@override $GoldRateAlertCopyWith<$Res>? get mostTriggeredAlert;@override $GoldRateAlertCopyWith<$Res>? get recentlyTriggeredAlert;

}
/// @nodoc
class __$AlertStatisticsCopyWithImpl<$Res>
    implements _$AlertStatisticsCopyWith<$Res> {
  __$AlertStatisticsCopyWithImpl(this._self, this._then);

  final _AlertStatistics _self;
  final $Res Function(_AlertStatistics) _then;

/// Create a copy of AlertStatistics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalAlerts = null,Object? activeAlerts = null,Object? triggeredAlerts = null,Object? expiredAlerts = null,Object? totalTriggers = null,Object? mostTriggeredAlert = freezed,Object? recentlyTriggeredAlert = freezed,}) {
  return _then(_AlertStatistics(
totalAlerts: null == totalAlerts ? _self.totalAlerts : totalAlerts // ignore: cast_nullable_to_non_nullable
as int,activeAlerts: null == activeAlerts ? _self.activeAlerts : activeAlerts // ignore: cast_nullable_to_non_nullable
as int,triggeredAlerts: null == triggeredAlerts ? _self.triggeredAlerts : triggeredAlerts // ignore: cast_nullable_to_non_nullable
as int,expiredAlerts: null == expiredAlerts ? _self.expiredAlerts : expiredAlerts // ignore: cast_nullable_to_non_nullable
as int,totalTriggers: null == totalTriggers ? _self.totalTriggers : totalTriggers // ignore: cast_nullable_to_non_nullable
as int,mostTriggeredAlert: freezed == mostTriggeredAlert ? _self.mostTriggeredAlert : mostTriggeredAlert // ignore: cast_nullable_to_non_nullable
as GoldRateAlert?,recentlyTriggeredAlert: freezed == recentlyTriggeredAlert ? _self.recentlyTriggeredAlert : recentlyTriggeredAlert // ignore: cast_nullable_to_non_nullable
as GoldRateAlert?,
  ));
}

/// Create a copy of AlertStatistics
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoldRateAlertCopyWith<$Res>? get mostTriggeredAlert {
    if (_self.mostTriggeredAlert == null) {
    return null;
  }

  return $GoldRateAlertCopyWith<$Res>(_self.mostTriggeredAlert!, (value) {
    return _then(_self.copyWith(mostTriggeredAlert: value));
  });
}/// Create a copy of AlertStatistics
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoldRateAlertCopyWith<$Res>? get recentlyTriggeredAlert {
    if (_self.recentlyTriggeredAlert == null) {
    return null;
  }

  return $GoldRateAlertCopyWith<$Res>(_self.recentlyTriggeredAlert!, (value) {
    return _then(_self.copyWith(recentlyTriggeredAlert: value));
  });
}
}

// dart format on
