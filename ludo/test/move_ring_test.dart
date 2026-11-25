import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/ui/board_view.dart';
import 'package:ludo/src/ui/controller.dart';

/// Always rolls a three.
class _Threes implements Random {
  @override
  int nextInt(int max) => 2;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.9;
}

void main() {
  setUp(() => KitTheme.useGoogleFonts = false);

  for (final quality in GraphicsQuality.values) {
    testWidgets('only movable tokens get a ring; steps leave prints (${quality.name})', (tester) async {
      final state = GameState.fresh(const MatchConfig(
        seats: [SeatConfig(name: 'You', corner: 3), SeatConfig(name: 'Bot', corner: 1, isBot: true)],
      ));
      // Two tokens out (movable), two in base (not movable with a three).
      state.steps[0][0] = 4;
      state.steps[0][1] = 20;
      final c = LudoController(state: state, random: _Threes(), timing: GameTiming.instant, soundOn: false, hapticsOn: false);
      final steps = <StepEvent>[];
      c.events.listen((e) {
        if (e is StepEvent) steps.add(e);
      });
      await tester.pumpWidget(MaterialApp(
        home: Center(child: SizedBox(width: 360, height: 360, child: BoardView(controller: c, quality: quality))),
      ));
      c.start();
      await tester.pump();
      expect(find.byType(MoveRing), findsNothing);

      c.rollTapped();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(c.phase, TurnPhase.choosing);
      expect(find.byType(MoveRing), findsNWidgets(2));

      c.selectToken(0);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(steps.take(3).map((s) => s.number), [1, 2, 3]);
      expect(steps[2].last, isTrue);
      final layer = tester.state<FootprintLayerState>(find.byType(FootprintLayer));
      expect(layer.trail.prints, isNotEmpty);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
