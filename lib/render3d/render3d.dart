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

  /// 把一个世界坐标点投影到屏幕（给贴在 3D 位置上的 2D 标签用）
  Projected? projectPoint(V3 p, double aspect, Size size) {
    final v = viewProjection(aspect).transformPoint(p);
    if (v.w <= 0.0001) return null;
    final invW = 1.0 / v.w;
    return Projected(
      Offset(
        (v.x * invW * 0.5 + 0.5) * size.width,
        (0.5 - v.y * invW * 0.5) * size.height,
      ),
      v.w,
      // 1 世界单位 = 多少像素（焦距 / 深度 / 宽高比修正）
      (size.height / 2 / tan(fovY / 2)) * invW,
    );
  }
}

/// 屏幕上的投影结果
class Projected {
  final Offset at;

  /// 与相机的距离（世界单位）
  final double depth;

  /// 世界 1 单位在屏幕上占多少像素
  final double pixelsPerUnit;
  const Projected(this.at, this.depth, this.pixelsPerUnit);
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

/// 贴在某个物体脚下的"接触阴影"（AO）来源
class ShadowCaster {
  /// 物体贴地中心
  final V3 at;

  /// 接触半径
  final double radius;

  /// 物体高度：太阳把影子沿光线方向拉多长就靠它（0 = 只有脚下一圈）
  final double height;
  const ShadowCaster(this.at, this.radius, {this.height = 1.0});
}

/// 逐像素软件光栅器：Z-buffer + 透视校正插值 + 完整光照
///
/// 着色公式（每个像素）：
///   color = ambient*base + max(0, N·L)*lightColor*base        ← 主光
///         + skyTint*max(0,N.y)*skyStrength                     ← 天光（朝上偏冷）
///         + groundTint*max(0,-N.y)*groundStrength              ← 地面反弹（朝下偏暖）
///         + spec                                               ← 高光
///   再乘接触阴影 AO，最后按深度做大气透视（降饱和 + 混雾色）
class Rasterizer3D {
  final int width;
  final int height;

  /// RGBA8 颜色缓冲
  final Uint8List pixels;

  /// 深度缓冲（存 NDC z，越小越近）
  final Float32List depth;

  /// 太阳方向（指向光源的单位向量，构造时自动归一化）
  final V3 lightDir;
  final Color lightColor;

  /// 阳光强度（1.0 时 N·L 全量；调小一点，浅色路面才不会烧成纯白）
  final double sunIntensity;

  /// 每个面一点随机的深浅抖动，打散"整片叶子一个色"的剪纸感
  final double faceVariation;

  /// 环境光（0.30 ~ 0.40）
  final double ambient;

  /// 天光：朝上的面偏冷
  final Color skyTint;
  final double skyStrength;

  /// 地面反弹光：朝下的面偏暖
  final Color groundTint;
  final double groundStrength;

  /// 接触阴影强度（0 = 关）
  final double aoStrength;

  /// 太阳投影的深浅（影子本身有多暗）
  final double shadowStrength;

  /// 双面光照：法线背对相机时翻到正面用。
  /// 地形、路面、树叶都是单面片，没有背面；不翻的话整片地面永远只有 ambient 亮度，
  /// 看起来就是一张没有光照的纯色卡。
  final bool twoSided;

  /// 地面材质噪声强度：让草地和路面不是一个纯色块
  final double noiseStrength;

  /// 镜面高光强度
  final double specStrength;

  /// 关掉光照只留 ambient —— 用来做"没有光照"的对比图
  final bool lightingEnabled;

  final Color fogColor;
  final double fogNear;
  final double fogFar;

  /// 大气透视：远处去饱和的比例
  final double fogDesat;

  /// 阴影来源
  final List<ShadowCaster> casters;

  // ── 预烘好的阴影场（世界 XZ 平面上的栅格）──
  Float32List? _shadow;
  double _shX0 = 0, _shZ0 = 0, _shCell = 0.35;
  int _shW = 0, _shH = 0;

  Rasterizer3D({
    required this.width,
    required this.height,
    V3 lightDir = const V3(-0.45, 0.78, -0.42),
    this.lightColor = const Color(0xFFFFF3DA),
    this.sunIntensity = 0.82,
    this.faceVariation = 0.08,
    this.ambient = 0.34,
    this.skyTint = const Color(0xFFB6DBF5),
    this.skyStrength = 0.20,
    this.groundTint = const Color(0xFFE7B67A),
    this.groundStrength = 0.10,
    this.aoStrength = 0.55,
    this.shadowStrength = 0.60,
    this.twoSided = true,
    this.noiseStrength = 0.10,
    this.specStrength = 0.35,
    this.lightingEnabled = true,
    this.fogColor = const Color(0xFFCFE6EE),
    this.fogNear = 16,
    this.fogFar = 34,
    this.fogDesat = 0.65,
    this.casters = const [],
  })  : lightDir = lightDir.normalized,
        pixels = Uint8List(width * height * 4),
        depth = Float32List(width * height);

  /// 预烘一张"地面阴影场"：每个格子里记 0~1 的阴影浓度。
  ///
  /// 每个 caster 当成一根竖着的胶囊（脚底 → 头顶），沿光线方向投到 y=0 平面上，
  /// 得到一个从脚下往背光侧拉长的影子。比"脚下压暗一圈"真实得多：
  /// 树影会顺着一侧倒下去，而且离树越远越淡。
  void _buildGrid() {
    if (casters.isEmpty || shadowStrength <= 0) {
      _shadow = null;
      return;
    }
    final ly = lightDir.y.abs() < 1e-4 ? 1e-4 : lightDir.y;
    var minX = double.infinity, maxX = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;

    double topX(ShadowCaster c) => c.at.x - lightDir.x * (c.height / ly);
    double topZ(ShadowCaster c) => c.at.z - lightDir.z * (c.height / ly);

    for (final c in casters) {
      final pad = c.radius * 1.9 + 0.5;
      minX = min(minX, min(c.at.x, topX(c)) - pad);
      maxX = max(maxX, max(c.at.x, topX(c)) + pad);
      minZ = min(minZ, min(c.at.z, topZ(c)) - pad);
      maxZ = max(maxZ, max(c.at.z, topZ(c)) + pad);
    }
    if (!minX.isFinite) {
      _shadow = null;
      return;
    }

    const cell = 0.25;
    final w = ((maxX - minX) / cell).ceil() + 1;
    final h = ((maxZ - minZ) / cell).ceil() + 1;
    if (w <= 0 || h <= 0 || w * h > 4000000) {
      _shadow = null;
      return;
    }
    final field = Float32List(w * h);

    for (final c in casters) {
      final ax = c.at.x, az = c.at.z;
      final bx = topX(c), bz = topZ(c);
      final r = c.radius * 1.05; // 影子比本体宽一点点
      final segX = bx - ax, segZ = bz - az;
      final segLen2 = segX * segX + segZ * segZ;
      final c0 = max(0, ((min(ax, bx) - r - minX) / cell).floor());
      final c1 = min(w - 1, ((max(ax, bx) + r - minX) / cell).ceil());
      final r0 = max(0, ((min(az, bz) - r - minZ) / cell).floor());
      final r1 = min(h - 1, ((max(az, bz) + r - minZ) / cell).ceil());
      for (var iz = r0; iz <= r1; iz++) {
        final pz = minZ + iz * cell;
        for (var ix = c0; ix <= c1; ix++) {
          final px = minX + ix * cell;
          // 到"脚底—头顶"这条线段在 XZ 上投影的距离
          var t = segLen2 < 1e-9
              ? 0.0
              : ((px - ax) * segX + (pz - az) * segZ) / segLen2;
          if (t < 0) t = 0;
          if (t > 1) t = 1;
          final dx = px - (ax + segX * t);
          final dz = pz - (az + segZ * t);
          final d = sqrt(dx * dx + dz * dz);
          if (d >= r) continue;
          var v = 1.0 - d / r;
          v = v * v * (3 - 2 * v); // 边缘柔化
          final i = iz * w + ix;
          if (v > field[i]) field[i] = v;
        }
      }
    }

    // 一次 3x3 模糊，让影子边缘是软的
    final blurred = Float32List(w * h);
    for (var iz = 0; iz < h; iz++) {
      for (var ix = 0; ix < w; ix++) {
        var s = 0.0;
        var n = 0;
        for (var j = -1; j <= 1; j++) {
          final zz = iz + j;
          if (zz < 0 || zz >= h) continue;
          for (var k = -1; k <= 1; k++) {
            final xx = ix + k;
            if (xx < 0 || xx >= w) continue;
            s += field[zz * w + xx];
            n++;
          }
        }
        blurred[iz * w + ix] = s / n;
      }
    }

    _shadow = blurred;
    _shX0 = minX;
    _shZ0 = minZ;
    _shCell = cell;
    _shW = w;
    _shH = h;
  }

  /// 地面某点的阴影浓度：0 = 晒得到太阳，1 = 完全在阴影里
  double _aoAt(double x, double z) {
    final fld = _shadow;
    if (fld == null) return 0;
    final fx = (x - _shX0) / _shCell;
    final fz = (z - _shZ0) / _shCell;
    if (fx < 0 || fz < 0 || fx > _shW - 1.001 || fz > _shH - 1.001) return 0;
    final ix = fx.floor(), iz = fz.floor();
    final tx = fx - ix, tz = fz - iz;
    final i0 = iz * _shW + ix;
    final i1 = i0 + _shW;
    final a = fld[i0] * (1 - tx) + fld[i0 + 1] * tx;
    final b = fld[i1] * (1 - tx) + fld[i1 + 1] * tx;
    return a * (1 - tz) + b * tz;
  }

  static double _hash(int ix, int iz) {
    var h = ix * 374761393 + iz * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return (h & 0xFFFF) / 65535.0;
  }

  static double _hash3(double x, double y, double z) {
    final ix = (x * 57.0).round();
    final iy = (y * 57.0).round();
    final iz = (z * 57.0).round();
    return _hash(ix * 31 + iy, iz);
  }

  /// 平滑插值的 value noise（0~1）
  static double _valueNoise(double x, double z) {
    final x0 = x.floor(), z0 = z.floor();
    final fx = x - x0, fz = z - z0;
    final sx = fx * fx * (3 - 2 * fx);
    final sz = fz * fz * (3 - 2 * fz);
    final a = _hash(x0, z0), b = _hash(x0 + 1, z0);
    final c = _hash(x0, z0 + 1), d = _hash(x0 + 1, z0 + 1);
    return (a * (1 - sx) + b * sx) * (1 - sz) + (c * (1 - sx) + d * sx) * sz;
  }

  void clear(Color bg) {
    final al = (bg.a * 255).round();
    final r = (bg.r * 255).round();
    final g = (bg.g * 255).round();
    final b = (bg.b * 255).round();
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = r;
      pixels[i + 1] = g;
      pixels[i + 2] = b;
      pixels[i + 3] = al;
    }
    depth.fillRange(0, depth.length, double.infinity);
  }

  /// 渲染一帧：模型矩阵 × 视图矩阵 × 投影矩阵，然后光栅化 + 深度测试 + 光照
  void renderScene(List<MeshInstance> instances, Camera3D camera) {
    _buildGrid();
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
    // 顶点世界坐标（算光照与雾）
    final wa = model.transformPoint(tri.a);
    final wb = model.transformPoint(tri.b);
    final wc = model.transformPoint(tri.c);

    // 每个面一点点深浅抖动：一片叶子是一个面，不抖的话整片叶子同一个色，
    // 看着就是剪纸。抖动按面心位置哈希，稳定不闪。
    var base = tri.color;
    if (faceVariation > 0) {
      final cxw = (wa.x + wb.x + wc.x) / 3;
      final cyw = (wa.y + wb.y + wc.y) / 3;
      final czw = (wa.z + wb.z + wc.z) / 3;
      final v = 1.0 + (_hash3(cxw, cyw, czw) - 0.5) * 2 * faceVariation;
      base = Color.fromARGB(
        (base.a * 255).round(),
        ((base.r * v) * 255).round().clamp(0, 255),
        ((base.g * v) * 255).round().clamp(0, 255),
        ((base.b * v) * 255).round().clamp(0, 255),
      );
    }

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
        var ux = nx / nl, uy = ny / nl, uz = nz / nl;

        // 世界位置
        final wx = wa.x * b0 + wb.x * b1 + wc.x * b2;
        final wy = wa.y * b0 + wb.y * b1 + wc.y * b2;
        final wz = wa.z * b0 + wb.z * b1 + wc.z * b2;

        // ⑧ 光照：全部由法线算，没有写死的色值
        final vx = camPos.x - wx, vy = camPos.y - wy, vz = camPos.z - wz;
        final vlen = sqrt(vx * vx + vy * vy + vz * vz);

        // 双面光照：单面片（地形、路面、树叶）法线朝反了就翻过来，
        // 否则整片地面永远 N·L = 0，只剩 ambient，看着像没开灯
        if (twoSided && vlen > 1e-6 && ux * vx + uy * vy + uz * vz < 0) {
          ux = -ux;
          uy = -uy;
          uz = -uz;
        }

        double r, g, b;
        if (!lightingEnabled) {
          // 只有 ambient（对比图用）：所有面同一个亮度，看不出体积
          r = base.r * 0.62;
          g = base.g * 0.62;
          b = base.b * 0.62;
        } else {
          // 主光：max(0, N·L)
          var ndl = ux * lightDir.x + uy * lightDir.y + uz * lightDir.z;
          if (ndl < 0) ndl = 0;

          // 天光（朝上的面偏冷）/ 地面反弹（朝下的面偏暖）
          final up = uy > 0 ? uy : 0.0;
          final down = uy < 0 ? -uy : 0.0;

          final sun = ndl * sunIntensity;
          r = base.r * ambient +
              base.r * sun * lightColor.r +
              skyTint.r * up * skyStrength +
              groundTint.r * down * groundStrength;
          g = base.g * ambient +
              base.g * sun * lightColor.g +
              skyTint.g * up * skyStrength +
              groundTint.g * down * groundStrength;
          b = base.b * ambient +
              base.b * sun * lightColor.b +
              skyTint.b * up * skyStrength +
              groundTint.b * down * groundStrength;

          // Blinn-Phong 高光（只有朝光的面才有）
          if (specStrength > 0 && ndl > 0 && vlen > 0.0001) {
            final hx = (lightDir.x + vx / vlen) * 0.5;
            final hy = (lightDir.y + vy / vlen) * 0.5;
            final hz = (lightDir.z + vz / vlen) * 0.5;
            final hl = sqrt(hx * hx + hy * hy + hz * hz);
            final ndoth = (ux * hx + uy * hy + uz * hz) / hl;
            if (ndoth > 0) {
              final s = pow(ndoth, 26).toDouble() * specStrength;
              r += s;
              g += s;
              b += s;
            }
          }

          // 太阳投影 + 接触阴影：贴地的面（草、路、屋顶）落到影子里就压暗
          if (uy > 0.28 && (shadowStrength > 0 || aoStrength > 0)) {
            final sh = _aoAt(wx, wz);
            if (sh > 0) {
              final k = 1.0 - shadowStrength * sh;
              r *= k;
              g *= k;
              b *= k;
            }
          }

          // 材质噪声：草地/石板不该是一整块纯色
          if (noiseStrength > 0 && uy > 0.55) {
            final nA = _valueNoise(wx * 1.9, wz * 1.9);
            final nB = _valueNoise(wx * 0.42, wz * 0.42);
            final k = 1.0 +
                ((nA - 0.5) * 1.1 + (nB - 0.5) * 1.5) * noiseStrength;
            r *= k;
            g *= k;
            b *= k;
          }
        }

        // ⑨ 大气透视：远处降饱和 + 往雾色 lerp
        if (vlen > fogNear) {
          var t = (vlen - fogNear) / (fogFar - fogNear);
          if (t > 1) t = 1;
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          final ds = t * fogDesat;
          r += (lum - r) * ds;
          g += (lum - g) * ds;
          b += (lum - b) * ds;
          r += (fogColor.r - r) * t;
          g += (fogColor.g - g) * t;
          b += (fogColor.b - b) * t;
        }

        final o = idx * 4;
        pixels[o] = (r.clamp(0.0, 1.0) * 255).round();
        pixels[o + 1] = (g.clamp(0.0, 1.0) * 255).round();
        pixels[o + 2] = (b.clamp(0.0, 1.0) * 255).round();
        pixels[o + 3] = 255; // 画到的像素一定不透明
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