import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/home_widget_service.dart';
import 'app_controller.dart';
import 'clock_provider.dart';
import 'day_slots_provider.dart';
import 'timer_controller.dart';

final homeWidgetServiceProvider = Provider((ref) => HomeWidgetService());

final homeWidgetSyncProvider = Provider<void>((ref) {
  final service = ref.watch(homeWidgetServiceProvider);
  if (!service.enabled) return;
  final signedIn = ref.watch(authStateProvider).value == true &&
      ref.watch(cloudInitializationErrorProvider) == null;
  if (!signedIn) {
    service.publish(null);
    return;
  }
  final state = ref.watch(appControllerProvider);
  service.publish(buildHomeWidgetSnapshot(
    tasks: state.tasks,
    entries: state.entries,
    timers: ref
        .watch(timerControllerProvider.select((state) => state.timers))
        .values
        .toList(),
    now: ref.watch(clockProvider),
    slots: ref.watch(daySlotsProvider),
  ));
});
