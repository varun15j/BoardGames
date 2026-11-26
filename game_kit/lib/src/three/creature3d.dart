/// Low-poly creatures built from simple solids on a small joint hierarchy,
/// animated by code. A creature stands about one unit tall at the origin,
/// facing +z.
library;

import 'dart:math' as math;

import '../avatars/catalog.dart';
import '../creatures.dart';
import 'math3d.dart';
import 'mesh.dart';

/// How a creature moves in 3D.
enum Gait3 { quadruped, hopper, flyer, walker, waddler, hoverer }

/// Which model is used; avatars without their own model use the mascot.
enum Species3 { cat, frog, owl, mascot }

Species3 speciesFor(String avatarId) => switch (avatarId) {
      'cat' => Species3.cat,
      'frog' => Species3.frog,
      'owl' => Species3.owl,
      _ => Species3.mascot,
    };

/// The movement style of every avatar, ready for its own model.
Gait3 gaitFor(Avatar avatar) {
  if (avatar.id == 'owl' || avatar.id == 'phoenix') return Gait3.flyer;
  return switch (creatureFor(avatar).motion) {
    Locomotion.quadruped => Gait3.quadruped,
    Locomotion.hopper => Gait3.hopper,
    Locomotion.waddler => Gait3.waddler,
    Locomotion.floater => Gait3.hoverer,
    Locomotion.walker => Gait3.walker,
  };
}

/// What a creature is doing.
enum Action3 { idle, move, knocked, cheer }

/// The moment being drawn: [progress] runs 0..1 through the action, [time]
/// is a free-running clock in seconds for idle motion.
class Anim3 {
  const Anim3({this.action = Action3.idle, this.progress = 0, this.time = 0, this.leftLeads = false});
  final Action3 action;
  final double progress;
  final double time;
  final bool leftLeads;
}

/// Whole-body motion: height off the ground, lean and squash.
class BodyMotion {
  const BodyMotion({this.lift = 0, this.pitch = 0, this.roll = 0, this.spin = 0, this.stretch = 1});
  final double lift;
  final double pitch;
  final double roll;
  final double spin;

  /// Vertical scale; below 1 is a squash.
  final double stretch;
}

/// Angles of the moving joints, in radians.
class JointAngles {
  const JointAngles({
    this.frontLeft = 0,
    this.frontRight = 0,
    this.backLeft = 0,
    this.backRight = 0,
    this.tail = 0,
    this.head = 0,
    this.headTurn = 0,
    this.wings = 0,
    this.throat = 1,
  });
  final double frontLeft, frontRight, backLeft, backRight, tail, head, headTurn, wings, throat;
}

double _arc(double p) => p <= 0 || p >= 1 ? 0 : math.sin(p * math.pi);

/// Squash right at take-off and landing.
double _squash(double p) {
  if (p <= 0 || p >= 1) return 1;
  if (p < 0.15) return 1 - 0.22 * math.sin(p / 0.15 * math.pi);
  if (p > 0.85) return 1 - 0.26 * math.sin((p - 0.85) / 0.15 * math.pi);
  return 1;
}

BodyMotion bodyMotion(Gait3 gait, Anim3 a) {
  final p = a.progress;
  final up = _arc(p);
  switch (a.action) {
    case Action3.knocked:
      return BodyMotion(lift: up * 3.2, spin: p * math.pi * 4, roll: math.sin(p * math.pi * 6) * 0.5);
    case Action3.cheer:
      return BodyMotion(lift: _arc((p * 2) % 1) * 0.9, spin: p * math.pi * 2, stretch: _squash((p * 2) % 1));
    case Action3.idle:
      if (gait == Gait3.hoverer) return BodyMotion(lift: 0.25 + math.sin(a.time * 2.2) * 0.1);
      return BodyMotion(stretch: 1 + math.sin(a.time * 2.4) * 0.018);
    case Action3.move:
      return switch (gait) {
        // A small pounce: nose down as it lands.
        Gait3.quadruped => BodyMotion(lift: up * 0.35, pitch: math.sin(p * math.pi * 2) * 0.16, stretch: _squash(p)),
        // Crouch, a high stretched leap, then a flat landing.
        Gait3.hopper => BodyMotion(lift: up * 1.5, pitch: -math.sin(p * math.pi * 2) * 0.45, stretch: _squash(p)),
        // Up quickly, glide, settle.
        Gait3.flyer => BodyMotion(lift: math.min(1, up * 1.8) * 1.15, pitch: up * 0.22),
        Gait3.walker => BodyMotion(lift: up * 0.45, stretch: _squash(p)),
        Gait3.waddler => BodyMotion(lift: up * 0.22, roll: up * (a.leftLeads ? 0.26 : -0.26)),
        Gait3.hoverer => BodyMotion(lift: 0.25 + up * 0.7, pitch: up * 0.2),
      };
  }
}

JointAngles jointAngles(Gait3 gait, Anim3 a) {
  final t = a.time;
  final moving = a.action == Action3.move;
  final up = _arc(a.progress);
  final lead = a.leftLeads ? 1.0 : -1.0;
  if (a.action == Action3.knocked || a.action == Action3.cheer) {
    final flail = math.sin(a.progress * math.pi * 8);
    return JointAngles(
      frontLeft: flail,
      frontRight: -flail,
      backLeft: -flail,
      backRight: flail,
      tail: flail * 0.6,
      wings: (flail.abs()) * 1.4,
    );
  }
  switch (gait) {
    case Gait3.quadruped:
      // Diagonal pairs swing together.
      final swing = moving ? math.sin(a.progress * math.pi * 2) * 0.8 * lead : 0.0;
      return JointAngles(
        frontLeft: swing,
        backRight: swing,
        frontRight: -swing,
        backLeft: -swing,
        tail: moving ? math.sin(a.progress * math.pi * 2) * 0.7 : math.sin(t * 1.7) * 0.18 + _flick(t),
        head: moving ? up * 0.18 : 0,
      );
    case Gait3.hopper:
      // Back legs kick straight out behind in the leap.
      return JointAngles(
        backLeft: up * 1.7,
        backRight: up * 1.7,
        frontLeft: -up * 0.7,
        frontRight: -up * 0.7,
        throat: moving ? 1 : 1 + math.max(0, math.sin(t * 3.1)) * 0.35,
      );
    case Gait3.flyer:
      return JointAngles(
        wings: moving ? 0.5 + math.sin(a.progress * math.pi * 6) * 0.9 : 0,
        backLeft: up * 0.6,
        backRight: up * 0.6,
        headTurn: moving ? 0 : _look(t),
      );
    case Gait3.waddler:
    case Gait3.walker:
    case Gait3.hoverer:
      final step = moving ? math.sin(a.progress * math.pi * 2) * 0.7 * lead : 0.0;
      return JointAngles(
        backLeft: step,
        backRight: -step,
        frontLeft: -step,
        frontRight: step,
        wings: moving ? up * 0.7 : 0,
        headTurn: moving ? 0 : _look(t) * 0.5,
      );
  }
}

/// Now and then a cat flicks its tail.
double _flick(double t) {
  final phase = t % 4.0;
  return phase < 0.5 ? math.sin(phase * math.pi * 4) * 0.45 : 0;
}

/// An owl looks one way, then the other.
double _look(double t) {
  final phase = (t % 6.0) / 6.0;
  if (phase < 0.12) return math.sin(phase / 0.12 * math.pi / 2) * 0.9;
  if (phase < 0.45) return 0.9;
  if (phase < 0.57) return 0.9 - (phase - 0.45) / 0.12 * 1.8;
  if (phase < 0.88) return -0.9;
  return -0.9 + (phase - 0.88) / 0.12 * 0.9;
}

/// Height of the middle of the mascot's head, and the radius of the picture
/// on it (most of the 0.68-wide head).
const double kMascotHeadHeight = 0.74;
const double kMascotFaceRadius = 0.29;

/// One solid and where it sits.
class Part3 {
  const Part3(this.mesh, this.at);
  final Mesh mesh;
  final Mat at;
}

/// Builds the solids of one species in one colour and level of detail, once,
/// and poses them each frame.
class CreatureModel {
  CreatureModel(this.species, int color, {this.low = false}) : _color = color {
    _build();
  }

  final Species3 species;
  final int _color;
  final bool low;
  final Map<String, Mesh> _m = {};

  Mesh _ball(String key, double x, double y, double z, int color, {bool small = false}) => _m.putIfAbsent(
        key,
        () => Mesh.ellipsoid(x, y, z, color, around: small || low ? 5 : 8, down: small || low ? 4 : 6),
      );
  Mesh _rod(String key, double r0, double r1, double h, int color, [int? sides]) =>
      _m.putIfAbsent(key, () => Mesh.rod(r0, r1, h, color, sides: sides ?? (low ? 4 : 6)));

  static const _white = 0xFFFFFFFF;
  static const _ink = 0xFF14182B;

  void _build() {
    switch (species) {
      case Species3.cat:
        const fur = 0xFFF59E42, pink = 0xFFFF8FA3;
        _ball('body', 0.24, 0.21, 0.34, fur);
        _ball('belly', 0.17, 0.12, 0.25, _white);
        _ball('head', 0.25, 0.22, 0.21, fur);
        _ball('muzzle', 0.12, 0.08, 0.07, _white, small: true);
        _ball('nose', 0.035, 0.028, 0.028, pink, small: true);
        _ball('eye', 0.045, 0.058, 0.035, _ink, small: true);
        _rod('ear', 0.095, 0.004, 0.19, fur, 4);
        _rod('leg', 0.062, 0.055, 0.27, fur);
        _ball('paw', 0.072, 0.045, 0.085, _white, small: true);
        _rod('tail', 0.052, 0.044, 0.21, fur);
        _ball('tip', 0.06, 0.06, 0.06, _white, small: true);
      case Species3.frog:
        const skin = 0xFF4CB944, belly = 0xFFC9EE8A, dark = 0xFF2F8F32;
        _ball('body', 0.34, 0.23, 0.32, skin);
        _ball('throat', 0.23, 0.14, 0.14, belly);
        _ball('eyeball', 0.13, 0.13, 0.12, skin);
        _ball('white', 0.085, 0.09, 0.05, _white, small: true);
        _ball('pupil', 0.04, 0.045, 0.028, _ink, small: true);
        _ball('mouth', 0.2, 0.022, 0.03, dark, small: true);
        _rod('thigh', 0.09, 0.065, 0.26, skin);
        _rod('shin', 0.06, 0.045, 0.26, skin);
        _rod('arm', 0.055, 0.045, 0.22, skin);
        _ball('foot', 0.12, 0.028, 0.13, dark, small: true);
      case Species3.owl:
        const feather = 0xFF9A6A44, pale = 0xFFF0D2A8, wing = 0xFF6E4528, beak = 0xFFFFB000;
        _ball('body', 0.27, 0.33, 0.23, feather);
        _ball('chest', 0.18, 0.2, 0.1, pale);
        _ball('head', 0.28, 0.22, 0.22, feather);
        _ball('disc', 0.11, 0.115, 0.05, _white, small: true);
        _ball('pupil', 0.052, 0.058, 0.03, _ink, small: true);
        _rod('beak', 0.055, 0.004, 0.11, beak, 4);
        _rod('tuft', 0.065, 0.004, 0.17, feather, 4);
        _ball('wing', 0.06, 0.27, 0.15, wing);
        _rod('leg', 0.035, 0.035, 0.14, beak);
        _ball('foot', 0.085, 0.032, 0.11, beak, small: true);
        _ball('tailfeather', 0.13, 0.035, 0.16, wing, small: true);
      case Species3.mascot:
        // A big head for the picture on a short, round body.
        _ball('body', 0.25, 0.2, 0.22, _color);
        _ball('head', 0.34, 0.33, 0.28, _color);
        _rod('leg', 0.075, 0.065, 0.2, _color);
        _rod('arm', 0.055, 0.05, 0.2, _color);
        _ball('foot', 0.1, 0.05, 0.13, _ink, small: true);
    }
    // The player's collar.
    _rod('collar', species == Species3.frog ? 0.3 : 0.2, species == Species3.frog ? 0.28 : 0.18, 0.07, _color, low ? 6 : 10);
  }

  /// The posed solids, in the creature's own space.
  List<Part3> pose(Gait3 gait, Anim3 anim) {
    final body = bodyMotion(gait, anim);
    final j = jointAngles(gait, anim);
    final root = Mat.move(0, body.lift, 0) *
        Mat.rotY(body.spin) *
        Mat.rotZ(body.roll) *
        Mat.rotX(body.pitch) *
        Mat.scale(2 - body.stretch, body.stretch, 2 - body.stretch);
    final out = <Part3>[];
    void put(String mesh, Mat local) => out.add(Part3(_m[mesh]!, root * local));
    // A limb hanging from a joint, swung forward by [angle].
    Mat limb(double x, double y, double z, double angle) => Mat.move(x, y, z) * Mat.rotX(-angle) * Mat.rotX(math.pi);

    switch (species) {
      case Species3.cat:
        for (final (x, z, angle) in [
          (-0.15, 0.2, j.frontLeft),
          (0.15, 0.2, j.frontRight),
          (-0.15, -0.22, j.backLeft),
          (0.15, -0.22, j.backRight),
        ]) {
          final hip = limb(x, 0.33, z, angle);
          put('leg', hip);
          put('paw', hip * Mat.move(0, 0.28, -0.02));
        }
        put('body', Mat.move(0, 0.45, -0.02));
        put('belly', Mat.move(0, 0.36, 0.04));
        put('collar', Mat.move(0, 0.52, 0.2) * Mat.rotX(0.9));
        final head = Mat.move(0, 0.72, 0.3) * Mat.rotY(j.headTurn) * Mat.rotX(j.head);
        put('head', head);
        put('muzzle', head * Mat.move(0, -0.07, 0.17));
        put('nose', head * Mat.move(0, -0.035, 0.24));
        for (final s in [-1.0, 1.0]) {
          put('eye', head * Mat.move(s * 0.1, 0.035, 0.18));
          put('ear', head * Mat.move(s * 0.14, 0.13, -0.01) * Mat.rotZ(-s * 0.3));
        }
        // A three-piece tail that curls up and sways.
        var joint = Mat.move(0, 0.5, -0.32) * Mat.rotZ(j.tail * 0.6) * Mat.rotX(-0.75);
        for (var i = 0; i < 3; i++) {
          put('tail', joint);
          joint = joint * Mat.move(0, 0.19, 0) * Mat.rotX(0.42) * Mat.rotZ(j.tail * 0.4);
        }
        put('tip', joint);
      case Species3.frog:
        for (final (s, angle) in [(-1.0, j.backLeft), (1.0, j.backRight)]) {
          // Folded beside the body at rest; straight out behind in the air.
          // Each bone starts where the one before ends.
          final e = (angle / 1.7).clamp(0.0, 1.0);
          final thigh = Mat.move(s * 0.24, 0.22, -0.12) * Mat.rotY(-s * 0.3 * (1 - e)) * Mat.rotX(1.4 + 3.0 * e);
          put('thigh', thigh);
          final knee = thigh * Mat.move(0, 0.25, 0);
          // The shin folds back under the thigh, then straightens.
          final shin = knee * Mat.rotX(2.55 * (1 - e));
          put('shin', shin);
          put('foot', shin * Mat.move(0, 0.26, 0) * Mat.rotX(-(1.4 + 3.0 * e) - 2.55 * (1 - e)));
        }
        for (final (s, angle) in [(-1.0, j.frontLeft), (1.0, j.frontRight)]) {
          final shoulder = limb(s * 0.22, 0.25, 0.2, angle);
          put('arm', shoulder);
          put('foot', Mat.move(s * 0.22, 0.25, 0.2) * Mat.rotX(-angle) * Mat.move(0, -0.22, 0.05) * Mat.scale(0.7));
        }
        put('body', Mat.move(0, 0.33, -0.02) * Mat.rotX(-0.22));
        put('throat', Mat.move(0, 0.27, 0.22) * Mat.scale(1, j.throat, j.throat));
        put('collar', Mat.move(0, 0.3, 0.02));
        put('mouth', Mat.move(0, 0.42, 0.29));
        for (final s in [-1.0, 1.0]) {
          final eye = Mat.move(s * 0.17, 0.56, 0.12);
          put('eyeball', eye);
          put('white', eye * Mat.move(0, 0.01, 0.1));
          put('pupil', eye * Mat.move(0, 0.01, 0.148));
        }
      case Species3.owl:
        for (final (s, angle) in [(-1.0, j.backLeft), (1.0, j.backRight)]) {
          final hip = limb(s * 0.11, 0.17, 0.02, -angle);
          put('leg', hip);
          put('foot', hip * Mat.move(0, 0.15, -0.03));
        }
        put('body', Mat.move(0, 0.47, 0));
        put('chest', Mat.move(0, 0.4, 0.15));
        put('tailfeather', Mat.move(0, 0.24, -0.23) * Mat.rotX(-0.5));
        put('collar', Mat.move(0, 0.66, 0));
        for (final s in [-1.0, 1.0]) {
          // Wings hinge at the shoulder and beat outward.
          put('wing', Mat.move(s * 0.24, 0.66, -0.02) * Mat.rotZ(s * j.wings * 1.5) * Mat.move(s * 0.05, -0.22, 0));
        }
        final head = Mat.move(0, 0.85, 0) * Mat.rotY(j.headTurn) * Mat.rotX(j.head);
        put('head', head);
        for (final s in [-1.0, 1.0]) {
          put('disc', head * Mat.move(s * 0.11, 0.02, 0.18));
          put('pupil', head * Mat.move(s * 0.11, 0.02, 0.23));
          put('tuft', head * Mat.move(s * 0.17, 0.12, 0) * Mat.rotZ(-s * 0.45));
        }
        put('beak', head * Mat.move(0, -0.06, 0.2) * Mat.rotX(math.pi * 0.7));
      case Species3.mascot:
        for (final (s, angle) in [(-1.0, j.backLeft), (1.0, j.backRight)]) {
          final hip = limb(s * 0.12, 0.23, 0, angle);
          put('leg', hip);
          put('foot', hip * Mat.move(0, 0.2, -0.03));
        }
        put('body', Mat.move(0, 0.37, 0));
        put('collar', Mat.move(0, 0.47, 0));
        for (final (s, angle) in [(-1.0, j.frontLeft), (1.0, j.frontRight)]) {
          put('arm', Mat.move(s * 0.24, 0.44, 0) * Mat.rotZ(s * (0.55 + j.wings * 0.6)) * Mat.rotX(math.pi - angle));
        }
        put('head', Mat.move(0, kMascotHeadHeight, 0) * Mat.rotY(j.headTurn));
    }
    return out;
  }

  int get triangleCount =>
      pose(Gait3.walker, const Anim3()).fold(0, (n, part) => n + part.mesh.triangleCount);

  /// Where the mascot's head is, for the picture drawn on it.
  V3 headPoint(Gait3 gait, Anim3 anim) {
    final body = bodyMotion(gait, anim);
    return V3(0, body.lift + kMascotHeadHeight * body.stretch, 0);
  }
}
