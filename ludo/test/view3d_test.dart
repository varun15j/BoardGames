import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/ui/board3d_view.dart';
import 'package:ludo/src/ui/board_view.dart';
import 'package:ludo/src/ui/controller.dart';
import 'package:ludo/src/ui/game_screen.dart';
import 'package:ludo/src/ui/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Always rolls a three.
class _Threes implements Random {
  @override
  int nextInt(int max) => 2;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.9;
}

GameState _state() {
  final state = GameState.fresh(const MatchConfig(seats: [
    SeatConfig(name: 'You', corner: 3, avatar: 'a:cat'),
    SeatConfig(name: 'Bot', corner: 1, isBot: true, avatar: 'a:frog'),
  ]));
  state.steps[0][0] = 4;
  state.steps[0][1] = 20;
  return state;
}

void main() {
  setUp(() {
    KitTheme.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> frames(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  testWidgets('the button switches 2D and 3D mid-match and is remembered', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = _state();
    await tester.pumpWidget(MaterialApp(home: GameScreen(state: state, timing: GameTiming.instant)));
    await tester.pump();
    expect(find.byType(BoardView), findsOneWidget, reason: '2D until chosen');

    await tester.tap(find.byKey(const ValueKey('view-toggle')));
    await frames(tester, 3);
    expect(find.byType(Board3DView), findsOneWidget);
    expect(find.byType(BoardView), findsNothing);
    expect(state.steps[0], [4, 20, -1, -1], reason: 'the match is untouched');
    expect(await tester.runAsync(const LudoStorage().loadView3d), isTrue);

    await tester.tap(find.byKey(const ValueKey('view-toggle')));
    await frames(tester, 3);
    expect(find.byType(BoardView), findsOneWidget);
    expect(await tester.runAsync(const LudoStorage().loadView3d), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final quality in GraphicsQuality.values) {
    testWidgets('3D board plays a move by tapping a creature (${quality.name})', (tester) async {
      final state = _state();
      final c = LudoController(state: state, random: _Threes(), timing: GameTiming.instant, soundOn: false, hapticsOn: false);
      await tester.pumpWidget(MaterialApp(
        home: Center(child: SizedBox(width: 360, height: 360, child: Board3DView(controller: c, quality: quality))),
      ));
      c.start();
      await frames(tester, 2);
      c.rollTapped();
      await frames(tester, 6);
      expect(c.phase, TurnPhase.choosing);
      final view = tester.state<Board3DViewState>(find.byType(Board3DView));
      expect(view.scene.die!.value, c.dieValue, reason: 'the die shows the engine\'s roll');
      expect(view.scene.low, quality == GraphicsQuality.performance);

      final at = view.screenPositionOf(0, 0);
      await tester.tapAt(tester.getTopLeft(find.byType(Board3DView)) + at);
      await frames(tester, 20);
      expect(state.steps[0][0], 7);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
