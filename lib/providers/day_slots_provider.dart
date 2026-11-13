import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/day_slots.dart';
import 'app_controller.dart';

final daySlotsProvider =
    NotifierProvider<DaySlotsController, DaySlots>(DaySlotsController.new);

class DaySlotsController extends Notifier<DaySlots> {
  static const _key = 'day_slots_v1';
  @override
  DaySlots build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const DaySlots();
    try {
      return DaySlots.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const DaySlots();
    }
  }

  Future<void> save(DaySlots value) async {
    if (!value.isValid) {
      throw ArgumentError(
          'Slots must start in morning, afternoon, evening order.');
    }
    final saved = await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(value.toJson()));
    if (!saved) throw StateError('Could not save time slots.');
    state = value;
  }
}
