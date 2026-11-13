import '../models/day_slots.dart';
import 'day_slots_screen.dart';
import '../providers/day_slots_provider.dart';
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
  final _forms = List.generate(6, (_) => GlobalKey<FormState>());
  int _step = 0;
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
    _timing = task?.timing ?? const TaskTiming(slot: DaySlot.morning);
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
    if (_saving) return;
    for (var step = 0; step < 4; step++) {
      final error = _validationError(step);
      if (error != null) {
        setState(() {
          _step = step;
          _error = error;
        });
        return;
      }
    }
    final goal = _type == TaskType.count
        ? int.tryParse(_count.text) ?? 0
        : (int.tryParse(_hours.text) ?? 0) * 3600 +
            (int.tryParse(_minutes.text) ?? 0) * 60 +
            (int.tryParse(_seconds.text) ?? 0);
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
  String? _validationError(int step) {
    if (step == 0) {
      if (_name.text.trim().isEmpty) return 'Give your task a name.';
      final count = int.tryParse(_count.text);
      final hours = int.tryParse(_hours.text);
      final minutes = int.tryParse(_minutes.text);
      final seconds = int.tryParse(_seconds.text);
      if (_type == TaskType.count) {
        if (count == null || count <= 0) {
          return 'Choose a goal greater than zero.';
        }
      } else if (hours == null ||
          minutes == null ||
          seconds == null ||
          hours > 99 ||
          minutes > 59 ||
          seconds > 59 ||
          hours * 3600 + minutes * 60 + seconds <= 0) {
        return 'Choose a valid duration greater than zero.';
      }
    }
    if (step == 1 &&
        _schedule is ScheduleWeekly &&
        (_schedule as ScheduleWeekly).daysOfWeek.isEmpty) {
      return 'Choose at least one weekday.';
    }
    if ((step == 2 || step == 3) &&
        !_timing.isValidFor(ref.read(daySlotsProvider))) {
      return 'The task must appear before its due time.';
    }
    return null;
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
  }

  void _next() {
    final valid = _forms[_step].currentState!.validate();
    final error = _validationError(_step);
    if (!valid || error != null) {
      setState(() => _error = error);
      return;
    }
    _goTo(_step + 1);
  }

  Widget _review(String title, String value, int step) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _goTo(step));

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider);
    final next = <DateTime>[];
    var day = _schedule.firstDueDateFrom(dateOnly(now));
    for (var i = 0; i < 3 && day != null; i++) {
      next.add(day);
      day = _schedule.nextDueDateAfter(day);
    }
    final pages = <Widget>[
      _section(
          'Make it yours',
          'A small action you want to make room for.',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Task name', hintText: 'e.g. Weekly review'),
                validator: (value) => value == null || value.trim().isEmpty
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
                    label: Text(type == TaskType.count ? 'Count' : 'Timer'),
                    selected: _type == type,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _type = type)),
            ]),
            const SizedBox(height: 16),
            if (_type == TaskType.count)
              _number(_count, 'Times per occurrence')
            else
              Row(children: [
                Expanded(child: _number(_hours, 'Hours', max: 99)),
                const SizedBox(width: 8),
                Expanded(child: _number(_minutes, 'Minutes', max: 59)),
                const SizedBox(width: 8),
                Expanded(child: _number(_seconds, 'Seconds', max: 59))
              ]),
          ])),
      _section(
          'Repeat',
          'Choose the days this task is due.',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SchedulePicker(
                initial: _schedule,
                onChanged: (value) => setState(() => _schedule = value)),
            const SizedBox(height: 16),
            Text(_schedule is ScheduleOnce ? 'Due date' : 'Next due dates',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final date in next)
                Chip(
                    label: Text(
                        '${kWeekDayLabels[date.weekday - 1]} ${shortDate(date)}'))
            ]),
            if (_schedule is ScheduleInterval &&
                (_schedule as ScheduleInterval).period == SchedulePeriod.month)
              const Text('Shorter months use their last day.',
                  style: TextStyle(fontSize: 12)),
          ])),
      _section(
          'Visibility',
          'Choose when it appears and how long it stays.',
          TaskTimingPicker(
              value: _timing,
              visibilityOnly: true,
              onEditSlots: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DaySlotsScreen())),
              slots: ref.watch(daySlotsProvider),
              onChanged: (value) => setState(() => _timing = value))),
      _section(
          'Deadline & grace',
          'Choose when it is due and how much flexibility you need.',
          TaskTimingPicker(
              value: _timing,
              deadlineOnly: true,
              slots: ref.watch(daySlotsProvider),
              onChanged: (value) => setState(() => _timing = value))),
      _section(
          'Personalize',
          'A familiar color and icon make it easier to spot.',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ColorSelector(
                selected: _color,
                onChanged: (value) => setState(() => _color = value)),
            const SizedBox(height: 20),
            IconSelector(
                selected: _icon,
                onChanged: (value) => setState(() => _icon = value)),
          ])),
      _section(
          'Ready to go',
          'Review your task before saving.',
          Column(children: [
            _review(
                'Task',
                '${_name.text.trim()} · ${_type == TaskType.count ? '${_count.text} times' : '${_hours.text}h ${_minutes.text}m ${_seconds.text}s'}',
                0),
            _review('Repeat', _schedule.describe(), 1),
            _review(
                'Visibility',
                'Show ${_timing.showDaysBefore == 0 ? 'on the due day' : '${_timing.showDaysBefore} days early'} at ${clockLabel(_timing.startMinute(ref.watch(daySlotsProvider)))}\n'
                    'Visible ${_timing.visibleDaysAfter == null ? 'until completed' : 'through ${_timing.visibleDaysAfter} days after due'}',
                2),
            _review(
                'Deadline & grace',
                'Due ${_timing.dueMinute == null ? 'at end of day' : 'at ${clockLabel(_timing.dueMinute!)}'} · ${_timing.graceDays == 0 ? 'No grace period' : '${_timing.graceDays} days grace'}',
                3),
            ListTile(
                leading: Icon(iconFor(_icon), color: Color(_color)),
                title: const Text('Appearance'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _goTo(4)),
          ])),
    ];
    while (_forms.length < pages.length) {
      _forms.add(GlobalKey<FormState>());
    }
    return PopScope(
      canPop: _step == 0 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving && _step > 0) _goTo(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.existing == null ? 'New task' : 'Edit task'),
            leading: IconButton(
                tooltip: _step == 0 ? 'Cancel' : 'Previous step',
                icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back),
                onPressed: _saving
                    ? null
                    : () {
                        if (_step == 0) {
                          Navigator.pop(context);
                        } else {
                          _goTo(_step - 1);
                        }
                      })),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Step ${_step + 1} of 6 · ${const [
                                      'Task',
                                      'Repeat',
                                      'Visibility',
                                      'Deadline',
                                      'Appearance',
                                      'Review'
                                    ][_step]}',
                                    style:
                                        Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                    value: (_step + 1) / 6,
                                    semanticsLabel: 'Task setup progress'),
                              ])),
                      Expanded(
                          child: SingleChildScrollView(
                              key: ValueKey('wizard-step-$_step'),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Form(
                                  key: _forms[_step],
                                  child: Column(children: [
                                    pages[_step],
                                    if (_error != null)
                                      Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(_error!,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error))),
                                  ])))),
                      SafeArea(
                          top: false,
                          child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 16),
                              child: Row(children: [
                                if (_step > 0) ...[
                                  OutlinedButton(
                                      onPressed: _saving
                                          ? null
                                          : () => _goTo(_step - 1),
                                      child: const Text('Back')),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                    child: FilledButton(
                                        onPressed: _saving
                                            ? null
                                            : _step == 5
                                                ? _save
                                                : _next,
                                        child: Text(_saving
                                            ? 'Saving…'
                                            : _step < 5
                                                ? 'Continue'
                                                : widget.existing == null
                                                    ? 'Create task'
                                                    : 'Save changes'))),
                              ]))),
                    ]))),
      ),
    );
  }
}
