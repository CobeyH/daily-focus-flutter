import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'page_router.dart';
import 'providers/task_provider.dart';

class StateChange extends ConsumerStatefulWidget {
  const StateChange({Key? key}) : super(key: key);

  @override
  StateChangeState createState() => StateChangeState();
}

class StateChangeState extends ConsumerState<StateChange>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(tasksProvider.notifier).save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const PageRouter();
  }
}
