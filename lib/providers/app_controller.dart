import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule.dart';
import '../models/task.dart';
import '../models/task_entry.dart';
import '../services/notification_service.dart';
import '../storage/app_storage.dart';
import '../utils/dates.dart';
import 'timer_controller.dart';

/// Provides the pre-loaded [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
      'sharedPreferencesProvider must be overridden in main()');
});

/// Provides the persistence layer.
final storageProvider = Provider<AppStorage>((ref) {
  return AppStorage(ref.watch(sharedPreferencesProvider));
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

  @override
  AppState build() {
    return AppState(
      tasks: _storage.loadTasks(),
      entries: _storage.loadEntries(),
    );
  }

  // ---- Task CRUD -----------------------------------------------------------

  Future<void> addTask(Task task) async {
    final tasks = [...state.tasks, task];
    state = AppState(tasks: tasks, entries: state.entries);
    await _storage.saveTasks(tasks);
  }

  Future<void> updateTask(Task updated) async {
    final tasks = state.tasks
        .map((t) => t.id == updated.id ? updated : t)
        .toList(growable: false);
    state = AppState(tasks: tasks, entries: state.entries);
    await _storage.saveTasks(tasks);
    // If the task has an active countdown and its definition changed,
    // reconcile the timer so the displayed remaining time matches the new
    // goal instead of the old one.
    await ref.read(timerControllerProvider.notifier).reconcileForTask(updated);
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
  }

  // ---- Daily progress ------------------------------------------------------

  /// Increments progress for [task] on today's date key. For tasks with a
  /// recurring schedule, this counts toward the goal on the current due
  /// date — not toward a different cycle.
  ///
  /// If the task is overdue (had a missed due date on or before today),
  /// that missed date is also credited so the overdue state clears. This
  /// lets a user "catch up" by tapping once today.
  ///
  /// [now] is the wall-clock "today" used for date-key selection. It
  /// defaults to the real current day but can be injected for tests.
  Future<void> increment(Task task, {DateTime? now}) async {
    final today = _todayOf(now);
    final todayKey = dateKey(today);
    final currentToday = state.progressFor(task.id, todayKey);
    final updatedToday = TaskEntry(
      taskId: task.id,
      dateKey: todayKey,
      progress: currentToday + task.step,
    );
    await _upsertEntry(updatedToday);

    // If the task is overdue and the missed date is strictly before today,
    // also credit that date so the overdue state clears. If the missed date
    // *is* today, today's increment already handles it.
    final missed = firstMissedDueDate(task, today, state);
    if (missed != null) {
      final m = DateTime(missed.year, missed.month, missed.day);
      if (m.isBefore(today)) {
        final missedKey = dateKey(m);
        final currentMissed = state.progressFor(task.id, missedKey);
        final updatedMissed = TaskEntry(
          taskId: task.id,
          dateKey: missedKey,
          progress: currentMissed + task.step,
        );
        await _upsertEntry(updatedMissed);
      }
    }
  }

  /// Decrements progress for [task] on today's date key (floor of 0).
  ///
  /// Mirrors [increment]: if the task is overdue, the most recent missed
  /// date is also decremented (if it has progress to remove). This keeps
  /// the overdue state in sync with the user's intent when they undo a tap.
  Future<void> decrement(Task task, {DateTime? now}) async {
    final today = _todayOf(now);
    final todayKey = dateKey(today);
    final currentToday = state.progressFor(task.id, todayKey);
    final nextToday = (currentToday - task.step).clamp(0, 1 << 30);
    await _upsertEntry(
        TaskEntry(taskId: task.id, dateKey: todayKey, progress: nextToday));

    final missed = firstMissedDueDate(task, today, state);
    if (missed != null) {
      final m = DateTime(missed.year, missed.month, missed.day);
      if (m.isBefore(today)) {
        final missedKey = dateKey(m);
        final currentMissed = state.progressFor(task.id, missedKey);
        if (currentMissed > 0) {
          final nextMissed = (currentMissed - task.step).clamp(0, 1 << 30);
          await _upsertEntry(TaskEntry(
              taskId: task.id, dateKey: missedKey, progress: nextMissed));
        }
      }
    }
  }

  /// Returns the date-only [DateTime] for [now] (defaults to real today).
  static DateTime _todayOf(DateTime? now) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Records the completion of a timed (minutes) task.
  ///
  /// Sets progress to [task].goal (the full duration) on the given day,
  /// overwriting any partial value. This runs when a running countdown
  /// finishes — not on each tap.
  Future<void> recordTimedCompletion(Task task, String dayKey) async {
    final updated =
        TaskEntry(taskId: task.id, dateKey: dayKey, progress: task.goal);
    await _upsertEntry(updated);
  }

  /// Marks [task]'s goal as met for today in one step, regardless of the
  /// current progress ("long-press to complete").
  ///
  /// * For occurrence tasks, today's entry is set to the goal.
  /// * For timed tasks, today's entry is set to the full duration and any
  ///   running/paused countdown is cleared (the scheduled notification is
  ///   cancelled) since the task is now complete.
  /// * If the task was overdue, the most recent missed due date is also fully
  ///   credited so the overdue state clears.
  ///
  /// This is a no-op if the goal is already met for today.
  Future<void> markComplete(Task task, {DateTime? now}) async {
    final today = _todayOf(now);
    final todayKey = dateKey(today);
    final target = task.goal;

    if (state.progressFor(task.id, todayKey) < target) {
      await _upsertEntry(
          TaskEntry(taskId: task.id, dateKey: todayKey, progress: target));
    }

    // If the task is overdue (a non-daily schedule with a missed due date
    // strictly before today), fully credit the most recent missed due date so
    // the overdue badge clears — mirroring increment()'s catch-up behaviour.
    //
    // This is intentionally guarded by [isTaskOverdueOn]: a daily task whose
    // previous day is merely unfilled must NOT be backfilled, or completing
    // today would also credit "yesterday" and inflate the streak by 2.
    if (isTaskOverdueOn(task, today, state)) {
      final missed = firstMissedDueDate(task, today, state);
      if (missed != null) {
        final m = DateTime(missed.year, missed.month, missed.day);
        if (m.isBefore(today) &&
            state.progressFor(task.id, dateKey(m)) < target) {
          await _upsertEntry(TaskEntry(
              taskId: task.id, dateKey: dateKey(m), progress: target));
        }
      }
    }

    // For timed tasks, completing the goal means the countdown is moot — clear
    // it and cancel its scheduled "task complete" notification.
    if (task.type == TaskType.minutes) {
      await ref.read(timerControllerProvider.notifier).clearFor(task.id);
    }
  }

  /// Resets [task]'s progress for today back to zero ("long-press a completed
  /// task to reset it").
  ///
  /// * For occurrence tasks, today's entry is removed/zeroed (and any overdue
  ///   missed date credited by [markComplete] is also reset if it was set in
  ///   the same session — see below).
  /// * For timed tasks, today's entry is zeroed and any paused running timer
  ///   is cleared and its notification cancelled.
  ///
  /// Only today's progress is touched; earlier history (which drives streaks)
  /// is left intact.
  Future<void> reset(Task task, {DateTime? now}) async {
    final today = _todayOf(now);
    final todayKey = dateKey(today);

    if (state.progressFor(task.id, todayKey) > 0) {
      await _upsertEntry(
          TaskEntry(taskId: task.id, dateKey: todayKey, progress: 0));
    }

    if (task.type == TaskType.minutes) {
      await ref.read(timerControllerProvider.notifier).clearFor(task.id);
    }
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
  }
}

final appControllerProvider =
    NotifierProvider<AppController, AppState>(AppController.new);

/// Convenience: the list of tasks.
final tasksProvider = Provider<List<Task>>((ref) {
  return ref.watch(appControllerProvider).tasks;
});

// ---- Schedule / due-date helpers ------------------------------------------

/// Whether [task] is due on [day]. Pure schedule check (no overdue).
bool isTaskDueOn(Task task, DateTime day) => task.schedule.isDueOn(day);

/// Returns the previous due date strictly before [d] under [schedule], or
/// `null` if none exists.
DateTime? _previousDueDate(Schedule schedule, DateTime d) {
  final before =
      DateTime(d.year, d.month, d.day).subtract(const Duration(days: 1));
  return schedule.lastDueDateOnOrBefore(before);
}

/// Whether [task] has at least one missed due date strictly before [day].
///
/// A task is "overdue" only if:
///
/// * It has a non-daily schedule (a daily task that hasn't been met today is
///   simply in-progress, not overdue — that would show as a confusing
///   "Overdue" badge every morning).
/// * And one of its due dates strictly before today was missed.
///
/// Today being a due date that hasn't been met yet is not overdue — that's
/// just the task being due today. The user must have had a chance to do it
/// yesterday or earlier for it to be "overdue".
bool isTaskOverdueOn(Task task, DateTime day, AppState state) {
  if (task.schedule is ScheduleDaily) return false;
  final today = DateTime(day.year, day.month, day.day);
  final cursor = task.schedule.lastDueDateOnOrBefore(today);
  if (cursor == null) return false;
  var d = cursor;
  var guard = 0;
  while (guard++ < 366 * 5) {
    if (state.progressFor(task.id, dateKey(d)) < task.goal) {
      return d.isBefore(today);
    }
    final prev = _previousDueDate(task.schedule, d);
    if (prev == null) break;
    d = prev;
  }
  return false;
}

/// Returns the oldest unmet due date on or before [day] for [task], or
/// `null` if all recent due dates are met. Used to display e.g.
/// "Overdue since Monday" on the task card.
DateTime? firstMissedDueDate(Task task, DateTime day, AppState state) {
  final today = DateTime(day.year, day.month, day.day);
  var d = task.schedule.lastDueDateOnOrBefore(today);
  var guard = 0;
  while (d != null && guard++ < 366 * 5) {
    if (state.progressFor(task.id, dateKey(d)) < task.goal) return d;
    final prev = _previousDueDate(task.schedule, d);
    d = prev;
  }
  return null;
}

/// Today's tasks sorted with overdue first, then due-today, then everything
/// else (still returned so the UI can offer a "show all" affordance).
final tasksForTodayProvider = Provider<List<Task>>((ref) {
  final state = ref.watch(appControllerProvider);
  final today = todayOnly();
  final tasks = [...state.tasks];
  int rank(Task t) {
    if (isTaskOverdueOn(t, today, state)) return 0;
    if (isTaskDueOn(t, today)) return 1;
    return 2;
  }

  tasks.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return a.createdAt.compareTo(b.createdAt);
  });
  return tasks;
});

// ---- Streak / progress helpers --------------------------------------------

/// Returns the progress for [task] on today's date key.
final taskProgressProvider = Provider.family<int, Task>((ref, task) {
  final state = ref.watch(appControllerProvider);
  return state.progressFor(task.id, dateKey(todayOnly()));
});

/// Whether [task]'s goal has been met today.
final taskDoneTodayProvider = Provider.family<bool, Task>((ref, task) {
  return ref.watch(taskProgressProvider(task)) >= task.goal;
});

/// Whether [task] is currently overdue (had an unmet due date on or before
/// today).
final taskOverdueProvider = Provider.family<bool, Task>((ref, task) {
  final state = ref.watch(appControllerProvider);
  return isTaskOverdueOn(task, todayOnly(), state);
});

/// The first (oldest) unmet due date on or before today, or `null` if the
/// task is up to date. Used to render a more helpful "Overdue since …"
/// affordance.
final taskMissedDueDateProvider = Provider.family<DateTime?, Task>((ref, task) {
  final state = ref.watch(appControllerProvider);
  return firstMissedDueDate(task, todayOnly(), state);
});

/// The most recent due date on or before today, regardless of whether it was
/// met. For [ScheduleDaily] this is today.
final taskLastDueDateProvider = Provider.family<DateTime?, Task>((ref, task) {
  return task.schedule.lastDueDateOnOrBefore(todayOnly());
});

/// Returns the current streak (consecutive due days meeting the goal, going
/// backwards from the most recent due day) for [task].
///
/// A streak survives a missed-then-completed due date: if the most recent
/// due day is unmet, the streak starts counting from the previous met due
/// day (so completing an overdue task today still preserves any prior
/// streak).
final taskStreakProvider = Provider.family<int, Task>((ref, task) {
  final state = ref.watch(appControllerProvider);
  final entries =
      state.entries.where((e) => e.taskId == task.id).toList(growable: false);

  final map = <String, int>{};
  for (final e in entries) {
    map[e.dateKey] = e.progress;
  }

  DateTime? maybeCursor = task.schedule.lastDueDateOnOrBefore(todayOnly());
  // If the most recent due day isn't met, skip it — the streak can continue
  // from the previous met due day (so completing an overdue task today
  // preserves any prior streak).
  if (maybeCursor != null && (map[dateKey(maybeCursor)] ?? 0) < task.goal) {
    maybeCursor = _previousDueDate(task.schedule, maybeCursor);
  }
  DateTime? cursor = maybeCursor;
  if (cursor == null) return 0;

  int streak = 0;
  while (true) {
    final today = cursor;
    if (today == null) break;
    final p = map[dateKey(today)] ?? 0;
    if (p < task.goal) break;
    streak++;
    cursor = _previousDueDate(task.schedule, today);
  }
  return streak;
});

/// The longest consecutive streak ever achieved for [task], across all time.
/// Unlike [taskStreakProvider] (which is the current streak anchored at today),
/// this scans every due date from the task's creation to today and returns the
/// maximum run of consecutive met goal days.
final taskBestStreakProvider = Provider.family<int, Task>((ref, task) {
  final state = ref.watch(appControllerProvider);
  final map = <String, int>{};
  for (final e in state.entries) {
    if (e.taskId == task.id) map[e.dateKey] = e.progress;
  }

  final today = todayOnly();
  final first =
      DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);

  // Walk every due date from the task's creation through today, tallying a
  // running streak that we reset when a due goal is missed. Only due dates
  // are considered so off days never break an interval/weekly cadence.
  DateTime? cursor = task.schedule.lastDueDateOnOrBefore(today);
  if (cursor == null) return 0;
  final last = cursor;

  int current = 0;
  int best = 0;
  DateTime? d = task.schedule.firstDueDateFrom(first);
  var guard = 0;
  while (d != null && guard++ < 366 * 5) {
    if (!d.isAfter(last)) {
      if ((map[dateKey(d)] ?? 0) >= task.goal) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    d = task.schedule.nextDueDateAfter(d);
  }
  return best;
});
