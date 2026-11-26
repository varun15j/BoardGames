import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/ludo.dart';
import 'package:ludo/src/net/events.dart';
import 'package:ludo/src/ui/controller.dart';

Future<void> _settle([int n = 5]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Table {
  _Table({int players = 4, int clientCount = 3, Duration grace = const Duration(milliseconds: 30), bool bots = false}) {
    host = HostRoom(code: 'ABCD', name: 'Hana', avatar: 'cat', random: Random(5), timing: GameTiming.instant, grace: grace);
    host.setPlayers(players);
    if (bots) host.setFillBots(true);
    for (var i = 0; i < clientCount; i++) {
      join('P${i + 1}');
    }
  }

  late final HostRoom host;
  final List<ClientRoom> clients = [];
  final List<MemoryChannel> pipes = [];

  ClientRoom join(String name, {ClientRoom? existing}) {
    final (near, far) = MemoryChannel.pair();
    final client = existing ?? ClientRoom(name: name, avatar: 'frog');
    host.accept(far);
    client.connect(near);
    if (existing == null) {
      clients.add(client);
      pipes.add(near);
    } else {
      pipes[clients.indexOf(client)] = near;
    }
    return client;
  }

  Future<void> readyAll() async {
    await _settle();
    for (final c in clients) {
      c.setReady(true);
    }
    await _settle();
  }

  /// Every human, host included, plays whenever it is their turn.
  Future<void> playToEnd() async {
    final game = host.controller!;
    var guard = 0;
    while (game.phase != TurnPhase.over && guard++ < 400000) {
      if (game.canRollHere) {
        game.rollTapped();
      } else if (game.canPickHere) {
        game.selectToken(game.movable.first);
      }
      for (final client in clients) {
        final mirror = client.controller;
        if (mirror == null) continue;
        if (mirror.canRollHere) {
          mirror.rollTapped();
        } else if (mirror.canPickHere) {
          mirror.selectToken(mirror.movable.first);
        }
      }
      await Future<void>.delayed(Duration.zero);
    }
    await _settle(20);
  }

  Future<void> close() async {
    for (final c in clients) {
      await c.leave();
    }
    await host.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('protocol', () {
    test('messages survive the round trip', () {
      for (final m in [
        NetMessage.hello(name: 'Asha', avatar: 'owl', seatToken: 't'),
        NetMessage.ready(true),
        NetMessage.roll,
        NetMessage.pick(2),
        NetMessage.react('🔥'),
        NetMessage.welcome(seat: 1, seatToken: 'abc', code: 'WXYZ'),
        NetMessage.end('bye'),
      ]) {
        final back = NetMessage.decode(m.encode());
        expect(back.type, m.type);
        expect(back.data, m.data);
      }
    });

    test('junk, other versions and huge messages are refused', () {
      for (final bad in ['nope', '[1]', '{"t":"roll"}', '{"v":2,"t":"roll"}', '{"v":1}', '{"v":1,"t":"x","a":"${'a' * 30000}"}']) {
        expect(() => NetMessage.decode(bad), throwsA(isA<ProtocolError>()), reason: bad.substring(0, min(20, bad.length)));
      }
      expect(() => NetMessage.decode('{"v":1,"t":"pick","token":"1"}').field<int>('token'), throwsA(isA<ProtocolError>()));
    });

    test('events and snapshots round trip', () {
      const capture = CaptureEvent(BoardPoint(1.5, 2.5), [TokenRef(1, 0)], 0);
      final back = decodeEvent(NetMessage.decode(encodeEvent(capture).encode()), 2)! as CaptureEvent;
      expect(back.at, capture.at);
      expect(back.victims, capture.victims);
      expect(decodeEvent(NetMessage.event('reaction', {'seat': 9, 'emoji': '🔥'}), 2), isNull);
      expect(decodeEvent(NetMessage.event('reaction', {'seat': 0, 'emoji': 'hello'}), 2), isNull);

      const snapshot = Snapshot(
        steps: [[0, -1], [3, 4]],
        display: [[0, -1], [3, 4]],
        turn: 1,
        finishOrder: [],
        captures: [0, 1],
        sixes: [1, 0],
        lastRoll: 4,
        phase: 'choosing',
        die: 4,
        rollId: 7,
        movable: [0, 1],
        flying: [TokenRef(0, 1)],
        status: 'x',
        notes: ['a', 'b'],
        timerMs: 900,
        timerTotalMs: 1000,
        takenOver: [],
      );
      final copy = Snapshot.fromJson(NetMessage.decode(NetMessage.snapshot(snapshot.toJson()).encode()).data);
      expect(copy.toJson(), snapshot.toJson());
      expect(() => Snapshot.fromJson(const {'steps': 3}), throwsFormatException);
    });

    test('room codes are 4 unambiguous characters', () {
      final random = Random(1);
      for (var i = 0; i < 200; i++) {
        final code = newRoomCode(random);
        expect(code.length, 4);
        expect(code, isNot(matches(RegExp('[IO01]'))));
        expect(parseRoomCode(code.toLowerCase()), code);
      }
      expect(parseRoomCode('AB'), isNull);
      expect(parseRoomCode('AB0D'), isNull);
      expect(RoomAddress.parse('192.168.1.5', 47831).toString(), '192.168.1.5:47831');
      expect(RoomAddress.parse(' 10.0.0.2:900 ', 1)!.port, 900);
      expect(RoomAddress.parse('300.1.1.1', 1), isNull);
      expect(RoomAddress.parse('example.com', 1), isNull);
    });
  });

  group('lobby', () {
    test('seats fill, names are cleaned, a full room refuses', () async {
      final table = _Table(players: 2, clientCount: 0);
      table.join('  A very long player name  ');
      await _settle();
      expect(table.host.seats[1].name.length, kMaxNameLength);
      expect(table.host.canStart, isFalse, reason: 'not ready yet');
      final late_ = table.join('Late');
      await _settle();
      expect(late_.ended.value, 'The room is full.');
      table.clients.first.setReady(true);
      await _settle();
      expect(table.host.canStart, isTrue);
      expect(table.clients.first.lobby.map((s) => s.name).first, 'Hana');
      await table.close();
    });

    test('empty seats need bots before the host can start', () async {
      final table = _Table(players: 3, clientCount: 1);
      await table.readyAll();
      expect(table.host.canStart, isFalse);
      table.host.setFillBots(true);
      expect(table.host.canStart, isTrue);
      await table.close();
    });
  });

  group('match', () {
    test('the host only accepts the current player\'s legal intents', () async {
      final table = _Table(players: 2, clientCount: 1);
      await table.readyAll();
      final game = table.host.start(soundOn: false, hapticsOn: false);
      await _settle();
      expect(game.state.turn, 0);
      final pipe = table.pipes.first;
      pipe.send(NetMessage.roll.encode()); // not their turn
      pipe.send(NetMessage.pick(0).encode());
      pipe.send('garbage');
      await _settle();
      expect(game.rollId, 0);
      expect(game.remoteRoll(1), isFalse);
      expect(game.remotePick(0, 0), isFalse, reason: 'nothing rolled yet');
      game.rollTapped();
      final rolls = game.rollId;
      game.rollTapped(); // repeated
      expect(game.rollId, rolls);
      await table.close();
    });

    test('a host and three players finish a match and all agree', () async {
      final table = _Table();
      await table.readyAll();
      final game = table.host.start(soundOn: false, hapticsOn: false);
      await _settle();
      expect(table.clients.every((c) => c.controller != null), isTrue);
      await table.playToEnd();
      expect(game.phase, TurnPhase.over);
      expect(Rules.isOver(game.state), isTrue);
      for (final client in table.clients) {
        final mirror = client.controller!;
        expect(mirror.phase, TurnPhase.over);
        expect(mirror.state.steps, game.state.steps);
        expect(mirror.display, game.display);
        expect(mirror.state.finishOrder, game.state.finishOrder);
        expect(mirror.state.captures, game.state.captures);
        expect(Rules.ranking(mirror.state), Rules.ranking(game.state));
      }
      await table.close();
    });

    test('a dropped player can come back to the same seat', () async {
      final table = _Table(players: 2, clientCount: 1, grace: const Duration(seconds: 30));
      await table.readyAll();
      final game = table.host.start(soundOn: false, hapticsOn: false);
      await _settle();
      final client = table.clients.first;
      final token = client.seatToken;
      await table.pipes.first.close();
      await _settle();
      expect(table.host.seats[1].connected, isFalse);
      expect(game.takenOver, isEmpty, reason: 'there is a grace period');

      // The same player returns with their seat token.
      final again = ClientRoom(name: 'P1', avatar: 'frog')..seatToken = token;
      table.clients.add(again);
      table.pipes.add(table.pipes.first);
      table.join('P1', existing: again);
      await _settle();
      expect(again.seat, 1);
      expect(again.controller, isNotNull);
      expect(table.host.seats[1].connected, isTrue);
      await table.close();
    });

    test('after the grace period a bot takes the seat and the match goes on', () async {
      final table = _Table(players: 2, clientCount: 1, grace: const Duration(milliseconds: 20));
      await table.readyAll();
      final game = table.host.start(soundOn: false, hapticsOn: false);
      await _settle();
      await table.pipes.first.close();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(game.takenOver, {1});
      table.clients.clear();
      await table.playToEnd();
      expect(game.phase, TurnPhase.over);
      await table.host.close();
    });

    test('players are told when the host leaves', () async {
      final table = _Table(players: 2, clientCount: 1);
      await table.readyAll();
      table.host.start(soundOn: false, hapticsOn: false);
      await _settle();
      await table.host.close();
      await _settle();
      expect(table.clients.first.ended.value, 'The host closed the room.');
      await table.clients.first.leave();
    });

    test('a latecomer cannot join a running match', () async {
      final table = _Table(players: 2, clientCount: 1);
      await table.readyAll();
      table.host.start(soundOn: false, hapticsOn: false);
      await _settle();
      final late_ = table.join('Late');
      await _settle();
      expect(late_.ended.value, 'The game has already started.');
      await table.close();
    });
  });

  test('a real WebSocket carries a hello and a welcome', () async {
    final host = HostRoom(code: 'WXYZ', name: 'H', avatar: 'cat');
    final server = await RoomServer.start(host.accept);
    final client = ClientRoom(name: 'C', avatar: 'owl')..connect(await SocketChannel.connect('127.0.0.1', server.port));
    for (var i = 0; i < 100 && client.seat == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(client.seat, 1);
    expect(client.code, 'WXYZ');
    await client.leave();
    await host.close();
    await server.close();
  });
}
