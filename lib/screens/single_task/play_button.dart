import 'dart:async';
import 'package:daily_focus/providers/active_task_provider.dart';
import 'package:daily_focus/notification_task_finished.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';

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
      ref.watch(activeTaskProvider.notifier).increment();
    });
  }

  void stopTimer() {
    timer?.cancel();
  }

  void toggleTimerTask() {
    setState(() {
      isPlaying = !isPlaying;
    });
    if (isPlaying) {
      startTimer();
    } else {
      stopTimer();
    }
  }

  IconData getIcon() {
    return isPlaying
        ? Icons.pause
        : widget.activeTask.incremental
            ? Icons.fast_forward
            : Icons.play_arrow;
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(activeTaskProvider);
    bool finished = task == null || task.progress >= task.goal;
    ref.listen<Task?>(activeTaskProvider, (Task? _, Task? task) {
      if (finished) {
        stopTimer();
        isPlaying = false;
        showNotification();
      }
    });
    return ElevatedButton(
      onPressed: () {
        if (finished) return;
        if (task.incremental) {
          ref.read(activeTaskProvider.notifier).increment();
        } else {
          toggleTimerTask();
        }
      },
      style: ElevatedButton.styleFrom(
          backgroundColor: finished ? Colors.grey : Colors.lightGreen),
      child: Icon(getIcon()),
    );
  }
}
