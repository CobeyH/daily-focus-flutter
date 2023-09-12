import 'package:daily_focus/providers/saves_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../database/task_database.dart';
import '../models/save.dart';
import '../models/task.dart';

part 'task_provider.g.dart';

@Riverpod(keepAlive: true)
class Tasks extends _$Tasks {
  @override
  Future<List<Task>> build() async {
    final db = TasksDatabase.dbProvider;
    return await db.getAllTasks();
  }

  void createNew(Task task) async {
    task.uuid = const Uuid().v4().toString();
    state = AsyncData([...state.value ?? [], task]);
    await TasksDatabase.dbProvider.insertTask(task);
  }

  Future<void> updateTask(Task task) async {
    state = AsyncData((state.value ?? [])
        .map((t) => t.uuid == task.uuid ? task : t)
        .toList());
    await TasksDatabase.dbProvider.updateTask(task);
  }

  void delete(Task task) {
    state = AsyncData((state.value ?? [])
        .where((element) => element.uuid != task.uuid)
        .toList());
    TasksDatabase.dbProvider.deleteTask(task.uuid);
  }

  Future<void> saveAll() async {
    List<Future> futures = [];
    for (Task task in state.value ?? []) {
      futures
          .add(ref.read(savesProvider.notifier).createNew(Save.fromTask(task)));
    }
    await Future.wait(futures);
  }

  Future<void> resetAll() async {
    for (Task task in state.value ?? []) {
      task.progress = 0;
      await updateTask(task);
    }
  }
}
