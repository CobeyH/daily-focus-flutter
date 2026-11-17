import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forest.dart';
import '../providers/forest_provider.dart';
import '../widgets/forest_landscape.dart';
import '../widgets/forest_tree.dart';

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

  void _sheet(Widget child) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .78, child: child));

  void _nursery() => _sheet(_Nursery(onPlanted: (id) {
        if (mounted) setState(() => _selected = id);
      }));

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
              const SizedBox(height: 16),
              LinearProgressIndicator(value: forest.levelProgress),
              const SizedBox(height: 8),
              Text(
                  '${forest.levelXp} / ${forest.xpToNextLevel} XP to level ${forest.level + 1}'),
              const SizedBox(height: 24),
              Text('A forest that stays with you', style: text.titleLarge),
              const SizedBox(height: 8),
              const Text(
                  'Each completed task earns 10 XP, 1 seed, and 1 water. '
                  'Your clearing expands with your level. Trees, levels, and resources never decay. '
                  'Undo keeps your rewards; the same occurrence never earns twice.'),
              const SizedBox(height: 20),
              for (final species in TreeSpecies.values)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                        width: 48,
                        height: 64,
                        child: ForestTreeArt(species: species, growth: 2)),
                    title: Text(species.label),
                    subtitle: Text(
                        'Level ${species.unlockLevel} · ${species.seedCost} seeds'),
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
      appBar: AppBar(title: const Text('Your forest'), actions: [
        IconButton(
            tooltip: 'Your trees (${forest.trees.length})',
            onPressed: _collection,
            icon: const Icon(Icons.forest_outlined)),
      ]),
      body: SafeArea(
          top: false,
          bottom: false,
          child: Column(children: [
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
                              avatar: const Icon(Icons.auto_awesome_outlined,
                                  size: 18),
                              label: Text('Level ${forest.level}'),
                              onPressed: _progress),
                          Chip(
                              avatar: const Icon(Icons.eco_outlined, size: 18),
                              label: Text('${forest.seeds} seeds')),
                          Chip(
                              avatar: const Icon(Icons.water_drop_outlined,
                                  size: 18),
                              label: Text('${forest.water} water')),
                        ]),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                        value: forest.levelProgress,
                        semanticsLabel: 'Progress to level ${forest.level + 1}',
                        semanticsValue:
                            '${(forest.levelProgress * 100).round()}%'),
                    const SizedBox(height: 6),
                    Text(
                        forest.nextUnlock == null
                            ? 'Your clearing keeps growing'
                            : 'Next: ${forest.nextUnlock!.label} at level ${forest.nextUnlock!.unlockLevel}',
                        style: text.bodySmall),
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
              return Column(children: [Expanded(child: scene), dock]);
            })),
          ])),
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
  const _Nursery({required this.onPlanted});
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
                    Text('${forest.seeds} seeds · Level ${forest.level}'),
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ]));
        }
        final species = TreeSpecies.values[index - 1];
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
                    child: ForestTreeArt(species: species, growth: 2)),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(species.label, style: text.titleMedium),
                      Text(
                          unlocked
                              ? '${species.seedCost} seeds · 2 water to grow'
                              : 'Unlocks at level ${species.unlockLevel}',
                          style: text.bodySmall),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                          onPressed: !_busy &&
                                  unlocked &&
                                  forest.seeds >= species.seedCost
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
