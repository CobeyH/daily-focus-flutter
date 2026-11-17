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
import 'package:daily_focus/widgets/forest_scene_geometry.dart';
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

  test(
      'isometric overview frames existing plots and tall trees across screen sizes',
      () {
    final forest = ForestState([
      for (var i = 0; i < 500; i++) reward(i),
      for (var i = 1; i <= 80; i++)
        ForestEvent(
            id: 'tree-$i',
            kind: 'plant',
            species: TreeSpecies.redwood,
            plot: i),
    ]);
    for (final size in [
      const Size(320, 350),
      const Size(900, 500),
      const Size(340, 170)
    ]) {
      final layout = ForestSceneLayout(forest, size);
      final viewport = Offset.zero & size;
      for (final tree in forest.trees) {
        final base = layout.treeBase(tree);
        expect(viewport.contains(base), isTrue);
        expect(viewport.contains(base - Offset(0, 155 * layout.scale)), isTrue);
      }
    }
    final before = forest.trees.map((tree) => tree.plot).toList();
    ForestSceneLayout(forest, const Size(390, 600),
        focusedTree: forest.trees.last);
    expect(forest.trees.map((tree) => tree.plot), before);
  });

  testWidgets(
      'forest fills its scene, selects trees, and never competes with page scrolling',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await AppStorage(prefs).saveForest([
      for (var i = 0; i < 12; i++) reward(i),
      const ForestEvent(
          id: 'plant-1', kind: 'plant', species: TreeSpecies.pine, plot: 1),
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
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    final scene = find.byType(ForestLandscape);
    expect(tester.getSize(scene).height, greaterThan(400));
    final tree = find.byKey(const ValueKey('forest-tree-plant-1'));
    await tester.tap(tree);
    await tester.pumpAndSettle();
    expect(tester.widget<ForestLandscape>(scene).selectedId, 'plant-1');
    final beforeZoom = tester.getSize(tree).width;
    await tester.tap(find.byTooltip('Closer look at selected tree'));
    await tester.pumpAndSettle();
    expect(tester.getSize(tree).width, greaterThan(beforeZoom));
    final before = tester.getRect(scene);
    await tester.dragFrom(tester.getTopLeft(scene) + const Offset(40, 150),
        const Offset(70, -100));
    await tester.pumpAndSettle();
    expect(tester.getRect(scene), before);
    await tester.tap(find.byTooltip('View whole forest'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next tree'));
    await tester.pumpAndSettle();
    expect(tester.widget<ForestLandscape>(scene).selectedId, 'starter');
    tester.view.physicalSize = const Size(800, 430);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // On a short wide window only the independent controls can scroll.
    expect(find.ancestor(of: scene, matching: find.byType(Scrollable)),
        findsNothing);
    expect(ForestState(AppStorage(prefs).loadForest()).trees, hasLength(2));
  });

  testWidgets(
      'forest watering and nursery persist with enlarged text and locked varieties',
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
    expect(find.text('5 seeds'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    await tester.tap(find.text('Water · 1'));
    await tester.pumpAndSettle();
    expect(ForestState(AppStorage(prefs).loadForest()).trees.first.growth, 1);
    await tester.tap(find.text('Plant a tree'));
    await tester.pumpAndSettle();
    final pine = find.byKey(const ValueKey('nursery-pine'));
    await tester
        .tap(find.descendant(of: pine, matching: find.text('Plant pine')));
    await tester.pumpAndSettle();
    final saved = ForestState(AppStorage(prefs).loadForest());
    expect(saved.trees, hasLength(2));
    expect(saved.seeds, 2);
    expect(saved.trees.last.plot, 1);
    expect(
        tester.widget<ForestLandscape>(find.byType(ForestLandscape)).selectedId,
        saved.trees.last.id);
    await tester.tap(find.text('Plant a tree'));
    await tester.pumpAndSettle();
    final redwood = find.byKey(const ValueKey('nursery-redwood'));
    await tester.scrollUntilVisible(redwood, 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Unlocks at level 16'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.descendant(
                of: redwood, matching: find.byType(FilledButton)))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(redwood)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Your trees (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collection-starter')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<ForestLandscape>(find.byType(ForestLandscape)).selectedId,
        'starter');
    await tester.tap(find.text('Level 2'));
    await tester.pumpAndSettle();
    expect(find.text('50 lifetime XP · 2 trees'), findsOneWidget);
    expect(find.textContaining('resources never decay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
