import 'package:daily_focus/models/day_slots.dart';
import 'package:daily_focus/models/schedule.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_occurrence.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/providers/completion_feedback_provider.dart';
import 'package:daily_focus/providers/forest_provider.dart';
import 'package:daily_focus/providers/timer_controller.dart';
import 'package:daily_focus/screens/home_screen.dart';
import 'package:daily_focus/screens/task_card.dart';
import 'package:daily_focus/services/home_widget_service.dart';
import 'package:daily_focus/services/notification_service.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/widgets/task_completion_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _morning = DateTime(2026, 11, 17, 9);
Task _task(
        {String id = 'walk',
        TaskType type = TaskType.count,
        Schedule schedule = const ScheduleDaily(),
        TaskTiming timing = const TaskTiming(showMinute: 1020)}) =>
    Task(
        id: id,
        name: id == 'walk' ? 'Walk' : id,
        type: type,
        goal: type == TaskType.minutes ? 60 : 1,
        steps: type == TaskType.multiStep ? const ['Wash', 'Dry'] : const [],
        step: 1,
        color: 0xff247866,
        icon: Icons.directions_walk.codePoint,
        createdAt: DateTime(2026, 11, 16),
        schedule: schedule,
        timing: timing);

class _Notifications extends NotificationService {
  DateTime? scheduledAt;
  @override
  Future<int> scheduleTaskComplete(
      {required int notificationId,
      required String taskName,
      required DateTime when}) async {
    scheduledAt = when;
    return notificationId;
  }

  @override
  Future<void> cancel(int notificationId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('same-day completion is independent of appearance and global slot start',
      () {
    final task = _task(timing: const TaskTiming(slot: DaySlot.evening));
    final today = TaskOccurrence(task, DateTime(2026, 11, 17), null, _morning,
        const DaySlots(evening: 1020));
    expect(today.visible, isFalse);
    expect(today.canComplete, isTrue);
    expect(today.status, OccurrenceStatus.upcoming);
    expect(today.appearsAt, DateTime(2026, 11, 17, 17));
    final tomorrow =
        TaskOccurrence(task, DateTime(2026, 11, 18), null, _morning);
    expect(tomorrow.canComplete, isFalse);
    final earlyWindow =
        _task(timing: const TaskTiming(showDaysBefore: 1, showMinute: 1020));
    expect(
        TaskOccurrence(earlyWindow, DateTime(2026, 11, 18), null, _morning)
            .canComplete,
        isTrue);
    final expired = _task(timing: const TaskTiming(visibleDaysAfter: 0));
    expect(
        TaskOccurrence(expired, DateTime(2026, 11, 16), null, _morning)
            .canComplete,
        isFalse);
  });

  test(
      'early completion persists on the correct day, updates widgets, and rewards once after undo',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final task = _task();
    await AppStorage(prefs).saveTasks([task]);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => _morning),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    Map<String, Object> snapshot(DateTime now) => buildHomeWidgetSnapshot(
        tasks: [task],
        entries: container.read(appControllerProvider).entries,
        now: now);
    expect(snapshot(_morning)['upcoming'], 1);
    await controller.markComplete(task);
    final saved = AppStorage(prefs).loadEntries().single;
    expect(saved.dateKey, '2026-11-17');
    expect(saved.completedAt, _morning.toUtc());
    expect(saved.completionTiming, 'onTime');
    expect(container.read(forestProvider).completions, 1);
    expect(snapshot(_morning)['upcoming'], 0);
    expect(snapshot(DateTime(2026, 11, 17, 17))['tasks'], isEmpty);
    await controller.undoCompletion(task, occurrenceKey: '2026-11-17');
    expect(snapshot(_morning)['upcoming'], 1);
    await controller.increment(task);
    expect(container.read(forestProvider).completions, 1);
    expect(container.read(completionFeedbackProvider)!.earnedWater, isFalse);
    final tomorrow = currentOccurrence(
        task, AppStorage(prefs).loadEntries(), DateTime(2026, 11, 18, 9))!;
    expect(tomorrow.progress, 0);
    expect(tomorrow.done, isFalse);
  });

  test('multi-step tasks can record early steps and reward only the last step',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final task = _task(type: TaskType.multiStep);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => _morning),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    await controller.increment(task);
    expect(AppStorage(prefs).loadEntries().single.progress, 1);
    expect(container.read(forestProvider).completions, 0);
    await controller.increment(task);
    expect(AppStorage(prefs).loadEntries().single.steps, ['Wash', 'Dry']);
    expect(AppStorage(prefs).loadEntries().single.progress, 2);
    expect(container.read(forestProvider).completions, 1);
  });

  test('later dates stay locked for completion, progress, and timer starts',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifications = _Notifications();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => _morning),
      notificationServiceProvider.overrideWithValue(notifications),
    ]);
    addTearDown(container.dispose);
    for (final type in TaskType.values) {
      final task = _task(
          type: type, schedule: ScheduleOnce(dueDate: DateTime(2026, 11, 18)));
      await container.read(appControllerProvider.notifier).increment(task);
      await container
          .read(appControllerProvider.notifier)
          .markComplete(task, occurrenceKey: '2026-11-18');
      if (type == TaskType.minutes) {
        await container
            .read(timerControllerProvider.notifier)
            .start(task, occurrenceKey: '2026-11-18');
      }
    }
    expect(AppStorage(prefs).loadEntries(), isEmpty);
    expect(AppStorage(prefs).loadActiveTimers(), isEmpty);
    expect(notifications.scheduledAt, isNull);
    expect(container.read(forestProvider).completions, 0);
  });

  test('an early timer can finish before the appearance time', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final task = _task(type: TaskType.minutes);
    await AppStorage(prefs).saveTasks([task]);
    var now = _morning;
    final notifications = _Notifications();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => now),
      notificationServiceProvider.overrideWithValue(notifications),
    ]);
    addTearDown(container.dispose);
    await container
        .read(timerControllerProvider.notifier)
        .start(task, occurrenceKey: '2026-11-17');
    expect(notifications.scheduledAt, _morning.add(const Duration(minutes: 1)));
    now = _morning.add(const Duration(minutes: 1));
    await container.read(timerControllerProvider.notifier).checkForElapsed();
    expect(AppStorage(prefs).loadEntries().single.completionTiming, 'onTime');
    expect(AppStorage(prefs).loadActiveTimers(), isEmpty);
    expect(container.read(forestProvider).completions, 1);
  });

  testWidgets(
      'Upcoming task completes with feedback, stays completed at 17:00, and can be undone early',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await AppStorage(prefs).saveTasks([_task()]);
    var now = _morning;
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => now),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(find.text('Upcoming tasks (1)'), findsOneWidget);
    await tester.tap(find.text('Upcoming tasks (1)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Complete'));
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(find.byType(CompletionWaterFlight), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Upcoming tasks (1)'), findsNothing);
    expect(find.text('Completed & skipped (1)'), findsOneWidget);
    await tester.ensureVisible(find.text('Completed & skipped (1)'));
    await tester.tap(find.text('Completed & skipped (1)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Undo'));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming tasks (1)'), findsOneWidget);
    await tester.ensureVisible(find.text('Complete'));
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    now = DateTime(2026, 11, 17, 17);
    container.invalidate(clockProvider);
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsNothing);
    expect(find.text('Completed & skipped (1)'), findsOneWidget);
    expect(container.read(forestProvider).completions, 1);
    expect(tester.takeException(), isNull);
  });

  for (final type in [TaskType.minutes, TaskType.multiStep]) {
    testWidgets('Upcoming ${type.name} exposes its early action',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final task = _task(type: type);
      await AppStorage(prefs).saveTasks([task]);
      await tester.pumpWidget(ProviderScope(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeSourceProvider.overrideWithValue(() => _morning),
        notificationServiceProvider.overrideWithValue(_Notifications()),
      ], child: MaterialApp(home: Scaffold(body: TaskCard(task: task)))));
      await tester.pumpAndSettle();
      await tester.tap(find
          .text(type == TaskType.minutes ? 'Start timer' : 'Complete step'));
      await tester.pump();
      if (type == TaskType.minutes) {
        expect(find.text('Pause'), findsOneWidget);
      } else {
        expect(find.text('Next: Dry'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
