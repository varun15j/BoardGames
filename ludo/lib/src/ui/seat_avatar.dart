import 'dart:math';

import 'package:game_kit/game_kit.dart';

import '../game/models.dart';

/// Used by seats saved before avatars existed, one per board corner.
const List<String> kDefaultCornerAvatars = ['frog', 'lion', 'owl', 'cat'];

/// What a seat shows.
AvatarChoice seatAvatar(SeatConfig seat) =>
    AvatarChoice.decode(seat.avatar) ?? AvatarChoice(kDefaultCornerAvatars[seat.corner]);

/// [count] different built-in avatars, none of them in [avoid].
List<Avatar> randomAvatars(int count, Random rng, {Set<String> avoid = const {}}) {
  final pool = [for (final a in kAvatars) if (!avoid.contains(a.id)) a]..shuffle(rng);
  return pool.take(count).toList();
}
