import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forest.dart';
import '../providers/app_controller.dart';
import '../providers/forest_reward_provider.dart';

class ForestRewardFrame {
  final int level;
  final double progress, burst, opacity;
  final bool levelUp;
  const ForestRewardFrame(
      this.level, this.progress, this.burst, this.opacity, this.levelUp);
  int get span =>
      ForestState.xpForLevel(level + 1) - ForestState.xpForLevel(level);
  int get xp => (progress * span).round();
}

class ForestRewardTimeline {
  final ForestReward reward;
  const ForestRewardTimeline(this.reward);
  int get segments => reward.afterLevel - reward.beforeLevel + 1;
  Duration get duration =>
      Duration(milliseconds: 700 + segments * 750 + 1200 + 180);
  ForestRewardFrame frameAt(Duration elapsed, {bool reduced = false}) {
    if (reduced) {
      return ForestRewardFrame(reward.afterLevel, reward.afterProgress, 0, 1,
          reward.afterLevel > reward.beforeLevel);
    }
    final ms = elapsed.inMilliseconds;
    final raw = math.max(0.0, (ms - 700) / 750);
    final index = raw.floor().clamp(0, segments - 1);
    final t = (raw - index).clamp(0.0, 1.0);
    final level = reward.beforeLevel + index;
    final start = index == 0 ? reward.beforeProgress : 0.0;
    final end = index == segments - 1 ? reward.afterProgress : 1.0;
    final progress = start +
        (end - start) * Curves.easeOutCubic.transform((t / .82).clamp(0, 1));
    return ForestRewardFrame(
        level,
        progress,
        index > 0 && t < .8 ? t / .8 : 0,
        math.min((ms / 160).clamp(0.0, 1.0),
            ((duration.inMilliseconds - ms) / 180).clamp(0.0, 1.0)),
        level > reward.beforeLevel);
  }
}

// Lives above the navigator: progress can be seen on the task list or forest,
// without inserting/removing content in either page's scrolling layout.
class ForestRewardOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const ForestRewardOverlay({super.key, required this.child});
  @override
  ConsumerState<ForestRewardOverlay> createState() =>
      _ForestRewardOverlayState();
}

class _ForestRewardOverlayState extends ConsumerState<ForestRewardOverlay> {
  ForestReward? _current, _pending;
  int _serial = 0;

  void _enqueue(ForestReward reward) {
    if (reward.xpGained <= 0) return;
    setState(() {
      if (_current == null) {
        _current = reward;
        _serial++;
      } else if (reward.after.xp > _current!.after.xp) {
        final before = _pending?.before ?? _current!.after;
        final after = _pending != null && _pending!.after.xp > reward.after.xp
            ? _pending!.after
            : reward.after;
        _pending = ForestReward(before, after);
      }
    });
  }

  void _next() => setState(() {
        _current = _pending;
        _pending = null;
        _serial++;
      });

  @override
  Widget build(BuildContext context) {
    ref.listen(forestRewardProvider, (_, next) {
      if (next != null) _enqueue(next);
    });
    ref.listen(authStateProvider, (_, next) {
      if (next.value == false && (_current != null || _pending != null)) {
        setState(() {
          _current = null;
          _pending = null;
        });
      }
    });
    final top = MediaQuery.paddingOf(context).top +
        math.max(56, MediaQuery.textScalerOf(context).scale(42) + 16) +
        8;
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      if (_current != null)
        Positioned(
          top: top,
          left: 12,
          right: 12,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ForestRewardCelebration(
                  key: ValueKey(_serial), reward: _current!, onFinished: _next),
            ),
          ),
        ),
    ]);
  }
}

class ForestRewardCelebration extends StatefulWidget {
  final ForestReward reward;
  final VoidCallback onFinished;
  const ForestRewardCelebration(
      {super.key, required this.reward, required this.onFinished});
  @override
  State<ForestRewardCelebration> createState() =>
      _ForestRewardCelebrationState();
}

class _ForestRewardCelebrationState extends State<ForestRewardCelebration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final timeline = ForestRewardTimeline(widget.reward);
  late final _controller =
      AnimationController(vsync: this, duration: timeline.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        });
  Timer? _hold;
  bool? _reduced;
  bool _finished = false;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished) return;
    if (state != AppLifecycleState.resumed) {
      _controller.stop();
      _hold?.cancel();
    } else if (_reduced == true) {
      _hold = Timer(const Duration(milliseconds: 2600), _finish);
    } else {
      _controller.forward();
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _controller.stop();
    _hold?.cancel();
    widget.onFinished();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced == reduced) return;
    _reduced = reduced;
    _hold?.cancel();
    if (reduced) {
      _controller.stop();
      if (_foreground) {
        _hold = Timer(const Duration(milliseconds: 2600), _finish);
      }
    } else if (_foreground) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final frame = timeline.frameAt(
              Duration(
                  milliseconds:
                      (_controller.value * timeline.duration.inMilliseconds)
                          .round()),
              reduced: _reduced ?? false);
          final colors = Theme.of(context).colorScheme,
              text = Theme.of(context).textTheme;
          final unlocked = frame.levelUp
              ? TreeSpecies.values
                  .where((species) => species.unlockLevel == frame.level)
                  .map((species) => species.label)
                  .toList()
              : <String>[];
          return Opacity(
              opacity: frame.opacity,
              child: Transform.translate(
                offset: Offset(0, -10 * (1 - frame.opacity)),
                child: Stack(clipBehavior: Clip.none, children: [
                  Semantics(
                    container: true,
                    liveRegion: true,
                    label:
                        'Earned ${widget.reward.xpGained} XP. Forest level ${widget.reward.afterLevel}.',
                    child: Material(
                      elevation: frame.levelUp ? 8 : 4,
                      color: frame.levelUp
                          ? colors.secondaryContainer
                          : colors.surfaceContainerLow,
                      shadowColor: colors.primary.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 10, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              DecoratedBox(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          colors.primary.withValues(alpha: .1)),
                                  child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Transform.scale(
                                          scale: 1 +
                                              math.sin(frame.burst * math.pi) *
                                                  .3,
                                          child: Icon(
                                              frame.levelUp
                                                  ? Icons.auto_awesome_rounded
                                                  : Icons.eco_outlined,
                                              color: colors.primary,
                                              size: 24)))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      frame.levelUp
                                          ? 'Level ${frame.level} reached!'
                                          : 'Forest progress',
                                      style: text.titleMedium)),
                              IconButton(
                                  key:
                                      const ValueKey('dismiss-forest-progress'),
                                  onPressed: _finish,
                                  icon: const Icon(Icons.close_rounded,
                                      semanticLabel: 'Dismiss forest progress',
                                      size: 20)),
                            ]),
                            const SizedBox(height: 6),
                            Wrap(spacing: 12, runSpacing: 4, children: [
                              Text('Level ${frame.level}',
                                  style: text.labelLarge),
                              Text('+${widget.reward.xpGained} XP',
                                  style: text.labelLarge
                                      ?.copyWith(color: colors.primary)),
                            ]),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                                key: const ValueKey('forest-reward-xp-bar'),
                                value: frame.progress,
                                backgroundColor:
                                    colors.onSurface.withValues(alpha: .12),
                                color: colors.primary,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(8),
                                semanticsLabel:
                                    'Forest level ${frame.level} progress',
                                semanticsValue:
                                    '${(frame.progress * 100).round()}%'),
                            const SizedBox(height: 8),
                            Text(
                                '${frame.xp} / ${frame.span} XP to level ${frame.level + 1}',
                                style: text.bodySmall),
                            if (frame.levelUp)
                              Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                      unlocked.isEmpty
                                          ? 'Your clearing expanded'
                                          : '${unlocked.join(', ')} unlocked',
                                      style: text.labelLarge)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (frame.burst > 0 && !(_reduced ?? false))
                    Positioned.fill(
                      child: IgnorePointer(
                          child: CustomPaint(
                              key: const ValueKey('forest-level-up-burst'),
                              painter: _LevelBurst(frame.burst, colors.primary,
                                  const Color(0xFFE3B450)))),
                    ),
                ]),
              ));
        },
      );
}

class _LevelBurst extends CustomPainter {
  final double progress;
  final Color green, gold;
  _LevelBurst(this.progress, this.green, this.gold);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    for (var i = 0; i < 24; i++) {
      final angle = math.pi + i * math.pi / 23;
      final distance = 25 + progress * (35 + i % 4 * 18);
      final point = Offset(size.width / 2 + math.cos(angle) * distance * 1.5,
          32 + math.sin(angle) * distance);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + progress * math.pi);
      paint.color = (i.isEven ? green : gold)
          .withValues(alpha: (1 - progress).clamp(0, 1));
      if (i % 3 == 0) {
        final path = Path()
          ..moveTo(0, -6)
          ..lineTo(2, -2)
          ..lineTo(6, 0)
          ..lineTo(2, 2)
          ..lineTo(0, 6)
          ..lineTo(-2, 2)
          ..lineTo(-6, 0)
          ..lineTo(-2, -2)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawOval(const Rect.fromLTWH(-3, -5, 6, 10), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LevelBurst old) =>
      old.progress != progress || old.green != green || old.gold != gold;
}
