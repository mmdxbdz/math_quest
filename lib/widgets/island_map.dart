import 'dart:math';
import 'package:flutter/material.dart';
import '../content/curriculum.dart';
import '../models.dart';
import '../pets.dart';
import '../store.dart';
import '../three_d.dart';
import 'island_scene.dart';

const List<String> kStageNames = ['基础', '提高', '挑战'];

/// 一关 = 一个课时的一个阶段（基础 / 提高 / 挑战）
class MapLevel {
  final Lesson lesson;
  final int stage;
  final String key;
  final int index;
  final int stars;
  final bool unlocked;
  final bool current;

  /// 屏幕上的投影位置与缩放（像素 / 世界单位）
  final double x;
  final double y;
  final double px;

  const MapLevel({
    required this.lesson,
    required this.stage,
    required this.key,
    required this.index,
    required this.stars,
    required this.unlocked,
    required this.current,
    this.x = 0,
    this.y = 0,
    this.px = 1,
  });

  MapLevel asCurrent() => MapLevel(
        lesson: lesson,
        stage: stage,
        key: key,
        index: index,
        stars: stars,
        unlocked: unlocked,
        current: true,
        x: x,
        y: y,
        px: px,
      );
}

/// 首页：整座岛是现场算出来的 3D 场景（顶点 → 透视 → 光照 → 光栅化）
class IslandMap extends StatefulWidget {
  final ProgressStore store;
  final void Function(MapLevel) onStartLevel;
  final VoidCallback onPetHouseTap;
  final double bottomInset;

  const IslandMap({
    super.key,
    required this.store,
    required this.onStartLevel,
    required this.onPetHouseTap,
    this.bottomInset = 16,
  });

  @override
  State<IslandMap> createState() => _IslandMapState();
}

class _IslandMapState extends State<IslandMap>
    with SingleTickerProviderStateMixin {
  /// 相机站在路上哪儿（世界单位）
  double _cam = 0;
  double _roadLength = 200;
  bool _inited = false;
  static const double _dragScale = 0.022;

  late final AnimationController _fling =
      AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    _fling.addListener(_onFlingTick);
  }

  void _onFlingTick() {
    final v = _fling.value;
    if (v < _minCam || v > _maxCam) {
      _fling.stop();
      setState(() => _cam = v.clamp(_minCam, _maxCam));
      return;
    }
    setState(() => _cam = v);
  }

  double get _minCam => -6.0;
  double get _maxCam => _roadLength + 3.0;

  @override
  void dispose() {
    _fling.dispose();
    super.dispose();
  }

  /// 手指往下扒拉 = 往前走
  void _onDragUpdate(DragUpdateDetails d) {
    _fling.stop();
    setState(
        () => _cam = (_cam + d.delta.dy * _dragScale).clamp(_minCam, _maxCam));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy * _dragScale;
    if (v.abs() < 1.0) return;
    _fling.value = _cam;
    _fling.animateWith(ClampingScrollSimulation(
      position: _cam,
      velocity: v,
      tolerance: const Tolerance(velocity: 0.4, distance: 0.05),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final foodKind = foodKindOf(widget.store.companion?.speciesId);
      final scene = IslandScene.build(
        size: size,
        units: units,
        store: widget.store,
        foodKind: foodKind,
        cam: _inited ? _cam : null,
      );
      if (!_inited) {
        _inited = true;
        _cam = scene.cam;
      }
      _roadLength = scene.roadLength;

      final markers = [...scene.markers]
        ..sort((a, b) => b.y.compareTo(a.y));
      final signs = [...scene.signs]..sort((a, b) => a.depth.compareTo(b.depth));
      final houses = [...scene.houses]
        ..sort((a, b) => a.depth.compareTo(b.depth));

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ScenePainter(scene: scene),
                size: size,
              ),
            ),
          ),
          for (final s in signs) _signPost(s),
          for (final h in houses) _petHouse(h),
          for (final m in markers) _levelHit(m),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: (_) => _fling.stop(),
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
            ),
          ),
          Positioned(
            right: 14,
            bottom: widget.bottomInset,
            child: _locateButton(scene),
          ),
        ],
      );
    });
  }

  Widget _levelHit(SceneMarker m) {
    final s = (m.px * 1.35).clamp(30.0, 170.0);
    final level = MapLevel(
      lesson: m.lesson,
      stage: m.stage,
      key: m.key,
      index: m.index,
      stars: m.stars,
      unlocked: m.unlocked,
      current: m.current,
      x: m.x,
      y: m.y,
      px: m.px,
    );
    return Positioned(
      key: ValueKey('lvl-' + m.index.toString()),
      left: m.x - s / 2,
      top: m.y - s * 0.95,
      width: s,
      height: s,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onStartLevel(level),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _signPost(SceneSign s) {
    final k = (s.px / 250).clamp(0.18, 1.0);
    return Positioned(
      left: s.x - 120,
      top: s.y - 46,
      width: 240,
      height: 64,
      child: IgnorePointer(
        child: Transform.scale(
          scale: k,
          alignment: Alignment.topCenter,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFC08A55), Color(0xFF95602F)],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF6F4520), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.unit.emoji, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.unit.title,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '第 ' +
                              s.firstLevel.toString() +
                              '–' +
                              s.lastLevel.toString() +
                              ' 关 · ' +
                              s.done.toString() +
                              '/' +
                              s.total.toString(),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _petHouse(SceneHouse h) {
    final sp = petSpeciesOf(h.speciesId);
    final avatarSize = (h.px * 0.55).clamp(12.0, 56.0);
    return Positioned(
      left: h.x - avatarSize / 2,
      top: h.y - h.px * 0.74,
      width: avatarSize,
      height: avatarSize,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: h.next
                  ? const Color(0xFFFFE08A)
                  : (h.owned ? const Color(0xFFFFC857) : Colors.white),
              width: h.next ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: FittedBox(
              child: SizedBox(
                width: 100,
                height: 100,
                child: PetAvatar(species: sp, stage: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _locateButton(IslandScene scene) {
    return GestureDetector(
      onTap: () {
        final want = scene.cam.clamp(_minCam, _maxCam);
        _fling.stop();
        _fling.value = _cam;
        _fling.animateTo(want, duration: const Duration(milliseconds: 420));
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text('🎯', style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 3D 画布：天空 + 整座岛的面 + 关卡数字
// ─────────────────────────────────────────────────────────────

class _ScenePainter extends CustomPainter {
  final IslandScene scene;

  const _ScenePainter({required this.scene});

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);

    final renderer = Renderer3D(
      camera: scene.camera,
      fog: const Color(0xFFE8F6FF),
      fogNear: 20,
      fogFar: 34,
    );
    renderer.render(canvas, scene.faces);

    // 地平线附近一层薄雾
    final horizon = scene.horizonY;
    final fogRect = Rect.fromLTWH(0, horizon - 26, size.width, 84);
    canvas.drawRect(
      fogRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99EAF7FF), Color(0x00EAF7FF)],
        ).createShader(fogRect),
    );

    for (final m in scene.markers) {
      _paintNumber(canvas, m);
    }
  }

  void _paintSky(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6FC6F2),
            Color(0xFFA8DFF6),
            Color(0xFFDFF4FD),
          ],
          stops: [0.0, 0.22, 0.42],
        ).createShader(sky),
    );

    final sun = Offset(size.width * 0.80, size.height * 0.10);
    canvas.drawCircle(
      sun,
      46,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF4C4).withValues(alpha: 0.95),
            const Color(0xFFFFF4C4).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 46)),
    );
    canvas.drawCircle(sun, 22, Paint()..color = const Color(0xFFFFF7D6));

    final rnd = Random(5);
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.92);
    for (var i = 0; i < 6; i++) {
      final cx = rnd.nextDouble() * size.width;
      final cy = scene.horizonY - 40 - rnd.nextDouble() * 150;
      final rw = 60 + rnd.nextDouble() * 90;
      for (var j = 0; j < 4; j++) {
        final ox = (j - 1.5) * rw * 0.36;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + ox, cy - (j.isEven ? rw * 0.10 : 0)),
            width: rw * (j.isEven ? 0.62 : 0.5),
            height: rw * 0.34,
          ),
          cloud,
        );
      }
    }
  }

  /// 关卡数字：白色小牌 + 星星
  void _paintNumber(Canvas canvas, SceneMarker m) {
    final k = (m.px / 42).clamp(0.42, 1.5);
    final badgeY = m.y + m.px * 0.22;
    final r = 12.0 * k;
    final center = Offset(m.x, badgeY);

    final ringColor = m.current
        ? const Color(0xFFFF8A3D)
        : (m.done
            ? const Color(0xFF62C246)
            : (m.locked ? const Color(0xFF9AA1AA) : Colors.white));

    if (m.current) {
      canvas.drawCircle(
        center,
        r * 1.9,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFC46B).withValues(alpha: 0.55),
              const Color(0xFFFFC46B).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r * 1.9)),
      );
    }

    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * k
        ..color = ringColor,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: (m.index + 1).toString(),
        style: TextStyle(
          fontSize: 13 * k,
          height: 1.0,
          fontWeight: FontWeight.w800,
          color: m.locked ? const Color(0xFF7C848D) : const Color(0xFF3C4854),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    if (m.stars > 0) {
      for (var i = 0; i < m.stars; i++) {
        final sx = m.x + (i - (m.stars - 1) / 2) * 9 * k;
        final sy = badgeY + r + 7 * k;
        canvas.drawCircle(
          Offset(sx, sy),
          2.6 * k,
          Paint()..color = const Color(0xFFFFC83D),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.scene.cam != scene.cam ||
      old.scene.faces.length != scene.faces.length ||
      old.scene.markers.length != scene.markers.length;
}