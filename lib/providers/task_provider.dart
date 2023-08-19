import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../database/task_database.dart';
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
    task.uuid = const Uuid().v4().toString();
    state = AsyncData([...state.value ?? [], task]);
    TasksDatabase.dbProvider.insertTask(task);
  }

  void updateTask(Task task) async {
    state = AsyncData((state.value ?? [])
        .map((element) => element.uuid == task.uuid ? task : element)
        .toList());
    await TasksDatabase.dbProvider.updateTask(task);
  }
}
