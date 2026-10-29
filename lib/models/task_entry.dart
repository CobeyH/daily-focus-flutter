/// Progress belongs to the scheduled due date, including early/late completion.
/// Timestamps retain when the action actually happened and allow undo to sync.
class TaskEntry {
  final String taskId;
  final String dateKey;
  final int progress;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? completionTiming; // onTime, grace, late; captured at completion
  final int? completedGoal;
  final int? previousProgress;
  final bool skipped;
  const TaskEntry(
      {required this.taskId,
      required this.dateKey,
      required this.progress,
      this.updatedAt,
      this.completedAt,
      this.completionTiming,
      this.completedGoal,
      this.previousProgress,
      this.skipped = false});
  bool isComplete(int goal) => !skipped && progress >= (completedGoal ?? goal);
  bool countsForStreak(int goal) =>
      isComplete(goal) && completionTiming != 'late';
  TaskEntry copyWith({String? dateKey, int? progress}) => TaskEntry(
      taskId: taskId,
      dateKey: dateKey ?? this.dateKey,
      progress: progress ?? this.progress,
      updatedAt: updatedAt,
      completedAt: completedAt,
      completionTiming: completionTiming,
      completedGoal: completedGoal,
      previousProgress: previousProgress,
      skipped: skipped);
  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'dateKey': dateKey,
        'progress': progress,
        'skipped': skipped,
        'updatedAt': updatedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'completionTiming': completionTiming,
        'completedGoal': completedGoal,
        'previousProgress': previousProgress,
      };
  factory TaskEntry.fromJson(Map<String, dynamic> json) => TaskEntry(
      taskId: json['taskId'] as String,
      dateKey: json['dateKey'] as String,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      completionTiming: json['completionTiming'] as String?,
      completedGoal: (json['completedGoal'] as num?)?.toInt(),
      previousProgress: (json['previousProgress'] as num?)?.toInt(),
      skipped: json['skipped'] as bool? ?? false);
}
