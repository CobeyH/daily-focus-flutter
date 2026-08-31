import 'package:uuid/uuid.dart';

import 'schedule.dart';

/// The two kinds of tasks described by the product goals.
///
/// * [count]   — occurrence based ("do X 5 times a day"). Each tap = +1.
/// * [minutes] — time based ("do X for N minutes a day"). Each tap = +step.
enum TaskType { count, minutes }

extension TaskTypeX on TaskType {
  String get label => this == TaskType.count ? 'times' : 'minutes';

  static TaskType fromValue(String v) =>
      v == 'minutes' ? TaskType.minutes : TaskType.count;
}

class Task {
  final String id;
  final String name;

  /// Whether the goal is measured in occurrences or minutes.
  final TaskType type;

  /// Daily target. For [TaskType.count] it's a number of occurrences; for
  /// [TaskType.minutes] it's a number of seconds.
  final int goal;

  /// How much one tap contributes. For [TaskType.count] this is always 1; for
  /// [TaskType.minutes] it's a configurable chunk of minutes (e.g. 5).
  final int step;

  /// ARGB color value used to theme the task.
  final int color;

  /// Material icon code point.
  final int icon;

  final DateTime createdAt;

  /// How often the task is due. Defaults to [ScheduleDaily] (every day) for
  /// tasks created without an explicit schedule.
  final Schedule schedule;

  const Task({
    required this.id,
    required this.name,
    required this.type,
    required this.goal,
    required this.step,
    required this.color,
    required this.icon,
    required this.createdAt,
    this.schedule = const ScheduleDaily(),
  });

  factory Task.create({
    required String name,
    required TaskType type,
    required int goal,
    required int step,
    required int color,
    required int icon,
    Schedule schedule = const ScheduleDaily(),
  }) {
    return Task(
      id: const Uuid().v4(),
      name: name,
      type: type,
      goal: goal,
      step: step,
      color: color,
      icon: icon,
      createdAt: DateTime.now(),
      schedule: schedule,
    );
  }

  Task copyWith({
    String? name,
    TaskType? type,
    int? goal,
    int? step,
    int? color,
    int? icon,
    Schedule? schedule,
  }) {
    return Task(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      goal: goal ?? this.goal,
      step: step ?? this.step,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt,
      schedule: schedule ?? this.schedule,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.label,
        'goal': goal,
        'goalSeconds': true,
        'step': step,
        'color': color,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
        'schedule': schedule.toJson(),
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
      step: json['step'] as int? ?? 1,
      color: json['color'] as int? ?? 0xFF5C6BC0,
      icon: json['icon'] as int? ?? 0xe0b0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      schedule: schedule,
    );
  }
}
