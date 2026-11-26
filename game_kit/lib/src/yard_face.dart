import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'avatars/avatar_store.dart';
import 'theme.dart';

/// Random blinks: eyes shut for [closed] every 3 to 6 seconds.
class BlinkSchedule {
  BlinkSchedule(this._rng) {
    _next = _gap();
  }

  static const closed = Duration(milliseconds: 120);
  static const minGap = Duration(seconds: 3);
  static const maxGap = Duration(seconds: 6);

  final math.Random _rng;
  late Duration _next;

  /// When the next blink starts.
  Duration get next => _next;

  Duration _gap() =>
      minGap + Duration(milliseconds: _rng.nextInt((maxGap - minGap).inMilliseconds + 1));

  /// Whether the eyes are shut at [now]; schedules the following blink once
  /// the current one is over. [now] must not go backwards.
  bool isClosedAt(Duration now) {
    while (now >= _next + closed) {
      _next = _next + closed + _gap();
    }
    return now >= _next;
  }
}

/// Where the face features go, in cells from the yard's top-left corner.
/// The eyes sit on the top two token spots, the cheeks on the bottom two.
class YardFaceLayout {
  YardFaceLayout._();
  static const yardCells = 6.0;
  static const inset = 0.8;
  static const eyes = [Offset(2, 2), Offset(4, 2)];
  static const cheeks = [Offset(2, 4), Offset(4, 4)];
}

/// The living face painted in a yard: the avatar as a faint watermark, two
/// blinking eyes in the player's colour on the top spots, cheeks and a smile
/// on the bottom ones. The canvas is the whole 6x6 yard.
class YardFacePainter extends CustomPainter {
  YardFacePainter({required this.color, required this.image, required this.closed, this.look = Offset.zero})
      : super(repaint: closed);

  static const watermarkOpacity = 0.3;

  final Color color;
  final ui.Image image;
  final ValueListenable<bool> closed;

  /// Where the pupils glance, each axis -1..1.
  final Offset look;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / YardFaceLayout.yardCells;
    // Matches the white panel the board paints inside each yard.
    final inner = (Offset.zero & size).deflate(2).deflate(YardFaceLayout.inset * u);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(inner, Radius.circular(u * 0.7)));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      inner,
      Paint()
        ..color = const Color.fromRGBO(0, 0, 0, watermarkOpacity)
        ..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    final dark = Color.lerp(color, KitColors.inkDark, 0.55)!;
    Paint line(double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = dark;

    for (final e in YardFaceLayout.eyes) {
      final c = e * u;
      final r = u * 0.62;
      if (closed.value) {
        canvas.drawCircle(c, r, Paint()..color = color);
        canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.62), 0.35, math.pi - 0.7, false, line(u * 0.13));
      } else {
        canvas.drawCircle(c, r, Paint()..color = Colors.white);
        final iris = c + Offset(look.dx * r * 0.22, look.dy * r * 0.22);
        canvas.drawCircle(iris, r * 0.6, Paint()..color = color);
        canvas.drawCircle(iris, r * 0.28, Paint()..color = KitColors.inkDark);
        canvas.drawCircle(iris + Offset(-r * 0.18, -r * 0.18), r * 0.12, Paint()..color = Colors.white);
      }
      canvas.drawCircle(c, r, line(u * 0.1));
    }
    for (final k in YardFaceLayout.cheeks) {
      final c = k * u;
      canvas.drawCircle(c, u * 0.55, Paint()..color = color.withValues(alpha: 0.5));
      canvas.drawCircle(c, u * 0.55, line(u * 0.07));
    }
    // A smile between the cheeks.
    canvas.drawArc(
      Rect.fromCenter(center: Offset(3 * u, 3.9 * u), width: u * 0.95, height: u * 0.9),
      0.35,
      math.pi - 0.7,
      false,
      line(u * 0.13),
    );
  }

  @override
  bool shouldRepaint(YardFacePainter old) => old.color != color || old.image != image || old.look != look;
}

/// A [YardFacePainter] for a choice of avatar.
class YardFace extends StatelessWidget {
  const YardFace({
    super.key,
    required this.color,
    required this.avatar,
    required this.closed,
    required this.size,
    this.look = Offset.zero,
    this.flat = false,
  });

  final Color color;
  final AvatarChoice avatar;
  final ValueListenable<bool> closed;
  final double size;
  final Offset look;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final pixels = size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1);
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: AvatarImages.instance,
        builder: (context, _) => CustomPaint(
          size: Size.square(size),
          painter: YardFacePainter(
            color: color,
            image: AvatarImages.instance.image(avatar, flat ? 128 : pixels),
            closed: closed,
            look: look,
          ),
        ),
      ),
    );
  }
}
