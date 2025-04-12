// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../save.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Save {
  String get uuid;
  String get name;
  int get goal;
  int get progress;
  bool get incremental;
  int? get iconPoint;
  DateTime get date;

  /// Create a copy of Save
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SaveCopyWith<Save> get copyWith =>
      _$SaveCopyWithImpl<Save>(this as Save, _$identity);

  /// Serializes this Save to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Save &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.incremental, incremental) ||
                other.incremental == incremental) &&
            (identical(other.iconPoint, iconPoint) ||
                other.iconPoint == iconPoint) &&
            (identical(other.date, date) || other.date == date));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, uuid, name, goal, progress, incremental, iconPoint, date);

  @override
  String toString() {
    return 'Save(uuid: $uuid, name: $name, goal: $goal, progress: $progress, incremental: $incremental, iconPoint: $iconPoint, date: $date)';
  }
}

/// @nodoc
abstract mixin class $SaveCopyWith<$Res> {
  factory $SaveCopyWith(Save value, $Res Function(Save) _then) =
      _$SaveCopyWithImpl;
  @useResult
  $Res call(
      {String uuid,
      String name,
      int goal,
      int progress,
      bool incremental,
      int? iconPoint,
      DateTime date});
}

/// @nodoc
class _$SaveCopyWithImpl<$Res> implements $SaveCopyWith<$Res> {
  _$SaveCopyWithImpl(this._self, this._then);

  final Save _self;
  final $Res Function(Save) _then;

  /// Create a copy of Save
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uuid = null,
    Object? name = null,
    Object? goal = null,
    Object? progress = null,
    Object? incremental = null,
    Object? iconPoint = freezed,
    Object? date = null,
  }) {
    return _then(_self.copyWith(
      uuid: null == uuid
          ? _self.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      goal: null == goal
          ? _self.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as int,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
      incremental: null == incremental
          ? _self.incremental
          : incremental // ignore: cast_nullable_to_non_nullable
              as bool,
      iconPoint: freezed == iconPoint
          ? _self.iconPoint
          : iconPoint // ignore: cast_nullable_to_non_nullable
              as int?,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Save extends Save {
  _Save(
      {required this.uuid,
      required this.name,
      required this.goal,
      required this.progress,
      required this.incremental,
      this.iconPoint,
      required this.date})
      : super._();
  factory _Save.fromJson(Map<String, dynamic> json) => _$SaveFromJson(json);

  @override
  final String uuid;
  @override
  final String name;
  @override
  final int goal;
  @override
  final int progress;
  @override
  final bool incremental;
  @override
  final int? iconPoint;
  @override
  final DateTime date;

  /// Create a copy of Save
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SaveCopyWith<_Save> get copyWith =>
      __$SaveCopyWithImpl<_Save>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SaveToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Save &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.incremental, incremental) ||
                other.incremental == incremental) &&
            (identical(other.iconPoint, iconPoint) ||
                other.iconPoint == iconPoint) &&
            (identical(other.date, date) || other.date == date));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, uuid, name, goal, progress, incremental, iconPoint, date);

  @override
  String toString() {
    return 'Save(uuid: $uuid, name: $name, goal: $goal, progress: $progress, incremental: $incremental, iconPoint: $iconPoint, date: $date)';
  }
}

/// @nodoc
abstract mixin class _$SaveCopyWith<$Res> implements $SaveCopyWith<$Res> {
  factory _$SaveCopyWith(_Save value, $Res Function(_Save) _then) =
      __$SaveCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String uuid,
      String name,
      int goal,
      int progress,
      bool incremental,
      int? iconPoint,
      DateTime date});
}

/// @nodoc
class __$SaveCopyWithImpl<$Res> implements _$SaveCopyWith<$Res> {
  __$SaveCopyWithImpl(this._self, this._then);

  final _Save _self;
  final $Res Function(_Save) _then;

  /// Create a copy of Save
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? uuid = null,
    Object? name = null,
    Object? goal = null,
    Object? progress = null,
    Object? incremental = null,
    Object? iconPoint = freezed,
    Object? date = null,
  }) {
    return _then(_Save(
      uuid: null == uuid
          ? _self.uuid
          : uuid // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      goal: null == goal
          ? _self.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as int,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as int,
      incremental: null == incremental
          ? _self.incremental
          : incremental // ignore: cast_nullable_to_non_nullable
              as bool,
      iconPoint: freezed == iconPoint
          ? _self.iconPoint
          : iconPoint // ignore: cast_nullable_to_non_nullable
              as int?,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
