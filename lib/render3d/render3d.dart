import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 纯 Dart 实时 3D 软件光栅器（无第三方库，无贴图，无 Transform）
//
//   数据流：
//   模型网格(顶点+法线+三角形)
//     → 模型矩阵 M (4x4)
//     → 视图矩阵 V = lookAt(eye,target,up) (4x4)
//     → 投影矩阵 P = perspective(fovY,aspect,near,far) (4x4)
//     → 裁剪空间 (x,y,z,w)
//     → 透视除法 x/w, y/w, z/w → NDC → 屏幕像素
//     → 三角形光栅化（边函数 + 重心坐标，按 1/w 做透视校正插值）
//     → 逐像素 Z-buffer 深度测试（近的遮挡远的）
//     → 逐像素光照：N·L 漫反射 + Blinn-Phong 镜面 + 距离雾
//     → RGBA 字节 → ui.decodeImageFromPixels → Canvas
// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────────── 向量 ─────────────────────────────

class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);

  static const V3 zero = V3(0, 0, 0);
  static const V3 upAxis = V3(0, 1, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l < 1e-9 ? const V3(0, 1, 0) : V3(x / l, y / l, z / l);
  }

  @override
  String toString() => 'V3(${x.toStringAsFixed(2)}, '
      '${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// 齐次坐标顶点（透视除法要用 w）
class V4 {
  final double x, y, z, w;
  const V4(this.x, this.y, this.z, this.w);
  V4.point(V3 p) : this(p.x, p.y, p.z, 1.0);
}

// ───────────────────────────── 4x4 矩阵 ─────────────────────────────

/// 列主序 4x4 矩阵：m[col * 4 + row]
class M4 {
  final Float64List m;

  M4._(this.m);

  factory M4.identity() {
    final m = Float64List(16);
    m[0] = 1;
    m[5] = 1;
    m[10] = 1;
    m[15] = 1;
    return M4._(m);
  }

  factory M4.fromRows(List<double> r) {
    // 行主序输入，转成列主序存储，方便手写矩阵时对照
    assert(r.length == 16);
    return M4._(Float64List.fromList([
      r[0], r[4], r[8], r[12], //
      r[1], r[5], r[9], r[13],
      r[2], r[6], r[10], r[14],
      r[3], r[7], r[11], r[15],
    ]));
  }

  /// 平移
  factory M4.translate(V3 t) {
    final m = M4.identity();
    m.m[12] = t.x;
    m.m[13] = t.y;
    m.m[14] = t.z;
    return m;
  }

  /// 缩放
  factory M4.scale(V3 s) {
    final m = Float64List(16);
    m[0] = s.x;
    m[5] = s.y;
    m[10] = s.z;
    m[15] = 1;
    return M4._(m);
  }

  /// 绕 Y 轴旋转（弧度）
  factory M4.rotateY(double a) {
    final c = cos(a), s = sin(a);
    return M4.fromRows([
      c, 0, s, 0, //
      0, 1, 0, 0,
      -s, 0, c, 0,
      0, 0, 0, 1,
    ]);
  }

  /// 绕 X 轴旋转（弧度）
  factory M4.rotateX(double a) {
    final c = cos(a), s = sin(a);
    return M4.fromRows([
      1, 0, 0, 0, //
      0, c, -s, 0,
      0, s, c, 0,
      0, 0, 0, 1,
    ]);
  }

  M4 operator *(M4 o) {
    final a = m, b = o.m;
    final r = Float64List(16);
    for (var c = 0; c < 4; c++) {
      final b0 = b[c * 4], b1 = b[c * 4 + 1], b2 = b[c * 4 + 2], b3 = b[c * 4 + 3];
      for (var row = 0; row < 4; row++) {
        r[c * 4 + row] = a[row] * b0 +
            a[4 + row] * b1 +
            a[8 + row] * b2 +
            a[12 + row] * b3;
      }
    }
    return M4._(r);
  }

  /// 变换点（w = 1，含透视除法前的 w）
  V4 transformPoint(V3 p) {
    final d = m;
    return V4(
      d[0] * p.x + d[4] * p.y + d[8] * p.z + d[12],
      d[1] * p.x + d[5] * p.y + d[9] * p.z + d[13],
      d[2] * p.x + d[6] * p.y + d[10] * p.z + d[14],
      d[3] * p.x + d[7] * p.y + d[11] * p.z + d[15],
    );
  }

  /// 变换法线（忽略平移，w = 0）
  V3 transformNormal(V3 n) {
    final d = m;
    return V3(
      d[0] * n.x + d[4] * n.y + d[8] * n.z,
      d[1] * n.x + d[5] * n.y + d[9] * n.z,
      d[2] * n.x + d[6] * n.y + d[10] * n.z,
    ).normalized;
  }

  /// 透视投影矩阵（右手系，相机看 -Z，NDC z ∈ [-1,1]）
  factory M4.perspective({
    required double fovY,
    required double aspect,
    required double near,
    required double far,
  }) {
    final f = 1.0 / tan(fovY / 2);
    return M4.fromRows([
      f / aspect, 0, 0, 0, //
      0, f, 0, 0,
      0, 0, (far + near) / (near - far), 2 * far * near / (near - far),
      0, 0, -1, 0,
    ]);
  }

  /// 视图矩阵：相机在 eye，看向 target，up 是上方向
  factory M4.lookAt({
    required V3 eye,
    required V3 target,
    V3 up = V3.upAxis,
  }) {
    final f = (target - eye).normalized; // 前
    final s = f.cross(up).normalized; // 右
    final u = s.cross(f); // 上（重新正交化）
    return M4.fromRows([
      s.x, s.y, s.z, -s.dot(eye), //
      u.x, u.y, u.z, -u.dot(eye),
      -f.x, -f.y, -f.z, f.dot(eye),
      0, 0, 0, 1,
    ]);
  }
}

// ───────────────────────────── 相机 ─────────────────────────────

/// 相机就是一个 position / target / fov 的对象：改它，整个画面跟着变
class Camera3D {
  final V3 position;
  final V3 target;
  final double fovY; // 垂直视场角（弧度）
  final double near;
  final double far;

  const Camera3D({
    required this.position,
    required this.target,
    this.fovY = 1.0, // ≈57°
    this.near = 0.1,
    this.far = 200,
  });

  /// 绕 target 的球面 orbit 相机 + 俯仰
  factory Camera3D.orbit({
    required V3 target,
    required double radius,
    required double yaw, // 绕 Y 轴
    required double pitch, // 上下俯仰
    double fovY = 1.0,
  }) {
    final cp = cos(pitch), sp = sin(pitch);
    return Camera3D(
      position: V3(
        target.x + radius * cp * sin(yaw),
        target.y + radius * sp,
        target.z + radius * cp * cos(yaw),
      ),
      target: target,
      fovY: fovY,
    );
  }

  M4 viewMatrix() => M4.lookAt(eye: position, target: target);

  M4 projectionMatrix(double aspect) => M4.perspective(
        fovY: fovY,
        aspect: aspect,
        near: near,
        far: far,
      );

  /// P * V
  M4 viewProjection(double aspect) => projectionMatrix(aspect) * viewMatrix();
}

// ───────────────────────────── 网格 ─────────────────────────────

/// 一个三角形：三个顶点 + 三个顶点法线 + 颜色
class Tri3D {
  final V3 a, b, c;
  final V3 na, nb, nc;
  final Color color;
  const Tri3D(this.a, this.b, this.c, this.na, this.nb, this.nc, this.color);
}

class Mesh {
  final List<Tri3D> tris;
  const Mesh(this.tris);

  /// 立方体（每个面一个法线，棱是硬的）
  factory Mesh.cube(double size,
      {Color color = const Color(0xFFE9A23B),
      Color? top,
      Color? side}) {
    final h = size / 2;
    final tris = <Tri3D>[];
    void face(V3 n, V3 p0, V3 p1, V3 p2, V3 p3, Color c) {
      tris.add(Tri3D(p0, p1, p2, n, n, n, c));
      tris.add(Tri3D(p0, p2, p3, n, n, n, c));
    }

    final topC = top ?? color;
    final sideC = side ?? color;
    face(const V3(0, 1, 0), V3(-h, h, -h), V3(-h, h, h), V3(h, h, h), V3(h, h, -h),
        topC);
    face(const V3(0, -1, 0), V3(-h, -h, -h), V3(h, -h, -h), V3(h, -h, h),
        V3(-h, -h, h), sideC);
    face(const V3(0, 0, 1), V3(-h, -h, h), V3(h, -h, h), V3(h, h, h),
        V3(-h, h, h), sideC);
    face(const V3(0, 0, -1), V3(h, -h, -h), V3(-h, -h, -h), V3(-h, h, -h),
        V3(h, h, -h), sideC);
    face(const V3(1, 0, 0), V3(h, -h, h), V3(h, -h, -h), V3(h, h, -h),
        V3(h, h, h), sideC);
    face(const V3(-1, 0, 0), V3(-h, -h, -h), V3(-h, -h, h), V3(-h, h, h),
        V3(-h, h, -h), sideC);
    return Mesh(tris);
  }

  /// 球（顶点法线 = 顶点方向，所以表面是光滑的）
  factory Mesh.sphere(double radius,
      {Color color = const Color(0xFF4FA3E3), int segU = 28, int segV = 18}) {
    final tris = <Tri3D>[];
    V3 at(int i, int j) {
      final theta = pi * j / segV;
      final phi = 2 * pi * i / segU;
      return V3(
        radius * sin(theta) * cos(phi),
        radius * cos(theta),
        radius * sin(theta) * sin(phi),
      );
    }

    for (var j = 0; j < segV; j++) {
      for (var i = 0; i < segU; i++) {
        final p00 = at(i, j);
        final p10 = at(i + 1, j);
        final p01 = at(i, j + 1);
        final p11 = at(i + 1, j + 1);
        final n00 = p00.normalized;
        final n10 = p10.normalized;
        final n01 = p01.normalized;
        final n11 = p11.normalized;
        if (j != 0) {
          tris.add(Tri3D(p00, p10, p11, n00, n10, n11, color));
        }
        if (j != segV - 1) {
          tris.add(Tri3D(p00, p11, p01, n00, n11, n01, color));
        }
      }
    }
    return Mesh(tris);
  }

  /// 水平地面（法线朝上）
  factory Mesh.plane(double size,
      {Color color = const Color(0xFF7FBF5A), int tiles = 8}) {
    // 用格子拼，既能看清透视，也方便看深度关系
    final tris = <Tri3D>[];
    final step = size / tiles;
    final start = -size / 2;
    const n = V3(0, 1, 0);
    for (var i = 0; i < tiles; i++) {
      for (var j = 0; j < tiles; j++) {
        final x0 = start + i * step;
        final z0 = start + j * step;
        final x1 = x0 + step;
        final z1 = z0 + step;
        final c = ((i + j) % 2 == 0)
            ? color
            : Color.lerp(color, Colors.black, 0.08)!;
        tris.add(Tri3D(V3(x0, 0, z0), V3(x0, 0, z1), V3(x1, 0, z1), n, n, n, c));
        tris.add(Tri3D(V3(x0, 0, z0), V3(x1, 0, z1), V3(x1, 0, z0), n, n, n, c));
      }
    }
    return Mesh(tris);
  }
}

/// 一个网格实例：网格 + 模型矩阵
class MeshInstance {
  final Mesh mesh;
  final M4 model;
  const MeshInstance(this.mesh, this.model);
}

// ───────────────────────────── 光栅器 ─────────────────────────────

/// 逐像素软件光栅器：Z-buffer + 透视校正插值 + Lambert/Blinn-Phong 着色
class Rasterizer3D {
  final int width;
  final int height;

  /// RGBA8 颜色缓冲
  final Uint8List pixels;

  /// 深度缓冲（存 NDC z，越小越近）
  final Float32List depth;

  final V3 lightDir; // 指向光源的单位向量
  final double ambient;
  final Color skyColor;
  final double fogNear;
  final double fogFar;

  Rasterizer3D({
    required this.width,
    required this.height,
    this.lightDir = const V3(-0.5, 0.85, 0.4),
    this.ambient = 0.30,
    this.skyColor = const Color(0xFFBFE3F5),
    this.fogNear = 14,
    this.fogFar = 34,
  })  : pixels = Uint8List(width * height * 4),
        depth = Float32List(width * height);

  void clear(Color bg) {
    final r = (bg.r * 255).round();
    final g = (bg.g * 255).round();
    final b = (bg.b * 255).round();
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = r;
      pixels[i + 1] = g;
      pixels[i + 2] = b;
      pixels[i + 3] = 255;
    }
    depth.fillRange(0, depth.length, double.infinity);
  }

  /// 渲染一帧：模型矩阵 × 视图矩阵 × 投影矩阵，然后光栅化 + 深度测试 + 光照
  void renderScene(List<MeshInstance> instances, Camera3D camera) {
    final vp = camera.viewProjection(width / height);
    for (final inst in instances) {
      final mvp = vp * inst.model;
      for (final tri in inst.mesh.tris) {
        _drawTriangle(tri, mvp, inst.model, camera);
      }
    }
  }

  void _drawTriangle(Tri3D tri, M4 mvp, M4 model, Camera3D camera) {
    // ① 顶点着色：MVP 变换
    final ca = mvp.transformPoint(tri.a);
    final cb = mvp.transformPoint(tri.b);
    final cc = mvp.transformPoint(tri.c);

    // ② 近平面：任一顶点在相机后面就丢掉这个三角形（简化版裁剪）
    if (ca.w <= 0.0001 || cb.w <= 0.0001 || cc.w <= 0.0001) return;

    // ③ 透视除法 → NDC → 屏幕像素
    final invWa = 1.0 / ca.w, invWb = 1.0 / cb.w, invWc = 1.0 / cc.w;
    final ax = (ca.x * invWa * 0.5 + 0.5) * width;
    final ay = (0.5 - ca.y * invWa * 0.5) * height;
    final bx = (cb.x * invWb * 0.5 + 0.5) * width;
    final by = (0.5 - cb.y * invWb * 0.5) * height;
    final cx = (cc.x * invWc * 0.5 + 0.5) * width;
    final cy = (0.5 - cc.y * invWc * 0.5) * height;

    final area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    if (area.abs() < 0.0001) return; // 退化成一条线

    // ④ 包围盒
    var minX = min(ax, min(bx, cx)).floor();
    var maxX = max(ax, max(bx, cx)).ceil();
    var minY = min(ay, min(by, cy)).floor();
    var maxY = max(ay, max(by, cy)).ceil();
    if (minX < 0) minX = 0;
    if (minY < 0) minY = 0;
    if (maxX > width - 1) maxX = width - 1;
    if (maxY > height - 1) maxY = height - 1;
    if (minX > maxX || minY > maxY) return;

    // ⑤ 法线（模型矩阵变换后）
    final na = model.transformNormal(tri.na);
    final nb = model.transformNormal(tri.nb);
    final nc = model.transformNormal(tri.nc);
    final base = tri.color;

    // 顶点世界坐标（算光照与雾）
    final wa = model.transformPoint(tri.a);
    final wb = model.transformPoint(tri.b);
    final wc = model.transformPoint(tri.c);

    final camPos = camera.position;
    final invArea = 1.0 / area;

    for (var y = minY; y <= maxY; y++) {
      final py = y + 0.5;
      final rowBase = y * width;
      for (var x = minX; x <= maxX; x++) {
        final px = x + 0.5;
        // 重心坐标（屏幕空间）
        final w0 = ((bx - px) * (cy - py) - (by - py) * (cx - px)) * invArea;
        final w1 = ((cx - px) * (ay - py) - (cy - py) * (ax - px)) * invArea;
        final w2 = 1.0 - w0 - w1;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue; // 三角形外

        // 透视校正：按 1/w 加权
        final iw = w0 * invWa + w1 * invWb + w2 * invWc;
        if (iw <= 0) continue;
        final b0 = w0 * invWa / iw;
        final b1 = w1 * invWb / iw;
        final b2 = w2 * invWc / iw;

        // NDC 深度（线性插值即可，1/w 已含在 z/w 里）
        final z = ca.z * invWa * b0 + cb.z * invWb * b1 + cc.z * invWc * b2;

        // ⑥ 深度测试：Z-buffer（近的遮挡远的）
        final idx = rowBase + x;
        if (z >= depth[idx]) continue;
        depth[idx] = z;

        // ⑦ 逐像素法线
        final nx = na.x * b0 + nb.x * b1 + nc.x * b2;
        final ny = na.y * b0 + nb.y * b1 + nc.y * b2;
        final nz = na.z * b0 + nb.z * b1 + nc.z * b2;
        final nl = sqrt(nx * nx + ny * ny + nz * nz);
        if (nl < 1e-9) continue;
        final ux = nx / nl, uy = ny / nl, uz = nz / nl;

        // 世界位置
        final wx = wa.x * b0 + wb.x * b1 + wc.x * b2;
        final wy = wa.y * b0 + wb.y * b1 + wc.y * b2;
        final wz = wa.z * b0 + wb.z * b1 + wc.z * b2;

        // ⑧ 光照：漫反射 N·L + Blinn-Phong 镜面
        var diff = ux * lightDir.x + uy * lightDir.y + uz * lightDir.z;
        if (diff < 0) diff = 0;
        // 视线（像素 → 相机）
        final vx = camPos.x - wx, vy = camPos.y - wy, vz = camPos.z - wz;
        final vlen = sqrt(vx * vx + vy * vy + vz * vz);
        var spec = 0.0;
        if (vlen > 0.0001 && diff > 0) {
          final hx = (lightDir.x + vx / vlen) * 0.5;
          final hy = (lightDir.y + vy / vlen) * 0.5;
          final hz = (lightDir.z + vz / vlen) * 0.5;
          final hl = sqrt(hx * hx + hy * hy + hz * hz);
          final ndoth = (ux * hx + uy * hy + uz * hz) / hl;
          if (ndoth > 0) spec = pow(ndoth, 28).toDouble() * 0.45;
        }
        final k = ambient + 0.85 * diff;

        var r = base.r * k + spec;
        var g = base.g * k + spec;
        var b = base.b * k + spec;

        // ⑨ 距离雾
        if (vlen > fogNear) {
          var t = (vlen - fogNear) / (fogFar - fogNear);
          if (t > 1) t = 1;
          r = r + (skyColor.r - r) * t * 0.9;
          g = g + (skyColor.g - g) * t * 0.9;
          b = b + (skyColor.b - b) * t * 0.9;
        }

        final o = idx * 4;
        pixels[o] = (r.clamp(0.0, 1.0) * 255).round();
        pixels[o + 1] = (g.clamp(0.0, 1.0) * 255).round();
        pixels[o + 2] = (b.clamp(0.0, 1.0) * 255).round();
      }
    }
  }

  /// 转成 Flutter 的图片
  Future<ui.Image> toImage() {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

/// 便捷：一次性渲染出图片
Future<ui.Image> renderToImage({
  required int width,
  required int height,
  required List<MeshInstance> instances,
  required Camera3D camera,
  Color background = const Color(0xFFBFE3F5),
}) async {
  final raster = Rasterizer3D(width: width, height: height);
  raster.clear(background);
  raster.renderScene(instances, camera);
  return raster.toImage();
}