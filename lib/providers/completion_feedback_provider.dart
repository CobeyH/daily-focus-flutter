import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_entry.dart';
import '../models/task_occurrence.dart';

/// A transient local UI signal; sync and restored history never emit it.
class TaskCompletionFeedback {
  final TaskOccurrence before;
  final TaskEntry completedEntry;
  final bool earnedWater;
  const TaskCompletionFeedback(this.before, this.completedEntry,
      {required this.earnedWater});
  String get key => '${before.task.id}/${before.key}';
  TaskOccurrence get completed => TaskOccurrence(
      before.task, before.dueDate, completedEntry, before.now, before.slots);
}

final completionFeedbackProvider =
    NotifierProvider<CompletionFeedbackController, TaskCompletionFeedback?>(
        CompletionFeedbackController.new);

class CompletionFeedbackController extends Notifier<TaskCompletionFeedback?> {
  @override
  TaskCompletionFeedback? build() => null;
  void emit(TaskCompletionFeedback event) => state = event;
}
