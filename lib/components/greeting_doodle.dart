import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/greeting.dart';
import '../theme/vd_motion.dart';

typedef _DoodlePass = ({List<PathMetric> metrics, double length});

/// Chalk-style doodle for the home header: sunrise, sun + cloud, moon + stars
/// or a sleepy moon by device time. It draws itself in once like a pen
/// tracing each stroke (VdMotion.doodle; instant under reduced motion), and a
/// tap redraws it. No idle loop, so screens settle and the battery is spared.
class GreetingDoodle extends StatefulWidget {
  final DateTime now;
  final Color color;
  final double size;
  const GreetingDoodle({
    super.key,
    required this.now,
    required this.color,
    this.size = 80,
  });

  @override
  State<GreetingDoodle> createState() => _GreetingDoodleState();
}

class _GreetingDoodleState extends State<GreetingDoodle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.duration = VdMotion.of(context).doodle;
    if (!_started) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(GreetingDoodle old) {
    super.didUpdateWidget(old);
    if (doodleSceneFor(old.now) != doodleSceneFor(widget.now)) _play();
  }

  void _play() {
    if (_c.duration == Duration.zero) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = doodleSceneFor(widget.now);
    return Semantics(
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _play();
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: DoodlePainter(
              scene: scene,
              progress: Curves.easeInOut.transform(_c.value),
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [scene]'s strokes in a 100×100 box scaled to the canvas, the first
/// `progress` share of total stroke length (strokes drawn one after another).
/// Each stroke is jittered and drawn twice, offset, for a hand-drawn look
/// (the rough.js double-stroke technique). Seeded, so every frame matches.
class DoodlePainter extends CustomPainter {
  final DoodleScene scene;
  final double progress;
  final Color color;
  DoodlePainter({
    required this.scene,
    required this.progress,
    required this.color,
  });

  static final Map<DoodleScene, List<_DoodlePass>> _cache = {};

  /// Geometry and lengths are fixed per scene; measure once, not each frame.
  static List<_DoodlePass> _passes(DoodleScene scene) =>
      _cache.putIfAbsent(scene, () {
        final strokes = _strokes(scene);
        return [
          for (final seed in [scene.index * 31 + 7, scene.index * 31 + 19])
            _measure([
              for (final s in strokes) _sketch(s, math.Random(seed + s.length)),
            ]),
        ];
      });

  static _DoodlePass _measure(List<Path> paths) {
    final metrics = [for (final path in paths) ...path.computeMetrics()];
    return (
      metrics: metrics,
      length: metrics.fold<double>(0, (a, m) => a + m.length),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final k = size.shortestSide / 100;
    canvas.save();
    canvas.scale(k);
    final passes = _passes(scene);
    for (var p = 0; p < passes.length; p++) {
      final paint = Paint()
        ..color = color.withValues(alpha: color.a * (p == 0 ? 1 : 0.45))
        ..style = PaintingStyle.stroke
        ..strokeWidth = p == 0 ? 2.6 : 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      var left = passes[p].length * progress.clamp(0.0, 1.0);
      for (final m in passes[p].metrics) {
        if (left <= 0) break;
        canvas.drawPath(m.extractPath(0, math.min(left, m.length)), paint);
        left -= m.length;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DoodlePainter old) =>
      old.progress != progress || old.scene != scene || old.color != color;
}

// ── stroke geometry (100×100 box, y down) ──────────────────────────────────

/// A smooth path through jittered [pts] (quadratic curves via midpoints).
Path _sketch(List<Offset> pts, math.Random r) {
  Offset j(Offset o) =>
      o + Offset(r.nextDouble() * 2.4 - 1.2, r.nextDouble() * 2.4 - 1.2);
  final q = [for (final o in pts) j(o)];
  final path = Path()..moveTo(q.first.dx, q.first.dy);
  if (q.length == 2) return path..lineTo(q[1].dx, q[1].dy);
  for (var i = 1; i < q.length - 1; i++) {
    final mid = Offset.lerp(q[i], q[i + 1], 0.5)!;
    path.quadraticBezierTo(q[i].dx, q[i].dy, mid.dx, mid.dy);
  }
  return path..lineTo(q.last.dx, q.last.dy);
}

/// Points on an arc from angle [a0] to [a1] (radians, either direction).
List<Offset> _arc(Offset c, double r, double a0, double a1, [int n = 14]) => [
  for (var i = 0; i <= n; i++)
    c + Offset.fromDirection(a0 + (a1 - a0) * i / n, r),
];

List<Offset> _ray(Offset c, double angle, double r0, double r1) => [
  c + Offset.fromDirection(angle, r0),
  c + Offset.fromDirection(angle, r1),
];

List<Offset> _bird(double x, double y, double w) => [
  Offset(x, y),
  Offset(x + w * 0.3, y - w * 0.12),
  Offset(x + w / 2, y + w * 0.18),
  Offset(x + w * 0.7, y - w * 0.12),
  Offset(x + w, y),
];

List<Offset> _star(Offset c, double r) => [
  for (var i = 0; i <= 10; i++)
    c +
        Offset.fromDirection(
          -math.pi / 2 + i * math.pi / 5,
          i.isEven ? r : r * 0.45,
        ),
];

List<Offset> _z(double x, double y, double w) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x, y + w),
  Offset(x + w, y + w),
];

/// Crescent opening to the right: outer arc then the inner (bite) arc.
List<List<Offset>> _crescent(Offset c, double r) {
  final bite = c + Offset(r * 0.55, 0);
  final br = math.sqrt(math.pow(r * 0.55, 2) + r * r);
  final a = math.atan2(r, -r * 0.55);
  return [
    _arc(c, r, -math.pi / 2, -3 * math.pi / 2, 18),
    _arc(bite, br, a, 2 * math.pi - a, 12),
  ];
}

const double _pi = math.pi;

List<List<Offset>> _strokes(DoodleScene scene) {
  switch (scene) {
    case DoodleScene.sunrise:
      const c = Offset(46, 62);
      return [
        [const Offset(6, 63), const Offset(40, 61), const Offset(94, 64)],
        _arc(c, 22, _pi, 2 * _pi, 16),
        for (final d in [200.0, 235.0, 270.0, 305.0, 340.0])
          _ray(c, d * _pi / 180, 29, 39),
        _bird(70, 12, 12),
        _bird(84, 24, 8),
      ];
    case DoodleScene.sunCloud:
      const c = Offset(38, 38);
      return [
        _arc(c, 16, -_pi / 2, 3 * _pi / 2 + 0.35, 18),
        for (var i = 0; i < 8; i++) _ray(c, i * _pi / 4 - _pi / 8, 22, 30),
        [
          const Offset(48, 82),
          const Offset(94, 82),
          ..._arc(const Offset(86, 74), 8, _pi / 2, -_pi, 8),
          ..._arc(const Offset(70, 66), 12, -0.3, -_pi - 0.2, 10),
          ..._arc(const Offset(54, 74), 8, -0.4, -_pi * 1.5, 8),
        ],
      ];
    case DoodleScene.moonStars:
      return [
        ..._crescent(const Offset(42, 52), 26),
        _star(const Offset(80, 24), 9),
        _star(const Offset(86, 60), 5),
        [const Offset(68, 84), const Offset(68, 92)],
        [const Offset(64, 88), const Offset(72, 88)],
      ];
    case DoodleScene.sleepyMoon:
      return [
        ..._crescent(const Offset(38, 58), 22),
        _z(64, 40, 8),
        _z(76, 24, 11),
        _z(88, 6, 8),
      ];
  }
}
