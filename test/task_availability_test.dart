import 'package:daily_focus/models/day_slots.dart';
import 'package:daily_focus/models/schedule.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_entry.dart';
import 'package:daily_focus/models/task_occurrence.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/screens/home_screen.dart';
import 'package:daily_focus/screens/task_creation.dart';
import 'package:daily_focus/services/home_widget_service.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/theme/app_theme.dart';
import 'package:daily_focus/widgets/schedule_picker.dart';
import 'package:daily_focus/widgets/task_timing_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final due = DateTime(2026, 11, 18);
Task task({TaskTiming timing = const TaskTiming(), Schedule? schedule}) => Task(
    id: 'review',
    name: 'Weekly review',
    type: TaskType.count,
    goal: 1,
    step: 1,
    color: 0xff247866,
    icon: Icons.check.codePoint,
    createdAt: DateTime(2026, 11, 16),
    schedule: schedule ?? ScheduleOnce(dueDate: due),
    timing: timing);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'one window controls availability at the exact timed deadline and extra-day boundary',
      () {
    for (final days in [0, 2]) {
      final t = task(timing: TaskTiming(dueMinute: 1080, graceDays: days));
      final end = DateTime(2026, 11, 18 + days, 18);
      final at = TaskOccurrence(t, due, null, end),
          after = TaskOccurrence(
              t, due, null, end.add(const Duration(microseconds: 1)));
      expect(at.visible, isTrue);
      expect(at.canComplete, isTrue);
      expect(after.visible, isFalse);
      expect(after.canComplete, isFalse);
      expect(t.timing.visibilityEnded(due, after.now),
          t.timing.pastGrace(due, after.now));
    }
  });
  test('all-day windows close at midnight after the last available day', () {
    final t = task(timing: const TaskTiming(graceDays: 2));
    final end = DateTime(2026, 11, 21);
    expect(
        TaskOccurrence(
                t, due, null, end.subtract(const Duration(microseconds: 1)))
            .visible,
        isTrue);
    expect(TaskOccurrence(t, due, null, end).visible, isFalse);
    expect(TaskOccurrence(t, due, null, end).canComplete, isFalse);
  });
  test('legacy settings normalize around grace and serialize as one window',
      () {
    for (final visible in [null, 0, 1, 30]) {
      final timing = TaskTiming.fromJson(
          {'graceDays': 2, 'visibleDaysAfter': visible, 'dueMinute': 1080});
      expect(timing.graceDays, 2);
      expect(timing.visibleDaysAfter, 2);
      expect(timing.toJson()['visibleDaysAfter'], timing.toJson()['graceDays']);
      expect(
          timing.visibilityEnded(due, DateTime(2026, 11, 20, 18, 1)), isTrue);
    }
    expect(TaskTiming.fromJson({'visibleDaysAfter': 3}).graceDays, 3);
    expect(TaskTiming.fromJson({}).graceDays, 0);
    expect(
        TaskTiming.fromJson({'graceDays': 0, 'visibleDaysAfter': 30}).graceDays,
        0);
    expect(TaskTiming.fromJson({'graceDays': 90}).graceDays, 30);
  });
  test('daylight saving keeps the availability end at the same local due time',
      () {
    for (final day in [DateTime(2026, 3, 7), DateTime(2026, 10, 31)]) {
      const timing = TaskTiming(graceDays: 2, dueMinute: 1080);
      final end = DateTime(day.year, day.month, day.day + 2, 18);
      expect(timing.closesAt(day), end);
      expect(timing.visibilityEnded(day, end), isFalse);
      expect(timing.visibilityEnded(day, end.add(const Duration(minutes: 1))),
          isTrue);
    }
  });
  test(
      'expired weekly cycle yields to the next occurrence when it appears early',
      () {
    final t = task(
        timing: const TaskTiming(showDaysBefore: 4, graceDays: 1),
        schedule: ScheduleWeekly(
            intervalWeeks: 1,
            daysOfWeek: const [DateTime.wednesday],
            firstDueDate: due));
    final occurrence = currentOccurrence(t, [], DateTime(2026, 11, 21, 10))!;
    expect(occurrence.key, '2026-11-25');
    expect(occurrence.visible, isTrue);
    expect(TaskOccurrence(t, due, null, occurrence.now).visible, isFalse);
  });
  test('Upcoming skips expired timed occurrences, including one-off tasks', () {
    final now = DateTime(2026, 11, 18, 19);
    final once = task(timing: const TaskTiming(dueMinute: 1080));
    expect(nextOccurrence(once, [], now), isNull);
    final daily = task(
        timing: const TaskTiming(dueMinute: 1080),
        schedule: const ScheduleDaily());
    expect(nextOccurrence(daily, [], now)!.key, '2026-11-19');
    expect(currentOccurrence(daily, [], now)!.key, '2026-11-19');
  });
  test(
      'same-day early completion and unfinished morning slots still work until expiry',
      () {
    final t = task(
        timing: const TaskTiming(
            slot: DaySlot.evening, dueMinute: 1200, graceDays: 1));
    expect(TaskOccurrence(t, due, null, DateTime(2026, 11, 18, 9)).canComplete,
        isTrue);
    expect(TaskOccurrence(t, due, null, DateTime(2026, 11, 19, 14)).visible,
        isTrue);
    expect(
        TaskOccurrence(t, due, null, DateTime(2026, 11, 19, 20, 1)).canComplete,
        isFalse);
  });
  test(
      'completion after expiry is refused and existing history survives reload',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = task(timing: const TaskTiming(graceDays: 2, dueMinute: 1080));
    final storage = AppStorage(prefs);
    await storage.saveTasks([t]);
    final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final controller = c.read(appControllerProvider.notifier);
    await controller.markComplete(t, now: DateTime(2026, 11, 20, 18, 1));
    await controller.increment(t,
        occurrenceKey: '2026-11-18', now: DateTime(2026, 11, 20, 18, 1));
    expect(storage.loadEntries(), isEmpty);
    await controller.markComplete(t, now: DateTime(2026, 11, 20, 18));
    expect(storage.loadEntries().single.completionTiming, 'grace');
    expect(
        currentStreak(t, storage.loadEntries(), DateTime(2026, 11, 20, 19)), 1);
    expect(storage.loadTasks().single.timing.visibleDaysAfter, 2);
    expect(storage.loadEntries().single.dateKey, '2026-11-18');
    expect(
        currentOccurrence(t, storage.loadEntries(), DateTime(2026, 11, 20, 19))!
            .done,
        isTrue);
  });
  test('home widget removes expired tasks at the same boundary as the app', () {
    final t = task(timing: const TaskTiming(graceDays: 2, dueMinute: 1080));
    final at = buildHomeWidgetSnapshot(
        tasks: [t], entries: [], now: DateTime(2026, 11, 20, 18));
    final after = buildHomeWidgetSnapshot(
        tasks: [t], entries: [], now: DateTime(2026, 11, 20, 18, 1));
    expect(at['tasks'], hasLength(1));
    expect(after['tasks'], isEmpty);
  });

  Future<SharedPreferences> pump(WidgetTester tester, Widget home,
      {Task? stored, double scale = 1, double width = 390}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (stored != null) await AppStorage(prefs).saveTasks([stored]);
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeSourceProvider.overrideWithValue(() => DateTime(2026, 11, 18, 10))
        ],
        child: MaterialApp(
            theme: focusTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: home)));
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> step(WidgetTester tester, int target) async {
    for (var i = 0; i < 8; i++) {
      final current = List.generate(6, (n) => n).firstWhere(
          (n) => find.byKey(ValueKey('wizard-step-$n')).evaluate().isNotEmpty);
      if (current == target) return;
      await tester.tap(find.text(current > target ? 'Back' : 'Continue'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
      'one-off wizard has one due-date picker with no duplicate text preview',
      (tester) async {
    final t = task();
    await pump(tester, TaskCreationScreen(existing: t), stored: t);
    await step(tester, 1);
    expect(find.byType(SchedulePicker), findsOneWidget);
    expect(find.text('Due date'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
    expect(find.text('Next due dates'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'visibility only controls appearance; availability is edited and reviewed once',
      (tester) async {
    final t = task(
        timing:
            const TaskTiming(showDaysBefore: 1, dueMinute: 1080, graceDays: 2));
    final prefs = await pump(tester, TaskCreationScreen(existing: t),
        stored: t, width: 320, scale: 1.5);
    await step(tester, 2);
    expect(find.byKey(const ValueKey('visibility-after')), findsNothing);
    expect(find.text('Keep visible after due date'), findsNothing);
    await step(tester, 3);
    await tester.ensureVisible(find.byKey(const ValueKey('grace-days')));
    await tester.pumpAndSettle();
    expect(find.text('Keep available after due'), findsOneWidget);
    expect(find.text('Grace period'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('grace-days')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Up to 3 days late').last);
    await tester.pumpAndSettle();
    await step(tester, 5);
    expect(find.textContaining('Available up to 3 days after due'),
        findsOneWidget);
    expect(find.textContaining('Visible until completed'), findsNothing);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final timing = AppStorage(prefs).loadTasks().single.timing;
    expect(timing.graceDays, 3);
    expect(timing.visibleDaysAfter, 3);
    expect(timing.slot, isNull);
    expect(timing.showDaysBefore, 1);
    expect(timing.dueMinute, 1080);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'recurring task previews remain useful and strict window is shown clearly',
      (tester) async {
    final t = task(schedule: const ScheduleDaily());
    await pump(tester, TaskCreationScreen(existing: t), stored: t);
    await step(tester, 1);
    expect(find.text('Next due dates'), findsOneWidget);
    expect(find.byType(Chip), findsWidgets);
    await step(tester, 3);
    expect(find.text('None · until the deadline'), findsOneWidget);
    expect(find.byType(TaskTimingPicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'expired tasks disappear from Tasks while today completion remains in history',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final t = task(timing: const TaskTiming(dueMinute: 1080, graceDays: 2));
    await AppStorage(prefs).saveTasks([t]);
    var now = DateTime(2026, 11, 20, 18);
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => now)
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Weekly review'), findsOneWidget);
    now = DateTime(2026, 11, 20, 18, 1);
    c.invalidate(clockProvider);
    await tester.pumpAndSettle();
    expect(find.text('Weekly review'), findsNothing);
    await AppStorage(prefs).saveEntries([
      TaskEntry(
          taskId: t.id,
          dateKey: '2026-11-18',
          progress: 1,
          completedAt: DateTime(2026, 11, 20, 17).toUtc(),
          completionTiming: 'grace')
    ]);
    c.invalidate(appControllerProvider);
    await tester.pumpAndSettle();
    expect(find.text('Completed & skipped (1)'), findsOneWidget);
    expect(AppStorage(prefs).loadEntries().single.progress, 1);
    expect(tester.takeException(), isNull);
  });
}
