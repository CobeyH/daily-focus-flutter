import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/task.dart';
import '../providers/app_controller.dart';
import '../utils/dates.dart';

/// A heat map showing each task's recent daily progress.
///
/// Rows are tasks; columns are the last [kWeeks] weeks of days. Each cell's
/// color reflects how close that task's goal came to being met that day, from
/// a faint tint for a little progress up to a deep, saturated fill for a met
/// (or exceeded) goal. Cells are spaced by weekday so days line up in columns,
/// and each column is labeled with its date.
///
/// Implemented with `SfCartesianChart` + `StackedBar100Series` and a custom
/// series renderer that evenly slices the Y axis into one row per task,
/// exactly as described in Syncfusion's heat map guide:
/// https://www.syncfusion.com/blogs/post/build-heat-map-using-flutter-charts
class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  /// Number of weeks of history to show (each week = 7 calendar days).
  static const int _weeks = 4;

  late final List<_DayBucket>? _buckets;

  @override
  void initState() {
    super.initState();
    final today = todayOnly();
    final start = today.subtract(Duration(days: _weeks * 7 - 1));
    _buckets = List.generate(_weeks * 7, (i) {
      final d = start.add(Duration(days: i));
      return _DayBucket(date: d);
    });
  }

  @override
  void dispose() {
    _buckets?.clear();
    super.dispose();
  }

  List<CartesianSeries<_StreakData, String>> _buildSeries(List<Task> tasks) {
    final days = _buckets!;
    // Column buckets, one per day, so the x-axis renders a labeled date for
    // each column. StackedBar100Series renders one rectangle per data point,
    // sized to fill its row slice.
    final data = <_StreakData>[
      for (final d in days) _StreakData(date: d.date, label: _dayLabel(d.date)),
    ];

    return List.generate(tasks.length, (rowIndex) {
      final task = tasks[rowIndex];
      final color = Color(task.color);
      return StackedBar100Series<_StreakData, String>(
        dataSource: data,
        xValueMapper: (_StreakData d, _) => d.label,
        yValueMapper: (_StreakData d, _) => _dayFraction(task, d.date),
        pointColorMapper: (_StreakData d, _) =>
            _dayFraction(task, d.date) <= 0 ? Colors.grey.shade200 : color,
        isVisibleInLegend: false,
        animationDuration: 0,
        width: 1,
        borderWidth: 1,
        borderColor: Colors.white,
        onCreateRenderer: (series) => _StreakSeriesRenderer(),
      );
    });
  }

  /// Completion fraction (0..1+) for [task] on [day]. Returns 0 for days in
  /// the future or on which the task isn't due.
  double _dayFraction(Task task, DateTime day) {
    if (!isTaskDueOn(task, day)) return 0;
    final progress =
        ref.read(appControllerProvider).progressFor(task.id, dateKey(day));
    return task.goal == 0 ? 0.0 : progress / task.goal;
  }

  static String _dayLabel(DateTime d) => '${d.day} ${const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Streaks')),
      body: tasks.isEmpty
          ? const Center(
              child: Text('Create a task to start tracking streaks.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeatmapCard(tasks: tasks, buildSeries: _buildSeries),
                const SizedBox(height: 16),
                _LegendCard(weeks: _weeks, buckets: _buckets!),
              ],
            ),
    );
  }
}

class _StreakData {
  final DateTime date;
  final String label;
  const _StreakData({required this.date, required this.label});
}

/// Generates the per-row (per-task) y-axis slicing. Mirrors Syncfusion's
/// `_HeatmapSeriesRenderer`: each series owns one evenly-sized slice of 0..101.
class _StreakSeriesRenderer
    extends StackedBar100SeriesRenderer<_StreakData, String> {
  @override
  void populateDataSource(
      [List<ChartValueMapper<_StreakData, num>>? yPaths,
      List<List<num>>? chaoticYLists,
      List<List<num>>? yLists,
      List<ChartValueMapper<_StreakData, Object>>? fPaths,
      List<List<Object?>>? chaoticFLists,
      List<List<Object?>>? fLists]) {
    super.populateDataSource(
        yPaths, chaoticYLists, yLists, fPaths, chaoticFLists, fLists);
    yMin = 0;
    yMax = 101;
    _computeHeatmapValues();
  }

  void _computeHeatmapValues() {
    if (xAxis == null || yAxis == null) return;
    if (yAxis!.dependents.isEmpty) return;

    final seriesLength = yAxis!.dependents.length;
    // Each row's slice height as a share of the 0..101 range.
    final num yValue = 101 / seriesLength;

    for (int i = 0; i < seriesLength; i++) {
      if (yAxis!.dependents[i] is _StreakSeriesRenderer) {
        final current = yAxis!.dependents[i] as _StreakSeriesRenderer;
        if (!current.controller.isVisible || current.dataCount == 0) continue;
        final stackValue = yValue * i;
        current.bottomValues.clear();
        current.topValues.clear();
        final length = current.dataCount;
        for (int j = 0; j < length; j++) {
          current.bottomValues.add(stackValue.toDouble());
          current.topValues.add((stackValue + yValue).toDouble());
        }
      }
    }
  }
}

class _HeatmapCard extends ConsumerWidget {
  final List<Task> tasks;
  final List<CartesianSeries<_StreakData, String>> Function(List<Task>)
      buildSeries;
  const _HeatmapCard({required this.tasks, required this.buildSeries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = buildSeries(tasks);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 180 + tasks.length * 22,
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
              labelPlacement: LabelPlacement.onTicks,
              axisLine: const AxisLine(width: 0),
              majorGridLines: const MajorGridLines(width: 0),
              majorTickLines: const MajorTickLines(width: 0),
              labelStyle: const TextStyle(fontSize: 9),
            ),
            primaryYAxis: NumericAxis(
              opposedPosition: true,
              axisLine: const AxisLine(width: 0),
              majorGridLines: const MajorGridLines(width: 0),
              majorTickLines: const MajorTickLines(width: 0),
              labelStyle: const TextStyle(fontSize: 0),
              multiLevelLabelStyle:
                  MultiLevelLabelStyle(borderColor: Colors.transparent),
              multiLevelLabels: _taskLabels(tasks),
              multiLevelLabelFormatter: _taskLabelFormatter,
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              animationDuration: 0,
              tooltipPosition: TooltipPosition.pointer,
              format: 'point.x : point.y',
            ),
            series: series,
          ),
        ),
      ),
    );
  }
}

List<NumericMultiLevelLabel> _taskLabels(List<Task> tasks) {
  // Each row spans tasks.length of the 0..101 range; compute midpoints.
  final step = 101 / tasks.length;
  return [
    for (var i = 0; i < tasks.length; i++)
      NumericMultiLevelLabel(
          start: step * i, end: step * (i + 1), text: _truncate(tasks[i].name)),
  ];
}

/// Custom Y-axis label rendering that only shows the task name, truncating
/// overly long ones.
ChartAxisLabel _taskLabelFormatter(MultiLevelLabelRenderDetails details) {
  return ChartAxisLabel(
    details.text,
    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
  );
}

String _truncate(String s, [int max = 16]) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';

class _LegendCard extends StatelessWidget {
  final int weeks;
  final List<_DayBucket> buckets;
  const _LegendCard({required this.weeks, required this.buckets});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last $weeks ${weeks == 1 ? 'week' : 'weeks'} · ${weeks * 7} days',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Less'),
                const SizedBox(width: 8),
                _legendCell(Color(0xFF5C6BC0).withValues(alpha: 0.12)),
                _legendCell(Color(0xFF5C6BC0).withValues(alpha: 0.35)),
                _legendCell(Color(0xFF5C6BC0).withValues(alpha: 0.65)),
                _legendCell(const Color(0xFF5C6BC0)),
                const SizedBox(width: 8),
                const Text('Goal met'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendCell(Color c) => Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
      );
}

class _DayBucket {
  final DateTime date;
  const _DayBucket({required this.date});
}
