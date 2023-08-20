import 'dart:math';

import 'package:daily_focus/providers/active_task_provider.dart';
import 'package:daily_focus/task_creation/task_creation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/task.dart';
import 'progress_bar_task.dart';
import 'providers/task_provider.dart';
import 'task_view.dart';

class TaskTab extends ConsumerWidget {
  const TaskTab({Key? key}) : super(key: key);

  Widget _getTaskGrid(BuildContext context, List<Task> tasks, WidgetRef ref) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks yet'));
    }
    double width = MediaQuery.of(context).size.width;
    int columnCount = max(width ~/ 195, 1);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.count(
        crossAxisCount: columnCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: tasks
            .map((e) => Column(
                  children: [
                    Text(e.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    Expanded(
                        child: TextButton(
                      style: ButtonStyle(
                          overlayColor: MaterialStateProperty.all<Color>(
                              Colors.transparent)),
                      onPressed: () => onTapProgressBar(context, e, ref),
                      child: Hero(tag: e.uuid, child: ProgressBarTask(task: e)),
                    ))
                  ],
                ))
            .toList(),
      ),
    );
  }

  onTapProgressBar(BuildContext context, Task task, WidgetRef ref) async {
    ref.read(activeTaskProvider.notifier).setActive(task);
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return const TaskView();
      },
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        body: ref.watch(tasksProvider).when(
            data: (tasks) => _getTaskGrid(context, tasks, ref),
            error: (e, _) => Text(e.toString()),
            loading: () => const Center(child: CircularProgressIndicator())),
        floatingActionButton: const TaskCreationButton());
  }
}
