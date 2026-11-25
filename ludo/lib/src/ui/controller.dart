import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/game_kit.dart';

import '../game/board.dart';
import '../game/bot.dart';
import '../game/models.dart';
import '../game/rules.dart';

enum TurnPhase { handoff, awaitingRoll, rolling, choosing, moving, over }

/// Scales every pause in the game flow. Tests use [instant].
class GameTiming {
  const GameTiming({this.scale = 1});
  final double scale;
  static const instant = GameTiming(scale: 0);
  Duration ms(num v) => Duration(milliseconds: (v * scale).round());
}

/// One-shot happenings the board and screen show as animations.
sealed class LudoEvent {
  const LudoEvent();
}

class CaptureEvent extends LudoEvent {
  const CaptureEvent(this.at, this.victims, this.bySeat);
  final BoardPoint at;
  final List<TokenRef> victims;
  final int bySeat;
}

class SafeEvent extends LudoEvent {
  const SafeEvent(this.at);
  final BoardPoint at;
}

class HomeEvent extends LudoEvent {
  const HomeEvent(this.seat);
  final int seat;
}

class BannerEvent extends LudoEvent {
  const BannerEvent(this.text, this.color);
  final String text;
  final Color color;
}

class ReactionEvent extends LudoEvent {
  const ReactionEvent(this.seat, this.emoji);
  final int seat;
  final String emoji;
}

/// A dashed landing marker shown for a token that can move.
class GhostInfo {
  const GhostInfo(this.token, this.at, this.capture);
  final TokenRef token;
  final BoardPoint at;
  final bool capture;
}

/// Runs a match: rolls, moves, bots, the turn timer and animation pacing.
/// The game rules themselves live in [Rules].
class LudoController extends ChangeNotifier {
  LudoController({
    required GameState state,
    Random? random,
    this.timing = const GameTiming(),
    this.turnSeconds = 15,
    this.onSave,
    this.onGameOver,
    this.soundOn = true,
    this.hapticsOn = true,
    this.reduceMotion = false,
  })  : state = state,
        _rng = random ?? Random(),
        display = [for (final r in state.steps) List<int>.of(r)],
        notes = List.filled(state.seatCount, '');

  final GameState state;
  final Random _rng;
  final GameTiming timing;
  final int turnSeconds;
  final void Function(GameState)? onSave;
  final VoidCallback? onGameOver;

  bool soundOn;
  bool hapticsOn;
  bool reduceMotion;

  /// Token steps as currently drawn (they lag behind [state] while hopping).
  final List<List<int>> display;
  final List<String> notes;

  TurnPhase phase = TurnPhase.awaitingRoll;
  int dieValue = 6;
  int rollId = 0;
  String status = '';
  List<int> movable = const [];
  List<GhostInfo> ghosts = const [];
  Set<TokenRef> flying = {};
  bool get paused => _paused;
  final ValueNotifier<double> timerFraction = ValueNotifier(0);

  final StreamController<LudoEvent> _events = StreamController.broadcast();
  Stream<LudoEvent> get events => _events.stream;

  int _gen = 0;
  bool _paused = false;
  bool _disposed = false;
  int _lastActiveSeat = -1;
  Timer? _ticker;
  int _leftMs = 0;
  int _totalMs = 1;
  VoidCallback? _onExpire;

  MatchConfig get config => state.config;
  SeatConfig get currentSeat => config.seats[state.turn];
  bool get humanToRoll => phase == TurnPhase.awaitingRoll && !currentSeat.isBot;
  bool get humanToPick => phase == TurnPhase.choosing && !currentSeat.isBot;
  double get _motion => reduceMotion ? 0.3 : 1;

  /// Begins (or resumes) play from the current state.
  void start() {
    _gen++;
    _beginTurn();
  }

  // ---------------------------------------------------------------- flow

  void _beginTurn() {
    if (_disposed) return;
    if (Rules.isOver(state)) {
      _finish();
      return;
    }
    final seat = state.turn;
    for (var i = 0; i < notes.length; i++) {
      notes[i] = i == seat ? '' : (state.finishOrder.contains(i) ? 'Finished' : 'Waiting');
    }
    onSave?.call(state);
    final needsHandoff = config.humanCount > 1 && !currentSeat.isBot && _lastActiveSeat != seat;
    _lastActiveSeat = seat;
    if (needsHandoff) {
      phase = TurnPhase.handoff;
      status = 'Pass to ${currentSeat.name}';
      notifyListeners();
      return;
    }
    _awaitRoll();
  }

  /// Pass-and-play: the next player confirms they have the device.
  void acknowledgeHandoff() {
    if (phase != TurnPhase.handoff) return;
    _awaitRoll();
  }

  void _awaitRoll() {
    final g = _gen;
    phase = TurnPhase.awaitingRoll;
    movable = const [];
    ghosts = const [];
    if (currentSeat.isBot) {
      status = '${currentSeat.name} is rolling…';
      notes[state.turn] = 'Rolling';
      notifyListeners();
      _wait(600).then((_) {
        if (g == _gen) _roll();
      });
    } else {
      status = state.sixStreak > 0 ? 'Bonus roll! Tap the die' : 'Your turn · tap the die';
      if (config.humanCount > 1) status = '${currentSeat.name} · tap the die';
      notifyListeners();
      _startTimer(turnSeconds * 1000, _roll);
    }
  }

  /// The human taps the die.
  void rollTapped() {
    if (humanToRoll && !_paused) _roll();
  }

  Future<void> _roll() async {
    if (phase != TurnPhase.awaitingRoll) return;
    final g = _gen;
    _stopTimer();
    phase = TurnPhase.rolling;
    dieValue = 1 + _rng.nextInt(6);
    rollId++;
    notes[state.turn] = 'Rolling';
    _feedback(heavy: false);
    notifyListeners();
    await _wait(reduceMotion ? 120 : 950);
    if (g != _gen) return;
    final roll = dieValue;
    notes[state.turn] = 'Rolled $roll';
    final outcome = Rules.registerRoll(state, roll);
    switch (outcome) {
      case RollOutcome.threeSixes:
        status = 'Three 6s in a row · turn over';
        _emit(const BannerEvent('Three 6s!', Color(0xFF3A4A70)));
        notifyListeners();
        await _wait(1100);
        if (g != _gen) return;
        Rules.endTurn(state);
        _beginTurn();
      case RollOutcome.noMoves:
        status = '${currentSeat.name} can\'t move';
        notes[state.turn] = 'No move';
        notifyListeners();
        await _wait(900);
        if (g != _gen) return;
        Rules.endTurn(state);
        _beginTurn();
      case RollOutcome.canMove:
        await _chooseMove(g, roll);
    }
  }

  Future<void> _chooseMove(int g, int roll) async {
    final moves = Rules.legalMoves(state, roll);
    final seat = currentSeat;
    if (seat.isBot) {
      notifyListeners();
      await _wait(450);
      if (g != _gen) return;
      await _move(LudoBot.chooseFrom(state, moves, roll, seat.level, _rng), g);
      return;
    }
    if (moves.length == 1) {
      status = 'Only one move · playing it';
      notifyListeners();
      await _wait(500);
      if (g != _gen) return;
      await _move(moves.first, g);
      return;
    }
    phase = TurnPhase.choosing;
    status = 'Tap a glowing token';
    movable = moves;
    ghosts = [
      for (final t in moves)
        GhostInfo(
          TokenRef(state.turn, t),
          _pointFor(state.turn, t, Rules.targetStep(state.steps[state.turn][t], roll)),
          Rules.victimsAt(state, state.turn, Rules.targetStep(state.steps[state.turn][t], roll)).isNotEmpty,
        ),
    ];
    notifyListeners();
    _startTimer(max(5000, turnSeconds * 1000 ~/ 2), () {
      if (phase == TurnPhase.choosing) _move(LudoBot.best(state, moves, roll), g);
    });
  }

  /// The human taps a glowing token.
  void selectToken(int token) {
    if (!humanToPick || _paused || !movable.contains(token)) return;
    _stopTimer();
    _move(token, _gen);
  }

  Future<void> _move(int token, int g) async {
    if (g != _gen) return;
    _stopTimer();
    final seat = state.turn;
    final roll = state.lastRoll!;
    phase = TurnPhase.moving;
    movable = const [];
    ghosts = const [];
    final res = Rules.applyMove(state, token, roll);
    notifyListeners();

    if (res.from < 0) {
      display[seat][token] = 0;
      _feedback(heavy: false);
      notifyListeners();
      await _wait(260);
    } else {
      for (var k = res.from + 1; k <= res.to; k++) {
        if (g != _gen) return;
        display[seat][token] = k;
        notifyListeners();
        await _wait(165);
      }
    }
    if (g != _gen) return;

    final at = _pointFor(seat, token, res.to);
    if (res.captured.isNotEmpty) {
      status = 'Captured!';
      _emit(CaptureEvent(at, res.captured, seat));
      _emit(const BannerEvent('Captured!', KitColors.danger));
      _feedback(heavy: true);
      for (final v in res.captured) {
        display[v.seat][v.token] = -1;
      }
      flying = {...res.captured};
      notifyListeners();
      _botReactions(seat, res.captured);
      await _wait(650);
      if (g != _gen) return;
      flying = {};
    } else if (res.reachedHome) {
      _emit(HomeEvent(seat));
      _emit(BannerEvent('Home!', kCornerStyles[state.cornerOf(seat)].color));
      _feedback(heavy: false);
      await _wait(600);
      if (g != _gen) return;
    } else if (res.landedOnSafe && res.to > 0) {
      _emit(SafeEvent(at));
    }

    if (res.playerFinished) {
      _emit(BannerEvent('${config.seats[seat].name} finished!', kCornerStyles[state.cornerOf(seat)].color));
      await _wait(700);
      if (g != _gen) return;
    }
    if (Rules.isOver(state)) {
      _finish();
      return;
    }
    if (res.bonusRoll) {
      notifyListeners();
      await _wait(450);
      if (g != _gen) return;
      _beginTurn();
    } else {
      Rules.endTurn(state);
      _beginTurn();
    }
  }

  void _finish() {
    _stopTimer();
    phase = TurnPhase.over;
    status = 'Game over';
    notifyListeners();
    onGameOver?.call();
  }

  void _botReactions(int by, List<TokenRef> victims) {
    final g = _gen;
    Future<void> later(int ms, int seat, String e) async {
      await _wait(ms);
      if (g == _gen && !_disposed) _emit(ReactionEvent(seat, e));
    }

    final v = victims.first.seat;
    if (config.seats[v].isBot) later(300, v, '😮');
    if (config.seats[by].isBot) later(700, by, '🔥');
  }

  BoardPoint _pointFor(int seat, int token, int step) =>
      Board.pointFor(state.cornerOf(seat), token, step, state.tokenCount);

  /// Where token [token] of [seat] is drawn right now.
  BoardPoint displayPoint(int seat, int token) => _pointFor(seat, token, display[seat][token]);

  /// A reaction from a player (the sender picks an emoji).
  void react(int seat, String emoji) {
    _emit(ReactionEvent(seat, emoji));
    if (config.seats.length > 1) {
      final others = [for (var i = 0; i < config.seats.length; i++) if (i != seat && config.seats[i].isBot) i];
      if (others.isNotEmpty && _rng.nextDouble() < 0.6) {
        final g = _gen;
        final who = others[_rng.nextInt(others.length)];
        _wait(1100).then((_) {
          if (g == _gen && !_disposed) _emit(ReactionEvent(who, const ['😂', '👍', '🔥'][_rng.nextInt(3)]));
        });
      }
    }
  }

  // --------------------------------------------------------------- timer

  void _startTimer(int ms, VoidCallback onExpire) {
    _stopTimer();
    _totalMs = ms;
    _leftMs = ms;
    _onExpire = onExpire;
    timerFraction.value = 1;
    if (timing.scale == 0) return; // tests drive the flow themselves
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_paused) return;
      _leftMs -= 50;
      timerFraction.value = max(0, _leftMs / _totalMs);
      if (_leftMs <= 0) {
        final f = _onExpire;
        _stopTimer();
        f?.call();
      }
    });
  }

  void _stopTimer() {
    _ticker?.cancel();
    _ticker = null;
    _onExpire = null;
    timerFraction.value = 0;
  }

  /// Seconds left on the human's clock, for the pod caption.
  int get secondsLeft => (_leftMs / 1000).ceil().clamp(0, 99);

  // ------------------------------------------------------------- helpers

  Future<void> _wait(num ms) async {
    final g = _gen;
    await Future<void>.delayed(timing.ms(ms * _motion));
    while (_paused && g == _gen && !_disposed) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void _emit(LudoEvent e) {
    if (!_disposed) _events.add(e);
  }

  void _feedback({required bool heavy}) {
    if (hapticsOn) {
      heavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    }
    if (soundOn) SystemSound.play(SystemSoundType.click);
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    notifyListeners();
  }

  /// Stops all pending work; the controller can't be used afterwards.
  @override
  void dispose() {
    _disposed = true;
    _gen++;
    _stopTimer();
    _events.close();
    timerFraction.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
