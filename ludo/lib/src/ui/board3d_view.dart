import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_kit/game_kit.dart';

import '../game/board.dart';
import '../game/models.dart';
import 'controller.dart';
import 'seat_avatar.dart';

/// World position of a point given in board cells. The board is centred on
/// the origin with rows running toward the player.
V3 cellToWorld(double row, double col, [double y = 0]) => V3(col - 7.5, y, row - 7.5);

/// How far down the camera looks (65 degrees), and how big creatures are.
const double kCameraPitch = 1.134;
const double kCreatureScale = 1.45;

/// Height of the tops of the track tiles.
const double kTileTop = 0.16;

/// Height of the white panel inside a yard.
const double kYardTop = 0.29;

/// One token's travel from one place to another.
class Motion3 {
  Motion3({
    required this.from,
    required this.to,
    required this.start,
    required this.duration,
    required this.action,
    required this.leftLeads,
  });

  final V3 from;
  final V3 to;
  final double start;
  final double duration;
  final Action3 action;
  final bool leftLeads;

  double progress(double now) => duration <= 0 ? 1 : ((now - start) / duration).clamp(0.0, 1.0);

  V3 position(double now) {
    final p = progress(now);
    // Ease in and out so leaps gather speed and settle.
    return V3.lerp(from, to, p * p * (3 - 2 * p));
  }

  bool done(double now) => progress(now) >= 1;
}

/// Heading that faces the direction of travel (0 faces the player).
double headingFor(V3 from, V3 to) {
  final d = to - from;
  if (d.x.abs() < 1e-6 && d.z.abs() < 1e-6) return 0;
  return math.atan2(d.x, d.z);
}

class TokenState3 {
  TokenState3(this.motion, this.step, this.scale);
  Motion3 motion;
  int step;
  double scale;
  double heading = 0;
}

/// The 3D board: a real perspective scene drawn from the same game state as
/// the flat board.
class Board3DView extends StatefulWidget {
  const Board3DView({
    super.key,
    required this.controller,
    this.quality = GraphicsQuality.optimized,
    this.tilt,
    this.onBounce,
  });

  final LudoController controller;

  /// Performance quality draws the low-detail scene: fewer triangles, no
  /// shadows and no tilt.
  final GraphicsQuality quality;
  final ValueListenable<Offset>? tilt;
  final VoidCallback? onBounce;

  @override
  State<Board3DView> createState() => Board3DViewState();
}

class Board3DViewState extends State<Board3DView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final Scene3 scene = Scene3();
  StreamSubscription<LudoEvent>? _sub;
  String? _banner;
  Color _bannerColor = KitColors.danger;
  Timer? _bannerTimer;

  LudoController get c => widget.controller;
  bool get _low => widget.quality == GraphicsQuality.performance;

  /// Idle motion is redrawn at this interval to save battery.
  static const _idleFrame = 1 / 12;

  @override
  void initState() {
    super.initState();
    scene.low = _low;
    _sync();
    c.addListener(_sync);
    _sub = c.events.listen(_onEvent);
    _ticker.start();
  }

  @override
  void didUpdateWidget(Board3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quality != widget.quality) {
      scene.low = _low;
      scene.invalidate();
    }
  }

  @override
  void dispose() {
    c.removeListener(_sync);
    _sub?.cancel();
    _bannerTimer?.cancel();
    _ticker.dispose();
    scene.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    scene.now = elapsed.inMicroseconds / 1e6;
    scene.trail.expire(elapsed);
    scene.clock = elapsed;
    _dieImpacts();
    final shut = [for (final b in scene.blinks) !_low && !c.reduceMotion && b.isClosedAt(elapsed)];
    final blinked = !listEquals(shut, scene.eyesShut);
    scene.eyesShut = shut;
    final busy = scene.busy(c);
    final idle = !_low && !c.reduceMotion && scene.now - scene.painted >= _idleFrame;
    if (busy || idle || blinked) scene.repaint();
  }

  void _dieImpacts() {
    final die = scene.die;
    if (die == null) return;
    final p = die.progress(scene.now);
    while (die.impacts < DieThrow.impacts.length && p >= DieThrow.impacts[die.impacts]) {
      die.impacts++;
      widget.onBounce?.call();
    }
  }

  /// Brings the scene up to date with the controller.
  void _sync() {
    final state = c.state;
    // A new roll throws the die onto the board.
    if (c.rollId != scene.rollId) {
      scene.rollId = c.rollId;
      final rng = math.Random(c.rollId * 13 + 5);
      scene.die = DieThrow3(
        value: c.dieValue,
        seed: c.rollId,
        start: scene.now,
        duration: c.reduceMotion ? 0.01 : DieView.rollDuration.inMilliseconds / 1000,
        from: const V3(0, kTileTop, 9),
        rest: V3((rng.nextDouble() - 0.5) * 3, 0.82, 1 + rng.nextDouble() * 1.5),
      );
    } else if (c.phase == TurnPhase.moving) {
      scene.die = null; // clear the board for the pieces
    }

    final placed = <TokenRef, (V3, double, int)>{};
    final cells = <BoardPoint, List<TokenRef>>{};
    for (var s = 0; s < state.seatCount; s++) {
      for (var t = 0; t < state.tokenCount; t++) {
        cells.putIfAbsent(c.displayPoint(s, t), () => []).add(TokenRef(s, t));
      }
    }
    for (final entry in cells.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final ref = entry.value[i];
        final step = c.display[ref.seat][ref.token];
        final home = step == Board.homeStep;
        final fan = entry.value.length > 1 && !home;
        final spot = fan ? clusterOffsets(entry.value.length)[i] : Offset.zero;
        final point = entry.key;
        final y = step < 0 ? kYardTop : (home ? 0.5 : kTileTop);
        placed[ref] = (
          cellToWorld(point.row + spot.dy, point.col + spot.dx, y),
          (home ? 0.62 : 1.0) * (fan ? clusterScale(entry.value.length) : 1),
          step,
        );
      }
    }

    for (final e in placed.entries) {
      final (to, scale, step) = e.value;
      final old = scene.tokens[e.key];
      if (old == null) {
        scene.tokens[e.key] = TokenState3(
          Motion3(from: to, to: to, start: scene.now, duration: 0, action: Action3.idle, leftLeads: false),
          step,
          scale,
        );
        continue;
      }
      old.scale = scale;
      if (old.step == step && old.motion.to == to) continue;
      final knocked = c.flying.contains(e.key);
      final hopped = old.step != step;
      final from = old.motion.position(scene.now);
      final action = knocked ? Action3.knocked : (hopped ? Action3.move : Action3.idle);
      final seconds = c.reduceMotion ? 0.02 : (knocked ? 0.62 : (hopped ? LudoController.stepMs / 1000 : 0.2));
      old.motion = Motion3(
        from: from,
        to: to,
        start: scene.now,
        duration: seconds,
        action: action,
        leftLeads: !old.motion.leftLeads,
      );
      if (hopped && !knocked) old.heading = headingFor(from, to);
      if (step == Board.homeStep && old.step != step) scene.cheering[e.key] = scene.now + seconds;
      old.step = step;
    }
    scene.repaint();
  }

  void _onEvent(LudoEvent e) {
    if (!mounted) return;
    switch (e) {
      case StepEvent(:final seat, :final from, :final to, :final number, :final last):
        if (c.reduceMotion && !last) return;
        scene.trail.style = _low ? FootprintStyle.performance : FootprintStyle.optimized;
        scene.trail.add(
          landing: Offset(to.col, to.row),
          direction: Offset(to.col - from.col, to.row - from.row),
          stepNumber: number,
          color: Color.lerp(kCornerStyles[c.state.cornerOf(seat)].color, KitColors.inkDark, 0.35)!,
          now: scene.clock,
        );
      case BannerEvent(:final text, :final color):
        _bannerTimer?.cancel();
        setState(() {
          _banner = text;
          _bannerColor = color;
        });
        _bannerTimer = Timer(const Duration(milliseconds: 1100), () {
          if (mounted) setState(() => _banner = null);
        });
      case CaptureEvent() || SafeEvent() || HomeEvent() || ReactionEvent():
        break;
    }
  }

  void _tap(Offset at) {
    if (!c.canPickHere) return;
    int? best;
    var nearest = double.infinity;
    for (final token in c.movable) {
      final s = scene.tokens[TokenRef(c.state.turn, token)];
      if (s == null) continue;
      final centre = s.motion.to + const V3(0, 0.45, 0);
      final d = (scene.camera.project(centre) - at).distance;
      if (d < nearest && d <= scene.camera.pixelsPerUnit(centre) * 1.2) {
        nearest = d;
        best = token;
      }
    }
    if (best != null) c.selectToken(best);
  }

  /// Where a movable token is on screen, for tests.
  Offset screenPositionOf(int seat, int token) =>
      scene.camera.project(scene.tokens[TokenRef(seat, token)]!.motion.to + const V3(0, 0.45, 0));

  @override
  Widget build(BuildContext context) {
    final tilt = _low ? null : widget.tilt;
    return SizedBox.expand(
      child: Semantics(
        label: '3D board',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(d.localPosition),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: ListenableBuilder(
                  listenable: AvatarImages.instance,
                  builder: (context, _) => CustomPaint(
                    painter: Board3DPainter(this, tilt, MediaQuery.devicePixelRatioOf(context)),
                  ),
                ),
              ),
              if (_banner != null)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: _bannerColor, borderRadius: BorderRadius.circular(14)),
                      child: Text(_banner!, style: KitTheme.heading(size: 22, color: Colors.white)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DieThrow3 {
  DieThrow3({
    required this.value,
    required this.seed,
    required this.start,
    required this.duration,
    required this.from,
    required this.rest,
  });
  final int value;
  final int seed;
  final double start;
  final double duration;
  final V3 from;
  final V3 rest;
  int impacts = 0;

  double progress(double now) => ((now - start) / duration).clamp(0.0, 1.0);
}

/// A resting creature as recorded drawing commands.
class TokenPicture {
  TokenPicture(this.picture, this.key, this.drawn);
  final ui.Picture picture;
  final Object key;
  final double drawn;
}

/// Everything the painter needs that changes over time, plus its caches.
class Scene3 extends ChangeNotifier {
  final Map<TokenRef, TokenState3> tokens = {};
  final Map<TokenRef, double> cheering = {};
  final FootprintTrail trail = FootprintTrail();
  final List<BlinkSchedule> blinks = [for (var i = 0; i < 4; i++) BlinkSchedule(math.Random(i * 7 + 1))];
  List<bool> eyesShut = const [false, false, false, false];
  final Map<(String, int, bool), CreatureModel> models = {};
  final Map<bool, DieModel> dice = {};

  /// Resting creatures, each drawn once and replayed.
  final Map<TokenRef, TokenPicture> resting = {};
  final Map<(AvatarChoice, ui.Image), ui.Image> faces = {};
  ui.Image? floorImage;
  final List<(int, Path, Paint, bool?)> eyes = [];
  int frame = 0;
  final TriangleBatch batch = TriangleBatch(1024);
  Camera3 camera = Camera3(pitch: kCameraPitch);
  Offset lean = Offset.zero;
  Object? floorKey;
  DieThrow3? die;
  int rollId = 0;
  double now = 0;
  double painted = 0;
  Duration clock = Duration.zero;
  bool low = false;

  CreatureModel model(String avatarId, int color) => models.putIfAbsent(
        (speciesFor(avatarId).name, color, low),
        () => CreatureModel(speciesFor(avatarId), color, low: low),
      );

  /// Something is moving that needs every frame.
  bool busy(LudoController c) =>
      tokens.values.any((t) => !t.motion.done(now)) ||
      cheering.values.any((until) => now < until + 0.6) ||
      (die != null && die!.progress(now) < 1) ||
      c.movable.isNotEmpty ||
      !trail.isEmpty;

  void repaint() => notifyListeners();

  void clearResting() {
    for (final p in resting.values) {
      p.picture.dispose();
    }
    resting.clear();
  }

  void invalidate() {
    floorKey = null;
    models.clear();
    clearResting();
    notifyListeners();
  }

  @override
  void dispose() {
    floorImage?.dispose();
    clearResting();
    for (final f in faces.values) {
      f.dispose();
    }
    trail.dispose();
    super.dispose();
  }
}

/// Draws the floor (cached per camera angle), then the moving things.
class Board3DPainter extends CustomPainter {
  Board3DPainter(this.view, this.tilt, this.ratio)
      : super(repaint: tilt == null ? view.scene : Listenable.merge([view.scene, tilt]));

  /// Device pixel ratio the cached board is drawn at.
  final double ratio;

  final Board3DViewState view;
  final ValueListenable<Offset>? tilt;

  Scene3 get scene => view.scene;
  LudoController get c => view.c;

  static final List<V3> _bounds = [
    for (final x in [-7.9, 7.9])
      for (final z in [-7.9, 7.9]) ...[V3(x, -0.7, z), V3(x, 0.2, z)],
    const V3(0, 1.9, -7.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    scene.painted = scene.now;
    scene.frame++;
    // Tilt orbits the camera in coarse steps with a wide dead band, so the
    // cached board is only redrawn after a real movement of the phone.
    final t = tilt?.value ?? Offset.zero;
    if ((t - scene.lean).distance > 0.4 || (t == Offset.zero && scene.lean != Offset.zero)) scene.lean = t;
    final yaw = scene.lean.dx * 0.07;
    final pitch = kCameraPitch + scene.lean.dy * 0.05;
    final images = [
      for (var s = 0; s < c.state.seatCount; s++)
        AvatarImages.instance.image(seatAvatar(c.config.seats[s]), 128),
    ];
    final key = (size.width, size.height, yaw, pitch, scene.low, Object.hashAll(images));
    if (key != scene.floorKey) {
      scene.floorKey = key;
      scene.camera = Camera3(pitch: pitch, yaw: yaw)..fit(_bounds, size.width, size.height, 0.995);
      final recorder = ui.PictureRecorder();
      final offscreen = Canvas(recorder)..scale(ratio);
      _paintFloor(offscreen);
      _paintYardFloor(offscreen);
      final picture = recorder.endRecording();
      scene.floorImage?.dispose();
      scene.floorImage = picture.toImageSync((size.width * ratio).ceil(), (size.height * ratio).ceil());
      picture.dispose();
      scene.eyes.clear();
      scene.clearResting();
    }
    final floor = scene.floorImage!;
    canvas.drawImageRect(
      floor,
      Rect.fromLTWH(0, 0, floor.width.toDouble(), floor.height.toDouble()),
      Rect.fromLTWH(0, 0, floor.width / ratio, floor.height / ratio),
      Paint()..filterQuality = FilterQuality.low,
    );
    _paintEyes(canvas);
    _paintFootprints(canvas);
    _paintRings(canvas);
    _paintObjects(canvas);
  }

  // ------------------------------------------------------------ floor

  void _paintFloor(Canvas canvas) {
    final camera = scene.camera;
    final batch = TriangleBatch(512);
    final paint = Paint();
    void flush() {
      batch.draw(canvas, paint);
      batch.clear();
    }

    batch.add(Mesh.box(15.8, 0.7, 15.8, 0xFFAAB8D8, top: 0xFFEEF3FC), Mat.move(0, -0.7, 0), camera);
    flush();

    for (var p = 0; p < 4; p++) {
      final o = Board.baseOrigin[p];
      final centre = cellToWorld(o[0] + 3, o[1] + 3);
      final color = kCornerStyles[p].color.toARGB32();
      batch.add(Mesh.box(5.9, 0.25, 5.9, color), Mat.move(centre.x, 0, centre.z), camera);
      flush();
      batch.add(Mesh.box(4.4, 0.04, 4.4, 0xFFFFFFFF), Mat.move(centre.x, 0.25, centre.z), camera);
      flush();
    }

    final tile = Mesh.box(0.9, kTileTop, 0.9, 0xFFC3CDE4, top: 0xFFFFFFFF);
    final tinted = <int, Mesh>{};
    Mesh coloured(int p) {
      final color = kCornerStyles[p].color.toARGB32();
      return tinted.putIfAbsent(p, () => Mesh.box(0.9, kTileTop, 0.9, color, top: color));
    }

    for (var i = 0; i < Board.loop.length; i++) {
      final rc = Board.loop[i];
      final start = Board.startIndex.indexOf(i);
      final at = cellToWorld(rc[0] + 0.5, rc[1] + 0.5);
      batch.add(start >= 0 ? coloured(start) : tile, Mat.move(at.x, 0, at.z), camera);
    }
    for (var p = 0; p < 4; p++) {
      for (final rc in Board.lanes[p]) {
        final at = cellToWorld(rc[0] + 0.5, rc[1] + 0.5);
        batch.add(coloured(p), Mat.move(at.x, 0, at.z), camera);
      }
    }
    flush();

    // The home pyramid: one face per colour.
    const apex = V3(0, 0.75, 0);
    const h = 1.5;
    const corners = [V3(-h, 0.05, -h), V3(h, 0.05, -h), V3(h, 0.05, h), V3(-h, 0.05, h)];
    const faces = [(3, 0), (0, 1), (1, 2), (2, 3)]; // left, back, right, front
    for (var p = 0; p < 4; p++) {
      final (a, b) = faces[p];
      batch.add(
        Mesh([corners[a], corners[b], apex], const [0, 2, 1], [kCornerStyles[p].color.toARGB32()]),
        Mat.identity,
        camera,
      );
    }
    flush();
    _flatDisc(canvas, const V3(0, 0.76, 0), 0.34, const Color(0xFFFFFFFF));
    _flatDisc(canvas, const V3(0, 0.77, 0), 0.2, KitColors.gold);

    // Safe-square stars.
    for (final i in Board.safeIndices) {
      final rc = Board.loop[i];
      final centre = cellToWorld(rc[0] + 0.5, rc[1] + 0.5, kTileTop + 0.005);
      final path = Path();
      for (var k = 0; k < 10; k++) {
        final r = k.isOdd ? 0.15 : 0.36;
        final a = -math.pi / 2 + k * math.pi / 5;
        final s = camera.project(centre + V3(r * math.cos(a), 0, r * math.sin(a)));
        k == 0 ? path.moveTo(s.dx, s.dy) : path.lineTo(s.dx, s.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = Board.startIndex.contains(i) ? Colors.white : const Color(0xFF27324F),
      );
    }
  }

  Path _circlePath(V3 centre, double radius, [int sides = 20]) {
    final points = [
      for (var i = 0; i < sides; i++)
        scene.camera.project(
          centre + V3(radius * math.cos(i * math.pi * 2 / sides), 0, radius * math.sin(i * math.pi * 2 / sides)),
        ),
    ];
    return Path()..addPolygon(points, true);
  }

  void _flatDisc(Canvas canvas, V3 centre, double radius, Color color) =>
      canvas.drawPath(_circlePath(centre, radius), Paint()..color = color);

  // ------------------------------------------------------------ decals

  /// The avatar watermark and cheeks on each yard floor.
  void _paintYardFloor(Canvas canvas) {
    for (var s = 0; s < c.state.seatCount; s++) {
      final corner = c.state.cornerOf(s);
      final o = Board.baseOrigin[corner];
      final color = kCornerStyles[corner].color;
      _watermark(canvas, o, AvatarImages.instance.image(seatAvatar(c.config.seats[s]), 128));
      for (final k in YardFaceLayout.cheeks) {
        final at = cellToWorld(o[0] + k.dy, o[1] + k.dx, kYardTop + 0.005);
        _flatDisc(canvas, at, 0.55, color.withValues(alpha: 0.5));
      }
    }
  }

  /// Blinking eyes on the top two spots, from shapes worked out once per
  /// camera angle. Each entry is (corner, shape, paint, shown when shut).
  void _paintEyes(Canvas canvas) {
    if (scene.eyes.isEmpty) {
      for (var s = 0; s < c.state.seatCount; s++) {
        final corner = c.state.cornerOf(s);
        final o = Board.baseOrigin[corner];
        final color = kCornerStyles[corner].color;
        final dark = Color.lerp(color, KitColors.inkDark, 0.55)!;
        for (final e in YardFaceLayout.eyes) {
          final at = cellToWorld(o[0] + e.dy, o[1] + e.dx, kYardTop + 0.005);
          void disc(double radius, Color tint, bool? shut) =>
              scene.eyes.add((corner, _circlePath(at, radius), Paint()..color = tint, shut));
          disc(0.66, dark, false);
          disc(0.56, Colors.white, false);
          disc(0.34, color, false);
          disc(0.16, KitColors.inkDark, false);
          disc(0.62, color, true);
          scene.eyes.add((
            corner,
            Path()
              ..moveTo(scene.camera.project(at + const V3(-0.4, 0, 0)).dx, scene.camera.project(at + const V3(-0.4, 0, 0)).dy)
              ..lineTo(scene.camera.project(at + const V3(0.4, 0, 0)).dx, scene.camera.project(at + const V3(0.4, 0, 0)).dy),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round
              ..color = dark,
            true,
          ));
        }
      }
    }
    for (final (corner, path, paint, shut) in scene.eyes) {
      if (shut == scene.eyesShut[corner]) canvas.drawPath(path, paint);
    }
  }

  void _watermark(Canvas canvas, List<int> origin, ui.Image image) {
    const n = 3;
    final xy = Float32List(n * n * 12);
    final uv = Float32List(n * n * 12);
    var k = 0;
    void corner(int i, int j) {
      final at = cellToWorld(origin[0] + 0.8 + 4.4 * j / n, origin[1] + 0.8 + 4.4 * i / n, kYardTop);
      final s = scene.camera.project(at);
      xy[k] = s.dx;
      xy[k + 1] = s.dy;
      uv[k] = image.width * i / n;
      uv[k + 1] = image.height * j / n;
      k += 2;
    }

    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        corner(i, j);
        corner(i + 1, j);
        corner(i + 1, j + 1);
        corner(i, j);
        corner(i + 1, j + 1);
        corner(i, j + 1);
      }
    }
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, xy, textureCoordinates: uv);
    canvas.drawVertices(
      vertices,
      BlendMode.srcOver,
      Paint()
        ..color = const Color.fromRGBO(0, 0, 0, 0.3)
        ..shader = ui.ImageShader(image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage),
    );
    vertices.dispose();
  }

  void _paintFootprints(Canvas canvas) {
    final style = scene.trail.style;
    for (final p in scene.trail.prints) {
      final opacity = footprintOpacity(scene.clock - p.born, style.life);
      if (opacity <= 0) continue;
      final at = cellToWorld(p.position.dy, p.position.dx, kTileTop + 0.01);
      _flatDisc(canvas, at, 0.15, p.color.withValues(alpha: opacity));
      if (!style.dots) {
        final back = V3(-math.sin(p.angle), 0, math.cos(p.angle)) * 0.2;
        _flatDisc(canvas, at + back, 0.09, p.color.withValues(alpha: opacity));
      }
    }
  }

  /// The rotating ring, flat on the tile under each token that can move.
  void _paintRings(Canvas canvas) {
    if (c.movable.isEmpty || !c.humanToPick) return;
    final turn = c.reduceMotion ? 0.0 : scene.now / (MoveRing.turn.inMilliseconds / 1000) * math.pi * 2;
    for (final token in c.movable) {
      final s = scene.tokens[TokenRef(c.state.turn, token)];
      if (s == null) continue;
      final centre = s.motion.to + const V3(0, 0.02, 0);
      for (var i = 0; i < 6; i++) {
        final path = Path();
        for (var k = 0; k <= 5; k++) {
          final a = turn + i * math.pi / 3 + k / 5 * math.pi / 3 * 0.62;
          final p = scene.camera.project(centre + V3(0.72 * math.cos(a), 0, 0.72 * math.sin(a)));
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, stroke..strokeWidth = 6.5..color = KitColors.stage);
        canvas.drawPath(path, stroke..strokeWidth = 4..color = i.isEven ? KitColors.gold : Colors.white);
      }
    }
  }

  /// One pre-rendered soft oval under a creature or the die.
  void _shadow(Canvas canvas, V3 at, double radius, [double strength = 1]) {
    if (scene.low) return;
    final image = CharacterSprites.shadow;
    final r = scene.camera.pixelsPerUnit(at) * radius;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: scene.camera.project(at + const V3(0.08, 0, 0.04)), width: r * 3, height: r * 1.7),
      Paint()..color = Color.fromRGBO(0, 0, 0, strength),
    );
  }

  // ------------------------------------------------------------ objects

  /// Creatures and the die, farthest first.
  void _paintObjects(Canvas canvas) {
    final camera = scene.camera;
    final objects = <(double, void Function())>[];
    final fill = Paint();

    var index = 0;
    var refreshed = 0;
    for (final entry in scene.tokens.entries) {
      final ref = entry.key;
      final token = entry.value;
      final at = token.motion.position(scene.now);
      final slot = index++;
      final cheerUntil = scene.cheering[ref];
      final live = !token.motion.done(scene.now) ||
          (cheerUntil != null && scene.now < cheerUntil + 0.6) ||
          // Still turning back to face the player.
          scene.now - token.motion.start - token.motion.duration < 0.9;
      objects.add((
        camera.toCamera(at).z,
        () {
          if (live) {
            scene.resting.remove(ref)?.picture.dispose();
            _paintCreature(canvas, ref, token, at, fill);
            return;
          }
          // Resting: replay the picture; redraw it now and then for the idle
          // motion, only a couple per frame so the cost stays level.
          final key = (token.motion.to, token.scale, seatAvatar(c.config.seats[ref.seat]));
          var cached = scene.resting[ref];
          final stale = cached != null &&
              !scene.low &&
              !c.reduceMotion &&
              scene.now - cached.drawn > 0.33 &&
              (scene.frame + slot) % 4 == 0 &&
              refreshed < 2;
          if (cached == null || cached.key != key || stale) {
            if (stale) refreshed++;
            cached?.picture.dispose();
            final recorder = ui.PictureRecorder();
            _paintCreature(Canvas(recorder), ref, token, at, fill);
            cached = scene.resting[ref] = TokenPicture(recorder.endRecording(), key, scene.now);
          }
          canvas.drawPicture(cached.picture);
        },
      ));
    }

    final die = scene.die;
    if (die != null) {
      final model = scene.dice.putIfAbsent(scene.low, () => DieModel(1.5));
      final pose = dieThrowPose(die.value, die.progress(scene.now), die.seed, die.from, die.rest);
      objects.add((
        // The die is thrown over everything near it.
        camera.toCamera(V3(pose.tx, pose.ty, pose.tz)).z + 1,
        () {
          final height = DieThrow.height(die.progress(scene.now));
          _shadow(canvas, V3(pose.tx, die.rest.y - 0.6, pose.tz), 0.8 * (1 - 0.4 * height), 1 - 0.5 * height);
          final placed = model.centred(pose);
          scene.batch.clear();
          scene.batch.add(model.cube, placed, camera);
          scene.batch.draw(canvas, fill);
          scene.batch.clear();
          scene.batch.add(model.pipMesh, placed, camera);
          scene.batch.draw(canvas, fill);
        },
      ));
    }

    objects.sort((a, b) => a.$1.compareTo(b.$1));
    for (final o in objects) {
      o.$2();
    }
    _paintCounts(canvas);
  }

  void _paintCreature(Canvas canvas, TokenRef ref, TokenState3 token, V3 at, Paint fill) {
    final camera = scene.camera;
    final corner = c.state.cornerOf(ref.seat);
    final style = kCornerStyles[corner];
    final choice = seatAvatar(c.config.seats[ref.seat]);
    final avatarId = choice.isPhoto ? 'photo' : choice.avatarId;
    final model = scene.model(avatarId, style.color.toARGB32());
    final gait = choice.isPhoto ? Gait3.walker : gaitFor(choice.avatar);

    final moving = !token.motion.done(scene.now);
    final cheerUntil = scene.cheering[ref];
    final cheer = cheerUntil != null && scene.now >= cheerUntil && scene.now < cheerUntil + 0.6;
    final Anim3 anim;
    if (cheer) {
      anim = Anim3(action: Action3.cheer, progress: (scene.now - cheerUntil) / 0.6, time: scene.now);
    } else if (moving) {
      anim = Anim3(
        action: token.motion.action,
        progress: token.motion.progress(scene.now),
        time: scene.now,
        leftLeads: token.motion.leftLeads,
      );
    } else {
      // Each token idles on its own beat.
      anim = Anim3(time: c.reduceMotion ? 0 : scene.now + ref.seat * 1.3 + ref.token * 0.7);
    }
    // Face the way of travel, then turn back to face the player.
    final since = scene.now - token.motion.start - token.motion.duration;
    final heading = moving || since < 0.5 ? token.heading : token.heading * math.max(0, 1 - (since - 0.5) * 3);

    final ground = Mat.move(at.x, at.y, at.z);
    final scale = Mat.scale(kCreatureScale * token.scale);
    _shadow(canvas, at, 0.42 * token.scale);
    // A flat ring of the player's colour marks the feet.
    canvas.drawPath(_circlePath(at + const V3(0, 0.015, 0), 0.5 * token.scale, 14), Paint()..color = style.color);
    // At rest a cat stands three-quarters on so its body and tail show, and
    // every creature tips its face a little up toward the camera.
    // The stand-in faces the player squarely, so its picture sits on its head.
    final rest = model.species == Species3.mascot ? 0.0 : (gait == Gait3.quadruped ? 0.65 : 0.2);
    final turned = moving ? heading : heading + rest * (heading == 0 ? 1 : 0);
    final world = ground * scale * Mat.rotX(-0.22) * Mat.rotY(turned);
    scene.batch.clear();
    for (final part in model.pose(gait, anim)) {
      scene.batch.add(part.mesh, world * part.at, camera);
    }
    scene.batch.draw(canvas, fill);

    // Overlays: a face for the mascot and the shape badge.
    if (model.species == Species3.mascot) {
      final head = world.apply(model.headPoint(gait, anim) + const V3(0, 0, 0.2));
      final r = camera.pixelsPerUnit(head) * kMascotFaceRadius * kCreatureScale * token.scale;
      final face = _roundFace(choice);
      final rect = Rect.fromCircle(center: camera.project(head), radius: r);
      canvas.drawCircle(rect.center, r * 1.1, Paint()..color = KitColors.inkDark);
      canvas.drawImageRect(
        face,
        Rect.fromLTWH(0, 0, face.width.toDouble(), face.height.toDouble()),
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    final foot = camera.project(at + V3(-0.3 * token.scale, 0.1, 0.3 * token.scale));
    final r = camera.pixelsPerUnit(at) * 0.17 * token.scale;
    canvas.drawCircle(foot, r + 1.2, Paint()..color = KitColors.inkDark);
    canvas.drawCircle(foot, r, Paint()..color = style.color);
    paintShapeMark(canvas, foot, r * 1.1, style.shape, 1);
  }

  /// The avatar cut to a circle, once.
  ui.Image _roundFace(AvatarChoice choice) {
    final source = AvatarImages.instance.image(choice, 128);
    return scene.faces.putIfAbsent((choice, source), () {
      final side = source.width.toDouble();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..clipPath(Path()..addOval(Rect.fromLTWH(0, 0, side, side)));
      canvas.drawImage(source, Offset.zero, Paint());
      final picture = recorder.endRecording();
      final image = picture.toImageSync(source.width, source.width);
      picture.dispose();
      return image;
    });
  }

  void _paintCounts(Canvas canvas) {
    final counts = <BoardPoint, int>{};
    for (var s = 0; s < c.state.seatCount; s++) {
      for (var t = 0; t < c.state.tokenCount; t++) {
        final step = c.display[s][t];
        if (step < 0 || step == Board.homeStep) continue;
        counts.update(c.displayPoint(s, t), (n) => n + 1, ifAbsent: () => 1);
      }
    }
    for (final e in counts.entries) {
      if (!showCountBadge(e.value)) continue;
      final at = cellToWorld(e.key.row, e.key.col + 0.35, 1.1);
      final centre = scene.camera.project(at);
      final r = scene.camera.pixelsPerUnit(at) * 0.3;
      canvas.drawCircle(centre, r + 1.5, Paint()..color = KitColors.inkDark);
      canvas.drawCircle(centre, r, Paint()..color = KitColors.gold);
      final text = TextPainter(
        text: TextSpan(
          text: '${e.value}',
          style: TextStyle(fontSize: r * 1.3, fontWeight: FontWeight.w800, color: KitColors.goldInk),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(Board3DPainter oldDelegate) => true;
}
