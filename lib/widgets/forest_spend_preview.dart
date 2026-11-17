import 'package:flutter/material.dart';
import '../models/forest.dart';

class ForestSpendPreview extends StatelessWidget {
  final ForestState forest;
  final ForestResources remaining;
  final String action;
  const ForestSpendPreview(
      {super.key,
      required this.forest,
      required this.remaining,
      required this.action});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('After $action: ${forest.balanceFor(remaining)}',
            style: Theme.of(context).textTheme.bodySmall),
        if (remaining.water < 2)
          Text('A new seedling needs 2 water to mature.',
              style: Theme.of(context).textTheme.bodySmall),
      ]));
}
