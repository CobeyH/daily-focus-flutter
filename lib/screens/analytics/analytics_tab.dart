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
    List<Save> saves = ref.watch(savesProvider.notifier).lastWeek();
    return ListView(
      children: saves.map((e) => Text(e.name)).toList(),
    );
  }
}
