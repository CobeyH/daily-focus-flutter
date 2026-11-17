import 'package:flutter/material.dart';
import '../models/forest.dart';

class ForestSpendPreview extends StatelessWidget {
  final ForestState forest;
  final ForestResources remaining;
  final String action;
  final ForestProject? building;
  const ForestSpendPreview(
      {super.key,
      required this.forest,
      required this.remaining,
      required this.action,
      this.building});
  @override
  Widget build(BuildContext context) {
    final shortfall = forest.goalShortfall(remaining, building: building);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('After $action: ${remaining.balance}',
              style: Theme.of(context).textTheme.bodySmall),
          if (remaining.water < 2)
            Text(
                'Water left: ${remaining.water}. A new seedling needs 2 water to mature.',
                style: Theme.of(context).textTheme.bodySmall),
          if (shortfall != null)
            Text(shortfall,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        ]));
  }
}
