import 'package:daily_focus/models/active_timer.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/schedule.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/providers/timer_controller.dart';
import 'package:daily_focus/services/notification_service.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestNotifications extends NotificationService {
  @override
  Future<int> scheduleTaskComplete(
          {required int notificationId,
          required String taskName,
          required DateTime when}) async =>
      notificationId;
  @override
  Future<void> cancel(int notificationId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'early timer stays pinned over midnight and records actual finish after restart',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);
    var now = DateTime(2026, 10, 27, 23, 59, 30);
    final task = Task(
        id: 'timer',
        name: 'Review',
        type: TaskType.minutes,
        goal: 60,
        step: 1,
        color: 0,
        icon: 0,
        createdAt: DateTime(2026, 10, 26),
        schedule: ScheduleWeekly(
            intervalWeeks: 1,
            daysOfWeek: [3],
            firstDueDate: DateTime(2026, 10, 28)),
        timing: const TaskTiming(showDaysBefore: 1, graceDays: 2));
    await storage.saveTasks([task]);
    ProviderContainer create() => ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeSourceProvider.overrideWithValue(() => now),
          notificationServiceProvider.overrideWithValue(TestNotifications())
        ]);
    var container = create();
    await container.read(timerControllerProvider.notifier).start(task);
    expect(storage.loadActiveTimers().single.occurrenceKey, '2026-10-28');
    expect(storage.loadActiveTimers().single.startedAt, now);
    now = DateTime(2026, 10, 27, 23, 59, 40);
    await container.read(appControllerProvider.notifier).updateTask(task
        .copyWith(timing: const TaskTiming(showDaysBefore: 1, graceDays: 3)));
    expect(storage.loadActiveTimers().single.remainingAt(now),
        const Duration(seconds: 50),
        reason: 'Editing flexibility must not restart the timer.');
    container.dispose();
    now = DateTime(2026, 10, 29, 12);
    container = create();
    addTearDown(container.dispose);
    container.read(timerControllerProvider);
    // Let the automatic restart recovery finish its local writes.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final entry = storage.loadEntries().single;
    expect(entry.dateKey, '2026-10-28');
    expect(entry.completedAt, DateTime(2026, 10, 28, 0, 0, 30).toUtc());
    expect(entry.completionTiming, 'onTime');
    expect(storage.loadActiveTimers(), isEmpty);
  });
  test('pause/resume serialization preserves the occurrence', () {
    final original = ActiveTimer(
        taskId: 't',
        startedAt: DateTime(2026, 10, 27, 23),
        paused: false,
        remaining: const Duration(minutes: 2),
        updatedAt: DateTime(2026, 10, 27, 23),
        occurrenceKey: '2026-10-28');
    final paused = original.pause(DateTime(2026, 10, 27, 23, 1));
    final resumed = ActiveTimer.fromJson(paused.toJson())
        .resume(DateTime(2026, 10, 29, 12));
    expect(resumed.occurrenceKey, '2026-10-28');
    expect(resumed.remaining, const Duration(minutes: 1));
  });
}
