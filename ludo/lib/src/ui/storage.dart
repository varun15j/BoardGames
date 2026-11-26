import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';

/// Saved game and settings, kept with shared_preferences.
class LudoStorage {
  const LudoStorage();

  static const _saveKey = 'ludo.save';
  static const _soundKey = 'ludo.sound';
  static const _hapticsKey = 'ludo.haptics';
  static const _view3dKey = 'ludo.view3d';

  Future<GameState?> loadSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw == null) return null;
      final state = GameState.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      return state;
    } catch (_) {
      return null; // a corrupt save is treated as no save
    }
  }

  Future<void> save(GameState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_saveKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> clearSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_saveKey);
    } catch (_) {}
  }

  /// Whether the player last chose the 3D board. 2D until they do.
  Future<bool> loadView3d() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_view3dKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveView3d(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_view3dKey, value);
    } catch (_) {}
  }

  Future<({bool sound, bool haptics})> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (sound: prefs.getBool(_soundKey) ?? true, haptics: prefs.getBool(_hapticsKey) ?? true);
    } catch (_) {
      return (sound: true, haptics: true);
    }
  }

  Future<void> saveSettings({required bool sound, required bool haptics}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundKey, sound);
      await prefs.setBool(_hapticsKey, haptics);
    } catch (_) {}
  }
}
