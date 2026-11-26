import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/bench.dart';

import 'games.dart';
import 'home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(_benchmark() ?? const BoardGamesApp());
}

/// Debug and profile builds can open a benchmark match from a PC:
/// `adb shell am start -n APP_ID/.MainActivity --es route /bench/optimized`
Widget? _benchmark() {
  if (kReleaseMode) return null;
  final mode = switch (PlatformDispatcher.instance.defaultRouteName) {
    '/bench/optimized' => GraphicsMode.optimized,
    '/bench/performance' => GraphicsMode.performance,
    _ => null,
  };
  if (mode == null) return null;
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: KitTheme.data(),
    onGenerateInitialRoutes: (_) => [MaterialPageRoute<void>(builder: (_) => ludoBenchmark(mode))],
    onGenerateRoute: (_) => null,
  );
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
