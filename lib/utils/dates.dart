/// Date helpers used across the app.
///
/// A "day" is identified by a `yyyy-MM-dd` key so that progress naturally
/// resets each midnight — each date key holds its own progress value, and the
/// UI always reads from the key matching "today".
String dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// A [DateTime] with the time-of-day zeroed out, representing "today".
DateTime todayOnly() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime calendarDay(DateTime value, int offset) =>
    DateTime(value.year, value.month, value.day + offset);
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
String shortDate(DateTime date) => '${const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][date.month - 1]} ${date.day}';
String clockLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
