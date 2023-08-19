import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/task.dart';
import 'providers/task_provider.dart';

class PlayButton extends ConsumerStatefulWidget {
  final Task activeTask;
  const PlayButton({Key? key, required this.activeTask}) : super(key: key);

  @override
  PlayButtonState createState() => PlayButtonState();
}

class PlayButtonState extends ConsumerState<PlayButton> {
  bool isPlaying = false;
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(
        () => widget.activeTask.progress += 1,
      );
      ref.watch(tasksProvider.notifier).updateTask(widget.activeTask);
    });
  }

  void stopTimer() {
    timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          isPlaying = !isPlaying;
        });
        if (isPlaying) {
          startTimer();
        } else {
          stopTimer();
        }
      },
      child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
    );
  }
}