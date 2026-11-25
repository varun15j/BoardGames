import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

DeviceCapability _device({int ram = 8000, int sdk = 36, bool low = false}) =>
    DeviceCapability(ramMb: ram, sdkInt: sdk, isLowRam: low);

GraphicsSettings _settings([DeviceCapability? device]) => GraphicsSettings(readDevice: () async => device);

void main() {
  setUp(() {
    KitTheme.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('auto detect', () {
    test('strong phones get 3D', () {
      expect(detectQuality(_device()), GraphicsQuality.optimized);
      // A "6 GB" phone reports a little under 6144 MB.
      expect(detectQuality(_device(ram: 5600, sdk: 29)), GraphicsQuality.optimized);
    });

    test('anything weak or unknown gets 2D', () {
      expect(detectQuality(_device(ram: 3800)), GraphicsQuality.performance);
      expect(detectQuality(_device(sdk: 28)), GraphicsQuality.performance);
      expect(detectQuality(_device(low: true)), GraphicsQuality.performance);
      expect(detectQuality(null), GraphicsQuality.performance);
    });
  });

  group('downgrade decision', () {
    test('needs a full window of slow frames', () {
      expect(shouldDowngrade(List.filled(149, 40)), isFalse);
      expect(shouldDowngrade(List.filled(150, 40)), isTrue);
      expect(shouldDowngrade(List.filled(300, 12)), isFalse);
    });

    test('a short stutter does not count', () {
      expect(shouldDowngrade([...List.filled(145, 8.0), ...List.filled(5, 120.0)]), isFalse);
    });

    test('only auto mode is downgraded, and it is remembered', () async {
      final s = _settings(_device());
      await s.ensureLoaded();
      expect(s.optimized, isTrue);
      expect(await s.downgradeAuto(), isTrue);
      expect(s.quality, GraphicsQuality.performance);

      final again = _settings(_device());
      await again.ensureLoaded();
      expect(again.optimized, isFalse);

      await again.setMode(GraphicsMode.optimized);
      expect(await again.downgradeAuto(), isFalse);
      expect(again.optimized, isTrue);
    });

    testWidgets('frame monitor downgrades only when allowed', (tester) async {
      Future<(GraphicsSettings, int)> run({required bool allowed}) async {
        SharedPreferences.setMockInitialValues({});
        final s = _settings(_device());
        await s.ensureLoaded();
        var told = 0;
        final m = FrameMonitor(settings: s, onDowngrade: () => told++, canDowngrade: allowed);
        m.addFrames(List.filled(200, 35));
        await Future<void>.delayed(Duration.zero);
        return (s, told);
      }

      await tester.runAsync(() async {
        final (slow, told) = await run(allowed: true);
        expect(slow.optimized, isFalse);
        expect(told, 1);
        final (debug, quiet) = await run(allowed: false);
        expect(debug.optimized, isTrue);
        expect(quiet, 0);
      });
    });
  });

  test('mode and tilt choice persist', () async {
    final s = _settings(_device(ram: 2000));
    await s.ensureLoaded();
    expect(s.mode, GraphicsMode.auto);
    expect(s.tiltEffect, isTrue);
    await s.setMode(GraphicsMode.optimized);
    await s.setTiltEffect(false);

    final next = _settings(_device(ram: 2000));
    await next.ensureLoaded();
    expect(next.mode, GraphicsMode.optimized);
    expect(next.optimized, isTrue);
    expect(next.tiltEffect, isFalse);
  });

  group('tilt', () {
    test('smooths, clamps and drifts back to level', () {
      final f = TiltFilter();
      final first = f.add(0, 2, 0.02);
      expect(first.dx, greaterThan(0));
      expect(first.dx, lessThan(0.1), reason: 'low-pass: no sudden jump');
      for (var i = 0; i < 200; i++) {
        f.add(0, 8, 0.02);
      }
      expect(f.value.dx, lessThanOrEqualTo(1.0));
      expect(f.value.dx, greaterThan(0.9));
      for (var i = 0; i < 600; i++) {
        f.add(0, 0, 0.02);
      }
      expect(f.value.distance, lessThan(0.02));
    });

    test('ignores sensor noise', () {
      final f = TiltFilter();
      for (var i = 0; i < 100; i++) {
        f.add(0.005, -0.005, 0.02);
      }
      expect(f.value, Offset.zero);
    });

    test('controller follows events and goes level when stopped', () async {
      final events = StreamController<GyroscopeEvent>(sync: true);
      final c = TiltController(source: () => events.stream)..start();
      final t0 = DateTime(2026);
      for (var i = 0; i < 20; i++) {
        events.add(GyroscopeEvent(0, 1.5, 0, t0.add(Duration(milliseconds: 20 * i))));
      }
      expect(c.value.dx, greaterThan(0.1));
      c.stop();
      expect(c.value, Offset.zero);
      expect(c.running, isFalse);
      c.dispose();
    });

    test('stays off when there is no sensor', () {
      TiltController.sensorsAvailable = false;
      addTearDown(() => TiltController.sensorsAvailable = true);
      final c = TiltController()..start();
      expect(c.running, isFalse);
      expect(c.value, Offset.zero);
      c.dispose();
    });
  });

  group('die lands on the rolled face', () {
    test('3D geometry, for every face and throw', () {
      for (var value = 1; value <= 6; value++) {
        for (var seed = 0; seed < 25; seed++) {
          expect(DieGeometry.faceToViewer(DieGeometry.orientation(value, 1, seed)), value);
        }
      }
    });

    for (final quality in GraphicsQuality.values) {
      testWidgets('die view in ${quality.name} quality', (tester) async {
        var bounces = 0;
        Widget die(int value, int id) => MaterialApp(
              home: Center(
                child: DieView(
                  value: value,
                  rollId: id,
                  color: KitColors.coral,
                  quality: quality,
                  onBounce: () => bounces++,
                ),
              ),
            );
        await tester.pumpWidget(die(1, 0));
        for (var value = 1; value <= 6; value++) {
          await tester.pumpWidget(die(value, value));
          for (var i = 0; i < 32; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          final state = tester.state<DieViewState>(find.byType(DieView));
          expect(
            quality == GraphicsQuality.performance ? state.shownFace : DieGeometry.faceToViewer(state.orientation),
            value,
          );
        }
        expect(bounces, quality == GraphicsQuality.optimized ? 6 * DieThrow.impacts.length : 0);
        expect(tester.takeException(), isNull);
      });
    }

    test('the throw starts and ends on the table', () {
      expect(DieThrow.height(0), 0);
      expect(DieThrow.height(1), 0);
      expect(DieThrow.height(DieThrow.impacts[0] / 2), closeTo(1, 0.01));
      expect(DieThrow.travel(1), 0);
    });
  });

  testWidgets('player token builds in both qualities', (tester) async {
    for (final quality in GraphicsQuality.values) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: Row(
            children: [
              for (final s in kCornerStyles) PlayerToken(color: s.color, shape: s.shape, size: 40, quality: quality),
            ],
          ),
        ),
      ));
      expect(find.byType(TokenDisc), quality == GraphicsQuality.performance ? findsNWidgets(4) : findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('graphics selector switches mode and shows the tilt switch', (tester) async {
    final s = _settings(_device(ram: 2000));
    await tester.runAsync(s.ensureLoaded);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GraphicsSelector(settings: s))));
    expect(find.text('Tilt effect'), findsNothing);
    await tester.tap(find.text('Optimized'));
    await tester.pumpAndSettle();
    expect(s.mode, GraphicsMode.optimized);
    expect(find.text('Tilt effect'), findsOneWidget);
    expect(find.text('Now showing: Optimized (3D)'), findsOneWidget);
  });
}
