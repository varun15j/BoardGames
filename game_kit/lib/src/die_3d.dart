import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A point or direction in 3D. x is right, y is down, z is toward the viewer.
class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x, y, z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) => Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  Vec3 normalized() {
    final l = math.sqrt(dot(this));
    return l == 0 ? this : this * (1 / l);
  }
}

/// A 3x3 rotation matrix.
class Rot3 {
  const Rot3(this.r0, this.r1, this.r2);
  final Vec3 r0, r1, r2;

  static const identity = Rot3(Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1));

  /// Rotation by [angle] radians around [axis].
  factory Rot3.axis(Vec3 axis, double angle) {
    final a = axis.normalized();
    final c = math.cos(angle), s = math.sin(angle), t = 1 - c;
    return Rot3(
      Vec3(t * a.x * a.x + c, t * a.x * a.y - s * a.z, t * a.x * a.z + s * a.y),
      Vec3(t * a.x * a.y + s * a.z, t * a.y * a.y + c, t * a.y * a.z - s * a.x),
      Vec3(t * a.x * a.z - s * a.y, t * a.y * a.z + s * a.x, t * a.z * a.z + c),
    );
  }

  Vec3 apply(Vec3 v) => Vec3(r0.dot(v), r1.dot(v), r2.dot(v));

  /// This rotation applied after [o].
  Rot3 after(Rot3 o) {
    final c0 = apply(Vec3(o.r0.x, o.r1.x, o.r2.x));
    final c1 = apply(Vec3(o.r0.y, o.r1.y, o.r2.y));
    final c2 = apply(Vec3(o.r0.z, o.r1.z, o.r2.z));
    return Rot3(Vec3(c0.x, c1.x, c2.x), Vec3(c0.y, c1.y, c2.y), Vec3(c0.z, c1.z, c2.z));
  }
}

/// Geometry of the six-sided die. Opposite faces add up to seven.
class DieGeometry {
  DieGeometry._();

  static const Map<int, Vec3> normals = {
    1: Vec3(0, 0, 1),
    6: Vec3(0, 0, -1),
    3: Vec3(1, 0, 0),
    4: Vec3(-1, 0, 0),
    2: Vec3(0, -1, 0),
    5: Vec3(0, 1, 0),
  };

  /// Rotation that turns face [value] straight at the viewer.
  static Rot3 faceFront(int value) => switch (value) {
        1 => Rot3.identity,
        6 => Rot3.axis(const Vec3(0, 1, 0), math.pi),
        3 => Rot3.axis(const Vec3(0, 1, 0), -math.pi / 2),
        4 => Rot3.axis(const Vec3(0, 1, 0), math.pi / 2),
        2 => Rot3.axis(const Vec3(1, 0, 0), -math.pi / 2),
        _ => Rot3.axis(const Vec3(1, 0, 0), math.pi / 2),
      };

  /// The slight three-quarter view the resting die is seen from, so two side
  /// faces show and it reads as a solid cube.
  static final Rot3 viewTilt =
      Rot3.axis(const Vec3(1, 0, 0), 0.36).after(Rot3.axis(const Vec3(0, 1, 0), -0.36));

  /// Orientation at [spin] progress (0 = start of the throw, 1 = settled).
  static Rot3 orientation(int value, double spin, int seed) {
    final rng = math.Random(seed * 31 + 7);
    double side() => rng.nextBool() ? 1.0 : -1.0;
    final axis = Vec3(side() * (0.5 + rng.nextDouble()), side() * (0.5 + rng.nextDouble()), side() * 0.6 * rng.nextDouble());
    final turns = (2.5 + rng.nextDouble()) * 2 * math.pi;
    final left = math.pow(1 - spin.clamp(0.0, 1.0), 2.2).toDouble();
    return viewTilt.after(Rot3.axis(axis, turns * left)).after(faceFront(value));
  }

  /// The face most directly turned toward the viewer, ignoring [viewTilt].
  static int faceToViewer(Rot3 r) {
    var best = 1;
    var bestZ = -2.0;
    for (final e in normals.entries) {
      final z = r.apply(e.value).z;
      if (z > bestZ) {
        bestZ = z;
        best = e.key;
      }
    }
    return best;
  }
}

/// Height and timing of the throw. All inputs and outputs are 0..1.
class DieThrow {
  DieThrow._();

  /// Progress points where the die touches down.
  static const List<double> impacts = [0.46, 0.66, 0.78];

  /// By this point the die has stopped turning.
  static const double settled = 0.80;

  /// Height above the table: one high throw and two decaying bounces.
  static double height(double t) {
    double arc(double a, double b, double peak) {
      final u = (t - a) / (b - a);
      return peak * 4 * u * (1 - u);
    }

    if (t <= 0 || t >= impacts.last) return 0;
    if (t < impacts[0]) return arc(0, impacts[0], 1);
    if (t < impacts[1]) return arc(impacts[0], impacts[1], 0.34);
    return arc(impacts[1], impacts[2], 0.11);
  }

  /// How far the die is from its dock toward the landing spot.
  static double travel(double t) {
    if (t <= 0 || t >= 1) return 0;
    if (t < impacts[0]) return Curves.easeOut.transform(t / impacts[0]);
    if (t < 0.9) return 1;
    return 1 - Curves.easeInOut.transform((t - 0.9) / 0.1);
  }

  /// A small rocking wobble just after the last bounce.
  static double wobble(double t) {
    if (t < impacts.last || t >= 0.9) return 0;
    final u = (t - impacts.last) / (0.9 - impacts.last);
    return math.sin(u * math.pi * 3) * (1 - u) * 0.12;
  }
}

/// Paints a lit, rounded, perspective-projected die filling the canvas.
class Die3DPainter extends CustomPainter {
  Die3DPainter({required this.orientation, required this.accent, this.light = const Offset(-0.35, -0.55)});

  final Rot3 orientation;
  final Color accent;

  /// Where the light comes from, in screen terms.
  final Offset light;

  static const _pips = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  static const double _camera = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final half = size.shortestSide * 0.34;
    Offset project(Vec3 v) {
      final k = _camera / (_camera - v.z);
      return centre + Offset(v.x * k, v.y * k) * half;
    }

    final lightDir = Vec3(light.dx, light.dy, 0.75).normalized();
    final faces = <({int value, Vec3 n, Vec3 u, Vec3 v})>[];
    for (final e in DieGeometry.normals.entries) {
      final local = e.value;
      final u = local.x.abs() > 0.5 ? const Vec3(0, 0, 1) : const Vec3(1, 0, 0);
      final v = local.cross(u);
      faces.add((value: e.key, n: orientation.apply(local), u: orientation.apply(u), v: orientation.apply(v)));
    }
    // Visible when the face looks toward the camera.
    final visible = faces.where((f) => f.n.dot(Vec3(0, 0, _camera) - f.n) > 0).toList()
      ..sort((a, b) => a.n.z.compareTo(b.n.z));

    // Rounded edges: a thick round-joined outline under the faces fills the
    // bevel between them.
    for (final f in visible) {
      final shade = 0.5 + 0.5 * math.max(0, f.n.dot(lightDir));
      final edge = _roundedFace(f.n, f.u, f.v, project, 1.0, 0.22);
      canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = half * 0.2
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(const Color(0xFF8C9BC0), const Color(0xFFEFF3FB), shade)!,
      );
    }
    for (final f in visible) {
      final shade = math.max(0.0, f.n.dot(lightDir));
      final path = _roundedFace(f.n, f.u, f.v, project, 0.97, 0.3);
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(light.dx.clamp(-1.0, 1.0), light.dy.clamp(-1.0, 1.0)),
            end: Alignment((-light.dx).clamp(-1.0, 1.0), (-light.dy).clamp(-1.0, 1.0)),
            colors: [
              Color.lerp(const Color(0xFFB4C0DC), Colors.white, 0.25 + 0.75 * shade)!,
              Color.lerp(const Color(0xFF9AA8CA), const Color(0xFFF0F4FC), shade)!,
            ],
          ).createShader(bounds),
      );
      _paintPips(canvas, f.value, f.n, f.u, f.v, project);
    }
  }

  Path _roundedFace(Vec3 n, Vec3 u, Vec3 v, Offset Function(Vec3) project, double extent, double radius) {
    Offset at(double a, double b) => project(n + u * (a * extent) + v * (b * extent));
    final k = 1 - radius;
    final path = Path();
    void move(Offset p) => path.moveTo(p.dx, p.dy);
    void line(Offset p) => path.lineTo(p.dx, p.dy);
    void curve(Offset c, Offset p) => path.quadraticBezierTo(c.dx, c.dy, p.dx, p.dy);
    move(at(-k, -1));
    line(at(k, -1));
    curve(at(1, -1), at(1, -k));
    line(at(1, k));
    curve(at(1, 1), at(k, 1));
    line(at(-k, 1));
    curve(at(-1, 1), at(-1, k));
    line(at(-1, -k));
    curve(at(-1, -1), at(-k, -1));
    return path..close();
  }

  void _paintPips(Canvas canvas, int value, Vec3 n, Vec3 u, Vec3 v, Offset Function(Vec3) project) {
    final one = value == 1;
    final radius = one ? 0.24 : 0.17;
    for (final i in _pips[value]!) {
      final c = n * 1.001 + u * ((i % 3 - 1) * 0.52) + v * ((i ~/ 3 - 1) * 0.52);
      Path disc(double r) {
        final points = [
          for (var k = 0; k < 16; k++)
            project(c + u * (math.cos(k * math.pi / 8) * r) + v * (math.sin(k * math.pi / 8) * r)),
        ];
        return Path()..addPolygon(points, true);
      }

      canvas.drawPath(disc(radius), Paint()..color = one ? accent : const Color(0xFF1B2440));
      canvas.drawPath(
        disc(radius * 0.45),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(Die3DPainter old) => old.orientation != orientation || old.accent != accent || old.light != light;
}
