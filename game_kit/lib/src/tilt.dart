import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Turns gyroscope rates into a calm tilt value in -1..1 on each axis.
///
/// Rotation is integrated with a slow leak, so the view drifts back to level
/// when the phone is held still (whatever angle that is), then low-pass
/// filtered so it never jitters.
class TiltFilter {
  TiltFilter({this.gain = 2.4, this.leakSeconds = 1.8, this.smoothSeconds = 0.09, this.deadZone = 0.015});

  /// Tilt units per radian of phone rotation.
  final double gain;
  final double leakSeconds;
  final double smoothSeconds;

  /// Rotation rates (rad/s) below this are treated as noise.
  final double deadZone;

  Offset _raw = Offset.zero;
  Offset value = Offset.zero;

  /// [wx] and [wy] are gyroscope rates around the device x and y axes.
  Offset add(double wx, double wy, double dt) {
    if (dt <= 0) return value;
    final step = math.min(dt, 0.1);
    double quiet(double w) => w.abs() < deadZone ? 0 : w;
    final leak = math.exp(-step / leakSeconds);
    _raw = Offset(
      (_raw.dx * leak + quiet(wy) * gain * step).clamp(-1.0, 1.0),
      (_raw.dy * leak + quiet(wx) * gain * step).clamp(-1.0, 1.0),
    );
    final a = 1 - math.exp(-step / smoothSeconds);
    value = Offset.lerp(value, _raw, a)!;
    return value;
  }

  void reset() {
    _raw = Offset.zero;
    value = Offset.zero;
  }
}

/// Device tilt as a listenable. Level (zero) while stopped or when the phone
/// has no gyroscope (emulator, web, tests).
class TiltController extends ValueNotifier<Offset> {
  TiltController({this.source, TiltFilter? filter})
      : _filter = filter ?? TiltFilter(),
        super(Offset.zero);

  /// Lets tests (and platforms without sensors) switch the real sensor off.
  static bool sensorsAvailable = true;

  /// Overrides the device gyroscope, for tests.
  final Stream<GyroscopeEvent> Function()? source;
  final TiltFilter _filter;
  StreamSubscription<GyroscopeEvent>? _sub;
  DateTime? _last;

  bool get running => _sub != null;

  bool get _platformHasSensor =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  void start() {
    if (_sub != null) return;
    final custom = source;
    if (custom == null && !(sensorsAvailable && _platformHasSensor)) return;
    _last = null;
    try {
      final stream = custom != null ? custom() : gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval);
      _sub = stream.listen(_onEvent, onError: (Object _) => stop(), cancelOnError: true);
    } catch (_) {
      _sub = null; // no gyroscope: stay level
    }
  }

  void _onEvent(GyroscopeEvent e) {
    final last = _last;
    _last = e.timestamp;
    if (last == null) return;
    final next = _filter.add(e.x, e.y, e.timestamp.difference(last).inMicroseconds / 1e6);
    // Skip imperceptible changes so painters rest when the phone does.
    if ((next - value).distance > 0.002) value = next;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _filter.reset();
    value = Offset.zero;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
