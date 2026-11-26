/// The host's side of a room. Only the host runs the rules: players send
/// what they want to do, the host checks it against the current turn and
/// tells everyone what happened.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:game_kit/game_kit.dart';

import '../game/models.dart';
import '../ui/controller.dart';
import 'channel.dart';
import 'events.dart';
import 'protocol.dart';
import 'snapshot.dart';

enum SeatKind { open, host, player, bot }

class LobbySeat {
  LobbySeat([this.kind = SeatKind.open]);
  SeatKind kind;
  String name = '';
  String avatar = '';
  bool ready = false;
  bool connected = false;
  String? token;
  Channel? channel;
  Timer? grace;
  DateTime? lastHeard;

  Map<String, Object?> toJson(int index) => {
        'seat': index,
        'kind': kind.name,
        'name': name,
        'avatar': avatar,
        'ready': ready,
        'connected': connected,
      };
}

class HostRoom extends ChangeNotifier {
  HostRoom({
    required this.code,
    required String name,
    required String avatar,
    Random? random,
    this.timing = const GameTiming(),
    this.grace = const Duration(seconds: 60),
    this.turnSeconds = 15,
  })  : _random = random ?? Random.secure(),
        seats = List.generate(4, (_) => LobbySeat()) {
    seats[0]
      ..kind = SeatKind.host
      ..name = cleanName(name, 'Host')
      ..avatar = _cleanAvatar(avatar)
      ..ready = true
      ..connected = true;
  }

  final String code;
  final GameTiming timing;

  /// How long a dropped player may take to come back before a bot plays.
  final Duration grace;
  final int turnSeconds;
  final Random _random;
  final List<LobbySeat> seats;

  int _players = 2;
  bool _fillBots = false;
  BotLevel _botLevel = BotLevel.normal;
  LudoController? controller;
  StreamSubscription<LudoEvent>? _events;
  bool _closed = false;

  int get players => _players;
  bool get fillBots => _fillBots;
  BotLevel get botLevel => _botLevel;
  bool get started => controller != null;

  List<LobbySeat> get active => seats.sublist(0, _players);

  /// Avatars travel as built-in ids only; photos stay on their phone.
  static String _cleanAvatar(String avatar) => kAvatarsById.containsKey(avatar) ? avatar : AvatarChoice.fallbackId;

  void setPlayers(int count) {
    if (started || count < 2 || count > 4) return;
    // Never push out someone who has joined.
    for (var i = count; i < 4; i++) {
      if (seats[i].kind == SeatKind.player) return;
    }
    _players = count;
    _lobbyChanged();
  }

  void setFillBots(bool value, [BotLevel? level]) {
    if (started) return;
    _fillBots = value;
    _botLevel = level ?? _botLevel;
    _lobbyChanged();
  }

  bool get canStart =>
      !started &&
      active.every((s) => switch (s.kind) {
            SeatKind.host => true,
            SeatKind.player => s.ready && s.connected,
            SeatKind.open || SeatKind.bot => _fillBots,
          });

  // ------------------------------------------------------------- players

  /// Takes a new connection; it must say hello first.
  void accept(Channel channel) {
    int? seat;
    var bad = 0;
    channel.messages.listen(
      (text) {
        final NetMessage message;
        try {
          message = NetMessage.decode(text);
          if (seat == null) {
            if (message.type != 'hello') return;
            seat = _hello(channel, message);
            return;
          }
          _handle(seat!, channel, message);
        } on ProtocolError {
          // Ignore the odd bad message, drop a connection that keeps sending them.
          if (++bad > 20) channel.close();
        }
      },
      onDone: () {
        if (seat != null) _lost(seat!, channel);
      },
      onError: (Object _) {},
    );
  }

  int? _hello(Channel channel, NetMessage hello) {
    if (_closed) return null;
    final token = hello.data['token'];
    var index = -1;
    if (token is String) {
      index = seats.indexWhere((s) => s.token == token);
    }
    if (index < 0) {
      if (started) return _refuse(channel, 'The game has already started.');
      index = seats.indexWhere((s) => s.kind == SeatKind.open);
      if (index < 0 || index >= _players) return _refuse(channel, 'The room is full.');
      seats[index]
        ..kind = SeatKind.player
        ..name = cleanName(hello.data['name'] as String?, 'Player ${index + 1}')
        ..avatar = _cleanAvatar(hello.data['avatar'] is String ? hello.data['avatar']! as String : '')
        ..ready = false
        ..token = newSeatToken(_random);
    }
    final seat = seats[index];
    seat.grace?.cancel();
    final old = seat.channel;
    seat
      ..channel = channel
      ..connected = true;
    old?.close();
    channel.send(NetMessage.welcome(seat: index, seatToken: seat.token!, code: code).encode());
    _lobbyChanged();
    if (started) {
      controller!.giveBack(index);
      channel.send(NetMessage.start(controller!.config.toJson()).encode());
      channel.send(NetMessage.snapshot(_snapshot().toJson()).encode());
    }
    return index;
  }

  int? _refuse(Channel channel, String reason) {
    channel.send(NetMessage.error(reason).encode());
    channel.close();
    return null;
  }

  void _handle(int index, Channel channel, NetMessage message) {
    final seat = seats[index];
    if (!identical(seat.channel, channel)) return; // replaced by a rejoin
    final game = controller;
    switch (message.type) {
      case 'ping':
        channel.send(NetMessage.pong.encode());
      case 'ready':
        if (game == null) {
          seat.ready = message.field<bool>('ready');
          _lobbyChanged();
        }
      case 'roll':
        game?.remoteRoll(index); // out of turn or repeated: ignored
      case 'pick':
        game?.remotePick(index, message.field<int>('token'));
      case 'react':
        final emoji = message.field<String>('emoji');
        if (game != null && kReactionEmoji.contains(emoji)) game.react(index, emoji);
      case 'leave':
        _lost(index, channel, left: true);
    }
  }

  void _lost(int index, Channel channel, {bool left = false}) {
    final seat = seats[index];
    if (_closed || !identical(seat.channel, channel)) return;
    seat
      ..channel = null
      ..connected = false;
    channel.close();
    if (!started) {
      seats[index] = LobbySeat();
    } else if (left) {
      seat.token = null;
      controller!.takeOver(index);
    } else {
      seat.grace = Timer(grace, () => controller?.takeOver(index));
    }
    _lobbyChanged();
  }

  // ---------------------------------------------------------------- game

  /// Builds the match from the lobby and starts it.
  LudoController start({bool soundOn = true, bool hapticsOn = true}) {
    assert(canStart);
    final corners = MatchConfig.cornersFor(_players);
    final used = {for (final s in active) s.avatar};
    final spare = [for (final a in kAvatars) if (!used.contains(a.id)) a]..shuffle(_random);
    final configs = <SeatConfig>[];
    for (var i = 0; i < _players; i++) {
      final seat = seats[i];
      if (seat.kind == SeatKind.open) {
        final avatar = spare.removeLast();
        seat
          ..kind = SeatKind.bot
          ..name = 'Bot ${avatar.name}'
          ..avatar = avatar.id;
      }
      configs.add(SeatConfig(
        name: seat.name,
        corner: corners[i],
        isBot: seat.kind == SeatKind.bot,
        level: _botLevel,
        avatar: AvatarChoice(seat.avatar).encode(),
      ));
    }
    final game = controller = LudoController(
      state: GameState.fresh(MatchConfig(seats: configs)),
      random: _random,
      timing: timing,
      turnSeconds: turnSeconds,
      localSeats: {0},
      handoffs: false,
      soundOn: soundOn,
      hapticsOn: hapticsOn,
    );
    _events = game.events.listen((e) => _broadcast(encodeEvent(e)));
    _broadcast(NetMessage.start(game.config.toJson()));
    game.addListener(_sendSnapshot);
    _lobbyChanged();
    game.start();
    return game;
  }

  Snapshot _snapshot() {
    final game = controller!;
    final state = game.state;
    return Snapshot(
      steps: state.steps,
      display: game.display,
      turn: state.turn,
      finishOrder: state.finishOrder,
      captures: state.captures,
      sixes: state.sixesRolled,
      lastRoll: state.lastRoll,
      phase: game.phase.name,
      die: game.dieValue,
      rollId: game.rollId,
      movable: game.movable,
      flying: [...game.flying],
      status: game.status,
      notes: game.notes,
      timerMs: game.timerLeftMs,
      timerTotalMs: game.timerTotalMs,
      takenOver: [...game.takenOver],
    );
  }

  void _sendSnapshot() => _broadcast(NetMessage.snapshot(_snapshot().toJson()));

  void _broadcast(NetMessage message) {
    final text = message.encode();
    for (final seat in seats) {
      seat.channel?.send(text);
    }
  }

  void _lobbyChanged() {
    if (_closed) return;
    _broadcast(NetMessage.lobby([for (var i = 0; i < _players; i++) seats[i].toJson(i)]));
    notifyListeners();
  }

  /// Ends the room for everyone.
  Future<void> close([String reason = 'The host closed the room.']) async {
    if (_closed) return;
    _closed = true;
    _broadcast(NetMessage.end(reason));
    await _events?.cancel();
    for (final seat in seats) {
      seat.grace?.cancel();
      await seat.channel?.close();
      seat.channel = null;
    }
    controller?.removeListener(_sendSnapshot);
    controller?.dispose();
  }
}
