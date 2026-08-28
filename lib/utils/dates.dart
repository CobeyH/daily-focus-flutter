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
