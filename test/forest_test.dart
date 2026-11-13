import 'package:daily_focus/models/forest.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/providers/forest_provider.dart';
import 'package:daily_focus/screens/forest_screen.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/storage/remote_storage.dart';
import 'package:daily_focus/storage/sync_coordinator.dart';
import 'package:daily_focus/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ForestEvent reward(int i) => ForestEvent(id: 'reward-$i', kind: 'reward');

class ForestRemote implements RemoteStorage {
  RemoteSnapshot snapshot;
  ForestRemote(this.snapshot);
  @override
  bool get isSignedIn => true;
  @override
  Future<RemoteSnapshot> pull() async => snapshot;
  @override
  Future<void> push({required RemoteSnapshot snapshot}) async {
    this.snapshot = snapshot;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'forest growth caps, deduplicates rewards, and unlocks without spending away unlocks',
      () {
    final state = ForestState([
      for (var i = 0; i < 12; i++) reward(i),
      reward(0),
      const ForestEvent(
          id: 'plant-birch', kind: 'plant', species: TreeSpecies.birch),
      for (var i = 0; i < 5; i++)
        ForestEvent(id: 'water-$i', kind: 'water', treeId: 'starter'),
    ]);
    expect(state.completions, 12);
    expect(state.seeds, 8);
    expect(state.water, 10);
    expect(state.trees.first.growth, 2);
    expect(state.unlocked(TreeSpecies.oak), isTrue);
    expect(
        ForestEvent.fromJson(state.events[0].toJson()).id, state.events[0].id);
  });

  test(
      'rewards once at full completion; undo, skips, edits, and deletion never remove them',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 11, 13, 13);
    final task = Task(
        id: 'laundry',
        name: 'Laundry',
        type: TaskType.multiStep,
        goal: 2,
        step: 1,
        steps: const ['Wash', 'Dry'],
        color: 0,
        icon: 0,
        createdAt: DateTime(2026, 11, 12));
    await AppStorage(prefs).saveTasks([task]);
    ProviderContainer open() => ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeSourceProvider.overrideWithValue(() => now)
        ]);
    var container = open();
    final controller = container.read(appControllerProvider.notifier);
    await controller.increment(task);
    expect(container.read(forestProvider).completions, 0);
    await controller.increment(task);
    expect(container.read(forestProvider).seeds, 1);
    await controller.undoCompletion(task, occurrenceKey: '2026-11-13');
    expect(container.read(forestProvider).seeds, 1);
    await controller.increment(task);
    expect(container.read(forestProvider).seeds, 1);
    await controller.skip(task, occurrenceKey: '2026-11-13');
    expect(container.read(forestProvider).seeds, 1);
    now = DateTime(2026, 11, 14, 13);
    await controller.markComplete(task);
    expect(container.read(forestProvider).seeds, 2);
    await controller.deleteTask(task.id);
    expect(container.read(forestProvider).seeds, 2);
    container.dispose();
    container = open();
    addTearDown(container.dispose);
    expect(container.read(forestProvider).completions, 2);
    expect(container.read(forestProvider).water, 2);
    await container.read(forestProvider.notifier).waterTree('starter');
    expect(container.read(forestProvider).trees.first.growth, 1);
    expect(container.read(forestProvider).water, 1);
    await expectLater(
        container.read(forestProvider.notifier).plant(TreeSpecies.pine),
        throwsStateError);
    await expectLater(
        container.read(forestProvider.notifier).plant(TreeSpecies.oak),
        throwsStateError);
    expect(container.read(forestProvider).seeds, 2);
  });

  test('forest merge keeps both devices actions without doubling a completion',
      () async {
    SharedPreferences.setMockInitialValues({});
    final local = AppStorage(await SharedPreferences.getInstance());
    await local.saveForest([
      reward(0),
      const ForestEvent(id: 'water-local', kind: 'water', treeId: 'starter')
    ]);
    final remote = ForestRemote(RemoteSnapshot(
        tasks: [], entries: [], timers: [], forest: [reward(0), reward(1)]));
    final sync = SyncCoordinator(local, remote);
    addTearDown(sync.dispose);
    await sync.pullAndMerge();
    await sync.pushLocal();
    await sync.pullAndMerge();
    final state = ForestState(local.loadForest());
    expect(state.completions, 2);
    expect(state.water, 1);
    expect(remote.snapshot.forest, hasLength(3));
  });

  testWidgets('forest can water and plant, persists, and fits enlarged text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await AppStorage(prefs).saveForest([for (var i = 0; i < 5; i++) reward(i)]);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
            theme: focusTheme(Brightness.dark),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!),
            home: const ForestScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('5 seeds'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Water tree · 1 water'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water tree · 1 water'));
    await tester.pumpAndSettle();
    expect(ForestState(AppStorage(prefs).loadForest()).trees.first.growth, 1);
    await tester.scrollUntilVisible(find.text('Plant pine'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plant pine'));
    await tester.pumpAndSettle();
    expect(ForestState(AppStorage(prefs).loadForest()).trees, hasLength(2));
    expect(ForestState(AppStorage(prefs).loadForest()).seeds, 2);
    expect(tester.takeException(), isNull);
  });
}
