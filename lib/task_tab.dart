import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/task.dart';
import 'progress_bar_task.dart';
import 'providers/task_provider.dart';
import 'task_view.dart';

class TaskTab extends ConsumerWidget {
  const TaskTab({Key? key}) : super(key: key);

  Widget _getTaskGrid(BuildContext context, List<Task> tasks) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks yet'));
    }
    double width = MediaQuery.of(context).size.width;
    int columnCount = max(width ~/ 200, 1);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.count(
        crossAxisCount: columnCount,
        mainAxisSpacing: 30,
        crossAxisSpacing: 30,
        children: tasks
            .map((e) => Column(
                  children: [
                    Text(e.name),
                    TextButton(
                      style: ButtonStyle(
                          overlayColor: MaterialStateProperty.all<Color>(
                              Colors.transparent)),
                      onPressed: () => onTapProgressBar(context, e),
                      child: ProgressBarTask(task: e),
                    )
                  ],
                ))
            .toList(),
      ),
    );
  }

  onTapProgressBar(BuildContext context, Task task) async {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return TaskView(task: task);
      },
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        body: ref.watch(tasksProvider).when(
            data: (tasks) => _getTaskGrid(context, tasks),
            error: (e, _) => Text(e.toString()),
            loading: () => const Center(child: CircularProgressIndicator())),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            ref.read(tasksProvider.notifier).createNew(Task.empty());
          },
          child: const Icon(Icons.add),
        ));
  }
}
