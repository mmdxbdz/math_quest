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
  final double x; // 投影到屏幕后的位置
  final double y;
  final int stars;
  final bool unlocked;
  final bool current;

  /// 离镜头多远（世界单位）：越大越远
  final double depth;

  /// 台阶在屏幕上缩小到多大（1.0 = 原始 92px 宽）
  final double scale;

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
    required this.depth,
    required this.scale,
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
        depth: depth,
        scale: scale,
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
  final double depth;
  final double scale;

  const MapSign({
    required this.unit,
    required this.x,
    required this.y,
    required this.done,
    required this.total,
    required this.firstLevel,
    required this.lastLevel,
    this.depth = 1,
    this.scale = 1,
  });
}

/// 路边的立体小物件：0 椰子树 / 1 小屋 / 2 灌木 / 3 石头 / 4 珊瑚 / 5 贝壳 / 6 灯塔
class MapDeco {
  final int kind;
  final double x;
  final double y;
  final double size;
  final double depth;

  const MapDeco({
    required this.kind,
    required this.x,
    required this.y,
    required this.size,
    this.depth = 1,
  });
}

/// 路边的宠物房：开在"刚好看满 N 关"的那一关后面，
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
  final double depth;
  final double scale;

  const MapPetHouse({
    required this.speciesId,
    required this.x,
    required this.y,
    required this.order,
    required this.owned,
    this.next = false,
    this.depth = 1,
    this.scale = 1,
  });
}

// ─────────────────────────────────────────────────────────────
// 布局：一条往远处（山上）延伸的路，用真透视投影算位置。
//   镜头站在路上 s = cam 的地方往远处看：
//   距离 d 处的东西 → 屏幕 y = 地平线 + f*镜头高/d，
//   横向 x = 屏幕中心 + f*横向偏移/d，缩放大 scale = f/d。
//   于是越远越小、越远越靠中间，路自然收敛到地平线——真 3D 透视。
// ─────────────────────────────────────────────────────────────

class MapLayout {
  final double width;
  final double height;
  final List<MapLevel> levels;
  final List<MapSign> signs;
  final List<MapDeco> decos;
  final List<MapPetHouse> houses;
  final int currentIndex;
  final double currentY;

  /// 镜头站在路上哪儿（世界单位，0 = 第 1 关脚下）
  final double cam;

  /// 地平线在屏幕上多高
  final double horizonY;

  /// 路一共多长（世界单位）
  final double roadLength;

  const MapLayout({
    required this.width,
    required this.height,
    required this.levels,
    required this.signs,
    required this.decos,
    required this.houses,
    required this.currentIndex,
    required this.currentY,
    required this.cam,
    required this.horizonY,
    required this.roadLength,
  });

  // ── 3D 相机参数（想调镜头感就动这几个数）
  static const double focal = 900; // 焦距：越大越"长焦"，远处收敛越慢
  static const double camHeight = 1.55; // 镜头离地多高（世界单位）
  static const double levelStep = 2.4; // 一关和一关隔多远
  static const double roadHalf = 0.62; // 路宽的一半（世界单位）
  static const double nearClip = 0.7; // 比这更近就贴脸了，不画

  static double horizonOf(double h) => h * 0.30;

  /// 距离 d 处的地面在屏幕上的 y
  static double projectY(double d, double h) =>
      horizonOf(h) + focal * camHeight / max(d, nearClip);

  /// 距离 d、横向偏移 lat 的点在屏幕上的 x
  static double projectX(double lat, double d, double w) =>
      w / 2 + focal * lat / max(d, nearClip);

  /// 距离 d 处的比例（世界 1 单位 = 多少像素）
  static double scaleOf(double d) => focal / max(d, nearClip);

  /// 路在 s 处的横向弯曲
  static double latAt(double s) => 0.30 * sin(s * 0.34);

  /// 屏幕上这一行离镜头多远（画地面用）
  static double distanceAtY(double y, double h) =>
      focal * camHeight / max(y - horizonOf(h), 1.0);

  /// 所有关卡排成一条路，一屏能看见远近十来关
  factory MapLayout.build(Size size, List<Unit> units, ProgressStore store,
      {double? cam}) {
    final w = size.width;
    final h = size.height;

    var levelTotal = 0;
    for (final u in units) {
      levelTotal += u.lessons.length * 3;
    }
    final houseCount = min(
      kPetSpecies.length - 1,
      levelTotal ~/ kPetUnlockEveryLevels,
    );
    final ownedSpecies = store.pets.map((p) => p.speciesId).toSet();

    // ① 先在路上排好每一关、木牌、宠物房的位置（世界单位 s）
    final levels = <MapLevel>[];
    final signs = <MapSign>[];
    final houses = <MapPetHouse>[];

    var s = 0.0;
    var idx = 0;
    var houseIdx = 0;
    for (final unit in units) {
      final firstLevel = idx + 1;
      final signS = s - 1.7;
      var unitDone = 0;
      final unitTotal = unit.lessons.length * 3;

      for (final lesson in unit.lessons) {
        for (var stage = 0; stage < 3; stage++) {
          final stars = store.stageStars(lesson.id, stage);
          levels.add(MapLevel(
            lesson: lesson,
            stage: stage,
            key: '${lesson.id}:s$stage',
            index: idx,
            x: 0,
            y: 0,
            stars: stars,
            unlocked: store.levelUnlocked(orderedLevelKeys, idx),
            current: false,
            depth: s,
            scale: 1,
          ));
          if (stars > 0) unitDone++;
          s += levelStep;
          idx++;
          // 每满 6 关：在两关之间开一间宠物房
          if (idx % kPetUnlockEveryLevels == 0 && houseIdx < houseCount) {
            final sp = petSpeciesOf(kPetUnlockOrder[houseIdx + 1]);
            houses.add(MapPetHouse(
              speciesId: sp.id,
              x: 0,
              y: 0,
              order: houseIdx + 1,
              owned: ownedSpecies.contains(sp.id),
              depth: s - levelStep * 0.5,
            ));
            houseIdx++;
          }
        }
      }

      signs.add(MapSign(
        unit: unit,
        x: 0,
        y: 0,
        done: unitDone,
        total: unitTotal,
        firstLevel: firstLevel,
        lastLevel: idx,
        depth: signS,
      ));
      s += 1.2; // 两个主题之间留一点空
    }
    final roadLength = s;

    // ② 镜头：默认站在"现在这一关"前面几格
    var currentIdx = levels.indexWhere((l) => l.unlocked && l.stars == 0);
    if (currentIdx < 0) {
      currentIdx = levels.indexWhere((l) => l.unlocked);
      if (currentIdx < 0) currentIdx = 0;
    }
    final camS = cam ?? (levels[currentIdx].depth - 4.2);

    // ③ 投影到屏幕
    final projLevels = <MapLevel>[];
    for (final l in levels) {
      final d = l.depth - camS;
      final lat = latAt(l.depth);
      projLevels.add(MapLevel(
        lesson: l.lesson,
        stage: l.stage,
        key: l.key,
        index: l.index,
        x: projectX(lat + (l.index.isEven ? -0.34 : 0.34), d, w),
        y: projectY(d, h),
        stars: l.stars,
        unlocked: l.unlocked,
        current: l.index == currentIdx,
        depth: d,
        scale: scaleOf(d) * 0.34 / 92.0,
      ));
    }

    final projSigns = <MapSign>[];
    for (final sg in signs) {
      final d = sg.depth - camS;
      projSigns.add(MapSign(
        unit: sg.unit,
        x: projectX(latAt(sg.depth), d, w),
        y: projectY(d, h),
        done: sg.done,
        total: sg.total,
        firstLevel: sg.firstLevel,
        lastLevel: sg.lastLevel,
        depth: d,
        scale: scaleOf(d) * 1.45 / 240.0,
      ));
    }

    final projHouses = <MapPetHouse>[];
    for (final ph in houses) {
      final d = ph.depth - camS;
      projHouses.add(MapPetHouse(
        speciesId: ph.speciesId,
        x: projectX(latAt(ph.depth) + 1.55, d, w),
        y: projectY(d, h),
        order: ph.order,
        owned: ph.owned,
        depth: d,
        scale: scaleOf(d) * 0.95 / 120.0,
      ));
    }
    final nextHouse = projHouses.indexWhere((hh) => !hh.owned);
    if (nextHouse >= 0) {
      final hh = projHouses[nextHouse];
      projHouses[nextHouse] = MapPetHouse(
        speciesId: hh.speciesId,
        x: hh.x,
        y: hh.y,
        order: hh.order,
        owned: hh.owned,
        next: true,
        depth: hh.depth,
        scale: hh.scale,
      );
    }

    // ④ 路边的小物件：固定随机，位置在世界坐标里，再投影
    final rnd = Random(11);
    final decos = <MapDeco>[];
    for (var i = 0; i < 170; i++) {
      final ds = rnd.nextDouble() * (roadLength + 26) - 10;
      final side = rnd.nextBool() ? 1.0 : -1.0;
      final lat = side * (0.85 + rnd.nextDouble() * 2.9);
      final worldSize = 0.26 + rnd.nextDouble() * 0.34;
      final d = ds - camS;
      if (d < nearClip) continue;
      decos.add(MapDeco(
        kind: rnd.nextInt(6),
        x: projectX(latAt(ds) + lat, d, w),
        y: projectY(d, h),
        size: scaleOf(d) * worldSize,
        depth: d,
      ));
    }
    // 山顶的灯塔：走到最后几关，它就从小变大
    final lhS = roadLength + 3.2;
    final dLh = lhS - camS;
    if (dLh > nearClip) {
      decos.add(MapDeco(
        kind: 6,
        x: projectX(latAt(lhS), dLh, w),
        y: projectY(dLh, h),
        size: scaleOf(dLh) * 1.6,
        depth: dLh,
      ));
    }

    return MapLayout(
      width: w,
      height: h,
      levels: projLevels,
      signs: projSigns,
      decos: decos,
      houses: projHouses,
      currentIndex: currentIdx,
      currentY: projLevels[currentIdx].y,
      cam: camS,
      horizonY: horizonOf(h),
      roadLength: roadLength,
    );
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
  /// 镜头站在路上的位置（世界单位）。越大 = 越往前（往山上）走。
  double _cam = 0;
  double _roadLength = 0;
  bool _inited = false;
  static const double _dragScale = 0.021; // 手指拖 1px ≈ 往前挪多少世界单位

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

  double get _minCam => -10.0;
  double get _maxCam => _roadLength + 2.0;

  @override
  void dispose() {
    _fling.dispose();
    super.dispose();
  }

  /// 画面跟着手指走：手指往下扒拉 = 往前走，上面的关就一节节下来
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

  /// 一键回到"现在这一关"前面
  void _focusCurrent(MapLayout layout) {
    final target = (_cam + layout.levels[layout.currentIndex].depth - 4.2)
        .clamp(_minCam, _maxCam);
    _fling.stop();
    _fling.value = _cam;
    _fling.animateTo(
      target,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final layout = MapLayout.build(
        size,
        units,
        widget.store,
        cam: _inited ? _cam : null,
      );
      if (!_inited) {
        _inited = true;
        _cam = layout.cam;
      }
      _roadLength = layout.roadLength;

      final mapStack = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _WorldPainter(layout: layout)),
            ),
          ),
          for (final s in _farToNear(layout.signs)) _signPost(s),
          for (final h in _farToNear(layout.houses)) _petHouse(h),
          for (final l in _farToNear(layout.levels)) _levelNode(l),
        ],
      );

      return Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: _Backdrop())),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _fling.stop(),
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: mapStack,
            ),
          ),
          Positioned(
            right: 14,
            bottom: widget.bottomInset,
            child: _locateButton(layout),
          ),
        ],
      );
    });
  }

  /// 远的先画、近的后画（3D 的遮挡顺序）
  List<T> _farToNear<T>(List<T> items) {
    final list = <T>[];
    for (final e in items) {
      final d = _depthOf(e);
      final y = _yOf(e);
      if (d > MapLayout.nearClip && y < 2200) list.add(e);
    }
    list.sort((a, b) => _depthOf(b).compareTo(_depthOf(a)));
    return list;
  }

  double _depthOf(dynamic o) {
    if (o is MapLevel) return o.depth;
    if (o is MapSign) return o.depth;
    if (o is MapPetHouse) return o.depth;
    return 1;
  }

  double _yOf(dynamic o) {
    if (o is MapLevel) return o.y;
    if (o is MapSign) return o.y;
    if (o is MapPetHouse) return o.y;
    return 0;
  }

  Widget _locateButton(MapLayout layout) {
    return GestureDetector(
      onTap: () => _focusCurrent(layout),
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

  Widget _signPost(MapSign s) {
    final fade = _fadeFor(s.depth);
    if (fade <= 0) return const SizedBox.shrink();
    return Positioned(
      left: s.x - 120,
      top: s.y - 30,
      width: 240,
      height: 60,
      child: Opacity(
        opacity: fade,
        child: Transform.scale(
          scale: s.scale.clamp(0.22, 1.5),
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
      ),
    ),
    );
  }

  Widget _petHouse(MapPetHouse h) {
    final fade = _fadeFor(h.depth);
    if (fade <= 0) return const SizedBox.shrink();
    final sp = petSpeciesOf(h.speciesId);
    return Positioned(
      left: h.x - 60,
      top: h.y - 58,
      width: 120,
      child: Opacity(
        opacity: fade,
        child: Transform.scale(
          scale: h.scale.clamp(0.24, 1.5),
          alignment: Alignment.topCenter,
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
            onTap: widget.onPetHouseTap,
            child: _PetHouseNode(species: sp, owned: h.owned, next: h.next),
          ),
        ),
      ),
    );
  }

  /// 太远的东西就淡出（消失在雾里），别挤成一串
  double _fadeFor(double depth) {
    if (depth > 21) return 0;
    if (depth <= 13) return 1;
    return 1 - (depth - 13) / 8 * 0.85;
  }
  Widget _levelNode(MapLevel l) {
    final fade = _fadeFor(l.depth);
    if (fade <= 0) return const SizedBox.shrink();
    final k = l.scale.clamp(0.12, 2.0);
    Widget pedestal = _LevelPedestal(level: l);
    if (l.current) {
      pedestal = _Bob(child: pedestal);
    }
    return Positioned(
      left: l.x - 46,
      // 台阶的圆心落在投影出来的那个点上
      top: l.y - 40 * k,
      width: 92,
      height: 110,
      child: Opacity(
        opacity: fade,
        child: Transform.scale(
          scale: k,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onStartLevel(l),
            child: pedestal,
          ),
        ),
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
    final w = size.width;
    final h = size.height;
    final horizon = layout.horizonY;

    // ── 远处的海（地平线下面一条窄窄的水带，靠云和雾跟草地接上）
    final seaRect = Rect.fromLTWH(0, horizon, w, h * 0.075);
    canvas.drawRect(
      seaRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9FE4E1), Color(0xFF62C8D0)],
        ).createShader(seaRect),
    );

    // ── 地面：草地从地平线一直铺到脚下
    final groundRect = Rect.fromLTWH(0, horizon + 4, w, h - horizon);
    canvas.drawRect(
      groundRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFB6E893),
            Color(0xFF95D672),
            Color(0xFF6FC050),
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(groundRect),
    );

    // ── 沿着 3D 透视的小路（土路肩 + 石板路面 + 石板缝）
    _paintRoad(canvas, w, h);

    // ── 草地上按透视铺的小草簇
    _paintGrassDetail(canvas, w, h);

    // ── 路边的彩色鹅卵石
    _paintPebbles(canvas, w, h);

    // ── 台阶 / 房子落在地上的接触阴影
    _paintContactShadows(canvas);

    // ── 路边的小物件 + 山顶灯塔（远的先画，近的后画）
    _paintDecos(canvas, horizon);

    // ── 地平线附近的雾和云：远处的路"还没从云雾里长出来"
    _paintHorizon(canvas, w, h);
  }

  /// 按透视采样每一行屏幕，画出路的梯形
  Path _bandPath(double w, double h, double halfWorld, double lat0) {
    final left = <Offset>[];
    final right = <Offset>[];
    for (var y = h + 40; y >= layout.horizonY + 3; y -= 4) {
      final d = MapLayout.distanceAtY(y, h);
      final s = layout.cam + d;
      final latc = MapLayout.latAt(s) + lat0;
      final halfPx = MapLayout.focal * halfWorld / d;
      final centerPx = w / 2 + MapLayout.focal * latc / d;
      left.add(Offset(centerPx - halfPx, y));
      right.add(Offset(centerPx + halfPx, y));
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  void _paintRoad(Canvas canvas, double w, double h) {
    // 土路肩
    canvas.drawPath(
      _bandPath(w, h, MapLayout.roadHalf * 1.18, 0),
      Paint()..color = const Color(0xFFE3D3AC),
    );
    // 石板路面
    final road = _bandPath(w, h, MapLayout.roadHalf, 0);
    canvas.drawPath(
      road,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFE7D2), Color(0xFFFBF7EC), Color(0xFFEDE4CE)],
          stops: [0.0, 0.55, 1.0],
        )
            .createShader(Rect.fromLTWH(0, layout.horizonY, w, h - layout.horizonY)),
    );
    // 两边压暗：一条路鼓起来的边
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFFB39B6E).withValues(alpha: 0.55),
    );

    // 一道高光，让路看着是鼓起来的
    canvas.save();
    canvas.translate(-3, -2);
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFFDF6).withValues(alpha: 0.75),
    );
    canvas.restore();

    // 横向石缝：按世界距离均分，越远越密（透视自然产生）
    final seam = Paint()
      ..color = const Color(0xFFBFB197).withValues(alpha: 0.62)
      ..strokeWidth = 2.0;
    for (var i = 0; i < 240; i++) {
      final s = i * 0.55;
      final d = s - layout.cam;
      if (d < 1.2 || d > 46) continue;
      final y = MapLayout.projectY(d, h);
      if (y > h + 20) continue;
      final latc = MapLayout.latAt(s);
      final halfPx = MapLayout.focal * MapLayout.roadHalf * 0.94 / d;
      final centerPx = w / 2 + MapLayout.focal * latc / d;
      canvas.drawLine(
        Offset(centerPx - halfPx, y),
        Offset(centerPx + halfPx, y),
        seam,
      );
    }
  }

  /// 路边一圈彩色鹅卵石：近处的看得清，远处缩成小点
  void _paintPebbles(Canvas canvas, double w, double h) {
    const colors = [
      Color(0xFFF4A7BC),
      Color(0xFF93D6F2),
      Color(0xFFF8D97B),
      Color(0xFFBFE7A1),
      Color(0xFFE5A9E3),
      Color(0xFFFFC79A),
    ];
    for (var i = 0; i < 520; i++) {
      final s = i * 0.30;
      final d = s - layout.cam;
      if (d < 1.0 || d > 20) continue;
      final y = MapLayout.projectY(d, h);
      if (y > h + 24) continue;
      final latc = MapLayout.latAt(s);
      final k = MapLayout.focal / d;
      for (final side in const [-1.0, 1.0]) {
        final latp = latc + side * (MapLayout.roadHalf + 0.055);
        final px = w / 2 + MapLayout.focal * latp / d;
        final r = k * 0.042;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(px, y), width: r * 2.1, height: r * 1.4),
          Paint()..color = colors[(i + (side > 0 ? 3 : 0)) % colors.length],
        );
      }
    }
  }

  /// 台阶和房子在地上的接触阴影：一下子就有"站在地上"的重量感
  void _paintContactShadows(Canvas canvas) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.11);
    for (final l in layout.levels) {
      if (l.depth < 1.0 || l.depth > 20) continue;
      final wpx = 92 * l.scale * 1.2;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(l.x, l.y + 2 * l.scale * 40),
            width: wpx,
            height: wpx * 0.30),
        paint,
      );
    }
    for (final hh in layout.houses) {
      if (hh.depth < 1.0 || hh.depth > 20) continue;
      final wpx = 120 * hh.scale * 1.15;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(hh.x, hh.y + 4),
            width: wpx,
            height: wpx * 0.28),
        paint,
      );
    }
  }
  /// 草地上按世界坐标散布的草簇（近大远小）
  void _paintGrassDetail(Canvas canvas, double w, double h) {
    final rnd = Random(29);
    for (var i = 0; i < 260; i++) {
      final ds = rnd.nextDouble() * (layout.roadLength + 26) - 10;
      final side = rnd.nextBool() ? 1.0 : -1.0;
      final lat = side * (0.78 + rnd.nextDouble() * 3.4);
      final d = ds - layout.cam;
      if (d < 1.2) continue;
      final y = MapLayout.projectY(d, h);
      if (y > h + 30 || y < layout.horizonY + 6) continue;
      final px = MapLayout.projectX(MapLayout.latAt(ds) + lat, d, w);
      final k = MapLayout.focal / d;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, y), width: k * 0.10, height: k * 0.045),
        Paint()..color = const Color(0xFF8FD073).withValues(alpha: 0.55),
      );
    }
  }

  /// 地平线：白白的雾 + 一排胖云，远处的路就消失在里头
  void _paintHorizon(Canvas canvas, double w, double h) {
    final horizon = layout.horizonY;
    final fogRect = Rect.fromLTWH(0, horizon - 6, w, h * 0.13);
    canvas.drawRect(
      fogRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6FDFF), Color(0x00F6FDFF)],
        ).createShader(fogRect),
    );

    final crnd = Random(7);
    for (var i = 0; i < 8; i++) {
      final cxx = -20 + (i / 7) * (w + 40) + (crnd.nextDouble() - 0.5) * 24;
      final cyy = horizon - 10 + (crnd.nextDouble() - 0.5) * 18;
      final rw = 78.0 + crnd.nextDouble() * 62;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cxx, cyy), width: rw, height: rw * 0.42),
        Paint()..color = const Color(0xFFF8FEFF).withValues(alpha: 0.95),
      );
    }
  }

  /// 山顶的灯塔按世界比例缩放
  void _paintLighthouseScaled(Canvas canvas, double x, double baseY, double k) {
    canvas.save();
    canvas.translate(x, baseY);
    canvas.scale(k);
    _paintLighthouse(canvas, 0, 0);
    canvas.restore();
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
        case 6: // 山顶灯塔
          _paintLighthouseScaled(canvas, d.x, d.y, d.size / 143.0);
          break;
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
      old.layout.cam != layout.cam ||
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
