import 'package:flutter/material.dart';

import '../models/schedule.dart';

/// The kind of schedule the user is currently configuring. The picker
/// switches between these three modes and configures a [Schedule] accordingly.
enum _ScheduleMode { daily, interval, weekly }

/// A self-contained picker for the schedule of a task.
///
/// Lets the user choose between:
///
/// * Daily (every day — the default).
/// * Interval (every N days/weeks/months, with optional first-due date).
/// * Weekly (specific weekdays, optionally every Nth week).
class SchedulePicker extends StatefulWidget {
  final Schedule initial;
  final ValueChanged<Schedule> onChanged;

  const SchedulePicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<SchedulePicker> createState() => _SchedulePickerState();
}

class _SchedulePickerState extends State<SchedulePicker> {
  late _ScheduleMode _mode;
  late int _intervalN;
  late SchedulePeriod _intervalPeriod;
  late int _weeklyN;
  late Set<int> _weeklyDays;
  DateTime? _firstDueDate;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _firstDueDate = null;
    if (s is ScheduleDaily) {
      _mode = _ScheduleMode.daily;
      _intervalN = 1;
      _intervalPeriod = SchedulePeriod.day;
      _weeklyN = 1;
      _weeklyDays = {};
    } else if (s is ScheduleInterval) {
      _mode = _ScheduleMode.interval;
      _intervalN = s.interval;
      _intervalPeriod = s.period;
      _firstDueDate = DateTime(
          s.firstDueDate.year, s.firstDueDate.month, s.firstDueDate.day);
      _weeklyN = 1;
      _weeklyDays = s.daysOfWeek != null ? s.daysOfWeek!.toSet() : <int>{};
    } else if (s is ScheduleWeekly) {
      _mode = _ScheduleMode.weekly;
      _weeklyN = s.intervalWeeks;
      _weeklyDays = s.daysOfWeek.toSet();
      _firstDueDate = s.firstDueDate == null
          ? null
          : DateTime(
              s.firstDueDate!.year, s.firstDueDate!.month, s.firstDueDate!.day);
      _intervalN = 1;
      _intervalPeriod = SchedulePeriod.day;
    } else {
      _mode = _ScheduleMode.daily;
      _intervalN = 1;
      _intervalPeriod = SchedulePeriod.day;
      _weeklyN = 1;
      _weeklyDays = {};
    }
  }

  void _emit() {
    final s = _buildSchedule();
    widget.onChanged(s);
  }

  Schedule _buildSchedule() {
    switch (_mode) {
      case _ScheduleMode.daily:
        return const ScheduleDaily();
      case _ScheduleMode.interval:
        final first = _firstDueDate ?? DateTime.now();
        return ScheduleInterval(
          period: _intervalPeriod,
          interval: _intervalN,
          firstDueDate: first,
          daysOfWeek:
              _intervalPeriod == SchedulePeriod.week && _weeklyDays.isNotEmpty
                  ? _weeklyDays.toList(growable: false)
                  : null,
        );
      case _ScheduleMode.weekly:
        return ScheduleWeekly(
          intervalWeeks: _weeklyN,
          daysOfWeek: _weeklyDays.toList(growable: false),
          firstDueDate: _firstDueDate,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How often?', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<_ScheduleMode>(
          segments: const [
            ButtonSegment(value: _ScheduleMode.daily, label: Text('Daily')),
            ButtonSegment(
                value: _ScheduleMode.interval, label: Text('Every N')),
            ButtonSegment(value: _ScheduleMode.weekly, label: Text('Days')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) {
            setState(() {
              _mode = s.first;
              // Reset _firstDueDate when switching to a mode that needs it,
              // so the picker starts at "today".
              if (_firstDueDate == null &&
                  (_mode == _ScheduleMode.interval ||
                      _mode == _ScheduleMode.weekly)) {
                final now = DateTime.now();
                _firstDueDate = DateTime(now.year, now.month, now.day);
              }
              _emit();
            });
          },
        ),
        const SizedBox(height: 16),
        if (_mode == _ScheduleMode.daily) _buildDaily(),
        if (_mode == _ScheduleMode.interval) _buildInterval(),
        if (_mode == _ScheduleMode.weekly) _buildWeekly(),
      ],
    );
  }

  Widget _buildDaily() {
    return Text(
      'Repeats every day.',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
    );
  }

  Widget _buildInterval() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Every '),
            _NumberStepper(
              value: _intervalN,
              min: 1,
              max: 99,
              onChanged: (v) {
                setState(() => _intervalN = v);
                _emit();
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<SchedulePeriod>(
                initialValue: _intervalPeriod,
                items: [
                  for (final p in SchedulePeriod.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text(p == SchedulePeriod.day && _intervalN == 1
                          ? p.singularLabel
                          : p.label),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _intervalPeriod = v);
                  _emit();
                },
              ),
            ),
          ],
        ),
        if (_intervalPeriod == SchedulePeriod.week) ...[
          const SizedBox(height: 12),
          _WeekdayChips(
            selected: _weeklyDays,
            onChanged: (s) {
              setState(() => _weeklyDays = s);
              _emit();
            },
            label: 'On',
          ),
        ],
        const SizedBox(height: 12),
        _FirstDueDateField(
          value: _firstDueDate,
          onChanged: (d) {
            setState(() => _firstDueDate = d);
            _emit();
          },
        ),
      ],
    );
  }

  Widget _buildWeekly() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekdayChips(
          selected: _weeklyDays,
          onChanged: (s) {
            setState(() => _weeklyDays = s);
            _emit();
          },
          label: 'On',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Every '),
            _NumberStepper(
              value: _weeklyN,
              min: 1,
              max: 12,
              onChanged: (v) {
                setState(() => _weeklyN = v);
                _emit();
              },
            ),
            const SizedBox(width: 8),
            const Text('week(s)'),
          ],
        ),
        if (_weeklyN > 1) ...[
          const SizedBox(height: 12),
          _FirstDueDateField(
            value: _firstDueDate,
            onChanged: (d) {
              setState(() => _firstDueDate = d);
              _emit();
            },
            helper: 'Anchors "every Nth" so the days don\'t slide.',
          ),
        ],
      ],
    );
  }
}

/// A small +/- stepper used by the interval pickers.
class _NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > min
                ? () => onChanged((value - 1).clamp(min, max))
                : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value < max
                ? () => onChanged((value + 1).clamp(min, max))
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// A row of weekday chips for selecting which days a task is due.
class _WeekdayChips extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final String label;

  const _WeekdayChips({
    required this.selected,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < kWeekDays.length; i++)
              FilterChip(
                label: Text(kWeekDayLabels[i]),
                selected: selected.contains(kWeekDays[i]),
                onSelected: (on) {
                  final s = {...selected};
                  if (on) {
                    s.add(kWeekDays[i]);
                  } else {
                    s.remove(kWeekDays[i]);
                  }
                  onChanged(s);
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// A date-picker field for setting the "first due date" of a recurring task.
class _FirstDueDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String helper;

  const _FirstDueDateField({
    required this.value,
    required this.onChanged,
    this.helper = 'When the task is first due.',
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final initial = value ?? DateTime(today.year, today.month, today.day);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(today.year - 2),
          lastDate: DateTime(today.year + 5),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'First due',
          helperText: helper,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value == null
              ? 'Today'
              : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}
