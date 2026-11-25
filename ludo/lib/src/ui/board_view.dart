import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../game/board.dart';
import '../game/models.dart';
import 'controller.dart';

/// The playing board: painted tiles, tokens, landing ghosts and effects.
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.controller, this.quality = GraphicsQuality.performance, this.tilt});
  final LudoController controller;
  final GraphicsQuality quality;

  /// Device tilt in -1..1; only used in optimized quality.
  final ValueListenable<Offset>? tilt;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _Fx {
  _Fx(this.key, this.builder);
  final Key key;
  final Widget Function(double unit, Key key) builder;
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  final List<_Fx> _fx = [];
  StreamSubscription<LudoEvent>? _sub;
  int _fxId = 0;
  final GlobalKey<FootprintLayerState> _footprints = GlobalKey();

  LudoController get c => widget.controller;
  bool get _optimized => widget.quality == GraphicsQuality.optimized;

  /// Largest board lean from phone movement (about 6 degrees).
  static const double _maxLean = 0.105;

  @override
  void initState() {
    super.initState();
    _sub = c.events.listen(_onEvent);
  }

  @override
  void didUpdateWidget(BoardView old) {
    super.didUpdateWidget(old);
    if (old.controller != c) {
      _sub?.cancel();
      _sub = c.events.listen(_onEvent);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _shake.dispose();
    super.dispose();
  }

  void _add(Widget Function(double unit, Key key) builder, {int ms = 1200}) {
    final fx = _Fx(ValueKey(_fxId++), builder);
    setState(() => _fx.add(fx));
    Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _fx.remove(fx));
    });
  }

  void _onEvent(LudoEvent e) {
    if (!mounted) return;
    switch (e) {
      case CaptureEvent(:final at, :final bySeat):
        final color = kCornerStyles[c.state.cornerOf(bySeat)].color;
        _add((u, k) => _Burst(key: k, at: at, unit: u, color: color, particles: _optimized ? 12 : 6), ms: 800);
        if (!c.reduceMotion) _shake.forward(from: 0);
      case SafeEvent(:final at):
        _add((u, k) => _Ripple(key: k, at: at, unit: u), ms: 800);
      case HomeEvent():
        _add((u, k) => _Ripple(key: k, at: const BoardPoint(7.5, 7.5), unit: u), ms: 800);
      case BannerEvent(:final text, :final color):
        _add((u, k) => _Banner(key: k, text: text, color: color, reduce: c.reduceMotion), ms: 1200);
      case StepEvent(:final seat, :final from, :final to, :final number, :final last):
        // With reduced motion only the final square is marked.
        if (c.reduceMotion && !last) return;
        final color = kCornerStyles[c.state.cornerOf(seat)].color;
        _footprints.currentState?.step(
          landing: Offset(to.col, to.row),
          direction: Offset(to.col - from.col, to.row - from.row),
          stepNumber: number,
          color: Color.lerp(color, KitColors.inkDark, 0.35)!,
        );
      case ReactionEvent():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board();
    final tilt = widget.tilt;
    if (!_optimized || tilt == null) return board;
    // Only the transform changes with each sensor tick; the board is reused.
    return ValueListenableBuilder<Offset>(
      valueListenable: tilt,
      child: board,
      builder: (context, t, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(t.dy * _maxLean)
          ..rotateY(-t.dx * _maxLean),
        child: child,
      ),
    );
  }

  Widget _board() {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 6) * 4 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFDCE6F7)],
            ),
            boxShadow: [
              if (_optimized) ...const [
                // A solid slab edge, then the soft shadow on the table.
                BoxShadow(color: Color(0xFF9FB0D3), offset: Offset(0, 6)),
                BoxShadow(color: Color(0xB3000000), blurRadius: 30, offset: Offset(0, 20), spreadRadius: -10),
              ],
            ],
          ),
          child: LayoutBuilder(builder: (context, box) {
            final side = math.min(box.maxWidth, box.maxHeight);
            final u = side / Board.size;
            return SizedBox(
              width: side,
              height: side,
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: BoardPainter()))),
                    // Prints sit under the pieces.
                    Positioned.fill(
                      child: FootprintLayer(key: _footprints, unit: u, quality: widget.quality),
                    ),
                    for (final g in c.ghosts) _ghost(g, u),
                    ..._tokens(u),
                    for (final fx in _fx) fx.builder(u, fx.key),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _ghost(GhostInfo g, double u) {
    final size = u * 0.95;
    return Positioned(
      left: g.at.col * u - size / 2,
      top: g.at.row * u - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(child: _GhostRing(capture: g.capture, reduce: c.reduceMotion)),
    );
  }

  List<Widget> _tokens(double u) {
    // Group tokens that share a drawn cell so they fan out instead of hiding.
    final entries = <({int seat, int token, BoardPoint p})>[];
    for (var s = 0; s < c.state.seatCount; s++) {
      for (var t = 0; t < c.state.tokenCount; t++) {
        entries.add((seat: s, token: t, p: c.displayPoint(s, t)));
      }
    }
    final groups = <BoardPoint, List<int>>{};
    for (var i = 0; i < entries.length; i++) {
      groups.putIfAbsent(entries[i].p, () => []).add(i);
    }
    final widgets = <(int, Widget)>[];
    for (final e in entries) {
      final idx = entries.indexOf(e);
      final group = groups[e.p]!;
      final home = c.display[e.seat][e.token] == Board.homeStep;
      final fan = group.length > 1 && !home;
      final a = group.indexOf(idx) / group.length * math.pi * 2;
      final dx = fan ? math.cos(a) * 0.22 : 0.0;
      final dy = fan ? math.sin(a) * 0.22 : 0.0;
      final isMovable = e.seat == c.state.turn && c.movable.contains(e.token) && c.humanToPick;
      final ref = TokenRef(e.seat, e.token);
      final fly = c.flying.contains(ref);
      final style = kCornerStyles[c.state.cornerOf(e.seat)];
      final box = u * 1.9;
      final tokenSize = u * (home ? 0.58 : 0.95) * (fan ? 0.82 : 1);
      widgets.add((
        isMovable ? 3 : (fly ? 2 : (home ? 0 : 1)),
        AnimatedPositioned(
          key: ValueKey('token-${e.seat}-${e.token}'),
          duration: Duration(milliseconds: c.reduceMotion ? 40 : (fly ? 550 : LudoController.stepMs - 20)),
          curve: fly ? Curves.easeInBack : Curves.easeInOut,
          left: (e.p.col + dx) * u - box / 2,
          top: (e.p.row + dy) * u - box / 2,
          width: box,
          height: box,
          child: TokenView(
            quality: widget.quality,
            tilt: widget.tilt,
            color: style.color,
            shape: style.shape,
            size: tokenSize,
            step: c.display[e.seat][e.token],
            movable: isMovable,
            reduceMotion: c.reduceMotion,
            semanticsLabel: '${c.config.seats[e.seat].name} token ${e.token + 1}',
            onTap: isMovable ? () => c.selectToken(e.token) : null,
          ),
        ),
      ));
    }
    widgets.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final w in widgets) w.$2];
  }
}

/// A token with hop, halo and bob animations.
class TokenView extends StatefulWidget {
  const TokenView({
    super.key,
    required this.color,
    required this.shape,
    required this.size,
    required this.step,
    required this.movable,
    required this.reduceMotion,
    this.quality = GraphicsQuality.performance,
    this.tilt,
    this.onTap,
    this.semanticsLabel,
  });

  final GraphicsQuality quality;
  final ValueListenable<Offset>? tilt;

  final Color color;
  final PlayerShape shape;
  final double size;
  final int step;
  final bool movable;
  final bool reduceMotion;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  State<TokenView> createState() => _TokenViewState();
}

class _TokenViewState extends State<TokenView> with TickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: LudoController.stepMs));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(TokenView old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step && !widget.reduceMotion) _hop.forward(from: 0);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.movable && !widget.reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: widget.movable,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: widget.movable ? HitTestBehavior.opaque : HitTestBehavior.translucent,
        onTap: widget.onTap,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_hop, _pulse]),
            builder: (context, _) {
              final h = math.sin(_hop.value * math.pi);
              final squash = _hop.value > 0.7 && _hop.value < 1 ? math.sin((_hop.value - 0.7) / 0.3 * math.pi) : 0.0;
              final bob = widget.movable ? -s * 0.14 * _pulse.value : 0.0;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (widget.movable)
                    MoveRing(size: s * 1.8, quality: widget.quality, reduceMotion: widget.reduceMotion),
                  Transform.translate(
                    offset: Offset(0, bob - s * 0.85 * h),
                    child: Transform(
                      // Stretch in the air, squash as it lands.
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(
                        1 + 0.14 * h + 0.12 * squash,
                        1 + 0.22 * h - 0.14 * squash,
                        1,
                      ),
                      child: PlayerToken(
                        color: widget.color,
                        shape: widget.shape,
                        size: s,
                        quality: widget.quality,
                        tilt: widget.tilt,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GhostRing extends StatefulWidget {
  const _GhostRing({required this.capture, required this.reduce});
  final bool capture;
  final bool reduce;

  @override
  State<_GhostRing> createState() => _GhostRingState();
}

class _GhostRingState extends State<_GhostRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    if (!widget.reduce) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: 0.95 - 0.45 * _c.value,
        child: CustomPaint(painter: _GhostPainter(widget.capture)),
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  _GhostPainter(this.capture);
  final bool capture;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1.5;
    final color = capture ? KitColors.danger : KitColors.gold;
    if (capture) {
      canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.28));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
      return;
    }
    // Dashed gold ring.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    const dashes = 12;
    for (var i = 0; i < dashes; i++) {
      final a = i / dashes * math.pi * 2;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, math.pi * 2 / dashes * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_GhostPainter old) => old.capture != capture;
}

class _Ripple extends StatelessWidget {
  const _Ripple({super.key, required this.at, required this.unit});
  final BoardPoint at;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final size = unit * 1.0;
    return Positioned(
      left: at.col * unit - size / 2,
      top: at.row * unit - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          builder: (context, t, _) => Transform.scale(
            scale: 1 + 3 * t,
            child: Opacity(
              opacity: 1 - t,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: KitColors.gold, width: 3)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Burst extends StatelessWidget {
  const _Burst({super.key, required this.at, required this.unit, required this.color, this.particles = 12});
  final int particles;
  final BoardPoint at;
  final double unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: at.col * unit,
      top: at.row * unit,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          builder: (context, t, _) => CustomPaint(painter: _BurstPainter(t, color, unit, particles)),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.color, this.unit, this.particles);
  final int particles;
  final double t;
  final Color color;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 1 - t);
    for (var i = 0; i < particles; i++) {
      final a = i / particles * math.pi * 2;
      final r = unit * (0.4 + (i.isEven ? 1.6 : 1.1) * Curves.easeOut.transform(t));
      canvas.drawCircle(Offset(math.cos(a) * r, math.sin(a) * r), unit * 0.17 * (1 - t * 0.8), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, required this.color, required this.reduce});
  final String text;
  final Color color;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            builder: (context, t, child) {
              final pop = reduce ? 1.0 : Curves.elasticOut.transform((t / 0.35).clamp(0.0, 1.0));
              final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
              return Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, reduce ? 0 : -24 * t),
                  child: Transform.rotate(angle: -0.05, child: Transform.scale(scale: 0.3 + 0.7 * pop, child: child)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 20, offset: Offset(0, 8))],
              ),
              child: Text(text, style: KitTheme.heading(size: 22, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the static board: bases, loop tiles, stars, home lanes, centre.
class BoardPainter extends CustomPainter {
  static const tileOutline = Color(0xFF6B7896);
  static const starColor = Color(0xFF27324F);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / Board.size;
    Rect cell(num r, num c, [double inset = 1]) =>
        Rect.fromLTWH(c * u + inset, r * u + inset, u - inset * 2, u - inset * 2);

    // Bases.
    for (var p = 0; p < 4; p++) {
      final color = kCornerStyles[p].color;
      final o = Board.baseOrigin[p];
      final outer = Rect.fromLTWH(o[1] * u + 2, o[0] * u + 2, u * 6 - 4, u * 6 - 4);
      canvas.drawRRect(RRect.fromRectAndRadius(outer, Radius.circular(u * 0.8)), Paint()..color = color);
      final inner = outer.deflate(u * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(u * 0.7)),
        Paint()..color = Colors.white,
      );
      for (final s in Board.sockets) {
        final c = Offset((o[1] + s[1]) * u, (o[0] + s[0]) * u);
        canvas.drawCircle(c, u * 0.55, Paint()..color = color.withValues(alpha: 0.45));
        canvas.drawCircle(
          c,
          u * 0.55,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      }
    }

    // Home lanes first, then the loop on top.
    for (var p = 0; p < 4; p++) {
      for (final rc in Board.lanes[p]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(cell(rc[0], rc[1]), Radius.circular(u * 0.2)),
          Paint()..color = kCornerStyles[p].color,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(cell(rc[0], rc[1]), Radius.circular(u * 0.2)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = tileOutline,
        );
      }
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = tileOutline;
    for (var i = 0; i < Board.loop.length; i++) {
      final rc = Board.loop[i];
      final rr = RRect.fromRectAndRadius(cell(rc[0], rc[1]), Radius.circular(u * 0.2));
      final startOf = Board.startIndex.indexOf(i);
      canvas.drawRRect(rr, Paint()..color = startOf >= 0 ? kCornerStyles[startOf].color : Colors.white);
      canvas.drawRRect(rr, edge);
      if (Board.isSafeLoopIndex(i)) {
        final centre = Offset(rc[1] * u + u / 2, rc[0] * u + u / 2);
        // White with a dark edge on start squares, solid dark elsewhere.
        if (startOf >= 0) _star(canvas, centre, u * 0.42, KitColors.inkDark);
        _star(canvas, centre, u * (startOf >= 0 ? 0.31 : 0.38), startOf >= 0 ? Colors.white : starColor);
      }
    }

    // Centre finish.
    final tri = [
      [Offset(6 * u, 6 * u), Offset(7.5 * u, 7.5 * u), Offset(6 * u, 9 * u)],
      [Offset(6 * u, 6 * u), Offset(7.5 * u, 7.5 * u), Offset(9 * u, 6 * u)],
      [Offset(9 * u, 6 * u), Offset(7.5 * u, 7.5 * u), Offset(9 * u, 9 * u)],
      [Offset(6 * u, 9 * u), Offset(7.5 * u, 7.5 * u), Offset(9 * u, 9 * u)],
    ];
    for (var p = 0; p < 4; p++) {
      final path = Path()..addPolygon(tri[p], true);
      canvas.drawPath(path, Paint()..color = kCornerStyles[p].color);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
    canvas.drawCircle(Offset(7.5 * u, 7.5 * u), u * 0.45, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(7.5 * u, 7.5 * u), u * 0.25, Paint()..color = KitColors.gold);
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var a = 0; a < 10; a++) {
      final rr = a.isOdd ? r * 0.42 : r;
      final an = -math.pi / 2 + a * math.pi / 5;
      final p = Offset(c.dx + rr * math.cos(an), c.dy + rr * math.sin(an));
      a == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(BoardPainter old) => false;
}
