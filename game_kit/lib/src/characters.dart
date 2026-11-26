import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'avatars/art.dart';
import 'avatars/avatar_store.dart';
import 'creatures.dart';
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

/// Where a creature stands on its 100 x 100 canvas.
const double kGroundY = 90;

/// Pre-rendered pictures, so drawing a resting creature costs one image copy:
/// no clipping, gradients or blur at frame time.
class CharacterSprites {
  CharacterSprites._();

  static final Map<(String, int, PlayerShape, int, bool), ui.Image> _bodies = {};
  static ui.Image? _shadow;

  /// Canvas side relative to the token size, leaving room for the outline.
  static const boxFactor = 1.3;

  static ui.Image _render(int width, int height, void Function(Canvas) paint) {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  /// The key a body is cached under: species (or photo), player and quality.
  static (String, int, PlayerShape, int, bool) keyFor(
    AvatarChoice avatar,
    Color color,
    PlayerShape shape,
    int px,
    bool flat, [
    ui.Image? photo,
  ]) =>
      (avatar.isPhoto ? 'photo:${photo?.hashCode}' : avatar.avatarId, color.toARGB32(), shape, px, flat);

  /// The resting body: species shape edged in the player's colour, standing
  /// on a ring of that colour, with the shape badge.
  static ui.Image body(AvatarChoice avatar, Color color, PlayerShape shape, double size, double ratio, bool flat) {
    final px = (size * boxFactor * ratio).ceil();
    final photo = avatar.isPhoto ? AvatarImages.instance.image(avatar, px.toDouble()) : null;
    return _bodies.putIfAbsent(keyFor(avatar, color, shape, px, flat, photo), () {
      if (_bodies.length > 128) _bodies.clear();
      final silhouette = _render(px, px, (canvas) {
        _toCanvas(canvas, px);
        if (photo != null) {
          _paintMascot(canvas, photo);
        } else {
          final creature = creatureFor(avatar.avatar);
          canvas.translate(50, 50 - creature.lift);
          canvas.scale(creature.scale);
          canvas.translate(-50, -50);
          for (final s in creature.shapes) {
            s.paint(canvas);
          }
        }
      });
      final result = _render(px, px, (canvas) {
        final unit = px / (100 * boxFactor);
        // A sticker edge: the silhouette stamped around itself.
        void edge(double radius, Color tint) {
          final paint = Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn);
          for (var i = 0; i < 8; i++) {
            final a = i * math.pi / 4;
            canvas.drawImage(silhouette, Offset(math.cos(a), math.sin(a)) * radius * unit, paint);
          }
        }

        edge(flat ? 6 : 7.5, KitColors.inkDark);
        edge(flat ? 4 : 5, color);
        canvas.drawImage(silhouette, Offset.zero, Paint());
        _toCanvas(canvas, px);
        // Badge, so players can be told apart without colour.
        const badge = Offset(13, 78);
        canvas.drawCircle(badge, 15, Paint()..color = KitColors.inkDark);
        canvas.drawCircle(badge, 12.5, Paint()..color = color);
        paintShapeMark(canvas, badge, 14, shape, 1);
      });
      silhouette.dispose();
      return result;
    });
  }

  /// Maps the 100 x 100 creature canvas into a [px] sprite.
  static void _toCanvas(Canvas canvas, int px) {
    canvas.scale(px / (100 * boxFactor));
    const margin = 100 * (boxFactor - 1) / 2;
    canvas.translate(margin, margin);
  }

  /// A photo becomes a round mascot with the picture as its face.
  static void _paintMascot(Canvas canvas, ui.Image photo) {
    const face = Rect.fromLTWH(16, 6, 68, 68);
    canvas.drawCircle(face.center, 38, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    canvas.drawImageRect(
      photo,
      Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
      face,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  /// One soft oval, used under every creature.
  static ui.Image get shadow => _shadow ??= _render(128, 56, (canvas) {
        canvas.drawOval(
          const Rect.fromLTWH(12, 12, 104, 32),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.38)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      });

  /// Where the ground point of a creature falls inside its box.
  static Offset footOf(Size box, double size) => Offset(
        box.width / 2,
        (box.height - size) / 2 + size * kGroundY / 100,
      );
}

/// A piece as the creature of the player's avatar. The resting body is one
/// cached picture; only legs, wings and tail are drawn live. The shadow is
/// separate (see [CharacterShadow]).
class CharacterPainter extends CustomPainter {
  CharacterPainter({
    required this.color,
    required this.shape,
    required this.avatar,
    required this.size,
    this.ratio = 1,
    this.pose = LegPose.standing,
    this.dizzy = false,
    this.flat = false,
    this.photoVersion,
  });

  final Color color;
  final PlayerShape shape;
  final AvatarChoice avatar;

  /// Side of the creature's canvas in logical pixels.
  final double size;

  /// Device pixel ratio the sprite is rendered at.
  final double ratio;
  final LegPose pose;
  final bool dizzy;

  /// Performance mode.
  final bool flat;

  /// Changes when a photo finishes loading.
  final Object? photoVersion;

  CreatureBody get creature => avatar.isPhoto
      ? const CreatureBody(motion: Locomotion.walker, shapes: [], limb: ink)
      : creatureFor(avatar.avatar);

  @override
  void paint(Canvas canvas, Size box) {
    final body = creature;
    final sprite = CharacterSprites.body(avatar, color, shape, size, ratio, flat);
    final foot = CharacterSprites.footOf(box, size);

    // The player's ring on the ground.
    final ring = Rect.fromCenter(center: foot, width: size * 0.82, height: size * 0.26);
    canvas.drawOval(ring, Paint()..color = color);
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size * 0.045)
        ..color = KitColors.inkDark,
    );

    // Work in creature coordinates for the moving parts.
    canvas.save();
    canvas.translate((box.width - size) / 2, (box.height - size) / 2);
    canvas.scale(size / 100);
    final swing = pose.left - pose.right;
    final effort = math.max(pose.left.abs(), pose.right.abs());
    if (body.tail != TailKind.none) _tail(canvas, body, swing);
    _legs(canvas, body, effort);
    canvas.restore();

    canvas.save();
    if (body.motion == Locomotion.waddler && swing != 0) {
      canvas.translate(foot.dx, foot.dy);
      canvas.rotate(swing * 0.14);
      canvas.translate(-foot.dx, -foot.dy);
    } else if (body.motion == Locomotion.floater && effort != 0) {
      canvas.translate(0, -effort * size * 0.1);
    }
    canvas.drawImageRect(
      sprite,
      Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
      Offset.zero & box,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.translate((box.width - size) / 2, (box.height - size) / 2);
    canvas.scale(size / 100);
    if (body.wing != null) _wings(canvas, Color(body.wing!), effort);
    if (dizzy) _dizzyEyes(canvas);
    canvas.restore();
  }

  Paint _line(int color, double width) => Paint()
    ..color = Color(color)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  /// A limb with a dark edge, from [a] to [b].
  void _limb(Canvas canvas, Offset a, Offset b, int color, double width) {
    canvas.drawLine(a, b, _line(0xFF0B0F1A, width + 4));
    canvas.drawLine(a, b, _line(color, width));
  }

  void _foot(Canvas canvas, Offset at, int color, [double w = 15, double h = 9]) {
    final rect = Rect.fromCenter(center: at, width: w, height: h);
    canvas.drawOval(rect.inflate(2), Paint()..color = KitColors.inkDark);
    canvas.drawOval(rect, Paint()..color = Color(color));
  }

  void _legs(Canvas canvas, CreatureBody body, double effort) {
    switch (body.motion) {
      case Locomotion.floater:
        // A little thrust under it while moving.
        if (effort > 0) {
          canvas.drawOval(
            Rect.fromCenter(center: const Offset(50, 86), width: 22, height: 10 + effort * 16),
            Paint()..color = const Color(0xCCFFAD00),
          );
        }
      case Locomotion.walker:
        for (final (side, lift) in [(-1.0, pose.left), (1.0, pose.right)]) {
          final up = math.max(0.0, lift);
          final end = Offset(50 + side * 14 + lift * side * 9, kGroundY - 2 - up * 16);
          _limb(canvas, Offset(50 + side * 11, 68), end, body.limb, 8);
          _foot(canvas, end + Offset(side * 3, 1), body.foot);
          // Arms swing opposite to the legs.
          final swing = side < 0 ? pose.right : pose.left;
          _limb(canvas, Offset(50 + side * 22, 54), Offset(50 + side * 40, 64 - swing * 14), body.limb, 6);
        }
      case Locomotion.waddler:
        for (final (side, lift) in [(-1.0, pose.left), (1.0, pose.right)]) {
          final up = math.max(0.0, lift);
          final end = Offset(50 + side * 14, kGroundY - 1 - up * 12);
          _limb(canvas, Offset(50 + side * 12, 76), end, body.limb, 7);
          _foot(canvas, end + const Offset(0, 1), body.foot, 18, 9);
        }
      case Locomotion.quadruped:
        // Diagonal pairs move together, like a trotting animal.
        const xs = [22.0, 34.0, 52.0, 64.0];
        final lifts = [pose.left, pose.right, pose.right, pose.left];
        for (var i = 0; i < 4; i++) {
          final up = math.max(0.0, lifts[i]);
          final end = Offset(xs[i] + lifts[i] * 7, kGroundY - 2 - up * 13);
          _limb(canvas, Offset(xs[i], 68), end, body.limb, 8);
          _foot(canvas, end + const Offset(1, 1), body.foot, 11, 7);
        }
      case Locomotion.hopper:
        // Back legs fold at rest and stretch out in the jump.
        for (final side in [-1.0, 1.0]) {
          final hip = Offset(50 + side * 22, 68);
          final knee = Offset(50 + side * (44 - effort * 12), 66 + effort * 14);
          final end = Offset(50 + side * (34 - effort * 8), kGroundY - 2 + effort * 6);
          _limb(canvas, hip, knee, body.limb, 12);
          _limb(canvas, knee, end, body.limb, 9);
          _foot(canvas, end + Offset(side * 4, 1), body.foot, 20, 9);
        }
    }
  }

  void _tail(Canvas canvas, CreatureBody body, double swing) {
    canvas.save();
    canvas.translate(18, 62);
    canvas.rotate(swing * 0.45);
    final color = body.tailColor;
    final path = Path()..moveTo(0, 0);
    switch (body.tail) {
      case TailKind.long:
        path.cubicTo(-20, -2, -4, -28, -16, -40);
        canvas.drawPath(path, _line(0xFF0B0F1A, 12));
        canvas.drawPath(path, _line(color, 8));
      case TailKind.short:
        _limb(canvas, Offset.zero, const Offset(-11, -12), color, 9);
      case TailKind.bushy:
        _foot(canvas, const Offset(-10, -14), color, 24, 38);
        _foot(canvas, const Offset(-13, -28), 0xFFFFFFFF, 14, 15);
      case TailKind.tuft:
        path.quadraticBezierTo(-18, -4, -14, -28);
        canvas.drawPath(path, _line(0xFF0B0F1A, 9));
        canvas.drawPath(path, _line(0xFFFFC857, 5));
        _foot(canvas, const Offset(-14, -30), color, 15, 18);
      case TailKind.spiky:
        path.cubicTo(-18, 6, -22, -12, -14, -30);
        canvas.drawPath(path, _line(0xFF0B0F1A, 14));
        canvas.drawPath(path, _line(color, 10));
        canvas.drawPath(
          Path()..addPolygon(const [Offset(-22, -28), Offset(-12, -44), Offset(-6, -28)], true),
          Paint()..color = const Color(0xFFFFD25A),
        );
      case TailKind.none:
        break;
    }
    canvas.restore();
  }

  void _wings(Canvas canvas, Color color, double flap) {
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(50 + side * 27, 46);
      canvas.rotate(-side * (0.15 + flap * 1.1));
      _foot(canvas, Offset(side * 3, 14), color.toARGB32(), 14, 34);
      canvas.restore();
    }
  }

  void _dizzyEyes(Canvas canvas) {
    final paint = _line(0xFF0B0F1A, 3.5);
    for (final x in [38.0, 62.0]) {
      final c = Offset(x, 38);
      canvas.drawCircle(c, 9, Paint()..color = Colors.white);
      canvas.drawLine(c + const Offset(-5, -5), c + const Offset(5, 5), paint);
      canvas.drawLine(c + const Offset(5, -5), c + const Offset(-5, 5), paint);
    }
  }

  @override
  bool shouldRepaint(CharacterPainter old) =>
      old.color != color ||
      old.shape != shape ||
      old.avatar != avatar ||
      old.size != size ||
      old.ratio != ratio ||
      old.pose != pose ||
      old.dizzy != dizzy ||
      old.flat != flat ||
      old.photoVersion != photoVersion;
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
  });

  final Color color;
  final PlayerShape shape;
  final AvatarChoice avatar;
  final double size;
  final LegPose pose;
  final bool dizzy;
  final bool flat;

  static double boxFor(double size) => size * CharacterSprites.boxFactor;

  /// Performance mode renders at up to 2x; optimized at the screen's ratio.
  static double ratioFor(double devicePixelRatio, bool flat) =>
      flat ? math.min(devicePixelRatio, 2) : devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    final ratio = ratioFor(MediaQuery.maybeDevicePixelRatioOf(context) ?? 1, flat);
    Widget paint(Object? photo) => CustomPaint(
          size: Size.square(boxFor(size)),
          painter: CharacterPainter(
            color: color,
            shape: shape,
            avatar: avatar,
            size: size,
            ratio: ratio,
            pose: pose,
            dizzy: dizzy,
            flat: flat,
            photoVersion: photo,
          ),
        );
    if (!avatar.isPhoto) return paint(null);
    return ListenableBuilder(
      listenable: AvatarImages.instance,
      builder: (context, _) => paint(AvatarImages.instance.image(avatar, size * CharacterSprites.boxFactor * ratio)),
    );
  }
}

/// The pre-rendered soft shadow for a creature of [size], positioned in the
/// same box as its [CharacterToken].
class CharacterShadow extends StatelessWidget {
  const CharacterShadow({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(CharacterToken.boxFor(size)), painter: _ShadowPainter(size));
}

class _ShadowPainter extends CustomPainter {
  _ShadowPainter(this.size);
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    final image = CharacterSprites.shadow;
    final foot = CharacterSprites.footOf(box, size);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: foot + Offset(size * 0.14, size * 0.03), width: size * 1.2, height: size * 0.5),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => old.size != size;
}
