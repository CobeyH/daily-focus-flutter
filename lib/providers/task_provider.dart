import 'package:daily_focus/providers/task_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/task.dart';

part 'task_provider.g.dart';

@Riverpod(keepAlive: true)
class Tasks extends _$Tasks {
  @override
  Future<List<Task>> build() async {
    final db = TasksDatabase.dbProvider;
    return await db.getAllTasks();
  }

  void createNew(Task task) {
    state = AsyncData([...state.value ?? [], task]);
    TasksDatabase.dbProvider.insertTask(task);
  }

  void delete(String taskId) {
    state = AsyncData((state.value ?? [])
        .where((element) => element.uuid != taskId)
        .toList());
    TasksDatabase.dbProvider.deleteTask(taskId);
  }
}
