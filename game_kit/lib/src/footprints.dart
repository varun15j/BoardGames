import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'graphics.dart';

/// One print left on the board. Positions are in cell units.
class Footprint {
  Footprint({
    required this.position,
    required this.angle,
    required this.leftFoot,
    required this.color,
    required this.born,
  });

  Offset position;
  double angle;
  bool leftFoot;
  Color color;
  Duration born;
}

/// How long prints live and how many may be on screen.
class FootprintStyle {
  const FootprintStyle({required this.life, required this.maxAlive, required this.dots});

  static const optimized = FootprintStyle(life: Duration(milliseconds: 1800), maxAlive: 12, dots: false);
  static const performance = FootprintStyle(life: Duration(milliseconds: 1100), maxAlive: 6, dots: true);

  static FootprintStyle of(GraphicsQuality q) => q == GraphicsQuality.optimized ? optimized : performance;

  final Duration life;
  final int maxAlive;

  /// Simple round dots instead of shoe prints.
  final bool dots;
}

/// Even-numbered steps use the left foot, odd ones the right, like walking.
bool isLeftFoot(int stepNumber) => stepNumber.isEven;

/// Where a print goes: [landing] shifted to the left or right of the
/// direction of travel by [sideways] cells.
Offset footprintOffset(Offset landing, Offset direction, bool leftFoot, {double sideways = 0.2}) {
  final d = direction.distance == 0 ? const Offset(0, -1) : direction / direction.distance;
  // Screen coordinates: y grows downward, so (dy, -dx) is the walker's left.
  final left = Offset(d.dy, -d.dx);
  return landing + left * (leftFoot ? sideways : -sideways);
}

/// Opacity of a print of the given [age]: solid for the first 60% of its
/// life, then fading to nothing.
double footprintOpacity(Duration age, Duration life) {
  final t = age.inMicroseconds / life.inMicroseconds;
  if (t < 0 || t >= 1) return 0;
  return t <= 0.6 ? 1 : 1 - (t - 0.6) / 0.4;
}

/// Quick scale-in as the foot lands.
double footprintScale(Duration age) {
  final t = (age.inMilliseconds / 140).clamp(0.0, 1.0);
  return 0.4 + 0.6 * Curves.easeOutBack.transform(t);
}

/// The prints currently on the board. Expired and surplus prints are reused,
/// so the list never grows past the cap.
class FootprintTrail extends ChangeNotifier {
  FootprintTrail({this.style = FootprintStyle.optimized});

  FootprintStyle style;
  final List<Footprint> prints = [];
  final List<Footprint> _spare = [];

  bool get isEmpty => prints.isEmpty;

  void add({
    required Offset landing,
    required Offset direction,
    required int stepNumber,
    required Color color,
    required Duration now,
  }) {
    final left = isLeftFoot(stepNumber);
    while (prints.length >= style.maxAlive) {
      _spare.add(prints.removeAt(0));
    }
    final position = footprintOffset(landing, direction, left);
    // The print's toe points the way the walker is going.
    final angle = math.atan2(direction.dx, -direction.dy);
    final print = _spare.isEmpty
        ? Footprint(position: position, angle: angle, leftFoot: left, color: color, born: now)
        : (_spare.removeLast()
          ..position = position
          ..angle = angle
          ..leftFoot = left
          ..color = color
          ..born = now);
    prints.add(print);
    notifyListeners();
  }

  /// Drops prints older than their life.
  void expire(Duration now) {
    while (prints.isNotEmpty && now - prints.first.born >= style.life) {
      _spare.add(prints.removeAt(0));
    }
  }
}

/// Draws a [FootprintTrail] over a board whose cells are [unit] pixels. Call
/// [FootprintLayerState.step] to leave a print. Ticks only while prints exist.
class FootprintLayer extends StatefulWidget {
  const FootprintLayer({super.key, required this.unit, required this.quality});
  final double unit;
  final GraphicsQuality quality;

  @override
  State<FootprintLayer> createState() => FootprintLayerState();
}

class FootprintLayerState extends State<FootprintLayer> with SingleTickerProviderStateMixin {
  late final FootprintTrail trail = FootprintTrail(style: FootprintStyle.of(widget.quality));
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<Duration> _clock = ValueNotifier(Duration.zero);
  Duration _offset = Duration.zero;

  @override
  void didUpdateWidget(FootprintLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    trail.style = FootprintStyle.of(widget.quality);
  }

  void step({required Offset landing, required Offset direction, required int stepNumber, required Color color}) {
    trail.add(landing: landing, direction: direction, stepNumber: stepNumber, color: color, now: _clock.value);
    if (!_ticker.isActive) {
      _offset = _clock.value;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    _clock.value = _offset + elapsed;
    trail.expire(_clock.value);
    if (trail.isEmpty) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    trail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: FootprintPainter(trail: trail, clock: _clock, unit: widget.unit),
        ),
      ),
    );
  }
}

class FootprintPainter extends CustomPainter {
  FootprintPainter({required this.trail, required this.clock, required this.unit})
      : super(repaint: Listenable.merge([trail, clock]));

  final FootprintTrail trail;
  final ValueNotifier<Duration> clock;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final style = trail.style;
    for (final p in trail.prints) {
      final age = clock.value - p.born;
      final opacity = footprintOpacity(age, style.life);
      if (opacity <= 0) continue;
      final fill = Paint()..color = p.color.withValues(alpha: opacity);
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: opacity * 0.9);
      canvas.save();
      canvas.translate(p.position.dx * unit, p.position.dy * unit);
      if (style.dots) {
        canvas.drawCircle(Offset.zero, unit * 0.14, fill);
        canvas.drawCircle(Offset.zero, unit * 0.14, rim);
      } else {
        canvas.rotate(p.angle);
        final s = unit * footprintScale(age);
        final shoe = shoePrintPath(s, p.leftFoot);
        canvas.drawPath(shoe, rim);
        canvas.drawPath(shoe, fill);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FootprintPainter old) => old.unit != unit || old.trail != trail;
}

/// A shoe print about half a cell long, toe pointing up: sole plus heel.
Path shoePrintPath(double unit, bool leftFoot) {
  final side = leftFoot ? 1.0 : -1.0;
  final sole = Path()
    ..moveTo(-0.10 * unit, 0.04 * unit)
    ..cubicTo(-0.17 * unit, -0.12 * unit, -0.12 * unit, -0.29 * unit, 0.02 * side * unit, -0.29 * unit)
    ..cubicTo(0.15 * unit, -0.28 * unit, 0.15 * unit, -0.10 * unit, 0.09 * unit, 0.04 * unit)
    ..close();
  return sole
    ..addOval(Rect.fromCenter(center: Offset(0, 0.16 * unit), width: 0.17 * unit, height: 0.16 * unit));
}
