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

  /// 这是第几座岛（= 第几个主题单元），以及一共有几座岛
  final int unitIndex;
  final int unitCount;

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
    this.unitIndex = 0,
    this.unitCount = 1,
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
  static const double islandCx = 0.5;
  static const double islandCy = 0.545;
  static const double islandRx = 0.455;
  static const double islandRy = 0.325;

  static Offset islandCenter(Size size) =>
      Offset(size.width * islandCx, size.height * islandCy);
  static double islandWidth(Size size) => size.width * islandRx * 2;
  static double islandHeight(Size size) => size.height * islandRy * 2;

  /// 一座岛 = 课程里的一个主题单元（2~4 课时，6~12 关），一屏就能看完整座岛。
  /// 关卡从岛的最下面那一关开始，一圈圈盘上去，山顶是灯塔。
  factory MapLayout.build(Size size, List<Unit> units, ProgressStore store,
      {int? unitIndex}) {
    final w = size.width;
    final h = size.height;
    final c = islandCenter(size);
    final rx = size.width * islandRx;
    final ry = size.height * islandRy;

    // 每个单元几关、从第几关开始
    final counts = [for (final u in units) u.lessons.length * 3];
    final starts = <int>[];
    var acc = 0;
    for (final n in counts) {
      starts.add(acc);
      acc += n;
    }

    // 全岛链的关卡顺序（用来判断解锁和"现在在第几关"）
    final keys = <String>[];
    final starsOf = <int>[];
    for (final u in units) {
      for (final lesson in u.lessons) {
        for (var stage = 0; stage < 3; stage++) {
          keys.add('${lesson.id}:s$stage');
          starsOf.add(store.stageStars(lesson.id, stage));
        }
      }
    }

    var globalCur = -1;
    for (var i = 0; i < keys.length; i++) {
      if (store.levelUnlocked(keys, i) && starsOf[i] == 0) {
        globalCur = i;
        break;
      }
    }
    if (globalCur < 0) {
      for (var i = 0; i < keys.length; i++) {
        if (store.levelUnlocked(keys, i)) globalCur = i;
      }
      if (globalCur < 0) globalCur = 0;
    }

    // 现在在哪座岛
    var curUnit = 0;
    for (var i = 0; i < counts.length; i++) {
      if (globalCur >= starts[i] && globalCur < starts[i] + counts[i]) {
        curUnit = i;
        break;
      }
    }
    final ui = (unitIndex ?? curUnit).clamp(0, units.length - 1);

    final unit = units[ui];
    final start = starts[ui];
    final n = counts[ui];

    // 关卡沿着圆岛盘旋而上：第 1 关在岛底，最后一关在山顶
    final levels = <MapLevel>[];
    final trail = <Offset>[];
    for (var k = 0; k < n; k++) {
      final g = start + k;
      final u01 = n == 1 ? 0.0 : k / (n - 1);
      final ang = (90 - 480 * u01) * pi / 180; // 从底下开始，转一圈零一点盘上去
      final rad = 0.80 - 0.30 * u01; // 越往上越靠里
      final x = c.dx + cos(ang) * rx * rad;
      final y = c.dy + sin(ang) * ry * rad;
      final lesson = unit.lessons[k ~/ 3];
      final stage = k % 3;
      levels.add(MapLevel(
        lesson: lesson,
        stage: stage,
        key: keys[g],
        index: g,
        x: x,
        y: y,
        stars: starsOf[g],
        unlocked: store.levelUnlocked(keys, g),
        current: g == globalCur,
      ));
      trail.add(Offset(x, y));
    }

    // 岛底一块木牌：这座岛的名字和进度
    final signY = c.dy + ry * 1.16;
    final done = levels.where((l) => l.stars > 0).length;
    final signs = <MapSign>[
      MapSign(
        unit: unit,
        x: c.dx,
        y: signY,
        done: done,
        total: n,
        firstLevel: start + 1,
        lastLevel: start + n,
      ),
    ];
    trail.insert(0, Offset(c.dx, signY - 14));

    // 宠物房：每满 6 关一间，落在这座岛的关卡之间
    final houses = <MapPetHouse>[];
    final ownedSpecies = store.pets.map((p) => p.speciesId).toSet();
    final houseCount = min(
      kPetSpecies.length - 1,
      keys.length ~/ kPetUnlockEveryLevels,
    );
    for (var k = 1; k <= houseCount; k++) {
      final afterGlobal = kPetUnlockEveryLevels * k - 1;
      final li = afterGlobal - start;
      if (li < 0 || li >= n) continue;
      final sp = petSpeciesOf(kPetUnlockOrder[k]);
      final a = levels[li];
      final b = li + 1 < n ? levels[li + 1] : null;
      final hx = b == null ? a.x + 44 : (a.x + b.x) / 2;
      final hy = b == null ? a.y - 42 : (a.y + b.y) / 2;
      houses.add(MapPetHouse(
        speciesId: sp.id,
        x: hx,
        y: hy,
        order: k,
        owned: ownedSpecies.contains(sp.id),
      ));
    }
    final nextHouse = houses.indexWhere((hh) => !hh.owned);
    if (nextHouse >= 0) {
      final hh = houses[nextHouse];
      houses[nextHouse] = MapPetHouse(
        speciesId: hh.speciesId,
        x: hh.x,
        y: hh.y,
        order: hh.order,
        owned: hh.owned,
        next: true,
      );
    }

    // 装饰：岛上零星种点东西，别挡着路
    final rnd = Random(23 + ui * 11);
    final decos = <MapDeco>[];
    for (var i = 0; i < 46; i++) {
      final ang = rnd.nextDouble() * pi * 2;
      final rad = 0.34 + rnd.nextDouble() * 0.60;
      final x = c.dx + cos(ang) * rx * rad;
      final y = c.dy + sin(ang) * ry * rad;
      var tooClose = false;
      for (final l in levels) {
        if ((Offset(l.x, l.y) - Offset(x, y)).distance < 54) {
          tooClose = true;
          break;
        }
      }
      if (tooClose) continue;
      decos.add(MapDeco(
        kind: rnd.nextInt(6),
        x: x,
        y: y,
        size: 20 + rnd.nextDouble() * 12,
      ));
    }
    // 山顶和岛边固定几个大件
    decos.add(MapDeco(kind: 0, x: c.dx - w * 0.22, y: c.dy - ry * 0.60, size: 30));
    decos.add(MapDeco(kind: 0, x: c.dx + w * 0.20, y: c.dy - ry * 0.44, size: 28));
    decos.add(MapDeco(kind: 1, x: c.dx + w * 0.10, y: c.dy + ry * 0.66, size: 28));
    decos.add(MapDeco(kind: 4, x: c.dx - w * 0.30, y: c.dy + ry * 0.42, size: 24));
    decos.add(MapDeco(kind: 5, x: c.dx + w * 0.30, y: c.dy - ry * 0.06, size: 22));

    var curIdx = levels.indexWhere((l) => l.current);
    if (curIdx < 0) curIdx = 0;

    return MapLayout(
      width: w,
      height: h,
      levels: levels,
      signs: signs,
      decos: decos,
      houses: houses,
      trail: trail,
      currentIndex: curIdx,
      currentY: levels[curIdx].y,
      unitIndex: ui,
      unitCount: units.length,
    );
  }

  /// 整条岛链上一共有几关（给标题显示用）
  static int totalLevels(List<Unit> units) {
    var n = 0;
    for (final u in units) {
      n += u.lessons.length * 3;
    }
    return n;
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

class _IslandMapState extends State<IslandMap> {
  /// null = 跟着现在的进度走；点了左右箭头（或左右滑）就临时翻到别的岛
  int? _browse;

  void _switchTo(int next, int unitCount) {
    if (next < 0 || next >= unitCount) return;
    setState(() => _browse = next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final layout =
          MapLayout.build(size, units, widget.store, unitIndex: _browse);

      final mapStack = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _WorldPainter(layout: layout)),
            ),
          ),
          for (final s in layout.signs) _signPost(s),
          for (final h in layout.houses) _petHouse(h),
          for (final l in layout.levels) _levelNode(l),
        ],
      );

      return Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _Backdrop())),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -120) _switchTo(layout.unitIndex + 1, layout.unitCount);
                if (v > 120) _switchTo(layout.unitIndex - 1, layout.unitCount);
              },
              onVerticalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -120) _switchTo(layout.unitIndex + 1, layout.unitCount);
                if (v > 120) _switchTo(layout.unitIndex - 1, layout.unitCount);
              },
              // 整座岛做一点透视：看起来是斜着从海面上鼓起来的
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0009)
                  ..rotateX(-0.20)
                  ..scaleByDouble(1.06, 1.06, 1.06, 1),
                child: mapStack,
              ),
            ),
          ),
          Positioned(left: 0, right: 0, top: 0, child: _islandBar(layout)),
          if (_browse != null)
            Positioned(
              right: 14,
              bottom: widget.bottomInset,
              child: GestureDetector(
                onTap: () => setState(() => _browse = null),
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
              ),
            ),
        ],
      );
    });
  }

  /// 岛顶上的标题条：第几座岛 · 名字，两边可以翻岛
  Widget _islandBar(MapLayout layout) {
    final unit = units[layout.unitIndex];
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, left: 10, right: 10),
        child: Row(
          children: [
            _arrow(
              '◀',
              layout.unitIndex > 0,
              () => _switchTo(layout.unitIndex - 1, layout.unitCount),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFC08A55), Color(0xFF9A6535)],
                    ),
                    borderRadius: BorderRadius.circular(16),
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
                      Text(unit.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '第 ${layout.unitIndex + 1}/${layout.unitCount} 座岛 · '
                          '${unit.title}',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _arrow(
              '▶',
              layout.unitIndex < layout.unitCount - 1,
              () => _switchTo(layout.unitIndex + 1, layout.unitCount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arrow(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: enabled ? 0.92 : 0.45),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: enabled ? const Color(0xFF6F4520) : const Color(0xFFB9B2A6),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _signPost(MapSign s) {
    return Positioned(
      left: s.x - 120,
      top: s.y - 30,
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

  Widget _petHouse(MapPetHouse h) {
    final sp = petSpeciesOf(h.speciesId);
    return Positioned(
      left: h.x - 60,
      top: h.y - 58,
      width: 120,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPetHouseTap,
        child: Transform.scale(
          scale: 0.84,
          child: _PetHouseNode(species: sp, owned: h.owned, next: h.next),
        ),
      ),
    );
  }

  Widget _levelNode(MapLevel l) {
    Widget pedestal = _LevelPedestal(level: l);
    if (l.current) {
      pedestal = _Bob(child: pedestal);
    }
    return Positioned(
      left: l.x - 46,
      top: l.y - 32,
      width: 92,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onStartLevel(l),
        // 一屏要摆下 6~12 关，台阶画小一点才不会挤在一起
        child: Transform.scale(scale: 0.72, child: pedestal),
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

  const _WorldPainter({required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    final c = MapLayout.islandCenter(size);
    final rx = MapLayout.islandWidth(size) / 2;
    final ry = MapLayout.islandHeight(size) / 2;

    Rect ell(double s) =>
        Rect.fromCenter(center: c, width: rx * 2 * s, height: ry * 2 * s);

    // 海水下的影子
    canvas.save();
    canvas.translate(10, 26);
    canvas.drawOval(
      ell(1.0),
      Paint()..color = const Color(0xFF2C7FAE).withValues(alpha: 0.18),
    );
    canvas.restore();

    // 岛外面两圈白浪
    for (var i = 1; i >= 0; i--) {
      canvas.drawOval(
        ell(1.06 + i * 0.05),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = Colors.white.withValues(alpha: i == 0 ? 0.5 : 0.26),
      );
    }

    // 礁石带
    canvas.drawOval(
      ell(1.0),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC4CFD8), Color(0xFF9DAAB7)],
        ).createShader(ell(1.0)),
    );

    // 岛的厚度：往左下挤一点，像一块从海里长出来的岛
    canvas.save();
    canvas.translate(-9, 15);
    canvas.drawOval(
      ell(0.945),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDBB80), Color(0xFFB78C51)],
        ).createShader(ell(1.0)),
    );
    canvas.restore();

    // 沙滩
    canvas.drawOval(
      ell(0.945),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF4DA), Color(0xFFF3DEB1)],
        ).createShader(ell(1.0)),
    );

    // 草地（圆鼓鼓的一大块）
    final grass = ell(0.85);
    canvas.drawOval(
      grass,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.18, -0.28),
          radius: 0.95,
          colors: [Color(0xFFCEF0A7), Color(0xFFA3DC80), Color(0xFF7EC565)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(grass),
    );
    canvas.drawOval(
      grass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Color(0xFFE6F9CB).withValues(alpha: 0.85),
    );

    // 山体上的一道高光（让圆岛看起来是鼓起来的）
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - rx * 0.16, c.dy - ry * 0.30),
        width: rx * 0.95,
        height: ry * 0.72,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCenter(
          center: Offset(c.dx - rx * 0.16, c.dy - ry * 0.30),
          width: rx * 0.95,
          height: ry * 0.72,
        )),
    );

    // 草地上的小草簇（固定随机，不闪烁）
    final rnd = Random(layout.unitIndex * 97 + 5);
    for (var i = 0; i < 96; i++) {
      final ang = rnd.nextDouble() * pi * 2;
      final rad = 0.16 + rnd.nextDouble() * 0.66;
      final x = c.dx + cos(ang) * rx * 0.85 * rad;
      final y = c.dy + sin(ang) * ry * 0.85 * rad;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 12, height: 5),
        Paint()..color = const Color(0xFF95D378).withValues(alpha: 0.5),
      );
    }

    // 岸边一块块礁石
    final rnd2 = Random(layout.unitIndex * 31 + 9);
    for (var i = 0; i < 26; i++) {
      final ang = rnd2.nextDouble() * pi * 2;
      final rad = 0.965 + rnd2.nextDouble() * 0.03;
      final x = c.dx + cos(ang) * rx * rad;
      final y = c.dy + sin(ang) * ry * rad;
      final rr = 7.0 + rnd2.nextDouble() * 5;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y + 4), width: rr * 2.3, height: rr * 1.4),
        Paint()..color = const Color(0xFFAFBAC4),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x - 2, y - 2), width: rr * 1.5, height: rr * 0.95),
        Paint()..color = const Color(0xFFD2DAE2),
      );
    }

    _paintTrail(canvas);
    // 山顶的灯塔（在最后一关上方，岛的最高处）
    _paintLighthouse(canvas, c.dx, c.dy - ry * 0.88);
    _paintDecos(canvas);
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

  void _paintDecos(Canvas canvas) {
    // 一屏装得下一整座岛，所以装饰全画（数量本来就不多）
    final visible = layout.decos.toList()
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
      old.layout.unitIndex != layout.unitIndex ||
      old.layout.levels.length != layout.levels.length ||
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
