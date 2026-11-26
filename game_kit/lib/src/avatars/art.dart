/// A tiny drawing language for the built-in avatars. All coordinates are on a
/// 100 x 100 canvas.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

sealed class Shape {
  const Shape(this.color);
  final int color;
  void paint(Canvas canvas);

  Paint get fill => Paint()..color = Color(color);
  Paint stroke(double width) => Paint()
    ..color = Color(color)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}

/// Circle.
class C extends Shape {
  const C(this.x, this.y, this.r, super.color);
  final double x, y, r;
  @override
  void paint(Canvas canvas) => canvas.drawCircle(Offset(x, y), r, fill);
}

/// Ellipse centred at (x, y).
class E extends Shape {
  const E(this.x, this.y, this.w, this.h, super.color);
  final double x, y, w, h;
  @override
  void paint(Canvas canvas) => canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h), fill);
}

/// Rounded rectangle centred at (x, y), optionally turned by [turn] degrees.
class R extends Shape {
  const R(this.x, this.y, this.w, this.h, this.radius, super.color, [this.turn = 0]);
  final double x, y, w, h, radius, turn;
  @override
  void paint(Canvas canvas) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(turn * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(radius)),
      fill,
    );
    canvas.restore();
  }
}

/// Filled polygon from x, y pairs.
class P extends Shape {
  const P(this.points, super.color);
  final List<double> points;
  @override
  void paint(Canvas canvas) => canvas.drawPath(
        Path()..addPolygon([for (var i = 0; i < points.length; i += 2) Offset(points[i], points[i + 1])], true),
        fill,
      );
}

/// Stroked arc of an ellipse; angles in degrees, 0 is to the right.
class A extends Shape {
  const A(this.x, this.y, this.w, this.h, this.start, this.sweep, super.color, [this.width = 3]);
  final double x, y, w, h, start, sweep, width;
  @override
  void paint(Canvas canvas) => canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        start * math.pi / 180,
        sweep * math.pi / 180,
        false,
        stroke(width),
      );
}

/// Straight line.
class L extends Shape {
  const L(this.x1, this.y1, this.x2, this.y2, super.color, [this.width = 3]);
  final double x1, y1, x2, y2, width;
  @override
  void paint(Canvas canvas) => canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke(width));
}

/// Star with [points] tips.
class S extends Shape {
  const S(this.x, this.y, this.r, super.color, [this.points = 5]);
  final double x, y, r;
  final int points;
  @override
  void paint(Canvas canvas) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isOdd ? r * 0.45 : r;
      final a = -math.pi / 2 + i * math.pi / points;
      final o = Offset(x + rr * math.cos(a), y + rr * math.sin(a));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path..close(), fill);
  }
}

const int ink = 0xFF1B2440;
const int white = 0xFFFFFFFF;
const int pink = 0xFFFF8FA3;

/// Two shiny eyes at height [y], [gap] apart.
List<Shape> eyes(double y, [double gap = 22, double r = 5]) => [
      C(50 - gap / 2, y, r, ink),
      C(50 + gap / 2, y, r, ink),
      C(50 - gap / 2 + r * 0.35, y - r * 0.35, r * 0.35, white),
      C(50 + gap / 2 + r * 0.35, y - r * 0.35, r * 0.35, white),
    ];

Shape smile(double y, [double w = 18]) => A(50, y - w * 0.25, w, w * 0.7, 20, 140, ink, 3.2);

List<Shape> cheeks(double y, [double gap = 40]) =>
    [E(50 - gap / 2, y, 10, 6, 0x88FF7A8A), E(50 + gap / 2, y, 10, 6, 0x88FF7A8A)];
