import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule.dart';
import '../models/task.dart';
import '../providers/app_controller.dart';
import '../utils/dates.dart';
import 'streak_screen.dart';
import 'task_card.dart';
import 'task_creation.dart';

/// The main screen showing the list of tasks for today.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// When true, tasks that aren't due today are shown (greyed out). Default
  /// false to keep the home screen focused on what needs attention.
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(tasksForTodayProvider);
    final tasks = _showAll
        ? allTasks
        : allTasks
            .where((t) => t.schedule is ScheduleDaily || _isDueOrOverdue(t))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Focus'),
        centerTitle: true,
        actions: [
          if (ref.watch(tasksProvider).isNotEmpty) ...[
            IconButton(
              tooltip: 'Streaks',
              icon: const Icon(Icons.local_fire_department_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StreakScreen()),
                );
              },
            ),
            IconButton(
              tooltip: _showAll ? 'Hide non-due tasks' : 'Show all tasks',
              icon: Icon(_showAll
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _showAll = !_showAll),
            ),
          ],
        ],
      ),
      body: tasks.isEmpty
          ? _EmptyState(
              showAll: _showAll,
              hasAnyTasks: ref.watch(tasksProvider).isNotEmpty,
            )
          : _TaskList(tasks: tasks),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TaskCreationScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _isDueOrOverdue(Task t) {
    final today = todayOnly();
    return isTaskDueOn(t, today) ||
        isTaskOverdueOn(t, today, ref.read(appControllerProvider));
  }
}

class _EmptyState extends StatelessWidget {
  final bool showAll;
  final bool hasAnyTasks;
  const _EmptyState({required this.showAll, required this.hasAnyTasks});

  @override
  Widget build(BuildContext context) {
    // If the user has tasks but none are due today (and they're not viewing
    // all), show the "all clear" message. Otherwise (no tasks at all, or
    // viewing all) show the "no tasks" / onboarding message.
    final isAllClear = !showAll && hasAnyTasks;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAllClear ? Icons.check_circle_outline : Icons.flag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isAllClear ? 'All clear for today' : 'No tasks yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isAllClear
                  ? 'No tasks are due or overdue today. Tap the eye icon to see recurring tasks on their off days.'
                  : 'Tap the + button to create your first task and start building a streak.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List tasks;

  const _TaskList({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, i) => TaskCard(task: tasks[i]),
    );
  }
}
