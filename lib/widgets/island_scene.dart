import 'dart:math';
import 'package:flutter/material.dart';
import '../content/curriculum.dart';
import '../models.dart';
import '../pets.dart';
import '../store.dart';
import '../three_d.dart';

// ─────────────────────────────────────────────────────────────
// 一座真的 3D 岛：地形、蜿蜒的石板路、路边椰子树/小屋/珊瑚，
// 还有按宠物口味做的 3D 关卡（北极熊是鱼、小狗是肉骨头……）。
// 全部是顶点 + 面，交给 three_d 的渲染管线算光照、透视、雾。
// ─────────────────────────────────────────────────────────────

/// 关卡的 3D 造型（跟着现在陪她玩的那只宠物换）
String foodKindOf(String? speciesId) {
  switch (speciesId) {
    case 'cat':
    case 'polar':
      return 'fish';
    case 'dog':
      return 'bone';
    case 'rabbit':
      return 'carrot';
    case 'bear':
      return 'honey';
    case 'panda':
      return 'bamboo';
    case 'fox':
      return 'grape';
    case 'pig':
      return 'corn';
    case 'frog':
      return 'bug';
  }
  return 'fish';
}

/// 屏幕上的一关
class SceneMarker {
  final int index;
  final double depth;
  final Lesson lesson;
  final int stage;
  final String key;
  final bool unlocked;
  final double x;
  final double y;
  final double px;
  final int stars;
  final bool locked;
  final bool current;
  final bool done;
  const SceneMarker({
    required this.index,
    required this.depth,
    required this.lesson,
    required this.stage,
    required this.key,
    required this.unlocked,
    required this.x,
    required this.y,
    required this.px,
    required this.stars,
    required this.locked,
    required this.current,
    required this.done,
  });
}

class SceneSign {
  final Unit unit;
  final int done;
  final int total;
  final int firstLevel;
  final int lastLevel;
  final double x;
  final double y;
  final double px;
  final double depth;
  const SceneSign({
    required this.unit,
    required this.done,
    required this.total,
    required this.firstLevel,
    required this.lastLevel,
    required this.x,
    required this.y,
    required this.px,
    required this.depth,
  });
}

class SceneHouse {
  final String speciesId;
  final int order;
  final bool owned;
  final bool next;
  final double x;
  final double y;
  final double px;
  final double depth;
  const SceneHouse({
    required this.speciesId,
    required this.order,
    required this.owned,
    required this.next,
    required this.x,
    required this.y,
    required this.px,
    required this.depth,
  });
}

class IslandScene {
  final List<Face3D> faces;
  final List<SceneMarker> markers;
  final List<SceneSign> signs;
  final List<SceneHouse> houses;
  final double cam;
  final double horizonY;
  final double roadLength;
  final int currentIndex;
  final Camera3D camera;

  const IslandScene({
    required this.faces,
    required this.markers,
    required this.signs,
    required this.houses,
    required this.cam,
    required this.horizonY,
    required this.roadLength,
    required this.currentIndex,
    required this.camera,
  });

  static const double levelStep = 2.4;
  static const double roadHalf = 0.72;

  /// 路中心线：往远处慢慢绕
  static double roadX(double s) => 1.15 * sin(s * 0.155);

  /// 路往山上爬：越远越高
  static double roadY(double s) => 0.055 * s;

  /// 路两边起伏的山坡
  static double hillY(double s, double u) {
    final d = u.abs() - roadHalf;
    if (d <= 0) return roadY(s);
    final rise = 0.30 * pow(d, 1.12).toDouble();
    final wob = 0.62 + 0.38 * sin(u * 0.9 + s * 0.36) * cos(s * 0.19 + u * 0.5);
    return roadY(s) + rise * wob;
  }

  static V3 pointOn(double s, double u) => V3(roadX(s) + u, hillY(s, u), s);

  /// 造景：地形 + 石板路 + 小物件 + 3D 关卡
  static IslandScene build({
    required Size size,
    required List<Unit> units,
    required ProgressStore store,
    required String foodKind,
    double? cam,
  }) {
    var s = 0.0;
    var idx = 0;
    var houseIdx = 0;
    var currentIdx = -1;
    final levels = <_Lvl>[];
    final worldSigns = <_Sign>[];
    final worldHouses = <_House>[];
    final houseCount = min(
      kPetSpecies.length - 1,
      orderedLevelKeys.length ~/ kPetUnlockEveryLevels,
    );
    final ownedSpecies = store.pets.map((p) => p.speciesId).toSet();

    for (final unit in units) {
      final signS = max(s - 1.9, 1.2);
      var unitDone = 0;
      final firstLevel = idx + 1;
      for (final lesson in unit.lessons) {
        for (var stage = 0; stage < 3; stage++) {
          final stars = store.stageStars(lesson.id, stage);
          final unlocked = store.levelUnlocked(orderedLevelKeys, idx);
          if (currentIdx < 0 && unlocked && stars == 0) currentIdx = idx;
          levels.add(_Lvl(
            index: idx,
            lesson: lesson,
            stage: stage,
            key: lesson.id + ':s' + stage.toString(),
            s: s,
            stars: stars,
            locked: !unlocked,
            done: stars > 0,
          ));
          if (stars > 0) unitDone++;
          s += levelStep;
          idx++;
          if (idx % kPetUnlockEveryLevels == 0 && houseIdx < houseCount) {
            final sp = petSpeciesOf(kPetUnlockOrder[houseIdx + 1]);
            worldHouses.add(_House(
              speciesId: sp.id,
              order: houseIdx + 1,
              owned: ownedSpecies.contains(sp.id),
              s: s - levelStep * 0.5,
            ));
            houseIdx++;
          }
        }
      }
      worldSigns.add(_Sign(
        unit: unit,
        done: unitDone,
        total: unit.lessons.length * 3,
        firstLevel: firstLevel,
        lastLevel: idx,
        s: signS,
      ));
      s += 1.4;
    }
    if (currentIdx < 0) {
      currentIdx = levels.indexWhere((l) => !l.locked);
      if (currentIdx < 0) currentIdx = 0;
    }
    final roadLength = s;

    // 相机站在路上
    final camS = cam ?? (levels[currentIdx].s - 4.3);
    final camera = Camera3D(
      pos: V3(roadX(camS), roadY(camS) + 1.62, camS),
      size: size,
    );

    final faces = <Face3D>[];

    // ── 地形：一条条横截面拼出来的山坡
    const latU = [
      -12.0,
      -6.2,
      -3.2,
      -1.6,
      -roadHalf - 0.05,
      roadHalf + 0.05,
      1.6,
      3.2,
      6.2,
      12.0
    ];
    final rows = <double>[];
    for (var ss = camS - 6; ss <= camS + 34; ss += 0.85) {
      rows.add(ss);
    }
    const grassA = Color(0xFFA6E178);
    const grassB = Color(0xFF92D667);
    for (var r = 0; r < rows.length - 1; r++) {
      final s0 = rows[r];
      final s1 = rows[r + 1];
      for (var c = 0; c < latU.length - 1; c++) {
        final u0 = latU[c];
        final u1 = latU[c + 1];
        if (u0 >= -roadHalf - 0.06 && u1 <= roadHalf + 0.06) continue;
        faces.add(quad3(
          pointOn(s0, u0),
          pointOn(s0, u1),
          pointOn(s1, u1),
          pointOn(s1, u0),
          (r + c).isEven ? grassA : grassB,
        ));
      }
    }

    // ── 石板路 + 路沿
    for (var r = 0; r < rows.length - 1; r++) {
      final s0 = rows[r];
      final s1 = rows[r + 1];
      final tile = (s0 / 1.1).floor().isEven;
      faces.add(quad3(
        V3(roadX(s0) - roadHalf, roadY(s0) + 0.012, s0),
        V3(roadX(s0) + roadHalf, roadY(s0) + 0.012, s0),
        V3(roadX(s1) + roadHalf, roadY(s1) + 0.012, s1),
        V3(roadX(s1) - roadHalf, roadY(s1) + 0.012, s1),
        tile ? const Color(0xFFFFF7DE) : const Color(0xFFF2E3BE),
      ));
      for (final side in const [-1.0, 1.0]) {
        final u0 = side * roadHalf;
        final u1 = side * (roadHalf + 0.17);
        faces.add(quad3(
          V3(roadX(s0) + u0, roadY(s0) + 0.010, s0),
          V3(roadX(s0) + u1, hillY(s0, u1) + 0.006, s0),
          V3(roadX(s1) + u1, hillY(s1, u1) + 0.006, s1),
          V3(roadX(s1) + u0, roadY(s1) + 0.010, s1),
          const Color(0xFFE8D2A2),
        ));
      }
    }

    // ── 路边的小物件
    final rnd = Random(17);
    for (var i = 0; i < 58; i++) {
      final ss = camS - 4 + rnd.nextDouble() * 38;
      final side = rnd.nextBool() ? 1.0 : -1.0;
      final u = side * (roadHalf + 0.42 + rnd.nextDouble() * 2.6);
      final dz = ss - camS;
      if (dz < 1.2 || dz > 30) continue;
      final p = pointOn(ss, u);
      final k = 0.7 + rnd.nextDouble() * 0.6;
      final kind = rnd.nextInt(10);
      if (kind < 4) {
        faces.addAll(_palm(p, k, rnd));
      } else if (kind < 6) {
        faces.addAll(_rock(p, k * 0.8));
      } else if (kind < 8) {
        faces.addAll(_bush(p, k));
      } else if (kind < 9) {
        faces.addAll(_coral(p, k));
      } else {
        faces.addAll(_shell(p, k * 0.6));
      }
    }

    // ── 山顶的灯塔
    final lhS = roadLength + 5;
    if (lhS - camS > 1.5 && lhS - camS < 34) {
      faces.addAll(_lighthouse(pointOn(lhS, 0), 1.7));
    }

    // ── 关卡：一只只 3D 小东西摆在路上
    final markers = <SceneMarker>[];
    for (final l in levels) {
      final d = l.s - camS;
      if (d < 1.1 || d > 26) continue;
      final u = l.index.isEven ? -0.26 : 0.26;
      final base = V3(roadX(l.s) + u, roadY(l.s) + 0.02, l.s);
      final pr = camera.project(base);
      if (pr == null) continue;
      final k = (pr.pixelsPerUnit * 0.50).clamp(8.0, 150.0);
      final main = l.locked
          ? const Color(0xFFB9BDC4)
          : (l.done ? const Color(0xFF9BE07C) : const Color(0xFFFFB347));
      final accent = l.locked
          ? const Color(0xFFD3D7DC)
          : (l.done ? const Color(0xFF6FC44F) : const Color(0xFFFF8A3D));
      // 地上的影子
      faces.addAll(discFaces(
        V3(base.x, base.y + 0.006, base.z),
        0.26,
        const Color(0x2E1F3A12),
      ));
      faces.addAll(foodFaces(foodKind, base, 0.62, main, accent,
          grey: l.locked));
      markers.add(SceneMarker(
        index: l.index,
        depth: d,
        lesson: l.lesson,
        stage: l.stage,
        key: l.key,
        unlocked: !l.locked,
        x: pr.at.dx,
        y: pr.at.dy,
        px: k,
        stars: l.stars,
        locked: l.locked,
        current: l.index == currentIdx,
        done: l.done,
      ));
    }

    // ── 宠物房
    final sceneHouses = <SceneHouse>[];
    for (final h in worldHouses) {
      final d = h.s - camS;
      if (d < 1.1 || d > 26) continue;
      const u = 1.5;
      final base = V3(roadX(h.s) + u, hillY(h.s, u), h.s);
      final pr = camera.project(base);
      if (pr == null) continue;
      faces.addAll(_house(base, 1.1));
      sceneHouses.add(SceneHouse(
        speciesId: h.speciesId,
        order: h.order,
        owned: h.owned,
        next: false,
        x: pr.at.dx,
        y: pr.at.dy,
        px: pr.pixelsPerUnit,
        depth: d,
      ));
    }
    final nextHouse = sceneHouses.indexWhere((hh) => !hh.owned);
    if (nextHouse >= 0) {
      final hh = sceneHouses[nextHouse];
      sceneHouses[nextHouse] = SceneHouse(
        speciesId: hh.speciesId,
        order: hh.order,
        owned: hh.owned,
        next: true,
        x: hh.x,
        y: hh.y,
        px: hh.px,
        depth: hh.depth,
      );
    }

    // ── 木牌
    final sceneSigns = <SceneSign>[];
    for (final sg in worldSigns) {
      final d = sg.s - camS;
      if (d < 1.1 || d > 26) continue;
      final base = V3(roadX(sg.s), roadY(sg.s) + 0.02, sg.s);
      final pr = camera.project(base);
      if (pr == null) continue;
      sceneSigns.add(SceneSign(
        unit: sg.unit,
        done: sg.done,
        total: sg.total,
        firstLevel: sg.firstLevel,
        lastLevel: sg.lastLevel,
        x: pr.at.dx,
        y: pr.at.dy,
        px: pr.pixelsPerUnit,
        depth: d,
      ));
    }

    return IslandScene(
      faces: faces,
      markers: markers,
      signs: sceneSigns,
      houses: sceneHouses,
      cam: camS,
      horizonY: camera.horizonY,
      roadLength: roadLength,
      currentIndex: currentIdx,
      camera: camera,
    );
  }
}

class _Lvl {
  final int index;
  final Lesson lesson;
  final int stage;
  final String key;
  final double s;
  final int stars;
  final bool locked;
  final bool done;
  const _Lvl({
    required this.index,
    required this.lesson,
    required this.stage,
    required this.key,
    required this.s,
    required this.stars,
    required this.locked,
    required this.done,
  });
}

class _House {
  final String speciesId;
  final int order;
  final bool owned;
  final double s;
  const _House({
    required this.speciesId,
    required this.order,
    required this.owned,
    required this.s,
  });
}

class _Sign {
  final Unit unit;
  final int done;
  final int total;
  final int firstLevel;
  final int lastLevel;
  final double s;
  const _Sign({
    required this.unit,
    required this.done,
    required this.total,
    required this.firstLevel,
    required this.lastLevel,
    required this.s,
  });
}

// ─────────────────────────────────────────────────────────────
// 3D 零件
// ─────────────────────────────────────────────────────────────

List<Face3D> _palm(V3 base, double k, Random rnd) {
  final faces = <Face3D>[];
  final h = 1.9 * k;
  final lean = (rnd.nextDouble() - 0.5) * 0.5;
  faces.addAll(prismFaces(
    base,
    0.075 * k,
    0.05 * k,
    h,
    const Color(0xFFA9743F),
    seg: 5,
  ));
  final top = V3(base.x + lean, base.y + h, base.z);
  for (var i = 0; i < 7; i++) {
    final a = i / 7 * 2 * pi + lean;
    final reach = (0.75 + rnd.nextDouble() * 0.35) * k;
    final tip = V3(
      top.x + cos(a) * reach,
      top.y - 0.18 * k + rnd.nextDouble() * 0.12,
      top.z + sin(a) * reach,
    );
    final mid = V3(
      top.x + cos(a) * reach * 0.45,
      top.y + 0.18 * k,
      top.z + sin(a) * reach * 0.45,
    );
    final side1 =
        V3(mid.x - sin(a) * 0.22 * k, mid.y, mid.z + cos(a) * 0.22 * k);
    final side2 =
        V3(mid.x + sin(a) * 0.22 * k, mid.y, mid.z - cos(a) * 0.22 * k);
    final under = V3(mid.x, mid.y - 0.16 * k, mid.z);
    final green = i.isEven ? const Color(0xFF63C74C) : const Color(0xFF83DD66);
    final dark = i.isEven ? const Color(0xFF46A637) : const Color(0xFF5FBE49);
    faces.add(tri3(top, side1, tip, green));
    faces.add(tri3(top, tip, side2, green));
    faces.add(tri3(side1, under, tip, dark));
    faces.add(tri3(under, side2, tip, dark));
  }
  return faces;
}

List<Face3D> _rock(V3 base, double k) => sphereFaces(
      V3(base.x, base.y + 0.14 * k, base.z),
      0.30 * k,
      0.22 * k,
      0.28 * k,
      const Color(0xFFB4BCC6),
      seg: 6,
      rings: 4,
      topColor: const Color(0xFFCBD3DB),
    );

List<Face3D> _bush(V3 base, double k) {
  final faces = <Face3D>[];
  for (final o in const [
    Offset(-0.16, 0.0),
    Offset(0.16, 0.06),
    Offset(0.0, -0.16),
  ]) {
    faces.addAll(sphereFaces(
      V3(base.x + o.dx * k, base.y + 0.22 * k, base.z + o.dy * k),
      0.22 * k,
      0.20 * k,
      0.22 * k,
      const Color(0xFF57B44A),
      seg: 6,
      rings: 4,
      topColor: const Color(0xFF74CC5C),
    ));
  }
  return faces;
}

List<Face3D> _coral(V3 base, double k) {
  final faces = <Face3D>[];
  for (var i = 0; i < 3; i++) {
    final a = i / 3 * 2 * pi;
    faces.addAll(prismFaces(
      V3(base.x + cos(a) * 0.10 * k, base.y, base.z + sin(a) * 0.10 * k),
      0.05 * k,
      0.0,
      0.34 * k + i * 0.08 * k,
      const Color(0xFFF58AA8),
      seg: 4,
    ));
  }
  return faces;
}

List<Face3D> _shell(V3 base, double k) => sphereFaces(
      V3(base.x, base.y + 0.05 * k, base.z),
      0.16 * k,
      0.08 * k,
      0.16 * k,
      const Color(0xFFFFE1C2),
      seg: 6,
      rings: 3,
    );

List<Face3D> _house(V3 base, double k) {
  final faces = <Face3D>[];
  final w = 0.95 * k, h = 0.78 * k, d = 0.85 * k;
  faces.addAll(boxFaces(
    V3(base.x, base.y + h / 2, base.z),
    w,
    h,
    d,
    const Color(0xFFFFF3E0),
    top: const Color(0xFFFFE9CC),
  ));
  faces.addAll(prismFaces(
    V3(base.x, base.y + h, base.z),
    w * 0.82,
    0.0,
    0.52 * k,
    const Color(0xFFE8734A),
    seg: 4,
  ));
  faces.addAll(boxFaces(
    V3(base.x, base.y + 0.22 * k, base.z - d / 2 - 0.02),
    w * 0.34,
    0.44 * k,
    0.03,
    const Color(0xFFA9743F),
  ));
  return faces;
}

List<Face3D> _lighthouse(V3 base, double k) {
  final faces = <Face3D>[];
  faces.addAll(prismFaces(
      base, 0.55 * k, 0.42 * k, 2.3 * k, const Color(0xFFF7F3EC), seg: 8));
  faces.addAll(prismFaces(
    V3(base.x, base.y + 2.3 * k, base.z),
    0.40 * k,
    0.0,
    0.55 * k,
    const Color(0xFFE8734A),
    seg: 8,
  ));
  faces.addAll(boxFaces(
    V3(base.x, base.y + 1.55 * k, base.z),
    0.30 * k,
    0.26 * k,
    0.30 * k,
    const Color(0xFFFFE08A),
    top: const Color(0xFFFFF0BA),
  ));
  return faces;
}

// ─────────────────────────────────────────────────────────────
// 关卡的 3D 造型：跟着宠物的口味换（北极熊是鱼、小狗是肉骨头…）
// ─────────────────────────────────────────────────────────────

List<Face3D> foodFaces(
  String kind,
  V3 base,
  double k,
  Color main,
  Color accent, {
  bool grey = false,
}) {
  final m = grey ? const Color(0xFFC3C7CD) : main;
  final a = grey ? const Color(0xFFD7DBE0) : accent;
  final faces = <Face3D>[];
  switch (kind) {
    case 'bone':
      final y = base.y + 0.30 * k;
      for (final side in const [-1.0, 1.0]) {
        for (final dz in const [-0.07, 0.07]) {
          faces.addAll(sphereFaces(
            V3(base.x + side * 0.30 * k, y + 0.10 * k, base.z + dz * k),
            0.13 * k,
            0.13 * k,
            0.13 * k,
            m,
            seg: 5,
            rings: 4,
          ));
        }
      }
      faces.addAll(boxFaces(
        V3(base.x, y + 0.09 * k, base.z),
        0.62 * k,
        0.16 * k,
        0.16 * k,
        m,
        top: a,
      ));
      break;
    case 'carrot':
      faces.addAll(prismFaces(
        V3(base.x, base.y + 0.02 * k, base.z),
        0.20 * k,
        0.0,
        0.52 * k,
        m,
        seg: 7,
      ));
      for (final o in const [
        Offset(-0.10, 0.0),
        Offset(0.10, 0.02),
        Offset(0.0, -0.10),
      ]) {
        faces.addAll(sphereFaces(
          V3(base.x + o.dx * k, base.y + 0.58 * k, base.z + o.dy * k),
          0.10 * k,
          0.16 * k,
          0.10 * k,
          a,
          seg: 4,
          rings: 3,
        ));
      }
      break;
    case 'honey':
      faces.addAll(prismFaces(
        V3(base.x, base.y + 0.03 * k, base.z),
        0.26 * k,
        0.20 * k,
        0.34 * k,
        m,
        seg: 8,
      ));
      faces.addAll(prismFaces(
        V3(base.x, base.y + 0.37 * k, base.z),
        0.24 * k,
        0.24 * k,
        0.10 * k,
        a,
        seg: 8,
      ));
      break;
    case 'bamboo':
      for (final o in const [
        Offset(-0.12, 0.0),
        Offset(0.02, 0.06),
        Offset(0.14, -0.04),
      ]) {
        faces.addAll(prismFaces(
          V3(base.x + o.dx * k, base.y + 0.02 * k, base.z + o.dy * k),
          0.06 * k,
          0.05 * k,
          0.62 * k,
          const Color(0xFF8CC860),
          seg: 5,
          top: const Color(0xFFA8D97C),
        ));
      }
      break;
    case 'grape':
      for (final o in const [
        Offset(-0.12, 0.0),
        Offset(0.12, 0.02),
        Offset(0.0, 0.10),
        Offset(0.0, -0.10),
      ]) {
        faces.addAll(sphereFaces(
          V3(base.x + o.dx * k, base.y + 0.26 * k + o.dy * 0.5 * k,
              base.z + o.dy * k),
          0.13 * k,
          0.13 * k,
          0.13 * k,
          m,
          seg: 5,
          rings: 4,
        ));
      }
      break;
    case 'corn':
      faces.addAll(prismFaces(
        V3(base.x, base.y + 0.02 * k, base.z),
        0.14 * k,
        0.10 * k,
        0.62 * k,
        m,
        seg: 7,
        top: a,
      ));
      break;
    case 'bug':
      faces.addAll(sphereFaces(
        V3(base.x, base.y + 0.20 * k, base.z),
        0.18 * k,
        0.14 * k,
        0.20 * k,
        m,
        seg: 6,
        rings: 4,
      ));
      faces.add(tri3(
        V3(base.x - 0.02 * k, base.y + 0.24 * k, base.z),
        V3(base.x - 0.30 * k, base.y + 0.40 * k, base.z - 0.10 * k),
        V3(base.x - 0.02 * k, base.y + 0.36 * k, base.z + 0.04 * k),
        a,
      ));
      faces.add(tri3(
        V3(base.x + 0.02 * k, base.y + 0.24 * k, base.z),
        V3(base.x + 0.30 * k, base.y + 0.40 * k, base.z - 0.10 * k),
        V3(base.x + 0.02 * k, base.y + 0.36 * k, base.z + 0.04 * k),
        a,
      ));
      break;
    case 'fish':
    default:
      final cy = base.y + 0.26 * k;
      faces.addAll(sphereFaces(
        V3(base.x, cy, base.z),
        0.30 * k,
        0.17 * k,
        0.13 * k,
        m,
        seg: 7,
        rings: 4,
        topColor: a,
      ));
      faces.add(tri3(
        V3(base.x - 0.28 * k, cy, base.z),
        V3(base.x - 0.52 * k, cy + 0.18 * k, base.z),
        V3(base.x - 0.52 * k, cy - 0.18 * k, base.z),
        a,
      ));
      faces.add(tri3(
        V3(base.x - 0.12 * k, cy + 0.14 * k, base.z),
        V3(base.x + 0.02 * k, cy + 0.30 * k, base.z),
        V3(base.x + 0.12 * k, cy + 0.14 * k, base.z),
        a,
      ));
      break;
  }
  return faces;
}