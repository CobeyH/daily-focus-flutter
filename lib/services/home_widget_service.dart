import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_timer.dart';
import '../models/day_slots.dart';
import '../models/task.dart';
import '../models/task_entry.dart';
import '../models/task_occurrence.dart';
import '../storage/app_storage.dart';
import '../utils/dates.dart';

const homeWidgetChannel = MethodChannel('daily_focus/home_widget');

Map<String, Object> buildHomeWidgetSnapshot({
  required List<Task> tasks,
  required List<TaskEntry> entries,
  required DateTime now,
  DaySlots slots = const DaySlots(),
  List<ActiveTimer> timers = const [],
}) {
  final pending = <TaskOccurrence>[];
  var upcoming = 0;
  var nextRefresh = calendarDay(now, 1);
  void boundary(DateTime time) {
    if (time.isAfter(now) && time.isBefore(nextRefresh)) nextRefresh = time;
  }

  for (final task in tasks) {
    final timer = timers.where((t) => t.taskId == task.id).firstOrNull;
    final occurrence = timer?.occurrenceKey != null
        ? TaskOccurrence(task, DateTime.parse(timer!.occurrenceKey!),
            entryFor(entries, task.id, timer.occurrenceKey!), now, slots)
        : currentOccurrence(task, entries, now, slots);
    if (occurrence == null || occurrence.done || occurrence.skipped) continue;
    boundary(occurrence.appearsAt);
    // Timed deadlines are inclusive; status changes just after that minute.
    boundary(
        task.timing.dueAt(occurrence.dueDate).add(const Duration(minutes: 1)));
    boundary(task.timing
        .closesAt(occurrence.dueDate)
        .add(const Duration(minutes: 1)));
    if (occurrence.visible) {
      pending.add(occurrence);
    } else if (now.isBefore(occurrence.appearsAt) &&
        dateKey(occurrence.appearsAt) == dateKey(now)) {
      upcoming++;
    }
  }
  int rank(TaskOccurrence occurrence) => switch (occurrence.status) {
        OccurrenceStatus.overdue => 0,
        OccurrenceStatus.grace => 1,
        OccurrenceStatus.due => 2,
        _ => 3,
      };
  pending.sort((a, b) {
    final status = rank(a).compareTo(rank(b));
    return status == 0 ? a.dueDate.compareTo(b.dueDate) : status;
  });
  final rows = <Map<String, Object>>[];
  // Keep the RemoteViews payload comfortably below Android's Binder limit.
  for (final occurrence in pending.take(100)) {
    final task = occurrence.task;
    final progress = occurrence.progress.clamp(0, occurrence.goal);
    final detail = switch (task.type) {
      TaskType.count => '$progress / ${occurrence.goal}',
      TaskType.minutes =>
        '${(progress / 60).floor()} / ${(occurrence.goal / 60).ceil()} min',
      TaskType.multiStep =>
        'Step ${progress + 1} / ${occurrence.goal} · ${occurrence.steps.elementAtOrNull(progress) ?? ''}',
    };
    rows.add({
      'name': task.name,
      'detail': '$detail · ${occurrence.label}',
      'compactDetail': detail,
      'progress': progress,
      'goal': occurrence.goal,
    });
  }
  return {
    'date': dateKey(now),
    'updatedAt': now.millisecondsSinceEpoch,
    'nextRefreshAt': nextRefresh.millisecondsSinceEpoch,
    'upcoming': upcoming,
    'total': pending.length,
    'empty': tasks.isEmpty ? 'No tasks yet' : 'All clear for now',
    'tasks': rows,
  };
}

class HomeWidgetService {
  final bool enabled;
  String? _lastPayload;
  HomeWidgetService({bool? enabled})
      : enabled = enabled ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  Future<void> publish(Map<String, Object>? snapshot) async {
    if (!enabled) return;
    final payload = jsonEncode(snapshot);
    if (payload == _lastPayload) return;
    try {
      await homeWidgetChannel.invokeMethod<void>('publish', {
        'signedIn': snapshot != null,
        'snapshot': snapshot == null ? null : payload,
      });
      _lastPayload = payload;
    } catch (error) {
      // A launcher problem must not prevent saving or completing a task.
      debugPrint('Could not update home-screen widget: $error');
    }
  }
}

// A short-lived, local-only background engine shares the app's scheduler. It
// never opens Firebase, requests permissions, changes task data, or runs the UI.
Future<void> refreshHomeWidgetBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final storage = AppStorage(prefs);
    final rawSlots = prefs.getString('day_slots_v1');
    var slots = const DaySlots();
    if (rawSlots != null) {
      try {
        slots = DaySlots.fromJson(
            Map<String, dynamic>.from(jsonDecode(rawSlots) as Map));
      } catch (_) {
        // Match the app's fallback when old time-slot settings are malformed.
      }
    }
    final snapshot = buildHomeWidgetSnapshot(
      tasks: storage.loadTasks(),
      entries: storage.loadEntries(),
      timers: storage.loadActiveTimers(),
      slots: slots,
      now: DateTime.now(),
    );
    await homeWidgetChannel.invokeMethod<void>(
        'backgroundSnapshot', jsonEncode(snapshot));
  } catch (error) {
    await homeWidgetChannel.invokeMethod<void>('backgroundError', '$error');
  }
}
