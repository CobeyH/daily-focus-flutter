import 'package:daily_focus/models/task.dart' show Task;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/save.freezed.dart';
part 'generated/save.g.dart';

@freezed
abstract class Save with _$Save {
  factory Save({
    required String uuid,
    required String name,
    required int goal,
    required int progress,
    required bool incremental,
    int? iconPoint,
    required DateTime date,
  }) = _Save;

  Save._();

  factory Save.fromJson(Map<String, dynamic> json) => _$SaveFromJson(json);

  factory Save.fromTask(Task t) {
    DateTime now = DateTime.now();
    return Save(
      uuid: t.uuid,
      name: t.name,
      goal: t.goal,
      progress: t.progress,
      incremental: t.incremental,
      date: DateTime(now.year, now.month, now.day),
    );
  }
}
