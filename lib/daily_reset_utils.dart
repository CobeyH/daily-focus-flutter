import 'package:daily_focus/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> checkAndResetTasks(WidgetRef ref) async {
  // Get the current date
  DateTime currentDate = DateTime.now();

  // Get the stored date of the last reset (or a default date)
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? savedEpoch = prefs.getInt('lastResetDate');
  DateTime? lastResetDate = savedEpoch != null
      ? DateTime.fromMillisecondsSinceEpoch(savedEpoch)
      : null;

  // Compare the current date with the stored date
  if (lastResetDate == null ||
      currentDate.day != lastResetDate.day ||
      currentDate.month != lastResetDate.month ||
      currentDate.year != lastResetDate.year) {
    // A new day has arrived, reset your tasks here
    // For example, you can call a function to reset tasks
    ref.read(tasksProvider.notifier).resetAll();

    // Store the current date as the new last reset date
    await prefs.setInt('lastResetDate', currentDate.millisecondsSinceEpoch);
  }
}
