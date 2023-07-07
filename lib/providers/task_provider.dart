import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/task.dart';

part 'task_provider.g.dart';

@riverpod
class TaskProvider extends _$TaskProvider {
  @override
  Future<List<Task>> build() async {
    return [];
  }

  createNew(Task task) {
    state = AsyncData([...state.value ?? [], task]);
  }
}
