import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/task.dart';
import 'task_provider.dart';

part 'active_task_provider.g.dart';

@Riverpod(keepAlive: true)
class ActiveTask extends _$ActiveTask {
  @override
  Task? build() {
    return null;
  }

  void setActive(Task task) {
    state = task;
  }

  void increment() async {
    if (state == null) return;
    state = Task(
        goal: state!.goal,
        progress: state!.progress + 1,
        uuid: state!.uuid,
        name: state!.name,
        incremental: state!.incremental,
        iconPoint: state!.iconPoint);
    ref.read(tasksProvider.notifier).updateTask(state!);
  }

  void delete() {
    if (state == null) return;
    ref.read(tasksProvider.notifier).delete(state!);
  }
}
