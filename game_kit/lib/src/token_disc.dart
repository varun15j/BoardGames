import 'package:flutter/material.dart';
import 'theme.dart';

/// Paints a white shape mark centred at [c] inside a box of side [size].
void paintShapeMark(Canvas canvas, Offset c, double size, PlayerShape shape, [double opacity = 0.92]) {
  final p = Paint()..color = Colors.white.withValues(alpha: opacity);
  final h = size / 2;
  switch (shape) {
    case PlayerShape.circle:
      canvas.drawCircle(c, h, p);
    case PlayerShape.square:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: size * 0.9, height: size * 0.9),
          Radius.circular(size * 0.12),
        ),
        p,
      );
    case PlayerShape.triangle:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - h)
          ..lineTo(c.dx + h, c.dy + h * 0.8)
          ..lineTo(c.dx - h, c.dy + h * 0.8)
          ..close(),
        p,
      );
    case PlayerShape.diamond:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - h)
          ..lineTo(c.dx + h, c.dy)
          ..lineTo(c.dx, c.dy + h)
          ..lineTo(c.dx - h, c.dy)
          ..close(),
        p,
      );
  }
}

/// A glossy disc with a white shape mark - the game token.
class TokenDisc extends StatelessWidget {
  const TokenDisc({super.key, required this.color, required this.shape, this.size = 28});
  final Color color;
  final PlayerShape shape;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: TokenDiscPainter(color, shape));
}

class TokenDiscPainter extends CustomPainter {
  TokenDiscPainter(this.color, this.shape);
  final Color color;
  final PlayerShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s / 2;
    final dark = Color.lerp(color, Colors.black, 0.4)!;
    canvas.drawCircle(c + Offset(0, s * 0.08), r * 0.94, Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawCircle(c + Offset(0, s * 0.04), r * 0.94, Paint()..color = dark);
    final body = Rect.fromCircle(center: c - Offset(0, s * 0.03), radius: r * 0.94);
    canvas.drawCircle(
      body.center,
      body.width / 2,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.45),
          radius: 1.0,
          colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.25)!],
          stops: const [0, 0.55, 1],
        ).createShader(body),
    );
    paintShapeMark(canvas, body.center, s * 0.4, shape);
  }

  @override
  bool shouldRepaint(TokenDiscPainter old) => old.color != color || old.shape != shape;
}

/// Avatar-style disc with an initial; used by pods and result rows.
class InitialDisc extends StatelessWidget {
  const InitialDisc({super.key, required this.color, required this.letter, this.size = 32});
  final Color color;
  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.45)!, color],
          stops: const [0, 0.6],
        ),
      ),
      child: Text(letter, style: KitTheme.heading(size: size * 0.42, color: Colors.white)),
    );
  }
}
