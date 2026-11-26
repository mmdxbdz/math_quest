import 'dart:math';
import 'package:flutter/material.dart';
import '../content/curriculum.dart';
import '../models.dart';
import '../pets.dart';
import '../store.dart';
import 'bars.dart';

const List<String> kStageNames = ['基础', '提高', '挑战'];

// ─────────────────────────────────────────────────────────────
// 数据：地图上的一关 / 木牌 / 装饰
// ─────────────────────────────────────────────────────────────

/// 一关 = 一个课时的一个阶段（基础 / 提高 / 挑战）
class MapLevel {
  final Lesson lesson;
  final int stage;
  final String key;
  final int index; // 0 起，全局顺序
  final double x;
  final double y;
  final int stars;
  final bool unlocked;
  final bool current;

  const MapLevel({
    required this.lesson,
    required this.stage,
    required this.key,
    required this.index,
    required this.x,
    required this.y,
    required this.stars,
    required this.unlocked,
    required this.current,
  });

  MapLevel asCurrent() => MapLevel(
        lesson: lesson,
        stage: stage,
        key: key,
        index: index,
        x: x,
        y: y,
        stars: stars,
        unlocked: unlocked,
        current: true,
      );
}

/// 每个主题一块木牌，写着主题名和进度
class MapSign {
  final Unit unit;
  final double x;
  final double y;
  final int done;
  final int total;
  final int firstLevel;
  final int lastLevel;

  const MapSign({
    required this.unit,
    required this.x,
    required this.y,
    required this.done,
    required this.total,
    required this.firstLevel,
    required this.lastLevel,
  });
}

/// 岛上的立体小物件：0 树 / 1 房子 / 2 灌木 / 3 石头
class MapDeco {
  final int kind;
  final double x;
  final double y;
  final double size;

  const MapDeco({
    required this.kind,
    required this.x,
    required this.y,
    required this.size,
  });
}

/// 岛上的宠物房：开在"刚好看满 N 关"的那一关和下一关之间，
/// 门框上挂着住在这间房里的宠物头像。
class MapPetHouse {
  final String speciesId;
  final double x;
  final double y;

  /// 这是第几只（1 起，和关卡数对应：第 6 关后第一间）
  final int order;
  final bool owned;

  /// 下一间就要住进来的（门上挂个金圈提示她）
  final bool next;

  const MapPetHouse({
    required this.speciesId,
    required this.x,
    required this.y,
    required this.order,
    required this.owned,
    this.next = false,
  });
}

// ─────────────────────────────────────────────────────────────
// 布局：路线从岛的最下方往上延伸，第 1 关在最下面，越往后越往上
// ─────────────────────────────────────────────────────────────

class MapLayout {
  final double width;
  final double height;
  final List<MapLevel> levels;
  final List<MapSign> signs;
  final List<MapDeco> decos;
  final List<MapPetHouse> houses;
  final List<Offset> trail; // 按世界 y 从小到大（= 从岛顶到岛底）
  final int currentIndex;
  final double currentY;

  const MapLayout({
    required this.width,
    required this.height,
    required this.levels,
    required this.signs,
    required this.decos,
    required this.houses,
    required this.trail,
    required this.currentIndex,
    required this.currentY,
  });

  /// 小路上某个高度处的中线 x
  double trailXAt(double y) {
    if (trail.isEmpty) return width / 2;
    if (y <= trail.first.dy) return trail.first.dx;
    if (y >= trail.last.dy) return trail.last.dx;
    var lo = 0;
    var hi = trail.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (trail[mid].dy <= y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = trail[lo];
    final b = trail[hi];
    final t = (y - a.dy) / (b.dy - a.dy == 0 ? 1 : b.dy - a.dy);
    return a.dx + (b.dx - a.dx) * t;
  }

  factory MapLayout.build(Size size, List<Unit> units, ProgressStore store) {
    const nodeGap = 120.0; // 台阶间距
    const signGap = 84.0; // 木牌与第一关的间距
    const unitGap = 36.0; // 主题之间的留白
    const houseGap = 132.0; // 宠物房占的那一段路
    const topPad = 180.0;

    final w = size.width;
    final cx = w / 2;
    final amp = min(w * 0.115, 46.0);

    // 整座岛上一共几间宠物房（开场送的那只不算）
    var levelTotal = 0;
    for (final u in units) {
      levelTotal += u.lessons.length * 3;
    }
    final houseCount = min(
      kPetSpecies.length - 1,
      levelTotal ~/ kPetUnlockEveryLevels,
    );
    final ownedSpecies =
        store.pets.map((p) => p.speciesId).toSet();

    // 先把整座岛算多高：路线是从下往上爬的
    var total = topPad;
    total += houseCount * houseGap;
    for (final u in units) {
      total += signGap + u.lessons.length * 3 * nodeGap + unitGap;
    }
    final height = total + 140;

    /// 世界 y：越小 = 屏幕越靠上。
    /// 第 1 关在岛的最下面（y 最大），越往后越往上爬（y 越小）。
    double worldY(double dist) => height - dist;

    var dist = topPad; // 从最下面的第 1 关往上量
    var idx = 0;
    var houseIdx = 0;
    final levels = <MapLevel>[];
    final signs = <MapSign>[];
    final houses = <MapPetHouse>[];
    final trailTopDown = <Offset>[];

    for (final unit in units) {
      final firstLevel = idx + 1;
      final signDist = dist;
      dist += signGap;

      var unitDone = 0;
      for (final lesson in unit.lessons) {
        for (var stage = 0; stage < 3; stage++) {
          final x = cx + amp * sin(idx * 0.42);
          final y = worldY(dist);
          final stars = store.stageStars(lesson.id, stage);
          levels.add(MapLevel(
            lesson: lesson,
            stage: stage,
            key: '${lesson.id}:s$stage',
            index: idx,
            x: x,
            y: y,
            stars: stars,
            unlocked: store.levelUnlocked(orderedLevelKeys, idx),
            current: false,
          ));
          trailTopDown.add(Offset(x, y));
          if (stars > 0) unitDone++;
          idx++;
          dist += nodeGap;
          // 每满 6 关：在刚过的这一关和下一关中间开一间宠物房
          if (idx % kPetUnlockEveryLevels == 0 && houseIdx < houseCount) {
            final sp = petSpeciesOf(kPetUnlockOrder[houseIdx + 1]);
            final hx = cx + amp * sin((idx - 0.5) * 0.42);
            final hy = worldY(dist + houseGap * 0.42);
            houses.add(MapPetHouse(
              speciesId: sp.id,
              x: hx,
              y: hy,
              order: houseIdx + 1,
              owned: ownedSpecies.contains(sp.id),
            ));
            trailTopDown.add(Offset(hx, hy));
            dist += houseGap;
            houseIdx++;
          }
        }
      }

      final signX = cx + amp * sin((firstLevel - 1) * 0.42);
      signs.add(MapSign(
        unit: unit,
        x: signX,
        y: worldY(signDist),
        done: unitDone,
        total: unit.lessons.length * 3,
        firstLevel: firstLevel,
        lastLevel: idx,
      ));
      trailTopDown.add(Offset(signX, worldY(signDist)));
      dist += unitGap;
    }

    // 当前关：第一个已解锁但还没拿星的关；全通了就停在最后一关
    var currentIdx = levels.indexWhere((l) => l.unlocked && l.stars == 0);
    if (currentIdx < 0) {
      currentIdx = levels.indexWhere((l) => l.unlocked);
      if (currentIdx < 0) currentIdx = 0;
    }
    levels[currentIdx] = levels[currentIdx].asCurrent();

    // 下一间宠物房：还没住人的第一间，门上挂金圈
    final nextHouse =
        houses.indexWhere((h) => !h.owned);
    if (nextHouse >= 0) {
      final h = houses[nextHouse];
      houses[nextHouse] = MapPetHouse(
        speciesId: h.speciesId,
        x: h.x,
        y: h.y,
        order: h.order,
        owned: h.owned,
        next: true,
      );
    }

    // 小路点按世界 y 递增排序（木牌是插在关卡之间的，一起排）
    trailTopDown.sort((a, b) => a.dy.compareTo(b.dy));

    // 装饰：沿小路两侧随机种
    final rnd = Random(11);
    final decos = <MapDeco>[];
    final signCount = signs.length;
    for (var i = 0; i < 64; i++) {
      final y = 90 + rnd.nextDouble() * (height - 180);
      final tx = _trailAt(trailTopDown, w / 2, y);
      final side = rnd.nextBool() ? 1 : -1;
      final off = w * (0.16 + rnd.nextDouble() * 0.09);
      decos.add(MapDeco(
        kind: rnd.nextInt(4),
        x: tx + side * off,
        y: y,
        size: 16 + rnd.nextDouble() * 10,
      ));
    }
    // 岛底和岛顶各放几个大件，避免太空
    if (signCount > 0) {
      decos.add(MapDeco(kind: 1, x: cx - w * 0.2, y: height - 70, size: 26));
      decos.add(MapDeco(kind: 0, x: cx + w * 0.2, y: height - 90, size: 24));
      // 山顶（最后的关卡上方）
      decos.add(MapDeco(kind: 1, x: cx - w * 0.18, y: 84, size: 24));
      decos.add(MapDeco(kind: 0, x: cx + w * 0.2, y: 66, size: 22));
    }

    return MapLayout(
      width: w,
      height: height,
      levels: levels,
      signs: signs,
      decos: decos,
      houses: houses,
      trail: trailTopDown,
      currentIndex: currentIdx,
      currentY: levels[currentIdx].y,
    );
  }

  static double _trailAt(List<Offset> trail, double fallback, double y) {
    if (trail.isEmpty) return fallback;
    if (y <= trail.first.dy) return trail.first.dx;
    if (y >= trail.last.dy) return trail.last.dx;
    var lo = 0;
    var hi = trail.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (trail[mid].dy <= y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = trail[lo];
    final b = trail[hi];
    final t = (y - a.dy) / (b.dy - a.dy == 0 ? 1 : b.dy - a.dy);
    return a.dx + (b.dx - a.dx) * t;
  }
}

// ─────────────────────────────────────────────────────────────
// 组件
// ─────────────────────────────────────────────────────────────

class IslandMap extends StatefulWidget {
  final ProgressStore store;
  final void Function(MapLevel level) onStartLevel;
  final VoidCallback? onPetHouseTap;
  final double bottomInset;

  const IslandMap({
    super.key,
    required this.store,
    required this.onStartLevel,
    this.onPetHouseTap,
    this.bottomInset = 0,
  });

  @override
  State<IslandMap> createState() => _IslandMapState();
}

class _IslandMapState extends State<IslandMap>
    with SingleTickerProviderStateMixin {
  /// 相机：屏幕最上方对应的世界 y。世界 y 越小 = 越高的地方。
  double _cam = 0;
  double _maxCam = 0;
  bool _inited = false;
  late final AnimationController _fling =
      AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    _fling.addListener(_onFlingTick);
  }

  void _onFlingTick() {
    final v = _fling.value;
    if (v < 0 || v > _maxCam) {
      _fling.stop();
      setState(() => _cam = v.clamp(0.0, _maxCam));
      return;
    }
    setState(() => _cam = v);
  }

  @override
  void dispose() {
    _fling.dispose();
    super.dispose();
  }

  /// 画面跟着手指走：手指往下滑，上面的下一关就跟着往下出来
  void _onDragUpdate(DragUpdateDetails d) {
    _fling.stop();
    setState(() => _cam = (_cam - d.delta.dy).clamp(0.0, _maxCam));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = -d.velocity.pixelsPerSecond.dy;
    if (v.abs() < 90) return;
    _fling.value = _cam;
    _fling.animateWith(ClampingScrollSimulation(
      position: _cam,
      velocity: v,
      tolerance: const Tolerance(velocity: 6, distance: 1),
    ));
  }

  void _focusCurrent(MapLayout layout, double viewH) {
    final target = (layout.currentY - viewH * 0.32).clamp(0.0, _maxCam);
    _fling.stop();
    _fling.value = _cam;
    _fling.animateTo(
      target,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final layout = MapLayout.build(size, units, widget.store);
      _maxCam = max(0.0, layout.height - size.height);
      if (!_inited) {
        _inited = true;
        _cam = (layout.currentY - size.height * 0.32).clamp(0.0, _maxCam);
      }
      if (_cam > _maxCam) _cam = _maxCam;

      // 倾斜之后内容顶部会缩进一块，多画一截补上，免得露出接缝
      final extraTop = size.height * 0.55;
      final boxH = size.height + extraTop;
      final cam = _cam - extraTop;

      final mapStack = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WorldPainter(
                  layout: layout,
                  cam: cam,
                  viewH: boxH,
                ),
              ),
            ),
          ),
          // 木牌只有十来个，全部保留（滚出屏幕的部分会被裁掉）
          for (final s in layout.signs) _signPost(s, cam),
          // 宠物房：夹在两关中间，门框上挂着住在这里的宠物
          for (final h in layout.houses)
            if (h.y - cam > -240 && h.y - cam < boxH + 240) _petHouse(h, cam),
          for (final l in layout.levels)
            if (l.y - cam > -220 && l.y - cam < boxH + 220)
              _levelNode(l, cam),
        ],
      );

      return Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _Backdrop())),
          Positioned(
            left: 0,
            right: 0,
            top: -extraTop,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _fling.stop(),
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              // 整个画面做一点透视，越往上越远——立体感主要来自这里
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0011)
                  ..rotateX(-0.26)
                  ..scaleByDouble(1.18, 1.18, 1.18, 1),
                child: mapStack,
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: widget.bottomInset,
            child: _locateButton(layout, size.height),
          ),
        ],
      );
    });
  }

  Widget _locateButton(MapLayout layout, double viewH) {
    return GestureDetector(
      onTap: () => _focusCurrent(layout, viewH),
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

  Widget _signPost(MapSign s, double cam) {
    final sy = s.y - cam;
    return Positioned(
      left: s.x - 120,
      top: sy - 30,
      width: 240,
      height: 60,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFC08A55), Color(0xFF9A6535)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6F4520), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.unit.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
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
    );
  }

  Widget _petHouse(MapPetHouse h, double cam) {
    final sy = h.y - cam;
    final sp = petSpeciesOf(h.speciesId);
    return Positioned(
      left: h.x - 60,
      top: sy - 58,
      width: 120,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPetHouseTap,
        child: _PetHouseNode(species: sp, owned: h.owned, next: h.next),
      ),
    );
  }

  Widget _levelNode(MapLevel l, double cam) {
    final sy = l.y - cam;
    Widget pedestal = _LevelPedestal(level: l);
    if (l.current) {
      pedestal = _Bob(child: pedestal);
    }
    return Positioned(
      left: l.x - 46,
      top: sy - 32,
      width: 92,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onStartLevel(l),
        child: pedestal,
      ),
    );
  }
}

/// 岛上的一间宠物房：屋顶 + 门框 + 门框上挂着的宠物头像
class _PetHouseNode extends StatelessWidget {
  final PetSpecies species;
  final bool owned;
  final bool next;

  const _PetHouseNode({
    required this.species,
    required this.owned,
    this.next = false,
  });

  @override
  Widget build(BuildContext context) {
    final wall = owned
        ? const [Color(0xFFFFF6E4), Color(0xFFF2DCB8)]
        : const [Color(0xFFEDF0F4), Color(0xFFCBD1DA)];
    final roof = owned
        ? const [Color(0xFFE0705A), Color(0xFFB94A38)]
        : const [Color(0xFFB7BFCB), Color(0xFF98A2B0)];
    final frame = owned ? const Color(0xFF9A6535) : const Color(0xFF8B93A0);

    return SizedBox(
      width: 120,
      height: 116,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 房身
          Positioned(
            bottom: 0,
            child: Container(
              width: 96,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: wall,
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6), bottom: Radius.circular(8)),
                border: Border.all(color: frame, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),
          ),
          // 屋顶
          Positioned(
            bottom: 58,
            child: SizedBox(
              width: 110,
              height: 34,
              child: CustomPaint(painter: _RoofPainter(colors: roof, edge: frame)),
            ),
          ),
          // 门（拱形门洞）
          Positioned(
            bottom: 4,
            child: Container(
              width: 52,
              height: 50,
              decoration: BoxDecoration(
                color: owned ? const Color(0xFF8A5A31) : frame,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26), bottom: Radius.circular(3)),
                border: Border.all(color: frame, width: 2),
              ),
            ),
          ),
          // 门框上挂的头像：告诉娃这间房住的是谁
          Positioned(
            bottom: 20,
            child: Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: owned ? Colors.white : const Color(0xFFE4E8EE),
                border: Border.all(
                  color: owned ? const Color(0xFFFFB300) : frame,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Opacity(
                  opacity: owned ? 1 : 0.55,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: PetAvatar(species: species, stage: 0, size: 40),
                  ),
                ),
              ),
            ),
          ),
          // 还没领到：锁
          if (!owned)
            Positioned(
              bottom: 2,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: frame, width: 1),
                ),
                child: Text(next ? '🎁' : '🔒',
                    style: const TextStyle(fontSize: 11)),
              ),
            ),
          // 下一间就要住进来的：门上套一圈金边
          if (next)
            Positioned(
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 96,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6), bottom: Radius.circular(8)),
                    border: Border.all(
                        color: const Color(0xFFFFC107), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC107).withValues(alpha: 0.55),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 屋顶：一个梯形小尖顶
class _RoofPainter extends CustomPainter {
  final List<Color> colors;
  final Color edge;

  const _RoofPainter({required this.colors, required this.edge});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.92)
      ..lineTo(0, size.height * 0.92)
      ..close();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_RoofPainter old) =>
      old.colors != colors || old.edge != edge;
}

/// 立体圆台台阶
class _LevelPedestal extends StatelessWidget {
  final MapLevel level;

  const _LevelPedestal({required this.level});

  @override
  Widget build(BuildContext context) {
    final locked = !level.unlocked;
    final done = level.stars > 0;
    final cur = level.current;

    final List<Color> top;
    final List<Color> side;
    final Color rim;
    final Color num;

    if (locked) {
      top = const [Color(0xFFE7ECF3), Color(0xFFC3CAD6)];
      side = const [Color(0xFFB4BCC9), Color(0xFF9199A7)];
      rim = const Color(0xFFFFFFFF);
      num = const Color(0xFF7E8794);
    } else if (done) {
      top = const [Color(0xFF8CE9BE), Color(0xFF31C08A)];
      side = const [Color(0xFF23A877), Color(0xFF12774F)];
      rim = const Color(0xFFF2FFFA);
      num = Colors.white;
    } else if (cur) {
      top = const [Color(0xFFFFD98A), Color(0xFFFF9A3C)];
      side = const [Color(0xFFE8712A), Color(0xFFB94A16)];
      rim = const Color(0xFFFFF4D8);
      num = Colors.white;
    } else {
      top = const [Color(0xFFA9E2FF), Color(0xFF4FB4EE)];
      side = const [Color(0xFF2F93CD), Color(0xFF1B6C9F)];
      rim = const Color(0xFFEAF8FF);
      num = Colors.white;
    }

    return SizedBox(
      height: 110,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 地面投影
          Positioned(
            bottom: 10,
            left: 16,
            right: 16,
            height: 18,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.16),
                borderRadius:
                    const BorderRadius.all(Radius.elliptical(30, 9)),
              ),
            ),
          ),
          // 柱身（厚度）
          Positioned(
            top: 26,
            left: 8,
            right: 8,
            bottom: 12,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: side,
                ),
                borderRadius:
                    const BorderRadius.all(Radius.elliptical(38, 32)),
              ),
            ),
          ),
          // 顶面
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 62,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: top,
                ),
                borderRadius:
                    const BorderRadius.all(Radius.elliptical(40, 31)),
                border: Border.all(color: rim, width: 2.5),
                boxShadow: cur
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFB35C).withValues(alpha: 0.75),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  level.index + 1 < 100
                      ? (level.index + 1).toString()
                      : '99+',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: num,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (locked)
            const Positioned(
              top: 42,
              child: Text('🔒', style: TextStyle(fontSize: 13)),
            ),
          Positioned(
            bottom: 0,
            child: StarRow(level.stars, size: 13),
          ),
        ],
      ),
    );
  }
}

/// 当前关轻轻上下浮动
class _Bob extends StatefulWidget {
  final Widget child;

  const _Bob({required this.child});

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -5 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 岛的绘制（立体：挤出侧面 + 沙滩 + 草地 + 土路）
// ─────────────────────────────────────────────────────────────

class _WorldPainter extends CustomPainter {
  final MapLayout layout;
  final double cam;
  final double viewH;

  const _WorldPainter({
    required this.layout,
    required this.cam,
    required this.viewH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(0, -cam);

    final w = size.width;
    final top = cam - 260;
    final bottom = cam + viewH + 260;

    // 海水下的影子
    canvas.save();
    canvas.translate(6, 26);
    canvas.drawPath(
      _ribbon(w, top, bottom, w * 0.335),
      Paint()..color = const Color(0xFF2C7FAE).withValues(alpha: 0.30),
    );
    canvas.restore();

    // 岛的厚度：把整块岛往左下挤出一点，形成侧壁
    canvas.save();
    canvas.translate(-10, 16);
    canvas.drawPath(
      _ribbon(w, top, bottom, w * 0.33),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC9A470), Color(0xFF9A7540)],
        ).createShader(Rect.fromLTWH(0, top, w, bottom - top)),
    );
    canvas.restore();

    // 沙滩
    canvas.drawPath(
      _ribbon(w, top, bottom, w * 0.33),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBEBC4), Color(0xFFEBD5A4)],
        ).createShader(Rect.fromLTWH(0, top, w, bottom - top)),
    );

    // 草地
    final grass = _ribbon(w, top, bottom, w * 0.33 - 20);
    canvas.drawPath(
      grass,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD3F0BE), Color(0xFFA6DA8D), Color(0xFF7FC169)],
        ).createShader(Rect.fromLTWH(0, top, w, bottom - top)),
    );
    canvas.drawPath(
      grass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF6FB259).withValues(alpha: 0.35),
    );

    _paintTrail(canvas);
    _paintDecos(canvas);

    canvas.restore();
  }

  Path _ribbon(double w, double top, double bottom, double halfW) {
    const step = 26.0;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var y = top; y <= bottom + step; y += step) {
      final wob = sin(y * 0.0075) * 0.05 + cos(y * 0.0031) * 0.035;
      final hw = halfW * (1 + wob);
      final cen = w / 2 + sin(y * 0.0042) * halfW * 0.10;
      left.add(Offset(cen - hw, y));
      right.add(Offset(cen + hw, y));
    }
    final p = Path()..moveTo(left.first.dx, left.first.dy);
    for (final o in left.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    for (final o in right.reversed) {
      p.lineTo(o.dx, o.dy);
    }
    p.close();
    return p;
  }

  void _paintTrail(Canvas canvas) {
    final pts = layout.trail;
    if (pts.length < 2) return;
    final path = _smooth(pts);

    // 阴影 / 厚度
    canvas.save();
    canvas.translate(-8, 13);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 42
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFB08B58),
    );
    canvas.restore();

    // 路面
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF2D8), Color(0xFFEFDDB4)],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 400)),
    );

    // 高光
    canvas.save();
    canvas.translate(-3, -4);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFFBF0).withValues(alpha: 0.9),
    );
    canvas.restore();
  }

  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = (i + 2 < pts.length) ? pts[i + 2] : p2;
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _paintDecos(Canvas canvas) {
    final top = cam - 120;
    final bottom = cam + viewH + 120;
    final visible = layout.decos
        .where((d) => d.y > top && d.y < bottom)
        .toList()
      ..sort((a, b) => a.y.compareTo(b.y));

    for (final d in visible) {
      final s = d.size;
      // 投影
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(d.x + 3, d.y + 3), width: s * 1.15, height: s * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.16),
      );
      switch (d.kind) {
        case 0: // 树
          canvas.drawRect(
            Rect.fromLTWH(d.x - s * 0.09, d.y - s * 1.05, s * 0.18, s * 1.05),
            Paint()..color = const Color(0xFF8B5A2B),
          );
          for (var i = 0; i < 3; i++) {
            final r = s * (0.62 - i * 0.13);
            final yy = d.y - s * (0.75 + i * 0.42);
            canvas.drawCircle(
              Offset(d.x - r * 0.28, yy),
              r,
              Paint()..color = Color.lerp(
                  const Color(0xFF2E8B57), const Color(0xFF7FD48F), i / 3)!,
            );
            canvas.drawCircle(
              Offset(d.x + r * 0.3, yy + r * 0.12),
              r * 0.86,
              Paint()..color = Color.lerp(
                  const Color(0xFF3AA366), const Color(0xFF95E0A2), i / 3)!,
            );
          }
          break;
        case 1: // 小房子
          final bw = s * 1.25;
          final bh = s * 1.0;
          canvas.drawRect(
            Rect.fromLTWH(d.x - bw / 2, d.y - bh, bw, bh),
            Paint()..color = const Color(0xFFFDF3E0),
          );
          canvas.drawRect(
            Rect.fromLTWH(d.x - bw / 2, d.y - bh * 0.55, bw, bh * 0.55),
            Paint()..color = const Color(0xFFF3E2C4),
          );
          final roof = Path()
            ..moveTo(d.x - bw * 0.62, d.y - bh)
            ..lineTo(d.x, d.y - bh * 1.6)
            ..lineTo(d.x + bw * 0.62, d.y - bh)
            ..close();
          canvas.drawPath(roof, Paint()..color = const Color(0xFFE07A5F));
          canvas.drawRect(
            Rect.fromLTWH(d.x - bw * 0.16, d.y - bh * 0.5, bw * 0.32, bh * 0.5),
            Paint()..color = const Color(0xFFB5835A),
          );
          break;
        case 2: // 灌木
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(d.x, d.y - s * 0.22),
                width: s * 1.1,
                height: s * 0.62),
            Paint()..color = const Color(0xFF63B86B),
          );
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(d.x - s * 0.22, d.y - s * 0.42),
                width: s * 0.7,
                height: s * 0.44),
            Paint()..color = const Color(0xFF84CE8B),
          );
          break;
        default: // 石头
          final p = Path()
            ..moveTo(d.x - s * 0.5, d.y)
            ..lineTo(d.x - s * 0.32, d.y - s * 0.5)
            ..lineTo(d.x + s * 0.18, d.y - s * 0.58)
            ..lineTo(d.x + s * 0.5, d.y - s * 0.12)
            ..close();
          canvas.drawPath(p, Paint()..color = const Color(0xFFB9BEC6));
          canvas.drawPath(
            Path()
              ..moveTo(d.x - s * 0.32, d.y - s * 0.5)
              ..lineTo(d.x + s * 0.18, d.y - s * 0.58)
              ..lineTo(d.x + s * 0.06, d.y - s * 0.26)
              ..close(),
            Paint()..color = const Color(0xFFD7DBE1),
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_WorldPainter old) =>
      old.cam != cam || old.layout.height != layout.height;
}

// ─────────────────────────────────────────────────────────────
// 背景：天、海、云、鸟
// ─────────────────────────────────────────────────────────────

class _Backdrop extends StatefulWidget {
  const _Backdrop();

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SeaPainter())),
          Positioned.fill(
            child: CustomPaint(
              painter: _SkyLife(t: _c.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9FDCF7), Color(0xFF6FC2E8), Color(0xFF4AA9D8)],
        ).createShader(rect),
    );
    // 太阳
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.09),
      26,
      Paint()..color = const Color(0xFFFFD375).withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.09),
      40,
      Paint()..color = const Color(0xFFFFE3A3).withValues(alpha: 0.35),
    );
    // 海面波纹
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (var i = 0; i < 9; i++) {
      final y = size.height * (0.18 + i * 0.095);
      final p = Path()..moveTo(-20, y);
      for (var x = -20.0; x < size.width + 40; x += 40) {
        p.quadraticBezierTo(x + 10, y - 5, x + 20, y);
        p.quadraticBezierTo(x + 30, y + 5, x + 40, y);
      }
      canvas.drawPath(p, wave);
    }
  }

  @override
  bool shouldRepaint(_SeaPainter old) => false;
}

class _SkyLife extends CustomPainter {
  final double t;

  _SkyLife({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // 云
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 3; i++) {
      final phase = (t + i * 0.33) % 1.0;
      final x = -80 + phase * (size.width + 160);
      final y = size.height * (0.08 + i * 0.16);
      final s = 0.8 + i * 0.25;
      for (final o in const [
        Offset(0, 0),
        Offset(26, -8),
        Offset(-26, 4),
        Offset(10, 8),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + o.dx * s, y + o.dy * s),
            width: 52 * s,
            height: 30 * s,
          ),
          cloudPaint,
        );
      }
    }
    // 飞鸟（扇翅膀）
    final birdPaint = Paint()
      ..color = const Color(0xFF4B6B7A).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final phase = (t * 1.6 + i * 0.27) % 1.0;
      final x = -40 + phase * (size.width + 80);
      final y = size.height * (0.16 + i * 0.10);
      final flap = sin((t * 12 + i) * pi) * 5;
      final p = Path()
        ..moveTo(x - 10, y + flap)
        ..quadraticBezierTo(x - 4, y - 4, x, y)
        ..quadraticBezierTo(x + 4, y - 4, x + 10, y + flap);
      canvas.drawPath(p, birdPaint);
    }
  }

  @override
  bool shouldRepaint(_SkyLife old) => old.t != t;
}
