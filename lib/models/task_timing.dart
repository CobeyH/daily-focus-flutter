import '../utils/dates.dart';

/// Local wall-clock settings. Grace days keep the same local due time over DST.
class TaskTiming {
  final int showDaysBefore;
  final int showMinute;
  final int? dueMinute;
  final int graceDays;
  const TaskTiming(
      {this.showDaysBefore = 0,
      this.showMinute = 0,
      this.dueMinute,
      this.graceDays = 0})
      : assert(showDaysBefore >= 0 && showDaysBefore <= 30),
        assert(showMinute >= 0 && showMinute < 1440),
        assert(dueMinute == null || (dueMinute >= 0 && dueMinute < 1440)),
        assert(graceDays >= 0 && graceDays <= 30);

  DateTime appearsAt(DateTime dueDate) => DateTime(dueDate.year, dueDate.month,
      dueDate.day - showDaysBefore, showMinute ~/ 60, showMinute % 60);

  /// All-day deadlines use the exclusive midnight boundary of the next day.
  DateTime dueAt(DateTime dueDate) => dueMinute == null
      ? calendarDay(dueDate, 1)
      : DateTime(dueDate.year, dueDate.month, dueDate.day, dueMinute! ~/ 60,
          dueMinute! % 60);
  DateTime closesAt(DateTime dueDate) {
    final due = dueAt(dueDate);
    return DateTime(
        due.year, due.month, due.day + graceDays, due.hour, due.minute);
  }

  bool pastDue(DateTime dueDate, DateTime now) => dueMinute == null
      ? !now.isBefore(dueAt(dueDate))
      : now.isAfter(dueAt(dueDate));
  bool pastGrace(DateTime dueDate, DateTime now) => dueMinute == null
      ? !now.isBefore(closesAt(dueDate))
      : now.isAfter(closesAt(dueDate));
  bool get isValid =>
      showDaysBefore > 0 || dueMinute == null || showMinute <= dueMinute!;
  Map<String, dynamic> toJson() => {
        'showDaysBefore': showDaysBefore,
        'showMinute': showMinute,
        'dueMinute': dueMinute,
        'graceDays': graceDays
      };
  factory TaskTiming.fromJson(Map<String, dynamic> json) => TaskTiming(
      showDaysBefore:
          ((json['showDaysBefore'] as num?)?.toInt() ?? 0).clamp(0, 30),
      showMinute: ((json['showMinute'] as num?)?.toInt() ?? 0).clamp(0, 1439),
      dueMinute: (json['dueMinute'] as num?)?.toInt().clamp(0, 1439),
      graceDays: ((json['graceDays'] as num?)?.toInt() ?? 0).clamp(0, 30));
}
