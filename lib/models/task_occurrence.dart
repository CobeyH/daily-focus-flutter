import '../utils/dates.dart';
import 'task.dart';
import 'day_slots.dart';
import 'task_entry.dart';

enum OccurrenceStatus {
  upcoming,
  available,
  due,
  grace,
  overdue,
  complete,
  skipped
}

class TaskOccurrence {
  final Task task;
  final DateTime dueDate;
  final TaskEntry? entry;
  final DateTime now;
  final DaySlots slots;
  const TaskOccurrence(this.task, this.dueDate, this.entry, this.now,
      [this.slots = const DaySlots()]);
  String get key => dateKey(dueDate);
  int get progress => entry?.progress ?? 0;
  bool get done => entry?.isComplete(task.goal) ?? false;
  bool get skipped => entry?.skipped ?? false;
  DateTime get appearsAt => task.timing.appearsAt(dueDate, slots);
  bool get visible =>
      !now.isBefore(appearsAt) && !task.timing.visibilityEnded(dueDate, now);
  bool get completedToday =>
      entry?.completedAt != null &&
      dateKey(entry!.completedAt!.toLocal()) == dateKey(now);
  OccurrenceStatus get status {
    if (skipped) return OccurrenceStatus.skipped;
    if (done) return OccurrenceStatus.complete;
    if (now.isBefore(appearsAt)) return OccurrenceStatus.upcoming;
    if (task.timing.pastGrace(dueDate, now)) return OccurrenceStatus.overdue;
    if (task.timing.pastDue(dueDate, now)) return OccurrenceStatus.grace;
    if (dateOnly(now).isBefore(dueDate)) return OccurrenceStatus.available;
    return OccurrenceStatus.due;
  }

  String get dueLabel =>
      '${shortDate(dueDate)}${task.timing.dueMinute == null ? '' : ' at ${clockLabel(task.timing.dueMinute!)}'}';
  String get graceLabel =>
      '${shortDate(calendarDay(dueDate, task.timing.graceDays))}${task.timing.dueMinute == null ? ', end of day' : ' at ${clockLabel(task.timing.dueMinute!)}'}';
  String get label => switch (status) {
        OccurrenceStatus.upcoming =>
          'Appears ${shortDate(appearsAt)} at ${clockLabel(task.timing.startMinute(slots))}',
        OccurrenceStatus.available => 'Available early · Due $dueLabel',
        OccurrenceStatus.due => task.timing.dueMinute == null
            ? 'Due today'
            : 'Due today at ${clockLabel(task.timing.dueMinute!)}',
        OccurrenceStatus.grace => 'Within grace · Okay through $graceLabel',
        OccurrenceStatus.overdue => 'Overdue · Due $dueLabel',
        OccurrenceStatus.complete => entry?.completionTiming == 'late'
            ? 'Completed late · Due $dueLabel'
            : entry?.completionTiming == 'grace'
                ? 'Completed within grace · Due $dueLabel'
                : 'Completed · Due $dueLabel',
        OccurrenceStatus.skipped => 'Skipped · Due $dueLabel',
      };
}

TaskEntry? entryFor(Iterable<TaskEntry> entries, String taskId, String key) {
  for (final entry in entries) {
    if (entry.taskId == taskId && entry.dateKey == key) return entry;
  }
  return null;
}

DateTime scheduleStart(Task task) =>
    dateOnly(task.schedule.startsOn ?? task.createdAt);

/// Select one actionable cycle. An older cycle still in grace takes priority;
/// expired cycles move to history once a new scheduled cycle is due. Off-day
/// recurring tasks remain actionable until their next due date.
TaskOccurrence? currentOccurrence(
    Task task, Iterable<TaskEntry> entries, DateTime now,
    [DaySlots slots = const DaySlots()]) {
  final start = scheduleStart(task);
  final today = dateOnly(now);
  TaskOccurrence at(DateTime day) => TaskOccurrence(
      task, day, entryFor(entries, task.id, dateKey(day)), now, slots);
  DateTime? last = task.schedule.lastDueDateOnOrBefore(today);
  if (last != null && last.isBefore(start)) last = null;

  // Overlapping grace windows must not redirect a late completion to this week.
  var previous = task.schedule.firstDueDateFrom(
      calendarDay(today, -task.timing.graceDays - 1).isBefore(start)
          ? start
          : calendarDay(today, -task.timing.graceDays - 1));
  while (previous != null && previous.isBefore(today)) {
    final candidate = at(previous);
    if (!candidate.done &&
        !candidate.skipped &&
        !task.timing.pastGrace(previous, now)) {
      return candidate;
    }
    previous = task.schedule.nextDueDateAfter(previous);
  }
  if (last != null) {
    final candidate = at(last);
    if (!candidate.done && !candidate.skipped) return candidate;
    if (candidate.completedToday || dateKey(last) == dateKey(today)) {
      return candidate;
    }
  }
  final next =
      task.schedule.firstDueDateFrom(today.isBefore(start) ? start : today);
  if (next != null) return at(next);
  return last == null ? null : at(last);
}

TaskOccurrence? nextOccurrence(
    Task task, Iterable<TaskEntry> entries, DateTime now,
    [DaySlots slots = const DaySlots()]) {
  var day = task.schedule.firstDueDateFrom(
      dateOnly(now).isBefore(scheduleStart(task))
          ? scheduleStart(task)
          : dateOnly(now));
  for (var i = 0; i < 366 && day != null; i++) {
    final occurrence = TaskOccurrence(
        task, day, entryFor(entries, task.id, dateKey(day)), now, slots);
    if (!occurrence.done && !occurrence.skipped && !occurrence.visible) {
      return occurrence;
    }
    day = task.schedule.nextDueDateAfter(day);
  }
  return null;
}
