import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/task_occurrence.dart';
import '../providers/app_controller.dart';
import '../providers/clock_provider.dart';
import '../utils/dates.dart';
import '../widgets/selectors.dart';

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final now = ref.watch(clockProvider);
    final first = calendarDay(now, 1 - now.weekday - 21);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
        appBar: AppBar(title: const Text('Your history')),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text('Consistency, with room\nfor real life.',
                      style: text.headlineMedium),
                  const SizedBox(height: 12),
                  Text('The last four weeks. Tap a day for its details.',
                      style: text.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    _legend(context, Icons.check, 'On time', colors.primary),
                    _legend(context, Icons.done_all, 'Within grace',
                        colors.tertiary),
                    _legend(context, Icons.schedule, 'Late', colors.error),
                    _legend(context, Icons.close, 'Missed', colors.error),
                    _legend(context, Icons.remove, 'Skipped / rest',
                        colors.onSurfaceVariant),
                  ]),
                  const SizedBox(height: 24),
                  if (state.tasks.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'Create a task to start tracking your progress.')),
                  for (final task in state.tasks)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Icon(iconFor(task.icon),
                                            color: Color(task.color)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(task.name,
                                                style: text.titleMedium))
                                      ]),
                                      const SizedBox(height: 8),
                                      Text(
                                          '${ref.watch(taskStreakProvider(task))} in a row · Best ${ref.watch(taskBestStreakProvider(task))}',
                                          style: text.bodySmall?.copyWith(
                                              color: colors.onSurfaceVariant)),
                                      const SizedBox(height: 18),
                                      Row(children: [
                                        for (final day in [
                                          'M',
                                          'T',
                                          'W',
                                          'T',
                                          'F',
                                          'S',
                                          'S'
                                        ])
                                          Expanded(
                                              child: Center(
                                                  child: Text(day,
                                                      style: text.labelSmall)))
                                      ]),
                                      const SizedBox(height: 6),
                                      for (var week = 0; week < 4; week++)
                                        Row(children: [
                                          for (var weekday = 0;
                                              weekday < 7;
                                              weekday++)
                                            Expanded(
                                                child: _day(
                                                    context,
                                                    task,
                                                    calendarDay(first,
                                                        week * 7 + weekday),
                                                    state,
                                                    now))
                                        ]),
                                    ])))),
                ]))));
  }

  Widget _legend(
          BuildContext context, IconData icon, String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall)
      ]);
  Widget _day(BuildContext context, Task task, DateTime date, AppState state,
      DateTime now) {
    final colors = Theme.of(context).colorScheme;
    final entry = entryFor(state.entries, task.id, dateKey(date));
    final occurrence = TaskOccurrence(task, date, entry, now);
    final scheduled = entry != null ||
        (task.schedule.isDueOn(date) && !date.isBefore(scheduleStart(task)));
    final future = date.isAfter(dateOnly(now));
    final status = !scheduled
        ? 'Rest day'
        : occurrence.done
            ? occurrence.label
            : occurrence.skipped
                ? 'Skipped'
                : future
                    ? 'Upcoming'
                    : task.timing.pastGrace(date, now)
                        ? 'Missed'
                        : 'Open';
    final icon = !scheduled || occurrence.skipped
        ? Icons.remove
        : occurrence.done
            ? entry?.completionTiming == 'grace'
                ? Icons.done_all
                : entry?.completionTiming == 'late'
                    ? Icons.schedule
                    : Icons.check
            : future
                ? Icons.more_horiz
                : task.timing.pastGrace(date, now)
                    ? Icons.close
                    : Icons.circle_outlined;
    final color = !scheduled || occurrence.skipped || future && !occurrence.done
        ? colors.onSurfaceVariant
        : occurrence.done
            ? entry?.completionTiming == 'late'
                ? colors.error
                : entry?.completionTiming == 'grace'
                    ? colors.tertiary
                    : colors.primary
            : task.timing.pastGrace(date, now)
                ? colors.error
                : colors.onSurfaceVariant;
    return Padding(
        padding: const EdgeInsets.all(2),
        child: Semantics(
            label: '${shortDate(date)}: $status',
            button: true,
            child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(task.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 12),
                                  Text('${shortDate(date)} · $status'),
                                  if (scheduled) ...[
                                    const SizedBox(height: 8),
                                    Text('Due ${occurrence.dueLabel}')
                                  ],
                                  if (entry?.completedAt != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                        'Recorded ${shortDate(entry!.completedAt!.toLocal())} at ${clockLabel(entry.completedAt!.toLocal().hour * 60 + entry.completedAt!.toLocal().minute)}')
                                  ],
                                ])))),
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: scheduled && !future
                            ? color.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      Text('${date.day}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Icon(icon, size: 18, color: color),
                    ])))));
  }
}
