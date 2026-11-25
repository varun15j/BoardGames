import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('footprint logic', () {
    test('feet alternate like walking', () {
      expect([for (var n = 1; n <= 4; n++) isLeftFoot(n)], [false, true, false, true]);
    });

    test('left and right prints sit on opposite sides of the path', () {
      const landing = Offset(5, 5);
      // Walking right (east): the left foot is to the north (smaller y).
      expect(footprintOffset(landing, const Offset(1, 0), true).dy, lessThan(5));
      expect(footprintOffset(landing, const Offset(1, 0), false).dy, greaterThan(5));
      // Walking up the screen: the left foot is to the west.
      expect(footprintOffset(landing, const Offset(0, -1), true).dx, lessThan(5));
    });

    test('solid, then fades out', () {
      const life = Duration(seconds: 2);
      expect(footprintOpacity(Duration.zero, life), 1);
      expect(footprintOpacity(const Duration(milliseconds: 1000), life), 1);
      expect(footprintOpacity(const Duration(milliseconds: 1600), life), closeTo(0.5, 0.01));
      expect(footprintOpacity(life, life), 0);
    });

    test('number alive is capped and objects are reused', () {
      for (final style in [FootprintStyle.optimized, FootprintStyle.performance]) {
        final trail = FootprintTrail(style: style);
        for (var i = 1; i <= 40; i++) {
          trail.add(
            landing: Offset(i.toDouble(), 0),
            direction: const Offset(1, 0),
            stepNumber: i,
            color: KitColors.coral,
            now: Duration(milliseconds: i),
          );
          expect(trail.prints.length, lessThanOrEqualTo(style.maxAlive));
        }
        expect(trail.prints.toSet().length, trail.prints.length);
        trail.expire(const Duration(seconds: 10));
        expect(trail.isEmpty, isTrue);
      }
      expect(FootprintStyle.performance.maxAlive, lessThan(FootprintStyle.optimized.maxAlive));
      expect(FootprintStyle.performance.dots, isTrue);
    });

    for (final quality in GraphicsQuality.values) {
      testWidgets('layer draws and clears prints in ${quality.name} quality', (tester) async {
        final key = GlobalKey<FootprintLayerState>();
        await tester.pumpWidget(MaterialApp(home: FootprintLayer(key: key, unit: 24, quality: quality)));
        key.currentState!.step(
          landing: const Offset(3, 3),
          direction: const Offset(1, 0),
          stepNumber: 1,
          color: KitColors.coral,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(key.currentState!.trail.prints, hasLength(1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 2));
        expect(key.currentState!.trail.isEmpty, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('move ring turns once every 1.2 s in both qualities', (tester) async {
    for (final quality in GraphicsQuality.values) {
      await tester.pumpWidget(MaterialApp(home: Center(child: MoveRing(size: 60, quality: quality))));
      MoveRingPainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<MoveRingPainter>()
          .single;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(painter().angle.value, closeTo(math.pi, 0.45));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  group('contrast (WCAG)', () {
    test('die pips on the face', () {
      expect(_contrast(DiePainter.pipColor, DiePainter.faceColor), greaterThan(15));
      expect(DiePainter.faceColor, Colors.white);
    });

    test('the dark mark edge stands out from every player colour', () {
      for (final s in kCornerStyles) {
        // 3:1 is the AA level for graphics.
        expect(
          math.max(_contrast(KitColors.inkDark, s.color), _contrast(Colors.white, s.color)),
          greaterThan(3),
          reason: s.name,
        );
      }
    });

    test('the front face of the 3D die is pure white', () {
      expect(Die3DPainter.dieFaceColor(const Vec3(0, 0, 1), const Vec3(0, 0, 1)), Colors.white);
    });
  });
}
