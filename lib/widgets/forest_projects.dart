import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forest.dart';
import '../providers/forest_provider.dart';

IconData projectIcon(ForestProject project) => switch (project) {
      ForestProject.nursery => Icons.yard_outlined,
      ForestProject.birdhouse => Icons.flutter_dash,
      ForestProject.pond => Icons.water_outlined,
    };
IconData restorationIcon(ForestRestoration milestone) => switch (milestone) {
      ForestRestoration.grass => Icons.grass,
      ForestRestoration.lichen => Icons.spa_outlined,
      ForestRestoration.wildflowers => Icons.local_florist_outlined,
    };

class ForestProjectSummary extends StatelessWidget {
  final ForestState forest;
  final VoidCallback onTap;
  const ForestProjectSummary(
      {super.key, required this.forest, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final project = forest.activeProject, milestone = forest.activeRestoration;
    final finished = forest.projects.length == ForestProject.values.length &&
        (!forest.restorationGoals ||
            forest.restorations.length == ForestRestoration.values.length);
    final title = forest.activeGoalTitle ??
        (finished ? 'Your sanctuary is thriving' : 'Choose a habitat goal');
    return ListTile(
        key: const ValueKey('forest-project-summary'),
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(project != null
            ? projectIcon(project)
            : milestone != null
                ? restorationIcon(milestone)
                : Icons.park_outlined),
        title: Text(title),
        subtitle: project == null && milestone == null
            ? Text(finished
                ? 'A living forest, yours to keep'
                : 'See which trees bring your forest to life')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(forest.restorationGoals
                    ? (project != null
                        ? forest.speciesProgress(project)
                        : '${forest.restorationCount(milestone!)} / ${milestone.target} ${milestone.diversity ? 'mature varieties' : 'mature trees'}')
                    : '${forest.materials} / ${forest.planFor(project!).cost.materials} materials · ${forest.matureTrees} / ${forest.planFor(project).matureTrees} mature trees'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                    value: project != null
                        ? forest.projectProgress(project)
                        : forest.restorationProgress(milestone!)),
              ]),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap);
  }
}

class ForestProjects extends ConsumerStatefulWidget {
  final VoidCallback onTendTrees;
  final ValueChanged<TreeSpecies>? onFindSpecies;
  const ForestProjects(
      {super.key, required this.onTendTrees, this.onFindSpecies});
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
    final forest = ref.watch(forestProvider),
        controller = ref.read(forestProvider.notifier),
        text = Theme.of(context).textTheme;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
              forest.restorationGoals
                  ? 'Habitat achievements'
                  : 'Build your sanctuary',
              style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(forest.resourceBalance),
          const SizedBox(height: 8),
          Text(forest.restorationGoals
              ? 'Choose what you want to bring to life. Grow the matching trees and the habitat appears automatically. Materials and water come from completed tasks.'
              : 'Every completed task earns 1 material. Each tree you grow to maturity contributes 3 more. Projects and residents stay forever.'),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_celebrated != null && !forest.restorationGoals)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    '${_celebrated!.label} complete!\n${forest.planFor(_celebrated!).benefit}')),
          const SizedBox(height: 16),
          for (final project in ForestProject.values)
            forest.restorationGoals
                ? _achievement(forest, project, controller)
                : _legacy(forest, project, controller),
          if (forest.restorationGoals) ...[
            const SizedBox(height: 8),
            Text('Restore the ecosystem', style: text.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'These milestones change the forest itself. Every change is permanent.'),
            const SizedBox(height: 12),
            for (final milestone in ForestRestoration.values)
              _ecology(forest, milestone, controller),
          ],
        ]);
  }

  Widget _card(Key key, IconData icon, String title, bool done,
          List<Widget> children) =>
      Card(
          key: key,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icon),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(title,
                              style: Theme.of(context).textTheme.titleMedium)),
                      if (done) const Icon(Icons.check_circle_outline)
                    ]),
                    const SizedBox(height: 12),
                    ...children
                  ])));
  Widget _achievement(
      ForestState forest, ForestProject project, ForestController controller) {
    final plan = forest.planFor(project),
        species = plan.species!,
        done = forest.hasProject(project);
    return _card(ValueKey('project-${project.name}'), projectIcon(project),
        project.label, done, [
      Text(plan.benefit),
      const SizedBox(height: 12),
      Text(forest.speciesProgress(project),
          key: ValueKey('requirement-${project.name}')),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: forest.projectProgress(project)),
      if (done)
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Habitat established · yours to keep'))
      else ...[
        const SizedBox(height: 8),
        Text(!forest.unlocked(species)
            ? '${species.label} unlocks at level ${species.unlockLevel}.'
            : '${forest.growingCount(species)} growing · ${_toPlant(forest, project)} still to plant'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton(
              onPressed: _busy
                  ? null
                  : () => _act(() => controller.chooseProject(project)),
              child: Text(forest.activeProject == project
                  ? 'Current goal'
                  : 'Make my goal')),
          OutlinedButton.icon(
              key: ValueKey('find-${species.name}'),
              onPressed: () {
                if (widget.onFindSpecies != null) {
                  widget.onFindSpecies!(species);
                } else {
                  widget.onTendTrees();
                }
              },
              icon: const Icon(Icons.park_outlined, size: 18),
              label: Text('Find ${species.label.toLowerCase()} trees')),
        ]),
      ],
    ]);
  }

  int _toPlant(ForestState forest, ForestProject project) {
    final plan = forest.planFor(project),
        remaining = plan.matureTrees -
            forest.matureCount(plan.species!) -
            forest.growingCount(plan.species!);
    return remaining < 0 ? 0 : remaining;
  }

  Widget _ecology(ForestState forest, ForestRestoration milestone,
      ForestController controller) {
    final done = forest.restorations.contains(milestone);
    return _card(ValueKey('restoration-${milestone.name}'),
        restorationIcon(milestone), milestone.label, done, [
      Text(milestone.reward),
      const SizedBox(height: 12),
      Text(
          '${forest.restorationCount(milestone)} / ${milestone.target} ${milestone.diversity ? 'mature varieties' : 'mature trees'}'),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: forest.restorationProgress(milestone)),
      if (done)
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Restored · a permanent part of your forest'))
      else ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          TextButton(
              onPressed: _busy
                  ? null
                  : () => _act(() => controller.chooseRestoration(milestone)),
              child: Text(forest.activeRestoration == milestone
                  ? 'Current goal'
                  : 'Make my goal')),
          OutlinedButton(
              onPressed: widget.onTendTrees, child: const Text('Choose trees')),
        ]),
      ],
    ]);
  }

  Widget _legacy(
      ForestState forest, ForestProject project, ForestController controller) {
    final plan = forest.planFor(project), done = forest.hasProject(project);
    return _card(ValueKey('project-${project.name}'), projectIcon(project),
        project.label, done, [
      Text(project.description),
      const SizedBox(height: 8),
      Text(plan.benefit),
      const SizedBox(height: 12),
      if (done)
        const Text('Established · yours to keep')
      else ...[
        if (plan.prerequisite != null)
          Text(forest.hasProject(plan.prerequisite!)
              ? '${plan.prerequisite!.label} established'
              : 'Build ${plan.prerequisite!.label} first'),
        Text('${forest.materials} / ${plan.cost.materials} materials'),
        TextButton(
            onPressed: widget.onTendTrees,
            child: Text(
                '${forest.matureTrees} / ${plan.matureTrees} mature trees')),
        if (plan.cost.water > 0)
          Text('${forest.water} / ${plan.cost.water} water'),
        Wrap(spacing: 8, children: [
          FilledButton.icon(
              key: ValueKey('build-${project.name}'),
              onPressed: _busy || !forest.canBuild(project)
                  ? null
                  : () => _act(() => controller.buildProject(project),
                      built: project),
              icon: const Icon(Icons.construction, size: 18),
              label: const Text('Build')),
          if (forest.activeProject == project)
            const Chip(label: Text('Current goal'))
          else
            TextButton(
                onPressed: _busy
                    ? null
                    : () => _act(() => controller.chooseProject(project)),
                child: const Text('Make my goal')),
        ]),
      ],
    ]);
  }
}

class ForestSandboxControls extends ConsumerWidget {
  const ForestSandboxControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forest = ref.watch(forestProvider),
        controller = ref.read(forestProvider.notifier);
    if (!controller.isSandbox) return const SizedBox.shrink();
    Future<void> start(Future<void> Function() action) async {
      await action();
      if (context.mounted) Navigator.pop(context);
    }

    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Forest debug sandbox',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
          'Temporary progress. Nothing here changes your tasks or saves to your real forest or Firebase.'),
      const SizedBox(height: 12),
      Text(
          'Level ${forest.level} · ${forest.xp} XP\n${forest.resourceBalance}'),
      const SizedBox(height: 16),
      FilledButton.icon(
          key: const ValueKey('restoration-forest-start'),
          onPressed: () => start(controller.debugRestorationStart),
          icon: const Icon(Icons.eco_outlined),
          label: const Text('Try restoration goals')),
      const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
              'Start at level 5 with a mature pine, 32 materials, and 30 water. Pin a habitat or ecosystem goal and choose the trees to grow.')),
      OutlinedButton(
          onPressed: forest.activeGoalTitle == null
              ? null
              : () => start(controller.debugCompleteGoal),
          child: const Text('Complete pinned tree goal')),
      OutlinedButton(
          onPressed: () => start(controller.debugRestoredForest),
          child: const Text('Preview restored forest')),
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
          'Trees mature with two water actions. Habitat and restoration milestones reveal themselves automatically; no collection or building step is needed.'),
      const SizedBox(height: 24),
      TextButton(
          onPressed: controller.debugReset,
          child: const Text('Reset sandbox to a fresh forest')),
    ]);
  }
}
