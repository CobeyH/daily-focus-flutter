import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/task.dart';
import 'progress_bar_task.dart';

class TaskView extends ConsumerStatefulWidget {
  final Task task;
  const TaskView({Key? key, required this.task}) : super(key: key);

  @override
  TaskViewState createState() => TaskViewState();
}

class TaskViewState extends ConsumerState<TaskView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.name),
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: Hero(
                tag: widget.task.uuid,
                child: ProgressBarTask(task: widget.task),
              ),
            ),
            ElevatedButton(
                onPressed: () => {print("Implement me")},
                child: const Icon(Icons.play_arrow)),
            const SizedBox(
              height: 100,
            )
          ],
        ),
      ),
    );
  }
}
