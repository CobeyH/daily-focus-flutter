import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/active_timer.dart';
import '../models/task.dart';
import '../models/task_entry.dart';
import 'remote_storage.dart';

/// Supabase-backed [RemoteStorage].
///
/// Mirrors the app's local model into three Postgres tables (`tasks`,
/// `entries`, `active_timers`) — see `docs/supabase_schema.sql`. Each table is
/// scoped by `user_id` and protected by row-level security using the signed-in
/// user's JWT.
///
/// Changes are pushed via `upsert` and observed via Realtime postgres changes,
/// so edits on one device propagate to others.
class SupabaseStorage implements RemoteStorage {
  SupabaseStorage();

  static const _mobileOAuthRedirect = 'com.dailyfocus.app://login-callback';
  static const _linuxCallbackPath = '/auth/callback';
  static const _oauthTimeout = Duration(minutes: 5);

  /// Whether we've successfully subscribed to realtime changes for this user.
  bool _subscribed = false;
  final _controller = StreamController<RemoteSnapshot>.broadcast();

  @override
  bool get isSignedIn => Supabase.instance.client.auth.currentUser != null;

  @override
  String? get currentUserEmail =>
      Supabase.instance.client.auth.currentUser?.email;

  @override
  Stream<bool> observeAuthState() {
    late final StreamController<bool> broadcast;
    broadcast = StreamController<bool>.broadcast(
      onListen: () {
        broadcast.add(isSignedIn);
      },
    );
    _client.auth.onAuthStateChange.listen((state) {
      // Any auth event (signed in/out, token refresh) → re-evaluate signed-in.
      broadcast.add(isSignedIn);
    });
    return broadcast.stream;
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// The current user's id (assumes signed-in).
  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<void> signInAnonymously() async {
    if (isSignedIn) return;
    await _client.auth.signInAnonymously();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signInWithGoogle() async {
    if (Platform.isLinux) {
      await _signInWithGoogleOnLinux();
      return;
    }

    // Subscribe before launching the browser so a fast callback cannot be
    // missed. supabase_flutter receives the custom-scheme deep link and
    // exchanges its PKCE code for a persisted session.
    final signedIn = _client.auth.onAuthStateChange.firstWhere(
      (state) =>
          state.event == AuthChangeEvent.signedIn && state.session != null,
    );
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _mobileOAuthRedirect,
    );
    if (!launched) {
      throw StateError('Could not open the browser for Google sign-in.');
    }
    await signedIn.timeout(_oauthTimeout);
  }

  /// Linux does not have an application URL-scheme registration during
  /// `flutter run`, so use a short-lived loopback callback instead. PKCE binds
  /// the returned authorization code to this client before a session is made.
  Future<void> _signInWithGoogleOnLinux() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectTo = Uri(
      scheme: 'http',
      host: 'localhost',
      port: server.port,
      path: _linuxCallbackPath,
    );

    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo.toString(),
      );
      if (!launched) {
        throw StateError('Could not open the browser for Google sign-in.');
      }

      final request = await server
          .where((request) => request.uri.path == _linuxCallbackPath)
          .first
          .timeout(_oauthTimeout);

      try {
        await _client.auth.getSessionFromUrl(request.requestedUri);
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html><body style="font-family: sans-serif; text-align: center; padding: 3rem">
  <h1>Signed in to Daily Focus</h1>
  <p>You can close this tab and return to the app.</p>
</body></html>
''');
        await request.response.close();
      } catch (error) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
<!doctype html>
<html><body style="font-family: sans-serif; text-align: center; padding: 3rem">
  <h1>Sign-in failed</h1>
  <p>Return to Daily Focus and try again.</p>
</body></html>
''');
        await request.response.close();
        rethrow;
      }
    } finally {
      await server.close(force: true);
    }
  }

  @override
  Future<void> signOut() async {
    if (isSignedIn) {
      await _client.auth.signOut();
    }
  }

  // ---- Helpers --------------------------------------------------------------

  Map<String, dynamic> _taskRow(Task t) => {
        'id': t.id,
        'user_id': _userId,
        'payload': jsonEncode(t.toJson()),
      };

  Map<String, dynamic> _entryRow(TaskEntry e) => {
        'task_id': e.taskId,
        'date_key': e.dateKey,
        'progress': e.progress,
        'user_id': _userId,
      };

  Map<String, dynamic> _timerRow(ActiveTimer t) => {
        'id': t.taskId,
        'payload': jsonEncode(t.toJson()),
        'user_id': _userId,
      };

  // ---- RemoteStorage --------------------------------------------------------

  @override
  Future<RemoteSnapshot> pull() async {
    // Entries reference tasks by id; resolve payloads for each table.
    final tasksRows = await _client
        .from('tasks')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    final entriesRows =
        await _client.from('entries').select().eq('user_id', _userId);
    final timersRows =
        await _client.from('active_timers').select().eq('user_id', _userId);

    final tasks = <Task>[];
    for (final row in tasksRows) {
      final payload = row['payload'];
      final json = payload is String
          ? jsonDecode(payload) as Map<String, dynamic>
          : (payload as Map<String, dynamic>);
      // Reinsert the id primary key since Task.fromJson reads `id`.
      json['id'] = row['id'];
      tasks.add(Task.fromJson(json));
    }

    final entries = <TaskEntry>[
      for (final row in entriesRows)
        TaskEntry(
          taskId: row['task_id'] as String,
          dateKey: row['date_key'] as String,
          progress: (row['progress'] as num).toInt(),
        ),
    ];

    final timers = <ActiveTimer>[];
    for (final row in timersRows) {
      final payload = row['payload'];
      final json = payload is String
          ? jsonDecode(payload) as Map<String, dynamic>
          : (payload as Map<String, dynamic>);
      timers.add(ActiveTimer.fromJson(json));
    }

    return RemoteSnapshot(tasks: tasks, entries: entries, timers: timers);
  }

  @override
  Future<void> push({required RemoteSnapshot snapshot}) async {
    // Upsert entire collections. Rows that exist are updated; new ones are
    // inserted. Deletions are handled separately via deleteTasks/deleteEntries.
    if (snapshot.tasks.isNotEmpty) {
      await _client.from('tasks').upsert(snapshot.tasks.map(_taskRow).toList());
    }
    if (snapshot.entries.isNotEmpty) {
      await _client.from('entries').upsert(
          snapshot.entries.map(_entryRow).toList(),
          onConflict: 'user_id, task_id, date_key');
    }
    if (snapshot.timers.isNotEmpty) {
      await _client.from('active_timers').upsert(
          snapshot.timers.map(_timerRow).toList(),
          onConflict: 'user_id, id');
    }
  }

  @override
  Future<void> deleteTasks(List<String> taskIds) async {
    for (final id in taskIds) {
      await _client.from('tasks').delete().eq('id', id).eq('user_id', _userId);
      // entries.active_timers cascade via FK on delete cascade.
    }
  }

  @override
  Future<void> deleteEntries(
      List<({String taskId, String dateKey})> keys) async {
    for (final key in keys) {
      await _client
          .from('entries')
          .delete()
          .eq('task_id', key.taskId)
          .eq('date_key', key.dateKey)
          .eq('user_id', _userId);
    }
  }

  @override
  Stream<RemoteSnapshot> observeChanges() {
    _ensureSubscribed();
    return _controller.stream;
  }

  /// Subscribes to Realtime postgres changes on all three tables for this user.
  void _ensureSubscribed() {
    if (_subscribed) return;
    _subscribed = true;

    void onChanged(String table) {
      // Debounce: realtime may deliver row-by-row events; re-pull the whole
      // snapshot instead so consumers always get a consistent view.
      pull().then(_controller.add).catchError((Object e, StackTrace s) {});
    }

    final channel = _client.channel('daily-focus-sync');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (_) => onChanged('tasks'),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'entries',
          callback: (_) => onChanged('entries'),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'active_timers',
          callback: (_) => onChanged('active_timers'),
        )
        .subscribe();
  }
}
