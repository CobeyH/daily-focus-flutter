import 'dart:ui' as ui;
import 'package:daily_focus/widgets/selectors.dart';
import 'package:daily_focus/widgets/task_progress_ring.dart';
import 'package:daily_focus/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('icon library preserves old code points and has unique labeled choices',
      () {
    const legacy = [
      Icons.local_florist,
      Icons.fitness_center,
      Icons.menu_book,
      Icons.self_improvement,
      Icons.restaurant,
      Icons.bed,
      Icons.directions_run,
      Icons.edit,
      Icons.check_circle,
      Icons.water_drop,
    ];
    for (final icon in legacy) {
      expect(iconFor(icon.codePoint), icon);
    }
    expect(iconFor(-1), Icons.flag);
    expect(taskIconChoices.length, greaterThan(80));
    expect(taskIconChoices.map((c) => c.icon.codePoint).toSet().length,
        taskIconChoices.length);
    expect(taskIconChoices.map((c) => c.label).toSet().length,
        taskIconChoices.length);
    expect(taskIconChoices.where((c) => c.matches('  HYDRATION ')).single.label,
        'Water');
    expect(taskIconChoices.where((c) => c.matches('yoga')).single.label,
        'Meditation');
    expect(
        taskIconChoices.where((c) => c.matches('money budget')), hasLength(2));
  });

  Future<void> pumpPicker(WidgetTester tester, ValueChanged<int> onChanged,
      {double width = 700, double scale = 1}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: focusTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: Center(
                child: IconSelector(
                    selected: Icons.water_drop.codePoint,
                    onChanged: onChanged)))));
    await tester.tap(find.byKey(const ValueKey('choose-task-icon')));
    await tester.pumpAndSettle();
  }

  testWidgets('search finds synonyms, selecting returns the stored code point',
      (tester) async {
    int? selected;
    await pumpPicker(tester, (value) => selected = value);
    await tester.enterText(
        find.byKey(const ValueKey('icon-search')), 'hydration');
    await tester.pumpAndSettle();
    expect(find.text('1 icon'), findsOneWidget);
    final choice =
        find.byKey(ValueKey('task-icon-${Icons.water_drop.codePoint}'));
    final semantics = tester.ensureSemantics();
    expect(
        tester
            .getSemantics(choice)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(selected, Icons.water_drop.codePoint);
    expect(find.byType(Dialog), findsNothing);
    semantics.dispose();
  });

  testWidgets(
      'category and search combine, empty search recovers, escape cancels',
      (tester) async {
    int? selected;
    await pumpPicker(tester, (value) => selected = value);
    await tester.tap(find.byKey(const ValueKey('icon-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home & care').last);
    await tester.pumpAndSettle();
    expect(find.text('Cleaning'), findsOneWidget);
    expect(find.text('Strength'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('icon-search')), 'wash');
    await tester.pumpAndSettle();
    expect(find.text('2 icons'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('icon-search')), 'no-such-icon');
    await tester.pumpAndSettle();
    expect(find.textContaining('No matching icons'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Cleaning'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(selected, isNull);
  });

  testWidgets('icon library fits a narrow screen with enlarged text',
      (tester) async {
    await pumpPicker(tester, (_) {}, width: 320, scale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.enterText(
        find.byKey(const ValueKey('icon-search')), 'medication');
    await tester.pumpAndSettle();
    expect(find.text('Medication'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close icon picker'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('ring exposes progress and updates with reduced motion enabled',
      (tester) async {
    final semantics = tester.ensureSemantics();
    Future<void> pump(double progress) => tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
                child: TaskProgressRing(
                    progress: progress,
                    color: Colors.teal,
                    icon: Icons.check,
                    label: 'Read')))));
    await pump(0.25);
    expect(find.bySemanticsLabel('Read'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Read')).value,
        '25 percent complete');
    await pump(1);
    await tester.pump();
    expect(tester.getSemantics(find.bySemanticsLabel('Read')).value,
        '100 percent complete');
    expect(tester.hasRunningAnimations, isFalse);
    semantics.dispose();
  });

  testWidgets(
      'ring edges have coverage antialiasing at desktop and HiDPI scales',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Center(
            child: TaskProgressRing(
                progress: 1,
                color: Colors.white,
                icon: Icons.check,
                label: 'Done'))));
    final paintWidget = tester.widget<CustomPaint>(find.descendant(
        of: find.byType(TaskProgressRing), matching: find.byType(CustomPaint)));
    // Rasterize only the vector ring: font rendering cannot influence the check.
    await tester.runAsync(() async {
      for (final scale in [1.0, 1.25, 2.0]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(scale);
        paintWidget.painter!.paint(canvas, const Size(48, 48));
        final picture = recorder.endRecording();
        final width = (48 * scale).round();
        final image = await picture.toImage(width, width);
        final data = (await image.toByteData())!;
        var blended = 0;
        var solid = 0;
        for (var y = 0; y < width; y++) {
          for (var x = 0; x < width; x++) {
            final alpha = data.getUint8((y * width + x) * 4 + 3);
            if (alpha > 0 && alpha < 255) blended++;
            if (alpha == 255) solid++;
            if (x == 0 || y == 0 || x == width - 1 || y == width - 1) {
              expect(alpha, 0, reason: 'No clipped edges at $scale×');
            }
          }
        }
        expect(blended, greaterThan(80),
            reason: 'Smooth edge coverage at $scale×');
        expect(solid, greaterThan(150), reason: 'Crisp interior at $scale×');
        expect(data.getUint8(((width ~/ 2) * width + width ~/ 2) * 4 + 3), 0);
        image.dispose();
        picture.dispose();
      }
    });
  });
}
