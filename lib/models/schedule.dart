import 'package:flutter/foundation.dart';

/// How often a task is due.
///
/// Three modes are supported:
///
/// * [ScheduleDaily] — the task is due every day (the original behaviour).
/// * [ScheduleInterval] — every N [SchedulePeriod]s (e.g. every 3 days,
///   every 2 weeks, every 6 months). For week periods, [daysOfWeek] pins the
///   due dates; for month periods, the day-of-month of [firstDueDate] is
///   used.
/// * [ScheduleWeekly] — every [intervalWeeks] weeks on specific weekdays
///   ([daysOfWeek]). `intervalWeeks=2` with `daysOfWeek=[mon]` =
///   "every other Monday".
sealed class Schedule {
  const Schedule();

  /// Whether the task is due on [day] under this schedule. Does not consider
  /// overdue state — just the raw cadence.
  bool isDueOn(DateTime day);

  /// The next due date strictly after [from], or `null` if none can be found
  /// within a reasonable horizon.
  DateTime? nextDueDateAfter(DateTime from);

  /// The most recent due date on or before [day], or `null` if none exists.
  DateTime? lastDueDateOnOrBefore(DateTime day);

  /// A short human-readable description, e.g. "Daily", "Every 3 days",
  /// "Every Monday", "Every other Monday".
  String describe();

  Map<String, dynamic> toJson();

  static Schedule fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String? ?? 'daily';
    switch (kind) {
      case 'interval':
        return ScheduleInterval(
          period: SchedulePeriodX.fromValue(json['period'] as String? ?? 'day'),
          interval: (json['interval'] as int?) ?? 1,
          firstDueDate: DateTime.parse(json['firstDueDate'] as String),
          daysOfWeek: _readDaysOfWeek(json['daysOfWeek']),
        );
      case 'weekly':
        return ScheduleWeekly(
          intervalWeeks: (json['intervalWeeks'] as int?) ?? 1,
          daysOfWeek: _readDaysOfWeek(json['daysOfWeek']) ?? const <int>[],
          firstDueDate: json['firstDueDate'] != null
              ? DateTime.parse(json['firstDueDate'] as String)
              : null,
        );
      case 'daily':
      default:
        return const ScheduleDaily();
    }
  }

  static List<int>? _readDaysOfWeek(dynamic v) {
    if (v == null) return null;
    final list = (v as List<dynamic>).cast<num>();
    return list.map((n) => n.toInt()).toList(growable: false);
  }
}

/// Due every day.
class ScheduleDaily extends Schedule {
  const ScheduleDaily();

  @override
  bool isDueOn(DateTime day) => true;

  @override
  DateTime? nextDueDateAfter(DateTime from) =>
      DateTime(from.year, from.month, from.day).add(const Duration(days: 1));

  @override
  DateTime? lastDueDateOnOrBefore(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  @override
  String describe() => 'Daily';

  @override
  Map<String, dynamic> toJson() => {'kind': 'daily'};
}

/// Every [interval] [period]s. For week periods, [daysOfWeek] is required and
/// pins the due dates. For month periods, the day-of-month of
/// [firstDueDate] is used.
@immutable
class ScheduleInterval extends Schedule {
  final SchedulePeriod period;
  final int interval;
  final DateTime firstDueDate;
  final List<int>? daysOfWeek;

  const ScheduleInterval({
    required this.period,
    required this.interval,
    required this.firstDueDate,
    this.daysOfWeek,
  });

  @override
  bool isDueOn(DateTime day) {
    final first =
        DateTime(firstDueDate.year, firstDueDate.month, firstDueDate.day);
    final cur = DateTime(day.year, day.month, day.day);
    if (cur.isBefore(first)) return false;

    switch (period) {
      case SchedulePeriod.day:
        final diffDays = cur.difference(first).inDays;
        return diffDays % interval == 0;
      case SchedulePeriod.week:
        if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
          if (!daysOfWeek!.contains(day.weekday)) return false;
        }
        final daysBetween = cur.difference(first).inDays;
        final weeksBetween = daysBetween ~/ 7;
        return weeksBetween % interval == 0 && daysBetween % 7 == 0;
      case SchedulePeriod.month:
        final monthsBetween =
            (cur.year - first.year) * 12 + (cur.month - first.month);
        return monthsBetween % interval == 0 && cur.day == first.day;
    }
  }

  @override
  DateTime? nextDueDateAfter(DateTime from) {
    var candidate =
        DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
    for (var i = 0; i < 366 * 5; i++) {
      if (isDueOn(candidate)) return candidate;
      candidate = candidate.add(const Duration(days: 1));
    }
    return null;
  }

  @override
  DateTime? lastDueDateOnOrBefore(DateTime day) {
    var candidate = DateTime(day.year, day.month, day.day);
    for (var i = 0; i < 366 * 5; i++) {
      if (isDueOn(candidate)) return candidate;
      candidate = candidate.subtract(const Duration(days: 1));
      if (candidate.year < 1900) return null;
    }
    return null;
  }

  @override
  String describe() {
    if (interval == 1) {
      return switch (period) {
        SchedulePeriod.day => 'Daily',
        SchedulePeriod.week => 'Weekly',
        SchedulePeriod.month => 'Monthly',
      };
    }
    return 'Every $interval ${period.label}';
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'interval',
        'period': period.name,
        'interval': interval,
        'firstDueDate': firstDueDate.toIso8601String(),
        if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      };
}

/// Every [intervalWeeks] weeks on the specified [daysOfWeek]. Anchored by
/// [firstDueDate] when provided, so "every other Monday" stays anchored to
/// its first Monday rather than sliding.
@immutable
class ScheduleWeekly extends Schedule {
  final int intervalWeeks;
  final List<int> daysOfWeek;
  final DateTime? firstDueDate;

  const ScheduleWeekly({
    required this.intervalWeeks,
    required this.daysOfWeek,
    this.firstDueDate,
  });

  @override
  bool isDueOn(DateTime day) {
    if (!daysOfWeek.contains(day.weekday)) return false;
    if (firstDueDate == null) return true;
    final first =
        DateTime(firstDueDate!.year, firstDueDate!.month, firstDueDate!.day);
    if (DateTime(day.year, day.month, day.day).isBefore(first)) return false;
    final daysBetween =
        DateTime(day.year, day.month, day.day).difference(first).inDays;
    final weeksBetween = daysBetween ~/ 7;
    return weeksBetween % intervalWeeks == 0;
  }

  @override
  DateTime? nextDueDateAfter(DateTime from) {
    var candidate =
        DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
    for (var i = 0; i < 14; i++) {
      if (isDueOn(candidate)) return candidate;
      candidate = candidate.add(const Duration(days: 1));
    }
    return null;
  }

  @override
  DateTime? lastDueDateOnOrBefore(DateTime day) {
    var candidate = DateTime(day.year, day.month, day.day);
    for (var i = 0; i < 14; i++) {
      if (isDueOn(candidate)) return candidate;
      candidate = candidate.subtract(const Duration(days: 1));
      if (candidate.year < 1900) return null;
    }
    return null;
  }

  @override
  String describe() {
    if (daysOfWeek.isEmpty) return 'No days selected';
    final days =
        daysOfWeek.map((d) => kWeekDayLabels[d - DateTime.monday]).join(', ');
    if (intervalWeeks == 1) return 'Every $days';
    return 'Every ${_ordinal(intervalWeeks)} $days';
  }

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'weekly',
        'intervalWeeks': intervalWeeks,
        'daysOfWeek': daysOfWeek,
        if (firstDueDate != null)
          'firstDueDate': firstDueDate!.toIso8601String(),
      };

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}

/// The unit used by [ScheduleInterval].
enum SchedulePeriod { day, week, month }

extension SchedulePeriodX on SchedulePeriod {
  String get label => switch (this) {
        SchedulePeriod.day => 'days',
        SchedulePeriod.week => 'weeks',
        SchedulePeriod.month => 'months',
      };

  String get singularLabel => switch (this) {
        SchedulePeriod.day => 'day',
        SchedulePeriod.week => 'week',
        SchedulePeriod.month => 'month',
      };

  static SchedulePeriod fromValue(String v) => switch (v) {
        'week' => SchedulePeriod.week,
        'month' => SchedulePeriod.month,
        _ => SchedulePeriod.day,
      };
}

/// Names for weekdays matching [DateTime.weekday] (1=Mon..7=Sun). Used for the
/// schedule picker's UI.
const List<int> kWeekDays = <int>[
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
];

/// Short weekday labels in the same order as [kWeekDays].
const List<String> kWeekDayLabels = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
