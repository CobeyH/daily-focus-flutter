import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/active_timer.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../utils/dates.dart';
import 'app_controller.dart';

/// State of all timed (countdown) tasks, running or paused.
///
/// A [DateTime] `now` is kept in state and bumped once per second by a
/// periodic [Timer] purely to drive UI rebuilds of the countdown labels. The
/// *authoritative* source of truth for remaining time is each [ActiveTimer]'s
/// [ActiveTimer.remaining] snapshot plus [ActiveTimer.updatedAt], so
/// correctness does not depend on the UI ticker — only the visual refresh
/// does.
class TimerState {
  final Map<String, ActiveTimer> timers;
  final DateTime now;

  const TimerState({required this.timers, required this.now});

  ActiveTimer? timerFor(String taskId) => timers[taskId];
}

class TimerController extends Notifier<TimerState> {
  Timer? _ticker;

  @override
  TimerState build() {
    final storage = ref.read(storageProvider);
    final loaded = storage.loadActiveTimers();
    final map = <String, ActiveTimer>{for (final t in loaded) t.taskId: t};
    _startTicker();
    ref.onDispose(() => _ticker?.cancel());
    // Immediately process any timers that elapsed while the app was killed.
    Future.microtask(_processElapsed);
    return TimerState(timers: map, now: DateTime.now());
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ref.mounted) {
        state = TimerState(timers: state.timers, now: DateTime.now());
      }
      _processElapsed();
    });
  }

  NotificationService get _notifier => ref.read(notificationServiceProvider);

  /// A stable, per-task notification id derived from the task id's hash.
  int _notificationIdFor(String taskId) =>
      1000 + (taskId.hashCode & 0x7fffffff) % 900000;

  /// Starts (or resumes) the countdown for a timed [task].
  ///
  /// If no timer exists, a new countdown is started from the task's daily
  /// goal. If a paused timer exists, it resumes from where it left off,
  /// retaining the progress already made.
  Future<void> start(Task task) async {
    if (task.type != TaskType.minutes) return;
    final now = DateTime.now();
    final existing = state.timers[task.id];
    final timer = existing?.resume(now) ?? ActiveTimer.start(task, now: now);

    final timers = {...state.timers, task.id: timer};
    state = TimerState(timers: timers, now: DateTime.now());
    await _persist(timers);

    await _notifier.scheduleTaskComplete(
      notificationId: _notificationIdFor(task.id),
      taskName: task.name,
      when: now.add(timer.remainingAt(now)),
    );
  }

  /// Stops (pauses) the countdown for [task], retaining the progress made so
  /// far so it can be resumed later.
  Future<void> cancel(Task task) async {
    final existing = state.timers[task.id];
    if (existing == null) return;
    final now = DateTime.now();
    final paused = existing.pause(now);

    final timers = {...state.timers, task.id: paused};
    state = TimerState(timers: timers, now: DateTime.now());
    await _persist(timers);
    await _notifier.cancel(_notificationIdFor(task.id));
  }

  /// Callable from a lifecycle observer on resume to catch up any timer that
  /// finished while the app was suspended (defense in depth beyond the
  /// scheduled notification).
  Future<void> checkForElapsed() async {
    await _processElapsed();
  }

  /// Credits any running timer whose remaining time has reached zero.
  Future<void> _processElapsed() async {
    final now = DateTime.now();
    final elapsed = state.timers.values
        .where((t) => t.isElapsed(now))
        .toList(growable: false);
    if (elapsed.isEmpty) return;

    final timers = {...state.timers};
    for (final t in elapsed) {
      timers.remove(t.taskId);
      await _completeTimedTask(t);
    }
    if (ref.mounted) {
      state = TimerState(timers: timers, now: DateTime.now());
    }
    await _persist(timers);
  }

  /// Credits a completed timer to the task on the day it was *started*.
  Future<void> _completeTimedTask(ActiveTimer timer) async {
    final tasks = ref.read(appControllerProvider).tasks;
    Task? found;
    for (final t in tasks) {
      if (t.id == timer.taskId) {
        found = t;
        break;
      }
    }
    if (found == null) return;

    await ref
        .read(appControllerProvider.notifier)
        .recordTimedCompletion(found, dateKey(timer.startedAt));
  }

  Future<void> _persist(Map<String, ActiveTimer> timers) async {
    await ref
        .read(storageProvider)
        .saveActiveTimers(timers.values.toList(growable: false));
  }
}

final timerControllerProvider =
    NotifierProvider<TimerController, TimerState>(TimerController.new);

/// The remaining duration for a [task] with an active (running or paused)
/// timer, or `null` if the task has no timer.
final taskRemainingProvider = Provider.family<Duration?, Task>((ref, task) {
  final state = ref.watch(timerControllerProvider);
  final t = state.timerFor(task.id);
  if (t == null) return null;
  return t.remainingAt(state.now);
});
