import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forest.dart';

class ForestReward {
  final ForestState before, after;
  final int xpGained, beforeLevel, afterLevel;
  final double beforeProgress, afterProgress;
  ForestReward(this.before, this.after)
      : xpGained = after.xp - before.xp,
        beforeLevel = before.level,
        afterLevel = after.level,
        beforeProgress = before.levelProgress,
        afterProgress = after.levelProgress;
}

// Local, successfully saved rewards only. Loading/syncing a forest never emits.
final forestRewardProvider =
    NotifierProvider<ForestRewardController, ForestReward?>(
        ForestRewardController.new);

class ForestRewardController extends Notifier<ForestReward?> {
  @override
  ForestReward? build() => null;
  void clear() => state = null;
  void emit(ForestReward reward) => state = reward;
}
