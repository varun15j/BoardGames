import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../game/models.dart';
import 'game_screen.dart';
import 'seat_avatar.dart';
import 'storage.dart';

enum SetupMode { bots, passAndPlay }

/// Match setup: 2-4 players, human or bot per seat, difficulty, length.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.mode, this.storage = const LudoStorage(), this.random, this.profile});

  /// Picks the bots' avatars; tests pass a seeded one.
  final Random? random;
  final PlayerProfile? profile;
  final SetupMode mode;
  final LudoStorage storage;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _players = 4;
  bool _quick = false;
  late List<SeatConfig> _seats;
  late final PlayerProfile _profile = widget.profile ?? PlayerProfile.instance;
  late final Random _rng = widget.random ?? Random();

  /// A distinct avatar for each of the four possible seats.
  late final List<Avatar> _spare = randomAvatars(4, _rng, avoid: {_profile.choice.avatarId});

  bool get _pass => widget.mode == SetupMode.passAndPlay;

  @override
  void initState() {
    super.initState();
    _seats = _build(_players, const []);
  }

  List<SeatConfig> _build(int count, List<SeatConfig> old) {
    final corners = MatchConfig.cornersFor(count);
    return [
      for (var i = 0; i < count; i++)
        () {
          final bot = i < old.length ? old[i].isBot : (_pass ? false : i > 0);
          final level = i < old.length ? old[i].level : BotLevel.normal;
          final prev = i < old.length ? old[i].name : null;
          final custom = prev != null && !prev.startsWith('Bot ') && prev != 'You' && !prev.startsWith('Player ');
          final name = custom
              ? prev
              : bot
                  ? 'Bot ${_spare[i].name}'
                  : _humanName(i);
          final avatar = i < old.length
              ? old[i].avatar
              : (i == 0 && !bot ? _profile.choice : AvatarChoice(_spare[i].id)).encode();
          return SeatConfig(name: name, corner: corners[i], isBot: bot, level: level, avatar: avatar);
        }(),
    ];
  }

  void _setSeat(int i, SeatConfig seat) => setState(() => _seats[i] = seat);

  String _humanName(int i) {
    if (i == 0 && _profile.name.isNotEmpty) return _profile.name;
    return _pass || i > 0 ? 'Player ${i + 1}' : 'You';
  }

  Future<void> _pickAvatar(int i) async {
    final seat = _seats[i];
    final pick = await Navigator.of(context).push<AvatarPick>(
      MaterialPageRoute(
        builder: (_) => AvatarPickerScreen(
          initial: seatAvatar(seat),
          name: seat.name,
          title: 'Seat ${i + 1}',
        ),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      _seats[i] = _seats[i].copyWith(
        name: pick.name.isEmpty ? seat.name : pick.name,
        avatar: pick.choice.encode(),
      );
      _nameVersion++;
    });
  }

  int _nameVersion = 0;

  void _toggleBot(int i, bool bot) {
    final s = _seats[i];
    _setSeat(i, s.copyWith(isBot: bot, name: bot ? 'Bot ${seatAvatar(s).avatar.name}' : _humanName(i)));
  }

  void _start() {
    final config = MatchConfig(seats: List.of(_seats), quick: _quick, passAndPlay: _pass);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GameScreen(state: GameState.fresh(config), storage: widget.storage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasHuman = _seats.any((s) => !s.isBot);
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: KitColors.ink),
                    ),
                    Text(_pass ? 'Pass & Play' : 'vs Bots', style: KitTheme.heading(size: 26)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _label('Players'),
                    SegmentedPills<int>(
                      options: const [2, 3, 4],
                      value: _players,
                      labelOf: (n) => '$n players',
                      onChanged: (n) => setState(() {
                        _players = n;
                        _seats = _build(n, _seats);
                      }),
                    ),
                    const SizedBox(height: 16),
                    _label('Seats'),
                    for (var i = 0; i < _seats.length; i++) ...[_seatCard(i), const SizedBox(height: 8)],
                    const SizedBox(height: 8),
                    _label('Length'),
                    SegmentedPills<bool>(
                      options: const [false, true],
                      value: _quick,
                      labelOf: (q) => q ? 'Quick · 2 tokens' : 'Classic · 4 tokens',
                      onChanged: (q) => setState(() => _quick = q),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: GoldButton(label: 'Start match', onPressed: hasHuman ? _start : null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(t.toUpperCase(), style: KitTheme.body(size: 11, weight: FontWeight.w800, color: KitColors.muted)),
      );

  Widget _seatCard(int i) {
    final seat = _seats[i];
    final style = kCornerStyles[seat.corner];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.color.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Choose avatar for ${seat.name}',
                excludeSemantics: true,
                child: GestureDetector(
                  key: ValueKey('seat-avatar-$i'),
                  onTap: () => _pickAvatar(i),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                        child: AvatarView(choice: seatAvatar(seat), size: 38),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: TokenDisc(color: style.color, shape: style.shape, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: seat.isBot
                    ? Text(seat.name, style: KitTheme.body(size: 15, weight: FontWeight.w800))
                    : TextFormField(
                        key: ValueKey('name-$i-${seat.isBot}-$_nameVersion'),
                        initialValue: seat.name,
                        maxLength: 12,
                        style: KitTheme.body(size: 15, weight: FontWeight.w800),
                        decoration: const InputDecoration(
                          isDense: true,
                          counterText: '',
                          border: InputBorder.none,
                          hintText: 'Name',
                        ),
                        onChanged: (v) => _seats[i] = _seats[i].copyWith(name: v.trim().isEmpty ? 'Player ${i + 1}' : v.trim()),
                      ),
              ),
              SizedBox(
                width: 138,
                child: SegmentedPills<bool>(
                  options: const [false, true],
                  value: seat.isBot,
                  labelOf: (b) => b ? 'Bot' : 'Human',
                  onChanged: (b) => _toggleBot(i, b),
                ),
              ),
            ],
          ),
          if (seat.isBot) ...[
            const SizedBox(height: 8),
            SegmentedPills<BotLevel>(
              options: BotLevel.values,
              value: seat.level,
              labelOf: (l) => l == BotLevel.easy ? 'Easy' : 'Normal',
              onChanged: (l) => _setSeat(i, seat.copyWith(level: l)),
            ),
          ],
        ],
      ),
    );
  }
}
