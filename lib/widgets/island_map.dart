import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../content/curriculum.dart';
import '../models.dart';
import '../pets.dart';
import '../render3d/render3d.dart' as r3;
import '../store.dart';
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

/// 贴在 3D 位置上的一个数字牌
class _Badge {
  final int index;
  final Offset at;
  final double ppu;
  final int stars;
  final bool locked;
  final bool current;
  final bool done;
  const _Badge(this.index, this.at, this.ppu, this.stars, this.locked,
      this.current, this.done);

  _Badge shift(Offset d) =>
      _Badge(index, at + d, ppu, stars, locked, current, done);
}

/// 投影到屏幕上的一个关卡
class _MarkerVM {
  final SceneMarker src;
  final Offset at;
  final double ppu;
  final double depth;
  const _MarkerVM(this.src, this.at, this.ppu, this.depth);
}

/// 首页：整座岛交给 lib/render3d 的软件光栅器画
/// （顶点 → 模型/视图/投影矩阵 → 透视除法 → 三角形光栅化 → 逐像素 Z-buffer + 光照）
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

  // 光栅化出来的图
  ui.Image? _image;
  bool _rendering = false;
  bool _pending = false;
  bool _dragging = false;
  double _drawnCam = double.nan;
  Size _drawnSize = Size.zero;
  SceneMarker? _drawnFor;
  Timer? _hiTimer;

  // 分辨率：故意渲染得比屏幕大（超采样），交给 RawImage 缩回屏幕大小，
  // 缩放时的双线性过滤顺便把三角形边缘磨平——这一步对"像不像渲染图"影响很大。
  static const double _fastScale = 0.78;
  static const double _hiScale = 1.6;

  static const Color _fog = Color(0xFFE3F4FE);

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
    setState(() {
      _cam = v;
      _dragging = true;
    });
    _scheduleHiQuality();
  }

  double get _minCam => -6.0;
  double get _maxCam => _roadLength + 3.0;

  @override
  void dispose() {
    _hiTimer?.cancel();
    _image?.dispose();
    _fling.dispose();
    super.dispose();
  }

  /// 手指往下扒拉 = 往前走
  void _onDragUpdate(DragUpdateDetails d) {
    _fling.stop();
    _hiTimer?.cancel();
    setState(() {
      _cam = (_cam + d.delta.dy * _dragScale).clamp(_minCam, _maxCam);
      _dragging = true;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy * _dragScale;
    _scheduleHiQuality();
    if (v.abs() < 1.0) return;
    _fling.value = _cam;
    _fling.animateWith(ClampingScrollSimulation(
      position: _cam,
      velocity: v,
      tolerance: const Tolerance(velocity: 0.4, distance: 0.05),
    ));
  }

  /// 停下来 260ms 后重画一张高清的
  void _scheduleHiQuality() {
    _hiTimer?.cancel();
    _hiTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _dragging = false);
    });
  }

  // ── 相机：位置 / 朝向 / 视场角，改它就是换视角 ──
  r3.Camera3D _camera() {
    final eyeX = IslandScene.roadX(_cam);
    final eyeY = IslandScene.roadY(_cam) + 1.62;
    final aheadS = _cam + 6.0;
    final targetX = IslandScene.roadX(aheadS);
    final targetY = IslandScene.roadY(aheadS) + 0.60;
    return r3.Camera3D(
      position: r3.V3(eyeX, eyeY, _cam),
      target: r3.V3(targetX, targetY, aheadS),
      fovY: 0.98,
    );
  }

  // ── 把 island_scene 生成的面转成三角形（光栅器只吃三角形）──
  List<r3.Tri3D> _toTriangles(IslandScene scene) {
    final tris = <r3.Tri3D>[];
    for (final f in scene.faces) {
      if (f.color.a < 0.99) continue; // 半透明的不参与（光栅器不做混合）
      final pts = f.pts;
      if (pts.length < 3) continue;
      final n = f.normal;
      final nv = r3.V3(n.x, n.y, n.z);
      for (var i = 1; i + 1 < pts.length; i++) {
        final a = pts[0], b = pts[i], c = pts[i + 1];
        tris.add(r3.Tri3D(
          r3.V3(a.x, a.y, a.z),
          r3.V3(b.x, b.y, b.z),
          r3.V3(c.x, c.y, c.z),
          nv,
          nv,
          nv,
          f.color,
        ));
      }
    }
    return tris;
  }

  Future<void> _render(IslandScene scene, Size size, {required bool hiQ}) async {
    if (_rendering) {
      _pending = true;
      return;
    }
    _rendering = true;
    final scale = hiQ ? _hiScale : _fastScale;
    final w = (size.width * scale).round().clamp(120, 900);
    final h = (size.height * scale).round().clamp(160, 1500);

    final raster = r3.Rasterizer3D(
      width: w,
      height: h,
      lightDir: const r3.V3(-0.45, 0.78, -0.42), // 太阳在左上偏前
      lightColor: const Color(0xFFFFF3DA),
      ambient: 0.30,
      sunIntensity: 0.78,
      skyTint: const Color(0xFFB6DBF5),
      skyStrength: 0.22,
      groundTint: const Color(0xFFE7B67A),
      groundStrength: 0.12,
      aoStrength: 0.55,
      shadowStrength: 0.74,
      noiseStrength: 0.14,
      specStrength: 0.16,
      fogColor: _fog,
      fogNear: 20,
      fogFar: 42,
      casters: [
        for (final c in scene.casters)
          r3.ShadowCaster(r3.V3(c.at.x, c.at.y, c.at.z), c.r, height: c.h),
      ],
    );
    // 背景留空（alpha 0），天空由下面的画布画，3D 只画岛
    raster.clear(const Color(0x00000000));
    raster.renderScene(
      [r3.MeshInstance(r3.Mesh(_toTriangles(scene)), r3.M4.identity())],
      _camera(),
    );

    final img = await raster.toImage();
    if (!mounted) {
      _rendering = false;
      return;
    }
    setState(() {
      _image?.dispose();
      _image = img;
      _drawnCam = _cam;
      _drawnSize = size;
      _drawnFor = scene.markers.isEmpty ? null : scene.markers.first;
      _rendering = false;
    });
    if (_pending) {
      _pending = false;
      /* 下一帧再画 */
    }
  }


  @override
  Widget build(BuildContext context) {
    return _buildCpu(context);
  }

  // ═══════════ CPU 路径：软件光栅器（着色器不可用时的降级） ═══════════

  Widget _buildCpu(BuildContext context) {
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

      final cam = _camera();
      final aspect = size.width / size.height;

      // 把世界坐标投影到屏幕（数字牌 / 木牌 / 宠物房都贴在 3D 位置上）
      final markers = <_MarkerVM>[];
      for (final m in scene.markers) {
        final p = cam.projectPoint(
            r3.V3(m.world.x, m.world.y, m.world.z), aspect, size);
        if (p == null) continue;
        markers.add(_MarkerVM(m, p.at, p.pixelsPerUnit, p.depth));
      }
      markers.sort((a, b) => b.at.dy.compareTo(a.at.dy));

      final horizon = _horizonY(cam, aspect, size);

      // 需要重画吗
      final needRender = _image == null ||
          _drawnCam != _cam ||
          _drawnSize != size ||
          (_drawnFor == null && scene.markers.isNotEmpty);
      if (needRender && !_rendering) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _render(scene, size, hiQ: !_dragging);
        });
      }

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 天空（渐变 + 太阳 + 云）在最底下，3D 图的背景是透明的
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _SkyPainter(horizon: horizon)),
            ),
          ),
          // 真 3D 的岛：软件光栅器逐像素画出来的
          Positioned.fill(
            child: _image == null
                ? const SizedBox.expand()
                : RawImage(
                    image: _image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.low,
                  ),
          ),
          // 数字牌（贴在 3D 位置上，但文字始终正对镜头）
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _BadgePainter([
                  for (final m in markers)
                    _Badge(
                      m.src.index,
                      Offset(m.at.dx, m.at.dy + m.ppu * 0.20),
                      m.ppu * 2.4,
                      m.src.stars,
                      m.src.locked,
                      m.src.current,
                      m.src.done,
                    ),
                ]),
              ),
            ),
          ),
          for (final h in scene.houses)
            _petHouse(h, cam, aspect, size),
          for (final s in scene.signs) _signPost(s, cam, aspect, size),
          // 关卡的点击热区（给测试和手指定位）
          for (final m in markers)
            Positioned(
              key: ValueKey('lvl-' + m.src.index.toString()),
              left: m.at.dx - (m.ppu * 0.8).clamp(24.0, 120.0) / 2,
              top: m.at.dy - (m.ppu * 0.8).clamp(24.0, 120.0) * 0.9,
              width: (m.ppu * 0.8).clamp(24.0, 120.0),
              height: (m.ppu * 0.8).clamp(24.0, 120.0),
              child: const IgnorePointer(child: SizedBox.expand()),
            ),
          // 拖动 / 点击
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) => _handleTap(d.localPosition, markers),
              onVerticalDragStart: (_) {
                _fling.stop();
                _hiTimer?.cancel();
                setState(() => _dragging = true);
              },
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

  double _horizonY(r3.Camera3D cam, double aspect, Size size) {
    final eye = cam.position;
    final p = cam.projectPoint(r3.V3(eye.x, eye.y, eye.z + 400), aspect, size);
    return p?.at.dy ?? size.height * 0.35;
  }

  void _handleTap(Offset pos, List<_MarkerVM> markers) {
    _MarkerVM? best;
    var bestD = double.infinity;
    for (final m in markers) {
      final d = (m.at - pos).distance;
      final reach = (m.ppu * 1.1).clamp(30.0, 110.0);
      if (d < reach && d < bestD) {
        bestD = d;
        best = m;
      }
    }
    if (best != null) {
      final m = best.src;
      widget.onStartLevel(MapLevel(
        lesson: m.lesson,
        stage: m.stage,
        key: m.key,
        index: m.index,
        stars: m.stars,
        unlocked: m.unlocked,
        current: m.current,
        x: best.at.dx,
        y: best.at.dy,
        px: best.ppu,
      ));
    }
  }

  Widget _signPost(SceneSign s, r3.Camera3D cam, double aspect, Size size) {
    final p = cam.projectPoint(
        r3.V3(IslandScene.roadX(s.world) - 1.5, IslandScene.roadY(s.world) + 0.55,
            s.world),
        aspect,
        size);
    if (p == null) return const SizedBox.shrink();
    final k = (p.pixelsPerUnit / 260).clamp(0.16, 1.0);
    return Positioned(
      left: p.at.dx - 120,
      top: p.at.dy - 46,
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
                color: const Color(0xFFA9713E),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF6F4520), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
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
                          style:
                              const TextStyle(fontSize: 10, color: Colors.white70),
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

  Widget _petHouse(SceneHouse h, r3.Camera3D cam, double aspect, Size size) {
    final sp = petSpeciesOf(h.speciesId);
    final p = cam.projectPoint(
        r3.V3(h.world.x, h.world.y + 0.62, h.world.z), aspect, size);
    if (p == null) return const SizedBox.shrink();
    final avatarSize = (p.pixelsPerUnit * 0.34).clamp(10.0, 52.0);
    return Positioned(
      left: p.at.dx - avatarSize / 2,
      top: p.at.dy - avatarSize / 2,
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
// 天空：渐变 + 太阳 + 云（在 3D 图下面，3D 图背景透明）
// ─────────────────────────────────────────────────────────────

class _SkyPainter extends CustomPainter {
  final double horizon;
  const _SkyPainter({required this.horizon});

  @override
  void paint(Canvas canvas, Size size) {
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
            Color(0xFFE6F6FE),
          ],
          stops: [0.0, 0.28, 0.62],
        ).createShader(sky),
    );

    final sun = Offset(size.width * 0.80, size.height * 0.09);
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
    canvas.drawCircle(sun, 20, Paint()..color = const Color(0xFFFFF7D6));

    final rnd = Random(5);
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.94);
    final top = horizon.clamp(60.0, size.height);
    for (var i = 0; i < 6; i++) {
      final cx = rnd.nextDouble() * size.width;
      final cy = 40 + rnd.nextDouble() * max(20.0, top - 90);
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

  @override
  bool shouldRepaint(_SkyPainter old) => old.horizon != horizon;
}

// ─────────────────────────────────────────────────────────────
// 数字牌：白底圆片 + 星星，位置跟着 3D 投影走
// ─────────────────────────────────────────────────────────────

class _BadgePainter extends CustomPainter {
  final List<_Badge> markers;
  const _BadgePainter(this.markers);

  @override
  void paint(Canvas canvas, Size size) {
    for (final vm in markers) {
      _paintBadge(canvas, vm);
    }
  }

  void _paintBadge(Canvas canvas, _Badge vm) {
    final m = vm;
    final k = (vm.ppu / 130).clamp(0.45, 1.6);
    final center = Offset(vm.at.dx, vm.at.dy);
    final r = 12.0 * k;

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

    canvas.drawCircle(center, r, Paint()..color = Colors.white.withValues(alpha: 0.96));
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
        final sx = vm.at.dx + (i - (m.stars - 1) / 2) * 10 * k;
        final sy = center.dy + r + 8 * k;
        canvas.drawCircle(
          Offset(sx, sy),
          2.6 * k,
          Paint()..color = const Color(0xFFFFC83D),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.markers.length != markers.length ||
      (markers.isNotEmpty &&
          old.markers.isNotEmpty &&
          old.markers.first.at != markers.first.at);
}