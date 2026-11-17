import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forest.dart';
import '../providers/forest_provider.dart';

IconData projectIcon(ForestProject project) => switch (project) {
      ForestProject.nursery => Icons.yard_outlined,
      ForestProject.birdhouse => Icons.flutter_dash,
      ForestProject.pond => Icons.water_outlined,
    };

class ForestProjectSummary extends StatelessWidget {
  final ForestState forest;
  final VoidCallback onTap;
  const ForestProjectSummary(
      {super.key, required this.forest, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final project = forest.activeProject;
    return ListTile(
      key: const ValueKey('forest-project-summary'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading:
          Icon(project == null ? Icons.park_outlined : projectIcon(project)),
      title:
          Text(project == null ? 'Your sanctuary is thriving' : project.label),
      subtitle: project == null
          ? const Text('Birds, frogs, and room to keep growing')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(forest.canBuild(project)
                  ? 'Ready to build'
                  : '${forest.materials} / ${project.materialCost} materials · ${forest.matureTrees} / ${project.matureTrees} mature trees'),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                  value: forest.projectProgress(project),
                  semanticsLabel: '${project.label} requirements'),
            ]),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class ForestProjects extends ConsumerStatefulWidget {
  final VoidCallback onTendTrees;
  const ForestProjects({super.key, required this.onTendTrees});
  @override
  ConsumerState<ForestProjects> createState() => _ForestProjectsState();
}

class _ForestProjectsState extends ConsumerState<ForestProjects> {
  bool _busy = false;
  String? _error;
  ForestProject? _celebrated;

  Future<void> _act(Future<void> Function() action,
      {ForestProject? built}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted && built != null) setState(() => _celebrated = built);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not save your project. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forest = ref.watch(forestProvider);
    final controller = ref.read(forestProvider.notifier);
    final text = Theme.of(context).textTheme;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Build your sanctuary', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text('${forest.materials} materials · ${forest.water} water'),
          const SizedBox(height: 8),
          const Text(
              'Every completed task earns 1 material. Each tree you grow to maturity contributes 3 more. Projects and residents stay forever.'),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 400),
            child: _celebrated == null
                ? const SizedBox.shrink()
                : Card(
                    key: ValueKey(_celebrated),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(
                                '${_celebrated!.label} complete!\n${_celebrated!.benefit}',
                                style: text.titleMedium)))),
          ),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final project in ForestProject.values)
            Card(
                key: ValueKey('project-${project.name}'),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(projectIcon(project)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(project.label,
                                    style: text.titleMedium)),
                            if (forest.hasProject(project))
                              const Icon(Icons.check_circle_outline),
                          ]),
                          const SizedBox(height: 8),
                          Text(project.description),
                          const SizedBox(height: 8),
                          Text(project.benefit, style: text.labelLarge),
                          const SizedBox(height: 12),
                          if (forest.hasProject(project))
                            const Text('Established · yours to keep')
                          else ...[
                            if (project.prerequisite != null)
                              _requirement(
                                  forest.hasProject(project.prerequisite!)
                                      ? '${project.prerequisite!.label} established'
                                      : 'Build ${project.prerequisite!.label} first',
                                  forest.hasProject(project.prerequisite!),
                                  onTap: forest.hasProject(
                                              project.prerequisite!) ||
                                          _busy
                                      ? null
                                      : () => _act(() =>
                                          controller.chooseProject(
                                              project.prerequisite!))),
                            _requirement(
                                '${forest.materials} / ${project.materialCost} materials',
                                forest.materials >= project.materialCost),
                            Text(
                                'Complete tasks and grow mature trees to gather materials.',
                                style: text.bodySmall),
                            _requirement(
                                '${forest.matureTrees} / ${project.matureTrees} mature trees',
                                forest.matureTrees >= project.matureTrees,
                                onTap: _busy ? null : widget.onTendTrees),
                            if (project.waterCost > 0) ...[
                              _requirement(
                                  '${forest.water} / ${project.waterCost} water',
                                  forest.water >= project.waterCost),
                              Text('Complete tasks to earn water.',
                                  style: text.bodySmall),
                            ],
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              FilledButton.icon(
                                  key: ValueKey('build-${project.name}'),
                                  onPressed: !_busy && forest.canBuild(project)
                                      ? () => _act(
                                          () =>
                                              controller.buildProject(project),
                                          built: project)
                                      : null,
                                  icon:
                                      const Icon(Icons.construction, size: 18),
                                  label: const Text('Build')),
                              if (forest.activeProject == project)
                                const Chip(label: Text('Current goal'))
                              else
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _act(() =>
                                            controller.chooseProject(project)),
                                    child: const Text('Make my goal')),
                            ]),
                          ],
                        ]))),
        ]);
  }

  Widget _requirement(String label, bool met, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Icon(
                  met
                      ? Icons.check_circle_outline
                      : onTap == null
                          ? Icons.circle_outlined
                          : Icons.arrow_forward,
                  size: 18,
                  color: met ? Theme.of(context).colorScheme.primary : null),
              const SizedBox(width: 8),
              Expanded(child: Text(label)),
            ])),
      );
}

class ForestSandboxControls extends ConsumerWidget {
  const ForestSandboxControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forest = ref.watch(forestProvider);
    final controller = ref.read(forestProvider.notifier);
    if (!controller.isSandbox) return const SizedBox.shrink();
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Forest debug sandbox',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
          'This is a temporary copy. Nothing here changes your tasks, saves to your real forest, or syncs to Firebase. Leave this screen to discard it.'),
      const SizedBox(height: 16),
      Text(
          'Level ${forest.level} · ${forest.xp} XP\n${forest.seeds} seeds · ${forest.water} water · ${forest.materials} materials'),
      const SizedBox(height: 16),
      FilledButton.icon(
          onPressed: controller.debugLevelUp,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Force next level')),
      OutlinedButton.icon(
          onPressed: controller.debugResources,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Grant 50 of each resource')),
      OutlinedButton(
          onPressed: () => controller.awardCompletion(
              'debug-${DateTime.now().microsecondsSinceEpoch}', 'preview'),
          child: const Text('Simulate a task completion')),
      OutlinedButton(
          onPressed: controller.debugGrowTrees,
          child: const Text('Grow four mature trees')),
      OutlinedButton(
          onPressed: forest.level < 16
              ? () => controller.debugLevelUp(targetLevel: 16)
              : null,
          child: const Text('Reach level 16 · all tree varieties')),
      const SizedBox(height: 16),
      const Text(
          'Use Plant a tree, Water, and the project panel to try the full progression. Force next level also plays the level-up celebration.'),
      const SizedBox(height: 24),
      TextButton(
          onPressed: controller.debugReset,
          child: const Text('Reset sandbox to a fresh forest')),
    ]);
  }
}
