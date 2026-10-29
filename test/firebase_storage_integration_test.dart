import 'dart:convert';

import 'package:daily_focus/models/active_timer.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_timing.dart';
import 'package:daily_focus/models/task_entry.dart';
import 'package:daily_focus/storage/firebase_storage.dart';
import 'package:daily_focus/storage/firebase_auth_client.dart';
import 'package:daily_focus/storage/remote_storage.dart';
import 'package:firedart/firedart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _enabled = bool.fromEnvironment('FIREBASE_EMULATOR_TEST');
const _project = 'demo-daily-focus';
const _password = 'emulator-only-password';

class _AuthEmulatorClient extends http.BaseClient {
  final _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final rewritten = http.Request(
      request.method,
      Uri.parse('http://127.0.0.1:9099/${request.url.host}${request.url.path}')
          .replace(query: request.url.query),
    )..headers.addAll(request.headers);
    if (request is http.Request) rewritten.bodyBytes = request.bodyBytes;
    return _client.send(rewritten);
  }

  @override
  void close() => _client.close();
}

FirebaseStorage _client({Future<String> Function()? googleSignIn}) {
  final auth = FirebaseAuth('fake-api-key', VolatileStore(),
      httpClient: FirebaseAuthClient(inner: _AuthEmulatorClient()));
  return FirebaseStorage(
    auth: auth,
    googleSignIn: googleSignIn,
    httpClient: _AuthEmulatorClient(),
    projectId: _project,
    emulator: Emulator('127.0.0.1', 8080),
    firestore: Firestore(
      _project,
      emulator: Emulator('127.0.0.1', 8080),
      authenticator: (metadata, _) async {
        metadata['authorization'] =
            'Bearer ${await auth.tokenProvider.idToken}';
      },
    ),
  );
}

void main() {
  group('Firebase Auth and Firestore emulator', () {
    late FirebaseStorage first;
    late FirebaseStorage second;
    late FirebaseStorage otherUser;
    late String email;

    setUp(() async {
      first = _client();
      second = _client();
      otherUser = _client();
      email = 'sync-${DateTime.now().microsecondsSinceEpoch}@example.test';
      await first.signUp(email: email, password: _password);
      await second.signIn(email: email, password: _password);
      await otherUser.signUp(email: 'other-$email', password: _password);
    });

    tearDown(() async {
      await first.dispose();
      await second.dispose();
      await otherUser.dispose();
    });

    test('emits an initial snapshot for an empty account', () async {
      final empty = await second
          .observeChanges()
          .first
          .timeout(const Duration(seconds: 15));
      expect(empty.tasks, isEmpty);
      expect(empty.entries, isEmpty);
      expect(empty.timers, isEmpty);
    });

    test('syncs tasks, history and active timers between devices', () async {
      final task = Task.create(
        name: 'Read',
        type: TaskType.minutes,
        goal: 600,
        step: 1,
        color: 0xff5c6bc0,
        icon: 0xe0b0,
        timing: const TaskTiming(
            showDaysBefore: 1, showMinute: 540, dueMinute: 1080, graceDays: 2),
      );
      final entry = TaskEntry(
          taskId: task.id,
          dateKey: '2026-10-27',
          progress: 60,
          updatedAt: DateTime.utc(2026, 10, 28),
          completedAt: DateTime.utc(2026, 10, 28),
          completionTiming: 'grace',
          completedGoal: 60,
          previousProgress: 0);
      final timer = ActiveTimer.start(task,
          now: DateTime.utc(2026, 10, 27), occurrenceKey: '2026-10-27');
      final update = second
          .observeChanges()
          .firstWhere((snapshot) =>
              snapshot.tasks.length == 1 &&
              snapshot.entries.length == 1 &&
              snapshot.timers.length == 1)
          .timeout(const Duration(seconds: 15));

      await first.push(
          snapshot: RemoteSnapshot(
        tasks: [task],
        entries: [entry],
        timers: [timer],
      ));
      final observed = await update;
      expect(observed.tasks.single.toJson(), task.toJson());
      expect(observed.entries.single.toJson(), entry.toJson());
      expect(observed.timers.single.toJson(), timer.toJson());

      // Updating an existing document must not duplicate it.
      await first.push(
          snapshot: RemoteSnapshot(
        tasks: [task.copyWith(name: 'Read a book')],
        entries: [entry.copyWith(progress: 120)],
        timers: [timer],
      ));
      final pulled = await second.pull();
      expect(pulled.tasks.single.name, 'Read a book');
      expect(pulled.entries.single.progress, 120);

      await first.deleteEntries([(taskId: task.id, dateKey: entry.dateKey)]);
      expect((await second.pull()).entries, isEmpty);
      await first.push(
          snapshot: RemoteSnapshot(tasks: [], entries: [entry], timers: []));
      await first.deleteTasks([task.id]);
      final deleted = await second.pull();
      expect(deleted.tasks, isEmpty);
      expect(deleted.entries, isEmpty);
      expect(deleted.timers, isEmpty);
    });

    test('rules reject another user and malformed documents', () async {
      final uid = first.auth.userId;
      final task = Task.create(
          name: 'Private',
          type: TaskType.count,
          goal: 1,
          step: 1,
          color: 0xff000000,
          icon: 0xe0b0);
      await first.push(
          snapshot: RemoteSnapshot(tasks: [task], entries: [], timers: []));
      expect((await otherUser.pull()).tasks, isEmpty);
      await expectLater(
          otherUser.firestore.document('users/$uid/tasks/${task.id}').get(),
          throwsA(anything));
      await expectLater(
          otherUser.firestore.document('users/$uid/tasks/${task.id}').delete(),
          throwsA(anything));
      await expectLater(
          first.firestore
              .document('users/$uid/tasks/wrong-id')
              .set(task.toJson()),
          throwsA(anything));
      final unauthenticated =
          Firestore(_project, emulator: Emulator('127.0.0.1', 8080));
      try {
        await expectLater(
            unauthenticated.document('users/$uid/tasks/${task.id}').get(),
            throwsA(anything));
      } finally {
        unauthenticated.close();
      }
    });

    test('auth listeners receive the current state and sign-out', () async {
      expect(await first.observeAuthState().first, isTrue);
      final signedOut = first.observeAuthState().firstWhere((value) => !value);
      await first.signOut();
      expect(await signedOut.timeout(const Duration(seconds: 2)), isFalse);
      expect(first.isSignedIn, isFalse);
    });
    test('exchanges a Google credential for a Firebase session', () async {
      String encode(Map<String, dynamic> data) =>
          base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
      // The emulator accepts unsigned provider tokens. Production Firebase
      // validates Google's signature and audience before issuing a session.
      final token = '${encode({'alg': 'none'})}.${encode({
            'sub': 'google-${DateTime.now().microsecondsSinceEpoch}',
            'email': 'google-$email',
            'email_verified': true,
            'iss': 'https://accounts.google.com',
            'aud': 'emulator-client',
            'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          })}.';
      final google = _client(googleSignIn: () async => token);
      try {
        await google.signInWithGoogle();
        expect(google.isSignedIn, isTrue);
        expect((await google.auth.getUser()).email, 'google-$email');
        expect((await google.pull()).tasks, isEmpty);
      } finally {
        await google.dispose();
      }
    });
  }, skip: !_enabled);
}
