import 'package:daily_focus/task_creation/task_creation.dart';
import 'package:flutter/material.dart';

class TaskCreationButton extends StatelessWidget {
  const TaskCreationButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return const TaskCreation();
          },
        ),
      ),
      child: const Icon(Icons.add),
    );
  }
}
