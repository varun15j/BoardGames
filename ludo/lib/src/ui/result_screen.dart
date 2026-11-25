import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../game/models.dart';
import '../game/rules.dart';
import 'game_screen.dart';
import 'ludo_game.dart';
import 'setup_screen.dart';
import 'storage.dart';

/// Ranks, captures and sixes, with Rematch / New match / Home.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.state, this.storage = const LudoStorage()});
  final GameState state;
  final LudoStorage storage;

  @override
  Widget build(BuildContext context) {
    final order = Rules.ranking(state);
    final seats = state.config.seats;
    final winner = seats[order.first];
    final soloHuman = state.config.humanCount == 1;
    final title = !winner.isBot && soloHuman
        ? 'You win!'
        : '${winner.name} wins!';
    return Scaffold(
      body: ResultView(
        title: title,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        confettiCount: GraphicsSettings.instance.optimized ? 140 : 50,
        rows: [
          for (var i = 0; i < order.length; i++)
            ResultRowData(
              rank: i + 1,
              name: seats[order[i]].name,
              color: kCornerStyles[seats[order[i]].corner].color,
              detail: '${state.captures[order[i]]} captures · ${state.sixesRolled[order[i]]} sixes',
            ),
        ],
        actions: [
          GoldButton(
            label: 'Rematch',
            icon: Icons.replay_rounded,
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => GameScreen(state: GameState.fresh(state.config), storage: storage),
              ),
            ),
          ),
          SoftButton(
            label: 'New match',
            icon: Icons.tune_rounded,
            onPressed: () {
              LudoGame.popToHome(context);
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SetupScreen(
                  mode: state.config.passAndPlay ? SetupMode.passAndPlay : SetupMode.bots,
                  storage: storage,
                ),
              ));
            },
          ),
          SoftButton(label: 'Home', icon: Icons.home_rounded, onPressed: () => LudoGame.popToHome(context)),
        ],
      ),
    );
  }
}
