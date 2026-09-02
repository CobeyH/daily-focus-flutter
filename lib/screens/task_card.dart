import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';
import '../models/task.dart';
import '../providers/app_controller.dart';
import '../providers/timer_controller.dart';
import '../utils/dates.dart';
import '../utils/duration_format.dart';
import '../widgets/selectors.dart';
import 'task_creation.dart';

/// A card representing one task with its progress ring, streak, and tap
/// controls.
class TaskCard extends ConsumerWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  /// Shows a confirmation dialog before deleting [taskName]. Returns `true`
  /// if the user confirmed the deletion.
  static Future<bool?> _confirmDelete(
      BuildContext context, String taskName) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          '“$taskName” will be removed and its history will be cleared. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(taskProgressProvider(task));
    final done = ref.watch(taskDoneTodayProvider(task));
    final streak = ref.watch(taskStreakProvider(task));
    final overdue = ref.watch(taskOverdueProvider(task));
    final controller = ref.read(appControllerProvider.notifier);

    final color = Color(task.color);
    final unit = task.type.label;

    final today = todayOnly();
    final dueToday = isTaskDueOn(task, today);
    final scheduleDesc = task.schedule.describe();

    // Whether this task's countdown is actively running (not paused, and not
    // an occurrence task). Used to visually highlight the active task.
    final activeTimer = ref.watch(timerControllerProvider).timerFor(task.id);
    final isActive =
        task.type == TaskType.minutes && activeTimer?.paused == false;

    // For timed tasks, the ring reflects live elapsed time (filling up as the
    // countdown runs), so it updates every tick. For occurrence tasks it is
    // the stored progress. Both fill from empty to full as you approach the
    // goal.
    final remaining = task.type == TaskType.minutes
        ? ref.watch(taskRemainingProvider(task))
        : null;
    final double fraction;
    if (task.type == TaskType.minutes && remaining != null && task.goal > 0) {
      final total = Duration(seconds: task.goal);
      final elapsed = total - remaining;
      fraction =
          (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    } else {
      fraction = task.goal == 0 ? 0.0 : (progress / task.goal).clamp(0.0, 1.0);
    }

    final greyedOut = !dueToday && !overdue;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, task.name),
      onDismissed: (_) => controller.deleteTask(task.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        // Long-press anywhere on the card completes the task for today (or
        // resets it to zero if it's already complete — handy for undoing an
        // accidental auto-complete). `opaque` behavior ensures the long-press
        // is recognized regardless of any inner interactive widgets.
        behavior: HitTestBehavior.opaque,
        onLongPress: done
            ? () => controller.reset(task)
            : () => controller.markComplete(task),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isActive
                ? BorderSide(color: color, width: 2)
                : BorderSide(color: Colors.grey.shade200),
          ),
          elevation: isActive ? 4 : 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _ProgressRing(
                    fraction: fraction, color: color, icon: task.icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.name,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    TaskCreationScreen(existing: task),
                              ));
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            onPressed: () async {
                              final ok =
                                  await _confirmDelete(context, task.name);
                              if (ok == true) {
                                await controller.deleteTask(task.id);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.type == TaskType.minutes
                            ? 'Goal: ${formatGoalDuration(Duration(seconds: task.goal))} today'
                            : '$progress / ${task.goal} $unit today',
                        style: TextStyle(
                          color: greyedOut
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.event_repeat,
                            size: 14,
                            color: greyedOut
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            scheduleDesc,
                            style: TextStyle(
                              color: greyedOut
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          if (overdue) ...[
                            const SizedBox(width: 8),
                            _OverdueBadge(
                                missedDate:
                                    ref.watch(taskMissedDueDateProvider(task))),
                          ],
                        ],
                      ),
                      if (task.type == TaskType.minutes)
                        _TimedStatus(task: task, color: color),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '$streak day${streak == 1 ? '' : 's'} streak',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (greyedOut)
                  _OffDayAction(task: task, color: color)
                else if (task.type == TaskType.minutes)
                  _TimedAction(task: task, color: color, done: done)
                else
                  _CountAction(task: task, color: color, done: done),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A red pill rendered next to the schedule description. Shows when the
/// missed due date was so the user knows *which* date the task is overdue
/// from, not just that it's overdue in the abstract.
class _OverdueBadge extends StatelessWidget {
  final DateTime? missedDate;
  const _OverdueBadge({required this.missedDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        _label(missedDate),
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Builds a human-readable "since …" label from [missedDate].
  ///
  /// * Same day → "Overdue today".
  /// * 1 day ago → "Overdue since yesterday".
  /// * Within the last 6 days → "Overdue since Mon".
  /// * Otherwise → "Overdue since Aug 25".
  /// * `null` (no specific missed date known) → "Overdue".
  static String _label(DateTime? missed) {
    if (missed == null) return 'Overdue';
    final today = todayOnly();
    final m = DateTime(missed.year, missed.month, missed.day);
    final daysAgo = today.difference(m).inDays;
    if (daysAgo <= 0) return 'Overdue today';
    if (daysAgo == 1) return 'Overdue since yesterday';
    if (daysAgo < 7) {
      return 'Overdue since ${kWeekDayLabels[m.weekday - DateTime.monday]}';
    }
    final months = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Overdue since ${months[m.month - 1]} ${m.day}';
  }
}

/// A small, disabled button shown for recurring tasks that aren't due today,
/// indicating when the task is next due.
class _OffDayAction extends StatelessWidget {
  final Task task;
  final Color color;

  const _OffDayAction({required this.task, required this.color});

  @override
  Widget build(BuildContext context) {
    final next = task.schedule.nextDueDateAfter(todayOnly());
    final daysAway = next == null
        ? null
        : DateTime(next.year, next.month, next.day)
            .difference(todayOnly())
            .inDays;
    final label = next == null
        ? 'Not scheduled'
        : daysAway == 0
            ? 'Today'
            : 'Next: in ${daysAway}d';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(Icons.event, color: Colors.grey.shade500, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double fraction;
  final Color color;
  final int icon;

  const _ProgressRing(
      {required this.fraction, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: fraction,
            strokeWidth: 5,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Center(
            child: fraction >= 1.0
                ? Icon(Icons.check, color: color, size: 28)
                : Icon(iconFor(icon), color: color, size: 24),
          ),
        ],
      ),
    );
  }
}

/// Formats a [Duration] as `mm:ss` (or `h:mm:ss` for durations ≥ 1 hour).
String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

/// Shows the live countdown (or "Done") for a timed task.
class _TimedStatus extends ConsumerWidget {
  final Task task;
  final Color color;

  const _TimedStatus({required this.task, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(taskRemainingProvider(task));
    if (remaining == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${_fmtDuration(remaining)} remaining',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Play/stop button for timed tasks.
class _TimedAction extends ConsumerWidget {
  final Task task;
  final Color color;
  final bool done;

  const _TimedAction(
      {required this.task, required this.color, required this.done});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(taskRemainingProvider(task));
    final timerState = ref.watch(timerControllerProvider);
    final activeTimer = timerState.timerFor(task.id);
    final timer = ref.read(timerControllerProvider.notifier);
    final running = remaining != null && (activeTimer?.paused == false);

    return Column(
      children: [
        IconButton(
          onPressed:
              running ? () => timer.cancel(task) : () => timer.start(task),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: running ? color : color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              running ? Icons.stop : Icons.play_arrow,
              color: running ? Colors.white : color,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          done ? 'Done!' : (running ? 'Stop' : 'Start'),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

/// Tap-to-increment/decrement button for count-based tasks.
class _CountAction extends ConsumerWidget {
  final Task task;
  final Color color;
  final bool done;

  const _CountAction(
      {required this.task, required this.color, required this.done});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(taskProgressProvider(task));
    final controller = ref.read(appControllerProvider.notifier);

    return Column(
      children: [
        IconButton(
          onPressed: done && progress > 0
              ? () => controller.decrement(task)
              : () => controller.increment(task),
          icon: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: done ? color : color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check : Icons.add,
              color: done ? Colors.white : color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          done ? 'Done!' : 'Tap',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
