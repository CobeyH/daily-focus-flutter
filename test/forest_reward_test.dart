import 'package:daily_focus/models/forest.dart';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/providers/forest_provider.dart';
import 'package:daily_focus/providers/forest_reward_provider.dart';
import 'package:daily_focus/screens/home_screen.dart';
import 'package:daily_focus/screens/forest_screen.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/widgets/forest_reward_overlay.dart';
import 'package:daily_focus/widgets/forest_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ForestState forest(int rewards, [List<ForestEvent> events = const []]) =>
    ForestState([
      for (var i = 0; i < rewards; i++)
        ForestEvent(id: 'reward-$i', kind: 'reward'),
      ...events,
    ]);
final _now = DateTime(2026, 11, 17, 13);

class _FailingForestStorage extends AppStorage {
  _FailingForestStorage(super.prefs);
  @override
  Future<void> saveForest(List<ForestEvent> events) async =>
      throw StateError('Test write failed');
}

Task _task({TaskType type = TaskType.count}) => Task(
    id: 'walk',
    name: 'Walk',
    type: type,
    goal: 1,
    steps: type == TaskType.multiStep ? const ['Wash', 'Dry'] : const [],
    step: 1,
    color: 0xff247866,
    icon: Icons.check.codePoint,
    createdAt: DateTime(2026, 11, 16));

Future<ProviderContainer> pumpHost(WidgetTester tester,
    {int rewards = 0,
    bool reduced = false,
    double textScale = 1,
    Task? task}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await AppStorage(prefs).saveForest(forest(rewards).events);
  await AppStorage(prefs).saveTasks([task ?? _task()]);
  tester.view.physicalSize = const Size(390, 950);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeSourceProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(textScale)),
              child: ForestRewardOverlay(child: child!)),
          home: const HomeScreen())));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'XP timeline fills the old level before changing level and resetting the bar',
      () {
    final timeline = ForestRewardTimeline(ForestReward(forest(4), forest(5)));
    expect(timeline.frameAt(Duration.zero).progress, .8);
    final filling = timeline.frameAt(const Duration(milliseconds: 1000));
    expect(filling.level, 1);
    expect(filling.progress, greaterThan(.8));
    final full = timeline.frameAt(const Duration(milliseconds: 1320));
    expect(full.level, 1);
    expect(full.progress, 1);
    final levelUp = timeline.frameAt(const Duration(milliseconds: 1600));
    expect(levelUp.level, 2);
    expect(levelUp.progress, 0);
    expect(levelUp.levelUp, isTrue);
    expect(levelUp.burst, greaterThan(0));
    expect(timeline.frameAt(timeline.duration).opacity, 0);
  });

  test(
      'batched rewards visit every crossed level and end at the exact stored XP',
      () {
    final timeline = ForestRewardTimeline(ForestReward(forest(4), forest(20)));
    expect(timeline.segments, 3);
    expect(timeline.frameAt(const Duration(milliseconds: 1320)).progress, 1);
    final second = timeline.frameAt(const Duration(milliseconds: 2070));
    expect(second.level, 2);
    expect(second.progress, 1);
    final end =
        timeline.frameAt(timeline.duration - const Duration(milliseconds: 200));
    expect(end.level, 3);
    expect(end.progress, forest(20).levelProgress);
    final reduced = timeline.frameAt(Duration.zero, reduced: true);
    expect(reduced.level, forest(20).level);
    expect(reduced.progress, forest(20).levelProgress);
    expect(reduced.burst, 0);
  });

  test('highest achieved growth stays specific to each variety', () {
    final state = forest(12, const [
      ForestEvent(id: 'p', kind: 'plant', species: TreeSpecies.pine, plot: 1),
      ForestEvent(id: 'b', kind: 'plant', species: TreeSpecies.birch, plot: 2),
      ForestEvent(id: 'w1', kind: 'water', treeId: 'starter'),
      ForestEvent(id: 'w2', kind: 'water', treeId: 'starter'),
      ForestEvent(id: 'w3', kind: 'water', treeId: 'b'),
    ]);
    expect(state.highestGrowth(TreeSpecies.pine), 2);
    expect(state.highestGrowth(TreeSpecies.birch), 1);
    expect(state.highestGrowth(TreeSpecies.oak), 0);
    expect(state.trees.firstWhere((t) => t.id == 'p').growth, 0);
  });

  test(
      'only new fully completed tasks emit saved XP feedback; undo/replay and sync do not',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final task = _task(type: TaskType.multiStep);
    await AppStorage(prefs).saveTasks([task]);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeSourceProvider.overrideWithValue(() => _now),
    ]);
    addTearDown(container.dispose);
    final events = <ForestReward>[];
    container.listen(forestRewardProvider, (_, next) {
      if (next != null) events.add(next);
    });
    final controller = container.read(appControllerProvider.notifier);
    await controller.increment(task);
    expect(events, isEmpty);
    await controller.increment(task);
    expect(events.single.xpGained, 10);
    expect(ForestState(AppStorage(prefs).loadForest()).xp, 10);
    await controller.undoCompletion(task, occurrenceKey: '2026-11-17');
    await controller.increment(task);
    expect(events, hasLength(1));
    container.invalidate(forestProvider);
    container.read(forestProvider);
    await container
        .read(forestProvider.notifier)
        .awardCompletion(task.id, '2026-11-17');
    expect(events, hasLength(1));
  });

  test('failed reward storage never emits XP or a level-up celebration',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      storageProvider.overrideWithValue(_FailingForestStorage(prefs)),
    ]);
    addTearDown(container.dispose);
    await expectLater(
        container
            .read(forestProvider.notifier)
            .awardCompletion('walk', '2026-11-17'),
        throwsStateError);
    expect(container.read(forestRewardProvider), isNull);
    expect(container.read(forestProvider).xp, 0);
  });

  testWidgets(
      'completion visibly fills XP, celebrates level up, and survives opening the forest',
      (tester) async {
    final container = await pumpHost(tester, rewards: 4);
    final before = tester.getTopLeft(find.widgetWithText(ChoiceChip, 'Today'));
    await tester.tap(find.text('Complete'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('+10 XP'), findsOneWidget);
    final bar = find.byKey(const ValueKey('forest-reward-xp-bar'));
    expect(tester.widget<LinearProgressIndicator>(bar).value, .8);
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.widget<LinearProgressIndicator>(bar).value, greaterThan(.8));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Level 2 reached!'), findsOneWidget);
    expect(find.text('Birch unlocked'), findsOneWidget);
    expect(find.byKey(const ValueKey('forest-level-up-burst')), findsOneWidget);
    expect(tester.getTopLeft(find.widgetWithText(ChoiceChip, 'Today')), before);
    await tester.tap(find.byTooltip('Your forest'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Level 2 reached!'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ForestRewardCelebration), findsNothing);
    expect(find.byType(ForestScreen), findsOneWidget);
    expect(container.read(forestProvider).level, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rapid task rewards coalesce without losing XP or stacking panels',
      (tester) async {
    final container = await pumpHost(tester);
    final controller = container.read(forestProvider.notifier);
    await controller.awardCompletion('a', '2026-11-17');
    await controller.awardCompletion('b', '2026-11-17');
    await controller.awardCompletion('c', '2026-11-17');
    await tester.pump();
    expect(find.byType(ForestRewardCelebration), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ForestRewardCelebration), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(container.read(forestProvider).xp, 30);
    expect(find.byType(ForestRewardCelebration), findsNothing);
  });

  testWidgets(
      'reduced motion keeps clear XP and unlock feedback without bursts',
      (tester) async {
    final container =
        await pumpHost(tester, rewards: 4, reduced: true, textScale: 1.5);
    tester.view.physicalSize = const Size(320, 700);
    await tester.pump();
    await container.read(appControllerProvider.notifier).markComplete(_task());
    await tester.pump();
    expect(find.text('Level 2 reached!'), findsOneWidget);
    expect(find.text('Birch unlocked'), findsOneWidget);
    expect(find.byKey(const ValueKey('forest-level-up-burst')), findsNothing);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('forest-reward-xp-bar')))
            .value,
        0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('dismiss-forest-progress')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ForestRewardCelebration), findsNothing);
  });

  testWidgets('XP feedback pauses in the background and resumes visibly',
      (tester) async {
    final container = await pumpHost(tester, rewards: 4);
    await container.read(appControllerProvider.notifier).markComplete(_task());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(ForestRewardCelebration), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('forest-reward-xp-bar')))
            .value,
        .8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Level 2 reached!'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ForestRewardCelebration), findsNothing);
  });

  testWidgets(
      'nursery and unlock list hide locked art and preview only the best stage reached',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await AppStorage(prefs).saveForest(forest(5, const [
      ForestEvent(id: 'w', kind: 'water', treeId: 'starter'),
    ]).events);
    await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ForestScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plant a tree'));
    await tester.pumpAndSettle();
    final pine = find.byKey(const ValueKey('nursery-pine'));
    final birch = find.byKey(const ValueKey('nursery-birch'));
    final oak = find.byKey(const ValueKey('nursery-oak'));
    expect(
        tester
            .widget<ForestTreeArt>(
                find.descendant(of: pine, matching: find.byType(ForestTreeArt)))
            .growth,
        1);
    expect(
        tester
            .widget<ForestTreeArt>(find.descendant(
                of: birch, matching: find.byType(ForestTreeArt)))
            .growth,
        0);
    expect(find.descendant(of: oak, matching: find.byType(ForestTreeArt)),
        findsNothing);
    expect(find.text('Oak'), findsOneWidget);
    Navigator.of(tester.element(oak)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 2'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Oak'), 180,
        scrollable: find.byType(Scrollable).last);
    final previews = tester
        .widgetList<ForestSpeciesPreview>(find.byType(ForestSpeciesPreview));
    expect(previews.any((p) => p.species == TreeSpecies.oak), isTrue);
    expect(
        tester
            .widgetList<ForestTreeArt>(find.byType(ForestTreeArt))
            .where((art) => art.species == TreeSpecies.oak),
        isEmpty);
    expect(
        tester
            .widgetList<ForestTreeArt>(find.byType(ForestTreeArt))
            .where((art) => art.species == TreeSpecies.birch)
            .single
            .growth,
        0);
    expect(tester.takeException(), isNull);
  });
}
