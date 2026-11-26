import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/ui/controller.dart';
import 'package:ludo/src/ui/game_screen.dart';
import 'package:ludo/src/ui/result_screen.dart';
import 'package:ludo/src/ui/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    KitTheme.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: KitTheme.data(), home: home));
    await tester.pump();
  }

  testWidgets('home lists the four entries and opens setup', (tester) async {
    await pumpApp(tester, const LudoGame());
    for (final t in ['vs Bots', 'Pass & Play', 'Quick Match', 'How to play']) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.tap(find.text('vs Bots'));
    await tester.pumpAndSettle();
    expect(find.text('Start match'), findsOneWidget);
    await tester.tap(find.text('2 players'));
    await tester.pump();
    expect(find.textContaining('Bot '), findsOneWidget);
    await tester.ensureVisible(find.text('Quick · 2 tokens'));
    await tester.tap(find.text('Quick · 2 tokens'));
    await tester.pump();
  });

  testWidgets('pass and play starts with a handoff card', (tester) async {
    await pumpApp(tester, const LudoGame());
    await tester.tap(find.text('Pass & Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start match'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pass to'), findsOneWidget);
    expect(find.text("I'm ready"), findsOneWidget);
    await tester.tap(find.text("I'm ready"));
    await tester.pump();
    expect(find.text('Pass to'), findsNothing);
    // Leave the tree so timers are cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a saved game offers Resume', (tester) async {
    final state = GameState.fresh(const MatchConfig(
      seats: [SeatConfig(name: 'You', corner: 3), SeatConfig(name: 'Bot', corner: 1, isBot: true)],
    ));
    await tester.runAsync(() => const LudoStorage().save(state));
    await pumpApp(tester, const LudoGame());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('Resume game'), findsOneWidget);
  });

  testWidgets('game screen: roll then open the pause menu', (tester) async {
    final state = GameState.fresh(const MatchConfig(
      quick: true,
      seats: [SeatConfig(name: 'You', corner: 3), SeatConfig(name: 'Bot', corner: 1, isBot: true)],
    ));
    await pumpApp(tester, GameScreen(state: state, timing: GameTiming.instant));
    expect(find.text('Your turn · tap the die'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Roll the die'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(find.bySemanticsLabel('Pause').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Save & exit'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('result screen ranks players', (tester) async {
    final state = GameState.fresh(const MatchConfig(
      seats: [SeatConfig(name: 'You', corner: 3), SeatConfig(name: 'Bot Amber', corner: 1, isBot: true)],
    ));
    state.steps[0].fillRange(0, 4, 56);
    state.finishOrder.add(0);
    state.captures[0] = 2;
    await pumpApp(tester, ResultScreen(state: state));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('You win!'), findsOneWidget);
    expect(find.text('Rematch'), findsOneWidget);
    expect(find.textContaining('2 captures'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
