/// The wire format for same-Wi-Fi play. Pure Dart: no sockets, no Flutter.
///
/// Every message is one JSON object with the protocol version `v` and a type
/// `t`. Clients only ever send intents; the host decides what happens.
library;

import 'dart:convert';
import 'dart:math';

const int kProtocolVersion = 1;

/// Longer messages are dropped.
const int kMaxMessageLength = 24 * 1024;

const int kMaxNameLength = 12;

class ProtocolError implements Exception {
  const ProtocolError(this.reason);
  final String reason;
  @override
  String toString() => 'ProtocolError: $reason';
}

/// A message: its type and its fields.
class NetMessage {
  const NetMessage(this.type, [this.data = const {}]);
  final String type;
  final Map<String, Object?> data;

  // Client to host.
  factory NetMessage.hello({required String name, required String avatar, String? seatToken}) =>
      NetMessage('hello', {'name': name, 'avatar': avatar, 'token': seatToken});
  factory NetMessage.ready(bool ready) => NetMessage('ready', {'ready': ready});
  static const roll = NetMessage('roll');
  factory NetMessage.pick(int token) => NetMessage('pick', {'token': token});
  factory NetMessage.react(String emoji) => NetMessage('react', {'emoji': emoji});
  static const leave = NetMessage('leave');
  static const ping = NetMessage('ping');

  // Host to client.
  factory NetMessage.welcome({required int seat, required String seatToken, required String code}) =>
      NetMessage('welcome', {'seat': seat, 'token': seatToken, 'code': code});
  factory NetMessage.lobby(List<Map<String, Object?>> seats) => NetMessage('lobby', {'seats': seats});
  factory NetMessage.start(Map<String, Object?> config) => NetMessage('start', {'config': config});
  factory NetMessage.snapshot(Map<String, Object?> snapshot) => NetMessage('snapshot', snapshot);
  factory NetMessage.event(String kind, Map<String, Object?> fields) => NetMessage('event', {'kind': kind, ...fields});
  factory NetMessage.error(String reason) => NetMessage('error', {'reason': reason});
  factory NetMessage.end(String reason) => NetMessage('end', {'reason': reason});
  static const pong = NetMessage('pong');

  String encode() => jsonEncode({'v': kProtocolVersion, 't': type, ...data});

  /// Throws [ProtocolError] for anything that is not a valid message.
  factory NetMessage.decode(String text) {
    if (text.length > kMaxMessageLength) throw const ProtocolError('message too long');
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const ProtocolError('not JSON');
    }
    if (json is! Map) throw const ProtocolError('not an object');
    if (json['v'] != kProtocolVersion) throw const ProtocolError('different version');
    final type = json['t'];
    if (type is! String) throw const ProtocolError('no type');
    return NetMessage(type, {
      for (final e in json.entries)
        if (e.key != 'v' && e.key != 't') e.key as String: e.value,
    });
  }

  /// A field of the given type, or a [ProtocolError].
  T field<T>(String name) {
    final value = data[name];
    if (value is! T) throw ProtocolError('bad field $name in $type');
    return value;
  }
}

/// Trims a player name to something safe to show.
String cleanName(String? name, String fallback) {
  final trimmed = (name ?? '').replaceAll(RegExp(r'[\x00-\x1F]'), '').trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed.length > kMaxNameLength ? trimmed.substring(0, kMaxNameLength) : trimmed;
}

/// Letters and digits that can't be mistaken for each other.
const String kRoomCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int kRoomCodeLength = 4;

String newRoomCode(Random random) =>
    List.generate(kRoomCodeLength, (_) => kRoomCodeAlphabet[random.nextInt(kRoomCodeAlphabet.length)]).join();

/// What a player typed, tidied up; null if it cannot be a room code.
String? parseRoomCode(String text) {
  final code = text.trim().toUpperCase().replaceAll(' ', '');
  if (code.length != kRoomCodeLength || code.split('').any((c) => !kRoomCodeAlphabet.contains(c))) return null;
  return code;
}

/// A hard to guess token that lets a player back into their seat.
String newSeatToken(Random random) => List.generate(24, (_) => random.nextInt(16).toRadixString(16)).join();
