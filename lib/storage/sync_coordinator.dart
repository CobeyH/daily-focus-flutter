import 'dart:async';

import '../models/active_timer.dart';
import '../models/task.dart';
import '../models/task_entry.dart';
import 'app_storage.dart';
import 'remote_storage.dart';

/// Coordinates local ([AppStorage]) and remote ([RemoteStorage]) state so the
/// user's data stays in sync across devices.
///
/// Sync policy (local-first, last-writer-wins):
///   * On startup (or sign-in), pull the remote snapshot and merge it into the
///     local store. Local wins ties (same updated_at) so a device never has to
///     "lose" its own edits.
///   * Local writes are pushed to the remote after each mutation.
///   * Remote changes (other devices) are observed and merged back into local.
///
/// The app always reads from the synchronous local store, so the UI stays
/// responsive even when offline.
class SyncCoordinator {
  final AppStorage _local;
  final RemoteStorage _remote;

  /// Optional callback invoked after local storage is updated by an inbound
  /// merge, so the UI state can be reloaded from disk. (In a Notifier this is
  /// wired to a `reloadFromStorage()`.)
  final Future<void> Function()? _onLocalChanged;

  StreamSubscription<RemoteSnapshot>? _sub;

  /// When true, an inbound-merge is in progress, so callers don't re-echo their
  /// own changes.
  bool _merging = false;

  SyncCoordinator(this._local, this._remote,
      {Future<void> Function()? onLocalChanged})
      : _onLocalChanged = onLocalChanged;

  bool get isSignedIn => _remote.isSignedIn;

  /// Ensures a user is signed in (signing in anonymously if needed), then pulls
  /// the remote snapshot and merges it into local. Idempotent — safe to call
  /// repeatedly (e.g. on every app launch).
  Future<void> ensureSignedInAndSync() async {
    if (!_remote.isSignedIn) {
      await _signInAnonymously();
    }
    await pullAndMerge();
    startObserving();
  }

  Future<void> _signInAnonymously() async {
    try {
      await _remote.signInAnonymously();
    } catch (e) {
      // If anonymous sign-in isn't enabled in the Supabase project, fall back
      // to a graceful no-op — the app remains fully usable in local mode.
    }
  }

  /// Pulls remote state and merges it into the local store. Safe to call
  /// multiple times.
  Future<void> pullAndMerge() async {
    final snapshot = await _remote.pull();
    await _mergeRemoteIntoLocal(snapshot);
  }

  /// Pushes the current local state to the remote.
  Future<void> pushLocal() async {
    await _remote.push(
      snapshot: RemoteSnapshot(
        tasks: _local.loadTasks(),
        entries: _local.loadEntries(),
        timers: _local.loadActiveTimers(),
      ),
    );
  }

  /// Deletes a task (and, via the backend cascade, its entries and timer).
  Future<void> deleteTask(String taskId) async {
    await _remote.deleteTasks([taskId]);
  }

  /// Starts observing remote changes and merging them in. Call once after
  /// sign-in.
  void startObserving() {
    _sub?.cancel();
    _sub = _remote.observeChanges().listen((snapshot) async {
      await _mergeRemoteIntoLocal(snapshot);
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }

  /// Merges [snapshot] into the local store. Only overrides local rows that are
  /// strictly older than (or missing from) the remote copy.
  ///
  /// Because the local store only keeps the latest value per key, this is a
  /// value-level merge (last-writer-wins on updated_at, local wins ties).
  Future<void> _mergeRemoteIntoLocal(RemoteSnapshot snapshot) async {
    if (_merging) return;
    _merging = true;
    try {
      final localTasks = _local.loadTasks();
      final localEntries = _local.loadEntries();
      final localTimers = _local.loadActiveTimers();

      final remoteTasksById = {for (final t in snapshot.tasks) t.id: t};
      final remoteEntries = {
        for (final e in snapshot.entries) '${e.taskId}:${e.dateKey}': e,
      };
      final remoteTimersById = {for (final t in snapshot.timers) t.taskId: t};

      // Merge tasks: union of local keys and remote keys.
      final mergedTasks = <Task>[];
      final seenTaskIds = <String>{};
      for (final local in localTasks) {
        final remote = remoteTasksById[local.id];
        if (remote == null) {
          mergedTasks.add(local); // local-only
        } else if (_isNewer(remote.createdAt, local.createdAt)) {
          mergedTasks.add(remote);
        } else {
          mergedTasks.add(local); // local wins ties
        }
        seenTaskIds.add(local.id);
      }
      for (final remote in snapshot.tasks) {
        if (!seenTaskIds.contains(remote.id)) {
          mergedTasks.add(remote); // remote-only
        }
      }

      // Merge entries: union by taskId:dateKey.
      final mergedEntries = <TaskEntry>[];
      final seenEntryKeys = <String>{};
      for (final local in localEntries) {
        final key = '${local.taskId}:${local.dateKey}';
        final remote = remoteEntries[key];
        if (remote == null) {
          mergedEntries.add(local);
        } else if (remote.progress > local.progress) {
          mergedEntries.add(remote);
        } else {
          mergedEntries.add(local);
        }
        seenEntryKeys.add(key);
      }
      for (final remote in snapshot.entries) {
        final key = '${remote.taskId}:${remote.dateKey}';
        if (!seenEntryKeys.contains(key)) {
          mergedEntries.add(remote);
        }
      }

      // Merge timers: union by taskId.
      final mergedTimers = <ActiveTimer>[];
      final seenTimerIds = <String>{};
      for (final local in localTimers) {
        final remote = remoteTimersById[local.taskId];
        if (remote == null) {
          mergedTimers.add(local);
        } else if (_isNewer(remote.updatedAt, local.updatedAt)) {
          mergedTimers.add(remote);
        } else {
          mergedTimers.add(local);
        }
        seenTimerIds.add(local.taskId);
      }
      for (final remote in snapshot.timers) {
        if (!seenTimerIds.contains(remote.taskId)) {
          mergedTimers.add(remote);
        }
      }

      // Persist the merged result locally.
      await _local.saveTasks(mergedTasks);
      await _local.saveEntries(mergedEntries);
      await _local.saveActiveTimers(mergedTimers);

      // Notify the UI so in-memory state reflects the merged data.
      await _onLocalChanged?.call();
    } finally {
      _merging = false;
    }
  }

  /// Newer wins: compares commit timestamps. Local wins ties (returns false
  /// when equal).
  bool _isNewer(DateTime remote, DateTime local) => remote.isAfter(local);
}
