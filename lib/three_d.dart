import 'dart:math';
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// 一个很小的 3D 渲染管线（纯 Dart，画到 Canvas 上）
///   顶点 → 相机矩阵（俯仰）→ 透视投影 → 面法线光照 → 深度排序 → 光栅化
///   不依赖任何游戏引擎，离线、没有贴图资源，怎么升级都不会糊。
/// ─────────────────────────────────────────────────────────────

class V3 {
  final double x;
  final double y;
  final double z;
  const V3(this.x, this.y, this.z);

  static const V3 zero = V3(0, 0, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get len => sqrt(x * x + y * y + z * z);
  V3 get unit {
    final l = len;
    return l < 1e-9 ? const V3(0, 1, 0) : V3(x / l, y / l, z / l);
  }

  static V3 lerp(V3 a, V3 b, double t) =>
      V3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
}

/// 投影结果：屏幕位置 + 深度 + 缩放（世界 1 单位 = 多少像素）
class Projected {
  final Offset at;
  final double depth;
  final double pixelsPerUnit;
  const Projected(this.at, this.depth, this.pixelsPerUnit);
}

/// 相机：站在 [pos]，朝 +z 方向看，往下压 [pitch] 弧度
class Camera3D {
  final V3 pos;
  final double pitch;
  final double fovY;
  final Size size;

  const Camera3D({
    required this.pos,
    required this.size,
    this.pitch = 0.20,
    this.fovY = 1.15,
  });

  double get focal => (size.height / 2) / tan(fovY / 2);

  /// 地平线在屏幕上的 y
  double get horizonY => size.height / 2 - focal * tan(pitch);

  Projected? project(V3 p) {
    final dx = p.x - pos.x;
    final dy = p.y - pos.y;
    final dz = p.z - pos.z;
    final cy = cos(pitch);
    final sy = sin(pitch);
    final vy = dy * cy + dz * sy;
    final vz = -dy * sy + dz * cy;
    if (vz < 0.06) return null;
    final f = focal;
    return Projected(
      Offset(size.width / 2 + f * dx / vz, size.height / 2 - f * vy / vz),
      vz,
      f / vz,
    );
  }
}

/// 三角形/四边形面：世界坐标顶点 + 颜色
class Face3D {
  final List<V3> pts;
  final Color color;

  /// 额外压暗/提亮（0 = 不参与光照，1 = 完整 lambert）
  final double lit;

  const Face3D(this.pts, this.color, {this.lit = 1.0});

  V3 get center {
    var sx = 0.0, sy = 0.0, sz = 0.0;
    for (final p in pts) {
      sx += p.x;
      sy += p.y;
      sz += p.z;
    }
    final n = pts.length;
    return V3(sx / n, sy / n, sz / n);
  }

  V3 get normal {
    final a = pts[0];
    final b = pts[1];
    final c = pts[pts.length - 1];
    return (b - a).cross(c - a).unit;
  }
}

/// 把一堆面按真 3D 光照 + 远处雾画出来
class Renderer3D {
  final Camera3D camera;

  /// 主光方向（从哪儿照过来）
  final V3 light;

  final double ambient;
  final Color fog;
  final double fogNear;
  final double fogFar;

  Renderer3D({
    required this.camera,
    this.light = const V3(-0.42, 0.82, -0.38),
    this.ambient = 0.68,
    this.fog = const Color(0xFFEFF9FF),
    this.fogNear = 16,
    this.fogFar = 34,
  });

  /// 一个面算完光照和雾之后的颜色
  Color shade(Face3D f, double depth) {
    final n = f.normal;
    var l = n.dot(light.unit);
    if (l < 0) l = -l * 0.35; // 背面也留一点亮
    final k = 1.0 - f.lit + f.lit * (ambient + (1 - ambient) * l);
    var c = f.color;
    final r = (c.r * k).clamp(0.0, 1.0);
    final g = (c.g * k).clamp(0.0, 1.0);
    final b = (c.b * k).clamp(0.0, 1.0);
    final a = f.color.a;
    final t = ((depth - fogNear) / max(fogFar - fogNear, 0.001)).clamp(0.0, 1.0);
    if (t > 0) {
      final fogged = Color.lerp(
          Color.from(alpha: a, red: r, green: g, blue: b), fog, t * 0.9)!;
      return fogged.withValues(alpha: a);
    }
    return Color.from(alpha: a, red: r, green: g, blue: b);
  }

  void render(Canvas canvas, List<Face3D> faces, {V3 light = const V3(-0.42, 0.82, -0.38)}) {
    // 1) 投影 + 深度
    final projected = <_PF>[];
    for (final f in faces) {
      final pts = <Offset>[];
      var depth = 0.0;
      var ok = true;
      for (final p in f.pts) {
        final pr = camera.project(p);
        if (pr == null) {
          ok = false;
          break;
        }
        pts.add(pr.at);
        depth += pr.depth;
      }
      if (!ok || pts.length < 3) continue;
      depth /= pts.length;
      // 屏幕外就不要了
      final xs = pts.map((p) => p.dx);
      final ys = pts.map((p) => p.dy);
      if (xs.reduce(min) > camera.size.width + 60) continue;
      if (xs.reduce(max) < -60) continue;
      if (ys.reduce(min) > camera.size.height + 60) continue;
      if (ys.reduce(max) < -60) continue;
      projected.add(_PF(pts, depth, f));
    }
    // 2) 远的先画
    projected.sort((a, b) => b.depth.compareTo(a.depth));
    // 3) 光栅化
    final paint = Paint()..style = PaintingStyle.fill;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0x14000000);
    for (final pf in projected) {
      paint.color = shade(pf.face, pf.depth);
      final path = Path()..addPolygon(pf.pts, true);
      canvas.drawPath(path, paint);
      if (pf.pts.length == 4) canvas.drawPath(path, edge);
    }
  }
}

class _PF {
  final List<Offset> pts;
  final double depth;
  final Face3D face;
  const _PF(this.pts, this.depth, this.face);
}

// ─────────────────────────────────────────────────────────────
// 立体小零件：长方体 / 圆锥 / 球 / 圆柱 / 棱柱 / 锥体
// ─────────────────────────────────────────────────────────────

/// 长方体（可以绕 y 轴转一下）
List<Face3D> boxFaces(
  V3 c,
  double w,
  double h,
  double d,
  Color color, {
  Color? top,
  double yaw = 0,
}) {
  final hw = w / 2, hh = h / 2, hd = d / 2;
  final cs = cos(yaw), sn = sin(yaw);
  Offset rot(double x, double z) => Offset(x * cs - z * sn, x * sn + z * cs);
  V3 corner(double x, double y, double z) {
    final r = rot(x, z);
    return V3(c.x + r.dx, c.y + y, c.z + r.dy);
  }

  final p000 = corner(-hw, -hh, -hd);
  final p100 = corner(hw, -hh, -hd);
  final p110 = corner(hw, hh, -hd);
  final p010 = corner(-hw, hh, -hd);
  final p001 = corner(-hw, -hh, hd);
  final p101 = corner(hw, -hh, hd);
  final p111 = corner(hw, hh, hd);
  final p011 = corner(-hw, hh, hd);
  final tc = top ?? color;
  return [
    Face3D([p010, p110, p111, p011], tc), // 顶
    Face3D([p000, p001, p101, p100], color), // 底
    Face3D([p001, p011, p111, p101], color), // +z
    Face3D([p000, p100, p110, p010], color), // -z
    Face3D([p000, p010, p011, p001], color), // -x
    Face3D([p100, p101, p111, p110], color), // +x
  ];
}

/// 圆柱/圆锥：底圆 + 顶圆（顶半径 0 就是圆锥）
List<Face3D> prismFaces(
  V3 base,
  double rBottom,
  double rTop,
  double h,
  Color color, {
  int seg = 10,
  Color? top,
}) {
  final faces = <Face3D>[];
  final bottom = <V3>[];
  final topRing = <V3>[];
  for (var i = 0; i < seg; i++) {
    final a = i / seg * 2 * pi;
    bottom.add(V3(base.x + cos(a) * rBottom, base.y, base.z + sin(a) * rBottom));
    topRing.add(V3(base.x + cos(a) * rTop, base.y + h, base.z + sin(a) * rTop));
  }
  for (var i = 0; i < seg; i++) {
    final j = (i + 1) % seg;
    if (rTop <= 0.0001) {
      faces.add(Face3D([bottom[i], bottom[j], topRing[i]], color));
    } else {
      faces.add(Face3D([bottom[i], bottom[j], topRing[j], topRing[i]], color));
    }
  }
  if (rTop > 0.0001) faces.add(Face3D(topRing, top ?? color));
  return faces;
}

/// 椭球：用经纬网格拼（seg 别太大，手机上够用）
List<Face3D> sphereFaces(
  V3 c,
  double rx,
  double ry,
  double rz,
  Color color, {
  int seg = 8,
  int rings = 5,
  Color? topColor,
}) {
  final faces = <Face3D>[];
  V3 at(double lat, double lon) {
    final cl = cos(lat), sl = sin(lat);
    return V3(
      c.x + rx * cl * cos(lon),
      c.y + ry * sl,
      c.z + rz * cl * sin(lon),
    );
  }

  for (var j = 0; j < rings - 1; j++) {
    final lat0 = -pi / 2 + pi * j / (rings - 1);
    final lat1 = -pi / 2 + pi * (j + 1) / (rings - 1);
    for (var i = 0; i < seg; i++) {
      final lon0 = 2 * pi * i / seg;
      final lon1 = 2 * pi * (i + 1) / seg;
      final cc = topColor != null && lat1 > 0.4 ? topColor : color;
      faces.add(Face3D([
        at(lat0, lon0),
        at(lat0, lon1),
        at(lat1, lon1),
        at(lat1, lon0),
      ], cc));
    }
  }
  return faces;
}

/// 四边形面片（用来铺地、铺路、做叶子）
Face3D quad3(V3 a, V3 b, V3 c, V3 d, Color color) => Face3D([a, b, c, d], color);

/// 三角形的面片
Face3D tri3(V3 a, V3 b, V3 c, Color color) => Face3D([a, b, c], color);

/// 平躺在地上的圆片（用来做影子 / 光斑）
List<Face3D> discFaces(V3 c, double r, Color color, {int seg = 10}) {
  final pts = <V3>[];
  for (var i = 0; i < seg; i++) {
    final a = i / seg * 2 * pi;
    pts.add(V3(c.x + cos(a) * r, c.y, c.z + sin(a) * r));
  }
  return [Face3D(pts, color, lit: 0.0)];
}