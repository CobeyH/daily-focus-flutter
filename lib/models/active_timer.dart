import '../models/task.dart';

/// Represents a "timed" task's countdown, which can be running or paused.
///
/// For [TaskType.minutes] tasks, the app starts a countdown equal to the
/// task's [Task.goal] (in minutes). Rather than relying on a Dart `Timer`
/// that dies when the app is suspended, we persist a snapshot of the
/// remaining time ([remaining]) together with the wall-clock instant that
/// snapshot was taken ([updatedAt]). This lets the remaining time be
/// recomputed at any moment (even after the process was killed and
/// relaunched) and lets us schedule a native OS notification for exactly
/// when the timer completes.
///
/// A timer can be [paused], which freezes [remaining] so that stopping it
/// retains the progress made instead of resetting the countdown.
class ActiveTimer {
  final String taskId;

  /// Absolute wall-clock time (UTC) at which the timer was started. Used to
  /// credit progress to the correct day if the app resumes after midnight.
  final DateTime startedAt;

  /// Whether the countdown is paused (stopped but retaining progress).
  final bool paused;

  /// The remaining duration as of [updatedAt]. While running, the effective
  /// remaining decreases as `now` advances past [updatedAt]; while paused,
  /// this is the frozen remaining time.
  final Duration remaining;

  /// Wall-clock time (UTC) at which [remaining] was snapshotted.
  final DateTime updatedAt;

  const ActiveTimer({
    required this.taskId,
    required this.startedAt,
    required this.paused,
    required this.remaining,
    required this.updatedAt,
  });

  /// Creates a fresh running timer for [task], counting down from its goal.
  factory ActiveTimer.start(Task task, {required DateTime now}) {
    return ActiveTimer(
      taskId: task.id,
      startedAt: now,
      paused: false,
      remaining: Duration(seconds: task.goal),
      updatedAt: now,
    );
  }

  /// Remaining duration (never negative), accounting for time passed since
  /// [updatedAt] while running.
  Duration remainingAt(DateTime now) {
    if (paused) return remaining;
    final diff = remaining - now.difference(updatedAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Whether the timer has elapsed (only meaningful while running).
  bool isElapsed(DateTime now) =>
      !paused && remainingAt(now).inMilliseconds <= 0;

  /// Returns a paused copy with the remaining time frozen at [now].
  ActiveTimer pause(DateTime now) => ActiveTimer(
        taskId: taskId,
        startedAt: startedAt,
        paused: true,
        remaining: remainingAt(now),
        updatedAt: now,
      );

  /// Returns a running copy that resumes from the frozen remaining time.
  ActiveTimer resume(DateTime now) => ActiveTimer(
        taskId: taskId,
        startedAt: startedAt,
        paused: false,
        remaining: remainingAt(now),
        updatedAt: now,
      );

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'startedAt': startedAt.toIso8601String(),
        'paused': paused,
        'remainingMs': remaining.inMilliseconds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ActiveTimer.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final startedAtRaw = json['startedAt'] as String?;
    final updatedAtRaw = json['updatedAt'] as String?;
    final startedAt = startedAtRaw != null ? DateTime.parse(startedAtRaw) : now;
    final updatedAt = updatedAtRaw != null ? DateTime.parse(updatedAtRaw) : now;

    // Backward-compatible migration: older persisted timers stored an absolute
    // `endsAt` instead of a `remaining` snapshot.
    final endsAtRaw = json['endsAt'] as String?;
    if (endsAtRaw != null) {
      final endsAt = DateTime.parse(endsAtRaw);
      final remaining = endsAt.difference(now);
      return ActiveTimer(
        taskId: json['taskId'] as String,
        startedAt: startedAt,
        paused: false,
        remaining: remaining.isNegative ? Duration.zero : remaining,
        updatedAt: now,
      );
    }

    return ActiveTimer(
      taskId: json['taskId'] as String,
      startedAt: startedAt,
      paused: json['paused'] as bool? ?? false,
      remaining: Duration(milliseconds: json['remainingMs'] as int? ?? 0),
      updatedAt: updatedAt,
    );
  }
}
