// Smoke + schedule tests for the Daily Focus app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_focus/main.dart';
import 'package:daily_focus/models/schedule.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/screens/auth_screen.dart';
import 'package:daily_focus/utils/dates.dart';

void main() {
  testWidgets('shows empty state and FAB', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const DailyFocusApp(),
      ),
    );
    // Allow the local-only auth stream to emit its initial signed-in value.
    await tester.pump();

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('auth screen offers Google sign-in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  group('Schedule', () {
    test('ScheduleDaily is due every day', () {
      const s = ScheduleDaily();
      expect(s.isDueOn(DateTime(2026, 8, 31)), isTrue);
      expect(s.isDueOn(DateTime(2026, 9, 1)), isTrue);
    });

    test('ScheduleInterval every N days', () {
      final s = ScheduleInterval(
        period: SchedulePeriod.day,
        interval: 3,
        firstDueDate: DateTime(2026, 8, 31),
      );
      expect(s.isDueOn(DateTime(2026, 8, 31)), isTrue);
      expect(s.isDueOn(DateTime(2026, 9, 1)), isFalse);
      expect(s.isDueOn(DateTime(2026, 9, 2)), isFalse);
      expect(s.isDueOn(DateTime(2026, 9, 3)), isTrue);
      expect(s.isDueOn(DateTime(2026, 9, 6)), isTrue);
    });

    test('ScheduleInterval every other Monday', () {
      // 2026-08-31 is a Monday. First due on that Monday, then every other.
      final s = ScheduleInterval(
        period: SchedulePeriod.week,
        interval: 2,
        firstDueDate: DateTime(2026, 8, 31),
      );
      // First Monday is due.
      expect(s.isDueOn(DateTime(2026, 8, 31)), isTrue);
      // Following Monday is skipped.
      expect(s.isDueOn(DateTime(2026, 9, 7)), isFalse);
      // The next one is due.
      expect(s.isDueOn(DateTime(2026, 9, 14)), isTrue);
    });

    test('ScheduleWeekly every Monday', () {
      final s = ScheduleWeekly(
        intervalWeeks: 1,
        daysOfWeek: const [DateTime.monday],
        firstDueDate: DateTime(2026, 8, 31),
      );
      expect(s.isDueOn(DateTime(2026, 8, 31)), isTrue); // Mon
      expect(s.isDueOn(DateTime(2026, 9, 1)), isFalse); // Tue
      expect(s.isDueOn(DateTime(2026, 9, 7)), isTrue); // Mon
      expect(s.isDueOn(DateTime(2026, 9, 14)), isTrue); // Mon
    });

    test('ScheduleWeekly every other Monday', () {
      final s = ScheduleWeekly(
        intervalWeeks: 2,
        daysOfWeek: const [DateTime.monday],
        firstDueDate: DateTime(2026, 8, 31),
      );
      expect(s.isDueOn(DateTime(2026, 8, 31)), isTrue); // Mon
      expect(s.isDueOn(DateTime(2026, 9, 7)), isFalse); // Mon
      expect(s.isDueOn(DateTime(2026, 9, 14)), isTrue); // Mon
      expect(s.isDueOn(DateTime(2026, 9, 21)), isFalse); // Mon
    });

    test('ScheduleInterval month period pins day-of-month', () {
      final s = ScheduleInterval(
        period: SchedulePeriod.month,
        interval: 1,
        firstDueDate: DateTime(2026, 8, 15),
      );
      expect(s.isDueOn(DateTime(2026, 8, 15)), isTrue);
      expect(s.isDueOn(DateTime(2026, 9, 15)), isTrue);
      expect(s.isDueOn(DateTime(2026, 9, 16)), isFalse);
    });

    test('ScheduleInterval month period every 3 months', () {
      final s = ScheduleInterval(
        period: SchedulePeriod.month,
        interval: 3,
        firstDueDate: DateTime(2026, 1, 10),
      );
      expect(s.isDueOn(DateTime(2026, 1, 10)), isTrue);
      expect(s.isDueOn(DateTime(2026, 4, 10)), isTrue);
      expect(s.isDueOn(DateTime(2026, 7, 10)), isTrue);
      expect(s.isDueOn(DateTime(2026, 10, 10)), isTrue);
      expect(s.isDueOn(DateTime(2026, 2, 10)), isFalse);
    });

    test('Schedule JSON round-trip', () {
      final s = ScheduleInterval(
        period: SchedulePeriod.week,
        interval: 2,
        firstDueDate: DateTime(2026, 8, 31),
        daysOfWeek: const [DateTime.monday, DateTime.wednesday],
      );
      final json = s.toJson();
      final restored = Schedule.fromJson(json);
      expect(restored, isA<ScheduleInterval>());
      final ri = restored as ScheduleInterval;
      expect(ri.period, SchedulePeriod.week);
      expect(ri.interval, 2);
      expect(ri.daysOfWeek, [DateTime.monday, DateTime.wednesday]);
    });

    test('Schedule describe produces human-readable text', () {
      expect(const ScheduleDaily().describe(), 'Daily');
      expect(
        ScheduleInterval(
          period: SchedulePeriod.day,
          interval: 3,
          firstDueDate: DateTime(2026, 8, 31),
        ).describe(),
        'Every 3 days',
      );
      expect(
        ScheduleWeekly(
          intervalWeeks: 2,
          daysOfWeek: const [DateTime.monday],
          firstDueDate: DateTime(2026, 8, 31),
        ).describe(),
        'Every 2nd Mon',
      );
    });
  });

  group('Overdue behavior', () {
    test('daily task is never overdue', () {
      final task = Task.create(
        name: 'Drink water',
        type: TaskType.count,
        goal: 5,
        step: 1,
        color: 0xFF000000,
        icon: 0xe000,
      );
      final state = AppState(tasks: [task], entries: const []);
      expect(isTaskOverdueOn(task, DateTime(2026, 8, 31), state), isFalse);
    });

    test('recurring task with a missed due date is overdue', () {
      // Every Monday; first due 2026-08-24. Today is Tuesday 2026-09-01 —
      // the previous Monday (2026-08-31) was missed, so the task is overdue.
      final task = Task.create(
        name: 'Take out trash',
        type: TaskType.count,
        goal: 1,
        step: 1,
        color: 0xFF000000,
        icon: 0xe000,
        schedule: ScheduleWeekly(
          intervalWeeks: 1,
          daysOfWeek: const [DateTime.monday],
          firstDueDate: DateTime(2026, 8, 24),
        ),
      );
      final state = AppState(tasks: [task], entries: const []);
      expect(isTaskOverdueOn(task, DateTime(2026, 9, 1), state), isTrue);
    });

    test('a recurring task created today is NOT overdue on the same day', () {
      // Every Monday; first due today (a Monday). Today is a due date but
      // there hasn't been a missed date strictly before today — the user
      // just made the task and hasn't had a chance to do it yet.
      final task = Task.create(
        name: 'Take out trash',
        type: TaskType.count,
        goal: 1,
        step: 1,
        color: 0xFF000000,
        icon: 0xe000,
        schedule: ScheduleWeekly(
          intervalWeeks: 1,
          daysOfWeek: const [DateTime.monday],
          firstDueDate: DateTime(2026, 8, 31),
        ),
      );
      final state = AppState(tasks: [task], entries: const []);
      expect(isTaskOverdueOn(task, DateTime(2026, 8, 31), state), isFalse);
    });

    test('completing an overdue task clears overdue', () async {
      // Deterministic date setup: today is Tuesday 2026-09-01. The schedule
      // is "every Monday" anchored to the missed Monday itself (2026-08-31),
      // so the only due date strictly before today is 2026-08-31 and it's
      // unmet — overdue.
      final today = DateTime(2026, 9, 1); // Tuesday
      final task = Task.create(
        name: 'Take out trash',
        type: TaskType.count,
        goal: 1,
        step: 1,
        color: 0xFF000000,
        icon: 0xe000,
        schedule: ScheduleWeekly(
          intervalWeeks: 1,
          daysOfWeek: const [DateTime.monday],
          firstDueDate: DateTime(2026, 8, 31),
        ),
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(appControllerProvider.notifier).addTask(task);

      expect(
        isTaskOverdueOn(task, today, container.read(appControllerProvider)),
        isTrue,
        reason: 'Should be overdue: missed Monday 2026-08-31 < today',
      );

      // Tap once, crediting today and the missed Monday (injected `now`
      // makes this deterministic regardless of real-world clock).
      await container
          .read(appControllerProvider.notifier)
          .increment(task, now: today);

      expect(
        isTaskOverdueOn(task, today, container.read(appControllerProvider)),
        isFalse,
        reason: 'Should no longer be overdue after completion',
      );
    });

    test('completing an overdue task credits both today and the missed date',
        () async {
      // Today is Tuesday 2026-09-01. Schedule is "every Monday" anchored
      // to the missed Monday (2026-08-31).
      final today = DateTime(2026, 9, 1); // Tuesday
      final missedMonday = DateTime(2026, 8, 31);
      final task = Task.create(
        name: 'Take out trash',
        type: TaskType.count,
        goal: 1,
        step: 1,
        color: 0xFF000000,
        icon: 0xe000,
        schedule: ScheduleWeekly(
          intervalWeeks: 1,
          daysOfWeek: const [DateTime.monday],
          firstDueDate: DateTime(2026, 8, 31),
        ),
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(appControllerProvider.notifier).addTask(task);

      await container
          .read(appControllerProvider.notifier)
          .increment(task, now: today);

      final after = container.read(appControllerProvider);
      expect(after.progressFor(task.id, dateKey(today)) >= 1, isTrue,
          reason: 'Today should be credited');
      expect(after.progressFor(task.id, dateKey(missedMonday)) >= 1, isTrue,
          reason: 'Missed date should be credited');
      expect(isTaskOverdueOn(task, today, after), isFalse);
    });
  });
}
