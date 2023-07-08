import 'package:daily_focus/providers/db_provider.dart';

import '../models/task.dart';

class TasksDatabase {
  static final TasksDatabase dbProvider = TasksDatabase._();

  TasksDatabase._();

  Future<List<Task>> getAllTasks() async {
    final db = await DBProvider.instance.database;
    List<Map<String, dynamic>> jsonTasks = await db.query('tasks');
    return jsonTasks.map((t) => Task.fromJson(t)).toList();
  }

  Future<int> insertTask(Task task) async {
    final db = await DBProvider.instance.database;
    return await db.insert('tasks', task.toJson());
  }

  Future<int> updateTask(Task task) async {
    final db = await DBProvider.instance.database;
    return await db.update(
      'tasks',
      task.toJson(),
      where: 'uuid = ?',
      whereArgs: [task.uuid],
    );
  }

  Future<int> deleteTask(String uuid) async {
    final db = await DBProvider.instance.database;
    return await db.delete(
      'tasks',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }
}
