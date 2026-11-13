import '../providers/completion_feedback_provider.dart';
import '../widgets/task_completion_animation.dart';
import 'forest_screen.dart';
import '../providers/day_slots_provider.dart';
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
import 'day_slots_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _view = 'Today';
  final _forestAnchor = GlobalKey();
  final _cardAnchors = <String, GlobalKey>{};
  final _departing = <String, TaskCompletionFeedback>{};
  final _flights = <OverlayEntry>{};
  late final _forestPulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  late final _forestScale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40),
    TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60),
  ]).animate(_forestPulse);

  bool get _visibleRoute =>
      mounted && ModalRoute.of(context)?.isCurrent == true;
  @override
  void dispose() {
    for (final flight in _flights) {
      flight.remove();
      flight.dispose();
    }
    _forestPulse.dispose();
    super.dispose();
  }

  Rect? _bounds(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _completion(TaskCompletionFeedback event) {
    if (!_visibleRoute || MediaQuery.disableAnimationsOf(context)) return;
    final source = _bounds(_cardAnchors[event.key]);
    final start = source?.center;
    final end = _bounds(_forestAnchor)?.center;
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    if (start == null || !screen.contains(start)) {
      _forestPulse.forward(from: 0);
      return;
    }
    setState(() => _departing[event.key] = event);
    if (end == null) return;
    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject() as RenderBox;
    late final OverlayEntry flight;
    flight = OverlayEntry(
        builder: (_) => CompletionWaterFlight(
            start: box.globalToLocal(start),
            sourceBounds: box.globalToLocal(source!.topLeft) & source.size,
            end: box.globalToLocal(end),
            isVisible: () => _visibleRoute,
            onFinished: () {
              if (!_flights.remove(flight)) return;
              flight.remove();
              flight.dispose();
              if (_visibleRoute) _forestPulse.forward(from: 0);
            }));
    _flights.add(flight);
    overlay.insert(flight);
  }

  Widget _pendingCard(TaskOccurrence occurrence) {
    final id = '${occurrence.task.id}/${occurrence.key}';
    final event = _departing[id];
    final card = Padding(
        key: _cardAnchors.putIfAbsent(id, () => GlobalKey()),
        padding: const EdgeInsets.only(bottom: 12),
        child: TaskCard(
            task: occurrence.task, occurrence: event?.completed ?? occurrence));
    if (event == null) return card;
    return TaskCompletionExit(
        key: ObjectKey(event),
        onFinished: () {
          if (mounted && identical(_departing[id], event)) {
            setState(() => _departing.remove(id));
          }
        },
        child: card);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(completionFeedbackProvider, (_, next) {
      if (next != null) _completion(next);
    });
    final state = ref.watch(appControllerProvider);
    _departing.removeWhere((_, event) =>
        !(entryFor(state.entries, event.before.task.id, event.before.key)
                ?.isComplete(event.before.goal) ??
            false));
    final now = ref.watch(clockProvider);
    final slots = ref.watch(daySlotsProvider);
    final timers =
        ref.watch(timerControllerProvider.select((value) => value.timers));
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final occurrences = <TaskOccurrence>[];
    for (final task in state.tasks) {
      var occurrence = _view == 'Upcoming'
          ? nextOccurrence(task, state.entries, now, slots)
          : currentOccurrence(task, state.entries, now, slots);
      final timerKey = timers[task.id]?.occurrenceKey;
      if (_view != 'Upcoming' && timerKey != null) {
        occurrence = TaskOccurrence(task, DateTime.parse(timerKey),
            entryFor(state.entries, task.id, timerKey), now, slots);
      }
      if (occurrence != null) {
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
                task, DateTime.parse(entry.dateKey), entry, now, slots));
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
    final pending = occurrences
        .where((o) => !o.done && !o.skipped && (_view != 'Today' || o.visible))
        .toList();
    final upcomingToday = occurrences
        .where((o) =>
            !o.done &&
            !o.skipped &&
            now.isBefore(o.appearsAt) &&
            dateKey(o.appearsAt) == dateKey(now))
        .toList()
      ..sort((a, b) => a.appearsAt.compareTo(b.appearsAt));
    final completed = occurrences.where((o) => o.done || o.skipped).toList();
    final displayedPending = [
      ...pending,
      for (final event in _departing.values)
        if (!pending.any((o) =>
            o.task.id == event.before.task.id && o.key == event.before.key))
          event.before
    ]..sort((a, b) {
        final compare = rank(a).compareTo(rank(b));
        return compare == 0 ? a.dueDate.compareTo(b.dueDate) : compare;
      });
    final visibleKeys =
        displayedPending.map((o) => '${o.task.id}/${o.key}').toSet();
    _cardAnchors.removeWhere((key, _) => !visibleKeys.contains(key));
    return Scaffold(
      appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(42) + 16,
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(shortDate(now),
                style: text.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(
                const [
                  'Monday',
                  'Tuesday',
                  'Wednesday',
                  'Thursday',
                  'Friday',
                  'Saturday',
                  'Sunday'
                ][now.weekday - 1],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    text.labelMedium?.copyWith(color: colors.onSurfaceVariant)),
          ]),
          actions: [
            IconButton(
                tooltip: 'Time slots',
                icon: const Icon(Icons.tune),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DaySlotsScreen()))),
            IconButton(
                tooltip: 'History',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StreakScreen())),
                icon: const Icon(Icons.calendar_month_outlined)),
            ScaleTransition(
                scale: _forestScale,
                child: IconButton.filledTonal(
                    key: _forestAnchor,
                    tooltip: 'Your forest',
                    icon: const Icon(Icons.park_outlined),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ForestScreen())))),
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final view in ['Today', 'Upcoming', 'All'])
                        ChoiceChip(
                            label: Text(view),
                            selected: _view == view,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _view = view)),
                    ]),
                    const SizedBox(height: 24),
                    if (_view == 'Today')
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('Tasks', style: text.titleLarge)),
                    if (displayedPending.isEmpty)
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
                    for (final occurrence in displayedPending)
                      _pendingCard(occurrence),
                    if (_view == 'Today' && upcomingToday.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Upcoming tasks', style: text.titleLarge),
                      const SizedBox(height: 12),
                      for (final occurrence in upcomingToday)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TaskCard(
                                key: ValueKey(
                                    'later-${occurrence.task.id}/${occurrence.key}'),
                                task: occurrence.task,
                                occurrence: occurrence)),
                    ],
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
    try {
      await ref.read(syncCoordinatorProvider)?.signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not finish signing out. Please try again.')));
    }
  }
}
