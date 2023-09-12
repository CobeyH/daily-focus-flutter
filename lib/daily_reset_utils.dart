import 'package:daily_focus/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DateTime?> getLastSaveDate() async {
  // Get the stored date of the last reset (or a default date)
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? savedEpoch = prefs.getInt('lastResetDate');
  return savedEpoch != null
      ? DateTime.fromMillisecondsSinceEpoch(savedEpoch)
      : null;
}

Future<void> resetTasks(WidgetRef ref, DateTime currentDate) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  // A new day has arrived, reset your tasks here
  // For example, you can call a function to reset tasks
  final tasks = await ref.read(tasksProvider.future);
  await ref.read(tasksProvider.notifier).saveAll();
  await ref.read(tasksProvider.notifier).resetAll();

  // Store the current date as the new last reset date
  await prefs.setInt('lastResetDate', currentDate.millisecondsSinceEpoch);
}

bool isSameDay(DateTime d1, DateTime? d2) {
  return d2 != null &&
      d1.day == d2.day &&
      d1.month == d2.month &&
      d1.year == d2.year;
}

Future<void> checkAndResetTasks(WidgetRef ref) async {
  // Get the current date
  DateTime currentDate = DateTime.now();
  DateTime? lastResetDate = await getLastSaveDate();
  // Compare the current date with the stored date
  if (!isSameDay(currentDate, lastResetDate)) {
    await resetTasks(ref, currentDate);
  }
}
