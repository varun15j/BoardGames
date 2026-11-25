import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import 'games.dart';

/// Game picker: one tile per game, Ludo first.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.games});
  final List<GameEntry> games;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              Text('Board Games', style: KitTheme.heading(size: 40)),
              const SizedBox(height: 4),
              Text('Pick a game and play offline', style: KitTheme.body(size: 15, color: KitColors.muted)),
              const SizedBox(height: 24),
              for (final g in games) ...[_Tile(entry: g), const SizedBox(height: 14)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry});
  final GameEntry entry;

  @override
  Widget build(BuildContext context) {
    final enabled = entry.route != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: entry.title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? () => Navigator.of(context).push(entry.route!()) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: entry.color.withValues(alpha: 0.2),
              border: Border.all(color: entry.color.withValues(alpha: 0.7), width: 1.5),
            ),
            child: Row(
              children: [
                TokenDisc(color: entry.color, shape: entry.shape, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title, style: KitTheme.heading(size: 24)),
                      Text(entry.tagline, style: KitTheme.body(size: 13, color: KitColors.muted)),
                    ],
                  ),
                ),
                if (enabled) const Icon(Icons.chevron_right_rounded, color: KitColors.gold, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
