import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/ui/board3d_view.dart';
import 'package:ludo/src/ui/controller.dart';
import 'package:ludo/src/ui/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    KitTheme.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  // A tall phone like the Nord 4 and a short one.
  for (final (name, size) in [('tall', const Size(412, 915)), ('short', const Size(360, 640))]) {
    for (final view3d in [true, false]) {
      testWidgets('$name phone fits the game in ${view3d ? "3D" : "2D"}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = GameState.fresh(const MatchConfig(seats: [
          SeatConfig(name: 'You', corner: 3, avatar: 'a:cat'),
          SeatConfig(name: 'B', corner: 0, isBot: true, avatar: 'a:lion'),
          SeatConfig(name: 'C', corner: 1, isBot: true, avatar: 'a:owl'),
          SeatConfig(name: 'D', corner: 2, isBot: true, avatar: 'a:frog'),
        ]));
        await tester.pumpWidget(MaterialApp(
          home: GameScreen(state: state, timing: GameTiming.instant, view3d: view3d),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'nothing overflows');
        if (view3d) {
          final board = tester.getSize(find.byType(Board3DView));
          expect(board.width, size.width, reason: 'the 3D board uses the full width');
          expect(board.height, greaterThan(200));
        }
        expect(find.text('You'), findsOneWidget);
        expect(find.bySemanticsLabel('Roll the die'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
