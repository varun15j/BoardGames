import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'die_3d.dart';
import 'graphics.dart';

/// A tappable 3D die. Whenever [rollId] changes it pops up toward the viewer,
/// is thrown [throwHeight] pixels up the screen, tumbles, bounces and settles
/// on [value], then returns to its dock. While [enabled] it glows to invite a
/// tap. The result is decided by the caller; this widget only presents it.
class DieView extends StatefulWidget {
  const DieView({
    super.key,
    required this.value,
    required this.rollId,
    required this.color,
    this.enabled = false,
    this.onTap,
    this.onBounce,
    this.tilt,
    this.quality = GraphicsQuality.optimized,
    this.reduceMotion = false,
    this.size = 78,
    this.throwHeight = 220,
    this.duration,
  });

  static const rollDuration = Duration(milliseconds: 1400);
  static const flatDuration = Duration(milliseconds: 900);
  static const reducedDuration = Duration(milliseconds: 260);

  final int value;
  final int rollId;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  /// Called each time the thrown die hits the table.
  final VoidCallback? onBounce;

  /// Device tilt in -1..1; moves the light and the contact shadow.
  final ValueListenable<Offset>? tilt;
  final GraphicsQuality quality;
  final bool reduceMotion;
  final double size;
  final double throwHeight;

  /// Overrides the default roll length for the quality.
  final Duration? duration;

  bool get flat => quality == GraphicsQuality.performance;
  Duration get rollTime =>
      reduceMotion ? reducedDuration : duration ?? (flat ? flatDuration : rollDuration);

  @override
  State<DieView> createState() => DieViewState();
}

class DieViewState extends State<DieView> with TickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(vsync: this, duration: widget.rollTime, value: 1)
    ..addListener(_checkImpacts);
  late final AnimationController _invite =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  int _impacts = 0;

  /// The face drawn by the flat (2D) die: a quick shuffle, then the result.
  int get shownFace {
    final t = _roll.value;
    if (widget.reduceMotion || t > 0.82) return widget.value;
    return 1 + ((t * 16).floor() * 5 + widget.rollId) % 6;
  }

  /// The orientation currently drawn; the face toward the viewer is the
  /// result once the roll is over.
  Rot3 get orientation =>
      DieGeometry.orientation(widget.value, widget.reduceMotion ? 1 : _roll.value / DieThrow.settled, widget.rollId);

  @override
  void initState() {
    super.initState();
    _syncInvite();
  }

  @override
  void didUpdateWidget(DieView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rollId != widget.rollId) {
      _impacts = 0;
      _roll.duration = widget.rollTime;
      _roll.forward(from: 0);
    }
    _syncInvite();
  }

  void _checkImpacts() {
    if (widget.reduceMotion || widget.flat) return;
    while (_impacts < DieThrow.impacts.length && _roll.value >= DieThrow.impacts[_impacts]) {
      _impacts++;
      widget.onBounce?.call();
    }
  }

  void _syncInvite() {
    if (widget.enabled && !widget.reduceMotion) {
      if (!_invite.isAnimating) _invite.repeat();
    } else {
      _invite.stop();
      _invite.value = 0;
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    _invite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.enabled ? 'Roll the die' : 'Die showing ${widget.value}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_roll, _invite, widget.tilt]),
            builder: (context, _) => widget.flat ? _flatFrame(size) : _frame(size),
          ),
        ),
      ),
    );
  }

  /// Performance mode: a simple in-place tumble with one flat face.
  Widget _flatFrame(double size) {
    final t = _roll.value;
    final spin = widget.reduceMotion ? 0.0 : (1 - Curves.easeOutCubic.transform(t)) * 4 * math.pi;
    final glow = widget.enabled ? math.sin(_invite.value * math.pi) : 0.0;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.31),
        color: widget.color.withValues(alpha: 0.30),
        border: Border.all(color: widget.color, width: 2),
        boxShadow: [
          if (widget.enabled)
            BoxShadow(color: widget.color.withValues(alpha: 0.7 * (1 - glow)), spreadRadius: 10 * glow),
        ],
      ),
      child: Transform.rotate(
        angle: spin,
        child: CustomPaint(size: Size.square(size * 0.6), painter: DiePainter(shownFace, widget.color)),
      ),
    );
  }

  Widget _frame(double size) {
    final t = _roll.value;
    final thrown = !widget.reduceMotion && t < 1;
    final h = thrown ? DieThrow.height(t) : 0.0;
    final travel = thrown ? DieThrow.travel(t) : 0.0;
    final tilt = widget.tilt?.value ?? Offset.zero;
    final glow = widget.enabled ? math.sin(_invite.value * math.pi) : 0.0;

    // The die grows as it leaves the table toward the viewer.
    final ground = Offset(thrown ? size * 0.35 * math.sin(travel * math.pi / 2) : 0, -widget.throwHeight * travel);
    final lift = Offset(0, -h * size * 1.25);
    final scale = 1 + 0.45 * travel + 0.9 * h;
    final light = Offset(-0.35 + tilt.dx * 0.6, -0.55 + tilt.dy * 0.6);

    // Contact shadow: smaller and fainter the higher the die is.
    final shadowSize = size * 0.74 * (1 + 0.45 * travel) * (1 - 0.45 * h);
    final shadowShift = Offset(size * (0.06 - tilt.dx * 0.16 + h * 0.25), size * (0.2 - tilt.dy * 0.16 + h * 0.2));

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // The dock it is thrown from.
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.31),
            color: widget.color.withValues(alpha: 0.30),
            border: Border.all(color: widget.color, width: 2),
            boxShadow: [
              if (widget.enabled)
                BoxShadow(color: widget.color.withValues(alpha: 0.7 * (1 - glow)), spreadRadius: 10 * glow),
            ],
          ),
        ),
        Transform.translate(
          offset: ground + shadowShift,
          child: Container(
            width: shadowSize,
            height: shadowSize * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(shadowSize / 2, shadowSize * 0.3)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5 - 0.3 * h), blurRadius: 6 + 18 * h),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: ground + lift,
          child: Transform.rotate(
            angle: thrown ? DieThrow.wobble(t) : 0,
            child: Transform.scale(
              scale: scale,
              child: CustomPaint(
                size: Size.square(size * 0.96),
                painter: Die3DPainter(orientation: orientation, accent: widget.color, light: light),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints one flat die face (performance mode).
class DiePainter extends CustomPainter {
  DiePainter(this.value, this.accent);
  final int value;
  final Color accent;

  static const _pips = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.22));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFF4F7FD));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFCCD6E8),
    );
    final pad = size.width * 0.2;
    final step = (size.width - pad * 2) / 2;
    for (final i in _pips[value.clamp(1, 6)]!) {
      final c = Offset(pad + (i % 3) * step, pad + (i ~/ 3) * step);
      final one = value == 1;
      canvas.drawCircle(c, size.width * (one ? 0.11 : 0.085), Paint()..color = one ? accent : const Color(0xFF1B2440));
    }
  }

  @override
  bool shouldRepaint(DiePainter old) => old.value != value || old.accent != accent;
}
