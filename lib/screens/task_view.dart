import 'package:daily_focus/providers/active_task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/task.dart';
import 'play_button.dart';
import 'progress_bar_task.dart';
import 'task_creation/task_creation.dart';

class TaskView extends ConsumerWidget {
  const TaskView({super.key});

  void editTask(BuildContext context, Task activeTask) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TaskCreation(task: activeTask);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(activeTaskProvider);
    if (task == null) return const Center(child: Text('No task selected'));
    return Scaffold(
      appBar: AppBar(
        title: Text(task.name, style: Theme.of(context).textTheme.titleLarge),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Hero(
                  tag: task.uuid,
                  child: ProgressBarTask(key: UniqueKey(), task: task)),
            ),
            PlayButton(activeTask: task),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () {
                      ref.read(activeTaskProvider.notifier).delete();
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.delete)),
                ElevatedButton(
                    onPressed: () => editTask(context, task),
                    child: const Icon(Icons.edit)),
              ],
            ),
            const SizedBox(
              height: 100,
            )
          ],
        ),
      ),
    );
  }
}
