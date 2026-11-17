import 'package:daily_focus/models/forest.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/forest_provider.dart';
import 'package:daily_focus/providers/forest_reward_provider.dart';
import 'package:daily_focus/screens/forest_screen.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/storage/remote_storage.dart';
import 'package:daily_focus/storage/sync_coordinator.dart';
import 'package:daily_focus/theme/app_theme.dart';
import 'package:daily_focus/widgets/forest_projects.dart';
import 'package:daily_focus/widgets/forest_reward_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<ForestEvent> established({int tasks = 50, int mature = 4}) => [
      for (var i = 0; i < tasks; i++)
        ForestEvent(id: 'reward-$i', kind: 'reward'),
      for (var i = 1; i < mature; i++)
        ForestEvent(
            id: 'tree-$i', kind: 'plant', species: TreeSpecies.pine, plot: i),
      for (final id in ['starter', for (var i = 1; i < mature; i++) 'tree-$i'])
        for (var i = 0; i < 2; i++)
          ForestEvent(id: 'water-$id-$i', kind: 'water', treeId: id),
    ];
ForestEvent built(ForestProject project) => ForestEvent(
    id: 'project_${project.name}', kind: 'project', project: project);

class _FailingStorage extends AppStorage {
  _FailingStorage(super.prefs);
  bool fail = true;
  @override
  Future<void> saveForest(List<ForestEvent> events) async {
    if (fail) throw StateError('disk full');
    return super.saveForest(events);
  }
}

class _Remote implements RemoteStorage {
  RemoteSnapshot snapshot;
  int pushes = 0;
  _Remote(this.snapshot);
  @override
  bool get isSignedIn => true;
  @override
  Future<RemoteSnapshot> pull() async => snapshot;
  @override
  Future<void> push({required RemoteSnapshot snapshot}) async {
    this.snapshot = snapshot;
    pushes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('legacy rewards and mature trees contribute permanent materials', () {
    final forest = ForestState(established(tasks: 12, mature: 2));
    expect(forest.materials, 18);
    expect(forest.seeds, 9);
    expect(forest.water, 8);
    expect(forest.canBuild(ForestProject.nursery), isTrue);
    expect(forest.canBuild(ForestProject.birdhouse), isFalse);
    expect(forest.canBuild(ForestProject.pond), isFalse);
    expect(forest.activeProject, ForestProject.nursery);
  });

  test('projects spend once, unlock the chain, and leave tree forms intact',
      () {
    final events = established(tasks: 30);
    final before = ForestState(events);
    final nursery = ForestState([
      ...events,
      built(ForestProject.nursery),
      built(ForestProject.nursery)
    ]);
    expect(nursery.materials, before.materials - 6);
    expect(nursery.seeds, before.seeds + 8);
    expect(nursery.canBuild(ForestProject.birdhouse), isTrue);
    expect(nursery.canBuild(ForestProject.pond), isFalse);
    final all = ForestState([
      ...nursery.events,
      built(ForestProject.birdhouse),
      built(ForestProject.pond)
    ]);
    expect(all.materials, 4);
    expect(all.water, before.water - 8);
    expect(all.activeProject, isNull);
    expect(all.level, lessThan(8));
    expect(all.unlocked(TreeSpecies.willow), isTrue);
    expect(all.highestGrowth(TreeSpecies.willow), 0);
    expect(all.trees.map((t) => t.growth), everyElement(2));
    expect(all.projectProgress(ForestProject.pond), 1);
  });

  test('tree, material, prerequisite and water requirements all gate building',
      () {
    final fresh = ForestState([]);
    expect(fresh.projectProgress(ForestProject.nursery), 0);
    expect(
        ForestState(established(tasks: 100, mature: 1))
            .canBuild(ForestProject.nursery),
        isFalse);
    final noWater = ForestState([
      ...established(tasks: 21, mature: 8),
      built(ForestProject.nursery),
      built(ForestProject.birdhouse),
      const ForestEvent(id: 'debug-pack', kind: 'debugResources')
    ]);
    // Remove the pack to verify water is a distinct requirement.
    final dry =
        ForestState(noWater.events.where((e) => e.kind != 'debugResources'));
    expect(dry.canBuild(ForestProject.pond), isFalse);
    expect(dry.water, 5);
    expect(dry.materials, greaterThanOrEqualTo(20));
    expect(noWater.canBuild(ForestProject.pond), isTrue);
    expect(noWater.projectProgress(ForestProject.pond), 1);
    final poor = ForestState(
        [...established(tasks: 8, mature: 3), built(ForestProject.nursery)]);
    expect(poor.materials, 11);
    expect(poor.canBuild(ForestProject.birdhouse), isFalse);
  });

  test(
      'project and goal JSON roundtrip and deterministic selection survive order',
      () {
    final events = [
      ...established(),
      built(ForestProject.nursery),
      const ForestEvent(
          id: 'goal_100_a', kind: 'goal', project: ForestProject.birdhouse),
      const ForestEvent(
          id: 'goal_101_b', kind: 'goal', project: ForestProject.pond)
    ];
    final reloaded = ForestState(
        events.reversed.map((e) => ForestEvent.fromJson(e.toJson())));
    expect(reloaded.activeProject, ForestProject.pond);
    expect(reloaded.projects, {ForestProject.nursery});
    expect(reloaded.materials, 56);
    expect(
        ForestState([...reloaded.events, built(ForestProject.pond)])
            .activeProject,
        ForestProject.birdhouse);
  });

  Future<ProviderContainer> open(
      {AppStorage? storage,
      bool sandbox = false,
      List<ForestEvent>? initial}) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (storage != null) storageProvider.overrideWithValue(storage),
      if (sandbox)
        forestProvider
            .overrideWith(() => ForestController.sandbox(initial ?? [])),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test(
      'controller persists projects and goals and rejects duplicate or premature builds',
      () async {
    final storage = AppStorage(await SharedPreferences.getInstance());
    await storage.saveForest(established());
    final container = await open();
    final controller = container.read(forestProvider.notifier);
    await expectLater(
        controller.buildProject(ForestProject.pond), throwsStateError);
    await controller.chooseProject(ForestProject.pond);
    await controller.buildProject(ForestProject.nursery);
    await expectLater(
        controller.buildProject(ForestProject.nursery), throwsStateError);
    expect(ForestState(storage.loadForest()).activeProject, ForestProject.pond);
    expect(ForestState(storage.loadForest()).projects, {ForestProject.nursery});
    expect(container.read(forestProvider).materials, 56);
    await controller.buildProject(ForestProject.birdhouse);
    await controller.buildProject(ForestProject.pond);
    await controller.plant(TreeSpecies.willow);
    expect(
        container
            .read(forestProvider)
            .trees
            .where((t) => t.species == TreeSpecies.willow)
            .length,
        1);
    expect(container.read(forestRewardProvider), isNull);
  });

  test(
      'concurrent build taps spend only once; failed writes rollback and queue recovers',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await AppStorage(prefs).saveForest(established());
    final storage = _FailingStorage(prefs);
    final container = await open(storage: storage);
    final controller = container.read(forestProvider.notifier);
    await expectLater(
        controller.buildProject(ForestProject.nursery), throwsStateError);
    expect(container.read(forestProvider).projects, isEmpty);
    expect(container.read(forestProvider).materials, 62);
    storage.fail = false;
    final results = await Future.wait([
      controller
          .buildProject(ForestProject.nursery)
          .then((_) => true, onError: (_) => false),
      controller
          .buildProject(ForestProject.nursery)
          .then((_) => true, onError: (_) => false),
    ]);
    expect(results, [true, false]);
    expect(container.read(forestProvider).materials, 56);
    expect(
        storage.loadForest().where((e) => e.kind == 'project'), hasLength(1));
  });

  test('ordinary forest rejects cheats even in a debug build', () async {
    final container = await open();
    final controller = container.read(forestProvider.notifier);
    await expectLater(controller.debugResources(), throwsStateError);
    await expectLater(controller.debugLevelUp(), throwsStateError);
    await expectLater(controller.debugGrowTrees(), throwsStateError);
    await expectLater(controller.debugReset(), throwsStateError);
    expect(container.read(forestProvider).events, isEmpty);
  });

  test(
      'sandbox grants resources without XP, level-up emits celebration, reset is isolated',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);
    await storage.saveForest(established(tasks: 4, mature: 1));
    final saved = prefs.getString('forest_events_v1');
    final remote = _Remote(RemoteSnapshot(tasks: [], entries: [], timers: []));
    final sync = SyncCoordinator(storage, remote);
    addTearDown(sync.dispose);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      syncCoordinatorProvider.overrideWithValue(sync),
      forestProvider
          .overrideWith(() => ForestController.sandbox(storage.loadForest())),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(forestProvider.notifier);
    final before = container.read(forestProvider);
    await controller.debugResources();
    var forest = container.read(forestProvider);
    expect(forest.xp, before.xp);
    expect(forest.seeds, before.seeds + 50);
    expect(forest.water, before.water + 50);
    expect(forest.materials, before.materials + 50);
    expect(container.read(forestRewardProvider), isNull);
    await controller.debugLevelUp();
    expect(container.read(forestProvider).level, 2);
    expect(container.read(forestProvider).levelXp, 0);
    expect(container.read(forestRewardProvider)!.afterLevel, 2);
    await controller.debugGrowTrees();
    expect(container.read(forestProvider).matureTrees, 4);
    for (final project in ForestProject.values) {
      await controller.buildProject(project);
    }
    await controller.chooseProject(ForestProject.pond);
    await controller.awardCompletion('test', 'today');
    expect(prefs.getString('forest_events_v1'), saved);
    expect(remote.pushes, 0);
    await controller.debugReset();
    expect(container.read(forestProvider).events, isEmpty);
    expect(container.read(forestRewardProvider), isNull);
    expect(storage.loadForest(), hasLength(before.events.length));
  });

  test('sandbox can reach all species and account progress never changes',
      () async {
    final container = await open(sandbox: true);
    final controller = container.read(forestProvider.notifier);
    await controller.debugLevelUp(targetLevel: 16);
    final forest = container.read(forestProvider);
    expect(forest.level, 16);
    expect(forest.xp, ForestState.xpForLevel(16));
    expect(TreeSpecies.values.every(forest.unlocked), isTrue);
    await controller.debugLevelUp(targetLevel: 2);
    expect(container.read(forestProvider).xp, forest.xp);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('merged project events do not duplicate spending or nursery rewards',
      () async {
    final storage = AppStorage(await SharedPreferences.getInstance());
    final events = established();
    await storage.saveForest([
      ...events,
      built(ForestProject.nursery),
      const ForestEvent(
          id: 'goal_102_local', kind: 'goal', project: ForestProject.pond)
    ]);
    final remote =
        _Remote(RemoteSnapshot(tasks: [], entries: [], timers: [], forest: [
      ...events,
      built(ForestProject.nursery),
      built(ForestProject.birdhouse),
      const ForestEvent(
          id: 'goal_101_remote', kind: 'goal', project: ForestProject.birdhouse)
    ]));
    final sync = SyncCoordinator(storage, remote);
    addTearDown(sync.dispose);
    await sync.pullAndMerge();
    await sync.pushLocal();
    await sync.pullAndMerge();
    final forest = ForestState(storage.loadForest());
    expect(forest.projects, {ForestProject.nursery, ForestProject.birdhouse});
    expect(forest.materials, 44);
    expect(forest.seeds, 49);
    expect(forest.activeProject, ForestProject.pond);
  });

  testWidgets(
      'debug entry opens isolated sandbox and exposes usable cheats and level animation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: focusTheme(Brightness.light), home: const ForestScreen())));
    await tester.tap(find.byTooltip('Open debug sandbox'));
    await tester.pumpAndSettle();
    expect(find.text('Forest sandbox'), findsOneWidget);
    await tester.tap(find.byTooltip('Sandbox controls'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Grant 50 of each resource'), 150,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Grant 50 of each resource'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grant 50 of each resource'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.textContaining('50 materials · 50 water'), -150,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('50 materials · 50 water'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Force next level'), 150,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Force next level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Force next level'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Level 2 reached!').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('forest-level-up-burst')), findsOneWidget);
    expect(container.read(forestProvider).xp, 0);
    expect(prefs.getString('forest_events_v1'), isNull);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Force next level'));
    await tester.pump();
    await tester.scrollUntilVisible(
        find.text('Reset sandbox to a fresh forest'), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Reset sandbox to a fresh forest'));
    await tester.pumpAndSettle();
    final sandbox = ProviderScope.containerOf(
        tester.element(find.byType(ForestSandboxControls)));
    await sandbox.read(forestProvider.notifier).debugLevelUp();
    await tester.pump();
    expect(find.byType(ForestRewardCelebration), findsOneWidget);
    await tester.tap(find.text('Reset sandbox to a fresh forest'));
    await tester.pumpAndSettle();
    expect(find.byType(ForestRewardCelebration), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('Level 1 · 0 XP'), -180,
        scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('Level 1 · 0 XP'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ForestSandboxControls))).pop();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Your forest'), findsOneWidget);
    expect(container.read(forestProvider).events, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'projects show dependencies, persist focus, and build each habitat',
      (tester) async {
    final container = await open(sandbox: true, initial: established());
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: focusTheme(Brightness.light),
            home: Scaffold(body: ForestProjects(onTendTrees: () {})))));
    expect(find.text('Build your sanctuary'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('build-nursery')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Woodland nursery complete!'), findsOneWidget);
    expect(
        container.read(forestProvider).activeProject, ForestProject.birdhouse);
    await tester.ensureVisible(find.byKey(const ValueKey('build-birdhouse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('build-birdhouse')));
    await tester.pumpAndSettle();
    expect(container.read(forestProvider).hasProject(ForestProject.birdhouse),
        isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('build-pond')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('build-pond')));
    await tester.pumpAndSettle();
    expect(container.read(forestProvider).projects, hasLength(3));
    expect(container.read(forestProvider).activeProject, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact forest and sheets fit enlarged text without nested scene scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = await open(sandbox: true, initial: established());
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: focusTheme(Brightness.dark),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(1.5),
                    disableAnimations: true),
                child: child!),
            home: const ForestScreen())));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('forest-project-summary')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('build-pond')), 200,
        scrollable: find.byType(Scrollable).last);
    expect(tester.takeException(), isNull);
  });
}
