/// A repeatable frame-time benchmark: one person and three bots in a fresh
/// match, played by the turn timer. Nothing is loaded from or saved to the
/// player's data. Used from debug and profile builds only.
library;

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import 'src/game/models.dart';
import 'src/ui/game_screen.dart';
import 'src/ui/storage.dart';

class _NoStorage extends LudoStorage {
  const _NoStorage();

  @override
  Future<GameState?> loadSave() async => null;
  @override
  Future<void> save(GameState state) async {}
  @override
  Future<void> clearSave() async {}
  @override
  Future<({bool sound, bool haptics})> loadSettings() async => (sound: false, haptics: false);
  @override
  Future<void> saveSettings({required bool sound, required bool haptics}) async {}
}

Widget ludoBenchmark(GraphicsMode mode) {
  final config = MatchConfig(
    seats: const [
      SeatConfig(name: 'You', corner: 3, avatar: 'a:cat'),
      SeatConfig(name: 'Bot Frog', corner: 0, isBot: true, avatar: 'a:frog'),
      SeatConfig(name: 'Bot Lion', corner: 1, isBot: true, avatar: 'a:lion'),
      SeatConfig(name: 'Bot Owl', corner: 2, isBot: true, avatar: 'a:owl'),
    ],
  );
  return Theme(
    data: KitTheme.data(),
    child: GameScreen(
      state: GameState.fresh(config),
      storage: const _NoStorage(),
      graphics: GraphicsSettings.fixed(mode),
    ),
  );
}
