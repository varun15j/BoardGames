import 'art.dart';

enum AvatarCategory {
  animals('Animals'),
  people('People'),
  fantasy('Fantasy'),
  space('Space'),
  food('Food'),
  sports('Sports');

  const AvatarCategory(this.label);
  final String label;
}

/// One built-in avatar: original vector art drawn in code.
class Avatar {
  const Avatar(this.id, this.name, this.category, this.background, this.shapes);
  final String id;
  final String name;
  final AvatarCategory category;
  final int background;
  final List<Shape> shapes;
}

const _a = AvatarCategory.animals;
const _p = AvatarCategory.people;
const _f = AvatarCategory.fantasy;
const _s = AvatarCategory.space;
const _d = AvatarCategory.food;
const _g = AvatarCategory.sports;

/// A person: neck, shoulders and head, with [back] hair behind and [front]
/// details over the face.
List<Shape> _person(int skin, int shirt, {List<Shape> back = const [], List<Shape> front = const []}) => [
      ...back,
      E(50, 100, 70, 40, shirt),
      R(50, 76, 16, 14, 6, skin),
      C(25, 52, 6, skin),
      C(75, 52, 6, skin),
      E(50, 50, 48, 52, skin),
      ...eyes(50, 18, 3.6),
      smile(66, 16),
      ...cheeks(60, 30),
      ...front,
    ];

final List<Avatar> kAvatars = [
  // ---------------------------------------------------------------- animals
  Avatar('cat', 'Cat', _a, 0xFF8FD3F4, [
    const P([18, 48, 22, 10, 46, 30], 0xFFF59E42), const P([82, 48, 78, 10, 54, 30], 0xFFF59E42),
    const P([24, 36, 26, 20, 38, 30], pink), const P([76, 36, 74, 20, 62, 30], pink),
    const E(50, 56, 68, 56, 0xFFF59E42), const E(50, 68, 34, 24, white),
    ...eyes(50, 28, 5.5), const P([45, 61, 55, 61, 50, 67], pink), smile(76, 14),
    const L(10, 62, 30, 64, white, 2), const L(10, 74, 30, 70, white, 2),
    const L(90, 62, 70, 64, white, 2), const L(90, 74, 70, 70, white, 2),
  ]),
  Avatar('dog', 'Puppy', _a, 0xFFB8E986, [
    const E(50, 54, 62, 62, 0xFFF3D3A4), const E(20, 48, 22, 46, 0xFF9C6B43), const E(80, 48, 22, 46, 0xFF9C6B43),
    const E(63, 45, 20, 22, 0xFF9C6B43), ...eyes(47, 26, 5), const E(50, 70, 32, 24, white),
    const E(50, 63, 14, 10, ink), smile(80, 16), const E(50, 85, 10, 9, pink),
  ]),
  Avatar('fox', 'Fox', _a, 0xFF4B6CB7, [
    const P([14, 52, 18, 8, 46, 32], 0xFFF26B1D), const P([86, 52, 82, 8, 54, 32], 0xFFF26B1D),
    const P([22, 20, 30, 26, 21, 36], ink), const P([78, 20, 70, 26, 79, 36], ink),
    const P([10, 50, 50, 24, 90, 50, 50, 92], 0xFFF26B1D),
    const P([10, 50, 40, 62, 50, 92], white), const P([90, 50, 60, 62, 50, 92], white),
    ...eyes(53, 30, 4.5), const C(50, 86, 7, ink),
  ]),
  Avatar('panda', 'Panda', _a, 0xFFFF9F80, [
    const C(22, 26, 15, ink), const C(78, 26, 15, ink), const E(50, 55, 70, 64, white),
    const R(34, 50, 18, 24, 9, ink, 35), const R(66, 50, 18, 24, 9, ink, -35),
    const C(36, 49, 4.5, white), const C(64, 49, 4.5, white), const C(36, 49, 2.2, ink), const C(64, 49, 2.2, ink),
    const E(50, 66, 14, 9, ink), smile(78, 16),
  ]),
  Avatar('frog', 'Frog', _a, 0xFFFFE08A, [
    const E(50, 62, 76, 54, 0xFF4CB944), const C(28, 36, 17, 0xFF4CB944), const C(72, 36, 17, 0xFF4CB944),
    const C(28, 34, 11, white), const C(72, 34, 11, white), const C(29, 35, 5.5, ink), const C(71, 35, 5.5, ink),
    const A(50, 56, 46, 32, 20, 140, ink, 3.5), ...cheeks(64, 52),
  ]),
  Avatar('rabbit', 'Rabbit', _a, 0xFFC7A6FF, [
    const R(35, 26, 17, 46, 9, white, -10), const R(65, 26, 17, 46, 9, white, 10),
    const R(35, 27, 7, 34, 4, pink, -10), const R(65, 27, 7, 34, 4, pink, 10),
    const E(50, 64, 60, 52, white), ...eyes(59, 24, 5), const E(50, 71, 10, 7, pink),
    const R(46, 84, 7, 10, 2, 0xFFE8ECF5), const R(54, 84, 7, 10, 2, 0xFFE8ECF5), smile(80, 14), ...cheeks(72, 36),
  ]),
  Avatar('bear', 'Bear', _a, 0xFF7ED9C3, [
    const C(22, 28, 15, 0xFF9A6234), const C(78, 28, 15, 0xFF9A6234), const C(22, 28, 7, 0xFFD9A66F),
    const C(78, 28, 7, 0xFFD9A66F), const C(50, 56, 34, 0xFF9A6234), const E(50, 68, 34, 26, 0xFFE9C08F),
    ...eyes(49, 26, 4.5), const E(50, 62, 15, 10, ink), smile(78, 15),
  ]),
  Avatar('owl', 'Owl', _a, 0xFF2E4A7D, [
    const P([20, 38, 20, 10, 42, 24], 0xFFA9744F), const P([80, 38, 80, 10, 58, 24], 0xFFA9744F),
    const E(50, 58, 70, 74, 0xFFA9744F), const E(50, 78, 44, 36, 0xFFF0D2A8),
    const C(34, 46, 17, white), const C(66, 46, 17, white), const C(35, 47, 8, ink), const C(65, 47, 8, ink),
    const C(38, 44, 2.6, white), const C(68, 44, 2.6, white), const P([43, 58, 57, 58, 50, 70], 0xFFFFB000),
  ]),
  Avatar('penguin', 'Penguin', _a, 0xFF9AD8FF, [
    const E(50, 58, 72, 80, 0xFF22304F), const E(37, 52, 30, 36, white), const E(63, 52, 30, 36, white),
    const E(50, 74, 48, 42, white), ...eyes(49, 24, 4.5), const P([38, 61, 62, 61, 50, 73], 0xFFFF9A00),
    ...cheeks(66, 40),
  ]),
  Avatar('lion', 'Lion', _a, 0xFF57C7A5, [
    const S(50, 53, 50, 0xFFB45A1A, 14), const C(50, 53, 33, 0xFFB45A1A), const C(30, 31, 9, 0xFFFFC857),
    const C(70, 31, 9, 0xFFFFC857), const C(50, 54, 26, 0xFFFFC857), ...eyes(49, 20, 4),
    const E(50, 66, 22, 16, 0xFFFFE9B5), const P([44, 60, 56, 60, 50, 67], 0xFF8A3B12), smile(76, 14),
  ]),

  // ----------------------------------------------------------------- people
  Avatar('cap', 'Cap kid', _p, 0xFF6FC3FF, _person(0xFFF2C29A, 0xFFF23D2C, front: const [
    A(50, 38, 46, 30, 180, 180, 0xFF5B3FF0, 14), R(50, 36, 52, 7, 3, 0xFF5B3FF0), R(74, 37, 20, 6, 3, 0xFF3D2AB0),
  ])),
  Avatar('bun', 'Top bun', _p, 0xFFFFC6D9, _person(0xFFC98B5E, 0xFF00A08C, back: const [
    C(50, 16, 14, 0xFF2A1B17), E(50, 46, 58, 58, 0xFF2A1B17),
  ], front: const [
    A(50, 38, 46, 28, 185, 170, 0xFF2A1B17, 10),
  ])),
  Avatar('beard', 'Beard', _p, 0xFFFFD25A, _person(0xFFE0A982, 0xFF22304F, front: const [
    A(50, 38, 46, 30, 180, 180, 0xFF5A3420, 11), A(50, 54, 46, 42, 15, 150, 0xFF5A3420, 12),
    A(50, 63, 18, 8, 200, 140, 0xFF5A3420, 5),
  ])),
  Avatar('pigtails', 'Pigtails', _p, 0xFF9BE7C4, _person(0xFFF6CBA6, 0xFFFF8F3D, back: const [
    C(17, 48, 14, 0xFFE0702F), C(83, 48, 14, 0xFFE0702F), E(50, 44, 56, 52, 0xFFE0702F),
  ], front: const [
    A(50, 38, 44, 26, 185, 170, 0xFFE0702F, 11), C(21, 38, 5, 0xFF5B3FF0), C(79, 38, 5, 0xFF5B3FF0),
  ])),
  Avatar('glasses', 'Glasses', _p, 0xFFB7C4FF, _person(0xFF9A6240, 0xFFFFAD00, front: const [
    A(50, 38, 46, 30, 180, 180, 0xFF151515, 11), A(39, 50, 20, 18, 0, 360, ink, 3), A(61, 50, 20, 18, 0, 360, ink, 3),
    L(49, 49, 51, 49, ink, 3),
  ])),
  Avatar('chef', 'Chef', _p, 0xFFFF8A75, _person(0xFFF2C29A, white, front: const [
    C(36, 18, 13, white), C(50, 13, 15, white), C(64, 18, 13, white), R(50, 28, 42, 14, 3, white),
    L(30, 33, 70, 33, 0xFFC9D1E4, 2), A(50, 64, 22, 8, 200, 140, 0xFF4A2A18, 4),
  ])),
  Avatar('headphones', 'DJ', _p, 0xFF3C2A78, _person(0xFFD29A70, 0xFF00C2A8, front: const [
    A(50, 40, 46, 32, 180, 180, 0xFF111111, 12), A(50, 46, 58, 58, 180, 180, 0xFFFFD25A, 6),
    R(22, 54, 12, 22, 6, 0xFFFFD25A), R(78, 54, 12, 22, 6, 0xFFFFD25A),
  ])),
  Avatar('grandma', 'Grandma', _p, 0xFF8FD6E1, _person(0xFFF3D0B5, 0xFF8E5BD0, back: const [
    C(50, 18, 12, 0xFFD7DCE6), E(50, 46, 58, 56, 0xFFD7DCE6),
  ], front: const [
    A(50, 38, 44, 26, 185, 170, 0xFFD7DCE6, 10), A(40, 51, 16, 12, 0, 360, 0xFFB5487A, 2.5),
    A(60, 51, 16, 12, 0, 360, 0xFFB5487A, 2.5), L(48, 50, 52, 50, 0xFFB5487A, 2.5),
  ])),
  Avatar('curls', 'Curls', _p, 0xFFFFB84D, _person(0xFF7A4A2E, 0xFF2F6BFF, back: const [
    C(50, 30, 28, 0xFF1D120E), C(26, 38, 18, 0xFF1D120E), C(74, 38, 18, 0xFF1D120E), C(32, 20, 16, 0xFF1D120E),
    C(68, 20, 16, 0xFF1D120E),
  ], front: const [
    C(36, 28, 8, 0xFF1D120E), C(50, 25, 9, 0xFF1D120E), C(64, 28, 8, 0xFF1D120E),
  ])),
  Avatar('longhair', 'Long hair', _p, 0xFFB6E36A, _person(0xFFE8B48C, 0xFFE0457B, back: const [
    R(50, 60, 62, 70, 28, 0xFF4B2418),
  ], front: const [
    A(50, 38, 44, 26, 185, 170, 0xFF4B2418, 11), A(34, 44, 22, 30, 200, 90, 0xFF4B2418, 7),
    C(25, 62, 3, 0xFFFFD25A), C(75, 62, 3, 0xFFFFD25A),
  ])),

  // ---------------------------------------------------------------- fantasy
  Avatar('dragon', 'Dragon', _f, 0xFF3B2A5A, [
    const P([22, 40, 14, 6, 40, 26], 0xFFFFD25A), const P([78, 40, 86, 6, 60, 26], 0xFFFFD25A),
    const P([8, 52, 24, 44, 22, 66], 0xFF1E8E5A), const P([92, 52, 76, 44, 78, 66], 0xFF1E8E5A),
    const E(50, 50, 62, 56, 0xFF2FBF71), const E(50, 74, 50, 32, 0xFF7BE0A4),
    const C(37, 46, 9, 0xFFFFE96B), const C(63, 46, 9, 0xFFFFE96B), const E(37, 46, 4, 13, ink),
    const E(63, 46, 4, 13, ink), const C(41, 70, 3.5, ink), const C(59, 70, 3.5, ink),
    const P([36, 82, 41, 90, 46, 83], white), const P([54, 83, 59, 90, 64, 82], white),
  ]),
  Avatar('unicorn', 'Unicorn', _f, 0xFFFFB6E1, [
    const P([42, 30, 50, 2, 58, 30], 0xFFFFC83D), const L(45, 22, 55, 18, white, 2), const L(47, 14, 53, 11, white, 2),
    const P([22, 42, 24, 16, 40, 32], white), const P([78, 42, 76, 16, 60, 32], white),
    const E(50, 58, 58, 64, white), const C(24, 44, 11, 0xFF8E7CFF), const C(20, 60, 10, 0xFF5FD0F5),
    const C(24, 75, 9, 0xFFFF7AB6), const C(36, 32, 10, 0xFFFF7AB6), ...eyes(54, 24, 4.5),
    const E(50, 76, 30, 20, 0xFFFFD3DF), const C(44, 75, 2.4, ink), const C(56, 75, 2.4, ink), ...cheeks(64, 38),
  ]),
  Avatar('wizard', 'Wizard', _f, 0xFF2B3A8F, [
    const E(50, 62, 42, 40, 0xFFF2C29A), const P([22, 46, 50, 2, 78, 46], 0xFF6B3FD6),
    const R(50, 46, 68, 9, 4, 0xFF4C2AA8), const S(50, 28, 8, 0xFFFFD25A), const S(63, 39, 4, 0xFFFFD25A),
    ...eyes(58, 18, 3.5), const P([26, 66, 74, 66, 50, 98], white), const E(50, 69, 26, 8, 0xFFE3E8F2),
    const C(50, 63, 5, 0xFFE8A682),
  ]),
  Avatar('robot', 'Robot', _f, 0xFFFF9D5C, [
    const L(50, 8, 50, 22, ink, 3.5), const C(50, 9, 6, 0xFFF23D2C), const R(14, 52, 10, 24, 4, 0xFF5C6B8A),
    const R(86, 52, 10, 24, 4, 0xFF5C6B8A), const R(50, 55, 66, 62, 16, 0xFFB9C6DD),
    const R(50, 48, 50, 24, 10, ink), const C(39, 48, 6, 0xFF48F0D0), const C(61, 48, 6, 0xFF48F0D0),
    const R(50, 72, 34, 10, 4, white), const L(42, 68, 42, 76, ink, 2), const L(50, 68, 50, 76, ink, 2),
    const L(58, 68, 58, 76, ink, 2),
  ]),
  Avatar('ghost', 'Ghost', _f, 0xFF4A3F7A, [
    const C(50, 44, 30, white), const R(50, 62, 60, 36, 2, white), const C(30, 80, 10, white),
    const C(50, 82, 10, white), const C(70, 80, 10, white), const E(40, 46, 9, 14, ink), const E(60, 46, 9, 14, ink),
    const E(50, 64, 10, 12, ink), ...cheeks(58, 38),
  ]),
  Avatar('witch', 'Witch', _f, 0xFF38C6A0, [
    const E(50, 62, 66, 60, 0xFF6A2C91), const E(50, 60, 44, 42, 0xFFA6D96A), const P([30, 40, 62, 2, 70, 40], ink),
    const E(50, 40, 76, 12, ink), const R(52, 33, 34, 7, 2, 0xFFF26B1D), ...eyes(56, 18, 4),
    const P([48, 58, 56, 68, 46, 68], 0xFF7FB84A), smile(80, 18),
  ]),
  Avatar('knight', 'Knight', _f, 0xFFB5333A, [
    const E(50, 14, 14, 22, 0xFFFFD25A), const R(50, 58, 60, 66, 26, 0xFFC4CEE0), const R(50, 52, 46, 12, 5, ink),
    const R(50, 62, 8, 40, 3, 0xFF8592AC), const C(30, 72, 2.6, ink), const C(37, 78, 2.6, ink),
    const C(63, 78, 2.6, ink), const C(70, 72, 2.6, ink), const C(40, 52, 2.4, white), const C(60, 52, 2.4, white),
  ]),
  Avatar('monster', 'One-eye', _f, 0xFFFFE066, [
    const P([24, 36, 22, 10, 40, 28], 0xFFFF7AB6), const P([76, 36, 78, 10, 60, 28], 0xFFFF7AB6),
    const E(50, 58, 72, 68, 0xFF7B4DFF), const C(50, 46, 19, white), const C(50, 48, 9, ink), const C(54, 44, 3, white),
    const E(50, 75, 36, 18, ink), const P([38, 68, 43, 76, 48, 68], white), const P([54, 68, 59, 76, 64, 68], white),
  ]),
  Avatar('queen', 'Queen', _f, 0xFF1E9BD7, [
    const E(50, 62, 66, 66, 0xFF3A1F14), const E(50, 60, 42, 46, 0xFFC98B5E),
    const P([26, 38, 22, 10, 37, 24, 50, 4, 63, 24, 78, 10, 74, 38], 0xFFFFC83D), const C(50, 28, 4.5, 0xFFF23D2C),
    const C(37, 31, 3, 0xFF48D0F0), const C(63, 31, 3, 0xFF48D0F0), ...eyes(57, 18, 3.6), smile(75, 15),
    ...cheeks(68, 28),
  ]),
  Avatar('phoenix', 'Firebird', _f, 0xFF23123F, [
    const P([50, 4, 62, 30, 78, 14, 74, 42, 92, 34, 78, 58, 50, 50, 22, 58, 8, 34, 26, 42, 22, 14, 38, 30], 0xFFF23D2C),
    const E(50, 60, 48, 52, 0xFFFF8A00), const E(50, 74, 28, 26, 0xFFFFD25A), ...eyes(52, 22, 4.5),
    const P([42, 60, 58, 60, 50, 74], 0xFFFFE96B),
  ]),

  // ------------------------------------------------------------------ space
  Avatar('rocket', 'Rocket', _s, 0xFF14224A, [
    const C(16, 20, 2, white), const C(84, 30, 2.5, white), const C(20, 74, 1.8, white),
    const P([30, 56, 16, 80, 36, 72], 0xFFF23D2C), const P([70, 56, 84, 80, 64, 72], 0xFFF23D2C),
    const E(50, 48, 36, 74, white), const P([36, 22, 50, 4, 64, 22], 0xFFF23D2C), const C(50, 42, 11, 0xFFF23D2C),
    const C(50, 42, 7.5, 0xFF6FD3FF), const P([40, 82, 50, 98, 60, 82], 0xFFFFAD00),
  ]),
  Avatar('saturn', 'Ringed planet', _s, 0xFF241A52, [
    const C(18, 22, 2, white), const C(82, 80, 2, white), const A(50, 52, 86, 30, 180, 180, 0xFFE9C46A, 7),
    const C(50, 52, 27, 0xFFF4A261), const A(50, 44, 46, 14, 20, 140, 0xFFE76F51, 5),
    const A(50, 56, 50, 12, 20, 140, 0xFFE76F51, 4), const A(50, 52, 86, 30, 0, 180, 0xFFFFE29A, 7),
  ]),
  Avatar('moon', 'Moon', _s, 0xFF101A3A, [
    const C(50, 50, 34, 0xFFFFE9A8), const C(66, 40, 29, 0xFF101A3A), const C(32, 56, 4.5, 0xFFE8C877),
    const C(44, 74, 3.5, 0xFFE8C877), const S(70, 34, 8, white), const S(80, 66, 5, white),
    const C(33, 44, 3, ink), const A(36, 58, 14, 10, 20, 140, ink, 2.5),
  ]),
  Avatar('sun', 'Sun', _s, 0xFF4FB8F0, [
    const S(50, 50, 48, 0xFFFF9F1C, 12), const C(50, 50, 29, 0xFFFFD23F), ...eyes(45, 20, 4.2), smile(66, 22),
    ...cheeks(57, 36),
  ]),
  Avatar('star', 'Star', _s, 0xFF5B3FF0, [
    const S(50, 53, 46, 0xFFFFD25A), ...eyes(50, 16, 3.8), smile(66, 14), ...cheeks(60, 28),
    const C(18, 22, 3, white), const C(84, 20, 2, white),
  ]),
  Avatar('astronaut', 'Astronaut', _s, 0xFF2C1E63, [
    const E(50, 96, 66, 36, 0xFFE6EBF5), const C(50, 50, 38, white), const E(50, 51, 54, 46, 0xFF22304F),
    const E(50, 53, 40, 36, 0xFFF2C29A), ...eyes(50, 16, 3.5), smile(66, 13),
    const A(50, 50, 48, 40, 200, 55, 0xAAFFFFFF, 4), const C(13, 52, 7, 0xFFF23D2C), const C(87, 52, 7, 0xFFF23D2C),
  ]),
  Avatar('ufo', 'Saucer', _s, 0xFF123047, [
    const P([36, 62, 16, 98, 84, 98, 64, 62], 0x55FFF59A), const E(50, 42, 40, 40, 0xFF7FE0FF),
    const E(50, 58, 82, 28, 0xFFB9C6DD), const E(50, 54, 82, 14, 0xFFDDE5F4), const C(24, 62, 4, 0xFFF23D2C),
    const C(50, 67, 4, 0xFFFFD25A), const C(76, 62, 4, 0xFF48F08A), const C(45, 36, 3, ink), const C(56, 36, 3, ink),
  ]),
  Avatar('alien', 'Alien', _s, 0xFF2D0F4E, [
    const L(34, 22, 28, 8, 0xFF8CF26B, 3.5), const L(66, 22, 72, 8, 0xFF8CF26B, 3.5), const C(28, 8, 4.5, 0xFF8CF26B),
    const C(72, 8, 4.5, 0xFF8CF26B), const E(50, 46, 68, 56, 0xFF8CF26B), const P([30, 62, 50, 94, 70, 62], 0xFF8CF26B),
    const R(35, 48, 18, 28, 9, ink, -30), const R(65, 48, 18, 28, 9, ink, 30), const C(38, 42, 3.5, white),
    const C(62, 42, 3.5, white), smile(76, 12),
  ]),
  Avatar('earth', 'Earth', _s, 0xFF0D1631, [
    const C(50, 50, 38, 0xFF2F8CFF), const P([24, 34, 42, 20, 52, 32, 44, 46, 30, 46], 0xFF3FBF5F),
    const P([48, 54, 66, 50, 70, 64, 58, 82, 50, 70], 0xFF3FBF5F), const P([66, 24, 80, 34, 74, 42], 0xFF3FBF5F),
    const A(50, 50, 66, 66, 190, 70, 0x99FFFFFF, 4), const C(12, 18, 2, white), const C(90, 76, 2, white),
  ]),
  Avatar('comet', 'Comet', _s, 0xFF0F2A4F, [
    const P([8, 8, 64, 46, 46, 64], 0xAAFF7A3D), const P([4, 40, 56, 54, 50, 68], 0x88FFD25A),
    const P([38, 6, 70, 46, 58, 52], 0x88FFD25A), const C(66, 66, 24, 0xFFBFE9FF), const C(66, 66, 16, white),
    const C(60, 64, 3, ink), const C(73, 64, 3, ink), const A(66, 70, 12, 9, 20, 140, ink, 2.5),
  ]),

  // ------------------------------------------------------------------- food
  Avatar('apple', 'Apple', _d, 0xFFFFE8B0, [
    const C(38, 58, 27, 0xFFE63946), const C(62, 58, 27, 0xFFE63946), const L(50, 36, 54, 14, 0xFF6B4226, 5),
    const R(66, 20, 24, 13, 7, 0xFF3FA34D, -25), const E(32, 48, 10, 16, 0x66FFFFFF), ...eyes(58, 22, 4), smile(74, 16),
  ]),
  Avatar('watermelon', 'Melon', _d, 0xFF7ED7F0, [
    const P([6, 38, 94, 38, 78, 72, 50, 88, 22, 72], 0xFF2E9E4F), const P([13, 38, 87, 38, 73, 66, 50, 79, 27, 66], 0xFFE9F7D0),
    const P([18, 38, 82, 38, 69, 61, 50, 72, 31, 61], 0xFFFF4D6D), const E(36, 48, 4, 7, ink), const E(50, 56, 4, 7, ink),
    const E(64, 48, 4, 7, ink), const E(44, 42, 3.5, 5, ink), const E(57, 43, 3.5, 5, ink),
  ]),
  Avatar('donut', 'Donut', _d, 0xFF6C4AB6, [
    const C(50, 52, 38, 0xFFD99A5B), const C(50, 49, 33, 0xFFFF77A9), const C(50, 50, 12, 0xFF6C4AB6),
    const R(32, 34, 10, 4, 2, 0xFFFFD25A, 30), const R(60, 26, 10, 4, 2, 0xFF48D0F0, -20),
    const R(74, 50, 10, 4, 2, white, 70), const R(66, 70, 10, 4, 2, 0xFF8CF26B, 25),
    const R(36, 72, 10, 4, 2, white, -35), const R(25, 54, 10, 4, 2, 0xFF48D0F0, 80),
  ]),
  Avatar('pizza', 'Pizza', _d, 0xFF2E7D5B, [
    const P([14, 24, 86, 24, 50, 94], 0xFFFFC857), const R(50, 22, 80, 14, 7, 0xFFC9803A),
    const C(36, 40, 8, 0xFFD7263D), const C(63, 42, 8, 0xFFD7263D), const C(50, 64, 8, 0xFFD7263D),
    const C(52, 40, 3, 0xFF3FA34D), const C(40, 56, 3, 0xFF3FA34D),
  ]),
  Avatar('icecream', 'Ice cream', _d, 0xFFA8E6F0, [
    const P([32, 54, 68, 54, 50, 96], 0xFFD99A5B), const L(38, 60, 58, 80, 0xFFB5773A, 2.5),
    const L(62, 60, 42, 80, 0xFFB5773A, 2.5), const C(50, 46, 22, 0xFFFF8FB8), const C(50, 27, 18, 0xFFFFF0C2),
    const C(50, 10, 6, 0xFFE63946), ...eyes(44, 16, 3.5), smile(57, 12),
  ]),
  Avatar('cupcake', 'Cupcake', _d, 0xFF9B5DE5, [
    const P([24, 58, 76, 58, 68, 92, 32, 92], 0xFFF4A261), const L(38, 62, 41, 88, 0xFFD97B3A, 3),
    const L(50, 62, 50, 88, 0xFFD97B3A, 3), const L(62, 62, 59, 88, 0xFFD97B3A, 3), const E(50, 56, 66, 24, 0xFFFFF1F6),
    const E(50, 43, 48, 22, 0xFFFFC2D9), const E(50, 30, 28, 20, 0xFFFFF1F6), const C(50, 18, 8, 0xFFE63946),
  ]),
  Avatar('burger', 'Burger', _d, 0xFF3D8BFF, [
    const R(50, 36, 72, 36, 18, 0xFFE9A44C), const E(36, 28, 5, 3, white), const E(52, 25, 5, 3, white),
    const E(66, 31, 5, 3, white), const R(50, 55, 78, 10, 5, 0xFF52B848), const R(50, 63, 72, 11, 5, 0xFF7A3E1D),
    const R(50, 70, 70, 6, 3, 0xFFFFD25A), const R(50, 80, 70, 16, 8, 0xFFE9A44C),
  ]),
  Avatar('avocado', 'Avocado', _d, 0xFFFFB4A2, [
    const E(50, 62, 60, 60, 0xFF2F6B2F), const E(50, 36, 40, 52, 0xFF2F6B2F), const E(50, 62, 48, 50, 0xFFC9E87A),
    const E(50, 40, 30, 40, 0xFFC9E87A), const C(50, 70, 14, 0xFF8A5A2B), ...eyes(44, 18, 3.8), smile(55, 11),
  ]),
  Avatar('strawberry', 'Strawberry', _d, 0xFFCDEBFF, [
    const P([16, 36, 84, 36, 70, 74, 50, 94, 30, 74], 0xFFEF233C), const C(32, 40, 16, 0xFFEF233C),
    const C(68, 40, 16, 0xFFEF233C), const P([26, 24, 44, 28, 50, 10, 56, 28, 74, 24, 62, 38, 38, 38], 0xFF2E9E4F),
    const E(34, 52, 3, 5, 0xFFFFE08A), const E(50, 62, 3, 5, 0xFFFFE08A), const E(66, 52, 3, 5, 0xFFFFE08A),
    const E(42, 76, 3, 5, 0xFFFFE08A), const E(59, 76, 3, 5, 0xFFFFE08A), const E(52, 46, 3, 5, 0xFFFFE08A),
  ]),
  Avatar('mango', 'Mango', _d, 0xFF00877A, [
    const E(48, 58, 62, 66, 0xFFFFA62B), const E(58, 46, 46, 46, 0xFFFFC53D), const E(36, 72, 28, 30, 0xFFF2682A),
    const L(58, 24, 62, 12, 0xFF6B4226, 5), const R(76, 18, 28, 14, 7, 0xFF52B848, -20), ...eyes(56, 20, 4),
    smile(72, 16),
  ]),

  // ----------------------------------------------------------------- sports
  Avatar('football', 'Football', _g, 0xFF2E9E4F, [
    const C(50, 50, 38, white), const P([50, 36, 63, 46, 58, 61, 42, 61, 37, 46], ink),
    const L(50, 36, 50, 13, ink), const L(63, 46, 85, 39, ink), const L(58, 61, 72, 81, ink),
    const L(42, 61, 28, 81, ink), const L(37, 46, 15, 39, ink), const C(50, 14, 6, ink), const C(83, 40, 6, ink),
    const C(71, 79, 6, ink), const C(29, 79, 6, ink), const C(17, 40, 6, ink),
  ]),
  Avatar('basketball', 'Basketball', _g, 0xFF22304F, [
    const C(50, 50, 39, 0xFFF2802A), const L(50, 11, 50, 89, ink), const L(11, 50, 89, 50, ink),
    const A(10, 50, 50, 70, -65, 130, ink), const A(90, 50, 50, 70, 115, 130, ink),
  ]),
  Avatar('tennis', 'Tennis ball', _g, 0xFF1D6FD1, [
    const C(50, 50, 38, 0xFFD6F23C), const A(14, 50, 56, 72, -62, 124, white, 5),
    const A(86, 50, 56, 72, 118, 124, white, 5),
  ]),
  Avatar('cricket', 'Cricket', _g, 0xFF63C5F2, [
    const R(40, 56, 20, 56, 6, 0xFFE9C08F, 40), const R(66, 25, 8, 30, 3, 0xFF22304F, 40),
    const C(72, 72, 16, 0xFFD7263D), const A(72, 72, 14, 32, 90, 180, white, 2.5),
    const A(72, 72, 8, 32, 90, 180, white, 1.5),
  ]),
  Avatar('shuttle', 'Shuttlecock', _g, 0xFFE85D75, [
    const P([20, 14, 80, 14, 62, 68, 38, 68], white), const L(34, 16, 43, 66, 0xFFB9C6DD, 2.5),
    const L(50, 16, 50, 66, 0xFFB9C6DD, 2.5), const L(66, 16, 57, 66, 0xFFB9C6DD, 2.5),
    const L(27, 38, 73, 38, 0xFF5B3FF0, 4), const R(50, 72, 28, 10, 3, 0xFF00A08C), const E(50, 82, 28, 22, 0xFFFFE9B5),
  ]),
  Avatar('trophy', 'Trophy', _g, 0xFF4C2AA8, [
    const A(27, 34, 28, 30, 70, 220, 0xFFFFC83D, 6), const A(73, 34, 28, 30, -110, 220, 0xFFFFC83D, 6),
    const P([27, 16, 73, 16, 66, 50, 50, 62, 34, 50], 0xFFFFC83D), const R(50, 69, 10, 18, 2, 0xFFE0A100),
    const R(50, 83, 40, 11, 3, 0xFF8A5A2B), const S(50, 34, 11, white),
  ]),
  Avatar('medal', 'Medal', _g, 0xFF0F6E6E, [
    const P([24, 4, 42, 4, 58, 44, 40, 48], 0xFFF23D2C), const P([76, 4, 58, 4, 42, 44, 60, 48], 0xFF3D8BFF),
    const C(50, 64, 28, 0xFFFFC83D), const C(50, 64, 20, 0xFFFFE08A), const S(50, 64, 15, 0xFFE0A100),
  ]),
  Avatar('darts', 'Bullseye', _g, 0xFFFFE8B0, [
    const C(46, 54, 38, 0xFF22304F), const C(46, 54, 29, white), const C(46, 54, 20, 0xFFF23D2C),
    const C(46, 54, 11, white), const C(46, 54, 5, 0xFFF23D2C), const L(48, 52, 82, 18, 0xFF5B3FF0, 4.5),
    const P([74, 14, 92, 8, 86, 26], 0xFF00A08C),
  ]),
  Avatar('bowling', 'Bowling', _g, 0xFF2B2D6E, [
    const E(38, 64, 30, 54, white), const E(38, 28, 18, 28, white), const L(30, 38, 46, 38, 0xFFF23D2C, 3.5),
    const L(30, 44, 46, 44, 0xFFF23D2C, 3.5), const C(70, 70, 22, 0xFF00C2A8), const C(66, 62, 3, ink),
    const C(75, 63, 3, ink), const C(68, 71, 3, ink),
  ]),
  Avatar('kite', 'Kite', _g, 0xFF7ED0FF, [
    const P([50, 6, 78, 38, 50, 74, 22, 38], 0xFFF23D2C), const P([50, 6, 78, 38, 50, 38], 0xFFFFAD00),
    const P([50, 38, 50, 74, 22, 38], 0xFFFFD25A), const L(50, 6, 50, 74, ink, 2), const L(22, 38, 78, 38, ink, 2),
    const A(42, 84, 18, 20, -80, 140, ink, 2.5), const P([34, 88, 24, 84, 26, 96], 0xFF5B3FF0),
    const P([52, 94, 62, 88, 62, 98], 0xFF00A08C),
  ]),
];

final Map<String, Avatar> kAvatarsById = {for (final a in kAvatars) a.id: a};

List<Avatar> avatarsIn(AvatarCategory category) => [for (final a in kAvatars) if (a.category == category) a];
