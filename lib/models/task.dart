import 'package:uuid/uuid.dart';

import 'schedule.dart';
import 'task_timing.dart';

/// The kinds of tasks described by the product goals.
///
/// * [count]   — occurrence based ("do X 5 times a day"). Each tap = +1.
/// * [minutes] — time based ("do X for N minutes a day"). Each tap = +step.
enum TaskType { count, minutes, multiStep }

extension TaskTypeX on TaskType {
  String get label => switch (this) {
        TaskType.count => 'times',
        TaskType.minutes => 'minutes',
        TaskType.multiStep => 'multiStep'
      };

  static TaskType fromValue(String v) => switch (v) {
        'minutes' => TaskType.minutes,
        'multiStep' => TaskType.multiStep,
        _ => TaskType.count
      };
}

class Task {
  final String id;
  final String name;

  /// Whether the goal is measured in occurrences or minutes.
  final TaskType type;

  /// Daily target. For [TaskType.count] it's a number of occurrences; for
  /// [TaskType.minutes] it's a number of seconds.
  final int _goal;
  final List<String> steps;
  int get goal =>
      type == TaskType.multiStep ? steps.length.clamp(1, 10000) : _goal;

  /// How much one tap contributes. For [TaskType.count] this is always 1; for
  /// [TaskType.minutes] it's a configurable chunk of minutes (e.g. 5).
  final int step;

  /// ARGB color value used to theme the task.
  final int color;

  /// Material icon code point.
  final int icon;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final TaskTiming timing;

  /// How often the task is due. Defaults to [ScheduleDaily] (every day) for
  /// tasks created without an explicit schedule.
  final Schedule schedule;

  const Task({
    required this.id,
    required this.name,
    required this.type,
    required int goal,
    this.steps = const [],
    required this.step,
    required this.color,
    required this.icon,
    required this.createdAt,
    this.updatedAt,
    this.timing = const TaskTiming(),
    this.schedule = const ScheduleDaily(),
  }) : _goal = goal;

  factory Task.create({
    required String name,
    required TaskType type,
    required int goal,
    List<String> steps = const [],
    required int step,
    required int color,
    required int icon,
    Schedule schedule = const ScheduleDaily(),
    TaskTiming timing = const TaskTiming(),
    DateTime? createdAt,
  }) {
    return Task(
      id: const Uuid().v4(),
      name: name,
      type: type,
      goal: goal,
      steps: List.unmodifiable(steps),
      step: step,
      color: color,
      icon: icon,
      createdAt: createdAt ?? DateTime.now(),
      schedule: schedule,
      timing: timing,
    );
  }

  Task copyWith({
    String? name,
    TaskType? type,
    int? goal,
    List<String>? steps,
    int? step,
    int? color,
    int? icon,
    Schedule? schedule,
    TaskTiming? timing,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      goal: goal ?? this.goal,
      steps: List.unmodifiable(steps ?? this.steps),
      step: step ?? this.step,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt,
      schedule: schedule ?? this.schedule,
      timing: timing ?? this.timing,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.label,
        'goal': goal,
        if (steps.isNotEmpty) 'steps': steps,
        'goalSeconds': true,
        'step': step,
        'color': color,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
        'schedule': schedule.toJson(),
        'timing': timing.toJson(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    final type = TaskTypeX.fromValue(json['type'] as String? ?? 'count');
    var goal = json['goal'] as int;
    // Legacy data stored time goals in minutes; migrate to seconds.
    if (type == TaskType.minutes && json['goalSeconds'] != true) {
      goal = goal * 60;
    }
    final scheduleJson = json['schedule'];
    final schedule = scheduleJson is Map<String, dynamic>
        ? Schedule.fromJson(scheduleJson)
        : const ScheduleDaily();
    return Task(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      goal: goal,
      steps: List<String>.unmodifiable(
          (json['steps'] as List?)?.whereType<String>() ?? const <String>[]),
      step: json['step'] as int? ?? 1,
      color: json['color'] as int? ?? 0xFF5C6BC0,
      icon: json['icon'] as int? ?? 0xe0b0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      schedule: schedule,
      timing: json['timing'] is Map
          ? TaskTiming.fromJson(
              Map<String, dynamic>.from(json['timing'] as Map))
          : const TaskTiming(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
