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
import 'package:daily_focus/widgets/forest_landscape.dart';
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
      'level boundaries grow progressively and unlock trees at permanent levels',
      () {
    for (var level = 1; level <= 25; level++) {
      final completed = ForestState.xpForLevel(level) ~/ 10;
      final at = ForestState([for (var i = 0; i < completed; i++) reward(i)]);
      expect(at.level, level);
      expect(at.levelXp, 0);
      expect(at.levelProgress, 0);
      if (level > 1) {
        final before =
            ForestState([for (var i = 0; i < completed - 1; i++) reward(i)]);
        expect(before.level, level - 1);
        expect(before.xpToNextLevel - before.levelXp, 10);
      }
      for (final species in TreeSpecies.values) {
        expect(at.unlocked(species), level >= species.unlockLevel);
      }
    }
    expect(
        ForestState([for (var i = 0; i < 5; i++) reward(i)])
            .unlocked(TreeSpecies.birch),
        isTrue);
    expect(
        ForestState([for (var i = 0; i < 12; i++) reward(i)])
            .unlocked(TreeSpecies.oak),
        isTrue);
  });

  test(
      'legacy trees retain their plots as new trees and levels expand the clearing',
      () {
    const legacy = [
      ForestEvent(id: 'plant-old-1', kind: 'plant', species: TreeSpecies.pine),
      ForestEvent(id: 'plant-old-2', kind: 'plant', species: TreeSpecies.birch)
    ];
    final before = ForestState(legacy);
    final after = ForestState([
      ...legacy,
      for (var i = 0; i < 32; i++) reward(i),
      ForestEvent(
          id: 'plant-0-new',
          kind: 'plant',
          species: TreeSpecies.maple,
          plot: before.nextPlot)
    ]);
    for (final tree in before.trees) {
      final restored = after.trees.firstWhere((t) => t.id == tree.id);
      expect(restored.plot, tree.plot);
      expect(ForestState.positionForPlot(restored.plot),
          ForestState.positionForPlot(tree.plot));
    }
    expect(after.level, 5);
    expect(after.clearingRadius, greaterThan(before.clearingRadius));
    final persisted = ForestState(after.events
        .map((e) => ForestEvent.fromJson(e.toJson()))
        .toList()
        .reversed);
    expect(persisted.trees.map((t) => t.plot), after.trees.map((t) => t.plot));
    expect(persisted.xp, 320);
    final collision = ForestState(const [
      ForestEvent(
          id: 'plant-a', kind: 'plant', species: TreeSpecies.pine, plot: 1),
      ForestEvent(
          id: 'plant-b', kind: 'plant', species: TreeSpecies.birch, plot: 1)
    ]);
    expect(collision.trees.map((t) => t.plot).toSet(), hasLength(3));
  });

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

  testWidgets(
      'continuous forest supports overview, tree selection, panning, and resizing',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await AppStorage(prefs).saveForest([
      for (var i = 0; i < 300; i++) reward(i),
      for (var i = 1; i <= 10; i++)
        ForestEvent(
            id: 'plant-$i', kind: 'plant', species: TreeSpecies.pine, plot: i)
    ]);
    tester.view.physicalSize = const Size(390, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
            theme: focusTheme(Brightness.light), home: const ForestScreen())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ForestLandscape));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View whole forest'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forest-tree-plant-8')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<ForestLandscape>(find.byType(ForestLandscape)).selectedId,
        'plant-8');
    final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const ValueKey('continuous-forest')));
    final beforePan = viewer.transformationController!.value.clone();
    final pan = await tester.startGesture(
        tester.getTopLeft(find.byType(ForestLandscape)) +
            const Offset(70, 200));
    for (var i = 0; i < 5; i++) {
      await pan.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pan.up();
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value, isNot(beforePan));
    final beforeZoom =
        viewer.transformationController!.value.getMaxScaleOnAxis();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(beforeZoom));
    tester.view.physicalSize = const Size(760, 950);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(ForestState(AppStorage(prefs).loadForest()).trees, hasLength(11));
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
    expect(find.text('Level 2'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(ForestLandscape), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('View whole forest'));
    await tester.pumpAndSettle();
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
    expect(ForestState(AppStorage(prefs).loadForest()).trees.last.plot, 1);
    await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Redwood'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Redwood'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unlocks at level 16'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Unlock at level 16'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Unlock at level 16'))
            .onPressed,
        isNull);

    expect(tester.takeException(), isNull);
  });
}
