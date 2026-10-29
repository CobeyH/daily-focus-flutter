import 'package:flutter/material.dart';
import 'task_icons.dart';

export 'task_icons.dart';

/// A small palette of colors users can pick for a task.
const List<int> taskColors = <int>[
  0xFF247866, // forest
  0xFFEF5350, // red
  0xFF66BB6A, // green
  0xFFFFA726, // orange
  0xFF26C6DA, // cyan
  0xFFAB47BC, // purple
  0xFFEC407A, // pink
  0xFF8D6E63, // brown
];

/// A circular color swatch selector.
class ColorSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const ColorSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in taskColors)
          GestureDetector(
            onTap: () => onChanged(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: selected == c
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
              ),
              child: selected == c
                  ? const Icon(Icons.check, color: Colors.white, size: 22)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Opens the searchable library without filling the task editor with a grid.
class IconSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const IconSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final choice = taskIconFor(selected);
    return OutlinedButton(
      key: const ValueKey('choose-task-icon'),
      onPressed: () async {
        final codePoint = await showDialog<int>(
            context: context, builder: (_) => _IconLibrary(selected: selected));
        if (codePoint != null && context.mounted) onChanged(codePoint);
      },
      child: Row(children: [
        Icon(iconFor(selected), size: 28),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(choice?.label ?? 'Task icon'),
          Text('Choose from ${taskIconChoices.length} icons',
              style: Theme.of(context).textTheme.bodySmall),
        ])),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

class _IconLibrary extends StatefulWidget {
  final int selected;
  const _IconLibrary({required this.selected});

  @override
  State<_IconLibrary> createState() => _IconLibraryState();
}

class _IconLibraryState extends State<_IconLibrary> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filterChanged() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final choices = taskIconChoices
        .where((choice) =>
            (_category == null || choice.category == _category) &&
            choice.matches(_search.text))
        .toList();
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text('Choose an icon',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Close icon picker',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('icon-search'),
              controller: _search,
              onChanged: (_) => _filterChanged(),
              decoration: InputDecoration(
                  labelText: 'Search icons',
                  hintText: 'Try yoga, laundry, or budget',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            _filterChanged();
                          },
                          icon: const Icon(Icons.close))),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                key: const ValueKey('icon-category'),
                initialValue: _category ?? 'All categories',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in [
                    'All categories',
                    ...taskIconCategories
                  ])
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) {
                  _category = value == 'All categories' ? null : value;
                  _filterChanged();
                }),
            const SizedBox(height: 12),
            Text('${choices.length} icon${choices.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Expanded(
              child: choices.isEmpty
                  ? const Center(
                      child: Text(
                          'No matching icons. Try another search or category.',
                          textAlign: TextAlign.center))
                  : LayoutBuilder(builder: (context, constraints) {
                      final columns =
                          (constraints.maxWidth / 104).floor().clamp(2, 6);
                      return Scrollbar(
                        controller: _scroll,
                        child: GridView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.only(right: 8, bottom: 8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    mainAxisExtent: 56 + 36 * textScale),
                            itemCount: choices.length,
                            itemBuilder: (context, index) {
                              final choice = choices[index];
                              final selected =
                                  choice.icon.codePoint == widget.selected;
                              return MergeSemantics(
                                  child: Semantics(
                                selected: selected,
                                child: Tooltip(
                                  message: choice.label,
                                  child: OutlinedButton(
                                    key: ValueKey(
                                        'task-icon-${choice.icon.codePoint}'),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.all(6),
                                        foregroundColor: selected
                                            ? colors.onPrimaryContainer
                                            : colors.onSurface,
                                        backgroundColor: selected
                                            ? colors.primaryContainer
                                            : null,
                                        side: BorderSide(
                                            color: selected
                                                ? colors.primary
                                                : colors.outlineVariant)),
                                    onPressed: () => Navigator.pop(
                                        context, choice.icon.codePoint),
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(choice.icon, size: 28),
                                          const SizedBox(height: 6),
                                          Text(choice.label,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium),
                                        ]),
                                  ),
                                ),
                              ));
                            }),
                      );
                    }),
            ),
          ]),
        ),
      ),
    );
  }
}
