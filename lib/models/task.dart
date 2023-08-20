import 'package:uuid/uuid.dart';

class Task {
  String uuid;
  String name;
  int goal;
  int progress;
  bool incremental;
  int? iconPoint;

  Task({
    required this.uuid,
    required this.name,
    required this.goal,
    required this.progress,
    required this.incremental,
    this.iconPoint,
  });

  Task.empty()
      : name = "Test Task",
        goal = 1,
        progress = 0,
        incremental = false,
        uuid = const Uuid().v4().toString();

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'goal': goal,
      'progress': progress,
      'incremental': incremental ? 1 : 0, //SQFLite doesn't support bools
      'iconPoint': iconPoint,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      uuid: json['uuid'],
      name: json['name'],
      goal: json['goal'],
      progress: json['progress'],
      incremental: json['incremental'] == 1 ? true : false,
      iconPoint: json['iconPoint'],
    );
  }
}
