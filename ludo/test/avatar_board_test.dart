import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/ui/board_view.dart';
import 'package:ludo/src/ui/controller.dart';
import 'package:ludo/src/ui/seat_avatar.dart';
import 'package:ludo/src/ui/setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    KitTheme.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  test('the yard eyes line up with the top two token spots', () {
    // Board.sockets are (row, col); the face layout is (x = col, y = row).
    final top = [for (final s in Board.sockets.take(2)) Offset(s[1], s[0])];
    final bottom = [for (final s in Board.sockets.skip(2)) Offset(s[1], s[0])];
    expect(YardFaceLayout.eyes, top);
    expect(YardFaceLayout.cheeks, bottom);
  });

  test('avatars are saved with the match', () {
    final state = GameState.fresh(const MatchConfig(seats: [
      SeatConfig(name: 'A', corner: 3, avatar: 'a:fox'),
      SeatConfig(name: 'B', corner: 1),
    ]));
    final copy = GameState.fromJson(state.toJson());
    expect(seatAvatar(copy.config.seats[0]), const AvatarChoice('fox'));
    expect(seatAvatar(copy.config.seats[1]), AvatarChoice(kDefaultCornerAvatars[1]));
  });

  for (final quality in GraphicsQuality.values) {
    testWidgets('each yard shows its player (${quality.name})', (tester) async {
      final state = GameState.fresh(const MatchConfig(seats: [
        SeatConfig(name: 'You', corner: 3, avatar: 'a:cat'),
        SeatConfig(name: 'Bot', corner: 1, isBot: true, avatar: 'a:ufo'),
      ]));
      final c = LudoController(state: state, timing: GameTiming.instant, soundOn: false, hapticsOn: false);
      await tester.pumpWidget(MaterialApp(
        home: Center(child: SizedBox(width: 360, height: 360, child: BoardView(controller: c, quality: quality))),
      ));
      await tester.pump(const Duration(seconds: 7));
      final yards = tester.widgetList<YardFace>(find.byType(YardFace)).toList();
      expect(yards.map((y) => y.avatar.avatarId), ['cat', 'ufo']);
      expect(yards.first.flat, quality == GraphicsQuality.performance);
      expect(find.byType(CharacterToken), findsNWidgets(8));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets('pass and play seats each pick a name and avatar', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SetupScreen(mode: SetupMode.passAndPlay, random: Random(3), profile: PlayerProfile()),
    ));
    final ids = tester.widgetList<AvatarView>(find.byType(AvatarView)).map((a) => a.choice.avatarId).toList();
    expect(ids.length, 4);
    expect(ids.toSet().length, 4, reason: 'distinct by default');

    await tester.tap(find.byKey(const ValueKey('seat-avatar-1')));
    await tester.pumpAndSettle();
    expect(find.text('Seat 2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ravi');
    await tester.ensureVisible(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('avatar-mango')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Ravi'), findsOneWidget);
    final after = tester.widgetList<AvatarView>(find.byType(AvatarView)).map((a) => a.choice.avatarId).toList();
    expect(after[1], 'mango');
  });
}
