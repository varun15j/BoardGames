import 'package:flutter/material.dart';
import 'reactions.dart';
import 'theme.dart';
import 'timer_ring.dart';
import 'token_disc.dart';

/// Avatar + name + progress for one player. When [active] the pod glows in
/// the player's colour and the ring around the avatar drains with
/// [timerFraction].
class PlayerPod extends StatelessWidget {
  const PlayerPod({
    super.key,
    required this.name,
    required this.color,
    required this.active,
    this.timerFraction,
    this.subtitle = '',
    this.homeCount = 0,
    this.totalTokens = 4,
    this.alignRight = false,
    this.reactionEmoji,
    this.reactionId = 0,
    this.reduceMotion = false,
    this.portrait,
  });

  /// Shown inside the timer ring instead of the initial letter.
  final Widget? portrait;

  final String name;
  final Color color;
  final bool active;

  /// 1 = full time left, 0 = out of time, null = no ring.
  final double? timerFraction;
  final String subtitle;
  final int homeCount;
  final int totalTokens;
  final bool alignRight;
  final String? reactionEmoji;
  final int reactionId;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final avatar = SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(46, 46),
            painter: TimerRingPainter(fraction: active ? (timerFraction ?? 0) : 0, color: color),
          ),
          portrait ?? InitialDisc(color: color, letter: name.isEmpty ? '?' : name.characters.first.toUpperCase(), size: 36),
          if (reactionEmoji != null)
            Positioned(
              left: 0,
              right: 0,
              top: -6,
              child: Center(child: FloatingEmoji(key: ValueKey(reactionId), emoji: reactionEmoji!, reduceMotion: reduceMotion)),
            ),
        ],
      ),
    );

    final info = Flexible(
      child: Column(
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KitTheme.body(size: 13, weight: FontWeight.w800)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: KitTheme.body(size: 11, color: KitColors.muted)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < totalTokens; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 2, left: 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < homeCount ? color : Colors.white.withValues(alpha: 0.18),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      label: '$name${active ? ", playing" : ""}, $homeCount of $totalTokens home',
      child: AnimatedScale(
        scale: active ? 1.04 : 1,
        duration: Duration(milliseconds: reduceMotion ? 0 : 300),
        child: AnimatedContainer(
          duration: Duration(milliseconds: reduceMotion ? 0 : 300),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: active ? color.withValues(alpha: 0.26) : Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: active ? color : Colors.white.withValues(alpha: 0.08), width: 1.5),
            boxShadow: [if (active) BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: -4)],
          ),
          child: Row(
            textDirection: alignRight ? TextDirection.rtl : TextDirection.ltr,
            children: [avatar, const SizedBox(width: 7), info],
          ),
        ),
      ),
    );
  }
}
