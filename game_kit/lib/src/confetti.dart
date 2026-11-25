import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Falling confetti in the given colours. Plays once (~2.8 s).
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.colors, this.count = 140});
  final List<Color> colors;
  final int count;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _Particle {
  _Particle(math.Random r, this.color)
      : x = 0.5 + (r.nextDouble() - 0.5) * 0.3,
        vx = (r.nextDouble() - 0.5) * 1.1,
        vy = -(r.nextDouble() * 1.1 + 0.35),
        rot = r.nextDouble() * math.pi,
        vr = (r.nextDouble() - 0.5) * 12,
        size = 6 + r.nextDouble() * 8;
  final double x, vx, vy, rot, vr, size;
  final Color color;
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
    ..forward();
  late final List<_Particle> _parts;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _parts = [for (int i = 0; i < widget.count; i++) _Particle(r, widget.colors[i % widget.colors.length])];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_parts, _c.value), size: Size.infinite),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.parts, this.t);
  final List<_Particle> parts;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final time = t * 2.8;
    for (final p in parts) {
      final x = (p.x + p.vx * time * 0.5) * size.width;
      final y = size.height * 0.35 + (p.vy * time + 1.4 * time * time) * size.height * 0.45;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + p.vr * time);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size / 2),
        Paint()..color = p.color.withValues(alpha: (1 - t * t).clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
