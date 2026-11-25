import 'package:flutter/material.dart';
import 'confetti.dart';
import 'night_background.dart';
import 'theme.dart';
import 'token_disc.dart';

/// One row of the result table.
class ResultRowData {
  const ResultRowData({required this.rank, required this.name, required this.color, this.detail = ''});
  final int rank;
  final String name;
  final Color color;
  final String detail;
}

/// Generic end-of-game screen: trophy, title, ranks that slide in one by
/// one, confetti, and caller-supplied [actions] (Rematch, Home, ...).
class ResultView extends StatefulWidget {
  const ResultView({
    super.key,
    required this.title,
    required this.rows,
    required this.actions,
    this.confettiColors = const [KitColors.coral, KitColors.teal, KitColors.amber, KitColors.violet],
    this.reduceMotion = false,
    this.footer,
  });

  final String title;
  final List<ResultRowData> rows;
  final List<Widget> actions;
  final List<Color> confettiColors;
  final bool reduceMotion;
  final Widget? footer;

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.reduceMotion ? 1 : 1400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NightBackground(
      child: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: CurvedAnimation(parent: _c, curve: const Interval(0, 0.45, curve: Curves.elasticOut)),
                        child: const Text('🏆', style: TextStyle(fontSize: 72)),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.title, textAlign: TextAlign.center, style: KitTheme.heading(size: 32)),
                      const SizedBox(height: 18),
                      for (int i = 0; i < widget.rows.length; i++) _row(i, widget.rows[i]),
                      if (widget.footer != null) ...[const SizedBox(height: 8), widget.footer!],
                      const SizedBox(height: 18),
                      for (final a in widget.actions) ...[a, const SizedBox(height: 12)],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!widget.reduceMotion) ConfettiOverlay(colors: widget.confettiColors),
        ],
      ),
    );
  }

  Widget _row(int i, ResultRowData r) {
    final start = (0.3 + i * 0.1).clamp(0.0, 0.8);
    final anim = CurvedAnimation(parent: _c, curve: Interval(start, (start + 0.3).clamp(0.0, 1.0), curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(-30 * (1 - anim.value), 0), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: r.rank == 1 ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: r.rank == 1 ? Border.all(color: KitColors.gold, width: 1.5) : null,
        ),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text('${r.rank}', style: KitTheme.heading(size: 20))),
            InitialDisc(color: r.color, letter: r.name.characters.first.toUpperCase(), size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(r.name, style: KitTheme.body(size: 16, weight: FontWeight.w800))),
            Text(r.detail, style: KitTheme.body(size: 12, color: KitColors.muted)),
          ],
        ),
      ),
    );
  }
}
