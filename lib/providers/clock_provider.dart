import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final timeSourceProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Refreshes on minute boundaries even with no running timers or user input.
/// The app also invalidates this on resume. Tests override it with a fixed time.
final clockProvider = Provider<DateTime>((ref) {
  final now = ref.read(timeSourceProvider)();
  final nextMinute =
      DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
  final timer = Timer(nextMinute.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return now;
});
