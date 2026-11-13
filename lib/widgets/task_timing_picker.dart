import 'package:flutter/material.dart';
import '../models/task_timing.dart';
import '../models/day_slots.dart';
import '../utils/dates.dart';

class TaskTimingPicker extends StatelessWidget {
  final TaskTiming value;
  final DaySlots slots;
  final bool visibilityOnly, deadlineOnly;
  final VoidCallback? onEditSlots;
  final ValueChanged<TaskTiming> onChanged;
  const TaskTimingPicker(
      {super.key,
      required this.value,
      required this.onChanged,
      this.slots = const DaySlots(),
      this.visibilityOnly = false,
      this.deadlineOnly = false,
      this.onEditSlots});

  void _change(
          {DaySlot? slot,
          bool clearSlot = false,
          int? after,
          bool clearAfter = false,
          int? before,
          int? show,
          int? due,
          bool clearDue = false,
          int? grace}) =>
      onChanged(TaskTiming(
          slot: clearSlot ? null : slot ?? value.slot,
          visibleDaysAfter: clearAfter ? null : after ?? value.visibleDaysAfter,
          showDaysBefore: before ?? value.showDaysBefore,
          showMinute: show ?? value.showMinute,
          dueMinute: clearDue ? null : due ?? value.dueMinute,
          graceDays: grace ?? value.graceDays));

  Future<void> _pickTime(BuildContext context,
      {required bool appearance}) async {
    final minute = appearance ? value.showMinute : value.dueMinute ?? 1080;
    final time = await showTimePicker(
        context: context,
        initialEntryMode: TimePickerEntryMode.input,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!),
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
    if (time != null) {
      final result = time.hour * 60 + time.minute;
      if (appearance) {
        _change(show: result);
      } else {
        _change(due: result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!deadlineOnly) ...[
        DropdownButtonFormField<int>(
            key: const ValueKey('appearance-days'),
            initialValue: value.showDaysBefore,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'First visible',
                prefixIcon: Icon(Icons.visibility_outlined)),
            items: [
              for (var day = 0; day <= 30; day++)
                DropdownMenuItem(
                    value: day,
                    child: Text(day == 0
                        ? 'On the due day'
                        : '$day day${day == 1 ? '' : 's'} before due'))
            ],
            onChanged: (day) {
              if (day != null) _change(before: day);
            }),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
            key: ValueKey('appearance-slot-${value.slot?.name ?? 'custom'}'),
            initialValue: value.slot?.index ?? -1,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Time of day'),
            items: [
              for (final slot in DaySlot.values)
                DropdownMenuItem(
                    value: slot.index,
                    child: Text(
                        '${slot.label} · ${clockLabel(slots.start(slot))}')),
              const DropdownMenuItem(value: -1, child: Text('Custom time')),
            ],
            onChanged: (index) {
              if (index != null) {
                _change(
                    slot: index < 0 ? null : DaySlot.values[index],
                    clearSlot: index < 0);
              }
            }),
        const SizedBox(height: 12),
        if (value.slot == null)
          Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Starting at', style: style.bodyMedium),
                OutlinedButton.icon(
                    key: const ValueKey('appearance-time'),
                    onPressed: () => _pickTime(context, appearance: true),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(clockLabel(value.showMinute))),
              ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
            key: const ValueKey('visibility-after'),
            initialValue: value.visibleDaysAfter ?? -1,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Keep visible after due date'),
            items: [
              const DropdownMenuItem(value: -1, child: Text('Until completed')),
              for (var day = 0; day <= 30; day++)
                DropdownMenuItem(
                    value: day,
                    child: Text(day == 0
                        ? 'Through the due day'
                        : '$day day${day == 1 ? '' : 's'} after due')),
            ],
            onChanged: (day) {
              if (day != null) {
                _change(after: day < 0 ? null : day, clearAfter: day < 0);
              }
            }),
        const SizedBox(height: 8),
        Text(
            'Once a task appears, it stays visible for the rest of that day. Later slots never hide unfinished tasks.',
            style: style.bodySmall),
        if (onEditSlots != null)
          TextButton.icon(
              onPressed: onEditSlots,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Edit global time slots')),
      ],
      if (!visibilityOnly) ...[
        Text('Due time', style: style.titleSmall),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                  key: const ValueKey('due-time'),
                  onPressed: () => _pickTime(context, appearance: false),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(value.dueMinute == null
                      ? 'End of day'
                      : clockLabel(value.dueMinute!))),
              if (value.dueMinute != null)
                TextButton(
                    onPressed: () => _change(clearDue: true),
                    child: const Text('Use end of day')),
            ]),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
            key: const ValueKey('grace-days'),
            initialValue: value.graceDays,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Grace period',
                prefixIcon: Icon(Icons.hourglass_bottom_rounded)),
            items: [
              for (var day = 0; day <= 30; day++)
                DropdownMenuItem(
                    value: day,
                    child: Text(day == 0
                        ? 'None · strict deadline'
                        : 'Up to $day day${day == 1 ? '' : 's'} late'))
            ],
            onChanged: (day) {
              if (day != null) _change(grace: day);
            }),
        const SizedBox(height: 10),
        Text(
            value.graceDays == 0
                ? 'No extra time for streak credit. Visibility is controlled separately above.'
                : 'Completion within this window keeps your streak. This does not change visibility or the next due date.',
            style: style.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
      if (!value.isValidFor(slots))
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
                'Choose an appearance time before the due time, or show the task on an earlier day.',
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]);
  }
}
