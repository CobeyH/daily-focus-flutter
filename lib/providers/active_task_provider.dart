import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/task_database.dart';
import '../models/task.dart';
import 'task_provider.dart';

part 'active_task_provider.g.dart';

@Riverpod(keepAlive: true)
class ActiveTask extends _$ActiveTask {
  @override
  Task? build() {
    return null;
  }

  void setActive(Task? task) {
    state = task;
  }

  void increment() async {
    if (state == null) return;
    state!.progress += 1;
    ref.read(tasksProvider.notifier).updateTask(state!);
    await TasksDatabase.dbProvider.updateTask(state!);
  }

  void delete() {
    if (state == null) return;
    TasksDatabase.dbProvider.deleteTask(state!.uuid);
  }
}
