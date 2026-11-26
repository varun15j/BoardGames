/// "Play on Wi-Fi": host a room or join one.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../game/models.dart';
import '../net/channel.dart';
import '../net/client_room.dart';
import '../net/discovery.dart';
import '../net/host_room.dart';
import '../net/protocol.dart';
import 'game_screen.dart';
import 'ludo_game.dart';

const _note = 'All phones must be on the same Wi-Fi, or on one phone\'s hotspot. '
    'Guest and public Wi-Fi often block phones from seeing each other.';

Widget _page(BuildContext context, String title, List<Widget> children) {
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
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KitTheme.heading(size: 24))),
                ],
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 20), children: children),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _info(String text) =>
    Text(text, style: KitTheme.body(size: 13, weight: FontWeight.w600, color: KitColors.muted));

Widget _seatRow({required int index, required String name, required String avatar, required String state}) {
  const corners = [3, 1, 0, 2];
  final style = kCornerStyles[corners[index % 4]];
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: style.color.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: style.color.withValues(alpha: 0.7), width: 1.5),
    ),
    child: Row(
      children: [
        if (avatar.isEmpty)
          const SizedBox(width: 36, height: 36, child: Icon(Icons.hourglass_empty_rounded, color: KitColors.muted))
        else
          AvatarView(choice: AvatarChoice(avatar), size: 36),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: KitTheme.body(size: 15, weight: FontWeight.w800))),
        Text(state, style: KitTheme.body(size: 12, color: KitColors.muted)),
      ],
    ),
  );
}

/// Empty means the room names the player by seat (Host, Player 2, ...).
String _myName(PlayerProfile profile) => profile.name;

class WifiScreen extends StatelessWidget {
  const WifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _page(context, 'Play on Wi-Fi', [
      GoldButton(
        label: 'Host a room',
        icon: Icons.wifi_tethering_rounded,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HostLobbyScreen())),
      ),
      const SizedBox(height: 14),
      SoftButton(
        label: 'Join a room',
        icon: Icons.login_rounded,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const JoinScreen())),
      ),
      const SizedBox(height: 18),
      _info(_note),
    ]);
  }
}

class HostLobbyScreen extends StatefulWidget {
  const HostLobbyScreen({super.key, this.discovery = const RoomDiscovery()});
  final RoomDiscovery discovery;

  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen> {
  late final HostRoom _room;
  RoomServer? _server;
  Future<void> Function()? _stopAnnouncing;
  List<String> _addresses = const [];
  String? _error;
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    final profile = PlayerProfile.instance;
    _room = HostRoom(code: newRoomCode(Random.secure()), name: _myName(profile), avatar: profile.choice.avatarId);
    _room.addListener(_changed);
    _open();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _open() async {
    try {
      final server = await RoomServer.start(_room.accept);
      _server = server;
      _addresses = await localAddresses();
      _stopAnnouncing = await widget.discovery.announce(_room.code, server.port);
    } catch (_) {
      _error = 'Couldn\'t open a room. Check that Wi-Fi or your hotspot is on.';
    }
    if (mounted) {
      setState(() {});
    } else {
      _closeAll();
    }
  }

  Future<void> _closeAll() async {
    _room.removeListener(_changed);
    await _stopAnnouncing?.call();
    await _room.close();
    await _server?.close();
  }

  @override
  void dispose() {
    if (!_handedOver) _closeAll();
    super.dispose();
  }

  void _start() {
    _handedOver = true;
    _room.removeListener(_changed);
    final game = _room.start();
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => GameScreen(state: game.state, controller: game, onLeave: _closeAll),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final server = _server;
    return _page(context, 'Host a room', [
      if (_error != null) Text(_error!, style: KitTheme.body(color: KitColors.gold)),
      Text('Room code', style: KitTheme.body(size: 13, color: KitColors.muted)),
      Text(_room.code, key: const ValueKey('room-code'), style: KitTheme.heading(size: 52, color: KitColors.gold)),
      if (server != null && _addresses.isNotEmpty)
        _info('If a phone can\'t find the room, enter this address there: ${_addresses.first}:${server.port}'),
      const SizedBox(height: 14),
      SegmentedPills<int>(
        options: const [2, 3, 4],
        value: _room.players,
        labelOf: (n) => '$n players',
        onChanged: _room.setPlayers,
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < _room.players; i++)
        _seatRow(
          index: i,
          name: switch (_room.seats[i].kind) {
            SeatKind.open => _room.fillBots ? 'Bot' : 'Waiting for a player…',
            _ => _room.seats[i].name,
          },
          avatar: _room.seats[i].avatar,
          state: switch (_room.seats[i].kind) {
            SeatKind.host => 'Host',
            SeatKind.player => _room.seats[i].ready ? 'Ready' : 'Not ready',
            SeatKind.bot || SeatKind.open => _room.fillBots ? 'Bot' : '',
          },
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Fill empty seats with bots', style: KitTheme.body(size: 15, weight: FontWeight.w800)),
        value: _room.fillBots,
        activeThumbColor: KitColors.goldInk,
        activeTrackColor: KitColors.gold,
        onChanged: _room.setFillBots,
      ),
      if (_room.fillBots)
        SegmentedPills<BotLevel>(
          options: BotLevel.values,
          value: _room.botLevel,
          labelOf: (l) => l == BotLevel.easy ? 'Easy' : 'Normal',
          onChanged: (l) => _room.setFillBots(true, l),
        ),
      const SizedBox(height: 14),
      GoldButton(label: 'Start match', onPressed: server != null && _room.canStart ? _start : null),
      const SizedBox(height: 12),
      _info(_note),
    ]);
  }
}

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.discovery = const RoomDiscovery()});
  final RoomDiscovery discovery;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _code = TextEditingController();
  final _address = TextEditingController();
  ClientRoom? _room;
  String? _message;
  bool _busy = false;
  bool _handedOver = false;

  @override
  void dispose() {
    _code.dispose();
    _address.dispose();
    if (!_handedOver) {
      _room?.removeListener(_changed);
      _room?.leave();
    }
    super.dispose();
  }

  Future<void> _join() async {
    final typed = _address.text.trim();
    final code = parseRoomCode(_code.text);
    RoomAddress? address;
    if (typed.isNotEmpty) {
      address = RoomAddress.parse(typed, RoomServer.defaultPort);
      if (address == null) return setState(() => _message = 'That address doesn\'t look right.');
    } else if (code == null) {
      return setState(() => _message = 'Enter the 4-character room code.');
    }
    setState(() {
      _busy = true;
      _message = 'Looking for the room…';
    });
    address ??= await widget.discovery.find(code!);
    if (!mounted) return;
    if (address == null) {
      setState(() {
        _busy = false;
        _message = 'No room found. Type the host\'s address below instead.';
      });
      return;
    }
    try {
      final channel = await SocketChannel.connect(address.host, address.port);
      if (!mounted) {
        await channel.close();
        return;
      }
      final profile = PlayerProfile.instance;
      final room = ClientRoom(name: _myName(profile), avatar: profile.choice.avatarId);
      room.addListener(_changed);
      room.connect(channel);
      setState(() {
        _room = room;
        _busy = false;
        _message = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'Couldn\'t connect. Are both phones on the same Wi-Fi?';
        });
      }
    }
  }

  void _changed() {
    final room = _room;
    if (!mounted || room == null) return;
    final reason = room.ended.value;
    if (reason != null) {
      room.removeListener(_changed);
      room.leave();
      setState(() {
        _room = null;
        _message = reason;
      });
      return;
    }
    final game = room.controller;
    if (game != null && !_handedOver) {
      _handedOver = true;
      room.removeListener(_changed);
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => GameScreen(state: game.state, controller: game, ended: room.ended, onLeave: room.leave),
      ));
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room != null) {
      return _page(context, 'Room ${room.code ?? ""}', [
        for (final s in room.lobby)
          _seatRow(
            index: s.seat,
            name: s.kind == 'open' ? 'Waiting for a player…' : s.name,
            avatar: s.kind == 'open' ? '' : s.avatar,
            state: s.kind == 'host'
                ? 'Host'
                : (s.kind == 'player' ? (s.ready ? 'Ready' : 'Not ready') : ''),
          ),
        const SizedBox(height: 12),
        GoldButton(label: room.ready ? 'Not ready' : 'I\'m ready', onPressed: () => room.setReady(!room.ready)),
        const SizedBox(height: 12),
        SoftButton(label: 'Leave room', onPressed: () => LudoGame.popToHome(context)),
        const SizedBox(height: 12),
        _info('The host starts the match.'),
      ]);
    }
    return _page(context, 'Join a room', [
      TextField(
        key: const ValueKey('join-code'),
        controller: _code,
        textCapitalization: TextCapitalization.characters,
        maxLength: kRoomCodeLength,
        style: KitTheme.heading(size: 30, color: KitColors.gold),
        decoration: const InputDecoration(labelText: 'Room code', counterText: ''),
      ),
      const SizedBox(height: 8),
      TextField(
        key: const ValueKey('join-address'),
        controller: _address,
        keyboardType: TextInputType.url,
        style: KitTheme.body(size: 16),
        decoration: const InputDecoration(labelText: 'Host address (only if the code is not found)'),
      ),
      const SizedBox(height: 16),
      GoldButton(label: _busy ? 'Connecting…' : 'Join', onPressed: _busy ? null : _join),
      if (_message != null) ...[
        const SizedBox(height: 10),
        Text(_message!, style: KitTheme.body(size: 14, color: KitColors.gold)),
      ],
      const SizedBox(height: 16),
      _info(_note),
    ]);
  }
}
