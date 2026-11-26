/// A real 3D die: a cube with pips, thrown onto the board.
library;

import 'dart:math' as math;

import '../die_3d.dart';
import 'math3d.dart';
import 'mesh.dart';

/// Face normals in the die's own space; opposite faces add up to seven.
const Map<int, V3> kDieFaces = {
  1: V3(0, 1, 0),
  6: V3(0, -1, 0),
  2: V3(0, 0, 1),
  5: V3(0, 0, -1),
  3: V3(1, 0, 0),
  4: V3(-1, 0, 0),
};

/// The turn that puts face [value] on top.
Mat faceUp(int value) => switch (value) {
      1 => Mat.identity,
      6 => Mat.rotX(math.pi),
      2 => Mat.rotX(-math.pi / 2),
      5 => Mat.rotX(math.pi / 2),
      3 => Mat.rotZ(math.pi / 2),
      _ => Mat.rotZ(-math.pi / 2),
    };

/// The face most nearly pointing up under [turn].
int topFace(Mat turn) {
  var best = 1;
  var high = -2.0;
  for (final e in kDieFaces.entries) {
    final y = turn.turn(e.value).y;
    if (y > high) {
      high = y;
      best = e.key;
    }
  }
  return best;
}

/// Where the die is at [progress] 0..1 of a throw from [from] to [rest]. It
/// ends flat on the board with [value] on top.
Mat dieThrowPose(int value, double progress, int seed, V3 from, V3 rest, {double size = 1.5}) {
  final p = progress.clamp(0.0, 1.0);
  final rng = math.Random(seed * 41 + 3);
  final spinDone = (p / DieThrow.settled).clamp(0.0, 1.0);
  final left = math.pow(1 - spinDone, 2).toDouble();
  final turnX = left * (2.5 + rng.nextDouble()) * 2 * math.pi;
  final turnZ = left * (1 + rng.nextDouble()) * 2 * math.pi * (rng.nextBool() ? 1 : -1);
  final yaw = (rng.nextDouble() - 0.5) * 0.7;
  final along = math.min(1.0, p / DieThrow.settled);
  final travel = 1 - (1 - along) * (1 - along);
  final ground = V3.lerp(from, rest, travel);
  final height = DieThrow.height(p) * 4.2;
  return Mat.move(ground.x, ground.y + height + size / 2, ground.z) *
      Mat.rotY(yaw) *
      Mat.rotX(turnX) *
      Mat.rotZ(turnZ) *
      faceUp(value);
}

/// The cube and its pips as solids of side [size].
class DieModel {
  DieModel(this.size) {
    final h = size / 2;
    cube = Mesh.box(size, size, size, 0xFFFFFFFF);
    const pips = {
      1: [4],
      2: [0, 8],
      3: [0, 4, 8],
      4: [0, 2, 6, 8],
      5: [0, 2, 4, 6, 8],
      6: [0, 2, 3, 5, 6, 8],
    };
    final points = <V3>[];
    final triangles = <int>[];
    for (final face in kDieFaces.entries) {
      final n = face.value;
      final u = n.x.abs() > 0.5 ? const V3(0, 0, 1) : const V3(1, 0, 0);
      final v = n.cross(u);
      for (final i in pips[face.key]!) {
        // The cube mesh stands on y = 0, so its middle is at y = h.
        final centre = V3(0, h, 0) + n * (h * 1.012) + u * ((i % 3 - 1) * h * 0.52) + v * ((i ~/ 3 - 1) * h * 0.52);
        final r = h * (face.key == 1 ? 0.28 : 0.19);
        final first = points.length;
        points.add(centre);
        for (var k = 0; k < 8; k++) {
          points.add(centre + u * (math.cos(k * math.pi / 4) * r) + v * (math.sin(k * math.pi / 4) * r));
        }
        for (var k = 0; k < 8; k++) {
          // v is n x u, so this winds counter-clockwise seen from outside.
          triangles.addAll([first, first + 1 + k, first + 1 + (k + 1) % 8]);
        }
      }
    }
    pipMesh = Mesh(points, triangles, List.filled(triangles.length ~/ 3, 0xFF0B0F1A));
  }

  final double size;

  /// Centred on x and z from y = 0; use [centred] to place it by its middle.
  late final Mesh cube;
  late final Mesh pipMesh;

  Mat centred(Mat pose) => pose * Mat.move(0, -size / 2, 0);
}
