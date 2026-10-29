import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_occurrence.dart';
import '../providers/app_controller.dart';
import '../providers/clock_provider.dart';
import '../providers/timer_controller.dart';
import '../utils/dates.dart';
import 'streak_screen.dart';
import 'task_card.dart';
import 'task_creation.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _view = 'Today';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final now = ref.watch(clockProvider);
    final timers =
        ref.watch(timerControllerProvider.select((value) => value.timers));
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final occurrences = <TaskOccurrence>[];
    for (final task in state.tasks) {
      var occurrence = _view == 'Upcoming'
          ? nextOccurrence(task, state.entries, now)
          : currentOccurrence(task, state.entries, now);
      final timerKey = timers[task.id]?.occurrenceKey;
      if (_view != 'Upcoming' && timerKey != null) {
        occurrence = TaskOccurrence(task, DateTime.parse(timerKey),
            entryFor(state.entries, task.id, timerKey), now);
      }
      if (occurrence != null && (_view != 'Today' || occurrence.visible)) {
        occurrences.add(occurrence);
      }
      if (_view == 'Today') {
        for (final entry in state.entries.where((e) =>
            e.taskId == task.id &&
            e.completedAt != null &&
            dateKey(e.completedAt!.toLocal()) == dateKey(now))) {
          if (!occurrences
              .any((o) => o.task.id == task.id && o.key == entry.dateKey)) {
            occurrences.add(TaskOccurrence(
                task, DateTime.parse(entry.dateKey), entry, now));
          }
        }
      }
    }
    int rank(TaskOccurrence value) => switch (value.status) {
          OccurrenceStatus.overdue => 0,
          OccurrenceStatus.grace => 1,
          OccurrenceStatus.due => 2,
          OccurrenceStatus.available => 3,
          OccurrenceStatus.upcoming => 4,
          _ => 5,
        };
    occurrences.sort((a, b) {
      final compare = rank(a).compareTo(rank(b));
      return compare == 0 ? a.dueDate.compareTo(b.dueDate) : compare;
    });
    final pending = occurrences.where((o) => !o.done && !o.skipped).toList();
    final completed = occurrences.where((o) => o.done || o.skipped).toList();
    return Scaffold(
      appBar: AppBar(
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.spa_outlined, color: colors.primary),
            const SizedBox(width: 10),
            const Flexible(
                child: Text('Daily Focus',
                    maxLines: 1, overflow: TextOverflow.ellipsis))
          ]),
          actions: [
            IconButton(
                tooltip: 'History',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StreakScreen())),
                icon: const Icon(Icons.calendar_month_outlined)),
            if (ref.watch(syncCoordinatorProvider) != null)
              PopupMenuButton<String>(
                  tooltip: 'Account',
                  icon: const Icon(Icons.account_circle_outlined),
                  onSelected: (_) => _signOut(context),
                  itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'out', child: Text('Sign out'))
                      ]),
            const SizedBox(width: 8),
          ]),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
                  children: [
                    Text(
                        '${const [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday'
                        ][now.weekday - 1]}, ${shortDate(now)}',
                        style:
                            text.labelLarge?.copyWith(color: colors.primary)),
                    const SizedBox(height: 8),
                    Text('A little progress,\nevery day.',
                        style: text.headlineMedium),
                    const SizedBox(height: 12),
                    Text(
                        _view == 'Today'
                            ? pending.isEmpty
                                ? 'Room to breathe. Your day is clear.'
                                : '${pending.length} task${pending.length == 1 ? '' : 's'} ready for your attention.'
                            : _view == 'Upcoming'
                                ? 'A little space to plan ahead.'
                                : 'Your routines, all in one place.',
                        style: text.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final view in ['Today', 'Upcoming', 'All'])
                        ChoiceChip(
                            label: Text(view),
                            selected: _view == view,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _view = view))
                    ]),
                    const SizedBox(height: 24),
                    if (pending.isEmpty)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(children: [
                                Icon(
                                    state.tasks.isEmpty
                                        ? Icons.add_task_rounded
                                        : Icons.check_circle_outline_rounded,
                                    color: colors.primary,
                                    size: 40),
                                const SizedBox(height: 16),
                                Text(
                                    state.tasks.isEmpty
                                        ? 'No tasks yet'
                                        : _view == 'Upcoming'
                                            ? 'Nothing coming up'
                                            : 'All clear for today',
                                    style: text.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                    state.tasks.isEmpty
                                        ? 'Start with one small thing you want to do regularly.'
                                        : _view == 'Today'
                                            ? 'Your next tasks will appear when their window opens.'
                                            : 'Adjust a schedule to plan your next occurrence.',
                                    textAlign: TextAlign.center,
                                    style: text.bodyMedium?.copyWith(
                                        color: colors.onSurfaceVariant)),
                              ]))),
                    for (final occurrence in pending)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TaskCard(
                              key: ValueKey(
                                  '${occurrence.task.id}/${occurrence.key}'),
                              task: occurrence.task,
                              occurrence: occurrence)),
                    if (completed.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ExpansionTile(
                              key: PageStorageKey('completed-$_view'),
                              tilePadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              title: Text(
                                  'Completed & skipped (${completed.length})',
                                  style: text.titleSmall),
                              shape: const Border(),
                              collapsedShape: const Border(),
                              children: [
                                for (final occurrence in completed)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: TaskCard(
                                          key: ValueKey(
                                              'done-${occurrence.task.id}/${occurrence.key}'),
                                          task: occurrence.task,
                                          occurrence: occurrence))
                              ])),
                  ]))),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TaskCreationScreen())),
          icon: const Icon(Icons.add),
          label: const Text('New task')),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Sign out?'),
                content: const Text('Your tasks will stay on this device.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign out'))
                ]));
    if (confirmed == true) await ref.read(syncCoordinatorProvider)?.signOut();
  }
}
