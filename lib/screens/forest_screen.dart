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
  TreeSpecies _plantSpecies = TreeSpecies.pine;
  bool _busy = false;
  String? _error;
  Future<void> _act(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not save that change. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forest = ref.watch(forestProvider);
    final controller = ref.read(forestProvider.notifier);
    final colors = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme;
    final selected = forest.trees.where((t) => t.id == _selected).firstOrNull ??
        forest.trees.first;
    final species = _plantSpecies;
    return Scaffold(
      appBar: AppBar(title: const Text('Your forest')),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Level ${forest.level}',
                                        style: text.headlineSmall),
                                    Text('${forest.xp} lifetime XP',
                                        style: text.bodyMedium),
                                  ]),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                  value: forest.levelProgress,
                                  semanticsLabel:
                                      'Progress to level ${forest.level + 1}',
                                  semanticsValue:
                                      '${(forest.levelProgress * 100).round()}%'),
                              const SizedBox(height: 8),
                              Text(
                                  '${forest.levelXp} / ${forest.xpToNextLevel} XP to level ${forest.level + 1}',
                                  style: text.bodySmall),
                              const SizedBox(height: 8),
                              Text(
                                  forest.nextUnlock == null
                                      ? 'Your clearing keeps expanding with every level.'
                                      : 'Next tree: ${forest.nextUnlock!.label} at level ${forest.nextUnlock!.unlockLevel}',
                                  style: text.bodyMedium),
                            ]))),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  Chip(
                      avatar: const Icon(Icons.eco_outlined, size: 18),
                      label: Text('${forest.seeds} seeds')),
                  Chip(
                      avatar: const Icon(Icons.water_drop_outlined, size: 18),
                      label: Text('${forest.water} water')),
                  Chip(
                      avatar: const Icon(Icons.park_outlined, size: 18),
                      label: Text('${forest.trees.length} trees')),
                ]),
                const SizedBox(height: 12),
                ForestLandscape(
                    forest: forest,
                    selectedId: selected.id,
                    onSelect: (id) => setState(() => _selected = id)),
                const SizedBox(height: 16),
                Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${selected.species.label} · ${selected.stage}',
                          style: text.titleMedium),
                      FilledButton.icon(
                          onPressed: _busy ||
                                  forest.water < 1 ||
                                  selected.growth >= 2
                              ? null
                              : () =>
                                  _act(() => controller.waterTree(selected.id)),
                          icon: const Icon(Icons.water_drop_outlined),
                          label: Text(selected.growth >= 2
                              ? 'Fully grown'
                              : 'Water tree · 1 water')),
                    ]),
                const SizedBox(height: 28),
                Text('Plant something new', style: text.titleLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final candidate in TreeSpecies.values)
                    ChoiceChip(
                        label: Text(candidate.label),
                        selected: species == candidate,
                        showCheckmark: false,
                        avatar: Icon(
                            forest.unlocked(candidate)
                                ? Icons.eco_outlined
                                : Icons.lock_outline,
                            size: 18),
                        onSelected: (_) =>
                            setState(() => _plantSpecies = candidate)),
                ]),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                  width: 86,
                                  height: 110,
                                  child: ForestTreeArt(
                                      species: species, growth: 2)),
                              Text(species.label, style: text.titleMedium),
                              const SizedBox(height: 6),
                              Text(forest.unlocked(species)
                                  ? '${species.seedCost} seeds · grows with 2 water'
                                  : 'Unlocks at level ${species.unlockLevel} · keep earning XP by completing tasks'),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                  onPressed: _busy ||
                                          !forest.unlocked(species) ||
                                          forest.seeds < species.seedCost
                                      ? null
                                      : () => _act(() async {
                                            final id =
                                                await controller.plant(species);
                                            if (mounted) {
                                              setState(() => _selected = id);
                                            }
                                          }),
                                  icon: Icon(forest.unlocked(species)
                                      ? Icons.add
                                      : Icons.lock_outline),
                                  label: Text(forest.unlocked(species)
                                      ? 'Plant ${species.label.toLowerCase()}'
                                      : 'Unlock at level ${species.unlockLevel}')),
                            ]))),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: colors.error)),
                const SizedBox(height: 16),
                Text(
                    'Each completed task earns 10 XP, 1 seed, and 1 water. Levels, trees, and resources never decay. Undo keeps your rewards; completing the same occurrence again does not earn more.',
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ]))),
    );
  }
}
