import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../providers/app_controller.dart';
import '../providers/timer_controller.dart';
import '../utils/duration_format.dart';
import '../widgets/selectors.dart';
import 'task_creation.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final TaskOccurrence? occurrence;
  const TaskCard({super.key, required this.task, this.occurrence});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = occurrence ?? ref.watch(taskOccurrenceProvider(task));
    if (current == null) return const SizedBox.shrink();
    final controller = ref.read(appControllerProvider.notifier);
    final timerState = ref.watch(timerControllerProvider);
    final storedTimer = timerState.timerFor(task.id);
    final timer = storedTimer?.occurrenceKey == current.key ||
            storedTimer?.occurrenceKey == null
        ? storedTimer
        : null;
    final remaining = timer?.remainingAt(timerState.now);
    final running = timer != null && !timer.paused;
    final finished = current.done || current.skipped;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = ColorScheme.fromSeed(
            seedColor: Color(task.color),
            brightness: Theme.of(context).brightness)
        .primary;
    final fraction = current.done
        ? 1.0
        : remaining != null && task.goal > 0
            ? (1 - remaining.inMilliseconds / (task.goal * 1000))
                .clamp(0.0, 1.0)
            : (current.progress / task.goal).clamp(0.0, 1.0);
    final streak = ref.watch(taskStreakProvider(task));
    final statusColor = switch (current.status) {
      OccurrenceStatus.overdue => colors.error,
      OccurrenceStatus.grace => colors.tertiary,
      OccurrenceStatus.complete => colors.primary,
      _ => colors.onSurfaceVariant,
    };
    Future<void> undo() => controller.reset(task, occurrenceKey: current.key);
    Future<void> complete() async {
      if (task.type == TaskType.count) {
        await controller.increment(task, occurrenceKey: current.key);
      } else {
        await controller.markComplete(task, occurrenceKey: current.key);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${task.name} updated'),
          action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (task.type == TaskType.count) {
                  controller.decrement(task, occurrenceKey: current.key);
                } else {
                  undo();
                }
              })));
    }

    return Card(
        child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: running
                    ? Border.all(color: colors.primary, width: 1.5)
                    : null),
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(
                    label:
                        '${task.name}, ${(fraction * 100).round()} percent complete',
                    child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(alignment: Alignment.center, children: [
                          CircularProgressIndicator(
                              value: fraction,
                              strokeWidth: 3,
                              color: color,
                              backgroundColor: color.withValues(alpha: 0.12)),
                          Icon(
                              current.done
                                  ? Icons.check_rounded
                                  : iconFor(task.icon),
                              color: color,
                              size: 23),
                        ]))),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(task.name, style: text.titleMedium),
                      const SizedBox(height: 3),
                      Text(task.schedule.describe(),
                          style: text.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ])),
                PopupMenuButton<String>(
                    tooltip: 'Task options',
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (action) async {
                      switch (action) {
                        case 'edit':
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  TaskCreationScreen(existing: task)));
                        case 'complete':
                          await controller.markComplete(task,
                              occurrenceKey: current.key);
                        case 'skip':
                          await controller.skip(task,
                              occurrenceKey: current.key);
                        case 'reset':
                          await undo();
                        case 'delete':
                          final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                      title: const Text('Delete task?'),
                                      content: Text(
                                          '“${task.name}” and its history will be deleted.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel')),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'))
                                      ]));
                          if (confirmed == true) {
                            await controller.deleteTask(task.id);
                          }
                      }
                    },
                    itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit task')),
                          if (current.visible && !finished) ...[
                            const PopupMenuItem(
                                value: 'complete',
                                child: Text('Mark complete')),
                            const PopupMenuItem(
                                value: 'skip',
                                child: Text('Skip this occurrence')),
                          ],
                          if (current.progress > 0 || finished || timer != null)
                            const PopupMenuItem(
                                value: 'reset',
                                child: Text('Reset this occurrence')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete task')),
                        ]),
              ]),
              const SizedBox(height: 16),
              Text(current.label,
                  style: text.bodyMedium?.copyWith(
                      color: statusColor, fontWeight: FontWeight.w500)),
              if (current.status == OccurrenceStatus.upcoming)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Due ${current.dueLabel}',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant))),
              if (current.status == OccurrenceStatus.due &&
                  task.timing.graceDays > 0)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Okay through ${current.graceLabel}',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant))),
              const SizedBox(height: 16),
              Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (current.visible) ...[
                      if (finished)
                        OutlinedButton.icon(
                            onPressed: () => controller.undoCompletion(task,
                                occurrenceKey: current.key),
                            icon: const Icon(Icons.undo_rounded, size: 18),
                            label: const Text('Undo'))
                      else if (task.type == TaskType.minutes)
                        FilledButton.icon(
                            onPressed: () => running
                                ? ref
                                    .read(timerControllerProvider.notifier)
                                    .cancel(task)
                                : ref
                                    .read(timerControllerProvider.notifier)
                                    .start(task, occurrenceKey: current.key),
                            icon: Icon(running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                            label: Text(running
                                ? 'Pause'
                                : timer == null
                                    ? 'Start timer'
                                    : 'Resume'))
                      else
                        FilledButton.icon(
                            onPressed: complete,
                            icon: Icon(
                                task.goal == 1
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 18),
                            label: Text(task.goal == 1 ? 'Complete' : 'Add 1')),
                    ],
                    Text(
                        task.type == TaskType.minutes
                            ? remaining == null
                                ? formatGoalDuration(
                                    Duration(seconds: task.goal))
                                : '${_duration(remaining)} left'
                            : '${current.progress} / ${task.goal} completed',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                    if (streak > 0)
                      Text(
                          '$streak ${task.schedule.describe() == 'Every day' ? 'day' : 'completion'}${streak == 1 ? '' : 's'} in a row',
                          style:
                              text.bodySmall?.copyWith(color: colors.primary)),
                  ]),
            ])));
  }

  String _duration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${value.inHours > 0 ? '${value.inHours}:' : ''}$minutes:$seconds';
  }
}
