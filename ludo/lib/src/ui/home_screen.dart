import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../game/models.dart';
import 'game_screen.dart';
import 'how_to_play.dart';
import 'seat_avatar.dart';
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
    PlayerProfile.instance.ensureLoaded();
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

  Future<void> _editProfile() async {
    final profile = PlayerProfile.instance;
    final pick = await Navigator.of(context).push<AvatarPick>(
      MaterialPageRoute(
        builder: (_) => AvatarPickerScreen(initial: profile.choice, name: profile.name, title: 'Your profile'),
      ),
    );
    if (pick != null) await profile.update(name: pick.name, choice: pick.choice);
  }

  void _quick() {
    final profile = PlayerProfile.instance;
    final bot = randomAvatars(1, Random(), avoid: {profile.choice.avatarId}).single;
    final config = MatchConfig(
      quick: true,
      seats: [
        SeatConfig(name: profile.name.isEmpty ? 'You' : profile.name, corner: 3, avatar: profile.choice.encode()),
        SeatConfig(name: 'Bot ${bot.name}', corner: 1, isBot: true, avatar: AvatarChoice(bot.id).encode()),
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
                    const SizedBox(height: 18),
                    Center(child: _profileChip()),
                    const SizedBox(height: 18),
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

  Widget _profileChip() {
    return ListenableBuilder(
      listenable: PlayerProfile.instance,
      builder: (context, _) {
        final profile = PlayerProfile.instance;
        return Semantics(
          button: true,
          label: 'Your profile',
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('profile-chip'),
            onTap: _editProfile,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: KitColors.gold, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarView(choice: profile.choice, size: 44),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      profile.name.isEmpty ? 'Choose your avatar' : profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KitTheme.body(size: 15, weight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _menuButton(
String label, IconData icon, VoidCallback onTap, {bool primary = false}) =>
      primary ? GoldButton(label: label, icon: icon, onPressed: onTap) : SoftButton(label: label, icon: icon, onPressed: onTap);
}
