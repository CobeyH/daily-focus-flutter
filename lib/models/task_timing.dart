import '../utils/dates.dart';
import 'day_slots.dart';

/// Local wall-clock settings. Grace days keep the same local due time over DST.
class TaskTiming {
  final DaySlot? slot;
  final int? visibleDaysAfter;
  final int showDaysBefore;
  final int showMinute;
  final int? dueMinute;
  final int graceDays;
  const TaskTiming(
      {this.slot,
      this.visibleDaysAfter,
      this.showDaysBefore = 0,
      this.showMinute = 0,
      this.dueMinute,
      this.graceDays = 0})
      : assert(visibleDaysAfter == null ||
            (visibleDaysAfter >= 0 && visibleDaysAfter <= 30)),
        assert(showDaysBefore >= 0 && showDaysBefore <= 30),
        assert(showMinute >= 0 && showMinute < 1440),
        assert(dueMinute == null || (dueMinute >= 0 && dueMinute < 1440)),
        assert(graceDays >= 0 && graceDays <= 30);

  int startMinute(DaySlots slots) =>
      slot == null ? showMinute : slots.start(slot!);
  DateTime appearsAt(DateTime dueDate, [DaySlots slots = const DaySlots()]) {
    final minute = startMinute(slots);
    return DateTime(dueDate.year, dueDate.month, dueDate.day - showDaysBefore,
        minute ~/ 60, minute % 60);
  }

  bool visibilityEnded(DateTime dueDate, DateTime now) =>
      visibleDaysAfter != null &&
      !now.isBefore(calendarDay(dueDate, visibleDaysAfter! + 1));

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
  bool get isValid => isValidFor(const DaySlots());
  bool isValidFor(DaySlots slots) =>
      showDaysBefore > 0 ||
      dueMinute == null ||
      startMinute(slots) <= dueMinute!;
  Map<String, dynamic> toJson() => {
        if (slot != null) 'slot': slot!.name,
        if (visibleDaysAfter != null) 'visibleDaysAfter': visibleDaysAfter,
        'showDaysBefore': showDaysBefore,
        'showMinute': showMinute,
        'dueMinute': dueMinute,
        'graceDays': graceDays
      };
  factory TaskTiming.fromJson(Map<String, dynamic> json) => TaskTiming(
      slot: DaySlot.values.where((s) => s.name == json['slot']).firstOrNull,
      visibleDaysAfter:
          (json['visibleDaysAfter'] as num?)?.toInt().clamp(0, 30),
      showDaysBefore:
          ((json['showDaysBefore'] as num?)?.toInt() ?? 0).clamp(0, 30),
      showMinute: ((json['showMinute'] as num?)?.toInt() ?? 0).clamp(0, 1439),
      dueMinute: (json['dueMinute'] as num?)?.toInt().clamp(0, 1439),
      graceDays: ((json['graceDays'] as num?)?.toInt() ?? 0).clamp(0, 30));
}
