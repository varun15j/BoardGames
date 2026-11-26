/// A two-way text pipe: a WebSocket on real phones, memory in tests.
library;

import 'dart:async';
import 'dart:io';

abstract class Channel {
  Stream<String> get messages;
  void send(String message);

  /// Closes both directions; [messages] ends on each side.
  Future<void> close();
}

/// Two ends of an in-memory pipe, for tests.
class MemoryChannel implements Channel {
  MemoryChannel._(this._incoming, this._outgoing);

  static (MemoryChannel, MemoryChannel) pair() {
    final a = StreamController<String>();
    final b = StreamController<String>();
    return (MemoryChannel._(a, b), MemoryChannel._(b, a));
  }

  final StreamController<String> _incoming;
  final StreamController<String> _outgoing;

  /// Everything sent from this end.
  final List<String> sent = [];

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String message) {
    if (_outgoing.isClosed) return;
    sent.add(message);
    _outgoing.add(message);
  }

  @override
  Future<void> close() async {
    // Not awaited: a pipe nobody listens to never reports it is done.
    if (!_outgoing.isClosed) unawaited(_outgoing.close());
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }
}

class SocketChannel implements Channel {
  SocketChannel(this._socket) {
    // The platform pings every few seconds and closes a silent connection.
    _socket.pingInterval = const Duration(seconds: 3);
  }

  final WebSocket _socket;

  static Future<SocketChannel> connect(String host, int port) async => SocketChannel(
        await WebSocket.connect('ws://$host:$port/').timeout(const Duration(seconds: 6)),
      );

  @override
  late final Stream<String> messages =
      _socket.where((m) => m is String).cast<String>().handleError((Object _) {});

  @override
  void send(String message) {
    if (_socket.readyState == WebSocket.open) _socket.add(message);
  }

  @override
  Future<void> close() async {
    await _socket.close();
  }
}

/// Accepts WebSocket players on the local network.
class RoomServer {
  RoomServer._(this._server);

  final HttpServer _server;

  /// Preferred port, so it can be typed by hand; any free port otherwise.
  static const defaultPort = 47831;

  static Future<RoomServer> start(void Function(Channel) onPlayer) async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      onPlayer(SocketChannel(await WebSocketTransformer.upgrade(request)));
    });
    return RoomServer._(server);
  }

  int get port => _server.port;

  Future<void> close() => _server.close(force: true);
}

/// This device's addresses on the local network, most likely first.
Future<List<String>> localAddresses() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  int rank(NetworkInterface i) => RegExp('wlan|ap|swlan|wifi', caseSensitive: false).hasMatch(i.name) ? 0 : 1;
  interfaces.sort((a, b) => rank(a).compareTo(rank(b)));
  return [
    for (final i in interfaces)
      for (final a in i.addresses)
        if (!a.isLoopback) a.address,
  ];
}
