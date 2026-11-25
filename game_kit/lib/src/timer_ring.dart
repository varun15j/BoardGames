import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A ring that drains clockwise as [fraction] falls from 1 to 0.
class TimerRingPainter extends CustomPainter {
  TimerRingPainter({required this.fraction, required this.color, this.strokeWidth = 3.5});
  final double fraction;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withValues(alpha: 0.12),
    );
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(TimerRingPainter old) => old.fraction != fraction || old.color != color;
}
