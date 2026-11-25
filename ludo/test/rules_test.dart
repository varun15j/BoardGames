import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/ludo.dart';

MatchConfig _config({int players = 4, bool quick = false}) => MatchConfig(
      quick: quick,
      seats: [
        for (final c in MatchConfig.cornersFor(players)) SeatConfig(name: 'P$c', corner: c),
      ],
    );

GameState _state({int players = 4, bool quick = false}) => GameState.fresh(_config(players: players, quick: quick));

void main() {
  group('board', () {
    test('loop has 52 unique cells and 8 safe squares', () {
      expect(Board.loop.length, 52);
      expect({for (final c in Board.loop) '${c[0]},${c[1]}'}.length, 52);
      expect(Board.safeIndices.length, 8);
      for (final s in Board.startIndex) {
        expect(Board.safeIndices, contains(s));
        expect(Board.safeIndices, contains((s + 8) % 52));
      }
    });

    test('a token walks 51 loop cells then the home lane', () {
      expect(Board.loopIndex(1, 0), 13);
      expect(Board.loopIndex(1, 50), (13 + 50) % 52);
      expect(Board.loopIndex(1, 51), -1);
      expect(Board.lanes[2].length, 5);
    });
  });

  group('leaving base', () {
    test('only a 6 lets a token leave base', () {
      final s = _state();
      for (var r = 1; r <= 5; r++) {
        expect(Rules.legalMoves(s, r), isEmpty, reason: 'roll $r');
      }
      expect(Rules.legalMoves(s, 6), [0, 1, 2, 3]);
      final res = Rules.applyMove(s, 2, 6);
      expect(res.leftBase, isTrue);
      expect(s.steps[0][2], 0);
      expect(res.bonusRoll, isTrue);
    });
  });

  group('finishing', () {
    test('needs an exact roll to reach home', () {
      final s = _state()..steps[0][0] = 53;
      expect(Rules.legalMoves(s, 3), [0]);
      expect(Rules.legalMoves(s, 4), isEmpty);
      s.steps[0][1] = 50;
      expect(Rules.legalMoves(s, 4), [1]);
    });

    test('reaching home gives a bonus roll; last token finishes the player', () {
      final s = _state()..steps[0][0] = 54;
      var res = Rules.applyMove(s, 0, 2);
      expect(res.reachedHome, isTrue);
      expect(res.bonusRoll, isTrue);
      expect(res.playerFinished, isFalse);

      for (var i = 0; i < 4; i++) {
        s.steps[0][i] = 56;
      }
      s.steps[0][3] = 55;
      res = Rules.applyMove(s, 3, 1);
      expect(res.playerFinished, isTrue);
      expect(res.bonusRoll, isFalse);
      expect(s.finishOrder, [0]);
    });

    test('match ends when all but one player has finished', () {
      final s = _state(players: 3);
      s.finishOrder.add(0);
      expect(Rules.isOver(s), isFalse);
      s.finishOrder.add(2);
      expect(Rules.isOver(s), isTrue);
      expect(Rules.ranking(s).take(2), [0, 2]);
    });

    test('finished players are skipped when passing the turn', () {
      final s = _state(players: 3)..finishOrder.add(1);
      s.turn = 0;
      Rules.endTurn(s);
      expect(s.turn, 2);
    });
  });

  group('captures', () {
    // Seat 0 is corner 3 (start index 39); seat 1 is corner 0 (start 0).
    test('landing on a rival on a normal square sends it home and gives a bonus', () {
      final s = _state();
      s.steps[0][0] = 3; // loop index 42
      final rivalStep = (42 + 3 - 0) % 52; // seat 1 corner 0: index == step
      s.steps[1][0] = 45; // corner 0 index 45
      expect(rivalStep, 45);
      final res = Rules.applyMove(s, 0, 3);
      expect(res.captured, [const TokenRef(1, 0)]);
      expect(s.steps[1][0], -1);
      expect(s.captures[0], 1);
      expect(res.bonusRoll, isTrue);
    });

    test('safe squares protect rivals', () {
      final s = _state();
      // Target loop index 47 (a star) for seat 0: step (47 - 39) = 8.
      s.steps[0][0] = 5;
      s.steps[1][0] = 47; // corner 0 step 47 -> loop index 47
      final res = Rules.applyMove(s, 0, 3);
      expect(res.captured, isEmpty);
      expect(res.landedOnSafe, isTrue);
      expect(s.steps[1][0], 47);
      expect(res.bonusRoll, isFalse);
    });

    test('start squares are safe', () {
      final s = _state();
      s.steps[0][0] = 10; // loop index 49
      // Corner 0 start (index 0) is step 15 for seat 0 (49 + 3 = 52 -> 0).
      s.steps[1][0] = 0;
      final res = Rules.applyMove(s, 0, 3);
      expect(Board.loopIndex(3, res.to), 0);
      expect(res.captured, isEmpty);
    });

    test('home lane squares are private', () {
      final s = _state();
      s.steps[0][0] = 48;
      s.steps[1][0] = 52;
      final res = Rules.applyMove(s, 0, 4); // seat 0 -> step 52 (own lane)
      expect(res.captured, isEmpty);
      expect(s.steps[1][0], 52);
    });

    test('a capture can take several stacked rivals', () {
      final s = _state();
      s.steps[0][0] = 3;
      s.steps[1][0] = 45;
      s.steps[2][1] = (45 - 13 + 52) % 52; // seat 2 is corner 1 (start 13)
      final res = Rules.applyMove(s, 0, 3);
      expect(res.captured.length, 2);
    });
  });

  group('rolls and bonus', () {
    test('a 6 gives a bonus roll even without capture', () {
      final s = _state()..steps[0][0] = 10;
      expect(Rules.applyMove(s, 0, 6).bonusRoll, isTrue);
    });

    test('an ordinary move ends the turn', () {
      final s = _state()..steps[0][0] = 10;
      expect(Rules.applyMove(s, 0, 4).bonusRoll, isFalse);
    });

    test('three sixes in a row end the turn', () {
      final s = _state()..steps[0][0] = 10;
      expect(Rules.registerRoll(s, 6), RollOutcome.canMove);
      expect(Rules.registerRoll(s, 6), RollOutcome.canMove);
      expect(Rules.registerRoll(s, 6), RollOutcome.threeSixes);
      expect(s.sixesRolled[0], 3);
    });

    test('a non-six resets the streak', () {
      final s = _state()..steps[0][0] = 10;
      Rules.registerRoll(s, 6);
      Rules.registerRoll(s, 6);
      Rules.registerRoll(s, 2);
      expect(s.sixStreak, 0);
      expect(Rules.registerRoll(s, 6), RollOutcome.canMove);
    });

    test('no legal move is reported', () {
      final s = _state();
      expect(Rules.registerRoll(s, 3), RollOutcome.noMoves);
    });
  });

  group('quick setup', () {
    test('two tokens each, one already out', () {
      final s = _state(quick: true);
      for (final row in s.steps) {
        expect(row, [0, -1]);
      }
      expect(s.tokenCount, 2);
    });

    test('player finishes with only two tokens home', () {
      final s = _state(players: 2, quick: true);
      s.steps[0] = [56, 55];
      final res = Rules.applyMove(s, 1, 1);
      expect(res.playerFinished, isTrue);
      expect(Rules.isOver(s), isTrue);
    });
  });

  group('save format', () {
    test('state survives a JSON round trip', () {
      final s = _state(quick: true)
        ..turn = 1
        ..steps[1][1] = 20
        ..captures[0] = 2;
      final copy = GameState.fromJson(s.toJson());
      expect(copy.steps, s.steps);
      expect(copy.turn, 1);
      expect(copy.captures, s.captures);
      expect(copy.config.quick, isTrue);
      expect(copy.config.seats.length, 4);
    });
  });

  group('bot', () {
    test('prefers a capture over finishing', () {
      final s = _state();
      s.steps[0][0] = 3; // can capture seat 1 token at loop index 45 with a 3
      s.steps[1][0] = 45;
      s.steps[0][1] = 53; // can finish with a 3
      expect(LudoBot.best(s, Rules.legalMoves(s, 3), 3), 0);
    });

    test('prefers finishing over leaving base', () {
      final s = _state();
      s.steps[0] = [50, -1, -1, -1]; // 50 + 6 = home
      expect(LudoBot.best(s, Rules.legalMoves(s, 6), 6), 0);
    });

    test('prefers leaving base over a safe square', () {
      final s = _state()..steps[0][0] = 5;
      // From step 5 (loop 44), +6 = step 11 (loop 50): not safe, but compare base.
      expect(LudoBot.best(s, Rules.legalMoves(s, 6), 6), 1);
    });

    test('prefers a safe square over entering the home lane', () {
      final s = _state();
      s.steps[0][0] = 46; // +3 = 49: lane not entered; not safe
      s.steps[0][1] = 48; // +3 = 51 enters the lane
      s.steps[0][2] = 5; // +3 = step 8 -> loop 47: safe star
      s.steps[0][3] = 56;
      expect(LudoBot.best(s, Rules.legalMoves(s, 3), 3), 2);
    });

    test('prefers entering the home lane over the furthest token', () {
      final s = _state();
      s.steps[0][0] = 48; // +3 = 51 lane
      s.steps[0][1] = 30; // +3 = 33
      s.steps[0][2] = 56;
      s.steps[0][3] = 56;
      expect(LudoBot.best(s, Rules.legalMoves(s, 3), 3), 0);
    });

    test('otherwise moves the furthest token', () {
      final s = _state();
      s.steps[0] = [10, 30, 20, 56];
      expect(LudoBot.best(s, Rules.legalMoves(s, 2), 2), 1);
    });

    test('easy bot sometimes picks a worse move, normal never does', () {
      final s = _state();
      s.steps[0] = [10, 30, 20, 56];
      final rng = Random(1);
      final easy = {for (var i = 0; i < 200; i++) LudoBot.choose(s, 2, BotLevel.easy, rng)};
      expect(easy.length, greaterThan(1));
      final normal = {for (var i = 0; i < 50; i++) LudoBot.choose(s, 2, BotLevel.normal, rng)};
      expect(normal, {1});
    });

    test('bots finish whole games without breaking rules', () {
      final rng = Random(7);
      for (var game = 0; game < 20; game++) {
        final s = _state(players: 2 + game % 3, quick: game.isEven);
        var guard = 0;
        while (!Rules.isOver(s) && guard++ < 20000) {
          final roll = 1 + rng.nextInt(6);
          final outcome = Rules.registerRoll(s, roll);
          if (outcome != RollOutcome.canMove) {
            Rules.endTurn(s);
            continue;
          }
          final t = LudoBot.choose(s, roll, BotLevel.normal, rng);
          final r = Rules.applyMove(s, t, roll);
          if (!r.bonusRoll) Rules.endTurn(s);
        }
        expect(Rules.isOver(s), isTrue, reason: 'game $game');
      }
    });
  });
}
