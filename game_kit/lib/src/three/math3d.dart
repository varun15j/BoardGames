/// Small 3D maths for the in-app renderer. World axes: x right, y up,
/// z toward the player.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;

  static const zero = V3(0, 0, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));
  V3 normalized() {
    final l = length;
    return l == 0 ? this : this * (1 / l);
  }

  static V3 lerp(V3 a, V3 b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) => other is V3 && other.x == x && other.y == y && other.z == z;
  @override
  int get hashCode => Object.hash(x, y, z);
  @override
  String toString() => 'V3($x, $y, $z)';
}

/// An affine transform: a 3x3 matrix (rows a, b, c) and a translation.
class Mat {
  const Mat(
    this.a0,
    this.a1,
    this.a2,
    this.b0,
    this.b1,
    this.b2,
    this.c0,
    this.c1,
    this.c2, [
    this.tx = 0,
    this.ty = 0,
    this.tz = 0,
  ]);

  final double a0, a1, a2, b0, b1, b2, c0, c1, c2, tx, ty, tz;

  static const identity = Mat(1, 0, 0, 0, 1, 0, 0, 0, 1);

  static Mat move(double x, double y, double z) => Mat(1, 0, 0, 0, 1, 0, 0, 0, 1, x, y, z);
  static Mat scale(double x, [double? y, double? z]) => Mat(x, 0, 0, 0, y ?? x, 0, 0, 0, z ?? x);

  static Mat rotX(double r) {
    final c = math.cos(r), s = math.sin(r);
    return Mat(1, 0, 0, 0, c, -s, 0, s, c);
  }

  static Mat rotY(double r) {
    final c = math.cos(r), s = math.sin(r);
    return Mat(c, 0, s, 0, 1, 0, -s, 0, c);
  }

  static Mat rotZ(double r) {
    final c = math.cos(r), s = math.sin(r);
    return Mat(c, -s, 0, s, c, 0, 0, 0, 1);
  }

  /// This transform applied after [o] (so `parent * child`).
  Mat operator *(Mat o) => Mat(
        a0 * o.a0 + a1 * o.b0 + a2 * o.c0,
        a0 * o.a1 + a1 * o.b1 + a2 * o.c1,
        a0 * o.a2 + a1 * o.b2 + a2 * o.c2,
        b0 * o.a0 + b1 * o.b0 + b2 * o.c0,
        b0 * o.a1 + b1 * o.b1 + b2 * o.c1,
        b0 * o.a2 + b1 * o.b2 + b2 * o.c2,
        c0 * o.a0 + c1 * o.b0 + c2 * o.c0,
        c0 * o.a1 + c1 * o.b1 + c2 * o.c1,
        c0 * o.a2 + c1 * o.b2 + c2 * o.c2,
        a0 * o.tx + a1 * o.ty + a2 * o.tz + tx,
        b0 * o.tx + b1 * o.ty + b2 * o.tz + ty,
        c0 * o.tx + c1 * o.ty + c2 * o.tz + tz,
      );

  V3 apply(V3 v) => V3(
        a0 * v.x + a1 * v.y + a2 * v.z + tx,
        b0 * v.x + b1 * v.y + b2 * v.z + ty,
        c0 * v.x + c1 * v.y + c2 * v.z + tz,
      );

  /// Direction only (no translation).
  V3 turn(V3 v) => V3(
        a0 * v.x + a1 * v.y + a2 * v.z,
        b0 * v.x + b1 * v.y + b2 * v.z,
        c0 * v.x + c1 * v.y + c2 * v.z,
      );
}

/// A perspective camera looking at the origin from above and in front.
class Camera3 {
  Camera3({this.pitch = 1.03, this.yaw = 0, this.distance = 34}) : view = Mat.rotX(pitch) * Mat.rotY(yaw);

  /// How far down the camera looks, in radians (about 59 degrees).
  final double pitch;
  final double yaw;
  final double distance;
  final Mat view;

  double _scale = 1;
  double _dx = 0;
  double _dy = 0;

  /// Frames the given world points inside a viewport of [width] x [height].
  void fit(Iterable<V3> points, double width, double height, [double fill = 0.98]) {
    _scale = 1;
    _dx = 0;
    _dy = 0;
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (final p in points) {
      final s = project(p);
      l = math.min(l, s.dx);
      r = math.max(r, s.dx);
      t = math.min(t, s.dy);
      b = math.max(b, s.dy);
    }
    final box = Rect.fromLTRB(l, t, r, b);
    _scale = math.min(width / box.width, height / box.height) * fill;
    _dx = width / 2 - box.center.dx * _scale;
    _dy = height / 2 - box.center.dy * _scale;
  }

  /// World point to camera space (x right, y up, z toward the viewer).
  V3 toCamera(V3 world) => view.turn(world);

  /// Camera-space point to screen.
  Offset screen(double x, double y, double z) {
    final s = distance / (distance - z) * _scale;
    return Offset(x * s + _dx, -y * s + _dy);
  }

  Offset project(V3 world) {
    final c = view.turn(world);
    return screen(c.x, c.y, c.z);
  }

  /// Screen pixels per world unit near [world].
  double pixelsPerUnit(V3 world) => distance / (distance - view.turn(world).z) * _scale;
}
