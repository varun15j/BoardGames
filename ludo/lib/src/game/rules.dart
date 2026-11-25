import 'board.dart';
import 'models.dart';

/// What happened when a roll was registered.
enum RollOutcome {
  /// At least one token can move.
  canMove,

  /// No legal move; the turn is over.
  noMoves,

  /// Third six in a row; the turn is over and the roll is lost.
  threeSixes,
}

/// The result of moving one token.
class MoveResult {
  const MoveResult({
    required this.seat,
    required this.token,
    required this.from,
    required this.to,
    required this.captured,
    required this.reachedHome,
    required this.landedOnSafe,
    required this.bonusRoll,
    required this.playerFinished,
  });

  final int seat;
  final int token;
  final int from;
  final int to;
  final List<TokenRef> captured;
  final bool reachedHome;
  final bool landedOnSafe;
  final bool bonusRoll;
  final bool playerFinished;

  bool get leftBase => from < 0;
}

/// The rules. All functions are pure Dart and operate on [GameState].
class Rules {
  Rules._();

  /// Step a token reaches with [roll]: leaving base always lands on step 0.
  static int targetStep(int step, int roll) => step < 0 ? 0 : step + roll;

  /// Tokens of the seat to move that may move with [roll].
  static List<int> legalMoves(GameState s, int roll) => legalMovesFor(s, s.turn, roll);

  static List<int> legalMovesFor(GameState s, int seat, int roll) {
    final moves = <int>[];
    final steps = s.steps[seat];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step < 0) {
        if (roll == 6) moves.add(i);
      } else if (step + roll <= Board.homeStep) {
        moves.add(i);
      }
    }
    return moves;
  }

  /// Opponent tokens that would be sent home by [seat] landing on [step].
  static List<TokenRef> victimsAt(GameState s, int seat, int step) {
    final idx = Board.loopIndex(s.cornerOf(seat), step);
    if (idx < 0 || Board.isSafeLoopIndex(idx)) return const [];
    final out = <TokenRef>[];
    for (var q = 0; q < s.seatCount; q++) {
      if (q == seat) continue;
      for (var j = 0; j < s.steps[q].length; j++) {
        if (Board.loopIndex(s.cornerOf(q), s.steps[q][j]) == idx) out.add(TokenRef(q, j));
      }
    }
    return out;
  }

  /// True when a token landing on [step] stands on a safe square.
  static bool isSafeStep(GameState s, int seat, int step) =>
      Board.isSafeLoopIndex(Board.loopIndex(s.cornerOf(seat), step));

  /// Registers a die roll for the seat to move: updates the six counters and
  /// reports whether the turn continues.
  static RollOutcome registerRoll(GameState s, int roll) {
    s.lastRoll = roll;
    if (roll == 6) {
      s.sixesRolled[s.turn]++;
      s.sixStreak++;
      if (s.sixStreak >= 3) return RollOutcome.threeSixes;
    } else {
      s.sixStreak = 0;
    }
    return legalMoves(s, roll).isEmpty ? RollOutcome.noMoves : RollOutcome.canMove;
  }

  /// Moves [token] of the seat to move by [roll]. The caller must pass a
  /// legal move. Captures remove rival tokens; the result says whether the
  /// player earns a bonus roll. Call [endTurn] when there is no bonus.
  static MoveResult applyMove(GameState s, int token, int roll) {
    final seat = s.turn;
    final from = s.steps[seat][token];
    final to = targetStep(from, roll);
    assert(legalMoves(s, roll).contains(token), 'illegal move');
    final captured = victimsAt(s, seat, to);
    s.steps[seat][token] = to;
    for (final v in captured) {
      s.steps[v.seat][v.token] = -1;
    }
    s.captures[seat] += captured.length;
    final reachedHome = to == Board.homeStep;
    final finished = reachedHome && s.hasFinished(seat);
    if (finished && !s.finishOrder.contains(seat)) s.finishOrder.add(seat);
    final bonus = !finished && (roll == 6 || captured.isNotEmpty || reachedHome);
    return MoveResult(
      seat: seat,
      token: token,
      from: from,
      to: to,
      captured: captured,
      reachedHome: reachedHome,
      landedOnSafe: isSafeStep(s, seat, to),
      bonusRoll: bonus,
      playerFinished: finished,
    );
  }

  /// The match ends when all but one player have brought every token home.
  static bool isOver(GameState s) => s.finishOrder.length >= s.seatCount - 1;

  /// Passes the turn to the next seat that has not finished.
  static void endTurn(GameState s) {
    s.sixStreak = 0;
    if (isOver(s)) return;
    var next = s.turn;
    do {
      next = (next + 1) % s.seatCount;
    } while (s.finishOrder.contains(next));
    s.turn = next;
  }

  /// Total progress of a seat, used to rank players who have not finished.
  static int progress(GameState s, int seat) => s.steps[seat].fold(0, (a, b) => a + (b < 0 ? 0 : b + 1));

  /// Seats from first to last: finishers in order, then by progress.
  static List<int> ranking(GameState s) {
    final rest = [for (var i = 0; i < s.seatCount; i++) if (!s.finishOrder.contains(i)) i]
      ..sort((a, b) => progress(s, b).compareTo(progress(s, a)));
    return [...s.finishOrder, ...rest];
  }
}
