import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

import 'models/task.dart';

class ProgressBarTask extends ConsumerWidget {
  final Task task;
  const ProgressBarTask({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircularStepProgressIndicator(
            totalSteps: task.goal,
            padding: task.incremental ? 1 / task.goal : 0,
            currentStep: task.progress.round(),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                IconData(task.iconPoint, fontFamily: 'MaterialIcons'),
                size: 50,
              ),
              Text(
                task.progress.toStringAsFixed(0),
                style: Theme.of(context).textTheme.titleLarge,
              )
            ]),
          ),
        ));
  }
}
