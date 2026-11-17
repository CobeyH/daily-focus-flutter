import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forest.dart';
import '../providers/forest_provider.dart';
import '../widgets/forest_landscape.dart';
import '../widgets/forest_tree.dart';
import '../widgets/forest_projects.dart';
import '../widgets/forest_spend_preview.dart';
import '../widgets/forest_reward_overlay.dart';
import '../providers/forest_reward_provider.dart';

class ForestScreen extends ConsumerStatefulWidget {
  const ForestScreen({super.key});
  @override
  ConsumerState<ForestScreen> createState() => _ForestScreenState();
}

class _ForestScreenState extends ConsumerState<ForestScreen> {
  String _selected = 'starter';
  bool _busy = false;
  String? _error;

  Future<void> _water(String id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(forestProvider.notifier).waterTree(id);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not save that change. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sheet(Widget child) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (context) => UncontrolledProviderScope(
            container: container,
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .78,
                child: child)));
  }

  void _nursery({TreeSpecies? suggested}) => _sheet(_Nursery(
      suggested: suggested,
      onPlanted: (id) {
        if (mounted) setState(() => _selected = id);
      }));

  void _projects() => _sheet(ForestProjects(
      onFindSpecies: _findSpecies,
      onTendTrees: () {
        final forest = ref.read(forestProvider);
        final wanted = forest.activeProject == null
            ? (forest.activeRestoration?.diversity == true
                ? TreeSpecies.values
                    .where((s) => !forest.matureSpecies.contains(s))
                    .firstOrNull
                : null)
            : forest.planFor(forest.activeProject!).species;
        if (wanted != null) {
          _findSpecies(wanted);
          return;
        }
        Navigator.pop(context);
        final growing = ref
            .read(forestProvider)
            .trees
            .where((t) => t.growth < 2)
            .firstOrNull;
        if (growing == null) {
          _nursery();
        } else {
          setState(() => _selected = growing.id);
        }
      }));

  void _findSpecies(TreeSpecies species) {
    Navigator.pop(context);
    final growing = ref
        .read(forestProvider)
        .trees
        .where((t) => t.species == species && t.growth < 2)
        .firstOrNull;
    if (growing != null) {
      setState(() => _selected = growing.id);
    } else {
      _nursery(suggested: species);
    }
  }

  void _debug() {
    if (!kDebugMode) return;
    if (ref.read(forestProvider.notifier).isSandbox) {
      _sheet(const ForestSandboxControls());
      return;
    }
    final initial = ref.read(forestProvider).events;
    Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => ProviderScope(
                  overrides: [
                    forestProvider.overrideWith(() => ForestController.sandbox(
                        initial,
                        restorationGoals: true)),
                    forestRewardProvider
                        .overrideWith(ForestRewardController.new),
                  ],
                  child: ForestRewardOverlay(
                      child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => const ForestScreen()),
                  )),
                )));
  }

  void _collection() => _sheet(Consumer(builder: (context, ref, child) {
        final forest = ref.watch(forestProvider);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: forest.trees.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('Your trees',
                      style: Theme.of(context).textTheme.headlineSmall));
            }
            final tree = forest.trees[index - 1];
            return ListTile(
                key: ValueKey('collection-${tree.id}'),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: SizedBox(
                    width: 52,
                    height: 72,
                    child: ForestTreeArt(
                        species: tree.species, growth: tree.growth)),
                title: Text('${tree.species.label} · Tree ${tree.plot + 1}'),
                subtitle: Text(tree.stage),
                selected: tree.id == _selected,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() => _selected = tree.id);
                  Navigator.pop(context);
                });
          },
        );
      }));

  void _progress() => _sheet(Consumer(builder: (context, ref, child) {
        final forest = ref.watch(forestProvider),
            text = Theme.of(context).textTheme;
        return ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            children: [
              Text('Level ${forest.level}', style: text.headlineMedium),
              const SizedBox(height: 8),
              Text('${forest.xp} lifetime XP · ${forest.trees.length} trees'),
              Text(forest.resourceBalance),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: forest.levelProgress),
              const SizedBox(height: 8),
              Text(
                  '${forest.levelXp} / ${forest.xpToNextLevel} XP to level ${forest.level + 1}'),
              const SizedBox(height: 24),
              Text('A forest that stays with you', style: text.titleLarge),
              const SizedBox(height: 8),
              Text('Each completed task earns 10 XP and planting resources. '
                  '${forest.restorationGoals ? 'Plant with materials and grow with water. Trees unlock habitats and restoration milestones. ' : 'Mature trees contribute 3 extra materials. '}'
                  'Your clearing expands with your level. Trees, levels, and resources never decay. '
                  'Undo keeps your rewards; the same occurrence never earns twice.'),
              const SizedBox(height: 20),
              const Text('Grow each variety to discover its appearance. '
                  'Previews show the best stage you have grown.'),
              const SizedBox(height: 12),
              for (final species in TreeSpecies.values)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                        width: 48,
                        height: 64,
                        child: ForestSpeciesPreview(
                            forest: forest, species: species)),
                    title: Text(species.label),
                    subtitle: Text(
                        'Level ${species.unlockLevel} · ${species.seedCost} ${forest.restorationGoals ? 'materials' : 'seeds'}'),
                    trailing: Icon(forest.unlocked(species)
                        ? Icons.check_rounded
                        : Icons.lock_outline)),
            ]);
      }));

  @override
  Widget build(BuildContext context) {
    final forest = ref.watch(forestProvider);
    final selected = forest.trees.where((t) => t.id == _selected).firstOrNull ??
        forest.trees.first;
    final text = Theme.of(context).textTheme;
    final scene = ForestLandscape(
        forest: forest,
        selectedId: selected.id,
        onSelect: (id) => setState(() => _selected = id));
    final dock = _careDock(forest, selected);
    return Scaffold(
      appBar: AppBar(
          leading: ref.read(forestProvider.notifier).isSandbox
              ? BackButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop())
              : null,
          title: Text(
              ref.read(forestProvider.notifier).isSandbox
                  ? 'Forest sandbox'
                  : 'Your forest',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          actions: [
            if (kDebugMode)
              IconButton(
                  tooltip: ref.read(forestProvider.notifier).isSandbox
                      ? 'Sandbox controls'
                      : 'Open debug sandbox',
                  onPressed: _debug,
                  icon: const Icon(Icons.bug_report_outlined)),
            IconButton(
                tooltip: 'Your trees (${forest.trees.length})',
                onPressed: _collection,
                icon: const Icon(Icons.forest_outlined)),
          ]),
      body: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(builder: (context, available) {
            final compact = available.maxWidth < 360 ||
                available.maxHeight < 620 ||
                MediaQuery.textScalerOf(context).scale(16) > 20;
            return Column(children: [
              if (ref.read(forestProvider.notifier).isSandbox)
                Material(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Center(
                        child: TextButton.icon(
                            onPressed: _debug,
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(forest.restorationGoals
                                ? 'Restoration goals · sandbox'
                                : 'Sandbox · temporary progress')))),
              if (compact)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      Row(children: [
                        TextButton(
                            onPressed: _progress,
                            child: Text('Level ${forest.level}')),
                        Expanded(
                            child: Wrap(spacing: 8, children: [
                          Text(
                              forest.restorationGoals
                                  ? '${forest.materials} materials'
                                  : '${forest.seeds} seeds',
                              style: text.bodySmall),
                          Text('${forest.water} water', style: text.bodySmall),
                        ])),
                        IconButton(
                            key: const ValueKey('forest-project-summary'),
                            tooltip: 'Sanctuary projects',
                            onPressed: _projects,
                            icon: const Icon(Icons.construction_outlined)),
                      ]),
                      LinearProgressIndicator(value: forest.levelProgress),
                    ]))
              else
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                            spacing: 8,
                            runSpacing: 0,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ActionChip(
                                  avatar: const Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 18),
                                  label: Text('Level ${forest.level}'),
                                  onPressed: _progress),
                              Chip(
                                  avatar:
                                      const Icon(Icons.eco_outlined, size: 18),
                                  label: Text(forest.restorationGoals
                                      ? '${forest.materials} materials'
                                      : '${forest.seeds} seeds')),
                              Chip(
                                  avatar: const Icon(Icons.water_drop_outlined,
                                      size: 18),
                                  label: Text('${forest.water} water')),
                            ]),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                            value: forest.levelProgress,
                            semanticsLabel:
                                'Progress to level ${forest.level + 1}',
                            semanticsValue:
                                '${(forest.levelProgress * 100).round()}%'),
                        const SizedBox(height: 6),
                        Text(
                            forest.nextUnlock == null
                                ? 'Your clearing keeps growing'
                                : 'Next: ${forest.nextUnlock!.label} at level ${forest.nextUnlock!.unlockLevel}',
                            style: text.bodySmall),
                        ForestProjectSummary(forest: forest, onTap: _projects),
                      ],
                    )),
              Expanded(child: LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth >= 760 ||
                    (constraints.maxWidth >= 540 &&
                        constraints.maxHeight < 420)) {
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: scene),
                        SizedBox(
                            width: 300,
                            child: SingleChildScrollView(child: dock)),
                      ]);
                }
                return Column(children: [
                  Expanded(child: scene),
                  if (compact)
                    ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * .48),
                        child: SingleChildScrollView(child: dock))
                  else
                    dock
                ]);
              })),
            ]);
          })),
    );
  }

  Widget _careDock(ForestState forest, ForestTree selected) {
    final colors = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme;
    final index = forest.trees.indexOf(selected);
    void step(int direction) => setState(() =>
        _selected = forest.trees[(index + direction) % forest.trees.length].id);
    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    SizedBox(
                        width: 52,
                        height: 64,
                        child: ForestTreeArt(
                            species: selected.species,
                            growth: selected.growth)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              '${selected.species.label} · Tree ${selected.plot + 1}',
                              style: text.titleMedium),
                          Text(selected.stage, style: text.bodySmall),
                        ])),
                    if (forest.trees.length > 1) ...[
                      IconButton(
                          tooltip: 'Previous tree',
                          onPressed: () => step(-1),
                          icon: const Icon(Icons.chevron_left)),
                      IconButton(
                          tooltip: 'Next tree',
                          onPressed: () => step(1),
                          icon: const Icon(Icons.chevron_right)),
                    ],
                  ]),
                  if (forest.restorationGoals) ...[
                    const SizedBox(height: 8),
                    Text(
                        forest.activeGoalTitle == null
                            ? 'Grow trees to reveal habitats and restore the forest.'
                            : '${forest.activeGoalTitle}: ${forest.goalAdvice}',
                        style: text.bodySmall),
                    if (selected.growth < 2 && forest.water >= 1)
                      ForestSpendPreview(
                          forest: forest,
                          remaining: forest.afterWatering(selected),
                          action: 'watering'),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                        onPressed:
                            _busy || forest.water < 1 || selected.growth >= 2
                                ? null
                                : () => _water(selected.id),
                        icon: const Icon(Icons.water_drop_outlined, size: 18),
                        label: Text(selected.growth >= 2
                            ? 'Fully grown'
                            : 'Water · 1')),
                    OutlinedButton.icon(
                        onPressed: _busy ? null : _nursery,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Plant a tree')),
                  ]),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!,
                            style: TextStyle(color: colors.error))),
                ]),
          )),
    );
  }
}

class _Nursery extends ConsumerStatefulWidget {
  final ValueChanged<String> onPlanted;
  final TreeSpecies? suggested;
  const _Nursery({required this.onPlanted, this.suggested});
  @override
  ConsumerState<_Nursery> createState() => _NurseryState();
}

class _NurseryState extends ConsumerState<_Nursery> {
  bool _busy = false;
  String? _error;
  Future<void> _plant(TreeSpecies species) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(forestProvider.notifier).plant(species);
      if (!mounted) return;
      widget.onPlanted(id);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not plant that tree. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final forest = ref.watch(forestProvider),
        text = Theme.of(context).textTheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: TreeSpecies.values.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plant a tree', style: text.headlineSmall),
                    Text('${forest.resourceBalance} · Level ${forest.level}'),
                    const SizedBox(height: 4),
                    Text('Previews reveal only the stages you have grown.',
                        style: text.bodySmall),
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ]));
        }
        final suggested = [
          if (widget.suggested != null) widget.suggested!,
          ...TreeSpecies.values.where((s) =>
              forest.restorationGoals &&
              forest.helpsGoal(s) &&
              s != widget.suggested)
        ];
        final ordered = [
          ...suggested,
          ...TreeSpecies.values.where((s) => !suggested.contains(s))
        ];
        final species = ordered[index - 1];
        final unlocked = forest.unlocked(species);
        return Card(
          key: ValueKey('nursery-${species.name}'),
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                SizedBox(
                    width: 68,
                    height: 100,
                    child:
                        ForestSpeciesPreview(forest: forest, species: species)),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(species.label, style: text.titleMedium),
                      Text(
                          unlocked
                              ? '${species.seedCost} ${forest.restorationGoals ? 'materials' : 'seeds'} · 2 water to grow'
                              : 'Unlocks at level ${species.unlockLevel}${species == TreeSpecies.willow && !forest.restorationGoals ? ' or restore the pond' : ''}',
                          style: text.bodySmall),
                      if (forest.restorationGoals) ...[
                        const SizedBox(height: 4),
                        const Text('Counts toward mature-tree achievements.'),
                        if (forest.helpsGoal(species))
                          Text('Helps your ${forest.activeGoalTitle} goal',
                              style: text.labelSmall?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                        if (forest.canPlant(species))
                          ForestSpendPreview(
                              forest: forest,
                              remaining: forest.resources -
                                  forest.plantingCost(species),
                              action: 'planting'),
                      ],
                      const SizedBox(height: 8),
                      FilledButton.icon(
                          onPressed:
                              !_busy && unlocked && forest.canPlant(species)
                                  ? () => _plant(species)
                                  : null,
                          icon: Icon(unlocked ? Icons.add : Icons.lock_outline,
                              size: 18),
                          label: Text(unlocked
                              ? 'Plant ${species.label.toLowerCase()}'
                              : 'Level ${species.unlockLevel}')),
                    ])),
              ])),
        );
      },
    );
  }
}
