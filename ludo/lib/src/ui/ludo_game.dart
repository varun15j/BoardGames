import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import 'home_screen.dart';
import 'storage.dart';

/// The entry point of the Ludo module: the Race Board home screen, wrapped in
/// the shared game theme. Put it anywhere a widget fits, or push
/// [LudoGame.route].
class LudoGame extends StatelessWidget {
  const LudoGame({super.key, this.storage = const LudoStorage()});

  /// Name given to [route] so inner screens can pop back to the Ludo home.
  static const routeName = 'ludo';

  final LudoStorage storage;

  /// A route that opens the game from any app.
  static Route<void> route() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: routeName),
        builder: (_) => const LudoGame(),
      );

  /// Pops back to the Ludo home screen.
  static void popToHome(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == routeName);

  @override
  Widget build(BuildContext context) {
    return Theme(data: KitTheme.data(), child: LudoHomeScreen(storage: storage));
  }
}
