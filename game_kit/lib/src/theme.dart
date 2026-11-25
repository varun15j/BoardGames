import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shapes printed on tokens so colour-blind players can tell them apart.
enum PlayerShape { circle, square, triangle, diamond }

/// Colours shared by every game.
class KitColors {
  KitColors._();
  static const stage = Color(0xFF101A2E);
  static const stage2 = Color(0xFF16233D);
  static const panel = Color(0xFF1C2B49);
  static const ink = Color(0xFFF2F6FF);
  static const muted = Color(0xFFA9B6D3);
  static const line = Color(0xFF2C3D62);
  static const tile = Color(0xFFFAFCFF);
  static const tileEdge = Color(0xFFD7E1F2);
  static const coral = Color(0xFFFF6B57);
  static const teal = Color(0xFF16B8A6);
  static const amber = Color(0xFFFFB429);
  static const violet = Color(0xFF7C6CF7);
  static const gold = Color(0xFFFFD25A);
  static const goldDeep = Color(0xFFC99A1C);
  static const goldInk = Color(0xFF3A2A00);
  static const danger = Color(0xFFFF3B3B);
}

/// A player colour together with its mark.
class PlayerStyle {
  const PlayerStyle(this.name, this.color, this.shape);
  final String name;
  final Color color;
  final PlayerShape shape;
}

/// Player styles indexed by board corner: 0 top-left, 1 top-right,
/// 2 bottom-right, 3 bottom-left (clockwise).
const List<PlayerStyle> kCornerStyles = [
  PlayerStyle('Teal', KitColors.teal, PlayerShape.square),
  PlayerStyle('Amber', KitColors.amber, PlayerShape.triangle),
  PlayerStyle('Violet', KitColors.violet, PlayerShape.diamond),
  PlayerStyle('Coral', KitColors.coral, PlayerShape.circle),
];

/// Typography and the app theme. Fonts come from Google Fonts (Baloo 2 for
/// headings, Nunito for text). Tests set [useGoogleFonts] to false.
class KitTheme {
  KitTheme._();

  static bool useGoogleFonts = true;

  static TextStyle heading({
    double size = 22,
    FontWeight weight = FontWeight.w800,
    Color color = KitColors.ink,
  }) {
    final base = TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.1);
    return useGoogleFonts ? GoogleFonts.baloo2(textStyle: base) : base;
  }

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color color = KitColors.ink,
  }) {
    final base = TextStyle(fontSize: size, fontWeight: weight, color: color);
    return useGoogleFonts ? GoogleFonts.nunito(textStyle: base) : base;
  }

  static ThemeData data() {
    final scheme = ColorScheme.fromSeed(
      seedColor: KitColors.gold,
      brightness: Brightness.dark,
    ).copyWith(surface: KitColors.stage, primary: KitColors.gold);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: KitColors.stage,
      canvasColor: KitColors.stage2,
      textTheme: TextTheme(
        titleLarge: heading(size: 24),
        titleMedium: heading(size: 18),
        bodyLarge: body(size: 16),
        bodyMedium: body(),
        labelLarge: body(weight: FontWeight.w800),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: KitColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
