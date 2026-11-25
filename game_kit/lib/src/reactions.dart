import 'package:flutter/material.dart';
import 'theme.dart';

/// Emoji available in the reactions sheet.
const List<String> kReactionEmoji = ['😀', '😂', '😮', '😢', '😡', '👍', '👏', '🎲', '🔥', '🙏'];

/// Shows the reactions bottom sheet and returns the chosen emoji, if any.
Future<String?> showReactionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF1E2E52),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)),
            ),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final e in kReactionEmoji)
                  Semantics(
                    button: true,
                    label: 'Send $e',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(e),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// An emoji that pops out, floats up and fades (1.6 s).
class FloatingEmoji extends StatefulWidget {
  const FloatingEmoji({super.key, required this.emoji, this.reduceMotion = false});
  final String emoji;
  final bool reduceMotion;

  @override
  State<FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<FloatingEmoji> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final rise = widget.reduceMotion ? 0.0 : -70 * Curves.easeOut.transform(t);
          final scale = widget.reduceMotion ? 1.0 : (t < 0.15 ? 0.4 + 0.85 * (t / 0.15) : 1.25 - 0.25 * ((t - 0.15) / 0.85));
          final opacity = t < 0.15 ? t / 0.15 : (1 - ((t - 0.15) / 0.85)).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Transform.translate(offset: Offset(0, rise), child: Transform.scale(scale: scale, child: child)),
          );
        },
        child: Text(widget.emoji, style: const TextStyle(fontSize: 28, color: KitColors.ink)),
      ),
    );
  }
}
