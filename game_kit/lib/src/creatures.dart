import 'avatars/art.dart';
import 'avatars/catalog.dart';
import 'footprints.dart';

/// How a creature gets about.
enum Locomotion {
  /// Two walking legs and swinging arms.
  walker,

  /// Four legs and a swinging tail.
  quadruped,

  /// Big back legs that spring.
  hopper,

  /// A rocking waddle with flapping wings.
  waddler,

  /// No legs: it floats.
  floater,
}

enum TailKind { none, long, short, bushy, tuft, spiky }

/// The body of one species on a 100 x 100 canvas, facing the viewer, with the
/// ground at y = 90. Legs, wings and tails are drawn separately so they can
/// move.
class CreatureBody {
  const CreatureBody({
    required this.motion,
    required this.shapes,
    required this.limb,
    this.foot = ink,
    this.scale = 1,
    this.lift = 0,
    this.tail = TailKind.none,
    this.tailColor = ink,
    this.wing,
    this.print = FootprintKind.dot,
  });

  final Locomotion motion;
  final List<Shape> shapes;

  /// Colour of legs and arms, and of the feet.
  final int limb;
  final int foot;

  /// Scale of [shapes] about the canvas centre, then moved up by [lift].
  final double scale;
  final double lift;
  final TailKind tail;
  final int tailColor;

  /// Wing colour for waddlers.
  final int? wing;
  final FootprintKind print;
}

const int _orange = 0xFFF59E42;
const int _fox = 0xFFF26B1D;
const int _brown = 0xFF9A6234;
const int _tan = 0xFFF3D3A4;
const int _green = 0xFF4CB944;

/// A four-legged animal: a low body behind a large head.
CreatureBody _quadruped({
  required int coat,
  required List<Shape> head,
  required TailKind tail,
  int? tailColor,
  int? limb,
  int? belly,
  List<Shape> back = const [],
}) =>
    CreatureBody(
      motion: Locomotion.quadruped,
      limb: limb ?? coat,
      foot: ink,
      tail: tail,
      tailColor: tailColor ?? coat,
      print: FootprintKind.paw,
      shapes: [
        ...back,
        E(42, 64, 58, 34, coat),
        if (belly != null) E(44, 72, 36, 15, belly),
        ...head,
      ],
    );

/// Eyes for a head centred at (64, 42).
List<Shape> _eyesAt(double x, double y, double gap, double r) => [
      C(x - gap / 2, y, r, ink),
      C(x + gap / 2, y, r, ink),
      C(x - gap / 2 + r * 0.35, y - r * 0.35, r * 0.38, white),
      C(x + gap / 2 + r * 0.35, y - r * 0.35, r * 0.38, white),
    ];

final Map<String, CreatureBody> _special = {
  'cat': _quadruped(coat: _orange, belly: white, tail: TailKind.long, head: [
    const P([40, 36, 42, 4, 62, 22], _orange), const P([90, 36, 88, 4, 68, 22], _orange),
    const P([45, 24, 46, 12, 55, 21], pink), const P([85, 24, 84, 12, 75, 21], pink),
    const E(65, 42, 52, 44, _orange), const E(65, 52, 28, 18, white), ..._eyesAt(65, 38, 22, 5),
    const P([61, 47, 69, 47, 65, 52], pink), const L(36, 48, 48, 50, white, 2), const L(36, 56, 48, 54, white, 2),
    const L(94, 48, 82, 50, white, 2), const L(94, 56, 82, 54, white, 2),
  ]),
  'dog': _quadruped(coat: _tan, tail: TailKind.short, tailColor: 0xFF9C6B43, head: [
    const E(65, 40, 46, 44, _tan), const E(42, 42, 17, 38, 0xFF9C6B43), const E(88, 42, 17, 38, 0xFF9C6B43),
    ..._eyesAt(65, 35, 20, 4.5), const E(65, 52, 28, 20, white), const E(65, 46, 13, 9, ink),
    const E(65, 62, 9, 10, pink),
  ]),
  'fox': _quadruped(coat: _fox, belly: white, limb: 0xFF5A2C12, tail: TailKind.bushy, head: [
    const P([38, 40, 36, 2, 62, 24], _fox), const P([92, 40, 94, 2, 68, 24], _fox),
    const P([38, 14, 36, 2, 46, 10], ink), const P([92, 14, 94, 2, 84, 10], ink),
    const P([36, 36, 65, 20, 94, 36, 65, 68], _fox), const P([36, 36, 56, 46, 65, 68], white),
    const P([94, 36, 74, 46, 65, 68], white), ..._eyesAt(65, 37, 22, 4), const C(65, 64, 5.5, ink),
  ]),
  'panda': _quadruped(coat: white, limb: ink, tail: TailKind.short, tailColor: ink, head: [
    const C(44, 20, 11, ink), const C(86, 20, 11, ink), const E(65, 42, 52, 48, white),
    const R(54, 40, 14, 18, 7, ink, 35), const R(76, 40, 14, 18, 7, ink, -35), const C(55, 40, 3.4, white),
    const C(75, 40, 3.4, white), const E(65, 53, 11, 7, ink), const A(65, 57, 14, 10, 20, 140, ink, 2.5),
  ]),
  'bear': _quadruped(coat: _brown, tail: TailKind.short, head: [
    const C(44, 20, 11, _brown), const C(86, 20, 11, _brown), const C(44, 20, 5, 0xFFD9A66F),
    const C(86, 20, 5, 0xFFD9A66F), const C(65, 42, 26, _brown), const E(65, 52, 28, 21, 0xFFE9C08F),
    ..._eyesAt(65, 36, 20, 4), const E(65, 47, 12, 8, ink), const A(65, 55, 12, 9, 20, 140, ink, 2.5),
  ]),
  'lion': _quadruped(coat: 0xFFFFC857, tail: TailKind.tuft, tailColor: 0xFFB45A1A, head: [
    const S(65, 42, 36, 0xFFB45A1A, 13), const C(65, 42, 26, 0xFFB45A1A), const C(65, 43, 19, 0xFFFFC857),
    ..._eyesAt(65, 39, 15, 3.4), const E(65, 52, 17, 12, 0xFFFFE9B5), const P([60, 48, 70, 48, 65, 54], 0xFF8A3B12),
  ]),
  'unicorn': _quadruped(coat: white, tail: TailKind.long, tailColor: 0xFF8E7CFF, head: [
    const P([60, 20, 74, 0, 72, 24], 0xFFFFC83D), const P([46, 30, 46, 12, 58, 24], white),
    const E(66, 42, 40, 46, white), const C(46, 28, 9, 0xFF8E7CFF), const C(42, 42, 9, 0xFF5FD0F5),
    const C(43, 56, 8, 0xFFFF7AB6), const C(56, 22, 7, 0xFFFF7AB6), ..._eyesAt(68, 38, 18, 4),
    const E(70, 57, 24, 17, 0xFFFFD3DF), const C(65, 56, 2, ink), const C(75, 56, 2, ink),
  ]),
  'dragon': _quadruped(
    coat: 0xFF2FBF71,
    belly: 0xFFD8F5A2,
    tail: TailKind.spiky,
    back: const [P([30, 54, 6, 22, 30, 32, 34, 14, 48, 50], 0xFF1E8E5A)],
    head: [
      const P([50, 26, 42, 4, 62, 20], 0xFFFFD25A), const P([80, 26, 88, 4, 68, 20], 0xFFFFD25A),
      const E(66, 40, 46, 40, 0xFF2FBF71), const E(68, 54, 36, 22, 0xFF7BE0A4), const C(56, 34, 7, 0xFFFFE96B),
      const C(76, 34, 7, 0xFFFFE96B), const E(56, 34, 3, 10, ink), const E(76, 34, 3, 10, ink),
      const C(62, 52, 2.5, ink), const C(76, 52, 2.5, ink), const P([58, 62, 62, 69, 66, 63], white),
    ],
  ),

  // Hoppers: a squat body; the big back legs are drawn moving.
  'frog': const CreatureBody(
    motion: Locomotion.hopper,
    limb: _green,
    foot: 0xFF2F8F32,
    print: FootprintKind.webbed,
    shapes: [
      E(50, 62, 66, 46, _green), E(50, 72, 40, 24, 0xFFC9EE8A), C(30, 36, 16, _green), C(70, 36, 16, _green),
      C(30, 34, 11, white), C(70, 34, 11, white), C(31, 35, 5.5, ink), C(69, 35, 5.5, ink),
      A(50, 54, 40, 24, 15, 150, ink, 3.5), E(24, 60, 9, 6, 0x88FF7A8A), E(76, 60, 9, 6, 0x88FF7A8A),
    ],
  ),
  'rabbit': const CreatureBody(
    motion: Locomotion.hopper,
    limb: white,
    foot: 0xFFE3D8F5,
    print: FootprintKind.paw,
    shapes: [
      R(40, 18, 13, 36, 7, white, -10), R(62, 18, 13, 36, 7, white, 10), R(40, 19, 5, 26, 3, pink, -10),
      R(62, 19, 5, 26, 3, pink, 10), C(18, 66, 10, white), E(48, 68, 52, 36, white), E(52, 44, 46, 40, white),
      C(42, 40, 4.5, ink), C(64, 40, 4.5, ink), C(43.5, 38.5, 1.6, white), C(65.5, 38.5, 1.6, white),
      E(53, 50, 9, 6, pink), R(50, 59, 5, 7, 1.5, 0xFFE8ECF5), R(56, 59, 5, 7, 1.5, 0xFFE8ECF5),
      E(36, 50, 9, 6, 0x88FF7A8A), E(70, 50, 9, 6, 0x88FF7A8A),
    ],
  ),

  // Birds waddle and flap.
  'owl': const CreatureBody(
    motion: Locomotion.waddler,
    limb: 0xFFFFB000,
    foot: 0xFFFFB000,
    wing: 0xFF7A4E30,
    shapes: [
      P([24, 32, 20, 4, 44, 18], 0xFFA9744F), P([76, 32, 80, 4, 56, 18], 0xFFA9744F), E(50, 50, 62, 70, 0xFFA9744F),
      E(50, 68, 40, 34, 0xFFF0D2A8), C(36, 38, 15, white), C(64, 38, 15, white), C(37, 39, 7, ink),
      C(63, 39, 7, ink), C(39.5, 36.5, 2.4, white), C(65.5, 36.5, 2.4, white), P([43, 49, 57, 49, 50, 61], 0xFFFFB000),
    ],
  ),
  'penguin': const CreatureBody(
    motion: Locomotion.waddler,
    limb: 0xFFFF9A00,
    foot: 0xFFFF9A00,
    wing: 0xFF22304F,
    print: FootprintKind.webbed,
    shapes: [
      E(50, 48, 58, 76, 0xFF22304F), E(40, 34, 24, 28, white), E(60, 34, 24, 28, white), E(50, 62, 42, 46, white),
      C(41, 33, 4.2, ink), C(59, 33, 4.2, ink), C(42.5, 31.5, 1.4, white), C(60.5, 31.5, 1.4, white),
      P([40, 42, 60, 42, 50, 52], 0xFFFF9A00),
    ],
  ),
  'phoenix': const CreatureBody(
    motion: Locomotion.waddler,
    limb: 0xFFFFAD00,
    foot: 0xFFFFAD00,
    wing: 0xFFF23D2C,
    shapes: [
      P([36, 28, 30, 4, 44, 14, 50, 0, 56, 14, 70, 4, 64, 28], 0xFFF23D2C), P([22, 70, 2, 90, 30, 82], 0xFFFFD25A),
      E(50, 52, 54, 64, 0xFFFF8A00), E(50, 68, 32, 28, 0xFFFFD25A), C(40, 38, 5, ink), C(60, 38, 5, ink),
      C(41.5, 36.5, 1.8, white), C(61.5, 36.5, 1.8, white), P([42, 46, 58, 46, 50, 60], 0xFFFFE96B),
    ],
  ),

  // A crescent drawn as its own outline (the avatar cuts it from the sky).
  'moon': const CreatureBody(
    motion: Locomotion.floater,
    limb: 0xFFFFE9A8,
    shapes: [
      P([
        58, 8, 38, 12, 22, 26, 15, 46, 19, 66, 32, 80, 52, 87, 70, 82, 82, 70, //
        64, 70, 48, 62, 40, 48, 40, 32, 46, 18,
      ], 0xFFFFE9A8),
      C(30, 40, 3.6, ink), A(31, 54, 13, 10, 20, 140, ink, 2.5), C(28, 66, 3.5, 0xFFE8C877), C(52, 76, 3, 0xFFE8C877),
    ],
  ),
};

const _floaters = {'ghost', 'rocket', 'ufo', 'comet'};

/// Limb colours for creatures built from their avatar picture.
const _limbs = {
  'robot': 0xFF5C6B8A,
  'alien': 0xFF5FBF45,
  'monster': 0xFF7B4DFF,
  'knight': 0xFF8592AC,
  'wizard': 0xFF4C2AA8,
  'witch': 0xFF6A2C91,
  'queen': 0xFF1E5F8F,
  'astronaut': 0xFFE6EBF5,
};

/// The body for an avatar. Animals and birds have their own; people stay
/// people; everything else (food, sports, space, fantasy) is the thing itself
/// with arms and legs, or floats.
CreatureBody creatureFor(Avatar avatar) {
  final special = _special[avatar.id];
  if (special != null) return special;
  final floats = _floaters.contains(avatar.id);
  return CreatureBody(
    motion: floats ? Locomotion.floater : Locomotion.walker,
    shapes: avatar.shapes,
    limb: _limbs[avatar.id] ?? ink,
    // Room underneath for legs.
    scale: floats ? 0.86 : 0.76,
    lift: floats ? 6 : 11,
    print: avatar.category == AvatarCategory.people ? FootprintKind.shoe : FootprintKind.dot,
  );
}

Locomotion locomotionFor(Avatar avatar) => creatureFor(avatar).motion;

