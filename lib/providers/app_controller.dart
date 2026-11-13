import 'day_slots_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/task_entry.dart';
import '../models/task_occurrence.dart';
import 'clock_provider.dart';
import '../services/notification_service.dart';
import '../storage/app_storage.dart';
import '../storage/remote_storage.dart';
import '../storage/sync_coordinator.dart';
import '../utils/dates.dart';
import 'timer_controller.dart';

/// Provides the pre-loaded [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'sharedPreferencesProvider must be overridden in main()');
});

final cloudInitializationErrorProvider = Provider<String?>((ref) => null);

/// Provides the persistence layer.
final storageProvider = Provider<AppStorage>((ref) {
  return AppStorage(ref.watch(sharedPreferencesProvider));
});

/// The Firebase client is initialized in main and injected here. A null backend
/// allows local-only widget tests without connecting to Firebase.
final remoteStorageProvider = Provider<RemoteStorage?>((ref) => null);

/// Coordinates local <-> remote sync. Null when a backend isn't configured (i.e.
/// pure local mode).
final syncCoordinatorProvider = Provider<SyncCoordinator?>((ref) {
  final remote = ref.watch(remoteStorageProvider);
  if (remote == null) return null;
  final coordinator = SyncCoordinator(
    ref.watch(storageProvider),
    remote,
    onLocalChanged: () async {
      // The remote merge rewrote the local store; refresh the in-memory state.
      ref.invalidate(appControllerProvider);
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Whether the user is signed in.
///
/// When a backend isn't configured, the app is effectively "signed in" (local
/// mode) so the home screen shows. When it is configured, this reflects the
/// realtime auth state: `null`/`false` → show the auth gate, `true` → home.
final authStateProvider = StreamProvider<bool?>((ref) {
  final coordinator = ref.watch(syncCoordinatorProvider);
  if (coordinator == null) {
    // Local-only mode: always treat as signed in so we skip the auth screen.
    return Stream.value(true);
  }
  return coordinator.observeAuthState();
});

/// Provides the notification service singleton.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// The immutable state of the app: the list of tasks and the full history of
/// daily entries.
class AppState {
  final List<Task> tasks;
  final List<TaskEntry> entries;

  const AppState({required this.tasks, required this.entries});

  /// Progress for [task] on the given [key] (defaults to 0).
  int progressFor(String taskId, String key) {
    for (final e in entries) {
      if (e.taskId == taskId && e.dateKey == key) return e.progress;
    }
    return 0;
  }
}

class AppController extends Notifier<AppState> {
  AppStorage get _storage => ref.read(storageProvider);

  /// Push the current local state to the cloud (best-effort, no-op offline).
  Future<void> _pushLocal() async {
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator == null) return;
    try {
      await coordinator.pushLocal();
    } catch (e) {
      // Offline or transient failure — the write still succeeded locally and
      // will be pushed on the next successful sync.
    }
  }

  @override
  AppState build() {
    final state = AppState(
      tasks: _storage.loadTasks(),
      entries: _storage.loadEntries(),
    );
    _kickOffSync();
    return state;
  }

  /// Best-effort initial sync: if the user already has a session, pull remote
  /// state in and start observing remote changes. Runs independently so the UI
  /// isn't blocked. If there's no session yet, the auth screen drives sign-in.
  void _kickOffSync() {
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator == null) return;
    Future.microtask(() async {
      try {
        await coordinator.syncIfSignedIn();
      } catch (e) {
        // Offline at startup — fall back to local-only until the next sync.
      }
    });
  }

  // ---- Task CRUD -----------------------------------------------------------

  Future<void> addTask(Task task) async {
    final tasks = [...state.tasks, task];
    state = AppState(tasks: tasks, entries: state.entries);
    await _storage.saveTasks(tasks);
    await _pushLocal();
  }

  Future<void> updateTask(Task updated) async {
    final previous =
        state.tasks.where((task) => task.id == updated.id).firstOrNull;
    updated =
        updated.copyWith(updatedAt: ref.read(timeSourceProvider)().toUtc());
    final tasks = state.tasks
        .map((t) => t.id == updated.id ? updated : t)
        .toList(growable: false);
    state = AppState(tasks: tasks, entries: state.entries);
    await _storage.saveTasks(tasks);
    // If the task has an active countdown and its definition changed,
    // reconcile the timer so the displayed remaining time matches the new
    // goal instead of the old one.
    if (previous?.type != updated.type) {
      await ref.read(timerControllerProvider.notifier).clearFor(updated.id);
    } else if (previous?.goal != updated.goal) {
      await ref
          .read(timerControllerProvider.notifier)
          .reconcileForTask(updated);
    }
    await _pushLocal();
  }

  Future<void> deleteTask(String id) async {
    final tasks = state.tasks.where((t) => t.id != id).toList(growable: false);
    final entries =
        state.entries.where((e) => e.taskId != id).toList(growable: false);
    state = AppState(tasks: tasks, entries: entries);
    await _storage.saveTasks(tasks);
    await _storage.saveEntries(entries);
    // Cancel any running/paused countdown and its scheduled notification
    // so a delete doesn't leave an orphan alarm pointing at a gone task.
    await ref.read(timerControllerProvider.notifier).clearFor(id);
    // Remove the task (and its cascaded entries) from the cloud too.
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator != null) {
      try {
        await coordinator.deleteTask(id);
      } catch (_) {}
    }
  }

  // Progress is written to exactly one scheduled occurrence.
  Future<void> increment(Task task,
      {DateTime? now, String? occurrenceKey}) async {
    final DateTime time = now ?? ref.read(timeSourceProvider)();
    final occurrence = _target(task, time, occurrenceKey);
    if (occurrence == null || !occurrence.visible || occurrence.done) return;
    await _record(task, occurrence,
        (occurrence.progress + task.step).clamp(0, task.goal), time);
  }

  Future<void> decrement(Task task,
      {DateTime? now, String? occurrenceKey}) async {
    final DateTime time = now ?? ref.read(timeSourceProvider)();
    final occurrence = _target(task, time, occurrenceKey);
    if (occurrence == null) return;
    await _record(task, occurrence,
        (occurrence.progress - task.step).clamp(0, task.goal), time);
  }

  Future<void> markComplete(Task task,
      {DateTime? now, String? occurrenceKey}) async {
    final DateTime time = now ?? ref.read(timeSourceProvider)();
    final occurrence = _target(task, time, occurrenceKey);
    if (occurrence == null || !occurrence.visible || occurrence.done) return;
    await _record(task, occurrence, task.goal, time);
    if (task.type == TaskType.minutes) {
      await ref.read(timerControllerProvider.notifier).clearFor(task.id);
    }
  }

  Future<void> recordTimedCompletion(Task task, String dueKey,
      {DateTime? completedAt}) async {
    final time = completedAt ?? DateTime.now();
    final occurrence = _target(task, time, dueKey);
    if (occurrence == null || occurrence.done || occurrence.skipped) return;
    await _record(task, occurrence, task.goal, time);
  }

  Future<void> reset(Task task, {DateTime? now, String? occurrenceKey}) async {
    final DateTime time = now ?? ref.read(timeSourceProvider)();
    final occurrence = _target(task, time, occurrenceKey);
    if (occurrence == null) return;
    await _record(task, occurrence, 0, time);
    if (task.type == TaskType.minutes) {
      await ref.read(timerControllerProvider.notifier).clearFor(task.id);
    }
  }

  Future<void> skip(Task task,
      {DateTime? now, required String occurrenceKey}) async {
    final DateTime time = now ?? ref.read(timeSourceProvider)();
    final occurrence = _target(task, time, occurrenceKey);
    if (occurrence == null) return;
    await _record(task, occurrence, 0, time, skipped: true);
    if (task.type == TaskType.minutes) {
      await ref.read(timerControllerProvider.notifier).clearFor(task.id);
    }
  }

  Future<void> undoCompletion(Task task,
      {required String occurrenceKey}) async {
    final time = ref.read(timeSourceProvider)();
    final occurrence = _target(task, time, occurrenceKey);
    if (occurrence == null) return;
    await _record(
        task, occurrence, occurrence.entry?.previousProgress ?? 0, time);
  }

  TaskOccurrence? _target(Task task, DateTime now, String? key) {
    if (key == null) {
      return currentOccurrence(
          task, state.entries, now, ref.read(daySlotsProvider));
    }
    final due = DateTime.tryParse(key);
    if (due == null) return null;
    return TaskOccurrence(task, dateOnly(due),
        entryFor(state.entries, task.id, key), now, ref.read(daySlotsProvider));
  }

  Future<void> _record(
      Task task, TaskOccurrence occurrence, int progress, DateTime time,
      {bool skipped = false}) async {
    final finished = progress >= task.goal;
    final timing = !finished
        ? null
        : task.timing.pastGrace(occurrence.dueDate, time)
            ? 'late'
            : task.timing.pastDue(occurrence.dueDate, time)
                ? 'grace'
                : 'onTime';
    final previousUpdate = occurrence.entry?.updatedAt;
    var updatedAt = time.toUtc();
    if (previousUpdate != null && !updatedAt.isAfter(previousUpdate)) {
      updatedAt = previousUpdate.add(const Duration(microseconds: 1));
    }
    await _upsertEntry(TaskEntry(
        taskId: task.id,
        dateKey: occurrence.key,
        progress: progress,
        updatedAt: updatedAt,
        completedAt: finished || skipped ? time.toUtc() : null,
        completionTiming: timing,
        completedGoal: finished ? task.goal : null,
        previousProgress: finished || skipped ? occurrence.progress : null,
        skipped: skipped));
  }

  Future<void> _upsertEntry(TaskEntry entry) async {
    final entries = [...state.entries];
    final idx = entries.indexWhere(
        (e) => e.taskId == entry.taskId && e.dateKey == entry.dateKey);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    state = AppState(tasks: state.tasks, entries: entries);
    await _storage.saveEntries(entries);
    await _pushLocal();
  }
}

final appControllerProvider =
    NotifierProvider<AppController, AppState>(AppController.new);

/// Convenience: the list of tasks.
final tasksProvider = Provider<List<Task>>((ref) {
  return ref.watch(appControllerProvider).tasks;
});

// ---- Occurrence views -----------------------------------------------------
bool isTaskDueOn(Task task, DateTime day) => task.schedule.isDueOn(day);
bool isTaskOverdueOn(Task task, DateTime day, AppState state) =>
    currentOccurrence(task, state.entries, day)?.status ==
    OccurrenceStatus.overdue;
DateTime? firstMissedDueDate(Task task, DateTime day, AppState state) {
  final occurrence = currentOccurrence(task, state.entries, day);
  return occurrence?.status == OccurrenceStatus.overdue
      ? occurrence?.dueDate
      : null;
}

final taskOccurrenceProvider = Provider.family<TaskOccurrence?, Task>(
    (ref, task) => currentOccurrence(
        task,
        ref.watch(appControllerProvider).entries,
        ref.watch(clockProvider),
        ref.watch(daySlotsProvider)));

final tasksForTodayProvider =
    Provider<List<Task>>((ref) => ref.watch(tasksProvider));
final taskProgressProvider = Provider.family<int, Task>(
    (ref, task) => ref.watch(taskOccurrenceProvider(task))?.progress ?? 0);
final taskDoneTodayProvider = Provider.family<bool, Task>(
    (ref, task) => ref.watch(taskOccurrenceProvider(task))?.done ?? false);
final taskOverdueProvider = Provider.family<bool, Task>((ref, task) =>
    ref.watch(taskOccurrenceProvider(task))?.status ==
    OccurrenceStatus.overdue);
final taskMissedDueDateProvider = Provider.family<DateTime?, Task>(
    (ref, task) => ref.watch(taskOverdueProvider(task))
        ? ref.watch(taskOccurrenceProvider(task))?.dueDate
        : null);
final taskLastDueDateProvider = Provider.family<DateTime?, Task>(
    (ref, task) => ref.watch(taskOccurrenceProvider(task))?.dueDate);

/// Streaks count successful scheduled occurrences, including completion in grace.
/// Open windows do not break a streak; explicit skips preserve it without adding.
int currentStreak(Task task, Iterable<TaskEntry> entries, DateTime now) {
  var day = task.schedule.lastDueDateOnOrBefore(now);
  var streak = 0;
  final start = scheduleStart(task);
  while (day != null && !day.isBefore(start)) {
    final entry = entryFor(entries, task.id, dateKey(day));
    if (entry?.countsForStreak(task.goal) ?? false) {
      streak++;
    } else if (!(entry?.skipped ?? false)) {
      if (task.timing.pastGrace(day, now)) break;
    }
    day = task.schedule.lastDueDateOnOrBefore(calendarDay(day, -1));
  }
  return streak;
}

final taskStreakProvider = Provider.family<int, Task>((ref, task) =>
    currentStreak(task, ref.watch(appControllerProvider).entries,
        ref.watch(clockProvider)));
final taskBestStreakProvider = Provider.family<int, Task>((ref, task) {
  final entries = ref.watch(appControllerProvider).entries;
  final now = ref.watch(clockProvider);
  var day = task.schedule.firstDueDateFrom(scheduleStart(task));
  var current = 0, best = 0;
  while (day != null && !day.isAfter(now)) {
    final entry = entryFor(entries, task.id, dateKey(day));
    if (entry?.countsForStreak(task.goal) ?? false) {
      current++;
      if (current > best) best = current;
    } else if (!(entry?.skipped ?? false) && task.timing.pastGrace(day, now)) {
      current = 0;
    }
    day = task.schedule.nextDueDateAfter(day);
  }
  return best;
});
