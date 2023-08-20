import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

import 'models/task.dart';

class ProgressBarTask extends ConsumerWidget {
  final Task task;
  const ProgressBarTask({Key? key, required this.task}) : super(key: key);

  String formatSeconds(int seconds) {
    if (seconds < 0) {
      return "Invalid input";
    }

    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;

    String hoursStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}h:' : '';
    String minutesStr = hours > 0 || minutes > 0
        ? '${minutes.toString().padLeft(2, '0')}m:'
        : '';
    String secondsStr = "${remainingSeconds.toString().padLeft(2, '0')}s";

    return hoursStr + minutesStr + secondsStr;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isComplete = task.progress >= task.goal;

    Text progressText = Text(
      task.incremental
          ? '${(task.goal - task.progress)} Left'
          : formatSeconds(task.goal - task.progress),
      style: Theme.of(context).textTheme.titleLarge,
    );

    return AspectRatio(
      aspectRatio: 1,
      child: CircularStepProgressIndicator(
        totalSteps: task.goal,
        padding: task.incremental ? 1 / task.goal : 0,
        currentStep: task.progress.round(),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            IconData(task.iconPoint, fontFamily: 'MaterialIcons'),
            color: Colors.black,
            size: 50,
          ),
          if (!isComplete) progressText,
        ]),
      ),
    );
  }
}
