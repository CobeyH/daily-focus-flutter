import 'package:flutter/material.dart';
import '../models/task_timing.dart';
import '../utils/dates.dart';

class TaskTimingPicker extends StatelessWidget {
  final TaskTiming value;
  final ValueChanged<TaskTiming> onChanged;
  const TaskTimingPicker(
      {super.key, required this.value, required this.onChanged});

  void _change(
          {int? before,
          int? show,
          int? due,
          bool clearDue = false,
          int? grace}) =>
      onChanged(TaskTiming(
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
      DropdownButtonFormField<int>(
          key: const ValueKey('appearance-days'),
          initialValue: value.showDaysBefore,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Show in Today',
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
      const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(height: 1)),
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
              ? 'After the deadline, this task is overdue.'
              : 'Completion within this window keeps your streak. The next due date stays the same.',
          style: style.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      if (!value.isValid)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
                'Choose an appearance time before the due time, or show the task on an earlier day.',
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]);
  }
}
