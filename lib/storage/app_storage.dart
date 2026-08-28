import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_timer.dart';
import '../models/task.dart';
import '../models/task_entry.dart';

/// Thin persistence layer over [SharedPreferences].
///
/// Data is stored as JSON strings. All reads are synchronous because
/// [SharedPreferences] is loaded before `runApp` (see `main.dart`).
class AppStorage {
  static const _tasksKey = 'tasks_v1';
  static const _entriesKey = 'entries_v1';
  static const _activeTimersKey = 'active_timers_v1';

  final SharedPreferences _prefs;

  AppStorage(this._prefs);

  List<Task> loadTasks() {
    final raw = _prefs.getString(_tasksKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final data =
        jsonEncode(tasks.map((t) => t.toJson()).toList(growable: false));
    await _prefs.setString(_tasksKey, data);
  }

  List<TaskEntry> loadEntries() {
    final raw = _prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TaskEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveEntries(List<TaskEntry> entries) async {
    final data =
        jsonEncode(entries.map((e) => e.toJson()).toList(growable: false));
    await _prefs.setString(_entriesKey, data);
  }

  List<ActiveTimer> loadActiveTimers() {
    final raw = _prefs.getString(_activeTimersKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ActiveTimer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveActiveTimers(List<ActiveTimer> timers) async {
    final data =
        jsonEncode(timers.map((t) => t.toJson()).toList(growable: false));
    await _prefs.setString(_activeTimersKey, data);
  }
}
