import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../models/task_timing.dart';
import '../providers/app_controller.dart';
import '../providers/clock_provider.dart';
import '../utils/dates.dart';
import '../widgets/schedule_picker.dart';
import '../widgets/selectors.dart';
import '../widgets/task_timing_picker.dart';

class TaskCreationScreen extends ConsumerStatefulWidget {
  final Task? existing;
  const TaskCreationScreen({super.key, this.existing});
  @override
  ConsumerState<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends ConsumerState<TaskCreationScreen> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _name, _count, _hours, _minutes, _seconds;
  late TaskType _type;
  late Schedule _schedule;
  late TaskTiming _timing;
  late int _color, _icon;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final task = widget.existing;
    _name = TextEditingController(text: task?.name ?? '');
    _type = task?.type ?? TaskType.count;
    final duration =
        Duration(seconds: _type == TaskType.minutes ? task!.goal : 600);
    _count = TextEditingController(
        text: '${_type == TaskType.count ? task?.goal ?? 1 : 1}');
    _hours = TextEditingController(text: '${duration.inHours}');
    _minutes =
        TextEditingController(text: '${duration.inMinutes.remainder(60)}');
    _seconds =
        TextEditingController(text: '${duration.inSeconds.remainder(60)}');
    _schedule = task?.schedule ?? const ScheduleDaily();
    _timing = task?.timing ?? const TaskTiming();
    _color = task?.color ?? taskColors.first;
    _icon = task?.icon ?? taskIcons.first.codePoint;
  }

  @override
  void dispose() {
    for (final controller in [_name, _count, _hours, _minutes, _seconds]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    final goal = _type == TaskType.count
        ? int.tryParse(_count.text) ?? 0
        : (int.tryParse(_hours.text) ?? 0) * 3600 +
            (int.tryParse(_minutes.text) ?? 0) * 60 +
            (int.tryParse(_seconds.text) ?? 0);
    String? error;
    if (goal <= 0) error = 'Choose a goal greater than zero.';
    if (_schedule is ScheduleWeekly &&
        (_schedule as ScheduleWeekly).daysOfWeek.isEmpty) {
      error = 'Choose at least one weekday.';
    }
    if (!_timing.isValid) error = 'The task must appear before its due time.';
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(appControllerProvider.notifier);
    final existing = widget.existing;
    final task = existing?.copyWith(
            name: _name.text.trim(),
            type: _type,
            goal: goal,
            step: 1,
            color: _color,
            icon: _icon,
            schedule: _schedule,
            timing: _timing) ??
        Task.create(
            name: _name.text.trim(),
            type: _type,
            goal: goal,
            step: 1,
            color: _color,
            icon: _icon,
            schedule: _schedule,
            timing: _timing);
    try {
      if (existing == null) {
        await controller.addTask(task);
      } else {
        await controller.updateTask(task);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this task. Please try again.';
        });
      }
    }
  }

  Widget _section(String title, String subtitle, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 20),
                    child,
                  ]))));
  Widget _number(TextEditingController controller, String label, {int? max}) =>
      TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5)
          ],
          decoration: InputDecoration(labelText: label),
          validator: (text) {
            final value = int.tryParse(text ?? '');
            return value == null || (max != null && value > max)
                ? 'Use 0–${max ?? 99999}'
                : null;
          });
  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider);
    final next = <DateTime>[];
    var day = _schedule.firstDueDateFrom(dateOnly(now));
    for (var i = 0; i < 3 && day != null; i++) {
      next.add(day);
      day = _schedule.nextDueDateAfter(day);
    }
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.existing == null ? 'New task' : 'Edit task'),
            actions: [
              TextButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save')),
              const SizedBox(width: 8)
            ]),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                    key: _form,
                    child: ListView(
                        key: const ValueKey('task-editor-scroll'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          _section(
                              'Make it yours',
                              'A small action you want to make room for.',
                              Column(children: [
                                TextFormField(
                                    controller: _name,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                        labelText: 'Task name',
                                        hintText: 'e.g. Weekly review'),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Give your task a name.'
                                            : null),
                                const SizedBox(height: 16),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final type in TaskType.values)
                                    ChoiceChip(
                                        avatar: Icon(
                                            type == TaskType.count
                                                ? Icons.check_rounded
                                                : Icons.timer_outlined,
                                            size: 18),
                                        label: Text(type == TaskType.count
                                            ? 'Count'
                                            : 'Timer'),
                                        selected: _type == type,
                                        showCheckmark: false,
                                        onSelected: (_) =>
                                            setState(() => _type = type)),
                                ]),
                                const SizedBox(height: 16),
                                if (_type == TaskType.count)
                                  _number(_count, 'Times per occurrence')
                                else
                                  Row(children: [
                                    Expanded(
                                        child:
                                            _number(_hours, 'Hours', max: 99)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _number(_minutes, 'Minutes',
                                            max: 59)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _number(_seconds, 'Seconds',
                                            max: 59))
                                  ]),
                              ])),
                          _section(
                              'Repeat',
                              'Choose the days this task is due.',
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SchedulePicker(
                                        initial: _schedule,
                                        onChanged: (value) =>
                                            setState(() => _schedule = value)),
                                    const SizedBox(height: 16),
                                    Text('Next due dates',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, runSpacing: 6, children: [
                                      for (final date in next)
                                        Chip(
                                            label: Text(
                                                '${kWeekDayLabels[date.weekday - 1]} ${shortDate(date)}'))
                                    ]),
                                    if (_schedule is ScheduleInterval &&
                                        (_schedule as ScheduleInterval)
                                                .period ==
                                            SchedulePeriod.month)
                                      const Text(
                                          'Shorter months use their last day.',
                                          style: TextStyle(fontSize: 12)),
                                  ])),
                          _section(
                              'Timing & flexibility',
                              'Visibility and deadlines work independently.',
                              TaskTimingPicker(
                                  value: _timing,
                                  onChanged: (value) =>
                                      setState(() => _timing = value))),
                          _section(
                              'Personalize',
                              'A familiar color and icon make it easier to spot.',
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ColorSelector(
                                        selected: _color,
                                        onChanged: (value) =>
                                            setState(() => _color = value)),
                                    const SizedBox(height: 20),
                                    IconSelector(
                                        selected: _icon,
                                        onChanged: (value) =>
                                            setState(() => _icon = value)),
                                  ])),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.check),
                              label: Text(_saving
                                  ? 'Saving…'
                                  : widget.existing == null
                                      ? 'Create task'
                                      : 'Save changes')),
                        ])))));
  }
}
