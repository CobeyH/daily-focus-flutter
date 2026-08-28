import 'package:flutter/material.dart';

/// A small palette of colors users can pick for a task.
const List<int> taskColors = <int>[
  0xFF5C6BC0, // indigo
  0xFFEF5350, // red
  0xFF66BB6A, // green
  0xFFFFA726, // orange
  0xFF26C6DA, // cyan
  0xFFAB47BC, // purple
  0xFFEC407A, // pink
  0xFF8D6E63, // brown
];

/// A small set of Material icons to choose from. Using const [IconData]
/// literals keeps icon tree-shaking working in release builds.
const List<IconData> taskIcons = <IconData>[
  Icons.local_florist,
  Icons.fitness_center,
  Icons.menu_book,
  Icons.self_improvement,
  Icons.restaurant,
  Icons.bed,
  Icons.directions_run,
  Icons.edit,
  Icons.check_circle,
  Icons.water_drop,
];

/// Resolves a stored icon code point back to an [IconData] (falls back to
/// [Icons.flag] if the code point is unknown).
IconData iconFor(int codePoint) {
  for (final i in taskIcons) {
    if (i.codePoint == codePoint) return i;
  }
  return Icons.flag;
}

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

/// A grid of icon choices.
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final icon in taskIcons)
          GestureDetector(
            onTap: () => onChanged(icon.codePoint),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected == icon.codePoint
                    ? const Color(0xFF5C6BC0).withValues(alpha: 0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: selected == icon.codePoint
                    ? Border.all(color: const Color(0xFF5C6BC0), width: 2)
                    : Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(icon, color: Colors.black87),
            ),
          ),
      ],
    );
  }
}
