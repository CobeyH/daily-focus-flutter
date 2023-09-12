import 'package:daily_focus/providers/saves_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/save.dart';

class AnalyticsTab extends ConsumerStatefulWidget {
  const AnalyticsTab({Key? key}) : super(key: key);

  @override
  AnalyticsTabState createState() => AnalyticsTabState();
}

class AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  @override
  Widget build(BuildContext context) {
    final savesFuture = ref.watch(savesProvider);

    return savesFuture.when(
        data: (List<Save> saves) {
          if (saves.isEmpty) return const Text("No saves");
          return ListView(children: saves.map((e) => Text(e.name)).toList());
        },
        error: (err, _) => const Text("Error"),
        loading: () => const CircularProgressIndicator());
  }
}
