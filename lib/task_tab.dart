import 'dart:math';

import 'package:flutter/material.dart';

import 'models/task.dart';
import 'progress_bar_task.dart';

class TaskTab extends StatelessWidget {
  const TaskTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Task> tasks = [
      Task(name: 'Task 1', goal: 10, progress: 3.0, incremental: true),
      Task(name: 'Task 2', goal: 15, progress: 5.0, incremental: false),
      Task(name: 'Task 3', goal: 20, progress: 3.0, incremental: true),
    ];
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
                    ProgressBarTask(task: e),
                  ],
                ))
            .toList(),
      ),
    );
  }
}
