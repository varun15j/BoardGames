import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';

/// One tile on the picker screen.
class GameEntry {
  const GameEntry({
    required this.title,
    required this.tagline,
    required this.color,
    required this.shape,
    this.route,
  });

  final String title;
  final String tagline;
  final Color color;
  final PlayerShape shape;

  /// Builds the route that opens the game; null means "coming soon".
  final Route<void> Function()? route;
}

/// Every game in the app. To add one, add an entry here (see the README).
final List<GameEntry> kGames = [
  GameEntry(
    title: 'Race Board',
    tagline: 'Ludo-style race for 2-4 players',
    color: KitColors.coral,
    shape: PlayerShape.circle,
    route: LudoGame.route,
  ),
  const GameEntry(
    title: 'Coming soon',
    tagline: 'More board games are on the way',
    color: KitColors.violet,
    shape: PlayerShape.diamond,
  ),
];
