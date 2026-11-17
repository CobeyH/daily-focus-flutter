import 'package:daily_focus/models/forest.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/forest_provider.dart';
import 'package:daily_focus/providers/forest_reward_provider.dart';
import 'package:daily_focus/screens/forest_screen.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/theme/app_theme.dart';
import 'package:daily_focus/widgets/forest_projects.dart';
import 'package:daily_focus/widgets/forest_spend_preview.dart';
import 'package:daily_focus/widgets/forest_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> sandbox() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      forestProvider.overrideWith(
          () => ForestController.sandbox([], resourceChoices: true)),
    ]);
    addTearDown(container.dispose);
    await container.read(forestProvider.notifier).debugBalancedStart();
    return container;
  }

  Future<void> complete(ProviderContainer container, int count,
      {String prefix = 'test'}) async {
    for (var i = 0; i < count; i++) {
      await container
          .read(forestProvider.notifier)
          .awardCompletion('$prefix-$i', 'today');
    }
  }

  test('same starting budget affords any habitat but two compete for resources',
      () async {
    for (final project in ForestProject.values) {
      final container = await sandbox();
      final controller = container.read(forestProvider.notifier);
      final before = container.read(forestProvider);
      expect(before.resources.balance, '8 seeds · 6 water · 12 materials');
      expect(before.level, 2);
      expect(before.matureTrees, 1);
      expect(before.activeProject, isNull);
      expect(ForestProject.values.every(before.canBuild), isTrue);
      for (final plan in ForestProject.values.map(before.planFor)) {
        expect(plan.prerequisite, isNull);
      }
      final preview = before.resources - before.planFor(project).cost;
      await controller.buildProject(project);
      final after = container.read(forestProvider);
      expect(after.resources.balance, preview.balance);
      expect(ForestProject.values.where(after.canBuild), isEmpty);
      expect(after.bonusIn(project), 4);
      expect(after.projects, {project});
      await expectLater(controller.buildProject(project), throwsStateError);
      if (project == ForestProject.pond) {
        expect(after.water, 0);
        expect(after.unlocked(TreeSpecies.willow), isTrue);
      }
    }
  });

  test('rapid competing purchases cannot spend the same materials twice',
      () async {
    final container = await sandbox();
    final controller = container.read(forestProvider.notifier);
    final outcomes = await Future.wait([
      controller
          .buildProject(ForestProject.nursery)
          .then((_) => true, onError: (_) => false),
      controller
          .buildProject(ForestProject.birdhouse)
          .then((_) => true, onError: (_) => false),
    ]);
    expect(outcomes, [true, false]);
    expect(container.read(forestProvider).resources.balance,
        '8 seeds · 4 water · 4 materials');
    expect(container.read(forestProvider).projects, {ForestProject.nursery});
  });

  test(
      'each project automatically pays its own bonus on the fourth new completion only',
      () async {
    for (final project in ForestProject.values) {
      final container = await sandbox();
      final controller = container.read(forestProvider.notifier);
      await controller.buildProject(project);
      final before = container.read(forestProvider);
      await complete(container, 3);
      var forest = container.read(forestProvider);
      expect(
          forest.resources.balance,
          (before.resources +
                  const ForestResources(seeds: 3, water: 3, materials: 3))
              .balance);
      expect(forest.bonusIn(project), 1);
      expect(forest.events.where((e) => e.kind == 'choiceBonus'), isEmpty);
      await controller.awardCompletion('test-3', 'today');
      forest = container.read(forestProvider);
      final expected = before.resources +
          const ForestResources(seeds: 4, water: 4, materials: 4) +
          forest.planFor(project).bonus;
      expect(forest.resources.balance, expected.balance);
      expect(forest.bonusIn(project), 4);
      expect(container.read(forestRewardProvider)!.habitatBonuses.single,
          contains(project.label));
      expect(forest.events.where((e) => e.kind == 'choiceBonus'), hasLength(1));
      await controller.awardCompletion('test-3', 'today');
      expect(
          container.read(forestProvider).resources.balance, expected.balance);
      expect(container.read(forestRewardProvider)!.after.resources.balance,
          expected.balance);
      await complete(container, 4, prefix: 'second');
      forest = container.read(forestProvider);
      expect(forest.events.where((e) => e.kind == 'choiceBonus'), hasLength(2));
    }
  });

  test(
      'habitat income starts at purchase, batches through level cheats, and replays deterministically',
      () async {
    final container = await sandbox();
    final controller = container.read(forestProvider.notifier);
    await complete(container, 2, prefix: 'before');
    await controller.buildProject(ForestProject.birdhouse);
    await controller
        .debugLevelUp(); // 7 -> 12 completions, one 4-task seed bonus.
    final forest = container.read(forestProvider);
    expect(forest.level, 3);
    expect(forest.events.where((e) => e.kind == 'choiceBonus'), hasLength(1));
    expect(forest.bonusIn(ForestProject.birdhouse), 3);
    final reloaded = ForestState(
        forest.events.reversed.map((e) => ForestEvent.fromJson(e.toJson())),
        resourceChoices: true);
    expect(reloaded.resources.balance, forest.resources.balance);
    expect(reloaded.bonusIn(ForestProject.birdhouse), 3);
    final duplicate = ForestState([...forest.events, ...forest.events],
        resourceChoices: true);
    expect(duplicate.resources.balance, forest.resources.balance);
  });

  test(
      'pines convert seeds and water into materials; birches provide a seed return',
      () async {
    for (final species in [TreeSpecies.pine, TreeSpecies.birch]) {
      final container = await sandbox();
      final controller = container.read(forestProvider.notifier);
      final before = container.read(forestProvider);
      final id = await controller.plant(species);
      var forest = container.read(forestProvider);
      expect(
          forest.resources.balance,
          (before.resources - ForestResources(seeds: species.seedCost))
              .balance);
      await controller.waterTree(id);
      forest = container.read(forestProvider);
      final tree = forest.trees.singleWhere((t) => t.id == id);
      final preview = forest.afterWatering(tree);
      await controller.waterTree(id);
      forest = container.read(forestProvider);
      expect(forest.resources.balance, preview.balance);
      expect(
          forest.resources.balance,
          (before.resources -
                  ForestResources(seeds: species.seedCost, water: 2) +
                  species.maturityYield)
              .balance);
      expect(forest.highestGrowth(species), 2);
      await expectLater(controller.waterTree(id), throwsStateError);
      expect(
          ForestState(forest.events, resourceChoices: true).resources.balance,
          forest.resources.balance);
      if (species == TreeSpecies.birch) {
        expect(forest.seeds, 10);
        expect(forest.materials, 12);
      } else {
        expect(forest.seeds, 5);
        expect(forest.materials, 16);
      }
    }
  });

  test('pond-first route grows willow water without making its planting free',
      () async {
    final container = await sandbox();
    final controller = container.read(forestProvider.notifier);
    await controller.buildProject(ForestProject.pond);
    final willow = await controller.plant(TreeSpecies.willow);
    expect(container.read(forestProvider).seeds, 1);
    await expectLater(controller.waterTree(willow), throwsStateError);
    await complete(container, 2);
    await controller.waterTree(willow);
    await controller.waterTree(willow);
    final forest = container.read(forestProvider);
    expect(forest.water, 6);
    expect(forest.seeds, 3);
    expect(forest.materials, 2);
    expect(forest.matureTrees, 2);
  });

  test(
      'pinning a goal highlights attainable supplies and previews competing spends',
      () async {
    final container = await sandbox();
    final controller = container.read(forestProvider.notifier);
    await controller.chooseProject(ForestProject.pond);
    var forest = container.read(forestProvider);
    final afterPlant = forest.resources - const ForestResources(seeds: 3);
    expect(forest.goalShortfall(afterPlant), isNull);
    final pine = await controller.plant(TreeSpecies.pine);
    forest = container.read(forestProvider);
    final afterWater =
        forest.afterWatering(forest.trees.singleWhere((t) => t.id == pine));
    expect(forest.goalShortfall(afterWater), contains('1 water'));
    await controller.waterTree(pine);
    forest = container.read(forestProvider);
    expect(forest.goalAdvice, contains('Save water'));
    expect(forest.helpsGoal(TreeSpecies.willow),
        isFalse); // still locked at level 2
    await controller.chooseProject(ForestProject.nursery);
    await controller.buildProject(ForestProject.nursery);
    forest = container.read(forestProvider);
    expect(forest.activeProject, isNull); // no automatic next purchase
    await controller.chooseProject(ForestProject.pond);
    forest = container.read(forestProvider);
    expect(forest.helpsGoal(TreeSpecies.pine), isTrue);
    expect(forest.helpsGoal(TreeSpecies.birch), isFalse);
    expect(forest.goalShortfall(forest.resources), contains('8 materials'));
  });

  test(
      'choice bonuses and budgets never reach real storage or change the saved economy',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);
    await storage.saveForest([
      for (var i = 0; i < 12; i++) ForestEvent(id: 'real-$i', kind: 'reward'),
      const ForestEvent(id: 'real-water-1', kind: 'water', treeId: 'starter'),
      const ForestEvent(id: 'real-water-2', kind: 'water', treeId: 'starter'),
    ]);
    final saved = prefs.getString('forest_events_v1');
    final container = await sandbox();
    final controller = container.read(forestProvider.notifier);
    await controller.buildProject(ForestProject.nursery);
    await complete(container, 4);
    await controller.debugResources();
    await controller.debugReset();
    expect(container.read(forestProvider).resourceChoices, isTrue);
    expect(prefs.getString('forest_events_v1'), saved);
    final real = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(real.dispose);
    expect(real.read(forestProvider).resourceChoices, isFalse);
    expect(real.read(forestProvider).materials, 15);
    await expectLater(real.read(forestProvider.notifier).debugBalancedStart(),
        throwsStateError);
  });

  test(
      'opening an experiment with existing projects gives no retroactive habitat income',
      () async {
    final container = ProviderContainer(overrides: [
      forestProvider.overrideWith(() => ForestController.sandbox([
            for (var i = 0; i < 12; i++)
              ForestEvent(id: 'prior-$i', kind: 'reward'),
            const ForestEvent(
                id: 'project_birdhouse',
                kind: 'project',
                project: ForestProject.birdhouse),
          ], resourceChoices: true))
    ]);
    addTearDown(container.dispose);
    final forest = container.read(forestProvider);
    expect(forest.bonusIn(ForestProject.birdhouse), 4);
    expect(forest.events.where((e) => e.kind == 'choiceBonus'), isEmpty);
    expect(forest.seeds, 12);
    await complete(container, 4);
    expect(container.read(forestProvider).seeds, 18);
  });

  testWidgets(
      'projects expose three competing options and exact remaining balances',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = await sandbox();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: focusTheme(Brightness.light),
            home: Scaffold(body: ForestProjects(onTendTrees: () {})))));
    expect(find.textContaining('+2 materials every 4 tasks'), findsOneWidget);
    expect(
        find.textContaining('After building: 8 seeds · 4 water · 4 materials'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('build-nursery')))
            .onPressed,
        isNotNull);
    await tester.ensureVisible(find.byKey(const ValueKey('build-birdhouse')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('build-birdhouse')))
            .onPressed,
        isNotNull);
    await tester.ensureVisible(find.byKey(const ValueKey('build-pond')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('build-pond')))
            .onPressed,
        isNotNull);
    expect(
        find.textContaining('After building: 8 seeds · 0 water · 0 materials'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('build-pond')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Next +2 water in 4 task completions'),
        findsOneWidget);
    expect(container.read(forestProvider).water, 0);
    await complete(container, 4);
    await tester.pumpAndSettle();
    expect(find.textContaining('Next +2 water in 4 task completions'),
        findsOneWidget);
    expect(container.read(forestProvider).water, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'nursery previews resource conversions and respects unrevealed tree forms',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = await sandbox();
    await container
        .read(forestProvider.notifier)
        .chooseProject(ForestProject.nursery);
    await container
        .read(forestProvider.notifier)
        .buildProject(ForestProject.birdhouse);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: focusTheme(Brightness.light), home: const ForestScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plant a tree'));
    await tester.pumpAndSettle();
    final pine = find.byKey(const ValueKey('nursery-pine'));
    final birch = find.byKey(const ValueKey('nursery-birch'));
    expect(
        find.descendant(
            of: pine, matching: find.text('At maturity: +4 materials')),
        findsOneWidget);
    expect(
        find.descendant(
            of: pine,
            matching: find.textContaining('Helps your Woodland nursery goal')),
        findsOneWidget);
    expect(
        find.descendant(
            of: birch, matching: find.text('At maturity: +6 seeds')),
        findsOneWidget);
    expect(find.descendant(of: pine, matching: find.byType(ForestSpendPreview)),
        findsOneWidget);
    final oak = find.byKey(const ValueKey('nursery-oak'));
    await tester.scrollUntilVisible(oak, 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: oak, matching: find.byType(ForestTreeArt)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'balanced-start UI is reachable and compact choices fit enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = await sandbox();
    await container.read(forestProvider.notifier).debugReset();
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
    await tester.tap(find.byTooltip('Sandbox controls'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('balanced-forest-start')), 150,
        scrollable: find.byType(Scrollable).last);
    await tester
        .ensureVisible(find.byKey(const ValueKey('balanced-forest-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('balanced-forest-start')));
    await tester.pumpAndSettle();
    expect(container.read(forestProvider).resources.balance,
        '8 seeds · 6 water · 12 materials');
    await tester.tap(find.byKey(const ValueKey('forest-project-summary')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('build-pond')), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
