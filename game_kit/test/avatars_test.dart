import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.red);
  final image = await recorder.endRecording().toImage(w, h);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  creatureTests();
  setUp(() {
    KitTheme.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('catalog', () {
    test('at least 60 avatars with unique ids, every category filled', () {
      expect(kAvatars.length, greaterThanOrEqualTo(60));
      expect({for (final a in kAvatars) a.id}.length, kAvatars.length);
      expect({for (final a in kAvatars) a.name}.length, kAvatars.length);
      for (final c in AvatarCategory.values) {
        expect(avatarsIn(c), isNotEmpty, reason: c.label);
      }
    });

    testWidgets('every avatar renders and is cached once', (tester) async {
      for (final a in kAvatars) {
        final first = AvatarImages.instance.image(AvatarChoice(a.id), 40);
        expect(first.width, 64);
        expect(identical(first, AvatarImages.instance.image(AvatarChoice(a.id), 50)), isTrue);
      }
    });
  });

  test('a choice survives encoding', () {
    expect(AvatarChoice.decode(const AvatarChoice('cat').encode()), const AvatarChoice('cat'));
    const photo = AvatarChoice('dog', photoPath: '/data/a|b.png');
    expect(AvatarChoice.decode(photo.encode()), photo);
    expect(AvatarChoice.decode(null), isNull);
    expect(AvatarChoice.decode('junk'), isNull);
    expect(const AvatarChoice('gone').avatar.id, AvatarChoice.fallbackId);
  });

  group('profile and photo', () {
    test('name and avatar persist', () async {
      final p = PlayerProfile();
      await p.ensureLoaded();
      await p.update(name: ' Asha ', choice: const AvatarChoice('panda'));
      final again = PlayerProfile();
      await again.ensureLoaded();
      expect(again.name, 'Asha');
      expect(again.choice, const AvatarChoice('panda'));
    });

    test('a missing photo falls back to the avatar', () async {
      SharedPreferences.setMockInitialValues({'kit.profile.avatar': 'p:owl|/no/such/file.png'});
      final p = PlayerProfile();
      await p.ensureLoaded();
      expect(p.choice, const AvatarChoice('owl'));
    });

    testWidgets('an unreadable photo shows the fallback image', (tester) async {
      const choice = AvatarChoice('owl', photoPath: '/no/such/photo.png');
      await tester.runAsync(() async {
        final shown = AvatarImages.instance.image(choice, 64);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(AvatarImages.instance.failed(choice, 64), isTrue);
        expect(identical(shown, AvatarImages.instance.image(const AvatarChoice('owl'), 64)), isTrue);
      });
    });

    testWidgets('importing crops to a private 256 px square; remove deletes it', (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('avatar_test');
        final bytes = await _png(400, 300);
        final path = await PhotoImporter(pick: () async => bytes, folder: () async => dir).import();
        expect(path, startsWith(dir.path));
        final saved = await squareCrop(File(path!).readAsBytesSync(), 256);
        expect(saved.width, 256);

        final p = PlayerProfile();
        await p.ensureLoaded();
        await p.update(choice: AvatarChoice('cat', photoPath: path));
        await p.removePhoto();
        expect(p.choice, const AvatarChoice('cat'));
        expect(File(path).existsSync(), isFalse);

        expect(await PhotoImporter(pick: () async => null, folder: () async => dir).import(), isNull);
        await dir.delete(recursive: true);
      });
    });
  });

  testWidgets('picker: categories, preview, denied gallery keeps the avatar', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    AvatarPick? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context).push<AvatarPick>(
            MaterialPageRoute(
              builder: (_) => AvatarPickerScreen(
                initial: const AvatarChoice('cat'),
                name: 'Asha',
                importer: PhotoImporter(pick: () async => throw Exception('denied')),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar-cat')), findsOneWidget);
    await tester.tap(find.text('Use my photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn\'t open that photo'), findsOneWidget);
    await tester.ensureVisible(find.text('Space'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Space'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('avatar-rocket')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result!.choice, const AvatarChoice('rocket'));
    expect(result!.name, 'Asha');
  });

  group('living yard', () {
    test('blinks every 3 to 6 seconds for 120 ms', () {
      for (var seed = 0; seed < 10; seed++) {
        final schedule = BlinkSchedule(Random(seed));
        final starts = <int>[];
        var wasClosed = false;
        var closedMs = 0;
        for (var ms = 0; ms < 60000; ms += 10) {
          final closed = schedule.isClosedAt(Duration(milliseconds: ms));
          if (closed && !wasClosed) starts.add(ms);
          if (closed) closedMs += 10;
          wasClosed = closed;
        }
        expect(starts.first, inInclusiveRange(3000, 6010));
        for (var i = 1; i < starts.length; i++) {
          expect(starts[i] - starts[i - 1], inInclusiveRange(3110, 6140));
        }
        expect(closedMs / starts.length, closeTo(120, 12));
      }
    });

    test('different yards do not blink together', () {
      expect(BlinkSchedule(Random(1)).next, isNot(BlinkSchedule(Random(2)).next));
    });

    test('eyes are on the top spots, cheeks below', () {
      expect(YardFaceLayout.eyes.map((e) => e.dy).toSet(), {2});
      expect(YardFaceLayout.cheeks.map((e) => e.dy).toSet(), {4});
      expect(YardFaceLayout.eyes.map((e) => e.dx), [2, 4]);
    });
  });

  group('walking', () {
    test('legs move only during a hop and alternate', () {
      for (final flat in [true, false]) {
        expect(legPose(0, true, flat: flat), LegPose.standing);
        expect(legPose(1, true, flat: flat), LegPose.standing);
      }
      expect(legPose(0.5, true).left, greaterThan(0));
      expect(legPose(0.5, true).right, lessThan(0));
      expect(legPose(0.5, false).right, greaterThan(0));
      // Performance mode has just two frames.
      final frames = {for (var i = 1; i < 20; i++) legPose(i / 20, true, flat: true)};
      expect(frames.length, 2);
    });

    testWidgets('characters build in both modes, with avatar and photo fallback', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Row(
          children: [
            for (final flat in [true, false])
              for (final choice in const [AvatarChoice('fox'), AvatarChoice('fox', photoPath: '/missing.png')])
                CharacterToken(
                  color: KitColors.coral,
                  shape: PlayerShape.circle,
                  avatar: choice,
                  size: 48,
                  flat: flat,
                  dizzy: !flat,
                  pose: legPose(0.5, true, flat: flat),
                ),
          ],
        ),
      ));
      expect(find.byType(CharacterToken), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });
}

void creatureTests() {
  group('creatures', () {
    test('every avatar has a token body and a way of moving', () {
      for (final a in kAvatars) {
        expect(creatureFor(a).shapes, isNotEmpty, reason: a.id);
        expect(Locomotion.values, contains(locomotionFor(a)));
      }
      expect({for (final a in kAvatars) locomotionFor(a)}, Locomotion.values.toSet());
    });

    test('animals are the whole animal, not a head on a person', () {
      for (final a in avatarsIn(AvatarCategory.animals)) {
        expect(identical(creatureFor(a).shapes, a.shapes), isFalse, reason: a.id);
        expect(locomotionFor(a), isNot(Locomotion.walker), reason: a.id);
      }
      expect(locomotionFor(kAvatarsById['frog']!), Locomotion.hopper);
      expect(locomotionFor(kAvatarsById['cat']!), Locomotion.quadruped);
      expect(locomotionFor(kAvatarsById['owl']!), Locomotion.waddler);
      expect(locomotionFor(kAvatarsById['rocket']!), Locomotion.floater);
      for (final a in avatarsIn(AvatarCategory.people)) {
        expect(locomotionFor(a), Locomotion.walker);
      }
    });

    test('footprints match the creature', () {
      expect(creatureFor(kAvatarsById['cat']!).print, FootprintKind.paw);
      expect(creatureFor(kAvatarsById['dog']!).print, FootprintKind.paw);
      expect(creatureFor(kAvatarsById['frog']!).print, FootprintKind.webbed);
      expect(creatureFor(kAvatarsById['pizza']!).print, FootprintKind.dot);
      expect(creatureFor(kAvatarsById['chef']!).print, FootprintKind.shoe);
    });

    testWidgets('the same avatar for two players gives different tokens', (tester) async {
      const cat = AvatarChoice('cat');
      final red = CharacterSprites.body(cat, KitColors.coral, PlayerShape.circle, 24, 2, false);
      final teal = CharacterSprites.body(cat, KitColors.teal, PlayerShape.square, 24, 2, false);
      expect(identical(red, teal), isFalse);
      expect(identical(red, CharacterSprites.body(cat, KitColors.coral, PlayerShape.circle, 24, 2, false)), isTrue);
    });

    test('crowded squares form a tidy cluster with a count from three', () {
      expect(clusterOffsets(1), [Offset.zero]);
      for (var n = 2; n <= 8; n++) {
        final spots = clusterOffsets(n);
        expect(spots.length, n);
        expect(spots.toSet().length, n, reason: '$n tokens must not hide each other');
        expect(spots.every((s) => s.dx.abs() <= 0.3 && s.dy.abs() <= 0.3), isTrue);
        expect(clusterScale(n), lessThan(1));
      }
      expect(showCountBadge(2), isFalse);
      expect(showCountBadge(3), isTrue);
    });
  });
}
