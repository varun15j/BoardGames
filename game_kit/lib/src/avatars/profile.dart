import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'avatar_store.dart';

/// Picks a photo from the gallery and keeps a small square copy in the app's
/// private documents folder. Nothing is uploaded or logged.
class PhotoImporter {
  const PhotoImporter({this.pick = _pickFromGallery, this.folder = _privateFolder});

  /// Returns the chosen file's bytes, or null if the player cancelled.
  final Future<Uint8List?> Function() pick;
  final Future<Directory> Function() folder;

  static const side = 256;

  static Future<Uint8List?> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    // Remove the picker's temporary copy.
    try {
      await File(file.path).delete();
    } catch (_) {}
    return bytes;
  }

  static Future<Directory> _privateFolder() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');

  /// The saved photo's path, or null if cancelled. Throws if the gallery is
  /// not allowed or the file isn't a readable picture.
  Future<String?> import() async {
    final bytes = await pick();
    if (bytes == null) return null;
    final image = await squareCrop(bytes, side);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = await folder();
    await dir.create(recursive: true);
    final file = File('${dir.path}/photo-${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
    return file.path;
  }
}

/// The device owner's name and avatar, persisted.
class PlayerProfile extends ChangeNotifier {
  static PlayerProfile instance = PlayerProfile();

  static const _nameKey = 'kit.profile.name';
  static const _avatarKey = 'kit.profile.avatar';

  Future<void>? _loading;
  String _name = '';
  AvatarChoice _choice = const AvatarChoice(AvatarChoice.fallbackId);

  /// Empty until the player types one.
  String get name => _name;
  AvatarChoice get choice => _choice;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _name = prefs.getString(_nameKey) ?? '';
      var choice = AvatarChoice.decode(prefs.getString(_avatarKey)) ?? _choice;
      // A photo that has gone missing falls back to the avatar.
      if (choice.isPhoto && !File(choice.photoPath!).existsSync()) choice = AvatarChoice(choice.avatarId);
      _choice = choice;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> update({String? name, AvatarChoice? choice}) async {
    final oldPhoto = _choice.photoPath;
    _name = name?.trim() ?? _name;
    _choice = choice ?? _choice;
    notifyListeners();
    if (oldPhoto != null && oldPhoto != _choice.photoPath) {
      try {
        await File(oldPhoto).delete();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameKey, _name);
      await prefs.setString(_avatarKey, _choice.encode());
    } catch (_) {}
  }

  Future<void> removePhoto() => update(choice: AvatarChoice(_choice.avatarId));
}
