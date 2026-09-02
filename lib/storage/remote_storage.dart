import 'dart:async';

import '../models/active_timer.dart';
import '../models/task.dart';
import '../models/task_entry.dart';

/// A complete snapshot of a user's data, used to reconcile local and remote
/// state during a sync.
class RemoteSnapshot {
  final List<Task> tasks;
  final List<TaskEntry> entries;
  final List<ActiveTimer> timers;

  const RemoteSnapshot({
    required this.tasks,
    required this.entries,
    required this.timers,
  });
}

/// Cross-device persistence for a signed-in user.
///
/// The app is local-first: [AppStorage] (SharedPreferences) serves synchronous
/// reads for an instant UI, and a [RemoteStorage] implementation mirrors those
/// writes to a backend so the same data is available on other devices.
///
/// Implementations must be idempotent and safe to call repeatedly.
abstract class RemoteStorage {
  /// Whether a user is currently signed in (and remote writes are possible).
  bool get isSignedIn;

  /// The email of the signed-in user, if any.
  String? get currentUserEmail;

  /// Emits auth state changes (sign-in, sign-out, session refresh). Emits
  /// immediately on listen with the current state.
  Stream<bool> observeAuthState();

  /// Signs in the user anonymously so they can persist data without creating
  /// an account. No-op if already signed in.
  Future<void> signInAnonymously();

  /// Creates a new email/password account and signs in. Throws on failure
  /// (e.g. email already registered).
  Future<void> signUp({required String email, required String password});

  /// Signs in an existing email/password account. Throws on failure
  /// (e.g. wrong credentials — or the email hasn't been verified yet).
  Future<void> signIn({required String email, required String password});

  /// Signs out the current user. Safe to call when not signed in.
  Future<void> signOut();

  /// Pulls the user's full data from the remote. Throws on failure.
  Future<RemoteSnapshot> pull();

  /// Pushes the user's full data to the remote (upsert semantics).
  ///
  /// Rows not present in [tasks]/[entries]/[timers] are *not* deleted here;
  /// callers that need deletions should use [deleteTasks]/[deleteEntries].
  Future<void> push({required RemoteSnapshot snapshot});

  /// Deletes the given task ids (and cascade deletes their entries/timers on
  /// the backend).
  Future<void> deleteTasks(List<String> taskIds);

  /// Deletes the given entry ids (task_id + date_key pairs).
  Future<void> deleteEntries(List<({String taskId, String dateKey})> keys);

  /// Emits snapshots whenever the remote data changes (e.g. due to another
  /// device). Subscribes to the appropriate channels; returns a cancelable
  /// subscription.
  Stream<RemoteSnapshot> observeChanges();
}
