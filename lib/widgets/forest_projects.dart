import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forest.dart';
import '../providers/forest_provider.dart';
import 'forest_spend_preview.dart';

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
    final finished = forest.projects.length == ForestProject.values.length;
    final plan = project == null ? null : forest.planFor(project);
    return ListTile(
      key: const ValueKey('forest-project-summary'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading:
          Icon(project == null ? Icons.park_outlined : projectIcon(project)),
      title: Text(project == null
          ? (finished
              ? 'Your sanctuary is thriving'
              : 'Choose your next project')
          : project.label),
      subtitle: project == null
          ? Text(finished
              ? 'Birds, frogs, and room to keep growing'
              : '${forest.materials} materials · choose what to grow next')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(forest.canBuild(project)
                  ? 'Ready to build'
                  : forest.resourceChoices
                      ? '${forest.materials} / ${plan!.cost.materials} materials${plan.cost.water > 0 ? ' · ${forest.water} / ${plan.cost.water} water' : ''}'
                      : '${forest.materials} / ${plan!.cost.materials} materials · ${forest.matureTrees} / ${plan.matureTrees} mature trees'),
              if (forest.resourceChoices && forest.goalAdvice != null)
                Text(forest.goalAdvice!),
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
          Text(forest.resources.balance),
          const SizedBox(height: 8),
          Text(forest.resourceChoices
              ? 'Choose a resource path. All three projects are available; they share your materials and water. Bonuses arrive automatically through task completions.'
              : 'Every completed task earns 1 material. Each tree you grow to maturity contributes 3 more. Projects and residents stay forever.'),
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
                                '${_celebrated!.label} complete!\n${forest.planFor(_celebrated!).benefit}',
                                style: text.titleMedium)))),
          ),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final project in ForestProject.values)
            _project(forest, project, controller),
        ]);
  }

  Widget _project(
      ForestState forest, ForestProject project, ForestController controller) {
    final plan = forest.planFor(project);
    final text = Theme.of(context).textTheme;
    final built = forest.hasProject(project);
    return Card(
        key: ValueKey('project-${project.name}'),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(projectIcon(project)),
                const SizedBox(width: 8),
                Expanded(child: Text(project.label, style: text.titleMedium)),
                if (built) const Icon(Icons.check_circle_outline),
              ]),
              const SizedBox(height: 8),
              Text(project.description),
              const SizedBox(height: 8),
              Text(plan.benefit, style: text.labelLarge),
              const SizedBox(height: 12),
              if (built) ...[
                const Text('Established · yours to keep'),
                if (forest.resourceChoices)
                  Text(
                      'Next +${plan.bonus.yieldLabel} in ${forest.bonusIn(project)} task completions',
                      key: ValueKey('bonus-${project.name}')),
              ] else ...[
                if (plan.prerequisite != null)
                  _requirement(
                      forest.hasProject(plan.prerequisite!)
                          ? '${plan.prerequisite!.label} established'
                          : 'Build ${plan.prerequisite!.label} first',
                      forest.hasProject(plan.prerequisite!),
                      onTap: forest.hasProject(plan.prerequisite!) || _busy
                          ? null
                          : () => _act(() =>
                              controller.chooseProject(plan.prerequisite!))),
                _requirement(
                    '${forest.materials} / ${plan.cost.materials} materials',
                    forest.materials >= plan.cost.materials),
                _requirement(
                    '${forest.matureTrees} / ${plan.matureTrees} mature trees',
                    forest.matureTrees >= plan.matureTrees,
                    onTap: _busy ? null : widget.onTendTrees),
                if (plan.cost.water > 0)
                  _requirement('${forest.water} / ${plan.cost.water} water',
                      forest.water >= plan.cost.water),
                if (forest.resourceChoices && forest.canBuild(project))
                  ForestSpendPreview(
                      key: ValueKey('preview-${project.name}'),
                      forest: forest,
                      remaining: forest.resources - plan.cost,
                      action: 'building',
                      building: project),
                if (forest.resourceChoices && !forest.canBuild(project))
                  Text('Grow pines for materials; complete tasks for water.',
                      style: text.bodySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  FilledButton.icon(
                      key: ValueKey('build-${project.name}'),
                      onPressed: !_busy && forest.canBuild(project)
                          ? () => _act(() => controller.buildProject(project),
                              built: project)
                          : null,
                      icon: const Icon(Icons.construction, size: 18),
                      label: const Text('Build')),
                  if (forest.activeProject == project)
                    const Chip(label: Text('Current goal'))
                  else
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () =>
                                _act(() => controller.chooseProject(project)),
                        child: const Text('Make my goal')),
                ]),
              ],
            ])));
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
          key: const ValueKey('balanced-forest-start'),
          onPressed: () async {
            await controller.debugBalancedStart();
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.balance),
          label: const Text('Try a balanced start')),
      const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
              'Resource choices: 8 seeds, 6 water, 12 materials, and one mature pine. You can afford any one habitat. Experiment with your next move.')),
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
          'Use a balanced start to compare choices. Simulate task completions to test automatic habitat bonuses. Resource grants are available when you want to explore freely.'),
      const SizedBox(height: 24),
      TextButton(
          onPressed: controller.debugReset,
          child: const Text('Reset sandbox to a fresh forest')),
    ]);
  }
}
