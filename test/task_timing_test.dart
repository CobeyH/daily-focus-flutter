import 'package:daily_focus/models/schedule.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_entry.dart';
import 'package:daily_focus/models/task_occurrence.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/utils/dates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Task review(
        {TaskTiming timing = const TaskTiming(
            showDaysBefore: 1, showMinute: 540, dueMinute: 1080, graceDays: 2),
        Schedule? schedule}) =>
    Task(
        id: 'review',
        name: 'Weekly review',
        type: TaskType.count,
        goal: 1,
        step: 1,
        color: 0xFF247866,
        icon: 0xe000,
        createdAt: DateTime(2026, 10, 26),
        schedule: schedule ??
            ScheduleWeekly(
                intervalWeeks: 1,
                daysOfWeek: [3],
                firstDueDate: DateTime(2026, 10, 28)),
        timing: timing);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('clock advances visibility at the next minute without an action',
      (tester) async {
    var time = DateTime(2026, 10, 27, 8, 59, 59);
    final container = ProviderContainer(
        overrides: [timeSourceProvider.overrideWithValue(() => time)]);
    final task = review();
    expect(currentOccurrence(task, [], container.read(clockProvider))!.visible,
        false);
    time = DateTime(2026, 10, 27, 9);
    await tester.pump(const Duration(seconds: 1));
    expect(currentOccurrence(task, [], container.read(clockProvider))!.visible,
        true);
    container.dispose();
  });
  test('appearance, due time, grace boundary, and overdue are separate', () {
    final task = review();
    OccurrenceStatus status(DateTime now) =>
        currentOccurrence(task, [], now)!.status;
    expect(status(DateTime(2026, 10, 27, 8, 59)), OccurrenceStatus.upcoming);
    expect(status(DateTime(2026, 10, 27, 9)), OccurrenceStatus.available);
    expect(status(DateTime(2026, 10, 28, 18)), OccurrenceStatus.due);
    expect(status(DateTime(2026, 10, 28, 18, 1)), OccurrenceStatus.grace);
    expect(status(DateTime(2026, 10, 30, 18)), OccurrenceStatus.grace);
    expect(status(DateTime(2026, 10, 30, 18, 1)), OccurrenceStatus.overdue);
  });
  test('all-day strict tasks expire at next midnight, grace at final midnight',
      () {
    const strict = TaskTiming();
    const grace = TaskTiming(graceDays: 2);
    final due = DateTime(2026, 10, 28);
    expect(strict.pastGrace(due, DateTime(2026, 10, 28, 23, 59, 59)), false);
    expect(strict.pastGrace(due, DateTime(2026, 10, 29)), true);
    expect(grace.pastGrace(due, DateTime(2026, 10, 30, 23, 59, 59)), false);
    expect(grace.pastGrace(due, DateTime(2026, 10, 31)), true);
  });
  test('legacy data defaults to same-day visibility and no grace', () {
    final json = review().toJson()
      ..remove('timing')
      ..remove('updatedAt');
    final task = Task.fromJson(json);
    expect(task.timing.showDaysBefore, 0);
    expect(task.timing.graceDays, 0);
    expect(task.timing.dueMinute, isNull);
    final entry = TaskEntry.fromJson(
        {'taskId': 'review', 'dateKey': '2026-10-28', 'progress': 1});
    expect(entry.countsForStreak(1), true);
  });
  test('calendar recurrence handles selected weekdays and long intervals', () {
    final weekly = ScheduleInterval(
        period: SchedulePeriod.week,
        interval: 1,
        firstDueDate: DateTime(2026, 10, 26),
        daysOfWeek: [3, 5]);
    expect(weekly.nextDueDateAfter(DateTime(2026, 10, 26)),
        DateTime(2026, 10, 28));
    expect(weekly.isDueOn(DateTime(2026, 10, 30)), true);
    final long = ScheduleWeekly(
        intervalWeeks: 12,
        daysOfWeek: [1],
        firstDueDate: DateTime(2026, 10, 26));
    expect(
        long.nextDueDateAfter(DateTime(2026, 10, 26)), DateTime(2027, 1, 18));
    expect(long.lastDueDateOnOrBefore(DateTime(2027, 1, 17)),
        DateTime(2026, 10, 26));
  });
  test('monthly tasks clamp to month end, including leap years', () {
    final task = ScheduleInterval(
        period: SchedulePeriod.month,
        interval: 1,
        firstDueDate: DateTime(2028, 1, 31));
    expect(task.nextDueDateAfter(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
    expect(task.nextDueDateAfter(DateTime(2028, 2, 29)), DateTime(2028, 3, 31));
  });
  test(
      'calendar days and due times survive Vancouver daylight-saving transitions',
      () {
    // Run this suite with TZ=America/Vancouver to exercise the 23/25-hour days.
    final daily = ScheduleInterval(
        period: SchedulePeriod.day,
        interval: 2,
        firstDueDate: DateTime(2026, 3, 7));
    expect(daily.isDueOn(DateTime(2026, 3, 9)), true);
    final beforeFall = DateTime(2026, 10, 31);
    expect(dateKey(calendarDay(beforeFall, 2)), '2026-11-02');
    expect(const TaskTiming(dueMinute: 1080, graceDays: 2).closesAt(beforeFall),
        DateTime(2026, 11, 2, 18));
  });
  test('overlapping grace windows prefer previous unfinished occurrence', () {
    final task = review(
        timing: const TaskTiming(graceDays: 2),
        schedule: const ScheduleDaily());
    final now = DateTime(2026, 10, 27, 12);
    expect(currentOccurrence(task, [], now)!.key, '2026-10-26');
    final done = TaskEntry(
        taskId: task.id, dateKey: '2026-10-26', progress: 1, completedAt: now);
    expect(currentOccurrence(task, [done], now)!.key, '2026-10-27');
  });
  test('expired daily cycles move to history and new daily tasks start fresh',
      () {
    final task =
        review(timing: const TaskTiming(), schedule: const ScheduleDaily());
    expect(
        currentOccurrence(task, [], DateTime(2026, 10, 29))!.key, '2026-10-29');
  });

  group('completion and persistence', () {
    late ProviderContainer container;
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(DateTime(2026, 10, 29, 12))
      ]);
    });
    tearDown(() => container.dispose());
    test('early completion is credited once to the future due date', () async {
      final task = review();
      final controller = container.read(appControllerProvider.notifier);
      await controller.addTask(task);
      await controller.markComplete(task, now: DateTime(2026, 10, 27, 10));
      final state = container.read(appControllerProvider);
      expect(state.entries, hasLength(1));
      expect(state.entries.single.dateKey, '2026-10-28');
      expect(state.entries.single.completionTiming, 'onTime');
      expect(
          state.entries.single.completedAt, DateTime(2026, 10, 27, 10).toUtc());
      expect(
          currentOccurrence(task, state.entries, DateTime(2026, 10, 28, 12))!
              .done,
          true);
      expect(
          nextOccurrence(task, state.entries, DateTime(2026, 10, 28, 12))!.key,
          '2026-11-04');
    });
    test('completion in grace and exact undo survive local reload', () async {
      final task = review();
      final controller = container.read(appControllerProvider.notifier);
      await controller.addTask(task);
      await controller.increment(task, now: DateTime(2026, 10, 29, 12));
      var entries = AppStorage(prefs).loadEntries();
      expect(entries, hasLength(1));
      expect(entries.single.dateKey, '2026-10-28');
      expect(entries.single.completionTiming, 'grace');
      expect(currentStreak(task, entries, DateTime(2026, 10, 29, 12)), 1);
      expect(AppStorage(prefs).loadTasks().single.timing.graceDays, 2);
      await controller.reset(task,
          now: DateTime(2026, 10, 29, 13), occurrenceKey: '2026-10-28');
      entries = AppStorage(prefs).loadEntries();
      expect(entries.single.progress, 0);
      expect(entries.single.completedAt, isNull);
      expect(entries.single.completionTiming, isNull);
      expect(currentStreak(task, entries, DateTime(2026, 10, 29, 13)), 0);
      expect(
          currentOccurrence(task, entries, DateTime(2026, 10, 29, 13))!.status,
          OccurrenceStatus.grace);
    });
    test(
        'late completion closes the occurrence but does not restore the streak',
        () async {
      final task = review();
      final controller = container.read(appControllerProvider.notifier);
      await controller.addTask(task);
      await controller.markComplete(task, now: DateTime(2026, 10, 31, 12));
      final entries = container.read(appControllerProvider).entries;
      expect(entries.single.completionTiming, 'late');
      expect(currentStreak(task, entries, DateTime(2026, 10, 31, 12)), 0);
      expect(currentOccurrence(task, entries, DateTime(2026, 10, 31, 12))!.done,
          true);
    });
    test('daily tap does not backfill yesterday', () async {
      final task =
          review(timing: const TaskTiming(), schedule: const ScheduleDaily());
      final controller = container.read(appControllerProvider.notifier);
      await controller.addTask(task);
      await controller.increment(task, now: DateTime(2026, 10, 29, 12));
      final entries = container.read(appControllerProvider).entries;
      expect(entries, hasLength(1));
      expect(entries.single.dateKey, '2026-10-29');
    });
    test('timer completion uses pinned due date and actual finish time',
        () async {
      final task = review().copyWith(type: TaskType.minutes, goal: 60);
      final controller = container.read(appControllerProvider.notifier);
      await controller.addTask(task);
      await controller.recordTimedCompletion(task, '2026-10-28',
          completedAt: DateTime(2026, 10, 29, 0, 1));
      final entries = container.read(appControllerProvider).entries;
      expect(entries.single.dateKey, '2026-10-28');
      expect(entries.single.completionTiming, 'grace');
      expect(currentOccurrence(task, entries, DateTime(2026, 10, 29, 10))!.done,
          true);
    });
    test('new weekly completion cannot fill two missed weeks', () async {
      final task = review(timing: const TaskTiming());
      final controller = container.read(appControllerProvider.notifier);
      await controller.addTask(task);
      await controller.markComplete(task, now: DateTime(2026, 11, 4, 12));
      expect(container.read(appControllerProvider).entries, hasLength(1));
      expect(container.read(appControllerProvider).entries.single.dateKey,
          '2026-11-04');
    });
    test('undo a full completion restores the prior partial count', () async {
      final task = review().copyWith(goal: 5);
      final controller = container.read(appControllerProvider.notifier);
      await controller.addTask(task);
      await controller.increment(task, now: DateTime(2026, 10, 29, 12));
      await controller.increment(task, now: DateTime(2026, 10, 29, 12));
      await controller.markComplete(task, now: DateTime(2026, 10, 29, 12));
      expect(AppStorage(prefs).loadEntries().single.previousProgress, 2);
      await controller.undoCompletion(task, occurrenceKey: '2026-10-28');
      expect(AppStorage(prefs).loadEntries().single.progress, 2);
      expect(AppStorage(prefs).loadEntries().single.completedAt, isNull);
    });
    test('skipping one occurrence leaves cadence unchanged and can be undone',
        () async {
      final task = review();
      final controller = container.read(appControllerProvider.notifier);
      await controller.addTask(task);
      await controller.skip(task,
          occurrenceKey: '2026-10-28', now: DateTime(2026, 10, 29, 12));
      expect(
          currentOccurrence(task, container.read(appControllerProvider).entries,
                  DateTime(2026, 10, 30))!
              .key,
          '2026-11-04');
      await controller.reset(task,
          occurrenceKey: '2026-10-28', now: DateTime(2026, 10, 29, 13));
      expect(
          container.read(appControllerProvider).entries.single.skipped, false);
    });
  });
}
