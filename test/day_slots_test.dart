import 'package:daily_focus/models/day_slots.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/models/task_occurrence.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/providers/day_slots_provider.dart';
import 'package:daily_focus/screens/home_screen.dart';
import 'package:daily_focus/screens/task_card.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('slots resolve on the first appearance day, not each following day', () {
    const timing = TaskTiming(
        slot: DaySlot.evening, showDaysBefore: 1, visibleDaysAfter: 2);
    final due = DateTime(2026, 11, 13);
    expect(timing.appearsAt(due), DateTime(2026, 11, 12, 18));
    expect(timing.appearsAt(due, const DaySlots(evening: 1140)),
        DateTime(2026, 11, 12, 19));
    expect(
        timing.visibilityEnded(due, DateTime(2026, 11, 15, 23, 59)), isFalse);
    expect(timing.visibilityEnded(due, DateTime(2026, 11, 16)), isTrue);
    final task = Task.create(
        name: 'Review',
        type: TaskType.count,
        goal: 1,
        step: 1,
        color: 0,
        icon: 0,
        timing: timing);
    expect(TaskOccurrence(task, due, null, DateTime(2026, 11, 13, 7)).visible,
        isTrue);
    expect(TaskOccurrence(task, due, null, DateTime(2026, 11, 13, 23)).visible,
        isTrue);
    expect(TaskTiming.fromJson(timing.toJson()).slot, DaySlot.evening);
    expect(TaskTiming.fromJson(timing.toJson()).visibleDaysAfter, 2);
    final legacy = TaskTiming.fromJson({'showMinute': 555});
    expect(legacy.slot, isNull);
    expect(legacy.startMinute(const DaySlots()), 555);
    expect(legacy.visibleDaysAfter, isNull);
  });

  test('slot ordering and due-time validation use configured start times', () {
    expect(const DaySlots(morning: 800).isValid, isFalse);
    expect(const DaySlots(afternoon: 1080).isValid, isFalse);
    const timing = TaskTiming(slot: DaySlot.afternoon, dueMinute: 750);
    expect(timing.isValidFor(const DaySlots()), isTrue);
    expect(timing.isValidFor(const DaySlots(afternoon: 780)), isFalse);
  });

  test('global slot settings persist and invalid settings cannot replace them',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer open() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    final first = open();
    await first
        .read(daySlotsProvider.notifier)
        .save(const DaySlots(morning: 420, afternoon: 780, evening: 1140));
    first.dispose();
    final restored = open();
    addTearDown(restored.dispose);
    expect(restored.read(daySlotsProvider).afternoon, 780);
    await expectLater(
        restored
            .read(daySlotsProvider.notifier)
            .save(const DaySlots(evening: 500)),
        throwsArgumentError);
    expect(restored.read(daySlotsProvider).evening, 1140);
  });

  testWidgets(
      'morning remains actionable in afternoon; evening moves from Upcoming at its boundary',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 11, 13, 13);
    final tasks = [
      for (final slot in DaySlot.values)
        Task(
            id: slot.name,
            name: slot.label,
            type: TaskType.count,
            goal: 1,
            step: 1,
            color: 0xff247866,
            icon: Icons.check.codePoint,
            createdAt: DateTime(2026, 11, 12),
            timing: TaskTiming(slot: slot))
    ];
    await AppStorage(prefs).saveTasks(tasks);
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => now)
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    Finder card(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(TaskCard));
    expect(
        find.descendant(of: card('Morning'), matching: find.text('Complete')),
        findsOneWidget);
    expect(
        find.descendant(of: card('Afternoon'), matching: find.text('Complete')),
        findsOneWidget);
    expect(
        find.descendant(of: card('Evening'), matching: find.text('Complete')),
        findsNothing);
    expect(tester.getTopLeft(find.text('Evening')).dy,
        greaterThan(tester.getTopLeft(find.text('Upcoming tasks')).dy));
    now = DateTime(2026, 11, 13, 18);
    container.invalidate(clockProvider);
    await tester.pumpAndSettle();
    expect(find.text('Upcoming tasks'), findsNothing);
    expect(
        find.descendant(of: card('Evening'), matching: find.text('Complete')),
        findsOneWidget);
    // A global change reclassifies existing tasks without editing them.
    await tester.tap(find.byTooltip('Time slots'));
    await tester.pumpAndSettle();
    Future<void> setEvening(String current, String hour) async {
      await tester.tap(find.widgetWithText(OutlinedButton, current));
      await tester.pumpAndSettle();
      final inputs = find.descendant(
          of: find.byType(TimePickerDialog), matching: find.byType(TextField));
      await tester.enterText(inputs.at(0), hour);
      await tester.enterText(inputs.at(1), '00');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    await setEvening('18:00', '10');
    await tester.tap(find.text('Save time slots'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Morning, Afternoon, Evening order'),
        findsOneWidget);
    expect(container.read(daySlotsProvider).evening, 1080);
    await setEvening('10:00', '19');
    await tester.tap(find.text('Save time slots'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming tasks'), findsOneWidget);
    expect(
        find.descendant(of: card('Evening'), matching: find.text('Complete')),
        findsNothing);
    expect(AppStorage(prefs).loadTasks().last.timing.slot, DaySlot.evening);
    expect(tester.takeException(), isNull);
  });
}
