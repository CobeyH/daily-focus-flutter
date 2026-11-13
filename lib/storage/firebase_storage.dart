import '../models/forest.dart';
import 'dart:async';
import 'dart:convert';

import 'package:firedart/firedart.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/firebase_config.dart';
import '../models/active_timer.dart';
import '../models/task.dart';
import '../models/task_entry.dart';
import '../services/google_sign_in_service.dart';
import 'firebase_auth_client.dart';
import 'firebase_token_store.dart';
import 'firestore_watch.dart';
import 'remote_storage.dart';

/// Firebase Auth and Firestore client shared by Android and Linux.
/// Each user's collections live under users/{Firebase Auth UID}.
class FirebaseStorage implements RemoteStorage {
  final FirebaseAuth auth;
  final Firestore firestore;
  final FirebaseTokenStore? _tokenStore;
  final Future<String> Function() _googleSignIn;
  final http.Client _http;
  final String projectId;
  final Emulator? emulator;
  FirestoreWatch? _watch;
  bool _disposed = false;
  final _authStates = StreamController<bool>.broadcast();
  late final StreamSubscription<bool> _authSubscription;

  FirebaseStorage({
    required this.auth,
    required this.firestore,
    FirebaseTokenStore? tokenStore,
    Future<String> Function()? googleSignIn,
    http.Client? httpClient,
    this.projectId = FirebaseConfig.projectId,
    this.emulator,
  })  : _tokenStore = tokenStore,
        _googleSignIn = googleSignIn ?? const GoogleSignInService().signIn,
        _http = httpClient ?? http.Client() {
    _authSubscription = auth.signInState.listen(
      _authStates.add,
      onError: _authStates.addError,
    );
  }

  static Future<FirebaseStorage> open() async {
    final store = await FirebaseTokenStore.open();
    final auth = FirebaseAuth(FirebaseConfig.apiKey, store,
        httpClient: FirebaseAuthClient());
    return FirebaseStorage(
      auth: auth,
      tokenStore: store,
      firestore: Firestore(
        FirebaseConfig.projectId,
        authenticator: (metadata, _) async {
          metadata['authorization'] =
              'Bearer ${await auth.tokenProvider.idToken}';
        },
      ),
    );
  }

  @override
  bool get isSignedIn => auth.isSignedIn;

  @override
  String? get currentUserEmail {
    final token = _tokenStore?.idToken;
    if (token == null) return null;
    try {
      final payload = jsonDecode(utf8.decode(
        base64Url.decode(base64Url.normalize(token.split('.')[1])),
      )) as Map<String, dynamic>;
      // Display only; Firestore authorizes requests using the verified token.
      return payload['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<bool> observeAuthState() => Stream<bool>.multi((controller) {
        final subscription = _authStates.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.add(isSignedIn);
        controller.onCancel = subscription.cancel;
      });

  Future<void> _persist() async => _tokenStore?.flush();

  @override
  Future<void> signInAnonymously() async {
    if (isSignedIn) return;
    await auth.signInAnonymously();
    await _persist();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await auth.signUp(email.trim(), password);
    await _persist();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await auth.signIn(email.trim(), password);
    await _persist();
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleIdToken = await _googleSignIn();
    final response = await _http
        .post(
          Uri.https('identitytoolkit.googleapis.com',
              '/v1/accounts:signInWithIdp', {'key': auth.apiKey}),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'postBody': Uri(queryParameters: {
              'id_token': googleIdToken,
              'providerId': 'google.com',
            }).query,
            'requestUri': 'http://localhost',
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError((body['error'] as Map?)?['message']?.toString() ??
          'Google sign-in failed. Please try again.');
    }
    auth.tokenProvider.setToken(body);
    await _persist();
  }

  @override
  Future<void> resetPassword({required String email}) =>
      auth.resetPassword(email.trim());

  @override
  Future<void> signOut() async {
    auth.signOut();
    final watch = _watch;
    _watch = null;
    watch?.close().ignore();
    await _persist();
  }

  CollectionReference _collection(String name, [String? uid]) =>
      firestore.collection('users/${uid ?? auth.userId}/$name');

  Future<List<Document>> _getAll(String name) async {
    final documents = <Document>[];
    var token = '';
    do {
      final page = await _collection(name).get(nextPageToken: token);
      documents.addAll(page);
      token = page.nextPageToken;
    } while (token.isNotEmpty);
    return documents;
  }

  RemoteSnapshot _snapshot(
          List<Map<String, dynamic>> tasks,
          List<Map<String, dynamic>> entries,
          List<Map<String, dynamic>> timers,
          List<Map<String, dynamic>> forest) =>
      RemoteSnapshot(
        forest: forest.map(ForestEvent.fromJson).toList(),
        tasks: tasks.map(Task.fromJson).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        entries: entries.map(TaskEntry.fromJson).toList(),
        timers: timers.map(ActiveTimer.fromJson).toList(),
      );

  @override
  Future<RemoteSnapshot> pull() async {
    final collections = await Future.wait([
      _getAll('tasks'),
      _getAll('entries'),
      _getAll('active_timers'),
      _getAll('forest'),
    ]);
    return _snapshot(
        collections[0].map((d) => d.map).toList(),
        collections[1].map((d) => d.map).toList(),
        collections[2].map((d) => d.map).toList(),
        collections[3].map((d) => d.map).toList());
  }

  static String _entryId(String taskId, String dateKey) => '${taskId}_$dateKey';

  @override
  Future<void> push({required RemoteSnapshot snapshot}) async {
    // Stable document IDs make retries idempotent. Existing local data is
    // uploaded after the first Firebase sign-in without changing its format.
    for (final event in snapshot.forest) {
      await _collection('forest').document(event.id).set(event.toJson());
    }
    for (final task in snapshot.tasks) {
      await _collection('tasks').document(task.id).set(task.toJson());
    }
    for (final entry in snapshot.entries) {
      await _collection('entries')
          .document(_entryId(entry.taskId, entry.dateKey))
          .set(entry.toJson());
    }
    for (final timer in snapshot.timers) {
      await _collection('active_timers')
          .document(timer.taskId)
          .set(timer.toJson());
    }
  }

  @override
  Future<void> deleteTasks(List<String> taskIds) async {
    // Firestore has no SQL foreign-key cascade, so delete dependents explicitly.
    for (final taskId in taskIds) {
      final entries =
          await _collection('entries').where('taskId', isEqualTo: taskId).get();
      for (final entry in entries) {
        await entry.reference.delete();
      }
      await _collection('active_timers').document(taskId).delete();
      await _collection('tasks').document(taskId).delete();
    }
  }

  @override
  Future<void> deleteEntries(
      List<({String taskId, String dateKey})> keys) async {
    for (final key in keys) {
      await _collection('entries')
          .document(_entryId(key.taskId, key.dateKey))
          .delete();
    }
  }

  @override
  Stream<RemoteSnapshot> observeChanges() async* {
    final uid = auth.userId;
    final watch = _watch ??= FirestoreWatch(
        projectId, () => auth.tokenProvider.idToken,
        emulator: emulator);
    while (!_disposed && isSignedIn && auth.userId == uid) {
      try {
        await for (final snapshot in watch.snapshots(uid)) {
          yield _snapshot(snapshot.tasks, snapshot.entries, snapshot.timers,
              snapshot.forest);
        }
      } catch (error) {
        debugPrint('Firebase sync reconnecting: $error');
      }
      if (!_disposed && isSignedIn && auth.userId == uid) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _watch?.close();
    await _persist();
    await _authSubscription.cancel();
    await _authStates.close();
    firestore.close();
    auth.close();
    _http.close();
  }
}
