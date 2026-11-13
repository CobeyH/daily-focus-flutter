import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_entry.dart';
import 'package:daily_focus/models/task_occurrence.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'multi-step progress survives reload, undo, definition edits, and the next cycle',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 11, 13, 13);
    var task = Task(
        id: 'laundry',
        name: 'Laundry',
        type: TaskType.multiStep,
        steps: const ['Wash laundry', 'Dry laundry', 'Fold laundry'],
        goal: 99,
        step: 5,
        color: 0,
        icon: 0,
        createdAt: DateTime(2026, 11, 12));
    await AppStorage(prefs).saveTasks([task]);
    ProviderContainer open() => ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeSourceProvider.overrideWithValue(() => now)
        ]);
    var container = open();
    expect(task.goal, 3);
    await container
        .read(appControllerProvider.notifier)
        .increment(task, now: now);
    expect(AppStorage(prefs).loadEntries().single.progress, 1,
        reason: 'Exactly one named step, regardless of count step size');
    container.dispose();
    container = open();
    addTearDown(container.dispose);
    task = AppStorage(prefs).loadTasks().single;
    expect(task.type, TaskType.multiStep);
    expect(task.steps, ['Wash laundry', 'Dry laundry', 'Fold laundry']);
    var occurrence = currentOccurrence(
        task, container.read(appControllerProvider).entries, now)!;
    expect(occurrence.steps[occurrence.progress], 'Dry laundry');
    expect(occurrence.done, isFalse);
    final controller = container.read(appControllerProvider.notifier);
    await controller.increment(task, now: now);
    // Edit the definition mid-cycle: the in-progress occurrence keeps its list.
    task = task.copyWith(steps: ['Wash clothes', 'Air dry']);
    await controller.updateTask(task);
    occurrence = currentOccurrence(
        task, container.read(appControllerProvider).entries, now)!;
    expect(occurrence.goal, 3);
    expect(occurrence.steps[occurrence.progress], 'Fold laundry');
    expect(occurrence.done, isFalse);
    expect(
        container
            .read(appControllerProvider)
            .entries
            .single
            .isComplete(task.goal),
        isFalse);
    await controller.increment(task, now: now);
    expect(
        container.read(appControllerProvider).entries.single.completedGoal, 3);
    expect(
        currentOccurrence(
                task, container.read(appControllerProvider).entries, now)!
            .done,
        isTrue);
    await controller.undoCompletion(task, occurrenceKey: '2026-11-13');
    expect(container.read(appControllerProvider).entries.single.progress, 2);
    await controller.decrement(task, now: now);
    expect(container.read(appControllerProvider).entries.single.progress, 1);
    final tomorrow = currentOccurrence(
        task,
        container.read(appControllerProvider).entries,
        DateTime(2026, 11, 14, 13))!;
    expect(tomorrow.progress, 0);
    expect(tomorrow.steps, ['Wash clothes', 'Air dry']);
    final roundTrip =
        TaskEntry.fromJson(AppStorage(prefs).loadEntries().single.toJson());
    expect(roundTrip.steps, ['Wash laundry', 'Dry laundry', 'Fold laundry']);
  });
}
