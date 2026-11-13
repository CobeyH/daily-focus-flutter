import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:daily_focus/models/task.dart';
import 'package:daily_focus/models/task_entry.dart';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/providers/clock_provider.dart';
import 'package:daily_focus/providers/forest_provider.dart';
import 'package:daily_focus/screens/home_screen.dart';
import 'package:daily_focus/screens/task_card.dart';
import 'package:daily_focus/storage/app_storage.dart';
import 'package:daily_focus/widgets/task_completion_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 11, 13, 13);
Task _task(
        {String id = 'laundry',
        int goal = 1,
        TaskType type = TaskType.count}) =>
    Task(
        id: id,
        name: 'Laundry',
        type: type,
        steps: type == TaskType.multiStep ? const ['Wash', 'Dry'] : const [],
        goal: goal,
        step: 1,
        color: 0xff247866,
        icon: Icons.local_laundry_service.codePoint,
        createdAt: DateTime(2026, 11, 12));
Future<ProviderContainer> _pump(WidgetTester tester, Task task,
    {bool reduced = false,
    List<Task> additionalTasks = const [],
    List<TaskEntry> entries = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await AppStorage(prefs).saveTasks([task, ...additionalTasks]);
  await AppStorage(prefs).saveEntries(entries);
  tester.view.physicalSize = const Size(390, 950);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(_now),
        timeSourceProvider.overrideWithValue(() => _now)
      ],
      child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!),
          home: const HomeScreen())));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

Future<({int pieces, Rect bounds, Offset center})> _rasterDroplets(
    WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('completion-droplets'));
  final painter = tester.widget<CustomPaint>(finder).painter!;
  final size = tester.getSize(finder);
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    final picture = recorder.endRecording();
    final width = size.width.ceil(), height = size.height.ceil();
    final image = await picture.toImage(width, height);
    final pixels = (await image.toByteData())!;
    final mask = Uint8List(width * height);
    var minX = width, minY = height, maxX = 0, maxY = 0;
    var xSum = 0.0, ySum = 0.0, weight = 0.0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final alpha = pixels.getUint8((y * width + x) * 4 + 3);
        if (alpha < 30) continue;
        mask[y * width + x] = 1;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        xSum += x * alpha;
        ySum += y * alpha;
        weight += alpha;
      }
    }
    var pieces = 0;
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == 0) continue;
      pieces++;
      final pending = [i];
      mask[i] = 0;
      while (pending.isNotEmpty) {
        final at = pending.removeLast();
        for (final neighbor in [
          if (at % width > 0) at - 1,
          if (at % width < width - 1) at + 1,
          if (at >= width) at - width,
          if (at < width * (height - 1)) at + width
        ]) {
          if (mask[neighbor] == 0) continue;
          mask[neighbor] = 0;
          pending.add(neighbor);
        }
      }
    }
    image.dispose();
    picture.dispose();
    return (
      pieces: pieces,
      bounds: Rect.fromLTRB(
          minX.toDouble(), minY.toDouble(), maxX.toDouble(), maxY.toDouble()),
      center: Offset(xSum / weight, ySum / weight)
    );
  }))!;
}

void main() {
  testWidgets(
      'last-task empty state crossfades immediately and completed header does not jump',
      (tester) async {
    await _pump(tester, _task(), additionalTasks: [
      _task(id: 'done')
    ], entries: [
      TaskEntry(
          taskId: 'done',
          dateKey: '2026-11-13',
          progress: 1,
          completedGoal: 1,
          completedAt: _now),
    ]);
    final header = find.textContaining('Completed & skipped (');
    final initialY = tester.getTopLeft(header).dy;
    expect(find.text('All clear for today'), findsNothing);
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(find.text('All clear for today'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Completed & skipped (1)'), findsOneWidget);
    expect(tester.getTopLeft(header).dy, closeTo(initialY, 1));
    var previousY = initialY;
    for (var frame = 0; frame < 25; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      final y = tester.getTopLeft(header).dy;
      expect((y - previousY).abs(), lessThan(20),
          reason: 'No empty-card insertion jump at frame $frame');
      previousY = y;
      if (frame == 5) {
        final fade = tester.widget<FadeTransition>(find
            .ancestor(
                of: find.text('All clear for today'),
                matching: find.byType(FadeTransition))
            .first);
        expect(fade.opacity.value, greaterThan(0));
        expect(find.text('Completed & skipped (1)'), findsOneWidget);
      }
    }
    expect(find.text('Completed & skipped (2)'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('card bursts again after undo without awarding resources again',
      (tester) async {
    final container = await _pump(tester, _task());
    final cardBounds = tester.getRect(find.byType(TaskCard));
    final destination = tester.getCenter(find.byTooltip('Your forest'));
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.byTooltip('Your forest')),
        findsOneWidget);
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(find.byType(TaskCompletionExit), findsOneWidget);
    expect(find.byType(CompletionWaterFlight), findsOneWidget);
    final flight = tester
        .widget<CompletionWaterFlight>(find.byType(CompletionWaterFlight));
    expect(cardBounds.contains(flight.start), isTrue);
    expect((flight.end - destination).distance, lessThan(1));
    final initialHeight =
        tester.getSize(find.byType(TaskCompletionExit)).height;
    await tester.pump(const Duration(milliseconds: 120));
    final burst = await _rasterDroplets(tester);
    expect(burst.pieces, greaterThanOrEqualTo(10));
    expect(burst.bounds.width, greaterThan(cardBounds.width * .6));
    expect(tester.getSize(find.byType(TaskCompletionExit)).height,
        lessThan(initialHeight));
    await tester.pump(const Duration(milliseconds: 580));
    final gathering = await _rasterDroplets(tester);
    expect((gathering.center - destination).distance,
        lessThan((burst.center - destination).distance));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCompletionExit), findsNothing);
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(container.read(forestProvider).water, 1);
    await tester.tap(find.text('Completed & skipped (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(find.byType(TaskCompletionExit), findsOneWidget);
    expect(find.byType(CompletionWaterFlight), findsOneWidget);
    expect(container.read(forestProvider).water, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid undo and re-completion can overlap bursts safely',
      (tester) async {
    final task = _task();
    final container = await _pump(tester, task);
    await tester.tap(find.text('Complete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await container
        .read(appControllerProvider.notifier)
        .undoCompletion(task, occurrenceKey: '2026-11-13');
    await tester.pump();
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(find.byType(CompletionWaterFlight), findsNWidgets(2));
    expect(container.read(forestProvider).water, 1);
    await tester.pumpAndSettle();
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'partial multi-step progress and skips do not play reward effects',
      (tester) async {
    await _pump(tester, _task(type: TaskType.multiStep));
    await tester.tap(find.text('Complete step'));
    await tester.pumpAndSettle();
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(find.text('Next: Dry'), findsOneWidget);
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this occurrence'));
    await tester.pumpAndSettle();
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(find.byType(TaskCompletionExit), findsNothing);
  });
  testWidgets('reduced motion completes immediately with no flight or exit',
      (tester) async {
    final container = await _pump(tester, _task(), reduced: true);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.byType(CompletionWaterFlight), findsNothing);
    expect(find.byType(TaskCompletionExit), findsNothing);
    expect(find.text('Completed & skipped (1)'), findsOneWidget);
    expect(container.read(forestProvider).water, 1);
  });
  testWidgets(
      'timer completion uses the same feedback and overlays clean up on disposal',
      (tester) async {
    final task = _task(type: TaskType.minutes);
    final container = await _pump(tester, task);
    await container
        .read(appControllerProvider.notifier)
        .recordTimedCompletion(task, '2026-11-13', completedAt: _now);
    await tester.pump();
    expect(find.byType(CompletionWaterFlight), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
