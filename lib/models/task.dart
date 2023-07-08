import 'package:uuid/uuid.dart';

class Task {
  String uuid;
  String name;
  int goal;
  double progress;
  bool incremental;

  Task({
    required this.uuid,
    required this.name,
    required this.goal,
    required this.progress,
    required this.incremental,
  });

  Task.empty()
      : name = "Test Task",
        goal = 1,
        progress = 0.0,
        incremental = false,
        uuid = const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'goal': goal,
      'progress': progress,
      'incremental': incremental ? 1 : 0, //SQFLite doesn't support bools
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      uuid: json['uuid'],
      name: json['name'],
      goal: json['goal'],
      progress: json['progress'],
      incremental: json['incremental'] == 1 ? true : false,
    );
  }
}
