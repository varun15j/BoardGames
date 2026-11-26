/// A player's side of a room: shows what the host says and sends intents.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/board.dart';
import '../game/models.dart';
import '../game/rules.dart';
import '../ui/controller.dart';
import 'channel.dart';
import 'events.dart';
import 'protocol.dart';
import 'snapshot.dart';

class ClientSeat {
  const ClientSeat({required this.seat, required this.kind, required this.name, required this.avatar, required this.ready, required this.connected});
  final int seat;
  final String kind;
  final String name;
  final String avatar;
  final bool ready;
  final bool connected;
}

class ClientRoom extends ChangeNotifier {
  ClientRoom({required this.name, required this.avatar});

  final String name;
  final String avatar;

  Channel? _channel;
  StreamSubscription<String>? _subscription;
  Timer? _ping;
  int? seat;
  String? seatToken;
  String? code;
  List<ClientSeat> lobby = const [];
  RemoteLudoController? controller;

  /// Why the room is over for this player; null while it is open.
  final ValueNotifier<String?> ended = ValueNotifier(null);
  bool _disposed = false;

  bool get ready => lobby.any((s) => s.seat == seat && s.ready);

  /// Joins (or rejoins) over [channel].
  void connect(Channel channel) {
    _subscription?.cancel();
    _channel = channel;
    _subscription = channel.messages.listen(
      (text) {
        try {
          _handle(NetMessage.decode(text));
        } on ProtocolError {
          // A message we cannot read is skipped.
        } on FormatException {
          // Likewise a snapshot of the wrong shape.
        }
      },
      onDone: () {
        if (identical(_channel, channel)) _end('Lost the connection to the host.');
      },
    );
    send(NetMessage.hello(name: name, avatar: avatar, seatToken: seatToken));
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 3), (_) => send(NetMessage.ping));
  }

  void send(NetMessage message) => _channel?.send(message.encode());

  void setReady(bool value) => send(NetMessage.ready(value));

  void _handle(NetMessage m) {
    if (_disposed) return;
    switch (m.type) {
      case 'welcome':
        seat = m.field<int>('seat');
        seatToken = m.field<String>('token');
        code = m.field<String>('code');
        notifyListeners();
      case 'lobby':
        lobby = [
          for (final raw in m.field<List<Object?>>('seats'))
            if (raw is Map)
              ClientSeat(
                seat: raw['seat'] as int? ?? 0,
                kind: raw['kind'] as String? ?? 'open',
                name: cleanName(raw['name'] as String?, ''),
                avatar: raw['avatar'] as String? ?? '',
                ready: raw['ready'] == true,
                connected: raw['connected'] == true,
              ),
        ];
        notifyListeners();
      case 'start':
        if (controller != null || seat == null) return;
        final config = MatchConfig.fromJson(m.field<Map<String, Object?>>('config'));
        if (seat! >= config.seats.length) throw const ProtocolError('bad config');
        controller = RemoteLudoController(GameState.fresh(config), seat!, send);
        notifyListeners();
      case 'snapshot':
        controller?.apply(Snapshot.fromJson(m.data));
      case 'event':
        final game = controller;
        if (game == null) return;
        final event = decodeEvent(m, game.config.seats.length);
        if (event != null) game.emitRemote(event);
      case 'error':
        _end(m.field<String>('reason'));
      case 'end':
        _end(m.field<String>('reason'));
    }
  }

  void _end(String reason) {
    if (_disposed || ended.value != null) return;
    _ping?.cancel();
    ended.value = reason;
    notifyListeners();
  }

  /// Leaves the room.
  Future<void> leave() async {
    if (_disposed) return;
    send(NetMessage.leave);
    _disposed = true;
    _ping?.cancel();
    await _subscription?.cancel();
    await _channel?.close();
    controller?.dispose();
  }
}

/// A controller that mirrors the host's match. It never runs the rules; taps
/// become requests to the host.
class RemoteLudoController extends LudoController {
  RemoteLudoController(GameState state, this.seat, this._send)
      : super(state: state, localSeats: {seat}, handoffs: false);

  final int seat;
  final void Function(NetMessage) _send;
  Timer? _countdown;
  int _msLeft = 0;

  @override
  void start() {}

  @override
  void rollTapped() {
    if (canRollHere) _send(NetMessage.roll);
  }

  @override
  void selectToken(int token) {
    if (canPickHere && movable.contains(token)) _send(NetMessage.pick(token));
  }

  @override
  void react(int seat, String emoji) => _send(NetMessage.react(emoji));

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  int get secondsLeft => (_msLeft / 1000).ceil().clamp(0, 99);

  void apply(Snapshot s) {
    final n = state.seatCount;
    if (s.steps.length != n || s.display.length != n || s.turn < 0 || s.turn >= n || s.notes.length != n) {
      throw const FormatException('snapshot does not match the match');
    }
    for (var i = 0; i < n; i++) {
      if (s.steps[i].length != state.tokenCount || s.display[i].length != state.tokenCount) {
        throw const FormatException('wrong token count');
      }
      state.steps[i].setAll(0, s.steps[i]);
      display[i].setAll(0, s.display[i]);
      notes[i] = s.notes[i];
    }
    state
      ..turn = s.turn
      ..lastRoll = s.lastRoll;
    state.finishOrder
      ..clear()
      ..addAll(s.finishOrder);
    state.captures.setAll(0, s.captures);
    state.sixesRolled.setAll(0, s.sixes);
    takenOver
      ..clear()
      ..addAll(s.takenOver);
    final wasOver = phase == TurnPhase.over;
    phase = TurnPhase.values.byName(s.phase);
    dieValue = s.die;
    rollId = s.rollId;
    movable = s.movable;
    flying = {...s.flying};
    status = _statusFor(s);
    ghosts = [
      if (phase == TurnPhase.choosing && s.lastRoll != null)
        for (final t in movable) _ghost(t, s.lastRoll!),
    ];
    _runClock(s.timerMs, s.timerTotalMs);
    notifyListeners();
    if (!wasOver && phase == TurnPhase.over) onGameOver?.call();
  }

  /// The host's wording is for the host; say it from this player's side.
  String _statusFor(Snapshot s) {
    final who = config.seats[s.turn].name;
    final mine = s.turn == seat && !takenOver.contains(seat);
    return switch (phase) {
      TurnPhase.awaitingRoll => mine ? 'Your turn · tap the die' : '$who\'s turn',
      TurnPhase.choosing => mine ? 'Tap a glowing token' : '$who is choosing',
      _ => s.status,
    };
  }

  GhostInfo _ghost(int token, int roll) {
    final to = Rules.targetStep(state.steps[state.turn][token], roll);
    return GhostInfo(
      TokenRef(state.turn, token),
      Board.pointFor(state.cornerOf(state.turn), token, to, state.tokenCount),
      Rules.victimsAt(state, state.turn, to).isNotEmpty,
    );
  }

  void _runClock(int left, int total) {
    _countdown?.cancel();
    _msLeft = left;
    timerFraction.value = total <= 0 ? 0 : (left / total).clamp(0.0, 1.0);
    if (left <= 0) return;
    _countdown = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _msLeft -= 100;
      if (_msLeft <= 0) timer.cancel();
      timerFraction.value = (_msLeft / total).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }
}
