import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

part 'task_provider.g.dart';

@Riverpod(keepAlive: true)
class Tasks extends _$Tasks {
  @override
  Future<List<Task>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('taskList');
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Task.fromJson(json)).toList();
    }
    return [];
  }

  void createNew(Task task) {
    state = AsyncData([...state.value ?? [], task]);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
      'taskList',
      jsonEncode(state.value?.map((t) => t.toJson()).toList()),
    );
  }
}
