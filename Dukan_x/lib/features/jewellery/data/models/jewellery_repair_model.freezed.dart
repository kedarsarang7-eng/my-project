// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jewellery_repair_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RepairStatusUpdate {

@HiveField(0) RepairStatus get status;@HiveField(1) DateTime get timestamp;@HiveField(2) String get updatedBy;@HiveField(3) String? get notes;@HiveField(4) List<String>? get photoUrls;
/// Create a copy of RepairStatusUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RepairStatusUpdateCopyWith<RepairStatusUpdate> get copyWith => _$RepairStatusUpdateCopyWithImpl<RepairStatusUpdate>(this as RepairStatusUpdate, _$identity);

  /// Serializes this RepairStatusUpdate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RepairStatusUpdate&&(identical(other.status, status) || other.status == status)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.photoUrls, photoUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,timestamp,updatedBy,notes,const DeepCollectionEquality().hash(photoUrls));

@override
String toString() {
  return 'RepairStatusUpdate(status: $status, timestamp: $timestamp, updatedBy: $updatedBy, notes: $notes, photoUrls: $photoUrls)';
}


}

/// @nodoc
abstract mixin class $RepairStatusUpdateCopyWith<$Res>  {
  factory $RepairStatusUpdateCopyWith(RepairStatusUpdate value, $Res Function(RepairStatusUpdate) _then) = _$RepairStatusUpdateCopyWithImpl;
@useResult
$Res call({
@HiveField(0) RepairStatus status,@HiveField(1) DateTime timestamp,@HiveField(2) String updatedBy,@HiveField(3) String? notes,@HiveField(4) List<String>? photoUrls
});




}
/// @nodoc
class _$RepairStatusUpdateCopyWithImpl<$Res>
    implements $RepairStatusUpdateCopyWith<$Res> {
  _$RepairStatusUpdateCopyWithImpl(this._self, this._then);

  final RepairStatusUpdate _self;
  final $Res Function(RepairStatusUpdate) _then;

/// Create a copy of RepairStatusUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? timestamp = null,Object? updatedBy = null,Object? notes = freezed,Object? photoUrls = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RepairStatus,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,photoUrls: freezed == photoUrls ? _self.photoUrls : photoUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [RepairStatusUpdate].
extension RepairStatusUpdatePatterns on RepairStatusUpdate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RepairStatusUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RepairStatusUpdate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RepairStatusUpdate value)  $default,){
final _that = this;
switch (_that) {
case _RepairStatusUpdate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RepairStatusUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _RepairStatusUpdate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  RepairStatus status, @HiveField(1)  DateTime timestamp, @HiveField(2)  String updatedBy, @HiveField(3)  String? notes, @HiveField(4)  List<String>? photoUrls)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RepairStatusUpdate() when $default != null:
return $default(_that.status,_that.timestamp,_that.updatedBy,_that.notes,_that.photoUrls);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  RepairStatus status, @HiveField(1)  DateTime timestamp, @HiveField(2)  String updatedBy, @HiveField(3)  String? notes, @HiveField(4)  List<String>? photoUrls)  $default,) {final _that = this;
switch (_that) {
case _RepairStatusUpdate():
return $default(_that.status,_that.timestamp,_that.updatedBy,_that.notes,_that.photoUrls);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  RepairStatus status, @HiveField(1)  DateTime timestamp, @HiveField(2)  String updatedBy, @HiveField(3)  String? notes, @HiveField(4)  List<String>? photoUrls)?  $default,) {final _that = this;
switch (_that) {
case _RepairStatusUpdate() when $default != null:
return $default(_that.status,_that.timestamp,_that.updatedBy,_that.notes,_that.photoUrls);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 62)
class _RepairStatusUpdate implements RepairStatusUpdate {
  const _RepairStatusUpdate({@HiveField(0) required this.status, @HiveField(1) required this.timestamp, @HiveField(2) required this.updatedBy, @HiveField(3) this.notes, @HiveField(4) final  List<String>? photoUrls}): _photoUrls = photoUrls;
  factory _RepairStatusUpdate.fromJson(Map<String, dynamic> json) => _$RepairStatusUpdateFromJson(json);

@override@HiveField(0) final  RepairStatus status;
@override@HiveField(1) final  DateTime timestamp;
@override@HiveField(2) final  String updatedBy;
@override@HiveField(3) final  String? notes;
 final  List<String>? _photoUrls;
@override@HiveField(4) List<String>? get photoUrls {
  final value = _photoUrls;
  if (value == null) return null;
  if (_photoUrls is EqualUnmodifiableListView) return _photoUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of RepairStatusUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RepairStatusUpdateCopyWith<_RepairStatusUpdate> get copyWith => __$RepairStatusUpdateCopyWithImpl<_RepairStatusUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RepairStatusUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RepairStatusUpdate&&(identical(other.status, status) || other.status == status)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other._photoUrls, _photoUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,timestamp,updatedBy,notes,const DeepCollectionEquality().hash(_photoUrls));

@override
String toString() {
  return 'RepairStatusUpdate(status: $status, timestamp: $timestamp, updatedBy: $updatedBy, notes: $notes, photoUrls: $photoUrls)';
}


}

/// @nodoc
abstract mixin class _$RepairStatusUpdateCopyWith<$Res> implements $RepairStatusUpdateCopyWith<$Res> {
  factory _$RepairStatusUpdateCopyWith(_RepairStatusUpdate value, $Res Function(_RepairStatusUpdate) _then) = __$RepairStatusUpdateCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) RepairStatus status,@HiveField(1) DateTime timestamp,@HiveField(2) String updatedBy,@HiveField(3) String? notes,@HiveField(4) List<String>? photoUrls
});




}
/// @nodoc
class __$RepairStatusUpdateCopyWithImpl<$Res>
    implements _$RepairStatusUpdateCopyWith<$Res> {
  __$RepairStatusUpdateCopyWithImpl(this._self, this._then);

  final _RepairStatusUpdate _self;
  final $Res Function(_RepairStatusUpdate) _then;

/// Create a copy of RepairStatusUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? timestamp = null,Object? updatedBy = null,Object? notes = freezed,Object? photoUrls = freezed,}) {
  return _then(_RepairStatusUpdate(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RepairStatus,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,updatedBy: null == updatedBy ? _self.updatedBy : updatedBy // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,photoUrls: freezed == photoUrls ? _self._photoUrls : photoUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}


/// @nodoc
mixin _$RepairWorkItem {

@HiveField(0) String get id;@HiveField(1) RepairType get type;@HiveField(2) String get description;@HiveField(3) int? get estimatedCostPaisa;@HiveField(4) int? get actualCostPaisa;@HiveField(5) bool get isCompleted;@HiveField(6) String? get completedBy;@HiveField(7) DateTime? get completedAt;@HiveField(8) String? get notes;
/// Create a copy of RepairWorkItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RepairWorkItemCopyWith<RepairWorkItem> get copyWith => _$RepairWorkItemCopyWithImpl<RepairWorkItem>(this as RepairWorkItem, _$identity);

  /// Serializes this RepairWorkItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RepairWorkItem&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description)&&(identical(other.estimatedCostPaisa, estimatedCostPaisa) || other.estimatedCostPaisa == estimatedCostPaisa)&&(identical(other.actualCostPaisa, actualCostPaisa) || other.actualCostPaisa == actualCostPaisa)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.completedBy, completedBy) || other.completedBy == completedBy)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,description,estimatedCostPaisa,actualCostPaisa,isCompleted,completedBy,completedAt,notes);

@override
String toString() {
  return 'RepairWorkItem(id: $id, type: $type, description: $description, estimatedCostPaisa: $estimatedCostPaisa, actualCostPaisa: $actualCostPaisa, isCompleted: $isCompleted, completedBy: $completedBy, completedAt: $completedAt, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $RepairWorkItemCopyWith<$Res>  {
  factory $RepairWorkItemCopyWith(RepairWorkItem value, $Res Function(RepairWorkItem) _then) = _$RepairWorkItemCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) RepairType type,@HiveField(2) String description,@HiveField(3) int? estimatedCostPaisa,@HiveField(4) int? actualCostPaisa,@HiveField(5) bool isCompleted,@HiveField(6) String? completedBy,@HiveField(7) DateTime? completedAt,@HiveField(8) String? notes
});




}
/// @nodoc
class _$RepairWorkItemCopyWithImpl<$Res>
    implements $RepairWorkItemCopyWith<$Res> {
  _$RepairWorkItemCopyWithImpl(this._self, this._then);

  final RepairWorkItem _self;
  final $Res Function(RepairWorkItem) _then;

/// Create a copy of RepairWorkItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? description = null,Object? estimatedCostPaisa = freezed,Object? actualCostPaisa = freezed,Object? isCompleted = null,Object? completedBy = freezed,Object? completedAt = freezed,Object? notes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RepairType,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,estimatedCostPaisa: freezed == estimatedCostPaisa ? _self.estimatedCostPaisa : estimatedCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,actualCostPaisa: freezed == actualCostPaisa ? _self.actualCostPaisa : actualCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,completedBy: freezed == completedBy ? _self.completedBy : completedBy // ignore: cast_nullable_to_non_nullable
as String?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RepairWorkItem].
extension RepairWorkItemPatterns on RepairWorkItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RepairWorkItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RepairWorkItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RepairWorkItem value)  $default,){
final _that = this;
switch (_that) {
case _RepairWorkItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RepairWorkItem value)?  $default,){
final _that = this;
switch (_that) {
case _RepairWorkItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  RepairType type, @HiveField(2)  String description, @HiveField(3)  int? estimatedCostPaisa, @HiveField(4)  int? actualCostPaisa, @HiveField(5)  bool isCompleted, @HiveField(6)  String? completedBy, @HiveField(7)  DateTime? completedAt, @HiveField(8)  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RepairWorkItem() when $default != null:
return $default(_that.id,_that.type,_that.description,_that.estimatedCostPaisa,_that.actualCostPaisa,_that.isCompleted,_that.completedBy,_that.completedAt,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  RepairType type, @HiveField(2)  String description, @HiveField(3)  int? estimatedCostPaisa, @HiveField(4)  int? actualCostPaisa, @HiveField(5)  bool isCompleted, @HiveField(6)  String? completedBy, @HiveField(7)  DateTime? completedAt, @HiveField(8)  String? notes)  $default,) {final _that = this;
switch (_that) {
case _RepairWorkItem():
return $default(_that.id,_that.type,_that.description,_that.estimatedCostPaisa,_that.actualCostPaisa,_that.isCompleted,_that.completedBy,_that.completedAt,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  RepairType type, @HiveField(2)  String description, @HiveField(3)  int? estimatedCostPaisa, @HiveField(4)  int? actualCostPaisa, @HiveField(5)  bool isCompleted, @HiveField(6)  String? completedBy, @HiveField(7)  DateTime? completedAt, @HiveField(8)  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _RepairWorkItem() when $default != null:
return $default(_that.id,_that.type,_that.description,_that.estimatedCostPaisa,_that.actualCostPaisa,_that.isCompleted,_that.completedBy,_that.completedAt,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 63)
class _RepairWorkItem extends RepairWorkItem {
  const _RepairWorkItem({@HiveField(0) required this.id, @HiveField(1) required this.type, @HiveField(2) required this.description, @HiveField(3) this.estimatedCostPaisa, @HiveField(4) this.actualCostPaisa, @HiveField(5) this.isCompleted = false, @HiveField(6) this.completedBy, @HiveField(7) this.completedAt, @HiveField(8) this.notes}): super._();
  factory _RepairWorkItem.fromJson(Map<String, dynamic> json) => _$RepairWorkItemFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  RepairType type;
@override@HiveField(2) final  String description;
@override@HiveField(3) final  int? estimatedCostPaisa;
@override@HiveField(4) final  int? actualCostPaisa;
@override@JsonKey()@HiveField(5) final  bool isCompleted;
@override@HiveField(6) final  String? completedBy;
@override@HiveField(7) final  DateTime? completedAt;
@override@HiveField(8) final  String? notes;

/// Create a copy of RepairWorkItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RepairWorkItemCopyWith<_RepairWorkItem> get copyWith => __$RepairWorkItemCopyWithImpl<_RepairWorkItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RepairWorkItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RepairWorkItem&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description)&&(identical(other.estimatedCostPaisa, estimatedCostPaisa) || other.estimatedCostPaisa == estimatedCostPaisa)&&(identical(other.actualCostPaisa, actualCostPaisa) || other.actualCostPaisa == actualCostPaisa)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.completedBy, completedBy) || other.completedBy == completedBy)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,description,estimatedCostPaisa,actualCostPaisa,isCompleted,completedBy,completedAt,notes);

@override
String toString() {
  return 'RepairWorkItem(id: $id, type: $type, description: $description, estimatedCostPaisa: $estimatedCostPaisa, actualCostPaisa: $actualCostPaisa, isCompleted: $isCompleted, completedBy: $completedBy, completedAt: $completedAt, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$RepairWorkItemCopyWith<$Res> implements $RepairWorkItemCopyWith<$Res> {
  factory _$RepairWorkItemCopyWith(_RepairWorkItem value, $Res Function(_RepairWorkItem) _then) = __$RepairWorkItemCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) RepairType type,@HiveField(2) String description,@HiveField(3) int? estimatedCostPaisa,@HiveField(4) int? actualCostPaisa,@HiveField(5) bool isCompleted,@HiveField(6) String? completedBy,@HiveField(7) DateTime? completedAt,@HiveField(8) String? notes
});




}
/// @nodoc
class __$RepairWorkItemCopyWithImpl<$Res>
    implements _$RepairWorkItemCopyWith<$Res> {
  __$RepairWorkItemCopyWithImpl(this._self, this._then);

  final _RepairWorkItem _self;
  final $Res Function(_RepairWorkItem) _then;

/// Create a copy of RepairWorkItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? description = null,Object? estimatedCostPaisa = freezed,Object? actualCostPaisa = freezed,Object? isCompleted = null,Object? completedBy = freezed,Object? completedAt = freezed,Object? notes = freezed,}) {
  return _then(_RepairWorkItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RepairType,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,estimatedCostPaisa: freezed == estimatedCostPaisa ? _self.estimatedCostPaisa : estimatedCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,actualCostPaisa: freezed == actualCostPaisa ? _self.actualCostPaisa : actualCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,completedBy: freezed == completedBy ? _self.completedBy : completedBy // ignore: cast_nullable_to_non_nullable
as String?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$RepairMaterial {

@HiveField(0) String get id;@HiveField(1) String get name;@HiveField(2) double get quantity;@HiveField(3) String get unit;@HiveField(4) int get costPaisa;@HiveField(5) String? get supplier;@HiveField(6) String? get notes;
/// Create a copy of RepairMaterial
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RepairMaterialCopyWith<RepairMaterial> get copyWith => _$RepairMaterialCopyWithImpl<RepairMaterial>(this as RepairMaterial, _$identity);

  /// Serializes this RepairMaterial to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RepairMaterial&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.costPaisa, costPaisa) || other.costPaisa == costPaisa)&&(identical(other.supplier, supplier) || other.supplier == supplier)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,quantity,unit,costPaisa,supplier,notes);

@override
String toString() {
  return 'RepairMaterial(id: $id, name: $name, quantity: $quantity, unit: $unit, costPaisa: $costPaisa, supplier: $supplier, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $RepairMaterialCopyWith<$Res>  {
  factory $RepairMaterialCopyWith(RepairMaterial value, $Res Function(RepairMaterial) _then) = _$RepairMaterialCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String name,@HiveField(2) double quantity,@HiveField(3) String unit,@HiveField(4) int costPaisa,@HiveField(5) String? supplier,@HiveField(6) String? notes
});




}
/// @nodoc
class _$RepairMaterialCopyWithImpl<$Res>
    implements $RepairMaterialCopyWith<$Res> {
  _$RepairMaterialCopyWithImpl(this._self, this._then);

  final RepairMaterial _self;
  final $Res Function(RepairMaterial) _then;

/// Create a copy of RepairMaterial
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? quantity = null,Object? unit = null,Object? costPaisa = null,Object? supplier = freezed,Object? notes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,costPaisa: null == costPaisa ? _self.costPaisa : costPaisa // ignore: cast_nullable_to_non_nullable
as int,supplier: freezed == supplier ? _self.supplier : supplier // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RepairMaterial].
extension RepairMaterialPatterns on RepairMaterial {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RepairMaterial value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RepairMaterial() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RepairMaterial value)  $default,){
final _that = this;
switch (_that) {
case _RepairMaterial():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RepairMaterial value)?  $default,){
final _that = this;
switch (_that) {
case _RepairMaterial() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String name, @HiveField(2)  double quantity, @HiveField(3)  String unit, @HiveField(4)  int costPaisa, @HiveField(5)  String? supplier, @HiveField(6)  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RepairMaterial() when $default != null:
return $default(_that.id,_that.name,_that.quantity,_that.unit,_that.costPaisa,_that.supplier,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String name, @HiveField(2)  double quantity, @HiveField(3)  String unit, @HiveField(4)  int costPaisa, @HiveField(5)  String? supplier, @HiveField(6)  String? notes)  $default,) {final _that = this;
switch (_that) {
case _RepairMaterial():
return $default(_that.id,_that.name,_that.quantity,_that.unit,_that.costPaisa,_that.supplier,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String name, @HiveField(2)  double quantity, @HiveField(3)  String unit, @HiveField(4)  int costPaisa, @HiveField(5)  String? supplier, @HiveField(6)  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _RepairMaterial() when $default != null:
return $default(_that.id,_that.name,_that.quantity,_that.unit,_that.costPaisa,_that.supplier,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 64)
class _RepairMaterial extends RepairMaterial {
  const _RepairMaterial({@HiveField(0) required this.id, @HiveField(1) required this.name, @HiveField(2) required this.quantity, @HiveField(3) required this.unit, @HiveField(4) required this.costPaisa, @HiveField(5) this.supplier, @HiveField(6) this.notes}): super._();
  factory _RepairMaterial.fromJson(Map<String, dynamic> json) => _$RepairMaterialFromJson(json);

@override@HiveField(0) final  String id;
@override@HiveField(1) final  String name;
@override@HiveField(2) final  double quantity;
@override@HiveField(3) final  String unit;
@override@HiveField(4) final  int costPaisa;
@override@HiveField(5) final  String? supplier;
@override@HiveField(6) final  String? notes;

/// Create a copy of RepairMaterial
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RepairMaterialCopyWith<_RepairMaterial> get copyWith => __$RepairMaterialCopyWithImpl<_RepairMaterial>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RepairMaterialToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RepairMaterial&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.costPaisa, costPaisa) || other.costPaisa == costPaisa)&&(identical(other.supplier, supplier) || other.supplier == supplier)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,quantity,unit,costPaisa,supplier,notes);

@override
String toString() {
  return 'RepairMaterial(id: $id, name: $name, quantity: $quantity, unit: $unit, costPaisa: $costPaisa, supplier: $supplier, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$RepairMaterialCopyWith<$Res> implements $RepairMaterialCopyWith<$Res> {
  factory _$RepairMaterialCopyWith(_RepairMaterial value, $Res Function(_RepairMaterial) _then) = __$RepairMaterialCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String name,@HiveField(2) double quantity,@HiveField(3) String unit,@HiveField(4) int costPaisa,@HiveField(5) String? supplier,@HiveField(6) String? notes
});




}
/// @nodoc
class __$RepairMaterialCopyWithImpl<$Res>
    implements _$RepairMaterialCopyWith<$Res> {
  __$RepairMaterialCopyWithImpl(this._self, this._then);

  final _RepairMaterial _self;
  final $Res Function(_RepairMaterial) _then;

/// Create a copy of RepairMaterial
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? quantity = null,Object? unit = null,Object? costPaisa = null,Object? supplier = freezed,Object? notes = freezed,}) {
  return _then(_RepairMaterial(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as double,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,costPaisa: null == costPaisa ? _self.costPaisa : costPaisa // ignore: cast_nullable_to_non_nullable
as int,supplier: freezed == supplier ? _self.supplier : supplier // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$JewelleryRepair {

// Core identifiers
@HiveField(0) String get id;@HiveField(1) String get tenantId;@HiveField(2) String get jobNumber;// Unique job number (e.g., JOB-2024-0001)
// Customer info
@HiveField(3) String get customerId;@HiveField(4) String get customerName;@HiveField(5) String? get customerPhone;@HiveField(6) String? get customerEmail;// Item details
@HiveField(7) String get itemDescription;@HiveField(8) String? get itemCategory;// Ring, Chain, etc.
@HiveField(9) String? get metalType;// Gold 22K, Silver, etc.
@HiveField(10) double? get weightGrams;@HiveField(11) String? get productId;// If linked to inventory
// Job details
@HiveField(12) List<RepairWorkItem> get workItems;@HiveField(13) List<RepairMaterial>? get materials;// Status
@HiveField(14) RepairStatus get status;@HiveField(15) RepairPriority get priority;@HiveField(16) List<RepairStatusUpdate>? get statusHistory;// Initial condition photos
@HiveField(17) List<String>? get conditionPhotoUrls;@HiveField(18) String? get customerComplaint;// What customer reported
// Damage assessment
@HiveField(19) String? get damageAssessment;@HiveField(20) String? get recommendedWork;@HiveField(21) int? get estimatedCostPaisa;@HiveField(22) int? get estimatedDays;@HiveField(23) DateTime? get estimatedCompletionDate;// Actual costs
@HiveField(24) int? get actualCostPaisa;@HiveField(25) int? get materialCostPaisa;@HiveField(26) int? get laborCostPaisa;@HiveField(27) int? get additionalChargesPaisa;@HiveField(28) String? get additionalChargesNote;// Advance payment
@HiveField(29) int get advanceReceivedPaisa;// Assigned craftsmen
@HiveField(30) String? get assignedTo;@HiveField(31) String? get assignedToName;@HiveField(32) DateTime? get assignedAt;// Timeline
@HiveField(33) DateTime get receivedDate;@HiveField(34) DateTime? get promisedDate;@HiveField(35) DateTime? get completedDate;@HiveField(36) DateTime? get deliveredDate;// Work tracking
@HiveField(37) DateTime? get workStartedDate;@HiveField(38) DateTime? get workCompletedDate;@HiveField(39) int? get actualWorkHours;// Delivery
@HiveField(40) String? get deliveredTo;@HiveField(41) String? get deliveryNotes;@HiveField(42) List<String>? get completionPhotoUrls;// Warranty
@HiveField(43) int get warrantyDays;@HiveField(44) DateTime? get warrantyExpiryDate;// Warranty claim (if this is a re-repair)
@HiveField(45) String? get originalJobId;// If this is a warranty claim
@HiveField(46) bool get isWarrantyClaim;// Customer feedback
@HiveField(47) int? get customerRating;// 1-5 stars
@HiveField(48) String? get customerFeedback;// Invoice
@HiveField(49) String? get invoiceId;@HiveField(50) bool get isPaid;// Metadata
@HiveField(51) DateTime get createdAt;@HiveField(52) String get createdBy;@HiveField(53) DateTime get updatedAt;@HiveField(54) String get updatedBy;// Sync
@HiveField(55) bool get synced;@HiveField(56) DateTime? get lastSyncedAt;@HiveField(57) String? get pendingOperation;
/// Create a copy of JewelleryRepair
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JewelleryRepairCopyWith<JewelleryRepair> get copyWith => _$JewelleryRepairCopyWithImpl<JewelleryRepair>(this as JewelleryRepair, _$identity);

  /// Serializes this JewelleryRepair to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JewelleryRepair&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.jobNumber, jobNumber) || other.jobNumber == jobNumber)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerEmail, customerEmail) || other.customerEmail == customerEmail)&&(identical(other.itemDescription, itemDescription) || other.itemDescription == itemDescription)&&(identical(other.itemCategory, itemCategory) || other.itemCategory == itemCategory)&&(identical(other.metalType, metalType) || other.metalType == metalType)&&(identical(other.weightGrams, weightGrams) || other.weightGrams == weightGrams)&&(identical(other.productId, productId) || other.productId == productId)&&const DeepCollectionEquality().equals(other.workItems, workItems)&&const DeepCollectionEquality().equals(other.materials, materials)&&(identical(other.status, status) || other.status == status)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other.statusHistory, statusHistory)&&const DeepCollectionEquality().equals(other.conditionPhotoUrls, conditionPhotoUrls)&&(identical(other.customerComplaint, customerComplaint) || other.customerComplaint == customerComplaint)&&(identical(other.damageAssessment, damageAssessment) || other.damageAssessment == damageAssessment)&&(identical(other.recommendedWork, recommendedWork) || other.recommendedWork == recommendedWork)&&(identical(other.estimatedCostPaisa, estimatedCostPaisa) || other.estimatedCostPaisa == estimatedCostPaisa)&&(identical(other.estimatedDays, estimatedDays) || other.estimatedDays == estimatedDays)&&(identical(other.estimatedCompletionDate, estimatedCompletionDate) || other.estimatedCompletionDate == estimatedCompletionDate)&&(identical(other.actualCostPaisa, actualCostPaisa) || other.actualCostPaisa == actualCostPaisa)&&(identical(other.materialCostPaisa, materialCostPaisa) || other.materialCostPaisa == materialCostPaisa)&&(identical(other.laborCostPaisa, laborCostPaisa) || other.laborCostPaisa == laborCostPaisa)&&(identical(other.additionalChargesPaisa, additionalChargesPaisa) || other.additionalChargesPaisa == additionalChargesPaisa)&&(identical(other.additionalChargesNote, additionalChargesNote) || other.additionalChargesNote == additionalChargesNote)&&(identical(other.advanceReceivedPaisa, advanceReceivedPaisa) || other.advanceReceivedPaisa == advanceReceivedPaisa)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.assignedToName, assignedToName) || other.assignedToName == assignedToName)&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.receivedDate, receivedDate) || other.receivedDate == receivedDate)&&(identical(other.promisedDate, promisedDate) || other.promisedDate == promisedDate)&&(identical(other.completedDate, completedDate) || other.completedDate == completedDate)&&(identical(other.deliveredDate, deliveredDate) || other.deliveredDate == deliveredDate)&&(identical(other.workStartedDate, workStartedDate) || other.workStartedDate == workStartedDate)&&(identical(other.workCompletedDate, workCompletedDate) || other.workCompletedDate == workCompletedDate)&&(identical(other.actualWorkHours, actualWorkHours) || other.actualWorkHours == actualWorkHours)&&(identical(other.deliveredTo, deliveredTo) || other.deliveredTo == deliveredTo)&&(identical(other.deliveryNotes, deliveryNotes) || other.deliveryNotes == deliveryNotes)&&const DeepCollectionEquality().equals(other.completionPhotoUrls, completionPhotoUrls)&&(identical(other.warrantyDays, warrantyDays) || other.warrantyDays == warrantyDays)&&(identical(other.warrantyExpiryDate, warrantyExpiryDate) || other.warrantyExpiryDate == warrantyExpiryDate)&&(identical(other.originalJobId, originalJobId) || other.originalJobId == originalJobId)&&(identical(other.isWarrantyClaim, isWarrantyClaim) || other.isWarrantyClaim == isWarrantyClaim)&&(identical(other.customerRating, customerRating) || other.customerRating == customerRating)&&(identical(other.customerFeedback, customerFeedback) || other.customerFeedback == customerFeedback)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.isPaid, isPaid) || other.isPaid == isPaid)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,jobNumber,customerId,customerName,customerPhone,customerEmail,itemDescription,itemCategory,metalType,weightGrams,productId,const DeepCollectionEquality().hash(workItems),const DeepCollectionEquality().hash(materials),status,priority,const DeepCollectionEquality().hash(statusHistory),const DeepCollectionEquality().hash(conditionPhotoUrls),customerComplaint,damageAssessment,recommendedWork,estimatedCostPaisa,estimatedDays,estimatedCompletionDate,actualCostPaisa,materialCostPaisa,laborCostPaisa,additionalChargesPaisa,additionalChargesNote,advanceReceivedPaisa,assignedTo,assignedToName,assignedAt,receivedDate,promisedDate,completedDate,deliveredDate,workStartedDate,workCompletedDate,actualWorkHours,deliveredTo,deliveryNotes,const DeepCollectionEquality().hash(completionPhotoUrls),warrantyDays,warrantyExpiryDate,originalJobId,isWarrantyClaim,customerRating,customerFeedback,invoiceId,isPaid,createdAt,createdBy,updatedAt,updatedBy,synced,lastSyncedAt,pendingOperation]);

@override
String toString() {
  return 'JewelleryRepair(id: $id, tenantId: $tenantId, jobNumber: $jobNumber, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, customerEmail: $customerEmail, itemDescription: $itemDescription, itemCategory: $itemCategory, metalType: $metalType, weightGrams: $weightGrams, productId: $productId, workItems: $workItems, materials: $materials, status: $status, priority: $priority, statusHistory: $statusHistory, conditionPhotoUrls: $conditionPhotoUrls, customerComplaint: $customerComplaint, damageAssessment: $damageAssessment, recommendedWork: $recommendedWork, estimatedCostPaisa: $estimatedCostPaisa, estimatedDays: $estimatedDays, estimatedCompletionDate: $estimatedCompletionDate, actualCostPaisa: $actualCostPaisa, materialCostPaisa: $materialCostPaisa, laborCostPaisa: $laborCostPaisa, additionalChargesPaisa: $additionalChargesPaisa, additionalChargesNote: $additionalChargesNote, advanceReceivedPaisa: $advanceReceivedPaisa, assignedTo: $assignedTo, assignedToName: $assignedToName, assignedAt: $assignedAt, receivedDate: $receivedDate, promisedDate: $promisedDate, completedDate: $completedDate, deliveredDate: $deliveredDate, workStartedDate: $workStartedDate, workCompletedDate: $workCompletedDate, actualWorkHours: $actualWorkHours, deliveredTo: $deliveredTo, deliveryNotes: $deliveryNotes, completionPhotoUrls: $completionPhotoUrls, warrantyDays: $warrantyDays, warrantyExpiryDate: $warrantyExpiryDate, originalJobId: $originalJobId, isWarrantyClaim: $isWarrantyClaim, customerRating: $customerRating, customerFeedback: $customerFeedback, invoiceId: $invoiceId, isPaid: $isPaid, createdAt: $createdAt, createdBy: $createdBy, updatedAt: $updatedAt, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class $JewelleryRepairCopyWith<$Res>  {
  factory $JewelleryRepairCopyWith(JewelleryRepair value, $Res Function(JewelleryRepair) _then) = _$JewelleryRepairCopyWithImpl;
@useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String jobNumber,@HiveField(3) String customerId,@HiveField(4) String customerName,@HiveField(5) String? customerPhone,@HiveField(6) String? customerEmail,@HiveField(7) String itemDescription,@HiveField(8) String? itemCategory,@HiveField(9) String? metalType,@HiveField(10) double? weightGrams,@HiveField(11) String? productId,@HiveField(12) List<RepairWorkItem> workItems,@HiveField(13) List<RepairMaterial>? materials,@HiveField(14) RepairStatus status,@HiveField(15) RepairPriority priority,@HiveField(16) List<RepairStatusUpdate>? statusHistory,@HiveField(17) List<String>? conditionPhotoUrls,@HiveField(18) String? customerComplaint,@HiveField(19) String? damageAssessment,@HiveField(20) String? recommendedWork,@HiveField(21) int? estimatedCostPaisa,@HiveField(22) int? estimatedDays,@HiveField(23) DateTime? estimatedCompletionDate,@HiveField(24) int? actualCostPaisa,@HiveField(25) int? materialCostPaisa,@HiveField(26) int? laborCostPaisa,@HiveField(27) int? additionalChargesPaisa,@HiveField(28) String? additionalChargesNote,@HiveField(29) int advanceReceivedPaisa,@HiveField(30) String? assignedTo,@HiveField(31) String? assignedToName,@HiveField(32) DateTime? assignedAt,@HiveField(33) DateTime receivedDate,@HiveField(34) DateTime? promisedDate,@HiveField(35) DateTime? completedDate,@HiveField(36) DateTime? deliveredDate,@HiveField(37) DateTime? workStartedDate,@HiveField(38) DateTime? workCompletedDate,@HiveField(39) int? actualWorkHours,@HiveField(40) String? deliveredTo,@HiveField(41) String? deliveryNotes,@HiveField(42) List<String>? completionPhotoUrls,@HiveField(43) int warrantyDays,@HiveField(44) DateTime? warrantyExpiryDate,@HiveField(45) String? originalJobId,@HiveField(46) bool isWarrantyClaim,@HiveField(47) int? customerRating,@HiveField(48) String? customerFeedback,@HiveField(49) String? invoiceId,@HiveField(50) bool isPaid,@HiveField(51) DateTime createdAt,@HiveField(52) String createdBy,@HiveField(53) DateTime updatedAt,@HiveField(54) String updatedBy,@HiveField(55) bool synced,@HiveField(56) DateTime? lastSyncedAt,@HiveField(57) String? pendingOperation
});




}
/// @nodoc
class _$JewelleryRepairCopyWithImpl<$Res>
    implements $JewelleryRepairCopyWith<$Res> {
  _$JewelleryRepairCopyWithImpl(this._self, this._then);

  final JewelleryRepair _self;
  final $Res Function(JewelleryRepair) _then;

/// Create a copy of JewelleryRepair
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? jobNumber = null,Object? customerId = null,Object? customerName = null,Object? customerPhone = freezed,Object? customerEmail = freezed,Object? itemDescription = null,Object? itemCategory = freezed,Object? metalType = freezed,Object? weightGrams = freezed,Object? productId = freezed,Object? workItems = null,Object? materials = freezed,Object? status = null,Object? priority = null,Object? statusHistory = freezed,Object? conditionPhotoUrls = freezed,Object? customerComplaint = freezed,Object? damageAssessment = freezed,Object? recommendedWork = freezed,Object? estimatedCostPaisa = freezed,Object? estimatedDays = freezed,Object? estimatedCompletionDate = freezed,Object? actualCostPaisa = freezed,Object? materialCostPaisa = freezed,Object? laborCostPaisa = freezed,Object? additionalChargesPaisa = freezed,Object? additionalChargesNote = freezed,Object? advanceReceivedPaisa = null,Object? assignedTo = freezed,Object? assignedToName = freezed,Object? assignedAt = freezed,Object? receivedDate = null,Object? promisedDate = freezed,Object? completedDate = freezed,Object? deliveredDate = freezed,Object? workStartedDate = freezed,Object? workCompletedDate = freezed,Object? actualWorkHours = freezed,Object? deliveredTo = freezed,Object? deliveryNotes = freezed,Object? completionPhotoUrls = freezed,Object? warrantyDays = null,Object? warrantyExpiryDate = freezed,Object? originalJobId = freezed,Object? isWarrantyClaim = null,Object? customerRating = freezed,Object? customerFeedback = freezed,Object? invoiceId = freezed,Object? isPaid = null,Object? createdAt = null,Object? createdBy = null,Object? updatedAt = null,Object? updatedBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,jobNumber: null == jobNumber ? _self.jobNumber : jobNumber // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerEmail: freezed == customerEmail ? _self.customerEmail : customerEmail // ignore: cast_nullable_to_non_nullable
as String?,itemDescription: null == itemDescription ? _self.itemDescription : itemDescription // ignore: cast_nullable_to_non_nullable
as String,itemCategory: freezed == itemCategory ? _self.itemCategory : itemCategory // ignore: cast_nullable_to_non_nullable
as String?,metalType: freezed == metalType ? _self.metalType : metalType // ignore: cast_nullable_to_non_nullable
as String?,weightGrams: freezed == weightGrams ? _self.weightGrams : weightGrams // ignore: cast_nullable_to_non_nullable
as double?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,workItems: null == workItems ? _self.workItems : workItems // ignore: cast_nullable_to_non_nullable
as List<RepairWorkItem>,materials: freezed == materials ? _self.materials : materials // ignore: cast_nullable_to_non_nullable
as List<RepairMaterial>?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RepairStatus,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as RepairPriority,statusHistory: freezed == statusHistory ? _self.statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<RepairStatusUpdate>?,conditionPhotoUrls: freezed == conditionPhotoUrls ? _self.conditionPhotoUrls : conditionPhotoUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,customerComplaint: freezed == customerComplaint ? _self.customerComplaint : customerComplaint // ignore: cast_nullable_to_non_nullable
as String?,damageAssessment: freezed == damageAssessment ? _self.damageAssessment : damageAssessment // ignore: cast_nullable_to_non_nullable
as String?,recommendedWork: freezed == recommendedWork ? _self.recommendedWork : recommendedWork // ignore: cast_nullable_to_non_nullable
as String?,estimatedCostPaisa: freezed == estimatedCostPaisa ? _self.estimatedCostPaisa : estimatedCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,estimatedDays: freezed == estimatedDays ? _self.estimatedDays : estimatedDays // ignore: cast_nullable_to_non_nullable
as int?,estimatedCompletionDate: freezed == estimatedCompletionDate ? _self.estimatedCompletionDate : estimatedCompletionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,actualCostPaisa: freezed == actualCostPaisa ? _self.actualCostPaisa : actualCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,materialCostPaisa: freezed == materialCostPaisa ? _self.materialCostPaisa : materialCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,laborCostPaisa: freezed == laborCostPaisa ? _self.laborCostPaisa : laborCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,additionalChargesPaisa: freezed == additionalChargesPaisa ? _self.additionalChargesPaisa : additionalChargesPaisa // ignore: cast_nullable_to_non_nullable
as int?,additionalChargesNote: freezed == additionalChargesNote ? _self.additionalChargesNote : additionalChargesNote // ignore: cast_nullable_to_non_nullable
as String?,advanceReceivedPaisa: null == advanceReceivedPaisa ? _self.advanceReceivedPaisa : advanceReceivedPaisa // ignore: cast_nullable_to_non_nullable
as int,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,assignedToName: freezed == assignedToName ? _self.assignedToName : assignedToName // ignore: cast_nullable_to_non_nullable
as String?,assignedAt: freezed == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,receivedDate: null == receivedDate ? _self.receivedDate : receivedDate // ignore: cast_nullable_to_non_nullable
as DateTime,promisedDate: freezed == promisedDate ? _self.promisedDate : promisedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,completedDate: freezed == completedDate ? _self.completedDate : completedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveredDate: freezed == deliveredDate ? _self.deliveredDate : deliveredDate // ignore: cast_nullable_to_non_nullable
as DateTime?,workStartedDate: freezed == workStartedDate ? _self.workStartedDate : workStartedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,workCompletedDate: freezed == workCompletedDate ? _self.workCompletedDate : workCompletedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,actualWorkHours: freezed == actualWorkHours ? _self.actualWorkHours : actualWorkHours // ignore: cast_nullable_to_non_nullable
as int?,deliveredTo: freezed == deliveredTo ? _self.deliveredTo : deliveredTo // ignore: cast_nullable_to_non_nullable
as String?,deliveryNotes: freezed == deliveryNotes ? _self.deliveryNotes : deliveryNotes // ignore: cast_nullable_to_non_nullable
as String?,completionPhotoUrls: freezed == completionPhotoUrls ? _self.completionPhotoUrls : completionPhotoUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,warrantyDays: null == warrantyDays ? _self.warrantyDays : warrantyDays // ignore: cast_nullable_to_non_nullable
as int,warrantyExpiryDate: freezed == warrantyExpiryDate ? _self.warrantyExpiryDate : warrantyExpiryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,originalJobId: freezed == originalJobId ? _self.originalJobId : originalJobId // ignore: cast_nullable_to_non_nullable
as String?,isWarrantyClaim: null == isWarrantyClaim ? _self.isWarrantyClaim : isWarrantyClaim // ignore: cast_nullable_to_non_nullable
as bool,customerRating: freezed == customerRating ? _self.customerRating : customerRating // ignore: cast_nullable_to_non_nullable
as int?,customerFeedback: freezed == customerFeedback ? _self.customerFeedback : customerFeedback // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,isPaid: null == isPaid ? _self.isPaid : isPaid // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
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


/// Adds pattern-matching-related methods to [JewelleryRepair].
extension JewelleryRepairPatterns on JewelleryRepair {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JewelleryRepair value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JewelleryRepair() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JewelleryRepair value)  $default,){
final _that = this;
switch (_that) {
case _JewelleryRepair():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JewelleryRepair value)?  $default,){
final _that = this;
switch (_that) {
case _JewelleryRepair() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String jobNumber, @HiveField(3)  String customerId, @HiveField(4)  String customerName, @HiveField(5)  String? customerPhone, @HiveField(6)  String? customerEmail, @HiveField(7)  String itemDescription, @HiveField(8)  String? itemCategory, @HiveField(9)  String? metalType, @HiveField(10)  double? weightGrams, @HiveField(11)  String? productId, @HiveField(12)  List<RepairWorkItem> workItems, @HiveField(13)  List<RepairMaterial>? materials, @HiveField(14)  RepairStatus status, @HiveField(15)  RepairPriority priority, @HiveField(16)  List<RepairStatusUpdate>? statusHistory, @HiveField(17)  List<String>? conditionPhotoUrls, @HiveField(18)  String? customerComplaint, @HiveField(19)  String? damageAssessment, @HiveField(20)  String? recommendedWork, @HiveField(21)  int? estimatedCostPaisa, @HiveField(22)  int? estimatedDays, @HiveField(23)  DateTime? estimatedCompletionDate, @HiveField(24)  int? actualCostPaisa, @HiveField(25)  int? materialCostPaisa, @HiveField(26)  int? laborCostPaisa, @HiveField(27)  int? additionalChargesPaisa, @HiveField(28)  String? additionalChargesNote, @HiveField(29)  int advanceReceivedPaisa, @HiveField(30)  String? assignedTo, @HiveField(31)  String? assignedToName, @HiveField(32)  DateTime? assignedAt, @HiveField(33)  DateTime receivedDate, @HiveField(34)  DateTime? promisedDate, @HiveField(35)  DateTime? completedDate, @HiveField(36)  DateTime? deliveredDate, @HiveField(37)  DateTime? workStartedDate, @HiveField(38)  DateTime? workCompletedDate, @HiveField(39)  int? actualWorkHours, @HiveField(40)  String? deliveredTo, @HiveField(41)  String? deliveryNotes, @HiveField(42)  List<String>? completionPhotoUrls, @HiveField(43)  int warrantyDays, @HiveField(44)  DateTime? warrantyExpiryDate, @HiveField(45)  String? originalJobId, @HiveField(46)  bool isWarrantyClaim, @HiveField(47)  int? customerRating, @HiveField(48)  String? customerFeedback, @HiveField(49)  String? invoiceId, @HiveField(50)  bool isPaid, @HiveField(51)  DateTime createdAt, @HiveField(52)  String createdBy, @HiveField(53)  DateTime updatedAt, @HiveField(54)  String updatedBy, @HiveField(55)  bool synced, @HiveField(56)  DateTime? lastSyncedAt, @HiveField(57)  String? pendingOperation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JewelleryRepair() when $default != null:
return $default(_that.id,_that.tenantId,_that.jobNumber,_that.customerId,_that.customerName,_that.customerPhone,_that.customerEmail,_that.itemDescription,_that.itemCategory,_that.metalType,_that.weightGrams,_that.productId,_that.workItems,_that.materials,_that.status,_that.priority,_that.statusHistory,_that.conditionPhotoUrls,_that.customerComplaint,_that.damageAssessment,_that.recommendedWork,_that.estimatedCostPaisa,_that.estimatedDays,_that.estimatedCompletionDate,_that.actualCostPaisa,_that.materialCostPaisa,_that.laborCostPaisa,_that.additionalChargesPaisa,_that.additionalChargesNote,_that.advanceReceivedPaisa,_that.assignedTo,_that.assignedToName,_that.assignedAt,_that.receivedDate,_that.promisedDate,_that.completedDate,_that.deliveredDate,_that.workStartedDate,_that.workCompletedDate,_that.actualWorkHours,_that.deliveredTo,_that.deliveryNotes,_that.completionPhotoUrls,_that.warrantyDays,_that.warrantyExpiryDate,_that.originalJobId,_that.isWarrantyClaim,_that.customerRating,_that.customerFeedback,_that.invoiceId,_that.isPaid,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String jobNumber, @HiveField(3)  String customerId, @HiveField(4)  String customerName, @HiveField(5)  String? customerPhone, @HiveField(6)  String? customerEmail, @HiveField(7)  String itemDescription, @HiveField(8)  String? itemCategory, @HiveField(9)  String? metalType, @HiveField(10)  double? weightGrams, @HiveField(11)  String? productId, @HiveField(12)  List<RepairWorkItem> workItems, @HiveField(13)  List<RepairMaterial>? materials, @HiveField(14)  RepairStatus status, @HiveField(15)  RepairPriority priority, @HiveField(16)  List<RepairStatusUpdate>? statusHistory, @HiveField(17)  List<String>? conditionPhotoUrls, @HiveField(18)  String? customerComplaint, @HiveField(19)  String? damageAssessment, @HiveField(20)  String? recommendedWork, @HiveField(21)  int? estimatedCostPaisa, @HiveField(22)  int? estimatedDays, @HiveField(23)  DateTime? estimatedCompletionDate, @HiveField(24)  int? actualCostPaisa, @HiveField(25)  int? materialCostPaisa, @HiveField(26)  int? laborCostPaisa, @HiveField(27)  int? additionalChargesPaisa, @HiveField(28)  String? additionalChargesNote, @HiveField(29)  int advanceReceivedPaisa, @HiveField(30)  String? assignedTo, @HiveField(31)  String? assignedToName, @HiveField(32)  DateTime? assignedAt, @HiveField(33)  DateTime receivedDate, @HiveField(34)  DateTime? promisedDate, @HiveField(35)  DateTime? completedDate, @HiveField(36)  DateTime? deliveredDate, @HiveField(37)  DateTime? workStartedDate, @HiveField(38)  DateTime? workCompletedDate, @HiveField(39)  int? actualWorkHours, @HiveField(40)  String? deliveredTo, @HiveField(41)  String? deliveryNotes, @HiveField(42)  List<String>? completionPhotoUrls, @HiveField(43)  int warrantyDays, @HiveField(44)  DateTime? warrantyExpiryDate, @HiveField(45)  String? originalJobId, @HiveField(46)  bool isWarrantyClaim, @HiveField(47)  int? customerRating, @HiveField(48)  String? customerFeedback, @HiveField(49)  String? invoiceId, @HiveField(50)  bool isPaid, @HiveField(51)  DateTime createdAt, @HiveField(52)  String createdBy, @HiveField(53)  DateTime updatedAt, @HiveField(54)  String updatedBy, @HiveField(55)  bool synced, @HiveField(56)  DateTime? lastSyncedAt, @HiveField(57)  String? pendingOperation)  $default,) {final _that = this;
switch (_that) {
case _JewelleryRepair():
return $default(_that.id,_that.tenantId,_that.jobNumber,_that.customerId,_that.customerName,_that.customerPhone,_that.customerEmail,_that.itemDescription,_that.itemCategory,_that.metalType,_that.weightGrams,_that.productId,_that.workItems,_that.materials,_that.status,_that.priority,_that.statusHistory,_that.conditionPhotoUrls,_that.customerComplaint,_that.damageAssessment,_that.recommendedWork,_that.estimatedCostPaisa,_that.estimatedDays,_that.estimatedCompletionDate,_that.actualCostPaisa,_that.materialCostPaisa,_that.laborCostPaisa,_that.additionalChargesPaisa,_that.additionalChargesNote,_that.advanceReceivedPaisa,_that.assignedTo,_that.assignedToName,_that.assignedAt,_that.receivedDate,_that.promisedDate,_that.completedDate,_that.deliveredDate,_that.workStartedDate,_that.workCompletedDate,_that.actualWorkHours,_that.deliveredTo,_that.deliveryNotes,_that.completionPhotoUrls,_that.warrantyDays,_that.warrantyExpiryDate,_that.originalJobId,_that.isWarrantyClaim,_that.customerRating,_that.customerFeedback,_that.invoiceId,_that.isPaid,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@HiveField(0)  String id, @HiveField(1)  String tenantId, @HiveField(2)  String jobNumber, @HiveField(3)  String customerId, @HiveField(4)  String customerName, @HiveField(5)  String? customerPhone, @HiveField(6)  String? customerEmail, @HiveField(7)  String itemDescription, @HiveField(8)  String? itemCategory, @HiveField(9)  String? metalType, @HiveField(10)  double? weightGrams, @HiveField(11)  String? productId, @HiveField(12)  List<RepairWorkItem> workItems, @HiveField(13)  List<RepairMaterial>? materials, @HiveField(14)  RepairStatus status, @HiveField(15)  RepairPriority priority, @HiveField(16)  List<RepairStatusUpdate>? statusHistory, @HiveField(17)  List<String>? conditionPhotoUrls, @HiveField(18)  String? customerComplaint, @HiveField(19)  String? damageAssessment, @HiveField(20)  String? recommendedWork, @HiveField(21)  int? estimatedCostPaisa, @HiveField(22)  int? estimatedDays, @HiveField(23)  DateTime? estimatedCompletionDate, @HiveField(24)  int? actualCostPaisa, @HiveField(25)  int? materialCostPaisa, @HiveField(26)  int? laborCostPaisa, @HiveField(27)  int? additionalChargesPaisa, @HiveField(28)  String? additionalChargesNote, @HiveField(29)  int advanceReceivedPaisa, @HiveField(30)  String? assignedTo, @HiveField(31)  String? assignedToName, @HiveField(32)  DateTime? assignedAt, @HiveField(33)  DateTime receivedDate, @HiveField(34)  DateTime? promisedDate, @HiveField(35)  DateTime? completedDate, @HiveField(36)  DateTime? deliveredDate, @HiveField(37)  DateTime? workStartedDate, @HiveField(38)  DateTime? workCompletedDate, @HiveField(39)  int? actualWorkHours, @HiveField(40)  String? deliveredTo, @HiveField(41)  String? deliveryNotes, @HiveField(42)  List<String>? completionPhotoUrls, @HiveField(43)  int warrantyDays, @HiveField(44)  DateTime? warrantyExpiryDate, @HiveField(45)  String? originalJobId, @HiveField(46)  bool isWarrantyClaim, @HiveField(47)  int? customerRating, @HiveField(48)  String? customerFeedback, @HiveField(49)  String? invoiceId, @HiveField(50)  bool isPaid, @HiveField(51)  DateTime createdAt, @HiveField(52)  String createdBy, @HiveField(53)  DateTime updatedAt, @HiveField(54)  String updatedBy, @HiveField(55)  bool synced, @HiveField(56)  DateTime? lastSyncedAt, @HiveField(57)  String? pendingOperation)?  $default,) {final _that = this;
switch (_that) {
case _JewelleryRepair() when $default != null:
return $default(_that.id,_that.tenantId,_that.jobNumber,_that.customerId,_that.customerName,_that.customerPhone,_that.customerEmail,_that.itemDescription,_that.itemCategory,_that.metalType,_that.weightGrams,_that.productId,_that.workItems,_that.materials,_that.status,_that.priority,_that.statusHistory,_that.conditionPhotoUrls,_that.customerComplaint,_that.damageAssessment,_that.recommendedWork,_that.estimatedCostPaisa,_that.estimatedDays,_that.estimatedCompletionDate,_that.actualCostPaisa,_that.materialCostPaisa,_that.laborCostPaisa,_that.additionalChargesPaisa,_that.additionalChargesNote,_that.advanceReceivedPaisa,_that.assignedTo,_that.assignedToName,_that.assignedAt,_that.receivedDate,_that.promisedDate,_that.completedDate,_that.deliveredDate,_that.workStartedDate,_that.workCompletedDate,_that.actualWorkHours,_that.deliveredTo,_that.deliveryNotes,_that.completionPhotoUrls,_that.warrantyDays,_that.warrantyExpiryDate,_that.originalJobId,_that.isWarrantyClaim,_that.customerRating,_that.customerFeedback,_that.invoiceId,_that.isPaid,_that.createdAt,_that.createdBy,_that.updatedAt,_that.updatedBy,_that.synced,_that.lastSyncedAt,_that.pendingOperation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@HiveType(typeId: 65)
class _JewelleryRepair extends JewelleryRepair {
  const _JewelleryRepair({@HiveField(0) required this.id, @HiveField(1) required this.tenantId, @HiveField(2) required this.jobNumber, @HiveField(3) required this.customerId, @HiveField(4) required this.customerName, @HiveField(5) this.customerPhone, @HiveField(6) this.customerEmail, @HiveField(7) required this.itemDescription, @HiveField(8) this.itemCategory, @HiveField(9) this.metalType, @HiveField(10) this.weightGrams, @HiveField(11) this.productId, @HiveField(12) required final  List<RepairWorkItem> workItems, @HiveField(13) final  List<RepairMaterial>? materials, @HiveField(14) this.status = RepairStatus.pending, @HiveField(15) this.priority = RepairPriority.normal, @HiveField(16) final  List<RepairStatusUpdate>? statusHistory, @HiveField(17) final  List<String>? conditionPhotoUrls, @HiveField(18) this.customerComplaint, @HiveField(19) this.damageAssessment, @HiveField(20) this.recommendedWork, @HiveField(21) this.estimatedCostPaisa, @HiveField(22) this.estimatedDays, @HiveField(23) this.estimatedCompletionDate, @HiveField(24) this.actualCostPaisa, @HiveField(25) this.materialCostPaisa, @HiveField(26) this.laborCostPaisa, @HiveField(27) this.additionalChargesPaisa, @HiveField(28) this.additionalChargesNote, @HiveField(29) this.advanceReceivedPaisa = 0, @HiveField(30) this.assignedTo, @HiveField(31) this.assignedToName, @HiveField(32) this.assignedAt, @HiveField(33) required this.receivedDate, @HiveField(34) this.promisedDate, @HiveField(35) this.completedDate, @HiveField(36) this.deliveredDate, @HiveField(37) this.workStartedDate, @HiveField(38) this.workCompletedDate, @HiveField(39) this.actualWorkHours, @HiveField(40) this.deliveredTo, @HiveField(41) this.deliveryNotes, @HiveField(42) final  List<String>? completionPhotoUrls, @HiveField(43) this.warrantyDays = 0, @HiveField(44) this.warrantyExpiryDate, @HiveField(45) this.originalJobId, @HiveField(46) this.isWarrantyClaim = false, @HiveField(47) this.customerRating, @HiveField(48) this.customerFeedback, @HiveField(49) this.invoiceId, @HiveField(50) this.isPaid = false, @HiveField(51) required this.createdAt, @HiveField(52) required this.createdBy, @HiveField(53) required this.updatedAt, @HiveField(54) required this.updatedBy, @HiveField(55) this.synced = true, @HiveField(56) this.lastSyncedAt, @HiveField(57) this.pendingOperation}): _workItems = workItems,_materials = materials,_statusHistory = statusHistory,_conditionPhotoUrls = conditionPhotoUrls,_completionPhotoUrls = completionPhotoUrls,super._();
  factory _JewelleryRepair.fromJson(Map<String, dynamic> json) => _$JewelleryRepairFromJson(json);

// Core identifiers
@override@HiveField(0) final  String id;
@override@HiveField(1) final  String tenantId;
@override@HiveField(2) final  String jobNumber;
// Unique job number (e.g., JOB-2024-0001)
// Customer info
@override@HiveField(3) final  String customerId;
@override@HiveField(4) final  String customerName;
@override@HiveField(5) final  String? customerPhone;
@override@HiveField(6) final  String? customerEmail;
// Item details
@override@HiveField(7) final  String itemDescription;
@override@HiveField(8) final  String? itemCategory;
// Ring, Chain, etc.
@override@HiveField(9) final  String? metalType;
// Gold 22K, Silver, etc.
@override@HiveField(10) final  double? weightGrams;
@override@HiveField(11) final  String? productId;
// If linked to inventory
// Job details
 final  List<RepairWorkItem> _workItems;
// If linked to inventory
// Job details
@override@HiveField(12) List<RepairWorkItem> get workItems {
  if (_workItems is EqualUnmodifiableListView) return _workItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_workItems);
}

 final  List<RepairMaterial>? _materials;
@override@HiveField(13) List<RepairMaterial>? get materials {
  final value = _materials;
  if (value == null) return null;
  if (_materials is EqualUnmodifiableListView) return _materials;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Status
@override@JsonKey()@HiveField(14) final  RepairStatus status;
@override@JsonKey()@HiveField(15) final  RepairPriority priority;
 final  List<RepairStatusUpdate>? _statusHistory;
@override@HiveField(16) List<RepairStatusUpdate>? get statusHistory {
  final value = _statusHistory;
  if (value == null) return null;
  if (_statusHistory is EqualUnmodifiableListView) return _statusHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Initial condition photos
 final  List<String>? _conditionPhotoUrls;
// Initial condition photos
@override@HiveField(17) List<String>? get conditionPhotoUrls {
  final value = _conditionPhotoUrls;
  if (value == null) return null;
  if (_conditionPhotoUrls is EqualUnmodifiableListView) return _conditionPhotoUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@HiveField(18) final  String? customerComplaint;
// What customer reported
// Damage assessment
@override@HiveField(19) final  String? damageAssessment;
@override@HiveField(20) final  String? recommendedWork;
@override@HiveField(21) final  int? estimatedCostPaisa;
@override@HiveField(22) final  int? estimatedDays;
@override@HiveField(23) final  DateTime? estimatedCompletionDate;
// Actual costs
@override@HiveField(24) final  int? actualCostPaisa;
@override@HiveField(25) final  int? materialCostPaisa;
@override@HiveField(26) final  int? laborCostPaisa;
@override@HiveField(27) final  int? additionalChargesPaisa;
@override@HiveField(28) final  String? additionalChargesNote;
// Advance payment
@override@JsonKey()@HiveField(29) final  int advanceReceivedPaisa;
// Assigned craftsmen
@override@HiveField(30) final  String? assignedTo;
@override@HiveField(31) final  String? assignedToName;
@override@HiveField(32) final  DateTime? assignedAt;
// Timeline
@override@HiveField(33) final  DateTime receivedDate;
@override@HiveField(34) final  DateTime? promisedDate;
@override@HiveField(35) final  DateTime? completedDate;
@override@HiveField(36) final  DateTime? deliveredDate;
// Work tracking
@override@HiveField(37) final  DateTime? workStartedDate;
@override@HiveField(38) final  DateTime? workCompletedDate;
@override@HiveField(39) final  int? actualWorkHours;
// Delivery
@override@HiveField(40) final  String? deliveredTo;
@override@HiveField(41) final  String? deliveryNotes;
 final  List<String>? _completionPhotoUrls;
@override@HiveField(42) List<String>? get completionPhotoUrls {
  final value = _completionPhotoUrls;
  if (value == null) return null;
  if (_completionPhotoUrls is EqualUnmodifiableListView) return _completionPhotoUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Warranty
@override@JsonKey()@HiveField(43) final  int warrantyDays;
@override@HiveField(44) final  DateTime? warrantyExpiryDate;
// Warranty claim (if this is a re-repair)
@override@HiveField(45) final  String? originalJobId;
// If this is a warranty claim
@override@JsonKey()@HiveField(46) final  bool isWarrantyClaim;
// Customer feedback
@override@HiveField(47) final  int? customerRating;
// 1-5 stars
@override@HiveField(48) final  String? customerFeedback;
// Invoice
@override@HiveField(49) final  String? invoiceId;
@override@JsonKey()@HiveField(50) final  bool isPaid;
// Metadata
@override@HiveField(51) final  DateTime createdAt;
@override@HiveField(52) final  String createdBy;
@override@HiveField(53) final  DateTime updatedAt;
@override@HiveField(54) final  String updatedBy;
// Sync
@override@JsonKey()@HiveField(55) final  bool synced;
@override@HiveField(56) final  DateTime? lastSyncedAt;
@override@HiveField(57) final  String? pendingOperation;

/// Create a copy of JewelleryRepair
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JewelleryRepairCopyWith<_JewelleryRepair> get copyWith => __$JewelleryRepairCopyWithImpl<_JewelleryRepair>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JewelleryRepairToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JewelleryRepair&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.jobNumber, jobNumber) || other.jobNumber == jobNumber)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerEmail, customerEmail) || other.customerEmail == customerEmail)&&(identical(other.itemDescription, itemDescription) || other.itemDescription == itemDescription)&&(identical(other.itemCategory, itemCategory) || other.itemCategory == itemCategory)&&(identical(other.metalType, metalType) || other.metalType == metalType)&&(identical(other.weightGrams, weightGrams) || other.weightGrams == weightGrams)&&(identical(other.productId, productId) || other.productId == productId)&&const DeepCollectionEquality().equals(other._workItems, _workItems)&&const DeepCollectionEquality().equals(other._materials, _materials)&&(identical(other.status, status) || other.status == status)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other._statusHistory, _statusHistory)&&const DeepCollectionEquality().equals(other._conditionPhotoUrls, _conditionPhotoUrls)&&(identical(other.customerComplaint, customerComplaint) || other.customerComplaint == customerComplaint)&&(identical(other.damageAssessment, damageAssessment) || other.damageAssessment == damageAssessment)&&(identical(other.recommendedWork, recommendedWork) || other.recommendedWork == recommendedWork)&&(identical(other.estimatedCostPaisa, estimatedCostPaisa) || other.estimatedCostPaisa == estimatedCostPaisa)&&(identical(other.estimatedDays, estimatedDays) || other.estimatedDays == estimatedDays)&&(identical(other.estimatedCompletionDate, estimatedCompletionDate) || other.estimatedCompletionDate == estimatedCompletionDate)&&(identical(other.actualCostPaisa, actualCostPaisa) || other.actualCostPaisa == actualCostPaisa)&&(identical(other.materialCostPaisa, materialCostPaisa) || other.materialCostPaisa == materialCostPaisa)&&(identical(other.laborCostPaisa, laborCostPaisa) || other.laborCostPaisa == laborCostPaisa)&&(identical(other.additionalChargesPaisa, additionalChargesPaisa) || other.additionalChargesPaisa == additionalChargesPaisa)&&(identical(other.additionalChargesNote, additionalChargesNote) || other.additionalChargesNote == additionalChargesNote)&&(identical(other.advanceReceivedPaisa, advanceReceivedPaisa) || other.advanceReceivedPaisa == advanceReceivedPaisa)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.assignedToName, assignedToName) || other.assignedToName == assignedToName)&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.receivedDate, receivedDate) || other.receivedDate == receivedDate)&&(identical(other.promisedDate, promisedDate) || other.promisedDate == promisedDate)&&(identical(other.completedDate, completedDate) || other.completedDate == completedDate)&&(identical(other.deliveredDate, deliveredDate) || other.deliveredDate == deliveredDate)&&(identical(other.workStartedDate, workStartedDate) || other.workStartedDate == workStartedDate)&&(identical(other.workCompletedDate, workCompletedDate) || other.workCompletedDate == workCompletedDate)&&(identical(other.actualWorkHours, actualWorkHours) || other.actualWorkHours == actualWorkHours)&&(identical(other.deliveredTo, deliveredTo) || other.deliveredTo == deliveredTo)&&(identical(other.deliveryNotes, deliveryNotes) || other.deliveryNotes == deliveryNotes)&&const DeepCollectionEquality().equals(other._completionPhotoUrls, _completionPhotoUrls)&&(identical(other.warrantyDays, warrantyDays) || other.warrantyDays == warrantyDays)&&(identical(other.warrantyExpiryDate, warrantyExpiryDate) || other.warrantyExpiryDate == warrantyExpiryDate)&&(identical(other.originalJobId, originalJobId) || other.originalJobId == originalJobId)&&(identical(other.isWarrantyClaim, isWarrantyClaim) || other.isWarrantyClaim == isWarrantyClaim)&&(identical(other.customerRating, customerRating) || other.customerRating == customerRating)&&(identical(other.customerFeedback, customerFeedback) || other.customerFeedback == customerFeedback)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.isPaid, isPaid) || other.isPaid == isPaid)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.updatedBy, updatedBy) || other.updatedBy == updatedBy)&&(identical(other.synced, synced) || other.synced == synced)&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt)&&(identical(other.pendingOperation, pendingOperation) || other.pendingOperation == pendingOperation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,jobNumber,customerId,customerName,customerPhone,customerEmail,itemDescription,itemCategory,metalType,weightGrams,productId,const DeepCollectionEquality().hash(_workItems),const DeepCollectionEquality().hash(_materials),status,priority,const DeepCollectionEquality().hash(_statusHistory),const DeepCollectionEquality().hash(_conditionPhotoUrls),customerComplaint,damageAssessment,recommendedWork,estimatedCostPaisa,estimatedDays,estimatedCompletionDate,actualCostPaisa,materialCostPaisa,laborCostPaisa,additionalChargesPaisa,additionalChargesNote,advanceReceivedPaisa,assignedTo,assignedToName,assignedAt,receivedDate,promisedDate,completedDate,deliveredDate,workStartedDate,workCompletedDate,actualWorkHours,deliveredTo,deliveryNotes,const DeepCollectionEquality().hash(_completionPhotoUrls),warrantyDays,warrantyExpiryDate,originalJobId,isWarrantyClaim,customerRating,customerFeedback,invoiceId,isPaid,createdAt,createdBy,updatedAt,updatedBy,synced,lastSyncedAt,pendingOperation]);

@override
String toString() {
  return 'JewelleryRepair(id: $id, tenantId: $tenantId, jobNumber: $jobNumber, customerId: $customerId, customerName: $customerName, customerPhone: $customerPhone, customerEmail: $customerEmail, itemDescription: $itemDescription, itemCategory: $itemCategory, metalType: $metalType, weightGrams: $weightGrams, productId: $productId, workItems: $workItems, materials: $materials, status: $status, priority: $priority, statusHistory: $statusHistory, conditionPhotoUrls: $conditionPhotoUrls, customerComplaint: $customerComplaint, damageAssessment: $damageAssessment, recommendedWork: $recommendedWork, estimatedCostPaisa: $estimatedCostPaisa, estimatedDays: $estimatedDays, estimatedCompletionDate: $estimatedCompletionDate, actualCostPaisa: $actualCostPaisa, materialCostPaisa: $materialCostPaisa, laborCostPaisa: $laborCostPaisa, additionalChargesPaisa: $additionalChargesPaisa, additionalChargesNote: $additionalChargesNote, advanceReceivedPaisa: $advanceReceivedPaisa, assignedTo: $assignedTo, assignedToName: $assignedToName, assignedAt: $assignedAt, receivedDate: $receivedDate, promisedDate: $promisedDate, completedDate: $completedDate, deliveredDate: $deliveredDate, workStartedDate: $workStartedDate, workCompletedDate: $workCompletedDate, actualWorkHours: $actualWorkHours, deliveredTo: $deliveredTo, deliveryNotes: $deliveryNotes, completionPhotoUrls: $completionPhotoUrls, warrantyDays: $warrantyDays, warrantyExpiryDate: $warrantyExpiryDate, originalJobId: $originalJobId, isWarrantyClaim: $isWarrantyClaim, customerRating: $customerRating, customerFeedback: $customerFeedback, invoiceId: $invoiceId, isPaid: $isPaid, createdAt: $createdAt, createdBy: $createdBy, updatedAt: $updatedAt, updatedBy: $updatedBy, synced: $synced, lastSyncedAt: $lastSyncedAt, pendingOperation: $pendingOperation)';
}


}

/// @nodoc
abstract mixin class _$JewelleryRepairCopyWith<$Res> implements $JewelleryRepairCopyWith<$Res> {
  factory _$JewelleryRepairCopyWith(_JewelleryRepair value, $Res Function(_JewelleryRepair) _then) = __$JewelleryRepairCopyWithImpl;
@override @useResult
$Res call({
@HiveField(0) String id,@HiveField(1) String tenantId,@HiveField(2) String jobNumber,@HiveField(3) String customerId,@HiveField(4) String customerName,@HiveField(5) String? customerPhone,@HiveField(6) String? customerEmail,@HiveField(7) String itemDescription,@HiveField(8) String? itemCategory,@HiveField(9) String? metalType,@HiveField(10) double? weightGrams,@HiveField(11) String? productId,@HiveField(12) List<RepairWorkItem> workItems,@HiveField(13) List<RepairMaterial>? materials,@HiveField(14) RepairStatus status,@HiveField(15) RepairPriority priority,@HiveField(16) List<RepairStatusUpdate>? statusHistory,@HiveField(17) List<String>? conditionPhotoUrls,@HiveField(18) String? customerComplaint,@HiveField(19) String? damageAssessment,@HiveField(20) String? recommendedWork,@HiveField(21) int? estimatedCostPaisa,@HiveField(22) int? estimatedDays,@HiveField(23) DateTime? estimatedCompletionDate,@HiveField(24) int? actualCostPaisa,@HiveField(25) int? materialCostPaisa,@HiveField(26) int? laborCostPaisa,@HiveField(27) int? additionalChargesPaisa,@HiveField(28) String? additionalChargesNote,@HiveField(29) int advanceReceivedPaisa,@HiveField(30) String? assignedTo,@HiveField(31) String? assignedToName,@HiveField(32) DateTime? assignedAt,@HiveField(33) DateTime receivedDate,@HiveField(34) DateTime? promisedDate,@HiveField(35) DateTime? completedDate,@HiveField(36) DateTime? deliveredDate,@HiveField(37) DateTime? workStartedDate,@HiveField(38) DateTime? workCompletedDate,@HiveField(39) int? actualWorkHours,@HiveField(40) String? deliveredTo,@HiveField(41) String? deliveryNotes,@HiveField(42) List<String>? completionPhotoUrls,@HiveField(43) int warrantyDays,@HiveField(44) DateTime? warrantyExpiryDate,@HiveField(45) String? originalJobId,@HiveField(46) bool isWarrantyClaim,@HiveField(47) int? customerRating,@HiveField(48) String? customerFeedback,@HiveField(49) String? invoiceId,@HiveField(50) bool isPaid,@HiveField(51) DateTime createdAt,@HiveField(52) String createdBy,@HiveField(53) DateTime updatedAt,@HiveField(54) String updatedBy,@HiveField(55) bool synced,@HiveField(56) DateTime? lastSyncedAt,@HiveField(57) String? pendingOperation
});




}
/// @nodoc
class __$JewelleryRepairCopyWithImpl<$Res>
    implements _$JewelleryRepairCopyWith<$Res> {
  __$JewelleryRepairCopyWithImpl(this._self, this._then);

  final _JewelleryRepair _self;
  final $Res Function(_JewelleryRepair) _then;

/// Create a copy of JewelleryRepair
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? jobNumber = null,Object? customerId = null,Object? customerName = null,Object? customerPhone = freezed,Object? customerEmail = freezed,Object? itemDescription = null,Object? itemCategory = freezed,Object? metalType = freezed,Object? weightGrams = freezed,Object? productId = freezed,Object? workItems = null,Object? materials = freezed,Object? status = null,Object? priority = null,Object? statusHistory = freezed,Object? conditionPhotoUrls = freezed,Object? customerComplaint = freezed,Object? damageAssessment = freezed,Object? recommendedWork = freezed,Object? estimatedCostPaisa = freezed,Object? estimatedDays = freezed,Object? estimatedCompletionDate = freezed,Object? actualCostPaisa = freezed,Object? materialCostPaisa = freezed,Object? laborCostPaisa = freezed,Object? additionalChargesPaisa = freezed,Object? additionalChargesNote = freezed,Object? advanceReceivedPaisa = null,Object? assignedTo = freezed,Object? assignedToName = freezed,Object? assignedAt = freezed,Object? receivedDate = null,Object? promisedDate = freezed,Object? completedDate = freezed,Object? deliveredDate = freezed,Object? workStartedDate = freezed,Object? workCompletedDate = freezed,Object? actualWorkHours = freezed,Object? deliveredTo = freezed,Object? deliveryNotes = freezed,Object? completionPhotoUrls = freezed,Object? warrantyDays = null,Object? warrantyExpiryDate = freezed,Object? originalJobId = freezed,Object? isWarrantyClaim = null,Object? customerRating = freezed,Object? customerFeedback = freezed,Object? invoiceId = freezed,Object? isPaid = null,Object? createdAt = null,Object? createdBy = null,Object? updatedAt = null,Object? updatedBy = null,Object? synced = null,Object? lastSyncedAt = freezed,Object? pendingOperation = freezed,}) {
  return _then(_JewelleryRepair(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,jobNumber: null == jobNumber ? _self.jobNumber : jobNumber // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerEmail: freezed == customerEmail ? _self.customerEmail : customerEmail // ignore: cast_nullable_to_non_nullable
as String?,itemDescription: null == itemDescription ? _self.itemDescription : itemDescription // ignore: cast_nullable_to_non_nullable
as String,itemCategory: freezed == itemCategory ? _self.itemCategory : itemCategory // ignore: cast_nullable_to_non_nullable
as String?,metalType: freezed == metalType ? _self.metalType : metalType // ignore: cast_nullable_to_non_nullable
as String?,weightGrams: freezed == weightGrams ? _self.weightGrams : weightGrams // ignore: cast_nullable_to_non_nullable
as double?,productId: freezed == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as String?,workItems: null == workItems ? _self._workItems : workItems // ignore: cast_nullable_to_non_nullable
as List<RepairWorkItem>,materials: freezed == materials ? _self._materials : materials // ignore: cast_nullable_to_non_nullable
as List<RepairMaterial>?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RepairStatus,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as RepairPriority,statusHistory: freezed == statusHistory ? _self._statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<RepairStatusUpdate>?,conditionPhotoUrls: freezed == conditionPhotoUrls ? _self._conditionPhotoUrls : conditionPhotoUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,customerComplaint: freezed == customerComplaint ? _self.customerComplaint : customerComplaint // ignore: cast_nullable_to_non_nullable
as String?,damageAssessment: freezed == damageAssessment ? _self.damageAssessment : damageAssessment // ignore: cast_nullable_to_non_nullable
as String?,recommendedWork: freezed == recommendedWork ? _self.recommendedWork : recommendedWork // ignore: cast_nullable_to_non_nullable
as String?,estimatedCostPaisa: freezed == estimatedCostPaisa ? _self.estimatedCostPaisa : estimatedCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,estimatedDays: freezed == estimatedDays ? _self.estimatedDays : estimatedDays // ignore: cast_nullable_to_non_nullable
as int?,estimatedCompletionDate: freezed == estimatedCompletionDate ? _self.estimatedCompletionDate : estimatedCompletionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,actualCostPaisa: freezed == actualCostPaisa ? _self.actualCostPaisa : actualCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,materialCostPaisa: freezed == materialCostPaisa ? _self.materialCostPaisa : materialCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,laborCostPaisa: freezed == laborCostPaisa ? _self.laborCostPaisa : laborCostPaisa // ignore: cast_nullable_to_non_nullable
as int?,additionalChargesPaisa: freezed == additionalChargesPaisa ? _self.additionalChargesPaisa : additionalChargesPaisa // ignore: cast_nullable_to_non_nullable
as int?,additionalChargesNote: freezed == additionalChargesNote ? _self.additionalChargesNote : additionalChargesNote // ignore: cast_nullable_to_non_nullable
as String?,advanceReceivedPaisa: null == advanceReceivedPaisa ? _self.advanceReceivedPaisa : advanceReceivedPaisa // ignore: cast_nullable_to_non_nullable
as int,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,assignedToName: freezed == assignedToName ? _self.assignedToName : assignedToName // ignore: cast_nullable_to_non_nullable
as String?,assignedAt: freezed == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,receivedDate: null == receivedDate ? _self.receivedDate : receivedDate // ignore: cast_nullable_to_non_nullable
as DateTime,promisedDate: freezed == promisedDate ? _self.promisedDate : promisedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,completedDate: freezed == completedDate ? _self.completedDate : completedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveredDate: freezed == deliveredDate ? _self.deliveredDate : deliveredDate // ignore: cast_nullable_to_non_nullable
as DateTime?,workStartedDate: freezed == workStartedDate ? _self.workStartedDate : workStartedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,workCompletedDate: freezed == workCompletedDate ? _self.workCompletedDate : workCompletedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,actualWorkHours: freezed == actualWorkHours ? _self.actualWorkHours : actualWorkHours // ignore: cast_nullable_to_non_nullable
as int?,deliveredTo: freezed == deliveredTo ? _self.deliveredTo : deliveredTo // ignore: cast_nullable_to_non_nullable
as String?,deliveryNotes: freezed == deliveryNotes ? _self.deliveryNotes : deliveryNotes // ignore: cast_nullable_to_non_nullable
as String?,completionPhotoUrls: freezed == completionPhotoUrls ? _self._completionPhotoUrls : completionPhotoUrls // ignore: cast_nullable_to_non_nullable
as List<String>?,warrantyDays: null == warrantyDays ? _self.warrantyDays : warrantyDays // ignore: cast_nullable_to_non_nullable
as int,warrantyExpiryDate: freezed == warrantyExpiryDate ? _self.warrantyExpiryDate : warrantyExpiryDate // ignore: cast_nullable_to_non_nullable
as DateTime?,originalJobId: freezed == originalJobId ? _self.originalJobId : originalJobId // ignore: cast_nullable_to_non_nullable
as String?,isWarrantyClaim: null == isWarrantyClaim ? _self.isWarrantyClaim : isWarrantyClaim // ignore: cast_nullable_to_non_nullable
as bool,customerRating: freezed == customerRating ? _self.customerRating : customerRating // ignore: cast_nullable_to_non_nullable
as int?,customerFeedback: freezed == customerFeedback ? _self.customerFeedback : customerFeedback // ignore: cast_nullable_to_non_nullable
as String?,invoiceId: freezed == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String?,isPaid: null == isPaid ? _self.isPaid : isPaid // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
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
mixin _$RepairStatistics {

 int get totalJobs; int get pendingJobs; int get inProgressJobs; int get completedJobs; int get deliveredJobs; int get overdueJobs; int get warrantyClaims; double get averageRepairDays; int get totalRevenuePaisa; int get totalMaterialCostPaisa; int get totalLaborCostPaisa;
/// Create a copy of RepairStatistics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RepairStatisticsCopyWith<RepairStatistics> get copyWith => _$RepairStatisticsCopyWithImpl<RepairStatistics>(this as RepairStatistics, _$identity);

  /// Serializes this RepairStatistics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RepairStatistics&&(identical(other.totalJobs, totalJobs) || other.totalJobs == totalJobs)&&(identical(other.pendingJobs, pendingJobs) || other.pendingJobs == pendingJobs)&&(identical(other.inProgressJobs, inProgressJobs) || other.inProgressJobs == inProgressJobs)&&(identical(other.completedJobs, completedJobs) || other.completedJobs == completedJobs)&&(identical(other.deliveredJobs, deliveredJobs) || other.deliveredJobs == deliveredJobs)&&(identical(other.overdueJobs, overdueJobs) || other.overdueJobs == overdueJobs)&&(identical(other.warrantyClaims, warrantyClaims) || other.warrantyClaims == warrantyClaims)&&(identical(other.averageRepairDays, averageRepairDays) || other.averageRepairDays == averageRepairDays)&&(identical(other.totalRevenuePaisa, totalRevenuePaisa) || other.totalRevenuePaisa == totalRevenuePaisa)&&(identical(other.totalMaterialCostPaisa, totalMaterialCostPaisa) || other.totalMaterialCostPaisa == totalMaterialCostPaisa)&&(identical(other.totalLaborCostPaisa, totalLaborCostPaisa) || other.totalLaborCostPaisa == totalLaborCostPaisa));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalJobs,pendingJobs,inProgressJobs,completedJobs,deliveredJobs,overdueJobs,warrantyClaims,averageRepairDays,totalRevenuePaisa,totalMaterialCostPaisa,totalLaborCostPaisa);

@override
String toString() {
  return 'RepairStatistics(totalJobs: $totalJobs, pendingJobs: $pendingJobs, inProgressJobs: $inProgressJobs, completedJobs: $completedJobs, deliveredJobs: $deliveredJobs, overdueJobs: $overdueJobs, warrantyClaims: $warrantyClaims, averageRepairDays: $averageRepairDays, totalRevenuePaisa: $totalRevenuePaisa, totalMaterialCostPaisa: $totalMaterialCostPaisa, totalLaborCostPaisa: $totalLaborCostPaisa)';
}


}

/// @nodoc
abstract mixin class $RepairStatisticsCopyWith<$Res>  {
  factory $RepairStatisticsCopyWith(RepairStatistics value, $Res Function(RepairStatistics) _then) = _$RepairStatisticsCopyWithImpl;
@useResult
$Res call({
 int totalJobs, int pendingJobs, int inProgressJobs, int completedJobs, int deliveredJobs, int overdueJobs, int warrantyClaims, double averageRepairDays, int totalRevenuePaisa, int totalMaterialCostPaisa, int totalLaborCostPaisa
});




}
/// @nodoc
class _$RepairStatisticsCopyWithImpl<$Res>
    implements $RepairStatisticsCopyWith<$Res> {
  _$RepairStatisticsCopyWithImpl(this._self, this._then);

  final RepairStatistics _self;
  final $Res Function(RepairStatistics) _then;

/// Create a copy of RepairStatistics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalJobs = null,Object? pendingJobs = null,Object? inProgressJobs = null,Object? completedJobs = null,Object? deliveredJobs = null,Object? overdueJobs = null,Object? warrantyClaims = null,Object? averageRepairDays = null,Object? totalRevenuePaisa = null,Object? totalMaterialCostPaisa = null,Object? totalLaborCostPaisa = null,}) {
  return _then(_self.copyWith(
totalJobs: null == totalJobs ? _self.totalJobs : totalJobs // ignore: cast_nullable_to_non_nullable
as int,pendingJobs: null == pendingJobs ? _self.pendingJobs : pendingJobs // ignore: cast_nullable_to_non_nullable
as int,inProgressJobs: null == inProgressJobs ? _self.inProgressJobs : inProgressJobs // ignore: cast_nullable_to_non_nullable
as int,completedJobs: null == completedJobs ? _self.completedJobs : completedJobs // ignore: cast_nullable_to_non_nullable
as int,deliveredJobs: null == deliveredJobs ? _self.deliveredJobs : deliveredJobs // ignore: cast_nullable_to_non_nullable
as int,overdueJobs: null == overdueJobs ? _self.overdueJobs : overdueJobs // ignore: cast_nullable_to_non_nullable
as int,warrantyClaims: null == warrantyClaims ? _self.warrantyClaims : warrantyClaims // ignore: cast_nullable_to_non_nullable
as int,averageRepairDays: null == averageRepairDays ? _self.averageRepairDays : averageRepairDays // ignore: cast_nullable_to_non_nullable
as double,totalRevenuePaisa: null == totalRevenuePaisa ? _self.totalRevenuePaisa : totalRevenuePaisa // ignore: cast_nullable_to_non_nullable
as int,totalMaterialCostPaisa: null == totalMaterialCostPaisa ? _self.totalMaterialCostPaisa : totalMaterialCostPaisa // ignore: cast_nullable_to_non_nullable
as int,totalLaborCostPaisa: null == totalLaborCostPaisa ? _self.totalLaborCostPaisa : totalLaborCostPaisa // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RepairStatistics].
extension RepairStatisticsPatterns on RepairStatistics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RepairStatistics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RepairStatistics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RepairStatistics value)  $default,){
final _that = this;
switch (_that) {
case _RepairStatistics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RepairStatistics value)?  $default,){
final _that = this;
switch (_that) {
case _RepairStatistics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalJobs,  int pendingJobs,  int inProgressJobs,  int completedJobs,  int deliveredJobs,  int overdueJobs,  int warrantyClaims,  double averageRepairDays,  int totalRevenuePaisa,  int totalMaterialCostPaisa,  int totalLaborCostPaisa)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RepairStatistics() when $default != null:
return $default(_that.totalJobs,_that.pendingJobs,_that.inProgressJobs,_that.completedJobs,_that.deliveredJobs,_that.overdueJobs,_that.warrantyClaims,_that.averageRepairDays,_that.totalRevenuePaisa,_that.totalMaterialCostPaisa,_that.totalLaborCostPaisa);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalJobs,  int pendingJobs,  int inProgressJobs,  int completedJobs,  int deliveredJobs,  int overdueJobs,  int warrantyClaims,  double averageRepairDays,  int totalRevenuePaisa,  int totalMaterialCostPaisa,  int totalLaborCostPaisa)  $default,) {final _that = this;
switch (_that) {
case _RepairStatistics():
return $default(_that.totalJobs,_that.pendingJobs,_that.inProgressJobs,_that.completedJobs,_that.deliveredJobs,_that.overdueJobs,_that.warrantyClaims,_that.averageRepairDays,_that.totalRevenuePaisa,_that.totalMaterialCostPaisa,_that.totalLaborCostPaisa);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalJobs,  int pendingJobs,  int inProgressJobs,  int completedJobs,  int deliveredJobs,  int overdueJobs,  int warrantyClaims,  double averageRepairDays,  int totalRevenuePaisa,  int totalMaterialCostPaisa,  int totalLaborCostPaisa)?  $default,) {final _that = this;
switch (_that) {
case _RepairStatistics() when $default != null:
return $default(_that.totalJobs,_that.pendingJobs,_that.inProgressJobs,_that.completedJobs,_that.deliveredJobs,_that.overdueJobs,_that.warrantyClaims,_that.averageRepairDays,_that.totalRevenuePaisa,_that.totalMaterialCostPaisa,_that.totalLaborCostPaisa);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RepairStatistics extends RepairStatistics {
  const _RepairStatistics({this.totalJobs = 0, this.pendingJobs = 0, this.inProgressJobs = 0, this.completedJobs = 0, this.deliveredJobs = 0, this.overdueJobs = 0, this.warrantyClaims = 0, this.averageRepairDays = 0, this.totalRevenuePaisa = 0, this.totalMaterialCostPaisa = 0, this.totalLaborCostPaisa = 0}): super._();
  factory _RepairStatistics.fromJson(Map<String, dynamic> json) => _$RepairStatisticsFromJson(json);

@override@JsonKey() final  int totalJobs;
@override@JsonKey() final  int pendingJobs;
@override@JsonKey() final  int inProgressJobs;
@override@JsonKey() final  int completedJobs;
@override@JsonKey() final  int deliveredJobs;
@override@JsonKey() final  int overdueJobs;
@override@JsonKey() final  int warrantyClaims;
@override@JsonKey() final  double averageRepairDays;
@override@JsonKey() final  int totalRevenuePaisa;
@override@JsonKey() final  int totalMaterialCostPaisa;
@override@JsonKey() final  int totalLaborCostPaisa;

/// Create a copy of RepairStatistics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RepairStatisticsCopyWith<_RepairStatistics> get copyWith => __$RepairStatisticsCopyWithImpl<_RepairStatistics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RepairStatisticsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RepairStatistics&&(identical(other.totalJobs, totalJobs) || other.totalJobs == totalJobs)&&(identical(other.pendingJobs, pendingJobs) || other.pendingJobs == pendingJobs)&&(identical(other.inProgressJobs, inProgressJobs) || other.inProgressJobs == inProgressJobs)&&(identical(other.completedJobs, completedJobs) || other.completedJobs == completedJobs)&&(identical(other.deliveredJobs, deliveredJobs) || other.deliveredJobs == deliveredJobs)&&(identical(other.overdueJobs, overdueJobs) || other.overdueJobs == overdueJobs)&&(identical(other.warrantyClaims, warrantyClaims) || other.warrantyClaims == warrantyClaims)&&(identical(other.averageRepairDays, averageRepairDays) || other.averageRepairDays == averageRepairDays)&&(identical(other.totalRevenuePaisa, totalRevenuePaisa) || other.totalRevenuePaisa == totalRevenuePaisa)&&(identical(other.totalMaterialCostPaisa, totalMaterialCostPaisa) || other.totalMaterialCostPaisa == totalMaterialCostPaisa)&&(identical(other.totalLaborCostPaisa, totalLaborCostPaisa) || other.totalLaborCostPaisa == totalLaborCostPaisa));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalJobs,pendingJobs,inProgressJobs,completedJobs,deliveredJobs,overdueJobs,warrantyClaims,averageRepairDays,totalRevenuePaisa,totalMaterialCostPaisa,totalLaborCostPaisa);

@override
String toString() {
  return 'RepairStatistics(totalJobs: $totalJobs, pendingJobs: $pendingJobs, inProgressJobs: $inProgressJobs, completedJobs: $completedJobs, deliveredJobs: $deliveredJobs, overdueJobs: $overdueJobs, warrantyClaims: $warrantyClaims, averageRepairDays: $averageRepairDays, totalRevenuePaisa: $totalRevenuePaisa, totalMaterialCostPaisa: $totalMaterialCostPaisa, totalLaborCostPaisa: $totalLaborCostPaisa)';
}


}

/// @nodoc
abstract mixin class _$RepairStatisticsCopyWith<$Res> implements $RepairStatisticsCopyWith<$Res> {
  factory _$RepairStatisticsCopyWith(_RepairStatistics value, $Res Function(_RepairStatistics) _then) = __$RepairStatisticsCopyWithImpl;
@override @useResult
$Res call({
 int totalJobs, int pendingJobs, int inProgressJobs, int completedJobs, int deliveredJobs, int overdueJobs, int warrantyClaims, double averageRepairDays, int totalRevenuePaisa, int totalMaterialCostPaisa, int totalLaborCostPaisa
});




}
/// @nodoc
class __$RepairStatisticsCopyWithImpl<$Res>
    implements _$RepairStatisticsCopyWith<$Res> {
  __$RepairStatisticsCopyWithImpl(this._self, this._then);

  final _RepairStatistics _self;
  final $Res Function(_RepairStatistics) _then;

/// Create a copy of RepairStatistics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalJobs = null,Object? pendingJobs = null,Object? inProgressJobs = null,Object? completedJobs = null,Object? deliveredJobs = null,Object? overdueJobs = null,Object? warrantyClaims = null,Object? averageRepairDays = null,Object? totalRevenuePaisa = null,Object? totalMaterialCostPaisa = null,Object? totalLaborCostPaisa = null,}) {
  return _then(_RepairStatistics(
totalJobs: null == totalJobs ? _self.totalJobs : totalJobs // ignore: cast_nullable_to_non_nullable
as int,pendingJobs: null == pendingJobs ? _self.pendingJobs : pendingJobs // ignore: cast_nullable_to_non_nullable
as int,inProgressJobs: null == inProgressJobs ? _self.inProgressJobs : inProgressJobs // ignore: cast_nullable_to_non_nullable
as int,completedJobs: null == completedJobs ? _self.completedJobs : completedJobs // ignore: cast_nullable_to_non_nullable
as int,deliveredJobs: null == deliveredJobs ? _self.deliveredJobs : deliveredJobs // ignore: cast_nullable_to_non_nullable
as int,overdueJobs: null == overdueJobs ? _self.overdueJobs : overdueJobs // ignore: cast_nullable_to_non_nullable
as int,warrantyClaims: null == warrantyClaims ? _self.warrantyClaims : warrantyClaims // ignore: cast_nullable_to_non_nullable
as int,averageRepairDays: null == averageRepairDays ? _self.averageRepairDays : averageRepairDays // ignore: cast_nullable_to_non_nullable
as double,totalRevenuePaisa: null == totalRevenuePaisa ? _self.totalRevenuePaisa : totalRevenuePaisa // ignore: cast_nullable_to_non_nullable
as int,totalMaterialCostPaisa: null == totalMaterialCostPaisa ? _self.totalMaterialCostPaisa : totalMaterialCostPaisa // ignore: cast_nullable_to_non_nullable
as int,totalLaborCostPaisa: null == totalLaborCostPaisa ? _self.totalLaborCostPaisa : totalLaborCostPaisa // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
