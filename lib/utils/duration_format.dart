/// Formats a [Duration] as a compact, human-readable goal string.
///
/// Examples: `45s`, `5m`, `1h 30m`, `2h`, `2h 30m 15s`.
String formatGoalDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);

  final parts = <String>[];
  if (h > 0) parts.add('${h}h');
  if (m > 0 || (h > 0 && s == 0)) parts.add('${m}m');
  if (s > 0 || parts.isEmpty) parts.add('${s}s');
  return parts.join(' ');
}
