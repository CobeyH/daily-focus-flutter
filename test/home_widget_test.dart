import 'dart:async';
import 'dart:convert';

import 'package:daily_focus/models/day_slots.dart';
import 'package:daily_focus/models/schedule.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_entry.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/providers/day_slots_provider.dart';
import 'package:daily_focus/providers/home_widget_provider.dart';
import 'package:daily_focus/services/home_widget_service.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Task task(String id,
        {TaskTiming timing = const TaskTiming(),
        Schedule schedule = const ScheduleDaily(),
        TaskType type = TaskType.count,
        int goal = 3,
        List<String> steps = const []}) =>
    Task(
        id: id,
        name: id,
        type: type,
        goal: goal,
        steps: steps,
        step: 1,
        color: 0,
        icon: 0,
        createdAt: DateTime(2026, 11, 1),
        timing: timing,
        schedule: schedule);

List<Map<String, Object>> rows(Map<String, Object> snapshot) =>
    snapshot['tasks'] as List<Map<String, Object>>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(homeWidgetChannel, null));

  test('current tasks respect buckets, custom starts, and morning carryover',
      () {
    final tasks = [
      task('morning', timing: const TaskTiming(slot: DaySlot.morning)),
      task('afternoon', timing: const TaskTiming(slot: DaySlot.afternoon)),
      task('evening', timing: const TaskTiming(slot: DaySlot.evening)),
    ];
    final snapshot = buildHomeWidgetSnapshot(
        tasks: tasks,
        entries: [],
        now: DateTime(2026, 11, 16, 14),
        slots: const DaySlots(morning: 480, afternoon: 780, evening: 1140));
    expect(rows(snapshot).map((r) => r['name']), ['morning', 'afternoon']);
    expect(snapshot['upcoming'], 1);
    expect(snapshot['nextRefreshAt'],
        DateTime(2026, 11, 16, 19).millisecondsSinceEpoch);
    final evening = buildHomeWidgetSnapshot(
        tasks: tasks,
        entries: [],
        now: DateTime(2026, 11, 16, 19),
        slots: const DaySlots(morning: 480, afternoon: 780, evening: 1140));
    expect(rows(evening), hasLength(3));
    expect(evening['upcoming'], 0);
  });

  test('completed and skipped tasks disappear; undo restores progress', () {
    final tasks = [task('done'), task('skipped'), task('partial')];
    final entries = [
      const TaskEntry(taskId: 'done', dateKey: '2026-11-16', progress: 3),
      const TaskEntry(
          taskId: 'skipped', dateKey: '2026-11-16', progress: 0, skipped: true),
      const TaskEntry(taskId: 'partial', dateKey: '2026-11-16', progress: 1),
    ];
    final snapshot = buildHomeWidgetSnapshot(
        tasks: tasks, entries: entries, now: DateTime(2026, 11, 16, 14));
    expect(rows(snapshot).map((r) => r['name']), ['partial']);
    expect(rows(snapshot).single['detail'], contains('1 / 3'));
    final undone = buildHomeWidgetSnapshot(
        tasks: tasks,
        entries: entries.skip(1).toList(),
        now: DateTime(2026, 11, 16, 14));
    expect(rows(undone).map((r) => r['name']), ['done', 'partial']);
  });

  test(
      'weekly grace, early visibility, and expired one-off windows match the app',
      () {
    final snapshot = buildHomeWidgetSnapshot(tasks: [
      task('weekly',
          schedule: ScheduleWeekly(
              intervalWeeks: 1,
              daysOfWeek: const [DateTime.friday],
              firstDueDate: DateTime(2026, 11, 6)),
          timing: const TaskTiming(graceDays: 3)),
      task('early',
          schedule: ScheduleOnce(dueDate: DateTime(2026, 11, 18)),
          timing: const TaskTiming(showDaysBefore: 2)),
      task('expired',
          schedule: ScheduleOnce(dueDate: DateTime(2026, 11, 14)),
          timing: const TaskTiming(visibleDaysAfter: 1)),
      task('future', schedule: ScheduleOnce(dueDate: DateTime(2026, 11, 18))),
    ], entries: [], now: DateTime(2026, 11, 16, 14));
    expect(rows(snapshot).map((r) => r['name']), ['weekly', 'early']);
    expect(rows(snapshot).first['detail'], contains('Within grace'));
    expect(rows(snapshot).last['detail'], contains('Available early'));
    expect(snapshot['upcoming'], 0);
  });

  test('rollover refreshes daily tasks without reviving completed one-offs',
      () {
    final tasks = [
      task('daily'),
      task('once', schedule: ScheduleOnce(dueDate: DateTime(2026, 11, 16)))
    ];
    final entries = [
      for (final id in ['daily', 'once'])
        TaskEntry(
            taskId: id,
            dateKey: '2026-11-16',
            progress: 3,
            completedAt: DateTime(2026, 11, 16, 14))
    ];
    final today = buildHomeWidgetSnapshot(
        tasks: tasks, entries: entries, now: DateTime(2026, 11, 16, 23, 59));
    expect(rows(today), isEmpty);
    expect(
        today['nextRefreshAt'], DateTime(2026, 11, 17).millisecondsSinceEpoch);
    final tomorrow = buildHomeWidgetSnapshot(
        tasks: tasks, entries: entries, now: DateTime(2026, 11, 17));
    expect(rows(tomorrow).single['name'], 'daily');
    expect(rows(tomorrow).single['progress'], 0);
  });

  test('multi-step and timer progress remain understandable in a small panel',
      () {
    final snapshot = buildHomeWidgetSnapshot(tasks: [
      task('Laundry', type: TaskType.multiStep, steps: ['Wash', 'Dry']),
      task('Read', type: TaskType.minutes, goal: 900),
    ], entries: const [
      TaskEntry(
          taskId: 'Laundry',
          dateKey: '2026-11-16',
          progress: 1,
          steps: ['Wash', 'Dry']),
      TaskEntry(taskId: 'Read', dateKey: '2026-11-16', progress: 300),
    ], now: DateTime(2026, 11, 16, 14));
    expect(rows(snapshot).first['detail'], contains('Step 2 / 2 · Dry'));
    expect(rows(snapshot).first['compactDetail'], 'Step 2 / 2 · Dry');
    expect(rows(snapshot).last['compactDetail'], '5 / 15 min');
    expect(rows(snapshot).last['detail'], contains('5 / 15 min'));
    expect(jsonDecode(jsonEncode(snapshot))['tasks'], hasLength(2));
  });

  test('large lists preserve total and cap the native transport payload', () {
    final snapshot = buildHomeWidgetSnapshot(
        tasks: [for (var i = 0; i < 120; i++) task('$i')],
        entries: [],
        now: DateTime(2026, 11, 16, 14));
    expect(rows(snapshot), hasLength(100));
    expect(snapshot['total'], 120);
  });

  test(
      'background refresh reads saved task progress and tolerates old slot settings',
      () async {
    SharedPreferences.setMockInitialValues(
        {'day_slots_v1': 'old invalid data'});
    final prefs = await SharedPreferences.getInstance();
    await AppStorage(prefs).saveTasks([task('Saved task')]);
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(homeWidgetChannel, (call) async {
      calls.add(call);
      return null;
    });
    await refreshHomeWidgetBackground();
    expect(calls.single.method, 'backgroundSnapshot');
    final snapshot = jsonDecode(calls.single.arguments as String);
    expect((snapshot['tasks'] as List).single['name'], 'Saved task');
    // Recalculating the panel never completes tasks or changes local data.
    expect(AppStorage(prefs).loadEntries(), isEmpty);
  });

  test('native bridge retries failures and clears all content on sign-out',
      () async {
    final calls = <MethodCall>[];
    var fail = true;
    messenger.setMockMethodCallHandler(homeWidgetChannel, (call) async {
      calls.add(call);
      if (fail) throw PlatformException(code: 'temporary');
      return null;
    });
    final service = HomeWidgetService(enabled: true);
    final snapshot = buildHomeWidgetSnapshot(
        tasks: [task('Private task')],
        entries: [],
        now: DateTime(2026, 11, 16, 14));
    await service.publish(snapshot);
    fail = false;
    await service.publish(snapshot);
    await service.publish(snapshot);
    expect(calls, hasLength(2));
    await service.publish(null);
    expect(calls.last.arguments, {'signedIn': false, 'snapshot': null});
  });

  test('app task edits, completion, slot changes, and sign-out publish updates',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final savedTask = task('Laundry');
    await AppStorage(prefs).saveTasks([savedTask]);
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(homeWidgetChannel, (call) async {
      calls.add(call);
      return null;
    });
    final auth = StreamController<bool?>();
    addTearDown(auth.close);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => DateTime(2026, 11, 16, 14)),
      homeWidgetServiceProvider
          .overrideWithValue(HomeWidgetService(enabled: true)),
      authStateProvider.overrideWith((ref) => auth.stream),
    ]);
    addTearDown(container.dispose);
    container.listen(homeWidgetSyncProvider, (previous, next) {},
        fireImmediately: true);
    auth.add(true);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    Map<String, dynamic> latest() =>
        jsonDecode((calls.last.arguments as Map)['snapshot'] as String);
    expect((latest()['tasks'] as List).single['name'], 'Laundry');
    await container
        .read(appControllerProvider.notifier)
        .markComplete(savedTask);
    await container.pump();
    expect(latest()['tasks'], isEmpty);
    await container
        .read(appControllerProvider.notifier)
        .undoCompletion(savedTask, occurrenceKey: '2026-11-16');
    await container.read(appControllerProvider.notifier).updateTask(
        savedTask.copyWith(
            name: 'Evening laundry',
            timing: const TaskTiming(slot: DaySlot.evening)));
    await container.pump();
    expect(latest()['upcoming'], 1);
    await container
        .read(daySlotsProvider.notifier)
        .save(const DaySlots(morning: 360, afternoon: 600, evening: 780));
    await container.pump();
    expect((latest()['tasks'] as List).single['name'], 'Evening laundry');
    auth.add(false);
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(calls.last.arguments, {'signedIn': false, 'snapshot': null});
  });
}
