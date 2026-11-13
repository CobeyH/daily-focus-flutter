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

Future<void> _goToWizard(WidgetTester tester, int step) async {
  for (var i = 0;
      i < 12 && find.byKey(ValueKey('wizard-step-$step')).evaluate().isEmpty;
      i++) {
    final current = List.generate(6, (i) => i).firstWhere(
        (i) => find.byKey(ValueKey('wizard-step-$i')).evaluate().isNotEmpty);
    await tester.tap(find.text(current > step ? 'Back' : 'Continue'));
    await tester.pumpAndSettle();
  }
  expect(find.byKey(ValueKey('wizard-step-$step')), findsOneWidget);
}

Future<void> _saveWizard(WidgetTester tester) async {
  await _goToWizard(tester, 5);
  await tester.tap(find.text('Save changes'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'multi-step wizard validates names, reorders, persists, and completes each stage',
      (tester) async {
    final prefs = await _pump(tester, [], width: 320, scale: 1.5);
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Task name'), 'Laundry');
    await tester.tap(find.text('Multi-step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Name this step.'), findsNWidgets(2));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Step 1'), 'Dry laundry');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Step 2'), 'Wash laundry');
    await tester.ensureVisible(find.byTooltip('Move step 2 up'));
    await tester.tap(find.byTooltip('Move step 2 up'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Step 1'))
            .controller!
            .text,
        'Wash laundry');
    await _goToWizard(tester, 5);
    expect(find.textContaining('Wash laundry → Dry laundry'), findsOneWidget);
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    expect(AppStorage(prefs).loadTasks().single.steps,
        ['Wash laundry', 'Dry laundry']);
    expect(find.text('Next: Wash laundry'), findsOneWidget);
    await tester.tap(find.text('Complete step'));
    await tester.pumpAndSettle();
    expect(find.text('Next: Dry laundry'), findsOneWidget);
    expect(AppStorage(prefs).loadEntries().single.progress, 1);
    await tester.tap(find.text('Undo last step'));
    await tester.pumpAndSettle();
    expect(find.text('Next: Wash laundry'), findsOneWidget);
    await tester.tap(find.text('Complete step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete step'));
    await tester.pumpAndSettle();
    expect(AppStorage(prefs).loadEntries().single.isComplete(2), isTrue);
    expect(find.text('Completed & skipped (1)'), findsOneWidget);
  });

  testWidgets(
      'count selector aligns with name and never-repeat saves through the wizard',
      (tester) async {
    final prefs = await _pump(tester, []);
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextFormField, 'Task name');
    final count = find.widgetWithText(ChoiceChip, 'Count');
    expect(tester.getTopLeft(count).dx, tester.getTopLeft(name).dx);
    await tester.enterText(name, 'Send application');
    await _goToWizard(tester, 1);
    await tester.tap(find.text('Never repeat'));
    await tester.pumpAndSettle();
    final dateField = find
        .ancestor(
            of: find.text('Happens once. No new occurrence after completion.'),
            matching: find.byType(InkWell))
        .first;
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _goToWizard(tester, 5);
    expect(find.text('Never repeats'), findsOneWidget);
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    final saved = AppStorage(prefs).loadTasks().single;
    expect(saved.schedule, isA<ScheduleOnce>());
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();
    await _goToWizard(tester, 1);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Never repeat'))
            .selected,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'wizard validates, retains drafts on Back, and saves only after review',
      (tester) async {
    final prefs = await _pump(tester, []);
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wizard-step-0')), findsOneWidget);
    expect(find.textContaining('Give your task a name.'), findsWidgets);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Task name'), 'Walk outside');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Times per occurrence'), '3');
    await _goToWizard(tester, 1);
    expect(AppStorage(prefs).loadTasks(), isEmpty);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Walk outside'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await _goToWizard(tester, 5);
    expect(find.textContaining('Walk outside'), findsOneWidget);
    expect(AppStorage(prefs).loadTasks(), isEmpty);
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    expect(AppStorage(prefs).loadTasks().single.name, 'Walk outside');
    expect(AppStorage(prefs).loadTasks().single.goal, 3);
    expect(find.textContaining('in a row'), findsNothing);
  });

  testWidgets('canceling a new task leaves storage unchanged', (tester) async {
    final prefs = await _pump(tester, []);
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Task name'), 'Discard me');
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCreationScreen), findsNothing);
    expect(AppStorage(prefs).loadTasks(), isEmpty);
  });

  testWidgets('home keeps the date in the app bar and starts with task filters',
      (tester) async {
    await _pump(tester, [_task()], width: 320, scale: 1.5);
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Oct 29')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('Thursday')),
        findsOneWidget);
    expect(find.textContaining('A little progress'), findsNothing);
    expect(find.textContaining('ready for your attention'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Weekly review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chosen library icon survives saving and reopening the editor',
      (tester) async {
    final prefs = await _pump(tester, [_task()]);
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();
    await _goToWizard(tester, 2);
    await tester.tap(find.byKey(const ValueKey('appearance-slot-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evening · 18:00').last);
    await tester.pumpAndSettle();
    await _goToWizard(tester, 4);
    await tester.ensureVisible(find.byKey(const ValueKey('choose-task-icon')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('choose-task-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choose-task-icon')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('icon-search')), 'laundry');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laundry'));
    await tester.pumpAndSettle();
    await _saveWizard(tester);
    expect(AppStorage(prefs).loadTasks().single.timing.slot?.name, 'evening');
    expect(AppStorage(prefs).loadTasks().single.icon,
        Icons.local_laundry_service.codePoint);
    expect(find.byIcon(Icons.local_laundry_service), findsOneWidget);
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();
    await _goToWizard(tester, 4);
    await tester.ensureVisible(find.byKey(const ValueKey('choose-task-icon')));
    await tester.pumpAndSettle();
    expect(find.text('Laundry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task editor fits larger text on a small phone', (tester) async {
    await _pump(tester, [_task()],
        width: 320, scale: 1.5, home: TaskCreationScreen(existing: _task()));
    expect(tester.takeException(), isNull);
    await _goToWizard(tester, 3);
    await tester.ensureVisible(find.byKey(const ValueKey('grace-days')));
    await tester.pumpAndSettle();
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
    await _goToWizard(tester, 3);
    await tester.ensureVisible(find.byKey(const ValueKey('grace-days')));
    await tester.pumpAndSettle();
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
    await _goToWizard(tester, 2);
    await tester.ensureVisible(find.byKey(const ValueKey('appearance-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-time')));
    await tester.pumpAndSettle();
    await tester.enterText(inputs.at(0), '09');
    await tester.enterText(inputs.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _saveWizard(tester);
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
