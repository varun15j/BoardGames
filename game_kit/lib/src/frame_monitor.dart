import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'graphics.dart';

/// Watches frame times during play. If auto mode picked 3D and the phone
/// can't keep up, it switches to performance mode and calls [onDowngrade].
///
/// Debug builds are far slower than what players get, so they only log the
/// numbers and never downgrade.
class FrameMonitor {
  FrameMonitor({required this.settings, required this.onDowngrade, this.canDowngrade = !kDebugMode});

  final GraphicsSettings settings;
  final VoidCallback onDowngrade;
  final bool canDowngrade;

  static const _warmUpFrames = 30;
  static const _window = 150;

  final List<double> _frames = [];
  int _skipped = 0;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) =>
      addFrames([for (final t in timings) (t.buildDuration + t.rasterDuration).inMicroseconds / 1000]);

  /// Feeds frame costs in milliseconds.
  @visibleForTesting
  void addFrames(List<double> ms) {
    for (final f in ms) {
      if (_skipped < _warmUpFrames) {
        _skipped++;
        continue;
      }
      _frames.add(f);
      if (_frames.length >= _window) _closeWindow();
    }
  }

  void _closeWindow() {
    final average = _frames.reduce((a, b) => a + b) / _frames.length;
    if (!kReleaseMode) {
      final worst = _frames.reduce((a, b) => a > b ? a : b);
      final slow = _frames.where((f) => f > 16.7).length;
      debugPrint('[frames] ${settings.quality.name}: avg ${average.toStringAsFixed(1)} ms, '
          'worst ${worst.toStringAsFixed(1)} ms, $slow of ${_frames.length} over 16.7 ms');
    }
    final slowDevice = shouldDowngrade(_frames);
    _frames.clear();
    if (slowDevice && canDowngrade) {
      settings.downgradeAuto().then((changed) {
        if (changed) onDowngrade();
      });
    }
  }
}
