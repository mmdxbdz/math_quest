import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 是否使用 GPU（SDF 光线步进）渲染。测试环境没有 GPU，测试里会关掉。
bool kUseGpuIsland = false;

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
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _frame;
  Ticker? _ticker;

  Size _want = Size.zero;
  double _time = 0;
  bool _rendering = false;
  bool _dead = false;
  int _slowFrames = 0;
  double _lastRenderAt = -1;

  /// 离屏渲染宽度（再放大到全屏）。手机上这是性能的关键：
  /// 300 宽 ≈ 195k 像素，足够黏土风的柔和画面。
  static const double _offscreenWidth = 300;

  /// 水波刷新间隔（秒）：不需要 60fps
  static const double _refreshEvery = 0.09;

  /// 一帧超过这个毫秒数就认为这块 GPU 扛不住
  static const int _slowFrameMs = 150;

  static const Vector3 _sun = Vector3(-0.45, 0.80, -0.40);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/island.frag');
      if (!mounted) {
        return;
      }
      setState(() {
        _program = program;
        _shader = program.fragmentShader();
      });
      _ticker = createTicker((_) {
        _time += 1.0 / 60.0;
        _schedule();
      })..start();
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    if (_dead) return;
    _dead = true;
    _ticker?.dispose();
    _ticker = null;
    widget.onFailed?.call(e);
  }

  @override
  void didUpdateWidget(IslandShaderView old) {
    super.didUpdateWidget(old);
    if (old.camera != widget.camera || old.levels != widget.levels) {
      // 相机变了立刻重画
      _lastRenderAt = -1;
      _schedule();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _schedule() {
    if (_dead || _rendering || _program == null) return;
    if (_want.isEmpty) return;
    if (_lastRenderAt > 0 && _time - _lastRenderAt < _refreshEvery) return;
    _render();
  }

  void _setUniforms(ui.FragmentShader s, double w, double h) {
    final cam = widget.camera;
    final eye = cam.position;
    final t = cam.target;
    // uA = (w, h, time, fovTan)
    s.setFloat(0, w);
    s.setFloat(1, h);
    s.setFloat(2, _time);
    s.setFloat(3, cam.fovTan);
    // uB = (cam.xyz, levels)
    s.setFloat(4, eye.x);
    s.setFloat(5, eye.y);
    s.setFloat(6, eye.z);
    s.setFloat(7, widget.levels.toDouble());
    // uC = (target.xyz, unused)
    s.setFloat(8, t.x);
    s.setFloat(9, t.y);
    s.setFloat(10, t.z);
    s.setFloat(11, 0.0);
    // uD = (sun.xyz, power)
    s.setFloat(12, _sun.x);
    s.setFloat(13, _sun.y);
    s.setFloat(14, _sun.z);
    s.setFloat(15, 1.0);
  }

  Future<void> _render() async {
    final shader = _shader;
    if (shader == null || _want.isEmpty) return;
    _rendering = true;
    _lastRenderAt = _time;

    final w = _offscreenWidth.round();
    final h = (w * _want.height / _want.width).round().clamp(96, 1200);

    final sw = Stopwatch()..start();
    ui.Image? img;
    ui.Picture? pic;
    try {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, Offset.zero & Size(w * 1.0, h * 1.0));
      _setUniforms(shader, w * 1.0, h * 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w * 1.0, h * 1.0),
        Paint()..shader = shader,
      );
      pic = rec.endRecording();
      img = await pic.toImage(w, h);
      sw.stop();
      if (!mounted) {
        img.dispose();
        return;
      }
      // 太慢就自动认输，退回 CPU 版本，绝不把 App 拖死
      if (sw.elapsedMilliseconds > _slowFrameMs) {
        _slowFrames++;
        if (_slowFrames >= 3) {
          img.dispose();
          _fail('着色器一帧 ${sw.elapsedMilliseconds}ms，太慢');
          return;
        }
      } else {
        _slowFrames = 0;
      }
      final old = _frame;
      setState(() => _frame = img);
      old?.dispose();
    } catch (e) {
      _fail(e);
    } finally {
      pic?.dispose();
      _rendering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _want = Size(c.maxWidth, c.maxHeight);
      if (_frame == null) {
        // 还没画出来：给一片天空色，不要闪白
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6BC0EC), Color(0xFFDDEEF7)],
            ),
          ),
          child: SizedBox.expand(),
        );
      }
      return CustomPaint(
        size: _want,
        painter: _FramePainter(_frame!),
        isComplex: true,
      );
    });
  }
}

/// 把离屏渲染的图放大铺满
class _FramePainter extends CustomPainter {
  final ui.Image image;
  const _FramePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => !identical(old.image, image);
}