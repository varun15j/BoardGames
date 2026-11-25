import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/game_kit.dart';

import 'games.dart';
import 'home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const BoardGamesApp());
}

class BoardGamesApp extends StatelessWidget {
  const BoardGamesApp({super.key, this.games});

  /// The games shown on the picker. Add new games in `games.dart`.
  final List<GameEntry>? games;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Board Games',
      debugShowCheckedModeBanner: false,
      theme: KitTheme.data(),
      home: HomeScreen(games: games ?? kGames),
    );
  }
}
