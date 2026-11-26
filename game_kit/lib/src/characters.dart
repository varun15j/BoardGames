import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'avatars/avatar_store.dart';
import 'theme.dart';
import 'token_disc.dart';

/// How high each leg and arm is, each -1..1 (0 = standing).
class LegPose {
  const LegPose(this.left, this.right);
  static const standing = LegPose(0, 0);
  final double left;
  final double right;

  @override
  bool operator ==(Object other) => other is LegPose && other.left == left && other.right == right;
  @override
  int get hashCode => Object.hash(left, right);
}

/// The walking pose during one hop. [progress] runs 0..1 over the hop; legs
/// only move while it is strictly between the ends, and [leftLeads]
/// alternates from one square to the next. [flat] gives the 2-frame swing
/// used in performance mode.
LegPose legPose(double progress, bool leftLeads, {bool flat = false}) {
  if (progress <= 0 || progress >= 1) return LegPose.standing;
  final swing = flat ? (progress < 0.5 ? 1.0 : -1.0) : math.sin(progress * math.pi);
  final lead = swing;
  final trail = -swing * 0.35;
  return leftLeads ? LegPose(lead, trail) : LegPose(trail, lead);
}

/// A piece as a little character: the player's avatar (or photo) as its face,
/// a body and two legs in the player's colour, and the shape mark as a badge.
class CharacterPainter extends CustomPainter {
  CharacterPainter({
    required this.color,
    required this.shape,
    required this.face,
    required this.size,
    this.pose = LegPose.standing,
    this.dizzy = false,
    this.flat = false,
    this.tilt,
  }) : super(repaint: tilt);

  final Color color;
  final PlayerShape shape;
  final ui.Image face;

  /// Footprint diameter; the character stands a bit taller than this.
  final double size;
  final LegPose pose;
  final bool dizzy;

  /// Performance mode: flat colours, no shadows.
  final bool flat;
  final ValueListenable<Offset>? tilt;

  @override
  void paint(Canvas canvas, Size box) {
    final s = size;
    final t = flat ? Offset.zero : (tilt?.value ?? Offset.zero);
    final foot = box.center(Offset.zero) + Offset(0, s * 0.46);
    final lean = Offset(t.dx * s * 0.12, t.dy * s * 0.08);
    final hip = foot + Offset(0, -s * 0.22);
    final bodyCentre = foot + Offset(0, -s * 0.38) + lean * 0.5;
    final head = foot + Offset(0, -s * 0.86) + lean;
    final headR = s * 0.38;
    final dark = Color.lerp(color, KitColors.inkDark, 0.72)!;

    if (!flat) {
      final cast = foot + Offset(s * (0.16 - t.dx * 0.28), s * (0.02 - t.dy * 0.2));
      canvas.drawOval(
        Rect.fromCenter(center: cast, width: s * 0.9, height: s * 0.32),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.07),
      );
    }

    // Legs and shoes. A leading leg lifts and steps forward.
    for (final (side, lift) in [(-1.0, pose.left), (1.0, pose.right)]) {
      final up = math.max(0.0, lift);
      final start = hip + Offset(side * s * 0.12, 0);
      final end = foot + Offset(side * s * 0.14 + lift * s * 0.12 * side, -up * s * 0.22);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = dark
          ..strokeWidth = s * 0.13
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawOval(
        Rect.fromCenter(center: end + Offset(side * s * 0.03, s * 0.02), width: s * 0.22, height: s * 0.12),
        Paint()..color = KitColors.inkDark,
      );
    }

    // Arms swing opposite to the legs.
    for (final (side, swing) in [(-1.0, pose.right), (1.0, pose.left)]) {
      canvas.drawLine(
        bodyCentre + Offset(side * s * 0.2, -s * 0.06),
        bodyCentre + Offset(side * s * 0.38, s * 0.08 - swing * s * 0.16),
        Paint()
          ..color = dark
          ..strokeWidth = s * 0.1
          ..strokeCap = StrokeCap.round,
      );
    }

    // Body.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: bodyCentre, width: s * 0.54, height: s * 0.42),
      Radius.circular(s * 0.18),
    );
    final fill = Paint()..color = color;
    if (!flat) {
      fill.shader = LinearGradient(
        colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.35)!],
        stops: const [0, 0.5, 1],
      ).createShader(body.outerRect);
    }
    canvas.drawRRect(body, fill);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07
        ..color = dark,
    );

    // Head: the face in a ring of the player's colour.
    canvas.drawCircle(head, headR + s * 0.09, Paint()..color = dark);
    canvas.drawCircle(head, headR + s * 0.055, Paint()..color = color);
    final headRect = Rect.fromCircle(center: head, radius: headR);
    canvas.save();
    canvas.clipPath(Path()..addOval(headRect));
    canvas.drawImageRect(
      face,
      Rect.fromLTWH(0, 0, face.width.toDouble(), face.height.toDouble()),
      headRect,
      Paint()..filterQuality = flat ? FilterQuality.low : FilterQuality.medium,
    );
    canvas.restore();
    if (!flat) {
      canvas.drawOval(
        Rect.fromCenter(
          center: head + Offset(-headR * (0.45 - t.dx * 0.2), -headR * (0.55 - t.dy * 0.2)),
          width: headR * 0.5,
          height: headR * 0.28,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }
    if (dizzy) _dizzyEyes(canvas, head, headR);

    // Shape badge, so colours can be told apart without colour.
    final badge = bodyCentre + Offset(0, s * 0.02);
    paintShapeMark(canvas, badge, s * 0.22, shape, 1);
  }

  void _dizzyEyes(Canvas canvas, Offset head, double r) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.14
      ..color = KitColors.inkDark;
    for (final dx in [-0.36, 0.36]) {
      final c = head + Offset(dx * r, -r * 0.1);
      canvas.drawCircle(c, r * 0.26, Paint()..color = Colors.white);
      final d = r * 0.16;
      canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), paint);
      canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), paint);
    }
  }

  @override
  bool shouldRepaint(CharacterPainter old) =>
      old.color != color ||
      old.shape != shape ||
      old.face != face ||
      old.size != size ||
      old.pose != pose ||
      old.dizzy != dizzy ||
      old.flat != flat;
}

/// A [CharacterPainter] for a choice of avatar; repaints when a photo loads.
class CharacterToken extends StatelessWidget {
  const CharacterToken({
    super.key,
    required this.color,
    required this.shape,
    required this.avatar,
    required this.size,
    this.pose = LegPose.standing,
    this.dizzy = false,
    this.flat = false,
    this.tilt,
  });

  final Color color;
  final PlayerShape shape;
  final AvatarChoice avatar;
  final double size;
  final LegPose pose;
  final bool dizzy;
  final bool flat;
  final ValueListenable<Offset>? tilt;

  static double boxFor(double size) => size * 1.7;

  @override
  Widget build(BuildContext context) {
    final pixels = size * 0.76 * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1);
    return ListenableBuilder(
      listenable: AvatarImages.instance,
      builder: (context, _) => CustomPaint(
        size: Size.square(boxFor(size)),
        painter: CharacterPainter(
          color: color,
          shape: shape,
          // Performance mode uses the small cached image.
          face: AvatarImages.instance.image(avatar, flat ? 64 : pixels),
          size: size,
          pose: pose,
          dizzy: dizzy,
          flat: flat,
          tilt: tilt,
        ),
      ),
    );
  }
}
