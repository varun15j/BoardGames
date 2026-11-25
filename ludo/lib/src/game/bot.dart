import 'dart:math';

import 'board.dart';
import 'models.dart';
import 'rules.dart';

/// Bot move choice.
///
/// Priority: capture > finish > leave base > safe square > enter home lane >
/// furthest token. The easy bot plays a random legal move half the time.
class LudoBot {
  LudoBot._();

  static int choose(GameState s, int roll, BotLevel level, Random rng) {
    final moves = Rules.legalMoves(s, roll);
    assert(moves.isNotEmpty);
    return chooseFrom(s, moves, roll, level, rng);
  }

  static int chooseFrom(GameState s, List<int> moves, int roll, BotLevel level, Random rng) {
    if (moves.length == 1) return moves.first;
    if (level == BotLevel.easy && rng.nextBool()) return moves[rng.nextInt(moves.length)];
    return best(s, moves, roll);
  }

  /// The highest priority move, ignoring any randomness.
  static int best(GameState s, List<int> moves, int roll) {
    var bestToken = moves.first;
    var bestScore = -1;
    for (final t in moves) {
      final score = _score(s, t, roll);
      if (score > bestScore) {
        bestScore = score;
        bestToken = t;
      }
    }
    return bestToken;
  }

  static int _score(GameState s, int token, int roll) {
    final seat = s.turn;
    final from = s.steps[seat][token];
    final to = Rules.targetStep(from, roll);
    var score = 0;
    if (Rules.victimsAt(s, seat, to).isNotEmpty) score += 100000;
    if (to == Board.homeStep) score += 10000;
    if (from < 0) score += 1000;
    if (Rules.isSafeStep(s, seat, to) && from >= 0) score += 100;
    if (from <= Board.lastLoopStep && to > Board.lastLoopStep && to < Board.homeStep) score += 10;
    return score + max(from, 0);
  }
}
