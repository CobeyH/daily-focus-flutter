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
    final controller = ref.read(appControllerProvider.notifier);
    if (_isEdit) {
      await controller.updateTask(widget.existing!.copyWith(
        name: name,
        type: _type,
        goal: _goal,
        step: _step,
        color: _color,
        icon: _icon,
      ));
    } else {
      await controller.addTask(Task.create(
        name: name,
        type: _type,
        goal: _goal,
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
                'When you start this task, a timer counts down $_goal minutes. '
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
