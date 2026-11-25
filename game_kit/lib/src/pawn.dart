import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'graphics.dart';
import 'theme.dart';
import 'token_disc.dart';

/// A player piece in either graphics quality: a flat glossy disc in
/// performance mode, a raised 3D pawn with a moving shadow in optimized mode.
///
/// [size] is the diameter of the flat disc; the pawn is built to the same
/// footprint but stands taller, centred in a box of side [boxFor].
class PlayerToken extends StatelessWidget {
  const PlayerToken({
    super.key,
    required this.color,
    required this.shape,
    required this.size,
    required this.quality,
    this.tilt,
  });

  final Color color;
  final PlayerShape shape;
  final double size;
  final GraphicsQuality quality;
  final ValueListenable<Offset>? tilt;

  static double boxFor(double size) => size * 1.6;

  @override
  Widget build(BuildContext context) {
    if (quality == GraphicsQuality.performance) {
      return TokenDisc(color: color, shape: shape, size: size);
    }
    return CustomPaint(
      size: Size.square(boxFor(size)),
      painter: PawnPainter(color: color, shape: shape, size: size, tilt: tilt),
    );
  }
}

/// A glossy pawn: base ring, rounded body, domed head with the shape mark on
/// top. The light is fixed in the world, so as the phone tilts the shadow
/// slides the other way and the head leans a little more than the board.
class PawnPainter extends CustomPainter {
  PawnPainter({required this.color, required this.shape, required this.size, this.tilt}) : super(repaint: tilt);

  final Color color;
  final PlayerShape shape;
  final double size;
  final ValueListenable<Offset>? tilt;

  @override
  void paint(Canvas canvas, Size box) {
    final s = size;
    final t = tilt?.value ?? Offset.zero;
    final foot = box.center(Offset.zero) + Offset(0, s * 0.30);
    final lean = Offset(t.dx * s * 0.12, t.dy * s * 0.09);
    final head = foot + Offset(0, -s * 0.70) + lean;
    final headRadius = s * 0.34;
    final dark = Color.lerp(color, Colors.black, 0.5)!;
    final light = Color.lerp(color, Colors.white, 0.55)!;

    // Cast shadow, opposite to the tilt, plus a tight contact shadow.
    final cast = foot + Offset(s * (0.20 - t.dx * 0.28), s * (0.07 - t.dy * 0.22));
    canvas.drawOval(
      Rect.fromCenter(center: cast, width: s * 1.0, height: s * 0.46),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.09),
    );
    canvas.drawOval(
      Rect.fromCenter(center: foot + Offset(0, s * 0.04), width: s * 0.86, height: s * 0.36),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Base: a dark edge, a white ring and the coloured top of the plinth.
    Rect base(double w, double h, double dy) => Rect.fromCenter(center: foot + Offset(0, dy), width: s * w, height: s * h);
    canvas.drawOval(base(0.90, 0.40, 0), Paint()..color = dark);
    canvas.drawOval(base(0.84, 0.35, -s * 0.045), Paint()..color = Colors.white);
    canvas.drawOval(base(0.70, 0.28, -s * 0.07), Paint()..color = color);

    // Body: a waisted cone from the plinth up to the neck.
    final neck = head + Offset(0, headRadius * 0.72);
    final body = Path()
      ..moveTo(foot.dx - s * 0.32, foot.dy - s * 0.08)
      ..quadraticBezierTo(neck.dx - s * 0.09, foot.dy - s * 0.30, neck.dx - s * 0.15, neck.dy)
      ..lineTo(neck.dx + s * 0.15, neck.dy)
      ..quadraticBezierTo(neck.dx + s * 0.09, foot.dy - s * 0.30, foot.dx + s * 0.32, foot.dy - s * 0.08)
      ..quadraticBezierTo(foot.dx, foot.dy + s * 0.10, foot.dx - s * 0.32, foot.dy - s * 0.08)
      ..close();
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, s * 0.07)
      ..strokeJoin = StrokeJoin.round
      ..color = dark;
    canvas.drawPath(body, outline);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [light, color, dark],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromLTRB(foot.dx - s * 0.34, neck.dy, foot.dx + s * 0.34, foot.dy)),
    );
    // Ambient occlusion where the head sits on the neck.
    canvas.drawOval(
      Rect.fromCenter(center: neck + Offset(0, s * 0.04), width: s * 0.38, height: s * 0.14),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );

    // Head.
    final headRect = Rect.fromCircle(center: head, radius: headRadius);
    canvas.drawCircle(head, headRadius, outline);
    canvas.drawCircle(
      head,
      headRadius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.35 + t.dx * 0.35, -0.45 + t.dy * 0.35),
          radius: 1.0,
          colors: [light, color, Color.lerp(color, Colors.black, 0.35)!],
          stops: const [0, 0.5, 1],
        ).createShader(headRect),
    );
    // Shape mark on top of the dome.
    paintShapeMark(canvas, head + Offset(0, -headRadius * 0.05), headRadius * 0.98, shape, 0.96);
    // Specular glint.
    canvas.drawOval(
      Rect.fromCenter(
        center: head + Offset(-headRadius * (0.45 - t.dx * 0.2), -headRadius * (0.55 - t.dy * 0.2)),
        width: headRadius * 0.45,
        height: headRadius * 0.28,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(PawnPainter old) =>
      old.color != color || old.shape != shape || old.size != size || old.tilt != tilt;
}
