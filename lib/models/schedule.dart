import 'package:flutter/foundation.dart';

import '../utils/dates.dart';

/// Calendar recurrence. Dates are local civil dates, never elapsed 24h periods.
sealed class Schedule {
  const Schedule();
  bool isDueOn(DateTime day);
  DateTime? get startsOn;
  bool get hasDays => true;

  DateTime? _find(DateTime from, int direction) {
    if (!hasDays) return null;
    var day = dateOnly(from);
    // Supports the editor's full range, including every 99 months.
    for (var i = 0; i < 366 * 100; i++) {
      if (direction < 0 &&
          startsOn != null &&
          day.isBefore(dateOnly(startsOn!))) {
        return null;
      }
      if (isDueOn(day)) return day;
      day = calendarDay(day, direction);
    }
    return null;
  }

  DateTime? nextDueDateAfter(DateTime from) => _find(calendarDay(from, 1), 1);
  DateTime? firstDueDateFrom(DateTime from) => _find(from, 1);
  DateTime? lastDueDateOnOrBefore(DateTime day) => _find(day, -1);
  String describe();
  Map<String, dynamic> toJson();

  static Schedule fromJson(Map<String, dynamic> json) {
    final first = DateTime.tryParse(json['firstDueDate'] as String? ?? '');
    final days = (json['daysOfWeek'] as List?)
            ?.cast<num>()
            .map((n) => n.toInt())
            .where((n) => n >= 1 && n <= 7)
            .toSet()
            .toList() ??
        <int>[];
    switch (json['kind']) {
      case 'once':
        return ScheduleOnce(
            dueDate: DateTime.tryParse(json['dueDate'] as String? ?? '') ??
                first ??
                DateTime(1970));
      case 'interval':
        return ScheduleInterval(
            period:
                SchedulePeriodX.fromValue(json['period'] as String? ?? 'day'),
            interval: ((json['interval'] as num?)?.toInt() ?? 1).clamp(1, 99),
            firstDueDate: first ?? DateTime(1970),
            daysOfWeek: days);
      case 'weekly':
        return ScheduleWeekly(
            intervalWeeks:
                ((json['intervalWeeks'] as num?)?.toInt() ?? 1).clamp(1, 99),
            daysOfWeek: days,
            firstDueDate: first);
      default:
        return const ScheduleDaily();
    }
  }
}

class ScheduleOnce extends Schedule {
  final DateTime dueDate;
  const ScheduleOnce({required this.dueDate});
  @override
  DateTime get startsOn => dateOnly(dueDate);
  @override
  bool isDueOn(DateTime day) => dateOnly(day) == startsOn;
  @override
  DateTime? firstDueDateFrom(DateTime from) =>
      dateOnly(from).isAfter(startsOn) ? null : startsOn;
  @override
  DateTime? nextDueDateAfter(DateTime from) =>
      dateOnly(from).isBefore(startsOn) ? startsOn : null;
  @override
  DateTime? lastDueDateOnOrBefore(DateTime day) =>
      dateOnly(day).isBefore(startsOn) ? null : startsOn;
  @override
  String describe() => 'Never repeats';
  @override
  Map<String, dynamic> toJson() =>
      {'kind': 'once', 'dueDate': startsOn.toIso8601String()};
}

class ScheduleDaily extends Schedule {
  const ScheduleDaily();
  @override
  DateTime? get startsOn => null;
  @override
  bool isDueOn(DateTime day) => true;
  @override
  String describe() => 'Every day';
  @override
  Map<String, dynamic> toJson() => {'kind': 'daily'};
}

@immutable
class ScheduleInterval extends Schedule {
  final SchedulePeriod period;
  final int interval;
  final DateTime firstDueDate;
  final List<int>? daysOfWeek;
  const ScheduleInterval(
      {required this.period,
      required this.interval,
      required this.firstDueDate,
      this.daysOfWeek})
      : assert(interval > 0);
  @override
  DateTime get startsOn => firstDueDate;
  @override
  bool isDueOn(DateTime day) {
    if (dateOnly(day).isBefore(dateOnly(firstDueDate))) return false;
    switch (period) {
      case SchedulePeriod.day:
        return calendarDaysBetween(firstDueDate, day) % interval == 0;
      case SchedulePeriod.week:
        return _weeklyDue(
            day,
            firstDueDate,
            interval,
            daysOfWeek?.isNotEmpty == true
                ? daysOfWeek!
                : [firstDueDate.weekday]);
      case SchedulePeriod.month:
        final months = (day.year - firstDueDate.year) * 12 +
            day.month -
            firstDueDate.month;
        final lastDay = DateTime(day.year, day.month + 1, 0).day;
        return months % interval == 0 &&
            day.day == firstDueDate.day.clamp(1, lastDay);
    }
  }

  @override
  String describe() {
    if (period == SchedulePeriod.week) {
      return _weeklyDescription(
          interval,
          daysOfWeek?.isNotEmpty == true
              ? daysOfWeek!
              : [firstDueDate.weekday]);
    }
    if (interval == 1) {
      return period == SchedulePeriod.day
          ? 'Every day'
          : 'Monthly on ${firstDueDate.day}';
    }
    return 'Every $interval ${period.label}';
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'interval',
        'period': period.name,
        'interval': interval,
        'firstDueDate': firstDueDate.toIso8601String(),
        if (daysOfWeek != null) 'daysOfWeek': daysOfWeek
      };
}

@immutable
class ScheduleWeekly extends Schedule {
  final int intervalWeeks;
  final List<int> daysOfWeek;
  final DateTime? firstDueDate;
  const ScheduleWeekly(
      {required this.intervalWeeks,
      required this.daysOfWeek,
      this.firstDueDate})
      : assert(intervalWeeks > 0);
  @override
  DateTime? get startsOn => firstDueDate;
  @override
  bool get hasDays => daysOfWeek.isNotEmpty;
  @override
  bool isDueOn(DateTime day) => _weeklyDue(
      day, firstDueDate ?? DateTime(1970, 1, 5), intervalWeeks, daysOfWeek);
  @override
  String describe() => _weeklyDescription(intervalWeeks, daysOfWeek);
  @override
  Map<String, dynamic> toJson() => {
        'kind': 'weekly',
        'intervalWeeks': intervalWeeks,
        'daysOfWeek': daysOfWeek,
        if (firstDueDate != null)
          'firstDueDate': firstDueDate!.toIso8601String()
      };
}

bool _weeklyDue(DateTime day, DateTime first, int interval, List<int> days) {
  if (dateOnly(day).isBefore(dateOnly(first)) || !days.contains(day.weekday)) {
    return false;
  }
  final anchorMonday = calendarDay(first, 1 - first.weekday);
  return (calendarDaysBetween(anchorMonday, day) ~/ 7) % interval == 0;
}

String _weeklyDescription(int interval, List<int> days) {
  if (days.isEmpty) return 'Choose weekdays';
  final sorted = days.toSet().toList()..sort();
  final label = sorted.length == 7
      ? 'every day'
      : sorted.map((d) => kWeekDayLabels[d - 1]).join(', ');
  return interval == 1
      ? (sorted.length == 7 ? 'Every day' : 'Every $label')
      : 'Every $interval weeks · $label';
}

enum SchedulePeriod { day, week, month }

extension SchedulePeriodX on SchedulePeriod {
  String get label => switch (this) {
        SchedulePeriod.day => 'days',
        SchedulePeriod.week => 'weeks',
        SchedulePeriod.month => 'months'
      };
  String get singularLabel => name;
  static SchedulePeriod fromValue(String value) => switch (value) {
        'week' => SchedulePeriod.week,
        'month' => SchedulePeriod.month,
        _ => SchedulePeriod.day
      };
}

const kWeekDays = [1, 2, 3, 4, 5, 6, 7];
const kWeekDayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
