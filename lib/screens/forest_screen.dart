import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forest.dart';
import '../providers/forest_provider.dart';
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
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = forest.trees.where((t) => t.id == _selected).firstOrNull ??
        forest.trees.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Your forest')),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Text('Small actions. A growing forest.',
                    style: text.headlineSmall),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  Chip(
                      avatar: const Icon(Icons.eco_outlined, size: 18),
                      label: Text('${forest.seeds} seeds')),
                  Chip(
                      avatar: const Icon(Icons.water_drop_outlined, size: 18),
                      label: Text('${forest.water} water')),
                ]),
                const SizedBox(height: 12),
                Text(
                    'Every completed task earns 1 seed and 1 water. Missed tasks never take anything away. Your first pine is a gift.',
                    style: text.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 20),
                Container(
                    decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final columns =
                          (constraints.maxWidth / 110).floor().clamp(2, 6);
                      return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 158,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8),
                          itemCount: forest.trees.length,
                          itemBuilder: (context, index) {
                            final tree = forest.trees[index];
                            return Semantics(
                                selected: tree.id == selected.id,
                                child: InkWell(
                                  key: ValueKey('forest-tree-${tree.id}'),
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () =>
                                      setState(() => _selected = tree.id),
                                  child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                              color: tree.id == selected.id
                                                  ? colors.primary
                                                  : Colors.transparent)),
                                      child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Column(children: [
                                            Expanded(
                                                child: ForestTreeArt(
                                                    species: tree.species,
                                                    growth: tree.growth)),
                                            Text(
                                                '${tree.species.label} ${index + 1}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: text.labelMedium),
                                            Text(tree.stage,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: text.labelSmall),
                                          ]))),
                                ));
                          });
                    })),
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
                const SizedBox(height: 8),
                for (final species in TreeSpecies.values)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(species.label, style: text.titleMedium),
                                  const SizedBox(height: 6),
                                  Text(forest.unlocked(species)
                                      ? '${species.seedCost} seeds · grows with 2 water'
                                      : 'Unlocks after ${species.unlockAt} completed tasks · ${forest.completions}/${species.unlockAt}'),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                      onPressed: _busy ||
                                              !forest.unlocked(species) ||
                                              forest.seeds < species.seedCost
                                          ? null
                                          : () => _act(() async {
                                                final id = await controller
                                                    .plant(species);
                                                if (mounted) {
                                                  setState(
                                                      () => _selected = id);
                                                }
                                              }),
                                      icon: Icon(forest.unlocked(species)
                                          ? Icons.add
                                          : Icons.lock_outline),
                                      label: Text(forest.unlocked(species)
                                          ? 'Plant ${species.label.toLowerCase()}'
                                          : 'Keep growing')),
                                ])),
                      )),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: colors.error)),
                const SizedBox(height: 12),
                Text(
                    'Rewards are earned once per scheduled occurrence, after the entire task is finished. Undo keeps your reward; completing it again does not add another. Skips and partial steps do not earn resources.',
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ]))),
    );
  }
}
