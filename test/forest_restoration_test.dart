import 'dart:ui' as ui;
import 'package:daily_focus/models/forest.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/forest_provider.dart';
import 'package:daily_focus/screens/forest_screen.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/theme/app_theme.dart';
import 'package:daily_focus/widgets/forest_ecology_art.dart';
import 'package:daily_focus/widgets/forest_landscape.dart';
import 'package:daily_focus/widgets/forest_projects.dart';
import 'package:daily_focus/widgets/forest_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<ForestEvent> grove(List<TreeSpecies> mature,
        {List<TreeSpecies> young = const [], int tasks = 200}) =>
    [
      for (var i = 0; i < tasks; i++)
        ForestEvent(id: 'task-$i', kind: 'reward'),
      for (var i = 0; i < mature.length + young.length; i++)
        ForestEvent(
            id: 'tree-$i',
            kind: 'plant',
            species: [...mature, ...young][i],
            plot: i + 1),
      for (var i = 0; i < mature.length + young.length; i++)
        for (var stage = 0; stage < (i < mature.length ? 2 : 1); stage++)
          ForestEvent(id: 'water-$i-$stage', kind: 'water', treeId: 'tree-$i'),
    ];
ForestState ecology(List<ForestEvent> events) =>
    ForestState(events, restorationGoals: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ProviderContainer> sandbox({List<ForestEvent>? events}) async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      forestProvider.overrideWith(
          () => ForestController.sandbox(events ?? [], restorationGoals: true))
    ]);
    addTearDown(c.dispose);
    if (events == null) {
      await c.read(forestProvider.notifier).debugRestorationStart();
    }
    return c;
  }

  test(
      'restoration start spends no fabricated materials and opens maples for testing',
      () async {
    final c = await sandbox(), forest = c.read(forestProvider);
    expect(forest.completions, 32);
    expect(forest.level, 5);
    expect(forest.materials, 32);
    expect(forest.water, 30);
    expect(forest.matureCount(TreeSpecies.pine), 1);
    expect(forest.unlocked(TreeSpecies.maple), isTrue);
    expect(forest.activeGoalTitle, isNull);
    expect(forest.projects, isEmpty);
    expect(forest.restorations, isEmpty);
  });
  test(
      'all tree varieties consume task materials and water without producing resources',
      () async {
    final c = await sandbox(events: grove([], tasks: 400)),
        controller = c.read(forestProvider.notifier);
    var material = 400, water = 400;
    for (final species in TreeSpecies.values) {
      final id = await controller.plant(species);
      material -= species.seedCost;
      expect(c.read(forestProvider).materials, material);
      await controller.waterTree(id);
      water--;
      await controller.waterTree(id);
      water--;
      expect(c.read(forestProvider).materials, material);
      expect(c.read(forestProvider).water, water);
      await expectLater(controller.waterTree(id), throwsStateError);
    }
    await controller.awardCompletion('one-more', 'today');
    expect(c.read(forestProvider).materials, material + 1);
    await controller.awardCompletion('one-more', 'today');
    expect(c.read(forestProvider).materials, material + 1);
  });
  test(
      'birdhouse needs exactly five mature maples, not a total count or growing maples',
      () async {
    final events = grove(
        [for (var i = 0; i < 4; i++) TreeSpecies.maple, TreeSpecies.pine],
        young: [TreeSpecies.maple], tasks: 50);
    final c = await sandbox(events: events),
        controller = c.read(forestProvider.notifier);
    expect(c.read(forestProvider).matureTrees, 5);
    expect(c.read(forestProvider).hasProject(ForestProject.birdhouse), isFalse);
    final before = c.read(forestProvider).materials;
    await controller.waterTree('tree-5');
    expect(c.read(forestProvider).matureCount(TreeSpecies.maple), 5);
    expect(c.read(forestProvider).hasProject(ForestProject.birdhouse), isTrue);
    expect(c.read(forestProvider).materials, before);
    expect(c.read(forestProvider).events.where((e) => e.kind == 'project'),
        isEmpty);
    expect(c.read(forestProvider).canBuild(ForestProject.birdhouse), isFalse);
    await expectLater(
        controller.buildProject(ForestProject.birdhouse), throwsStateError);
  });
  test(
      'nursery and pond are independent species achievements, with no circular willow unlock',
      () {
    final state = ecology(grove([
      for (var i = 0; i < 3; i++) TreeSpecies.pine,
      for (var i = 0; i < 3; i++) TreeSpecies.willow
    ]));
    expect(state.projects, {ForestProject.nursery, ForestProject.pond});
    expect(state.hasProject(ForestProject.birdhouse), isFalse);
    final lowLevel = ecology(
        grove([for (var i = 0; i < 3; i++) TreeSpecies.willow], tasks: 10));
    expect(lowLevel.hasProject(ForestProject.pond), isTrue);
    expect(lowLevel.unlocked(TreeSpecies.willow), isFalse);
  });
  test('grass, lichen and flowers have independent mature-tree boundaries', () {
    final two = ecology(grove([TreeSpecies.pine, TreeSpecies.maple],
        young: [TreeSpecies.birch]));
    expect(two.restorations, isEmpty);
    final threeSame =
        ecology(grove([TreeSpecies.pine, TreeSpecies.pine, TreeSpecies.pine]));
    expect(threeSame.restorations, {ForestRestoration.grass});
    final diverse = ecology(
        grove([TreeSpecies.pine, TreeSpecies.maple, TreeSpecies.birch]));
    expect(diverse.restorations,
        {ForestRestoration.grass, ForestRestoration.lichen});
    expect(
        ecology(grove([for (var i = 0; i < 7; i++) TreeSpecies.maple]))
            .restorations
            .contains(ForestRestoration.wildflowers),
        isFalse);
    expect(
        ecology(grove([for (var i = 0; i < 8; i++) TreeSpecies.maple]))
            .restorations,
        {ForestRestoration.grass, ForestRestoration.wildflowers});
  });
  test(
      'reload, event order and duplicate events preserve achievements without resource payouts',
      () {
    final events = grove([
      TreeSpecies.pine,
      TreeSpecies.birch,
      for (var i = 0; i < 5; i++) TreeSpecies.maple,
      TreeSpecies.willow
    ]);
    final before = ecology(events),
        after = ecology([...events, ...events]
            .reversed
            .map((e) => ForestEvent.fromJson(e.toJson()))
            .toList());
    expect(after.projects, before.projects);
    expect(after.restorations, before.restorations);
    expect(after.resources.balance, before.resources.balance);
    final spent = before.trees
        .where((t) => t.id != 'starter')
        .fold<int>(0, (n, t) => n + t.species.seedCost);
    expect(after.materials, 200 - spent);
  });
  test(
      'pinned goals explain missing varieties, existing seedlings and shared goal selection',
      () async {
    final c = await sandbox(
        events: grove([TreeSpecies.maple],
            young: [TreeSpecies.maple, TreeSpecies.maple], tasks: 32));
    final controller = c.read(forestProvider.notifier);
    await controller.chooseProject(ForestProject.birdhouse);
    var f = c.read(forestProvider);
    expect(f.goalAdvice, contains('Plant 2 more maple'));
    expect(f.helpsGoal(TreeSpecies.maple), isTrue);
    expect(f.helpsGoal(TreeSpecies.pine), isFalse);
    await controller.chooseRestoration(ForestRestoration.lichen);
    f = c.read(forestProvider);
    expect(f.activeProject, isNull);
    expect(f.activeRestoration, ForestRestoration.lichen);
    expect(f.helpsGoal(TreeSpecies.maple), isFalse);
    expect(f.helpsGoal(TreeSpecies.birch), isTrue);
    final reload = ecology(f.events.reversed
        .map((e) => ForestEvent.fromJson(e.toJson()))
        .toList());
    expect(reload.activeRestoration, ForestRestoration.lichen);
    await controller.chooseProject(ForestProject.pond);
    f = c.read(forestProvider);
    expect(f.activeRestoration, isNull);
    expect(f.goalAdvice, contains('level 8'));
    expect(f.helpsGoal(TreeSpecies.willow), isFalse);
  });
  test(
      'debug goal completion reuses growing maples and automatically completes the achievement',
      () async {
    final c = await sandbox(
        events: grove([TreeSpecies.maple],
            young: [TreeSpecies.maple, TreeSpecies.maple], tasks: 32));
    final controller = c.read(forestProvider.notifier);
    await controller.chooseProject(ForestProject.birdhouse);
    await controller.debugCompleteGoal();
    final f = c.read(forestProvider);
    expect(f.matureCount(TreeSpecies.maple), 5);
    expect(f.projects, {ForestProject.birdhouse});
    expect(f.trees.where((t) => t.species == TreeSpecies.maple), hasLength(5));
    expect(f.activeGoalTitle, isNull);
    expect(f.restorations, {ForestRestoration.grass});
  });
  test(
      'debug ecosystem completion handles diversity and full preview restores every milestone',
      () async {
    final c = await sandbox(), controller = c.read(forestProvider.notifier);
    await controller.chooseRestoration(ForestRestoration.lichen);
    await controller.debugCompleteGoal();
    expect(c.read(forestProvider).matureSpecies, hasLength(3));
    await controller.debugRestoredForest();
    final f = c.read(forestProvider);
    expect(f.restorations, ForestRestoration.values.toSet());
    expect(f.projects, ForestProject.values.toSet());
    expect(f.materials, 16);
    expect(f.water, 53);
  });
  test(
      'experiments preserve real forest credits and refuse debug controls on a real account',
      () async {
    final prefs = await SharedPreferences.getInstance(),
        storage = AppStorage(await SharedPreferences.getInstance());
    await storage.saveForest(grove([TreeSpecies.pine], tasks: 10));
    final saved = prefs.getString('forest_events_v1');
    final c = await sandbox(), controller = c.read(forestProvider.notifier);
    await controller.debugRestoredForest();
    await controller.debugResources();
    await controller.debugReset();
    expect(prefs.getString('forest_events_v1'), saved);
    expect(c.read(forestProvider).restorationGoals, isTrue);
    final real = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(real.dispose);
    expect(real.read(forestProvider).restorationGoals, isFalse);
    expect(real.read(forestProvider).materials, 13);
    await expectLater(
        real.read(forestProvider.notifier).debugRestorationStart(),
        throwsStateError);
    await expectLater(real.read(forestProvider.notifier).debugRestoredForest(),
        throwsStateError);
    await expectLater(real.read(forestProvider.notifier).debugCompleteGoal(),
        throwsStateError);
  });
  testWidgets(
      'achievement cards show exact recipes, no build buttons, and include ecosystem goals',
      (tester) async {
    final c = await sandbox();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: focusTheme(Brightness.light),
            home: Scaffold(body: ForestProjects(onTendTrees: () {})))));
    expect(find.text('Habitat achievements'), findsOneWidget);
    final bird = find.byKey(const ValueKey('project-birdhouse'));
    await tester.scrollUntilVisible(bird, 180);
    await tester.ensureVisible(bird);
    await tester.pumpAndSettle();
    expect(find.text('0 / 5 mature maple trees'), findsOneWidget);
    expect(find.byKey(const ValueKey('build-birdhouse')), findsNothing);
    await tester
        .tap(find.descendant(of: bird, matching: find.text('Make my goal')));
    await tester.pumpAndSettle();
    expect(c.read(forestProvider).activeProject, ForestProject.birdhouse);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('restoration-lichen')), 180);
    await tester.pumpAndSettle();
    expect(find.text('Lichen appears on mature tree trunks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'find-maple action opens matching nursery first and planting spends materials',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await sandbox();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: focusTheme(Brightness.light), home: const ForestScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forest-project-summary')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('find-maple')), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.byKey(const ValueKey('find-maple')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('find-maple')));
    await tester.pumpAndSettle();
    final maple = find.byKey(const ValueKey('nursery-maple'));
    expect(
        find.descendant(
            of: maple, matching: find.text('6 materials · 2 water to grow')),
        findsOneWidget);
    expect(
        tester
            .widget<ForestTreeArt>(find.descendant(
                of: maple, matching: find.byType(ForestTreeArt)))
            .growth,
        0);
    await tester
        .tap(find.descendant(of: maple, matching: find.text('Plant maple')));
    await tester.pumpAndSettle();
    expect(c.read(forestProvider).materials, 26);
    expect(c.read(forestProvider).water, 30);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'new grass appears with an in-scene discovery on the third mature tree',
      (tester) async {
    final c = await sandbox(
        events: grove([TreeSpecies.pine, TreeSpecies.maple],
            young: [TreeSpecies.birch]));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: focusTheme(Brightness.light), home: const ForestScreen())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('forest-discovery')), findsNothing);
    await c.read(forestProvider.notifier).waterTree('tree-2');
    await tester.pump();
    expect(find.textContaining('Grass spreads across the clearing'),
        findsOneWidget);
    expect(find.textContaining('Lichen appears on mature tree trunks'),
        findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('forest-discovery')), findsNothing);
  });
  testWidgets(
      'restoration controls and goal sheets fit a small screen with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await sandbox();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: focusTheme(Brightness.dark),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(1.5),
                    disableAnimations: true),
                child: child!),
            home: const ForestScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sandbox controls'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('restoration-forest-start')), 150,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('restoration-forest-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forest-project-summary')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('restoration-wildflowers')), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(ForestProjects))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sandbox controls'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Preview restored forest'), 150,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Preview restored forest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview restored forest'));
    await tester.pumpAndSettle();
    final discovery = find.byKey(const ValueKey('forest-discovery'));
    expect(discovery, findsOneWidget);
    expect(
        tester.getTopLeft(discovery).dy,
        greaterThanOrEqualTo(
            tester.getTopLeft(find.byType(ForestLandscape)).dy));
    expect(tester.takeException(), isNull);
  });
  test(
      'ecology art adds ground cover only when restored and lichen only to mature trunks',
      () async {
    Future<int> visible(void Function(ui.Canvas) draw) async {
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.translate(100, 100);
      draw(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      var pixels = 0;
      for (var i = 3; i < bytes.length; i += 4) {
        if (bytes[i] > 0) pixels++;
      }
      image.dispose();
      picture.dispose();
      return pixels;
    }

    final bare = ecology(grove([])),
        grass = ecology(
            grove([TreeSpecies.pine, TreeSpecies.pine, TreeSpecies.pine]));
    expect(
        await visible((c) => paintForestGroundcover(c, grass, 80, false)),
        greaterThan(
            await visible((c) => paintForestGroundcover(c, bare, 80, false))));
    expect(
        await visible((c) => paintForestLichen(
            c, Offset.zero, const ForestTree('test', TreeSpecies.maple, 0))),
        0);
    expect(
        await visible((c) => paintForestLichen(
            c, Offset.zero, const ForestTree('test', TreeSpecies.maple, 2))),
        greaterThan(0));
  });
}
