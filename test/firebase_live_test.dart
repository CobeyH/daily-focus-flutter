import 'package:daily_focus/config/firebase_config.dart';
import 'package:daily_focus/models/active_timer.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_entry.dart';
import 'package:daily_focus/storage/firebase_auth_client.dart';
import 'package:daily_focus/storage/firebase_storage.dart';
import 'package:daily_focus/storage/remote_storage.dart';
import 'package:firedart/firedart.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opt-in deployment smoke test. Creates and removes its own disposable user.
void main() {
  test('live Firebase email auth, rules and realtime sync', () async {
    final auth = FirebaseAuth(FirebaseConfig.apiKey, VolatileStore(),
        httpClient: FirebaseAuthClient());
    final remote = FirebaseStorage(
        auth: auth,
        firestore: Firestore(
          FirebaseConfig.projectId,
          authenticator: (metadata, _) async {
            metadata['authorization'] =
                'Bearer ${await auth.tokenProvider.idToken}';
          },
        ));
    final task = Task.create(
        name: 'Migration verification',
        type: TaskType.minutes,
        goal: 60,
        step: 1,
        color: 0xff5c6bc0,
        icon: 0xe0b0);
    try {
      await remote.signUp(
          email: 'migration-${task.id}@example.invalid',
          password: '${task.id}-temporary');
      expect((await remote.observeChanges().first).tasks, isEmpty);
      final updated = remote.observeChanges().firstWhere((snapshot) =>
          snapshot.tasks.length == 1 &&
          snapshot.entries.length == 1 &&
          snapshot.timers.length == 1);
      await remote.push(
          snapshot: RemoteSnapshot(tasks: [
        task
      ], entries: [
        TaskEntry(taskId: task.id, dateKey: '2026-10-27', progress: 10),
      ], timers: [
        ActiveTimer.start(task, now: DateTime.now().toUtc())
      ]));
      expect((await updated).tasks.single.name, task.name);
      expect((await remote.pull()).entries.single.progress, 10);
      final unauthenticated = Firestore(FirebaseConfig.projectId);
      try {
        await expectLater(
            unauthenticated
                .document('users/${auth.userId}/tasks/${task.id}')
                .get(),
            throwsA(anything));
      } finally {
        unauthenticated.close();
      }
    } finally {
      try {
        if (auth.isSignedIn) await remote.deleteTasks([task.id]);
      } finally {
        if (auth.isSignedIn) await auth.deleteAccount();
        await remote.dispose();
      }
    }
  },
      skip: !const bool.fromEnvironment('FIREBASE_LIVE_TEST'),
      timeout: const Timeout(Duration(minutes: 2)));
}
