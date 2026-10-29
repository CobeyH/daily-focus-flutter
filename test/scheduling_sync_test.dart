import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_entry.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/storage/remote_storage.dart';
import 'package:daily_focus/storage/sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryRemote implements RemoteStorage {
  RemoteSnapshot snapshot;
  MemoryRemote(this.snapshot);
  @override
  bool get isSignedIn => true;
  @override
  Future<RemoteSnapshot> pull() async => snapshot;
  @override
  Future<void> push({required RemoteSnapshot snapshot}) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> signIn(
      {required String email, required String password}) async {}
  @override
  Stream<RemoteSnapshot> observeChanges() => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('newer undo beats older completion and survives signing in', () async {
    SharedPreferences.setMockInitialValues({});
    final local = AppStorage(await SharedPreferences.getInstance());
    final task = Task(
        id: 'review',
        createdAt: DateTime(2026, 10, 26),
        name: 'Review',
        type: TaskType.count,
        goal: 1,
        step: 1,
        color: 0,
        icon: 0);
    final before = DateTime.utc(2026, 10, 29, 10);
    final after = DateTime.utc(2026, 10, 29, 11);
    await local.saveTasks([task]);
    await local.saveEntries([
      TaskEntry(
          taskId: task.id,
          dateKey: '2026-10-28',
          progress: 1,
          updatedAt: before,
          completedAt: before)
    ]);
    final newerTask = task.copyWith(
        timing: const TaskTiming(graceDays: 2, showDaysBefore: 1),
        updatedAt: after);
    final remote = MemoryRemote(RemoteSnapshot(tasks: [
      newerTask
    ], entries: [
      TaskEntry(
          taskId: task.id, dateKey: '2026-10-28', progress: 0, updatedAt: after)
    ], timers: []));
    var reloads = 0;
    final sync = SyncCoordinator(local, remote, onLocalChanged: () async {
      reloads++;
    });
    addTearDown(sync.dispose);
    await sync.signIn(email: 'test@example.test', password: 'unused');
    expect(local.loadEntries().single.progress, 0);
    expect(remote.snapshot.entries.single.progress, 0);
    expect(local.loadTasks().single.timing.graceDays, 2);
    expect(remote.snapshot.tasks.single.timing.showDaysBefore, 1);
    await sync.pullAndMerge();
    expect(reloads, 1,
        reason:
            'Identical snapshots must not restart sync via provider invalidation.');
  });
  test('newer local undo is not replaced by a stale remote completion',
      () async {
    SharedPreferences.setMockInitialValues({});
    final local = AppStorage(await SharedPreferences.getInstance());
    await local.saveEntries([
      TaskEntry(
          taskId: 't',
          dateKey: '2026-10-28',
          progress: 0,
          updatedAt: DateTime.utc(2026, 10, 29, 11))
    ]);
    final remote = MemoryRemote(RemoteSnapshot(tasks: [], entries: [
      TaskEntry(
          taskId: 't',
          dateKey: '2026-10-28',
          progress: 1,
          updatedAt: DateTime.utc(2026, 10, 29, 10))
    ], timers: []));
    final sync = SyncCoordinator(local, remote);
    addTearDown(sync.dispose);
    await sync.pullAndMerge();
    expect(local.loadEntries().single.progress, 0);
  });
}
