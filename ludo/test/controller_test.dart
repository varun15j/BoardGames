import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/ui/controller.dart';

MatchConfig _config({required List<bool> bots, bool quick = false}) {
  final corners = MatchConfig.cornersFor(bots.length);
  return MatchConfig(
    quick: quick,
    seats: [
      for (var i = 0; i < bots.length; i++)
        SeatConfig(name: 'S$i', corner: corners[i], isBot: bots[i], level: BotLevel.normal),
    ],
  );
}

Future<void> _until(bool Function() done, {int max = 200000}) async {
  var n = 0;
  while (!done() && n++ < max) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LudoController make(MatchConfig cfg, {void Function(GameState)? onSave, int seed = 1}) => LudoController(
        state: GameState.fresh(cfg),
        random: Random(seed),
        timing: GameTiming.instant,
        soundOn: false,
        hapticsOn: false,
        onSave: onSave,
      );

  test('an all-bot match plays to the end and saves every turn', () async {
    var saves = 0;
    final c = make(_config(bots: [true, true, true, true]), onSave: (_) => saves++)..start();
    await _until(() => c.phase == TurnPhase.over);
    expect(c.phase, TurnPhase.over);
    expect(Rules.isOver(c.state), isTrue);
    expect(saves, greaterThan(10));
    // The drawn positions caught up with the rules state.
    expect(c.display, c.state.steps);
    c.dispose();
  });

  test('quick all-bot match finishes too', () async {
    final c = make(_config(bots: [true, true], quick: true), seed: 5)..start();
    await _until(() => c.phase == TurnPhase.over);
    expect(c.phase, TurnPhase.over);
    c.dispose();
  });

  test('a human can roll and pick tokens through a whole match', () async {
    final c = make(_config(bots: [false, true]), seed: 3)..start();
    var guard = 0;
    while (c.phase != TurnPhase.over && guard++ < 400000) {
      if (c.humanToRoll) {
        c.rollTapped();
      } else if (c.humanToPick) {
        expect(c.movable, isNotEmpty);
        expect(c.ghosts.length, c.movable.length);
        c.selectToken(c.movable.first);
      }
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.phase, TurnPhase.over);
    c.dispose();
  });

  test('pass and play asks each human to take the device', () async {
    final c = make(_config(bots: [false, false]))..start();
    expect(c.phase, TurnPhase.handoff);
    c.acknowledgeHandoff();
    expect(c.phase, TurnPhase.awaitingRoll);
    c.dispose();
  });

  test('pausing stops a human from rolling', () async {
    final c = make(_config(bots: [false, true]))..start();
    c.pause();
    c.rollTapped();
    expect(c.phase, TurnPhase.awaitingRoll);
    c.resume();
    c.rollTapped();
    expect(c.phase, TurnPhase.rolling);
    await _until(() => c.phase != TurnPhase.rolling);
    c.dispose();
  });
}
