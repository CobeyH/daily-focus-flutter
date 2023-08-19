import 'dart:math';

import 'package:flutter/material.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

import 'models/task.dart';

class ProgressBarTask extends StatefulWidget {
  final Task task;
  const ProgressBarTask({Key? key, required this.task}) : super(key: key);

  @override
  ProgressBarTaskState createState() => ProgressBarTaskState();
}

class ProgressBarTaskState extends State<ProgressBarTask> {
  late Task _task;

  @override
  void initState() {
    _task = widget.task;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircularStepProgressIndicator(
            totalSteps: _task.goal,
            padding: _task.incremental ? 0 : pi / 20,
            currentStep: _task.progress.round(),
            child: Center(
                child: Text(
              _task.progress.toStringAsFixed(0),
              style: Theme.of(context).textTheme.titleLarge,
            )),
          ),
        ));
  }
}
