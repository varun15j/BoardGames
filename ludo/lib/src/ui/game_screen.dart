import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/game_kit.dart';

import '../game/models.dart';
import 'board_view.dart';
import 'controller.dart';
import 'pause_menu.dart';
import 'result_screen.dart';
import 'ludo_game.dart';
import 'storage.dart';

/// The match: pods, board, die and reactions.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.state,
    this.storage = const LudoStorage(),
    this.timing = const GameTiming(),
    this.graphics,
    this.tilt,
  });

  /// Defaults to the app-wide settings.
  final GraphicsSettings? graphics;

  /// Defaults to the device gyroscope.
  final TiltController? tilt;

  final GameState state;
  final LudoStorage storage;
  final GameTiming timing;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final LudoController c;
  StreamSubscription<LudoEvent>? _sub;
  final Map<int, (String, int)> _reactions = {};
  int _reactionId = 0;
  bool _leaving = false;
  late final GraphicsSettings _graphics = widget.graphics ?? GraphicsSettings.instance;
  late final TiltController _tilt = widget.tilt ?? TiltController();
  late final FrameMonitor _frames = FrameMonitor(settings: _graphics, onDowngrade: _announceDowngrade);
  late final AppLifecycleListener _lifecycle;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    c = LudoController(
      state: widget.state,
      timing: widget.timing,
      onSave: (s) => widget.storage.save(s),
      onGameOver: _gameOver,
    );
    _sub = c.events.listen((e) {
      if (e is ReactionEvent && mounted) {
        setState(() => _reactions[e.seat] = (e.emoji, ++_reactionId));
      }
    });
    widget.storage.loadSettings().then((s) {
      if (!mounted) return;
      c.soundOn = s.sound;
      c.hapticsOn = s.haptics;
    });
    _graphics.addListener(_applyGraphics);
    _graphics.ensureLoaded();
    _lifecycle = AppLifecycleListener(
      onShow: () {
        _visible = true;
        _applyGraphics();
      },
      onHide: () {
        _visible = false;
        _applyGraphics();
      },
    );
    c.start();
  }

  /// Starts or stops everything that depends on the graphics quality, so a
  /// change in the pause menu takes effect mid-match.
  void _applyGraphics() {
    if (!mounted) return;
    final optimized = _graphics.optimized;
    c.rollMs = optimized ? DieView.rollDuration.inMilliseconds + 100 : 950;
    if (optimized && _graphics.tiltEffect && !c.reduceMotion && _visible) {
      _tilt.start();
    } else {
      _tilt.stop();
    }
    optimized ? _frames.start() : _frames.stop();
    setState(() {});
  }

  void _announceDowngrade() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Switched to Performance mode for smoother play')),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    c.reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Applied after this frame: it may call setState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyGraphics());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _graphics.removeListener(_applyGraphics);
    _lifecycle.dispose();
    _frames.stop();
    if (widget.tilt == null) {
      _tilt.dispose();
    } else {
      _tilt.stop();
    }
    c.dispose();
    super.dispose();
  }

  Future<void> _gameOver() async {
    await widget.storage.clearSave();
    await Future<void>.delayed(widget.timing.ms(1000));
    if (!mounted || _leaving) return;
    _leaving = true;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(state: c.state, storage: widget.storage)),
    );
  }

  Future<void> _pause() async {
    if (c.phase == TurnPhase.over || _leaving) return;
    c.pause();
    final choice = await showDialog<PauseChoice>(
      context: context,
      builder: (_) => PauseMenu(
        controller: c,
        graphics: _graphics,
        onSettingsChanged: () => widget.storage.saveSettings(sound: c.soundOn, haptics: c.hapticsOn),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case PauseChoice.saveAndExit:
        await widget.storage.save(c.state);
        _exit();
      case PauseChoice.leave:
        await widget.storage.clearSave();
        _exit();
      case PauseChoice.resume || null:
        c.resume();
    }
  }

  void _exit() {
    _leaving = true;
    if (!mounted) return;
    LudoGame.popToHome(context);
  }

  Future<void> _react() async {
    final seat = c.state.turn;
    // Reactions come from the first human seat (or whoever holds the device).
    final from = !c.config.seats[seat].isBot ? seat : c.config.seats.indexWhere((s) => !s.isBot);
    final emoji = await showReactionsSheet(context);
    if (emoji != null && mounted) c.react(from < 0 ? 0 : from, emoji);
  }

  int? _seatAtCorner(int corner) {
    final i = c.config.seats.indexWhere((s) => s.corner == corner);
    return i < 0 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: NightBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) => Stack(
                children: [
                  Column(
                    children: [
                      _topBar(),
                      _podRow([0, 1]),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Center(
                            child: BoardView(controller: c, quality: _graphics.quality, tilt: _tilt),
                          ),
                        ),
                      ),
                      _podRow([3, 2]),
                      _controls(),
                    ],
                  ),
                  if (c.phase == TurnPhase.handoff) _handoff(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _roundButton(Icons.pause_rounded, 'Pause', _pause),
          Text(
            '${c.config.quick ? "Quick" : "Classic"} · ${c.config.seats.length} players'.toUpperCase(),
            style: KitTheme.body(size: 12, color: KitColors.muted),
          ),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, String label, VoidCallback onTap, {double size = 34}) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(size * 0.35),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, color: KitColors.ink, size: size * 0.55),
        ),
      ),
    );
  }

  Widget _podRow(List<int> corners) {
    Widget slot(int corner) {
      final seat = _seatAtCorner(corner);
      if (seat == null) return const SizedBox.shrink();
      final s = c.config.seats[seat];
      final style = kCornerStyles[corner];
      final active = c.state.turn == seat && c.phase != TurnPhase.over;
      final reaction = _reactions[seat];
      final right = corner == 1 || corner == 2;
      return ValueListenableBuilder<double>(
        valueListenable: c.timerFraction,
        builder: (context, fraction, _) => PlayerPod(
          name: s.name,
          color: style.color,
          active: active,
          timerFraction: !s.isBot && active ? fraction : null,
          subtitle: !s.isBot && active && fraction > 0 ? '${c.secondsLeft}s left' : c.notes[seat],
          homeCount: c.state.homeCount(seat),
          totalTokens: c.state.tokenCount,
          alignRight: right,
          reactionEmoji: reaction?.$1,
          reactionId: reaction?.$2 ?? 0,
          reduceMotion: c.reduceMotion,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(child: slot(corners[0])),
          const SizedBox(width: 8),
          Expanded(child: slot(corners[1])),
        ],
      ),
    );
  }

  Widget _controls() {
    final style = kCornerStyles[c.currentSeat.corner];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _roundButton(Icons.emoji_emotions_rounded, 'Send a reaction', _react, size: 48),
              DieView(
                value: c.dieValue,
                rollId: c.rollId,
                color: style.color,
                enabled: c.humanToRoll && !c.paused,
                onTap: c.rollTapped,
                reduceMotion: c.reduceMotion,
                quality: _graphics.quality,
                tilt: _tilt,
                throwHeight: MediaQuery.sizeOf(context).height * 0.30,
                onBounce: () {
                  if (c.hapticsOn) HapticFeedback.selectionClick();
                },
              ),
              _roundButton(Icons.pause_circle_outline_rounded, 'Pause', _pause, size: 48),
            ],
          ),
          Positioned(
            top: -30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
              child: Text(c.status, style: KitTheme.body(size: 12, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _handoff() {
    final s = c.currentSeat;
    final style = kCornerStyles[s.corner];
    return Positioned.fill(
      child: Container(
        color: KitColors.stage.withValues(alpha: 0.96),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pass to', style: KitTheme.body(size: 16, color: KitColors.muted)),
            const SizedBox(height: 14),
            PlayerToken(color: style.color, shape: style.shape, size: 84, quality: _graphics.quality),
            const SizedBox(height: 14),
            Text(s.name, textAlign: TextAlign.center, style: KitTheme.heading(size: 38, color: style.color)),
            const SizedBox(height: 28),
            SizedBox(width: 240, child: GoldButton(label: "I'm ready", onPressed: c.acknowledgeHandoff)),
          ],
        ),
      ),
    );
  }
}
