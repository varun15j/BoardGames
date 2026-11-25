import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../game/models.dart';
import 'game_screen.dart';
import 'how_to_play.dart';
import 'setup_screen.dart';
import 'storage.dart';

/// Race Board home: vs Bots, Pass & Play, Quick Match, How to play.
class LudoHomeScreen extends StatefulWidget {
  const LudoHomeScreen({super.key, this.storage = const LudoStorage()});
  final LudoStorage storage;

  @override
  State<LudoHomeScreen> createState() => _LudoHomeScreenState();
}

class _LudoHomeScreenState extends State<LudoHomeScreen> {
  GameState? _saved;

  @override
  void initState() {
    super.initState();
    GraphicsSettings.instance.ensureLoaded();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await widget.storage.loadSave();
    if (mounted) setState(() => _saved = s);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _refresh();
  }

  void _quick() {
    final config = MatchConfig(
      quick: true,
      seats: const [
        SeatConfig(name: 'You', corner: 3),
        SeatConfig(name: 'Bot Amber', corner: 1, isBot: true),
      ],
    );
    _open(GameScreen(state: GameState.fresh(config), storage: widget.storage));
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final s in kCornerStyles) ...[
                          TokenDisc(color: s.color, shape: s.shape, size: 40),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Race Board', textAlign: TextAlign.center, style: KitTheme.heading(size: 46)),
                    const SizedBox(height: 4),
                    Text(
                      'Roll, race and send rivals home',
                      textAlign: TextAlign.center,
                      style: KitTheme.body(size: 15, color: KitColors.muted),
                    ),
                    const SizedBox(height: 28),
                    if (saved != null) ...[
                      GoldButton(
                        label: 'Resume game',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => _open(GameScreen(state: saved, storage: widget.storage)),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _menuButton('vs Bots', Icons.smart_toy_rounded, () => _open(SetupScreen(mode: SetupMode.bots, storage: widget.storage)), primary: saved == null),
                    const SizedBox(height: 12),
                    _menuButton('Pass & Play', Icons.people_alt_rounded, () => _open(SetupScreen(mode: SetupMode.passAndPlay, storage: widget.storage))),
                    const SizedBox(height: 12),
                    _menuButton('Quick Match', Icons.bolt_rounded, _quick),
                    const SizedBox(height: 12),
                    SoftButton(label: 'How to play', icon: Icons.help_outline_rounded, onPressed: () => _open(const HowToPlayScreen())),
                    if (Navigator.of(context).canPop()) ...[
                      const SizedBox(height: 12),
                      SoftButton(label: 'Back to games', icon: Icons.arrow_back_rounded, onPressed: () => Navigator.of(context).maybePop()),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuButton(String label, IconData icon, VoidCallback onTap, {bool primary = false}) =>
      primary ? GoldButton(label: label, icon: icon, onPressed: onTap) : SoftButton(label: label, icon: icon, onPressed: onTap);
}
