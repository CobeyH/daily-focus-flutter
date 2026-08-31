import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Increments progress for [task] on today's date key.
  Future<void> increment(Task task) async {
    final key = dateKey(todayOnly());
    final current = state.progressFor(task.id, key);
    final updated = TaskEntry(
      taskId: task.id,
      dateKey: key,
      progress: current + task.step,
    );
    await _upsertEntry(updated);
  }

  /// Decrements progress for [task] on today's date key (floor of 0).
  Future<void> decrement(Task task) async {
    final key = dateKey(todayOnly());
    final current = state.progressFor(task.id, key);
    final next = (current - task.step).clamp(0, 1 << 30);
    final updated = TaskEntry(taskId: task.id, dateKey: key, progress: next);
    await _upsertEntry(updated);
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

// ---- Streak / progress helpers --------------------------------------------

/// Returns the progress for [task] on today's date key.
final taskProgressProvider = Provider.family<int, Task>((ref, task) {
  final state = ref.watch(appControllerProvider);
  return state.progressFor(task.id, dateKey(todayOnly()));
});

/// Returns the current streak (consecutive days meeting the goal, ending
/// today or yesterday) for [task].
final taskStreakProvider = Provider.family<int, Task>((ref, task) {
  final state = ref.watch(appControllerProvider);
  final entries =
      state.entries.where((e) => e.taskId == task.id).toList(growable: false);

  final map = <String, int>{};
  for (final e in entries) {
    map[e.dateKey] = e.progress;
  }

  int streak = 0;
  final now = todayOnly();
  var cursor = now;

  // If today isn't complete yet, streak can still be continued from
  // yesterday, so start counting from the most recent completed day.
  if ((map[dateKey(cursor)] ?? 0) < task.goal) {
    cursor = now.subtract(const Duration(days: 1));
  }

  while (true) {
    final p = map[dateKey(cursor)] ?? 0;
    if (p < task.goal) break;
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
});

/// Whether [task]'s goal has been met today.
final taskDoneTodayProvider = Provider.family<bool, Task>((ref, task) {
  return ref.watch(taskProgressProvider(task)) >= task.goal;
});
