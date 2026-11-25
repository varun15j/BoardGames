import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'graphics.dart';
import 'theme.dart';

/// A segmented gold-and-white ring that keeps turning around a piece that can
/// move. One turn takes 1.2 s. In performance quality it turns in coarse
/// steps, so it repaints far less often. Only build it for movable pieces.
class MoveRing extends StatefulWidget {
  const MoveRing({super.key, required this.size, required this.quality, this.reduceMotion = false});

  static const turn = Duration(milliseconds: 1200);

  /// Steps per turn in performance quality.
  static const coarseSteps = 16;

  final double size;
  final GraphicsQuality quality;
  final bool reduceMotion;

  @override
  State<MoveRing> createState() => _MoveRingState();
}

class _MoveRingState extends State<MoveRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: MoveRing.turn);
  final ValueNotifier<double> _angle = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _c.addListener(_update);
    _sync();
  }

  void _update() {
    var t = _c.value;
    if (widget.quality == GraphicsQuality.performance) {
      t = (t * MoveRing.coarseSteps).floor() / MoveRing.coarseSteps;
    }
    _angle.value = t * math.pi * 2;
  }

  void _sync() {
    if (widget.reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(MoveRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    _angle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.square(widget.size), painter: MoveRingPainter(_angle)),
      ),
    );
  }
}

class MoveRingPainter extends CustomPainter {
  MoveRingPainter(this.angle) : super(repaint: angle);
  final ValueNotifier<double> angle;

  static const segments = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final width = math.max(3.0, s * 0.11);
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: s / 2 - width / 2 - 1);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const sweep = math.pi * 2 / segments * 0.62;
    // A dark backing keeps the ring readable on white and amber squares.
    for (var i = 0; i < segments; i++) {
      final start = angle.value + i * math.pi * 2 / segments;
      canvas.drawArc(rect, start, sweep, false, base..strokeWidth = width + 2.5..color = const Color(0xE6101A2E));
    }
    for (var i = 0; i < segments; i++) {
      final start = angle.value + i * math.pi * 2 / segments;
      canvas.drawArc(rect, start, sweep, false, base..strokeWidth = width..color = i.isEven ? KitColors.gold : Colors.white);
    }
  }

  @override
  bool shouldRepaint(MoveRingPainter old) => old.angle != angle;
}
