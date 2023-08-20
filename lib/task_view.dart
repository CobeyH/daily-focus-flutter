import 'package:daily_focus/providers/active_task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'play_button.dart';
import 'progress_bar_task.dart';

class TaskView extends ConsumerWidget {
  const TaskView({super.key});

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
            Hero(
              tag: task.uuid,
              child: ProgressBarTask(key: UniqueKey(), task: task),
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
                    onPressed: () => {print("Implement me")},
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
