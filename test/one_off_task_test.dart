import 'package:daily_focus/models/schedule.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_occurrence.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final due = DateTime(2026, 11, 13);
  test('one-off schedule has exactly one civil due date and survives JSON', () {
    final schedule = Schedule.fromJson(ScheduleOnce(dueDate: due).toJson());
    expect(schedule, isA<ScheduleOnce>());
    expect(schedule.isDueOn(DateTime(2026, 11, 13, 23)), isTrue);
    expect(schedule.isDueOn(DateTime(2026, 11, 14)), isFalse);
    expect(schedule.firstDueDateFrom(DateTime(2026, 11, 12)), due);
    expect(schedule.firstDueDateFrom(due), due);
    expect(schedule.firstDueDateFrom(DateTime(2026, 11, 14)), isNull);
    expect(schedule.nextDueDateAfter(DateTime(2026, 11, 12)), due);
    expect(schedule.nextDueDateAfter(due), isNull);
    expect(schedule.lastDueDateOnOrBefore(DateTime(2026, 11, 12)), isNull);
    expect(schedule.lastDueDateOnOrBefore(DateTime(2030)), due);
  });

  test('late completion is recorded once and never returns as another task',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final task = Task(
        id: 'one-off',
        name: 'Send application',
        type: TaskType.count,
        goal: 1,
        step: 1,
        color: 0,
        icon: 0,
        createdAt: DateTime(2026, 11, 12),
        schedule: ScheduleOnce(dueDate: due),
        timing: const TaskTiming(graceDays: 2));
    await AppStorage(prefs).saveTasks([task]);
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    final late = DateTime(2026, 11, 14, 14);
    expect(currentOccurrence(task, [], late)!.status, OccurrenceStatus.grace);
    await controller.increment(task, now: late);
    final saved = AppStorage(prefs);
    expect(saved.loadTasks().single.schedule, isA<ScheduleOnce>());
    expect(saved.loadEntries().single.dateKey, '2026-11-13');
    expect(saved.loadEntries().single.completionTiming, 'grace');
    expect(currentOccurrence(task, saved.loadEntries(), late)!.done, isTrue);
    expect(currentOccurrence(task, saved.loadEntries(), DateTime(2026, 11, 15)),
        isNull);
    expect(nextOccurrence(task, saved.loadEntries(), DateTime(2026, 11, 15)),
        isNull);
    await controller.increment(task, now: DateTime(2026, 11, 15));
    expect(saved.loadEntries(), hasLength(1));
    expect(saved.loadEntries().single.progress, 1);
    await controller.reset(task, occurrenceKey: '2026-11-13', now: late);
    expect(currentOccurrence(task, saved.loadEntries(), late)!.done, isFalse);
  });
}
