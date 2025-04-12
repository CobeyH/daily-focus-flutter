// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Task {
  String get uuid;
  String get name;
  int get goal;
  int get progress;
  bool get incremental;
  int? get iconPoint;

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskCopyWith<Task> get copyWith =>
      _$TaskCopyWithImpl<Task>(this as Task, _$identity);

  /// Serializes this Task to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Task &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.incremental, incremental) ||
                other.incremental == incremental) &&
            (identical(other.iconPoint, iconPoint) ||
                other.iconPoint == iconPoint));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, uuid, name, goal, progress, incremental, iconPoint);

  @override
  String toString() {
    return 'Task(uuid: $uuid, name: $name, goal: $goal, progress: $progress, incremental: $incremental, iconPoint: $iconPoint)';
  }
}

/// @nodoc
abstract mixin class $TaskCopyWith<$Res> {
  factory $TaskCopyWith(Task value, $Res Function(Task) _then) =
      _$TaskCopyWithImpl;
  @useResult
  $Res call(
      {String uuid,
      String name,
      int goal,
      int progress,
      bool incremental,
      int? iconPoint});
}

/// @nodoc
class _$TaskCopyWithImpl<$Res> implements $TaskCopyWith<$Res> {
  _$TaskCopyWithImpl(this._self, this._then);

  final Task _self;
  final $Res Function(Task) _then;

  /// Create a copy of Task
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Task extends Task {
  _Task(
      {required this.uuid,
      required this.name,
      required this.goal,
      required this.progress,
      required this.incremental,
      this.iconPoint})
      : super._();
  factory _Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

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

  /// Create a copy of Task
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TaskCopyWith<_Task> get copyWith =>
      __$TaskCopyWithImpl<_Task>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Task &&
            (identical(other.uuid, uuid) || other.uuid == uuid) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.incremental, incremental) ||
                other.incremental == incremental) &&
            (identical(other.iconPoint, iconPoint) ||
                other.iconPoint == iconPoint));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, uuid, name, goal, progress, incremental, iconPoint);

  @override
  String toString() {
    return 'Task(uuid: $uuid, name: $name, goal: $goal, progress: $progress, incremental: $incremental, iconPoint: $iconPoint)';
  }
}

/// @nodoc
abstract mixin class _$TaskCopyWith<$Res> implements $TaskCopyWith<$Res> {
  factory _$TaskCopyWith(_Task value, $Res Function(_Task) _then) =
      __$TaskCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String uuid,
      String name,
      int goal,
      int progress,
      bool incremental,
      int? iconPoint});
}

/// @nodoc
class __$TaskCopyWithImpl<$Res> implements _$TaskCopyWith<$Res> {
  __$TaskCopyWithImpl(this._self, this._then);

  final _Task _self;
  final $Res Function(_Task) _then;

  /// Create a copy of Task
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
  }) {
    return _then(_Task(
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
    ));
  }
}

// dart format on
