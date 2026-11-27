import 'dart:math';
import 'package:flutter/material.dart';
import '../content/curriculum.dart';
import '../models.dart';
import '../store.dart';

const List<String> kStageNames = ['基础', '提高', '挑战'];

/// 底图：AI 渲染的黏土岛（当前是带水印的占位图，换成无水印同构图的即可）
const String kIslandArt = 'assets/map_island.png';
const Size kIslandArtSize = Size(1080, 1080);

/// 关卡在底图上的位置（归一化坐标，从山脚一路到山顶）
const List<Offset> kLevelSpots = [
  Offset(0.463, 0.769), // 石阶口
  Offset(0.574, 0.639), // 木桥头
  Offset(0.672, 0.576), // 绿色台
  Offset(0.669, 0.456), // 粉紫台
  Offset(0.546, 0.428), // 青色台
  Offset(0.341, 0.435), // 蓝色台
  Offset(0.437, 0.298), // 黄色台
  Offset(0.318, 0.372), // 左下小台
  Offset(0.531, 0.245), // 高处绿台
  Offset(0.614, 0.199), // 灯塔前粉台
];

/// 一关 = 一个课时的一个阶段（基础 / 提高 / 挑战）
class MapLevel {
  final Lesson lesson;
  final int stage;
  final String key;
  final int index;
  final int stars;
  final bool unlocked;
  final bool current;

  /// 屏幕上的位置与直径（像素）
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

/// 底图用 BoxFit.cover 铺满时，图片实际占的矩形
Rect coverRect(Size box, Size image) {
  final scale = max(box.width / image.width, box.height / image.height);
  return Rect.fromCenter(
    center: Offset(box.width / 2, box.height / 2),
    width: image.width * scale,
    height: image.height * scale,
  );
}

/// 首页地图：黏土岛底图 + 代码实时驱动的关卡圆盘
///
/// 底图是离线渲染好的插画（所以有那种柔和的黏土质感）；
/// 关卡、数字、星星、上锁、当前关呼吸光、点击热区全部由代码实时画，
/// 进度一变画面就跟着变。
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
  /// 当前翻到第几页（每页 10 关），-1 = 还没定位过
  int _page = -1;

  void _goPage(int p, int pageCount) {
    final next = p.clamp(0, pageCount - 1);
    if (next != _page) setState(() => _page = next);
  }

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// 所有关卡按顺序（与题库顺序一致）
  List<MapLevel> _orderedLevels() {
    final out = <MapLevel>[];
    var idx = 0;
    int? curIdx;
    for (final u in units) {
      for (final l in u.lessons) {
        for (var st = 0; st < 3; st++) {
          final stars = widget.store.stageStars(l.id, st);
          final unlocked = widget.store.levelUnlocked(orderedLevelKeys, idx);
          if (curIdx == null && unlocked && stars == 0) curIdx = idx;
          out.add(MapLevel(
            lesson: l,
            stage: st,
            key: l.id + ':s' + st.toString(),
            index: idx,
            stars: stars,
            unlocked: unlocked,
            current: false,
          ));
          idx++;
        }
      }
    }
    if (curIdx != null) out[curIdx] = out[curIdx].asCurrent();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final art = coverRect(size, kIslandArtSize);

      final all = _orderedLevels();
      final count = all.length;
      var curIdx = all.indexWhere((l) => l.current);
      if (curIdx < 0) curIdx = 0;

      // 每 10 关一页（正好对上岛上 10 块台子）
      final perPage = kLevelSpots.length;
      final pageCount = max(1, (count + perPage - 1) ~/ perPage);
      final curPage = (curIdx ~/ perPage).clamp(0, pageCount - 1).toInt();
      if (_page < 0) _page = curPage;
      _page = _page.clamp(0, pageCount - 1).toInt();
      final start = (_page * perPage).clamp(0, max(0, count - 1)).toInt();
      final shown = all.sublist(start, min(start + perPage, count));

      final radius = max(15.0, art.width * 0.038);

      final spots = <_Spot>[];
      for (var i = 0; i < shown.length; i++) {
        final spot = kLevelSpots[i];
        spots.add(_Spot(
          level: shown[i],
          at: Offset(
            art.left + spot.dx * art.width,
            art.top + spot.dy * art.height,
          ),
          r: radius,
        ));
      }

      // 当前单元 / 进度条
      final curLevel = all[curIdx];
      final unit = unitOfLesson(curLevel.lesson.id);
      final unitLevels =
          all.where((l) => unit?.lessons.any((x) => x.id == l.lesson.id) ?? false);
      final unitDone = unitLevels.where((l) => l.stars > 0).length;

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Image.asset(
              kIslandArt,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const _FallbackBackground(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _SpotPainter(spots, _pulse.value),
                ),
              ),
            ),
          ),
          for (final s in spots)
            Positioned(
              key: ValueKey('lvl-' + s.level.index.toString()),
              left: s.at.dx - s.r,
              top: s.at.dy - s.r,
              width: s.r * 2,
              height: s.r * 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onStartLevel(_levelOf(s)),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -120) {
                  _goPage(_page + 1, pageCount);
                } else if (v > 120) {
                  _goPage(_page - 1, pageCount);
                }
              },
              onTapUp: (d) {
                _Spot? best;
                var bestD = 1e9;
                for (final s in spots) {
                  final dd = (s.at - d.localPosition).distance;
                  if (dd < s.r * 1.9 && dd < bestD) {
                    bestD = dd;
                    best = s;
                  }
                }
                if (best != null) widget.onStartLevel(_levelOf(best));
              },
            ),
          ),
          // 顶部：当前单元 + 本单元进度
          Positioned(
            left: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.90),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(unit?.emoji ?? '🏝', style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    unit?.title ?? '闯关岛',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4C423A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$unitDone/${unitLevels.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9A8F86),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 右上：翻页（每页 10 关，共 78 关）
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.90),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pageButton(
                    key: const ValueKey('page-prev'),
                    text: '◀',
                    enabled: _page > 0,
                    onTap: () => _goPage(_page - 1, pageCount),
                  ),
                  Text(
                    '${start + 1}-${start + shown.length} / $count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4C423A),
                    ),
                  ),
                  _pageButton(
                    key: const ValueKey('page-next'),
                    text: '▶',
                    enabled: _page < pageCount - 1,
                    onTap: () => _goPage(_page + 1, pageCount),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _pageButton({
    required Key key,
    required String text,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? const Color(0xFFFFB347)
              : const Color(0xFFE1E4E8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: enabled ? Colors.white : const Color(0xFFAAB0B6),
            ),
          ),
        ),
      ),
    );
  }

  MapLevel _levelOf(_Spot s) => MapLevel(
        lesson: s.level.lesson,
        stage: s.level.stage,
        key: s.level.key,
        index: s.level.index,
        stars: s.level.stars,
        unlocked: s.level.unlocked,
        current: s.level.current,
        x: s.at.dx,
        y: s.at.dy,
        px: s.r * 2,
      );
}

class _Spot {
  final MapLevel level;
  final Offset at;
  final double r;
  const _Spot({required this.level, required this.at, required this.r});
}

/// 画圆盘：锁=灰、已过=绿、当前=橙 + 呼吸光
class _SpotPainter extends CustomPainter {
  final List<_Spot> spots;
  final double pulse;
  const _SpotPainter(this.spots, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in spots) {
      final l = s.level;
      final done = l.stars > 0;
      final locked = !l.unlocked;

      final base = locked
          ? const Color(0xFFB9BEC6)
          : (done ? const Color(0xFF74CE5F) : const Color(0xFFFFB13D));

      if (l.current) {
        final k = 0.88 + 0.12 * pulse;
        canvas.drawCircle(
          s.at,
          s.r * 2.15 * k,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFD08A).withValues(alpha: 0.60),
                const Color(0xFFFFD08A).withValues(alpha: 0.0),
              ],
            ).createShader(
                Rect.fromCircle(center: s.at, radius: s.r * 2.15 * k)),
        );
      }

      // 投影
      canvas.drawCircle(
        s.at.translate(0, s.r * 0.12),
        s.r * 1.05,
        Paint()..color = Colors.black.withValues(alpha: 0.14),
      );

      // 圆盘：柔和径向渐变 + 白边，做出黏土玩具的厚度
      canvas.drawCircle(
        s.at,
        s.r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.28, -0.42),
            colors: [
              Color.lerp(base, Colors.white, 0.38)!,
              base,
              Color.lerp(base, Colors.black, 0.16)!,
            ],
            stops: const [0.0, 0.60, 1.0],
          ).createShader(Rect.fromCircle(center: s.at, radius: s.r)),
      );
      canvas.drawCircle(
        s.at,
        s.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.r * 0.11
          ..color = Colors.white.withValues(alpha: 0.9),
      );

      // 关号
      final tp = TextPainter(
        text: TextSpan(
          text: (l.index + 1).toString(),
          style: TextStyle(
            fontSize: s.r * 1.02,
            height: 1.0,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: s.r * 0.16,
                offset: Offset(0, s.r * 0.08),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, s.at - Offset(tp.width / 2, tp.height / 2));

      // 锁
      if (locked) {
        final c = s.at.translate(0, s.r * 0.78);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c, width: s.r * 0.52, height: s.r * 0.42),
            Radius.circular(s.r * 0.10),
          ),
          Paint()..color = const Color(0xFF6E767F),
        );
        canvas.drawArc(
          Rect.fromCenter(
              center: c.translate(0, -s.r * 0.20),
              width: s.r * 0.34,
              height: s.r * 0.40),
          pi,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.r * 0.09
            ..color = const Color(0xFF6E767F),
        );
      }

      // 星星
      for (var i = 0; i < l.stars; i++) {
        final sx = s.at.dx + (i - (l.stars - 1) / 2) * s.r * 0.55;
        _star(canvas, Offset(sx, s.at.dy + s.r * 1.32), s.r * 0.22);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.46;
      final pt = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFC83D));
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.24
        ..color = const Color(0xFFE8A21C),
    );
  }

  @override
  bool shouldRepaint(_SpotPainter old) =>
      old.pulse != pulse ||
      old.spots.length != spots.length ||
      (spots.isNotEmpty &&
          old.spots.isNotEmpty &&
          old.spots.first.level.index != spots.first.level.index);
}

/// 底图缺失时的兜底
class _FallbackBackground extends StatelessWidget {
  const _FallbackBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8FD3F4), Color(0xFFC8ECFA), Color(0xFF9FE3D2)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}