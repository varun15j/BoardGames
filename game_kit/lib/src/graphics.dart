import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'buttons.dart';
import 'theme.dart';

/// What the player chose.
enum GraphicsMode { auto, performance, optimized }

/// What actually gets drawn: flat 2D, or realistic 3D with tilt.
enum GraphicsQuality { performance, optimized }

/// Hardware facts used to pick a quality in [GraphicsMode.auto].
class DeviceCapability {
  const DeviceCapability({required this.ramMb, required this.sdkInt, required this.isLowRam});
  final int ramMb;
  final int sdkInt;
  final bool isLowRam;

  @override
  String toString() => '$ramMb MB RAM, SDK $sdkInt${isLowRam ? ', low-RAM device' : ''}';
}

/// A phone sold as "6 GB" reports a bit less usable memory than 6144 MB.
const int kOptimizedMinRamMb = 5500;
const int kOptimizedMinSdk = 29;

/// 3D needs about 6 GB of RAM, Android 10+ and a device that is not flagged
/// low-RAM. Anything unknown means performance mode.
GraphicsQuality detectQuality(DeviceCapability? device) {
  if (device == null) return GraphicsQuality.performance;
  final strong = !device.isLowRam && device.ramMb >= kOptimizedMinRamMb && device.sdkInt >= kOptimizedMinSdk;
  return strong ? GraphicsQuality.optimized : GraphicsQuality.performance;
}

/// True when the average frame (build + raster) is over budget across a long
/// enough window to rule out a one-off stutter.
bool shouldDowngrade(List<double> frameMs, {int minFrames = 150, double thresholdMs = 20}) {
  if (frameMs.length < minFrames) return false;
  final recent = frameMs.sublist(frameMs.length - minFrames);
  return recent.reduce((a, b) => a + b) / minFrames > thresholdMs;
}

Future<DeviceCapability?> _readDevice() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return DeviceCapability(ramMb: info.physicalRamSize, sdkInt: info.version.sdkInt, isLowRam: info.isLowRamDevice);
  } catch (_) {
    return null;
  }
}

/// The graphics preference, persisted, plus the quality it resolves to.
class GraphicsSettings extends ChangeNotifier {
  GraphicsSettings({Future<DeviceCapability?> Function()? readDevice}) : _read = readDevice ?? _readDevice;

  /// A mode that is neither loaded nor saved, for benchmarks.
  GraphicsSettings.fixed(GraphicsMode mode)
      : _read = _readDevice,
        _mode = mode {
    _loading = Future<void>.value();
  }

  /// Shared by every game in the app.
  static GraphicsSettings instance = GraphicsSettings();

  static const _modeKey = 'kit.graphics.mode';
  static const _tiltKey = 'kit.graphics.tilt';
  static const _slowKey = 'kit.graphics.autoSlow';

  final Future<DeviceCapability?> Function() _read;
  Future<void>? _loading;

  GraphicsMode _mode = GraphicsMode.auto;
  bool _tiltEffect = true;
  bool _autoSlow = false;
  DeviceCapability? device;
  GraphicsQuality _detected = GraphicsQuality.performance;

  GraphicsMode get mode => _mode;

  /// "Tilt effect" switch; only matters in optimized quality.
  bool get tiltEffect => _tiltEffect;

  GraphicsQuality get quality => switch (_mode) {
        GraphicsMode.performance => GraphicsQuality.performance,
        GraphicsMode.optimized => GraphicsQuality.optimized,
        GraphicsMode.auto => _autoSlow ? GraphicsQuality.performance : _detected,
      };

  bool get optimized => quality == GraphicsQuality.optimized;

  /// Reads the saved choice and detects the device, once.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = GraphicsMode.values.asNameMap()[prefs.getString(_modeKey)] ?? GraphicsMode.auto;
      _tiltEffect = prefs.getBool(_tiltKey) ?? true;
      _autoSlow = prefs.getBool(_slowKey) ?? false;
    } catch (_) {}
    device = await _read();
    _detected = detectQuality(device);
    debugPrint('[graphics] mode=${_mode.name} device=${device ?? "unknown"} -> ${quality.name}');
    notifyListeners();
  }

  Future<void> setMode(GraphicsMode value) async {
    _mode = value;
    // Choosing again gives auto a fresh chance.
    _autoSlow = false;
    notifyListeners();
    await _store((p) async {
      await p.setString(_modeKey, value.name);
      await p.setBool(_slowKey, false);
    });
  }

  Future<void> setTiltEffect(bool value) async {
    _tiltEffect = value;
    notifyListeners();
    await _store((p) => p.setBool(_tiltKey, value));
  }

  /// Auto mode found the device too slow for 3D. Returns true when that
  /// changed what is drawn.
  Future<bool> downgradeAuto() async {
    if (_mode != GraphicsMode.auto || !optimized) return false;
    _autoSlow = true;
    notifyListeners();
    await _store((p) => p.setBool(_slowKey, true));
    return true;
  }

  Future<void> _store(Future<void> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }
}

String graphicsModeLabel(GraphicsMode m) => switch (m) {
      GraphicsMode.auto => 'Auto',
      GraphicsMode.performance => 'Performance',
      GraphicsMode.optimized => 'Optimized',
    };

String graphicsModeDescription(GraphicsMode m) => switch (m) {
      GraphicsMode.auto => 'Picks the best mode for this phone.',
      GraphicsMode.performance => 'Flat 2D board, smooth on any phone.',
      GraphicsMode.optimized => '3D dice and pieces, moving shadows and tilt.',
    };

/// Auto / Performance / Optimized selector with the tilt switch.
class GraphicsSelector extends StatelessWidget {
  const GraphicsSelector({super.key, required this.settings});
  final GraphicsSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Graphics', style: KitTheme.body(size: 13, weight: FontWeight.w800, color: KitColors.muted)),
          const SizedBox(height: 6),
          SegmentedPills<GraphicsMode>(
            options: GraphicsMode.values,
            value: settings.mode,
            labelOf: graphicsModeLabel,
            onChanged: settings.setMode,
          ),
          const SizedBox(height: 6),
          Text(
            '${graphicsModeLabel(settings.mode)}: ${graphicsModeDescription(settings.mode)}',
            style: KitTheme.body(size: 12, color: KitColors.muted),
          ),
          Text(
            'Now showing: ${settings.optimized ? "Optimized (3D)" : "Performance (2D)"}',
            style: KitTheme.body(size: 12, color: KitColors.gold),
          ),
          if (settings.optimized)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Tilt effect', style: KitTheme.body(size: 15, weight: FontWeight.w800)),
              value: settings.tiltEffect,
              activeThumbColor: KitColors.goldInk,
              activeTrackColor: KitColors.gold,
              onChanged: settings.setTiltEffect,
            ),
        ],
      ),
    );
  }
}
