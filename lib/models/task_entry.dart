/// A record of progress made on a [Task] for a single day.
///
/// Progress is keyed by [dateKey] (a `yyyy-MM-dd` string) rather than stored
/// as a mutable "today's progress" field. This is what makes tasks reset
/// automatically at midnight: a new day simply has no entry yet, so it starts
/// at zero.
class TaskEntry {
  final String taskId;
  final String dateKey;
  final int progress;

  const TaskEntry({
    required this.taskId,
    required this.dateKey,
    required this.progress,
  });

  TaskEntry copyWith({String? dateKey, int? progress}) => TaskEntry(
        taskId: taskId,
        dateKey: dateKey ?? this.dateKey,
        progress: progress ?? this.progress,
      );

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'dateKey': dateKey,
        'progress': progress,
      };

  factory TaskEntry.fromJson(Map<String, dynamic> json) => TaskEntry(
        taskId: json['taskId'] as String,
        dateKey: json['dateKey'] as String,
        progress: json['progress'] as int? ?? 0,
      );
}
