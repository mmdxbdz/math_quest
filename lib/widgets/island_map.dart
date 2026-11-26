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
  final List<Offset> trail; // 一条小路，按爬岛的先后顺序
  final int currentIndex;
  final double currentY;

  /// 路只画到这条线为止，再往上还在云雾里（走几关才延伸出来）
  final double revealY;

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
    this.revealY = 0,
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

// 岛的椭圆范围（画图和布局共用同一套数字）
/// 台阶之间的间距（往上爬的步长）
  static const double nodeGap = 132.0;

  /// 沿着岛上的路一直往上走：世界只有一条蜿蜒向上的小路，
  /// 第 1 关在岛脚最下面，越往后越靠近山顶的灯塔；屏幕是跟着手指走的镜头。
  /// 还没走到的地方用云雾挡着——走几步，路就往后面（上面）延伸一截。
  factory MapLayout.build(Size size, List<Unit> units, ProgressStore store) {
    const signGap = 92.0; // 木牌到第一关的距离
    const unitGap = 44.0; // 两个主题之间的留白
    const houseGap = 140.0; // 宠物房占的那一段路
    const topPad = 320.0; // 山顶给灯塔留的地方

    final w = size.width;
    final cx = w / 2;
    final amp = min(w * 0.115, 46.0);

    var levelTotal = 0;
    for (final u in units) {
      levelTotal += u.lessons.length * 3;
    }
    final houseCount = min(
      kPetSpecies.length - 1,
      levelTotal ~/ kPetUnlockEveryLevels,
    );
    final ownedSpecies = store.pets.map((p) => p.speciesId).toSet();

    var total = topPad + houseCount * houseGap;
    for (final u in units) {
      total += signGap + u.lessons.length * 3 * nodeGap + unitGap;
    }
    final height = total + 170;

    /// 世界 y：越小 = 越往山上（屏幕越靠上）
    double worldY(double dist) => height - dist;

    var dist = 170.0; // 从最下面的第 1 关往上量
    var idx = 0;
    var houseIdx = 0;
    final levels = <MapLevel>[];
    final signs = <MapSign>[];
    final houses = <MapPetHouse>[];
    final trail = <Offset>[];

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
          trail.add(Offset(x, y));
          if (stars > 0) unitDone++;
          idx++;
          dist += nodeGap;
          // 每满 6 关：在刚过的这一关和下一关中间开一间宠物房
          if (idx % kPetUnlockEveryLevels == 0 && houseIdx < houseCount) {
            final sp = petSpeciesOf(kPetUnlockOrder[houseIdx + 1]);
            final hx = cx + amp * sin((idx - 0.5) * 0.42);
            final hy = worldY(dist + nodeGap * 0.45);
            houses.add(MapPetHouse(
              speciesId: sp.id,
              x: hx,
              y: hy,
              order: houseIdx + 1,
              owned: ownedSpecies.contains(sp.id),
            ));
            trail.add(Offset(hx, hy));
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
      trail.add(Offset(signX, worldY(signDist)));
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
    final nextHouse = houses.indexWhere((h) => !h.owned);
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

    trail.sort((a, b) => a.dy.compareTo(b.dy));

    // 还没走到的路：只露出脚下往上 2~3 关，其余藏在云雾里，
    // 每往前走几关，路就再往上延伸一截。
    var unlockTop = double.infinity;
    for (final l in levels) {
      if (l.unlocked && l.y < unlockTop) unlockTop = l.y;
    }
    if (unlockTop == double.infinity) unlockTop = height;
    final revealY = unlockTop - nodeGap * 2.6;

    // 装饰：沿小路两侧随机种
    final rnd = Random(11);
    final decos = <MapDeco>[];
    for (var i = 0; i < 130; i++) {
      final y = 120 + rnd.nextDouble() * (height - 240);
      final tx = _trailX(trail, cx, y);
      final side = rnd.nextBool() ? 1 : -1;
      final off = w * (0.16 + rnd.nextDouble() * 0.09);
      decos.add(MapDeco(
        kind: rnd.nextInt(6),
        x: tx + side * off,
        y: y,
        size: 21 + rnd.nextDouble() * 12,
      ));
    }
    // 岛脚和山顶各放几个大件，避免太空
    decos.add(MapDeco(kind: 1, x: cx - w * 0.19, y: height - 96, size: 30));
    decos.add(MapDeco(kind: 0, x: cx + w * 0.20, y: height - 130, size: 30));
    decos.add(MapDeco(kind: 0, x: cx - w * 0.22, y: topPad - 150, size: 30));
    decos.add(MapDeco(kind: 2, x: cx + w * 0.24, y: topPad - 70, size: 26));

    return MapLayout(
      width: w,
      height: height,
      levels: levels,
      signs: signs,
      decos: decos,
      houses: houses,
      trail: trail,
      currentIndex: currentIdx,
      currentY: levels[currentIdx].y,
      revealY: revealY,
    );
  }

  /// 小路上某个高度处的中线 x
  static double _trailX(List<Offset> trail, double fallback, double y) {
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
  /// 镜头：屏幕最上方对应的世界 y。世界 y 越小 = 越往山上。
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

  /// 画面跟着手指走：手指往下扒拉，上面那几关就一节节下来
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
    final target = (layout.currentY - viewH * 0.34).clamp(0.0, _maxCam);
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
        _cam = (layout.currentY - size.height * 0.34).clamp(0.0, _maxCam);
      }
      if (_cam > _maxCam) _cam = _maxCam;

      // 倾斜之后内容顶部会缩进一块，多画一截补上，免得露接缝
      final extraTop = size.height * 0.55;
      final boxH = size.height + extraTop;
      final cam = _cam - extraTop;

      // 云雾那头还没走出来：只画已经走到的路（世界 y 越大 = 越靠下 = 已经走过）
      final revealLow = layout.revealY - 40;

      final mapStack = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WorldPainter(layout: layout, cam: cam, viewH: boxH),
              ),
            ),
          ),
          for (final s in layout.signs)
            if (s.y - cam > -160 && s.y - cam < boxH + 160 && s.y > revealLow)
              _signPost(s, cam),
          for (final h in layout.houses)
            if (h.y - cam > -240 && h.y - cam < boxH + 240 && h.y > revealLow)
              _petHouse(h, cam),
          for (final l in layout.levels)
            if (l.y - cam > -220 && l.y - cam < boxH + 220 && l.y > revealLow)
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
              // 整个画面做一点透视，越往上越远，像顺着山路往上走
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
    final cx = w / 2;
    final bottom = cam + viewH + 320;
    // 只画"已经走到的路"：再往上还在云雾里，走几关才延伸出来
    final revealed = layout.revealY > cam - 320;
    final top = revealed ? max(cam - 320, layout.revealY) : cam - 320;
    final span = bottom - top;

    // 云雾之外的整段路都不画（包括小路和装饰）
    canvas.save();
    if (revealed) {
      canvas.clipRect(
          Rect.fromLTWH(-60, layout.revealY, w + 120, viewH + 800));
    }

    // 海水下的影子
    canvas.save();
    canvas.translate(8, 30);
    canvas.drawPath(
      _ribbon(w, top, bottom, w * 0.345),
      Paint()..color = const Color(0xFF2C7FAE).withValues(alpha: 0.16),
    );
    canvas.restore();

    // 沙滩外面的礁石带
    canvas.drawPath(
      _ribbon(w, top, bottom, w * 0.372),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFC4CFD8), Color(0xFF9DAAB7)],
        ).createShader(Rect.fromLTWH(0, top, w, span)),
    );
    // 岛外面两圈白浪
    for (var i = 0; i < 2; i++) {
      canvas.drawPath(
        _ribbon(w, top, bottom, w * (0.382 + i * 0.022)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = Colors.white.withValues(alpha: i == 0 ? 0.6 : 0.3),
      );
    }

    // 岛的厚度
    canvas.save();
    canvas.translate(-12, 18);
    canvas.drawPath(
      _ribbon(w, top, bottom, w * 0.335),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFDDBB80), Color(0xFFB78C51)],
        ).createShader(Rect.fromLTWH(0, top, w, span)),
    );
    canvas.restore();

    // 沙滩
    canvas.drawPath(
      _ribbon(w, top, bottom, w * 0.335),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFFFF4DA), Color(0xFFF3DEB1)],
        ).createShader(Rect.fromLTWH(0, top, w, span)),
    );

    // 草地
    final grass = _ribbon(w, top, bottom, w * 0.335 - 22);
    canvas.drawPath(
      grass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFCEF0A7),
            Color(0xFFA3DC80),
            Color(0xFF7EC565),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, top, w, span)),
    );
    canvas.drawPath(
      grass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Color(0xFFE6F9CB).withValues(alpha: 0.8),
    );

    // 草簇（固定随机，不闪烁）
    for (var y = (top / 46).floor() * 46.0; y < bottom; y += 46) {
      final wob = sin(y * 0.0068) * 0.085 + cos(y * 0.0029) * 0.055;
      final hw = (w * 0.335 - 34) * (1 + wob);
      final cen = cx + sin(y * 0.0042) * w * 0.335 * 0.10;
      for (var i = 0; i < 3; i++) {
        final side = i == 0 ? -1.0 : (i == 1 ? 1.0 : 0.0);
        final gx = cen + side * hw * (0.55 + 0.16 * ((y ~/ 46) % 3));
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(gx, y + ((y.toInt() + i * 7) % 11)),
            width: 12,
            height: 5,
          ),
          Paint()..color = const Color(0xFF95D378).withValues(alpha: 0.55),
        );
      }
    }

    // 岸边一块块礁石
    for (var y = (top / 78).floor() * 78.0; y < bottom; y += 78) {
      final wob = sin(y * 0.0068) * 0.085 + cos(y * 0.0029) * 0.055;
      final hw = w * 0.335 * (1 + wob);
      final cen = cx + sin(y * 0.0042) * w * 0.335 * 0.10;
      for (final side in const [-1.0, 1.0]) {
        final rr = 8.0 + ((y.toInt() ~/ 78) % 3) * 3.5;
        final rx = cen + side * hw * 0.98;
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(rx, y + 6), width: rr * 2.3, height: rr * 1.4),
          Paint()..color = const Color(0xFFAFBAC4),
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(rx - 2, y - 2), width: rr * 1.5, height: rr * 0.95),
          Paint()..color = const Color(0xFFD2DAE2),
        );
      }
    }

    _paintTrail(canvas);
    // 山顶的灯塔：路一直走到最上面就能看见
    if (top < 300) {
      _paintLighthouse(canvas, cx + w * 0.22, 150);
    }
    _paintDecos(canvas, top);

    canvas.restore(); // 结束"只画走过的路"的裁剪

    // 路走到这儿就断了：前面是白白的云雾，走几关云雾退上去、路再延伸一截
    if (revealed) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(-60, layout.revealY - 560, w + 120, 660));
      final crnd = Random(7);
      // 一排胖云把路"截断"，看着像路还在云雾里面往前长
      for (var row = 0; row < 3; row++) {
        for (var i = 0; i < 8; i++) {
          final cxx = -30 + (i / 7) * (w + 60) + (crnd.nextDouble() - 0.5) * 26;
          final cyy = layout.revealY -
              14 +
              row * 30 +
              (crnd.nextDouble() - 0.5) * 22;
          final rw = 116.0 + crnd.nextDouble() * 96;
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cxx, cyy), width: rw, height: rw * 0.46),
            Paint()..color = const Color(0xFFF6FDFF).withValues(alpha: 0.97),
          );
        }
      }
      for (var i = 0; i < 6; i++) {
        final cxx = -20 + (i / 5) * (w + 40);
        final cyy = layout.revealY - 120 - crnd.nextDouble() * 90;
        final rw = 150.0 + crnd.nextDouble() * 120;
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cxx, cyy), width: rw, height: rw * 0.42),
          Paint()..color = const Color(0xFFF3FBFE).withValues(alpha: 0.9),
        );
      }
      canvas.restore();
    }

    canvas.restore();
  }

  /// 蜿蜒的岛身：两边随高度轻轻摆动，看起来是一条盘上山的岛路
  Path _ribbon(double w, double top, double bottom, double halfW) {
    const step = 26.0;
    final cx = w / 2;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var y = top - step; y <= bottom + step; y += step) {
      final wob = sin(y * 0.0068) * 0.085 + cos(y * 0.0029) * 0.055;
      final hw = halfW * (1 + wob);
      final cen = cx + sin(y * 0.0042) * w * 0.335 * 0.10;
      left.add(Offset(cen - hw, y));
      right.add(Offset(cen + hw, y));
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  /// 山顶的灯塔（白塔身 + 橘色圆顶 + 暖黄灯光）
  void _paintLighthouse(Canvas canvas, double x, double baseY) {
    canvas.save();
    canvas.translate(x, baseY);
    canvas.scale(1.35);
    canvas.translate(-x, -baseY);

    const towerH = 106.0;
    const bottomW = 42.0;
    const topW = 27.0;
    final topY = baseY - towerH;

    // 底座岩石
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, baseY + 5), width: 80, height: 24),
      Paint()..color = const Color(0xFFB7C1CA),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x - 4, baseY + 2), width: 66, height: 17),
      Paint()..color = const Color(0xFFD4DCE3),
    );

    // 塔身
    final tower = Path()
      ..moveTo(x - bottomW / 2, baseY)
      ..lineTo(x - topW / 2, topY + 14)
      ..lineTo(x + topW / 2, topY + 14)
      ..lineTo(x + bottomW / 2, baseY)
      ..close();
    canvas.drawPath(
      tower,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFF5F2EC), Color(0xFFFFFFFF), Color(0xFFDAD5CB)],
          stops: [0.0, 0.42, 1.0],
        ).createShader(tower.getBounds()),
    );

    // 两圈橘色条纹
    for (final ty in const [0.34, 0.70]) {
      final y = baseY - towerH * ty;
      final ww = bottomW - (bottomW - topW) * ty;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: ww - 1, height: 8),
        Paint()..color = const Color(0xFFFF8A5B),
      );
    }

    // 观景台
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, topY + 13), width: topW + 20, height: 8),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF9AA5B1),
    );

    // 灯室
    final lampRect = Rect.fromCenter(
      center: Offset(x, topY + 3),
      width: topW + 2,
      height: 17,
    );
    canvas.drawCircle(
      Offset(x, topY + 3),
      36,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF1BC).withValues(alpha: 0.8),
            const Color(0xFFFFF1BC).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, topY + 3), radius: 36)),
    );
    canvas.drawRect(lampRect, Paint()..color = const Color(0xFFFFE79A));
    canvas.drawRect(
      lampRect,
      Paint()
        ..color = const Color(0xFF8A929B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 橘色圆顶 + 尖顶
    final roof = Path()
      ..moveTo(x - topW / 2 - 4, topY - 5)
      ..quadraticBezierTo(x, topY - 27, x + topW / 2 + 4, topY - 5)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFF2843F));
    canvas.drawCircle(
      Offset(x, topY - 24),
      3.6,
      Paint()..color = const Color(0xFFF2843F),
    );
    canvas.restore();
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
        ..color = const Color(0xFFB3AC9C),
    );
    canvas.restore();

    // 路面：浅色的石板路
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF7EC), Color(0xFFDFD8C7)],
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

    // 一片片木栈道/石板的接缝
    final seam = Paint()
      ..color = const Color(0xFFBFB4A0).withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final seg = (b - a).distance;
      if (seg < 1) continue;
      final d = (b - a) / seg;
      final nrm = Offset(-d.dy, d.dx);
      final steps = (seg / 34).floor();
      for (var k = 1; k < steps; k++) {
        final p = Offset.lerp(a, b, k / steps)!;
        canvas.drawLine(p - nrm * 10, p + nrm * 10, seam);
      }
    }
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

  void _paintDecos(Canvas canvas, double top) {
    final visible = layout.decos
        .where((d) => d.y >= top - 40)
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
        case 0: // 椰子树：弯树干 + 一圈叶子 + 两个椰子
          final top = Offset(d.x + s * 0.26, d.y - s * 2.0);
          final trunkPath = Path()
            ..moveTo(d.x - s * 0.12, d.y)
            ..quadraticBezierTo(d.x + s * 0.14, d.y - s * 1.05, top.dx, top.dy);
          canvas.drawPath(
            trunkPath,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.26
              ..strokeCap = StrokeCap.round
              ..shader = const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFC08A54), Color(0xFF8A5A2E)],
              ).createShader(Rect.fromLTWH(
                  d.x - s * 0.3, d.y - s * 2.2, s * 0.9, s * 2.2)),
          );
          for (var i = 1; i <= 3; i++) {
            final tt = i / 4;
            final px = (1 - tt) * (1 - tt) * (d.x - s * 0.12) +
                2 * (1 - tt) * tt * (d.x + s * 0.14) +
                tt * tt * top.dx;
            final py = (1 - tt) * (1 - tt) * d.y +
                2 * (1 - tt) * tt * (d.y - s * 1.05) +
                tt * tt * top.dy;
            canvas.drawLine(
              Offset(px - s * 0.12, py),
              Offset(px + s * 0.11, py + s * 0.02),
              Paint()
                ..color = const Color(0xFF7A4E28).withValues(alpha: 0.45)
                ..strokeWidth = s * 0.06
                ..strokeCap = StrokeCap.round,
            );
          }
          for (final o in const [Offset(-0.14, 0.06), Offset(0.14, 0.10)]) {
            canvas.drawCircle(
              Offset(top.dx + s * o.dx, top.dy + s * o.dy),
              s * 0.13,
              Paint()..color = const Color(0xFF9A6A3A),
            );
          }
          for (var i = 0; i < 6; i++) {
            final ang = -pi / 2 + (i - 2.5) * 0.58;
            final len = s * (1.75 - (i - 2.5).abs() * 0.16);
            final tip = Offset(
                top.dx + cos(ang) * len, top.dy + sin(ang) * len * 0.70);
            final ctrl = Offset(
              top.dx + cos(ang) * len * 0.55,
              top.dy + sin(ang) * len * 0.5 - s * 0.22,
            );
            final leaf = Path()
              ..moveTo(top.dx, top.dy)
              ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy)
              ..quadraticBezierTo(
                  ctrl.dx - cos(ang) * s * 0.10,
                  ctrl.dy + s * 0.52,
                  top.dx,
                  top.dy)
              ..close();
            canvas.drawPath(
              leaf,
              Paint()
                ..color =
                    i.isEven ? const Color(0xFF5FBA57) : const Color(0xFF86DA73),
            );
          }
          break;
        case 1: // 小房子（圆顶小屋，参考图里的那种）
          final bw = s * 1.25;
          final bh = s * 1.0;
          final wall = Rect.fromLTRB(d.x - bw / 2, d.y - bh, d.x + bw / 2, d.y);
          canvas.drawRRect(
            RRect.fromRectAndRadius(wall, Radius.circular(s * 0.16)),
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF0E4D0)],
              ).createShader(wall),
          );
          final roof = Path()
            ..moveTo(d.x - bw * 0.64, d.y - bh * 0.96)
            ..quadraticBezierTo(d.x, d.y - bh * 1.95, d.x + bw * 0.64, d.y - bh * 0.96)
            ..close();
          canvas.drawPath(
            roof,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFA96B), Color(0xFFE07A45)],
              ).createShader(Rect.fromLTRB(
                  d.x - bw * 0.7, d.y - bh * 2, d.x + bw * 0.7, d.y - bh * 0.9)),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(d.x - bw * 0.16, d.y - bh * 0.52, bw * 0.32,
                  bh * 0.52),
              Radius.circular(s * 0.08),
            ),
            Paint()..color = const Color(0xFFB5835A),
          );
          canvas.drawCircle(
            Offset(d.x + bw * 0.28, d.y - bh * 0.66),
            s * 0.10,
            Paint()..color = const Color(0xFFFFE79A),
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
            Paint()..color = const Color(0xFF8ADB77),
          );
          break;
        case 4: // 珊瑚（沙滩边上的粉色珊瑚）
          for (final o in const [
            Offset(-0.30, 0.62),
            Offset(0.02, 0.80),
            Offset(0.30, 0.56),
          ]) {
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(d.x + s * o.dx, d.y - s * o.dy * 0.55),
                width: s * 0.22,
                height: s * o.dy,
              ),
              Paint()..color = const Color(0xFFF79AB2),
            );
          }
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(d.x, d.y - s * 0.06),
                width: s * 0.86,
                height: s * 0.22),
            Paint()..color = const Color(0xFFFFC2D1),
          );
          break;
        case 5: // 贝壳
          final shell = Rect.fromCenter(
            center: Offset(d.x, d.y - s * 0.14),
            width: s * 0.66,
            height: s * 0.46,
          );
          canvas.drawOval(shell, Paint()..color = const Color(0xFFFFF2E2));
          for (var i = -1; i <= 1; i++) {
            canvas.drawLine(
              Offset(d.x + i * s * 0.15, d.y - s * 0.34),
              Offset(d.x + i * s * 0.20, d.y + s * 0.02),
              Paint()
                ..color = const Color(0xFFE7CBB4)
                ..strokeWidth = 1.6,
            );
          }
          break;
        default: // 石头
          final p = Path()
            ..moveTo(d.x - s * 0.5, d.y)
            ..lineTo(d.x - s * 0.32, d.y - s * 0.5)
            ..lineTo(d.x + s * 0.18, d.y - s * 0.58)
            ..lineTo(d.x + s * 0.5, d.y - s * 0.12)
            ..close();
          canvas.drawPath(
            p,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD7DBE1), Color(0xFFA8AFB9)],
              ).createShader(Rect.fromLTRB(
                  d.x - s * 0.5, d.y - s * 0.6, d.x + s * 0.5, d.y)),
          );
          canvas.drawPath(
            Path()
              ..moveTo(d.x - s * 0.32, d.y - s * 0.5)
              ..lineTo(d.x + s * 0.18, d.y - s * 0.58)
              ..lineTo(d.x + s * 0.06, d.y - s * 0.26)
              ..close(),
            Paint()..color = const Color(0xFFEDF1F5),
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_WorldPainter old) =>
      old.cam != cam ||
      old.viewH != viewH ||
      old.layout.revealY != layout.revealY ||
      old.layout.height != layout.height;
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
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.42;

    // 天：上面浅蓝，靠近海面泛白（参考图那种粉蓝色）
    final skyRect = Rect.fromLTWH(0, 0, w, horizon + 4);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9EDCF2), Color(0xFFC6EEF9), Color(0xFFE8FAF2)],
          stops: [0.0, 0.60, 1.0],
        ).createShader(skyRect),
    );

    // 左上角的太阳光晕
    final sun = Offset(w * 0.15, h * 0.05);
    final glow = Rect.fromCircle(center: sun, radius: w * 0.42);
    canvas.drawCircle(
      sun,
      w * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF8DC).withValues(alpha: 0.95),
            const Color(0xFFFFF8DC).withValues(alpha: 0.0),
          ],
        ).createShader(glow),
    );
    canvas.drawCircle(
      sun,
      w * 0.055,
      Paint()..color = const Color(0xFFFFFBE8).withValues(alpha: 0.95),
    );

    // 海：青绿 → 蓝绿
    final seaRect = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(
      seaRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9CE8E4), Color(0xFF6FD3DA), Color(0xFF46B6C8)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(seaRect),
    );

    // 地平线远处的小岛，让海面有远近层次
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.20, horizon + h * 0.045),
        width: w * 0.30,
        height: h * 0.030,
      ),
      Paint()..color = const Color(0xFF5FC7C6).withValues(alpha: 0.55),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.18, horizon + h * 0.020),
        width: w * 0.17,
        height: h * 0.034,
      ),
      Paint()..color = const Color(0xFF7DD3A0).withValues(alpha: 0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.80, horizon + h * 0.030),
        width: w * 0.22,
        height: h * 0.024,
      ),
      Paint()..color = const Color(0xFF5FC7C6).withValues(alpha: 0.45),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.79, horizon + h * 0.010),
        width: w * 0.12,
        height: h * 0.026,
      ),
      Paint()..color = const Color(0xFF86D8A4).withValues(alpha: 0.75),
    );

    // 地平线上的一道亮边
    canvas.drawRect(
      Rect.fromLTWH(0, horizon - 3, w, 5),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // 海面亮带 + 波光
    for (var i = 0; i < 7; i++) {
      final y = horizon + (h - horizon) * (0.08 + i * 0.135);
      final bw = w * (0.30 + (i % 3) * 0.16);
      final rect = Rect.fromLTWH(w * (0.08 + (i % 4) * 0.17), y, bw, 5.0 + (i % 2) * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );
    }
    for (var i = 0; i < 30; i++) {
      final x = ((i * 37) % 100) / 100 * w;
      final y = horizon + (((i * 61) % 100) / 100) * (h - horizon);
      canvas.drawCircle(
        Offset(x, y),
        1.7,
        Paint()..color = Colors.white.withValues(alpha: 0.32),
      );
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
    // 云：黏土质感的蓬蓬云，底下带一点淡蓝的暗面
    for (var i = 0; i < 4; i++) {
      final phase = (t + i * 0.27) % 1.0;
      final x = -110 + phase * (size.width + 220);
      final y = size.height * (0.05 + i * 0.11);
      final s = 0.75 + i * 0.22;
      final lobes = const [
        Offset(0, 2),
        Offset(30, -6),
        Offset(-30, 4),
        Offset(12, 12),
        Offset(-14, 11),
        Offset(46, 6),
      ];
      // 暗面先画，整体往下挪一点
      for (final o in lobes) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + o.dx * s, y + o.dy * s + 6 * s),
            width: 58 * s,
            height: 34 * s,
          ),
          Paint()..color = const Color(0xFFCDE8F2).withValues(alpha: 0.55),
        );
      }
      for (final o in lobes) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + o.dx * s, y + o.dy * s),
            width: 58 * s,
            height: 34 * s,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.94),
        );
      }
    }
    // 飞鸟（扇翅膀）
    final birdPaint = Paint()
      ..color = const Color(0xFF4B6B7A).withValues(alpha: 0.6)
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
