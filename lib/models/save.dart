import 'package:daily_focus/models/task.dart';

class Save extends Task {
  final DateTime date;

  Save(
      {required super.uuid,
      required super.name,
      required super.goal,
      required super.progress,
      required super.incremental,
      super.iconPoint,
      required this.date});

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'goal': goal,
      'progress': progress,
      'incremental': incremental ? 1 : 0, //SQFLite doesn't support bools
      'iconPoint': iconPoint,
      'date': date.toIso8601String()
    };
  }

  factory Save.fromTask(Task t) {
    return Save(
      uuid: t.uuid,
      name: t.name,
      goal: t.goal,
      progress: t.progress,
      incremental: t.incremental,
      date: DateTime.now(),
    );
  }

  @override
  factory Save.fromJson(Map<String, dynamic> json) {
    return Save(
        uuid: json['uuid'],
        name: json['name'],
        goal: json['goal'],
        progress: json['progress'],
        incremental: json['incremental'] == 1 ? true : false,
        iconPoint: json['iconPoint'],
        date: DateTime(json['date']));
  }
}
