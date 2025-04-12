import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'generated/task.freezed.dart';
part 'generated/task.g.dart';

@freezed
abstract class Task with _$Task {
  factory Task({
    required String uuid,
    required String name,
    required int goal,
    required int progress,
    required bool incremental,
    int? iconPoint,
  }) = _Task;

  Task._();

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  static Task empty() {
    return Task(
      name: "",
      goal: 0,
      progress: 0,
      incremental: false,
      uuid: const Uuid().v4().toString(),
    );
  }
}
