import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/app_controller.dart';
import '../widgets/selectors.dart';

/// Screen for creating a new task or editing an existing one.
class TaskCreationScreen extends ConsumerStatefulWidget {
  final Task? existing;

  const TaskCreationScreen({super.key, this.existing});

  @override
  ConsumerState<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends ConsumerState<TaskCreationScreen> {
  late final TextEditingController _nameController;
  late TaskType _type;
  late int _goal;
  late int _step;
  late int _color;
  late int _icon;
  late bool _isEdit;

  // Time-based goal, split into h/m/s for easier entry.
  late int _goalHours;
  late int _goalMinutes;
  late int _goalSeconds;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _isEdit = t != null;
    _nameController = TextEditingController(text: t?.name ?? '');
    _type = t?.type ?? TaskType.count;
    _goal = t?.goal ?? 1;
    _step = t?.step ?? 1;
    _color = t?.color ?? taskColors.first;
    _icon = t?.icon ?? taskIcons.first.codePoint;

    // Split the goal into h/m/s. For count tasks the goal is occurrences and
    // this decomposition is unused; for minutes tasks it's stored in seconds.
    if (_type == TaskType.minutes) {
      final d = Duration(seconds: _goal);
      _goalHours = d.inHours;
      _goalMinutes = d.inMinutes.remainder(60);
      _goalSeconds = d.inSeconds.remainder(60);
    } else {
      _goalHours = 0;
      _goalMinutes = 0;
      _goalSeconds = 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give your task a name.')),
      );
      return;
    }
    // For time-based tasks, the goal is the total duration in seconds.
    final goal = _type == TaskType.minutes
        ? _goalHours * 3600 + _goalMinutes * 60 + _goalSeconds
        : _goal;
    if (_type == TaskType.minutes && goal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a goal longer than zero.')),
      );
      return;
    }
    final controller = ref.read(appControllerProvider.notifier);
    if (_isEdit) {
      await controller.updateTask(widget.existing!.copyWith(
        name: name,
        type: _type,
        goal: goal,
        step: _step,
        color: _color,
        icon: _icon,
      ));
    } else {
      await controller.addTask(Task.create(
        name: name,
        type: _type,
        goal: goal,
        step: _step,
        color: _color,
        icon: _icon,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Task' : 'New Task'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            autofocus: !_isEdit,
            decoration: const InputDecoration(
              labelText: 'Task name',
              hintText: 'e.g. Drink water',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Goal type',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<TaskType>(
            segments: const [
              ButtonSegment(value: TaskType.count, label: Text('Times')),
              ButtonSegment(value: TaskType.minutes, label: Text('Minutes')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 24),
          Text('Daily goal',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_type == TaskType.minutes)
            _DurationSelector(
              hours: _goalHours,
              minutes: _goalMinutes,
              seconds: _goalSeconds,
              onChanged: (h, m, s) => setState(() {
                _goalHours = h;
                _goalMinutes = m;
                _goalSeconds = s;
              }),
            )
          else
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    if (_goal > 1) _goal--;
                  }),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Text(
                    '$_goal ${_type.label}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _goal++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          if (_type == TaskType.minutes)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'When you start this task, a timer counts down '
                '${_goalHours}h ${_goalMinutes}m ${_goalSeconds}s. '
                'Even if the app is closed, you\'ll get a notification when it\'s '
                'done.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          const SizedBox(height: 24),
          const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ColorSelector(
              selected: _color, onChanged: (c) => setState(() => _color = c)),
          const SizedBox(height: 24),
          const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          IconSelector(
              selected: _icon, onChanged: (i) => setState(() => _icon = i)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// A three-column selector for entering a duration with hour / minute /
/// second granularity. Each column shows the value with +/- buttons and a
/// slider for quick adjustment.
class _DurationSelector extends StatelessWidget {
  final int hours;
  final int minutes;
  final int seconds;
  final void Function(int hours, int minutes, int seconds) onChanged;

  const _DurationSelector({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('h', hours, 24, 0),
      ('m', minutes, 59, 5),
      ('s', seconds, 59, 5),
    ];
    return Row(
      children: [
        for (final (label, value, max, step) in fields)
          Expanded(
            child: _TimeField(
              label: label,
              value: value,
              max: max,
              step: step,
              onChanged: (v) {
                switch (label) {
                  case 'h':
                    onChanged(v, minutes, seconds);
                    break;
                  case 'm':
                    onChanged(hours, v, seconds);
                    break;
                  default:
                    onChanged(hours, minutes, v);
                }
              },
            ),
          ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final int step;
  final void Function(int) onChanged;

  const _TimeField({
    required this.label,
    required this.value,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: () => onChanged((value + step).clamp(0, max)),
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: () => onChanged((value - step).clamp(0, max)),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Slider(
          value: value.toDouble().clamp(0, max.toDouble()),
          min: 0,
          max: max.toDouble(),
          divisions: max,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
