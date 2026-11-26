import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';

void _near(V3 a, V3 b) => expect((a - b).length, lessThan(1e-9), reason: '$a vs $b');

void main() {
  group('maths', () {
    test('rotations and composition', () {
      _near(Mat.rotY(math.pi / 2).apply(const V3(0, 0, 1)), const V3(1, 0, 0));
      _near(Mat.rotX(math.pi / 2).apply(const V3(0, 1, 0)), const V3(0, 0, 1));
      _near(Mat.rotZ(math.pi / 2).apply(const V3(1, 0, 0)), const V3(0, 1, 0));
      final m = Mat.move(1, 2, 3) * Mat.rotY(math.pi / 2) * Mat.scale(2);
      _near(m.apply(const V3(0, 0, 1)), const V3(3, 2, 3));
    });

    test('camera: up is up, nearer is lower and bigger, fit stays inside', () {
      final camera = Camera3()
        ..fit(const [V3(-8, 0, -8), V3(8, 0, -8), V3(8, 0, 8), V3(-8, 0, 8)], 300, 300);
      final centre = camera.project(V3.zero);
      expect(camera.project(const V3(0, 1, 0)).dy, lessThan(centre.dy));
      expect(camera.project(const V3(0, 0, 5)).dy, greaterThan(centre.dy));
      expect(camera.project(const V3(1, 0, 0)).dx, greaterThan(centre.dx));
      expect(camera.pixelsPerUnit(const V3(0, 0, 7)), greaterThan(camera.pixelsPerUnit(const V3(0, 0, -7))));
      for (final x in [-8.0, 8.0]) {
        for (final z in [-8.0, 8.0]) {
          final p = camera.project(V3(x, 0, z));
          expect(p.dx, inInclusiveRange(0, 300));
          expect(p.dy, inInclusiveRange(0, 300));
        }
      }
    });

    test('hidden faces are culled and the rest sorted far to near', () {
      final camera = Camera3();
      final batch = TriangleBatch(4);
      final box = Mesh.box(1, 1, 1, 0xFFFF0000);
      batch.add(box, Mat.move(0, 0, 3), camera);
      expect(batch.length, inInclusiveRange(4, 8), reason: 'about half of 12 triangles face away');
      final near = batch.length;
      batch.add(box, Mat.move(0, 0, -3), camera);
      expect(batch.order().first, greaterThanOrEqualTo(near), reason: 'the farther box is drawn first');
      batch.clear();
      expect(batch.length, 0);
    });
  });

  group('creatures', () {
    test('every avatar has a 3D movement style', () {
      for (final a in kAvatars) {
        expect(Gait3.values, contains(gaitFor(a)));
      }
      expect(gaitFor(kAvatarsById['cat']!), Gait3.quadruped);
      expect(gaitFor(kAvatarsById['frog']!), Gait3.hopper);
      expect(gaitFor(kAvatarsById['owl']!), Gait3.flyer);
      expect(gaitFor(kAvatarsById['penguin']!), Gait3.waddler);
      expect(gaitFor(kAvatarsById['rocket']!), Gait3.hoverer);
      expect(gaitFor(kAvatarsById['chef']!), Gait3.walker);
      expect({for (final a in kAvatars) speciesFor(a.id)}, Species3.values.toSet());
    });

    test('hops start and end on the ground, each style differently', () {
      Anim3 at(double p) => Anim3(action: Action3.move, progress: p);
      for (final gait in [Gait3.quadruped, Gait3.hopper, Gait3.flyer, Gait3.walker, Gait3.waddler]) {
        expect(bodyMotion(gait, at(0)).lift, closeTo(0, 1e-9), reason: gait.name);
        expect(bodyMotion(gait, at(1)).lift, closeTo(0, 1e-9), reason: gait.name);
        expect(bodyMotion(gait, at(0.5)).lift, greaterThan(0.1), reason: gait.name);
      }
      expect(bodyMotion(Gait3.hopper, at(0.5)).lift, greaterThan(bodyMotion(Gait3.quadruped, at(0.5)).lift * 3));
      // The owl glides: it stays high through the middle of the hop.
      expect(bodyMotion(Gait3.flyer, at(0.3)).lift, closeTo(bodyMotion(Gait3.flyer, at(0.6)).lift, 1e-9));
      expect(bodyMotion(Gait3.hoverer, const Anim3()).lift, greaterThan(0));
    });

    test('joints: cat trots diagonally, frog kicks, owl flaps and looks around', () {
      const mid = Anim3(action: Action3.move, progress: 0.25, leftLeads: true);
      final cat = jointAngles(Gait3.quadruped, mid);
      expect(cat.frontLeft, cat.backRight);
      expect(cat.frontRight, -cat.frontLeft);
      expect(cat.tail.abs(), greaterThan(0.1));
      final frog = jointAngles(Gait3.hopper, const Anim3(action: Action3.move, progress: 0.5));
      expect(frog.backLeft, greaterThan(1.5));
      expect(jointAngles(Gait3.hopper, const Anim3()).backLeft, 0);
      final wings = {
        for (var i = 1; i < 10; i++)
          jointAngles(Gait3.flyer, Anim3(action: Action3.move, progress: i / 10)).wings.sign,
      };
      expect(wings.length, greaterThan(1), reason: 'wings go up and down');
      expect(jointAngles(Gait3.flyer, const Anim3(time: 1.5)).headTurn.abs(), greaterThan(0.5));
      expect(jointAngles(Gait3.quadruped, const Anim3(time: 4.1)).tail,
          isNot(jointAngles(Gait3.quadruped, const Anim3(time: 4.4)).tail));
    });

    test('models are small enough to draw sixteen at once', () {
      for (final species in Species3.values) {
        final full = CreatureModel(species, 0xFFFF0000);
        final low = CreatureModel(species, 0xFFFF0000, low: true);
        expect(full.triangleCount, lessThan(1100), reason: species.name);
        expect(low.triangleCount, lessThan(full.triangleCount), reason: species.name);
      }
    });
  });

  group('3D die', () {
    test('lands with the rolled face up, for every value and throw', () {
      for (var value = 1; value <= 6; value++) {
        expect(topFace(faceUp(value)), value);
        for (var seed = 0; seed < 20; seed++) {
          final pose = dieThrowPose(value, 1, seed, const V3(0, 0, 9), const V3(1, 0, 1));
          expect(topFace(pose), value, reason: 'seed $seed');
          expect(pose.ty, closeTo(0.75, 1e-9), reason: 'resting on the board');
        }
      }
    });

    test('it is thrown into the air first', () {
      final mid = dieThrowPose(3, DieThrow.impacts[0] / 2, 1, const V3(0, 0, 9), const V3(1, 0, 1));
      expect(mid.ty, greaterThan(3));
    });
  });
}
