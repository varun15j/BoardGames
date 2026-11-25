import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// A tappable die that tumbles for ~900 ms whenever [rollId] changes and
/// then settles on [value]. While [enabled] it glows to invite a tap.
class DieView extends StatefulWidget {
  const DieView({
    super.key,
    required this.value,
    required this.rollId,
    required this.color,
    this.enabled = false,
    this.onTap,
    this.reduceMotion = false,
    this.size = 78,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final int rollId;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  final bool reduceMotion;
  final double size;
  final Duration duration;

  @override
  State<DieView> createState() => _DieViewState();
}

class _DieViewState extends State<DieView> with TickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(vsync: this, duration: widget.duration, value: 1);
  late final AnimationController _invite =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    _syncInvite();
  }

  @override
  void didUpdateWidget(DieView old) {
    super.didUpdateWidget(old);
    if (old.rollId != widget.rollId) {
      if (widget.reduceMotion) {
        _roll.value = 1;
      } else {
        _roll.duration = widget.duration;
        _roll.forward(from: 0);
      }
    }
    _syncInvite();
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
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_roll, _invite]),
          builder: (context, _) {
            final glow = widget.enabled ? math.sin(_invite.value * math.pi) : 0.0;
            return Container(
              width: size,
              height: size,
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
              child: _face(size * 0.6),
            );
          },
        ),
      ),
    );
  }

  Widget _face(double s) {
    final t = _roll.value;
    final tumbling = t < 1;
    final eased = Curves.easeOutCubic.transform(t);
    final spin = (1 - eased) * 4 * math.pi;
    // While tumbling show a quick sequence of faces, then land on the result.
    final shown = !tumbling || t > 0.82 ? widget.value : 1 + ((t * 16).floor() * 5 + widget.rollId) % 6;
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.003)
      ..rotateX(spin * 0.8)
      ..rotateY(spin)
      ..scaleByDouble(1 + 0.18 * math.sin(t * math.pi), 1 + 0.18 * math.sin(t * math.pi), 1, 1);
    return Transform(
      alignment: Alignment.center,
      transform: m,
      child: CustomPaint(size: Size.square(s), painter: DiePainter(shown, widget.color)),
    );
  }
}

/// Paints one die face.
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
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFE4EAF5)],
        ).createShader(Offset.zero & size),
    );
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

/// Small helper so games can show the die value in plain text for a11y.
String dieLabel(int value) => 'Rolled $value';

// Re-exported for convenience in tests.
const Color kDieInk = KitColors.ink;
