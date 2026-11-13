import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/providers/forest_provider.dart';
import 'package:daily_focus/screens/home_screen.dart';
import 'package:daily_focus/screens/task_card.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/widgets/task_completion_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 11, 13, 13);
Task _task({int goal = 1, TaskType type = TaskType.count}) => Task(
    id: 'laundry',
    name: 'Laundry',
    type: type,
    steps: type == TaskType.multiStep ? const ['Wash', 'Dry'] : const [],
    goal: goal,
    step: 1,
    color: 0xff247866,
    icon: Icons.local_laundry_service.codePoint,
    createdAt: DateTime(2026, 11, 12));
Future<ProviderContainer> _pump(WidgetTester tester, Task task,
    {bool reduced = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await AppStorage(prefs).saveTasks([task]);
  tester.view.physicalSize = const Size(390, 950);
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
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!),
          home: const HomeScreen())));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

void main() {
  testWidgets(
      'card shrinks, water flies to the app-bar forest, and undo cannot award another drop',
      (tester) async {
    final container = await _pump(tester, _task());
    final cardBounds = tester.getRect(find.byType(TaskCard));
    final destination = tester.getCenter(find.byTooltip('Your forest'));
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.byTooltip('Your forest')),
        findsOneWidget);
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(find.byType(TaskCompletionExit), findsOneWidget);
    expect(find.byType(CompletionWaterFlight), findsOneWidget);
    final flight = tester
        .widget<CompletionWaterFlight>(find.byType(CompletionWaterFlight));
    expect(cardBounds.contains(flight.start), isTrue);
    expect((flight.end - destination).distance, lessThan(1));
    final initialHeight =
        tester.getSize(find.byType(TaskCompletionExit)).height;
    final initialDrop = tester.getCenter(find.byIcon(Icons.water_drop_rounded));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getSize(find.byType(TaskCompletionExit)).height,
        lessThan(initialHeight));
    expect(tester.getCenter(find.byIcon(Icons.water_drop_rounded)),
        isNot(initialDrop));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCompletionExit), findsNothing);
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(container.read(forestProvider).water, 1);
    await tester.tap(find.text('Completed & skipped (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(find.byType(TaskCompletionExit), findsOneWidget);
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(container.read(forestProvider).water, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'partial multi-step progress and skips do not play reward effects',
      (tester) async {
    await _pump(tester, _task(type: TaskType.multiStep));
    await tester.tap(find.text('Complete step'));
    await tester.pumpAndSettle();
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(find.text('Next: Dry'), findsOneWidget);
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this occurrence'));
    await tester.pumpAndSettle();
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(find.byType(TaskCompletionExit), findsNothing);
  });
  testWidgets('reduced motion completes immediately with no flight or exit',
      (tester) async {
    final container = await _pump(tester, _task(), reduced: true);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(find.byType(TaskCompletionExit), findsNothing);
    expect(find.text('Completed & skipped (1)'), findsOneWidget);
    expect(container.read(forestProvider).water, 1);
  });
  testWidgets(
      'timer completion uses the same feedback and overlays clean up on disposal',
      (tester) async {
    final task = _task(type: TaskType.minutes);
    final container = await _pump(tester, task);
    await container
        .read(appControllerProvider.notifier)
        .recordTimedCompletion(task, '2026-11-13', completedAt: _now);
    await tester.pump();
    expect(find.byType(CompletionWaterFlight), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
