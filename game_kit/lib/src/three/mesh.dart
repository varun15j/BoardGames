import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'math3d.dart';

/// A triangle mesh with one colour per triangle. Triangles wind
/// counter-clockwise seen from outside.
class Mesh {
  Mesh(this.points, this.triangles, this.colors);

  final List<V3> points;

  /// Three point indices per triangle.
  final List<int> triangles;

  /// One ARGB colour per triangle.
  final List<int> colors;

  int get triangleCount => colors.length;

  /// Builds a convex solid, turning every triangle to face away from the
  /// solid's middle.
  factory Mesh.convex(List<V3> points, List<int> triangles, int color) {
    var centre = V3.zero;
    for (final p in points) {
      centre = centre + p;
    }
    centre = centre * (1 / points.length);
    final fixed = <int>[];
    for (var i = 0; i < triangles.length; i += 3) {
      final a = points[triangles[i]], b = points[triangles[i + 1]], c = points[triangles[i + 2]];
      final n = (b - a).cross(c - a);
      if (n.length < 1e-9) continue; // a pole's zero-area sliver
      final out = n.dot((a + b + c) * (1 / 3) - centre) >= 0;
      fixed.addAll([triangles[i], triangles[i + (out ? 1 : 2)], triangles[i + (out ? 2 : 1)]]);
    }
    return Mesh(points, fixed, List.filled(fixed.length ~/ 3, color));
  }

  /// A squashed sphere with radii [rx], [ry], [rz].
  factory Mesh.ellipsoid(double rx, double ry, double rz, int color, {int around = 8, int down = 6}) {
    final points = <V3>[
      for (var j = 0; j <= down; j++)
        for (var i = 0; i < around; i++)
          () {
            final lat = math.pi * j / down - math.pi / 2;
            final lon = math.pi * 2 * i / around;
            return V3(rx * math.cos(lat) * math.cos(lon), ry * math.sin(lat), rz * math.cos(lat) * math.sin(lon));
          }(),
    ];
    final tris = <int>[];
    for (var j = 0; j < down; j++) {
      for (var i = 0; i < around; i++) {
        final a = j * around + i, b = j * around + (i + 1) % around;
        tris.addAll([a, b, a + around, b, b + around, a + around]);
      }
    }
    return Mesh.convex(points, tris, color);
  }

  /// A tapered rod from y = 0 (radius [r0]) to y = [height] (radius [r1]).
  factory Mesh.rod(double r0, double r1, double height, int color, {int sides = 6}) {
    final points = <V3>[
      for (final (y, r) in [(0.0, r0), (height, r1)])
        for (var i = 0; i < sides; i++)
          V3(r * math.cos(math.pi * 2 * i / sides), y, r * math.sin(math.pi * 2 * i / sides)),
      const V3(0, 0, 0),
      V3(0, height, 0),
    ];
    final tris = <int>[];
    for (var i = 0; i < sides; i++) {
      final j = (i + 1) % sides;
      tris.addAll([i, j, i + sides, j, j + sides, i + sides]);
      tris.addAll([sides * 2, j, i, sides * 2 + 1, i + sides, j + sides]);
    }
    return Mesh.convex(points, tris, color);
  }

  /// A box centred on x and z, from y = 0 up to [h].
  factory Mesh.box(double w, double h, double d, int color, {int? top}) {
    final x = w / 2, z = d / 2;
    final points = [
      V3(-x, 0, -z), V3(x, 0, -z), V3(x, 0, z), V3(-x, 0, z), //
      V3(-x, h, -z), V3(x, h, -z), V3(x, h, z), V3(-x, h, z),
    ];
    const quads = [
      [4, 5, 6, 7], // top first
      [0, 1, 2, 3], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
    ];
    final mesh = Mesh.convex(points, [for (final q in quads) ...[q[0], q[1], q[2], q[0], q[2], q[3]]], color);
    if (top != null) {
      mesh.colors[0] = top;
      mesh.colors[1] = top;
    }
    return mesh;
  }
}

/// Collects transformed meshes, lights them, sorts far to near and draws
/// them in one call. Buffers are reused from frame to frame.
class TriangleBatch {
  TriangleBatch([int capacity = 512]) {
    _grow(capacity);
  }

  static const _light = V3(-0.4, 0.62, 0.67);

  late Float32List _xy;
  late Int32List _argb;
  late Float64List _depth;
  Float32List _outXy = Float32List(0);
  Int32List _outArgb = Int32List(0);
  int _count = 0;

  /// Triangles that survived culling since the last [clear].
  int get length => _count;

  void clear() => _count = 0;

  void _grow(int capacity) {
    final xy = Float32List(capacity * 6);
    final argb = Int32List(capacity * 3);
    final depth = Float64List(capacity);
    if (_count > 0) {
      xy.setRange(0, _count * 6, _xy);
      argb.setRange(0, _count * 3, _argb);
      depth.setRange(0, _count, _depth);
    }
    _xy = xy;
    _argb = argb;
    _depth = depth;
  }

  /// Adds [mesh] placed by [world], as seen by [camera].
  void add(Mesh mesh, Mat world, Camera3 camera) {
    final toView = camera.view * world;
    final pts = mesh.points;
    final cam = Float64List(pts.length * 3);
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      cam[i * 3] = toView.a0 * p.x + toView.a1 * p.y + toView.a2 * p.z + toView.tx;
      cam[i * 3 + 1] = toView.b0 * p.x + toView.b1 * p.y + toView.b2 * p.z + toView.ty;
      cam[i * 3 + 2] = toView.c0 * p.x + toView.c1 * p.y + toView.c2 * p.z + toView.tz;
    }
    if ((_count + mesh.triangleCount) > _depth.length) _grow((_count + mesh.triangleCount) * 2);
    final tris = mesh.triangles;
    for (var t = 0; t < mesh.triangleCount; t++) {
      final a = tris[t * 3] * 3, b = tris[t * 3 + 1] * 3, c = tris[t * 3 + 2] * 3;
      final ux = cam[b] - cam[a], uy = cam[b + 1] - cam[a + 1], uz = cam[b + 2] - cam[a + 2];
      final vx = cam[c] - cam[a], vy = cam[c + 1] - cam[a + 1], vz = cam[c + 2] - cam[a + 2];
      final nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      // Faces turned away from the viewer are not drawn.
      if (nx * -cam[a] + ny * -cam[a + 1] + nz * (camera.distance - cam[a + 2]) <= 0) continue;
      final length = math.sqrt(nx * nx + ny * ny + nz * nz);
      final lambert = length == 0 ? 0.0 : (nx * _light.x + ny * _light.y + nz * _light.z) / length;
      final shade = 0.58 + 0.46 * math.max(0.0, lambert);
      final color = _shade(mesh.colors[t], shade);
      var k = _count * 6;
      for (final v in [a, b, c]) {
        final p = camera.screen(cam[v], cam[v + 1], cam[v + 2]);
        _xy[k++] = p.dx;
        _xy[k++] = p.dy;
      }
      _argb[_count * 3] = color;
      _argb[_count * 3 + 1] = color;
      _argb[_count * 3 + 2] = color;
      _depth[_count] = cam[a + 2] + cam[b + 2] + cam[c + 2];
      _count++;
    }
  }

  static int _shade(int argb, double k) {
    int channel(int shift) {
      final v = (((argb >> shift) & 0xFF) * k).round();
      return v > 255 ? 255 : v;
    }

    return (argb & 0xFF000000) | (channel(16) << 16) | (channel(8) << 8) | channel(0);
  }

  /// Triangle numbers ordered far to near.
  List<int> order() => List<int>.generate(_count, (i) => i)..sort((a, b) => _depth[a].compareTo(_depth[b]));

  void draw(ui.Canvas canvas, ui.Paint paint) {
    if (_count == 0) return;
    if (_outArgb.length < _count * 3) {
      _outXy = Float32List(_depth.length * 6);
      _outArgb = Int32List(_depth.length * 3);
    }
    var n = 0;
    for (final t in order()) {
      _outXy.setRange(n * 6, n * 6 + 6, _xy, t * 6);
      _outArgb.setRange(n * 3, n * 3 + 3, _argb, t * 3);
      n++;
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(_outXy, 0, _count * 6),
      colors: Int32List.sublistView(_outArgb, 0, _count * 3),
    );
    canvas.drawVertices(vertices, ui.BlendMode.dst, paint);
    vertices.dispose();
  }
}
