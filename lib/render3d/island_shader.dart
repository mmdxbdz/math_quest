import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 是否使用 GPU（SDF 光线步进）渲染。测试环境没有 GPU，测试里会关掉。
bool kUseGpuIsland = true;

/// 着色器里的岛 = 这份 Dart 布局，两边必须一致，
/// 这样 2D 的数字牌才能正好贴在 3D 平台上。
class IslandLayout {
  static const double radius = 7.4;
  static const double topHeight = 3.55;
  static const double spiralStart = -1.5708;
  static const double spiralTurns = 9.2;

  static double smoothstep(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// 岛的解析高度（不含噪声），和 shader 的 islandBase 一致
  static double baseHeight(double x, double z) {
    final r = sqrt(x * x + z * z);
    var mound = topHeight * (1 - smoothstep(1.1, radius, r));
    mound += 0.45 * (1 - smoothstep(0.0, 5.2, r));
    return max(0.0, mound);
  }

  /// 第 i 个关卡平台在世界里的位置（和 shader 的 platformPos 一致）
  static Offset platformXZ(int i, int count) {
    final n = max(count - 1, 1);
    final t = i / n;
    final ang = spiralStart + t * spiralTurns;
    final r = radius - 1.0 + (1.15 - (radius - 1.0)) * t;
    return Offset(cos(ang) * r, sin(ang) * r);
  }

  static Vector3 platformPos(int i, int count) {
    final xz = platformXZ(i, count);
    return Vector3(xz.dx, baseHeight(xz.dx, xz.dy) + 0.30, xz.dy);
  }

  /// 椰子树在沙滩上的位置（和 shader 一致）
  static const List<List<double>> trunks = [
    [-5.6, 2.1],
    [-4.4, -3.4],
    [5.2, -2.4],
    [4.6, 3.6],
    [-0.9, 5.9],
    [1.9, -6.0],
  ];
}

class Vector3 {
  final double x, y, z;
  const Vector3(this.x, this.y, this.z);
}

/// 相机（beauty shot：绕岛转 + 俯仰）
class IslandCamera {
  final double yaw;
  final double pitch;
  final double radius;
  final double fovTan;
  final Vector3 target;

  const IslandCamera({
    this.yaw = 0.62,
    this.pitch = 0.40,
    this.radius = 16.5,
    this.fovTan = 0.55,
    this.target = const Vector3(0, 2.05, 0),
  });

  IslandCamera copyWith({double? yaw, double? pitch, double? radius}) =>
      IslandCamera(
        yaw: yaw ?? this.yaw,
        pitch: (pitch ?? this.pitch).clamp(-0.15, 1.25),
        radius: radius ?? this.radius,
        fovTan: fovTan,
        target: target,
      );

  Vector3 get position => Vector3(
        target.x + radius * cos(pitch) * sin(yaw),
        target.y + radius * sin(pitch),
        target.z + radius * cos(pitch) * cos(yaw),
      );

  /// 把世界坐标点投影到屏幕（数字牌用）
  ({Offset at, double depth, double pixelsPerUnit})? project(
      Vector3 p, Size size) {
    final eye = position;
    // forward
    final fx = target.x - eye.x, fy = target.y - eye.y, fz = target.z - eye.z;
    final fl = sqrt(fx * fx + fy * fy + fz * fz);
    final wx = fx / fl, wy = fy / fl, wz = fz / fl;
    // right = normalize(cross(forward, (0,1,0))) = normalize((-fz, 0, fx))
    var rx = -wz, rz = wx;
    final rl = sqrt(rx * rx + rz * rz);
    rx /= rl;
    rz /= rl;
    const ry = 0.0;
    // up' = cross(right, forward)
    final ux = ry * wz - rz * wy;
    final uy = rz * wx - rx * wz;
    final uz = rx * wy - ry * wx;

    final dx = p.x - eye.x, dy = p.y - eye.y, dz = p.z - eye.z;
    final vz = dx * wx + dy * wy + dz * wz;
    if (vz <= 0.001) return null;
    final vx = dx * rx + dy * ry + dz * rz;
    final vy = dx * ux + dy * uy + dz * uz;

    final sx = size.width / 2 + (vx / vz) / (fovTan * 2) * size.height;
    final sy = size.height / 2 - (vy / vz) / (fovTan * 2) * size.height;
    return (
      at: Offset(sx, sy),
      depth: vz,
      pixelsPerUnit: size.height / (2 * vz * fovTan),
    );
  }
}

/// 用 SDF 着色器画整座岛：天空 / 海面 / 岛 / 软阴影 / AO 全在 GPU 上，逐像素
class IslandShaderView extends StatefulWidget {
  final IslandCamera camera;
  final int levels;
  final void Function(Object error)? onFailed;

  const IslandShaderView({
    super.key,
    required this.camera,
    this.levels = 8,
    this.onFailed,
  });

  @override
  State<IslandShaderView> createState() => _IslandShaderViewState();
}

class _IslandShaderViewState extends State<IslandShaderView>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  Ticker? _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);

  static const Vector3 _sun = Vector3(-0.45, 0.80, -0.40);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/island.frag');
      if (!mounted) return;
      final shader = program.fragmentShader();
      setState(() => _shader = shader);
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      widget.onFailed?.call(e);
      setState(() {});
    }
  }

  void _startTicker() {
    final start = DateTime.now();
    _ticker = createTicker((_) {
      _time.value = DateTime.now().difference(start).inMilliseconds / 1000.0;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  void _setUniforms(ui.FragmentShader s, Size size) {
    final cam = widget.camera;
    final eye = cam.position;
    var i = 0;
    s.setFloat(i++, size.width);
    s.setFloat(i++, size.height);
    s.setFloat(i++, eye.x);
    s.setFloat(i++, eye.y);
    s.setFloat(i++, eye.z);
    s.setFloat(i++, cam.target.x);
    s.setFloat(i++, cam.target.y);
    s.setFloat(i++, cam.target.z);
    s.setFloat(i++, cam.fovTan);
    s.setFloat(i++, _time.value);
    s.setFloat(i++, 0.0); // uFocus
    s.setFloat(i++, widget.levels.toDouble());
    s.setFloat(i++, _sun.x);
    s.setFloat(i++, _sun.y);
    s.setFloat(i++, _sun.z);
    s.setFloat(i++, 1.0); // 太阳强度
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      if (_shader == null) {
        return const SizedBox.expand();
      }
      return ValueListenableBuilder<double>(
        valueListenable: _time,
        builder: (context, t, _) => CustomPaint(
          size: size,
          painter: _ShaderPainter(
            shader: _shader!,
            camera: widget.camera,
            levels: widget.levels,
            time: t,
            setUniforms: _setUniforms,
          ),
        ),
      );
    });
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final IslandCamera camera;
  final int levels;
  final double time;
  final void Function(ui.FragmentShader, Size) setUniforms;

  _ShaderPainter({
    required this.shader,
    required this.camera,
    required this.levels,
    required this.time,
    required this.setUniforms,
  });

  @override
  void paint(Canvas canvas, Size size) {
    setUniforms(shader, size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      old.time != time ||
      old.camera.yaw != camera.yaw ||
      old.camera.pitch != camera.pitch ||
      old.levels != levels;
}