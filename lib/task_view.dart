import 'package:daily_focus/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/task.dart';
import 'play_button.dart';
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
            Hero(
              tag: widget.task.uuid,
              child: ProgressBarTask(task: widget.task),
            ),
            PlayButton(activeTask: widget.task),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                    onPressed: () {
                      ref.read(tasksProvider.notifier).delete(widget.task.uuid);
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
