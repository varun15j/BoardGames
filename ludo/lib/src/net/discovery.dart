/// Finds a room on the local network by its code (Android network service
/// discovery). Players can always type the address instead.
library;

import 'dart:async';

import 'package:nsd/nsd.dart' as nsd;

const String _serviceType = '_raceboard._tcp';

String _serviceName(String code) => 'RaceBoard-$code';

class RoomAddress {
  const RoomAddress(this.host, this.port);
  final String host;
  final int port;

  /// "192.168.1.20" or "192.168.1.20:47831".
  static RoomAddress? parse(String text, int defaultPort) {
    final match = RegExp(r'^\s*(\d{1,3}(?:\.\d{1,3}){3})(?::(\d{1,5}))?\s*$').firstMatch(text);
    if (match == null) return null;
    if (match.group(1)!.split('.').any((n) => int.parse(n) > 255)) return null;
    final port = match.group(2) == null ? defaultPort : int.parse(match.group(2)!);
    if (port < 1 || port > 65535) return null;
    return RoomAddress(match.group(1)!, port);
  }

  @override
  String toString() => '$host:$port';
}

/// Announces and looks up rooms.
class RoomDiscovery {
  const RoomDiscovery();

  /// Announces the room; call the returned function to stop. Fails quietly:
  /// the address can still be typed.
  Future<Future<void> Function()> announce(String code, int port) async {
    try {
      final registration = await nsd.register(nsd.Service(name: _serviceName(code), type: _serviceType, port: port));
      return () async {
        try {
          await nsd.unregister(registration);
        } catch (_) {}
      };
    } catch (_) {
      return () async {};
    }
  }

  /// The address of the room with [code], or null if none answers in time.
  Future<RoomAddress?> find(String code, {Duration timeout = const Duration(seconds: 8)}) async {
    nsd.Discovery? discovery;
    final found = Completer<RoomAddress?>();
    try {
      discovery = await nsd.startDiscovery(_serviceType, ipLookupType: nsd.IpLookupType.v4);
      void check() {
        for (final service in discovery!.services) {
          final address = service.addresses?.firstOrNull?.address;
          final port = service.port;
          if (service.name == _serviceName(code) && address != null && port != null && !found.isCompleted) {
            found.complete(RoomAddress(address, port));
          }
        }
      }

      discovery.addListener(check);
      check();
      return await found.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      if (discovery != null) {
        try {
          await nsd.stopDiscovery(discovery);
        } catch (_) {}
      }
    }
  }
}
