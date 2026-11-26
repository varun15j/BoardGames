import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'catalog.dart';

/// What a player shows: a built-in avatar, or a photo kept in the app's
/// private storage with a built-in avatar to fall back on.
class AvatarChoice {
  const AvatarChoice(this.avatarId, {this.photoPath});
  final String avatarId;
  final String? photoPath;

  static const fallbackId = 'star';

  bool get isPhoto => photoPath != null;

  Avatar get avatar => kAvatarsById[avatarId] ?? kAvatarsById[fallbackId]!;

  /// Compact form kept in saved games and preferences.
  String encode() => photoPath == null ? 'a:$avatarId' : 'p:$avatarId|$photoPath';

  static AvatarChoice? decode(String? text) {
    if (text == null) return null;
    if (text.startsWith('a:')) return AvatarChoice(text.substring(2));
    if (text.startsWith('p:')) {
      final bar = text.indexOf('|');
      if (bar > 2) return AvatarChoice(text.substring(2, bar), photoPath: text.substring(bar + 1));
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarChoice && other.avatarId == avatarId && other.photoPath == photoPath;
  @override
  int get hashCode => Object.hash(avatarId, photoPath);
}

/// Paints built-in avatar art to fill [side] pixels.
void paintAvatar(Canvas canvas, Avatar avatar, double side) {
  canvas.save();
  canvas.scale(side / 100);
  canvas.clipRect(const Rect.fromLTWH(0, 0, 100, 100));
  canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = Color(avatar.background));
  for (final shape in avatar.shapes) {
    shape.paint(canvas);
  }
  canvas.restore();
}

/// Renders every avatar and photo once per size and keeps the image.
class AvatarImages extends ChangeNotifier {
  AvatarImages._();
  static final AvatarImages instance = AvatarImages._();

  final Map<String, ui.Image> _cache = {};
  final Set<String> _loading = {};
  final Set<String> _failed = {};

  /// Sizes images are rendered at.
  static const sizes = [64, 128, 256];
  static int bucket(double pixels) => sizes.firstWhere((s) => s >= pixels, orElse: () => sizes.last);

  /// The image for [choice] at roughly [pixels] wide. A photo that is still
  /// loading, or can't be read, shows the fallback avatar.
  ui.Image image(AvatarChoice choice, double pixels) {
    final px = bucket(pixels);
    if (choice.isPhoto) {
      final key = 'p:${choice.photoPath}:$px';
      final photo = _cache[key];
      if (photo != null) return photo;
      if (!_failed.contains(key) && _loading.add(key)) _loadPhoto(key, choice.photoPath!, px);
    }
    return _vector(choice.avatar, px);
  }

  /// True once a photo could not be read.
  bool failed(AvatarChoice choice, double pixels) => _failed.contains('p:${choice.photoPath}:${bucket(pixels)}');

  ui.Image _vector(Avatar avatar, int px) => _cache.putIfAbsent('a:${avatar.id}:$px', () {
        final recorder = ui.PictureRecorder();
        paintAvatar(Canvas(recorder), avatar, px.toDouble());
        final picture = recorder.endRecording();
        final image = picture.toImageSync(px, px);
        picture.dispose();
        return image;
      });

  Future<void> _loadPhoto(String key, String path, int px) async {
    try {
      final bytes = await File(path).readAsBytes();
      _cache[key] = await squareCrop(bytes, px);
    } catch (_) {
      _failed.add(key); // keep showing the fallback avatar
    }
    _loading.remove(key);
    notifyListeners();
  }
}

/// Decodes an image and crops its centre square, scaled to [side] pixels.
Future<ui.Image> squareCrop(Uint8List bytes, int side) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final source = (await codec.getNextFrame()).image;
  codec.dispose();
  final crop = math.min(source.width, source.height).toDouble();
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    Rect.fromCenter(center: Offset(source.width / 2, source.height / 2), width: crop, height: crop),
    Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final result = await picture.toImage(side, side);
  picture.dispose();
  source.dispose();
  return result;
}

/// A round (or rounded-square) avatar.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.choice, required this.size, this.circle = true});
  final AvatarChoice choice;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final pixels = size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1);
    final image = ListenableBuilder(
      listenable: AvatarImages.instance,
      builder: (context, _) => RawImage(
        image: AvatarImages.instance.image(choice, pixels).clone(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: circle
            ? ClipOval(child: image)
            : ClipRRect(borderRadius: BorderRadius.circular(size * 0.22), child: image),
      ),
    );
  }
}
