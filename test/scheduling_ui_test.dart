import 'package:daily_focus/models/schedule.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/screens/home_screen.dart';
import 'package:daily_focus/screens/streak_screen.dart';
import 'package:daily_focus/screens/task_creation.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 10, 29, 12);
Task _task({TaskTiming? timing, String name = 'Weekly review'}) => Task(
    id: 'review',
    name: name,
    type: TaskType.count,
    goal: 1,
    step: 1,
    color: 0xFF247866,
    icon: Icons.check.codePoint,
    createdAt: DateTime(2026, 10, 26),
    schedule: ScheduleWeekly(
        intervalWeeks: 1,
        daysOfWeek: [3],
        firstDueDate: DateTime(2026, 10, 28)),
    timing: timing ??
        const TaskTiming(
            showDaysBefore: 1, showMinute: 540, dueMinute: 1080, graceDays: 2));

Future<SharedPreferences> _pump(WidgetTester tester, List<Task> tasks,
    {double width = 390,
    double scale = 1,
    Brightness brightness = Brightness.light,
    Widget home = const HomeScreen()}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await AppStorage(prefs).saveTasks(tasks);
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(_now),
        timeSourceProvider.overrideWithValue(() => _now)
      ],
      child: MaterialApp(
          theme: focusTheme(brightness),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: home)));
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  testWidgets('task editor fits larger text on a small phone', (tester) async {
    await _pump(tester, [_task()],
        width: 320, scale: 1.5, home: TaskCreationScreen(existing: _task()));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('grace-days')), 200,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('task-editor-scroll')),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'grace completion moves to completed and undo restores same occurrence',
      (tester) async {
    final prefs = await _pump(tester, [_task()]);
    expect(find.textContaining('Within grace'), findsOneWidget);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(AppStorage(prefs).loadEntries(), hasLength(1));
    expect(AppStorage(prefs).loadEntries().single.dateKey, '2026-10-28');
    expect(AppStorage(prefs).loadEntries().single.completionTiming, 'grace');
    expect(find.text('Completed & skipped (1)'), findsOneWidget);
    await tester.tap(find.text('Completed & skipped (1)'));
    await tester.pumpAndSettle();
    final undoButton = find.widgetWithText(OutlinedButton, 'Undo');
    await tester.ensureVisible(undoButton);
    await tester.pumpAndSettle();
    await tester.tap(undoButton);
    await tester.pumpAndSettle();
    expect(AppStorage(prefs).loadEntries().single.progress, 0);
    expect(find.textContaining('Within grace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing exposes and persists appearance, due time and grace',
      (tester) async {
    final prefs = await _pump(tester, [_task()]);
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('grace-days')), 250,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('task-editor-scroll')),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.byKey(const ValueKey('grace-days')));
    await tester.pumpAndSettle();
    expect(find.text('Up to 2 days late'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grace-days')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Up to 3 days late').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('due-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('due-time')));
    await tester.pumpAndSettle();
    final inputs = find.descendant(
        of: find.byType(TimePickerDialog), matching: find.byType(TextField));
    expect(inputs, findsNWidgets(2));
    await tester.enterText(inputs.at(0), '18');
    await tester.enterText(inputs.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('appearance-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-time')));
    await tester.pumpAndSettle();
    await tester.enterText(inputs.at(0), '09');
    await tester.enterText(inputs.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = AppStorage(prefs).loadTasks().single;
    expect(saved.timing.graceDays, 3);
    expect(saved.timing.showDaysBefore, 1);
    expect(saved.timing.showMinute, 570);
    expect(saved.timing.dueMinute, 1110);
    expect(find.textContaining('Okay through Oct 31 at 18:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('future task stays out of Today and is visible in Upcoming',
      (tester) async {
    final task = _task().copyWith(
        schedule: ScheduleWeekly(
            intervalWeeks: 1,
            daysOfWeek: [5],
            firstDueDate: DateTime(2026, 10, 30)),
        timing: const TaskTiming(showMinute: 540));
    await _pump(tester, [task]);
    expect(find.text('Weekly review'), findsNothing);
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly review'), findsOneWidget);
    expect(find.textContaining('Appears Oct 30 at 09:00'), findsOneWidget);
    expect(find.text('Complete'), findsNothing);
  });

  testWidgets(
      'phone cards and history fit long names and larger text in dark mode',
      (tester) async {
    final task =
        _task(name: 'Review the weekly plan and prepare next week’s priorities')
            .copyWith(
                schedule: ScheduleWeekly(
                    intervalWeeks: 1,
                    daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
                    firstDueDate: DateTime(2026, 10, 26)));
    await _pump(tester, [task],
        width: 320, scale: 1.5, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
