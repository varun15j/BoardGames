import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/ui/controller.dart';
import 'package:ludo/src/ui/game_screen.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    KitTheme.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a match plays in 3D and switches to 2D from the pause menu', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final graphics = GraphicsSettings(
      readDevice: () async => const DeviceCapability(ramMb: 8000, sdkInt: 36, isLowRam: false),
    );
    await tester.runAsync(graphics.ensureLoaded);
    final tilt = TiltController(source: () => const Stream<GyroscopeEvent>.empty());
    final state = GameState.fresh(const MatchConfig(
      quick: true,
      seats: [SeatConfig(name: 'You', corner: 3), SeatConfig(name: 'Bot', corner: 1, isBot: true)],
    ));

    await tester.pumpWidget(MaterialApp(
      theme: KitTheme.data(),
      home: GameScreen(state: state, timing: GameTiming.instant, graphics: graphics, tilt: tilt),
    ));
    await tester.pump();
    PawnPainter? pawn() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<PawnPainter>()
        .firstOrNull;
    expect(pawn(), isNotNull);
    expect(find.byType(TokenDisc), findsNothing);

    await tester.tap(find.bySemanticsLabel('Roll the die'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Pause').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Performance'));
    await tester.tap(find.text('Performance'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(graphics.mode, GraphicsMode.performance);
    expect(find.text('Tilt effect'), findsNothing);
    expect(pawn(), isNull);
    expect(tilt.running, isFalse);

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
