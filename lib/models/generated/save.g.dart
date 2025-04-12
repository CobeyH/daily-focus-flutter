// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../save.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Save _$SaveFromJson(Map<String, dynamic> json) => _Save(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      goal: (json['goal'] as num).toInt(),
      progress: (json['progress'] as num).toInt(),
      incremental: json['incremental'] as bool,
      iconPoint: (json['icon_point'] as num?)?.toInt(),
      date: DateTime.parse(json['date'] as String),
    );

Map<String, dynamic> _$SaveToJson(_Save instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'goal': instance.goal,
      'progress': instance.progress,
      'incremental': instance.incremental,
      'icon_point': instance.iconPoint,
      'date': instance.date.toIso8601String(),
    };
