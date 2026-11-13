import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/day_slots.dart';
import '../providers/app_controller.dart';
import '../providers/day_slots_provider.dart';
import '../utils/dates.dart';

class DaySlotsScreen extends ConsumerStatefulWidget {
  const DaySlotsScreen({super.key});
  @override
  ConsumerState<DaySlotsScreen> createState() => _DaySlotsScreenState();
}

class _DaySlotsScreenState extends ConsumerState<DaySlotsScreen> {
  late DaySlots _draft;
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _draft = ref.read(daySlotsProvider);
  }

  Future<void> _pick(DaySlot slot) async {
    final minute = _draft.start(slot);
    final time = await showTimePicker(
        context: context,
        initialEntryMode: TimePickerEntryMode.input,
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!));
    if (time == null || !mounted) return;
    final value = time.hour * 60 + time.minute;
    setState(() {
      _draft = DaySlots(
          morning: slot == DaySlot.morning ? value : _draft.morning,
          afternoon: slot == DaySlot.afternoon ? value : _draft.afternoon,
          evening: slot == DaySlot.evening ? value : _draft.evening);
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!_draft.isValid) {
      setState(() =>
          _error = 'Start times must be in Morning, Afternoon, Evening order.');
      return;
    }
    for (final task in ref.read(appControllerProvider).tasks) {
      if (!task.timing.isValidFor(_draft)) {
        setState(() => _error =
            'This would show “${task.name}” after its deadline. Adjust its timing first.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await ref.read(daySlotsProvider.notifier).save(_draft);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save time slots. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Time slots')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text(
                      'Choose when each part of your day starts. Tasks stay visible after their slot starts, until completed or their visibility window ends.'),
                  const SizedBox(height: 20),
                  for (final slot in DaySlot.values)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(slot.label),
                        subtitle: const Text('Starts at'),
                        trailing: OutlinedButton(
                            onPressed: _saving ? null : () => _pick(slot),
                            child: Text(clockLabel(_draft.start(slot))))),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save time slots')),
                ]))),
      );
}
