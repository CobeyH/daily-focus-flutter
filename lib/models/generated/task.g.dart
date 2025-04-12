// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Task _$TaskFromJson(Map<String, dynamic> json) => _Task(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      goal: (json['goal'] as num).toInt(),
      progress: (json['progress'] as num).toInt(),
      incremental: json['incremental'] as bool,
      iconPoint: (json['icon_point'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TaskToJson(_Task instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'goal': instance.goal,
      'progress': instance.progress,
      'incremental': instance.incremental,
      'icon_point': instance.iconPoint,
    };
