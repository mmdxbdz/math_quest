import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../render3d/render3d.dart';

/// 3D 渲染验证场景：一个立方体 + 一个球 + 一块地面。
/// 手指左右拖 = 相机绕 Y 轴转圈，上下拖 = 俯仰。
/// 相机是 position / target / fov 对象，改它整个画面跟着变（没有 translate 假装）。
class Demo3D extends StatefulWidget {
  const Demo3D({super.key});

  @override
  State<Demo3D> createState() => _Demo3DState();
}

class _Demo3DState extends State<Demo3D> {
  double _yaw = 0.55;
  double _pitch = 0.30;
  final double _radius = 7.2;

  ui.Image? _image;
  bool _rendering = false;
  bool _pending = false;
  int _tris = 0;

  static const Color _bg = Color(0xFFBDE4F7);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  /// 场景：地面平面 + 立方体 + 球
  List<MeshInstance> _buildScene() => [
        MeshInstance(
          Mesh.plane(26, tiles: 13, color: const Color(0xFF86C862)),
          M4.identity(),
        ),
        MeshInstance(
          Mesh.cube(
            1.7,
            color: const Color(0xFFE9A23B),
            top: const Color(0xFFFFC46B),
            side: const Color(0xFFD98A28),
          ),
          M4.translate(const V3(-1.7, 0.85, 0.5)),
        ),
        MeshInstance(
          Mesh.sphere(1.15, color: const Color(0xFF4C9FE0)),
          M4.translate(const V3(1.9, 1.15, -0.9)),
        ),
      ];

  Future<void> _render() async {
    if (_rendering) {
      _pending = true;
      return;
    }
    final box = context.size;
    if (box == null || box.isEmpty) return;
    _rendering = true;

    // 渲染分辨率略低于屏幕：软件光栅器在手机上要留余量
    final w = (box.width * 0.75).round().clamp(120, 720);
    final h = (box.height * 0.75).round().clamp(160, 1280);

    final scene = _buildScene();
    final camera = Camera3D.orbit(
      target: const V3(0, 1.05, 0),
      radius: _radius,
      yaw: _yaw,
      pitch: _pitch,
      fovY: 0.95,
    );

    final raster = Rasterizer3D(
      width: w,
      height: h,
      lightDir: const V3(-0.55, 0.78, 0.42),
      ambient: 0.30,
      fogNear: 15,
      fogFar: 34,
      skyColor: _bg,
    );
    raster.clear(_bg);
    raster.renderScene(scene, camera);

    final img = await raster.toImage();
    if (!mounted) {
      _rendering = false;
      return;
    }
    setState(() {
      _image?.dispose();
      _image = img;
      _tris = scene.fold<int>(0, (s, m) => s + m.mesh.tris.length);
      _rendering = false;
    });
    if (_pending) {
      _pending = false;
      unawaited(_render());
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('3D 渲染验证'),
        backgroundColor: Colors.white.withValues(alpha: 0.9),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          setState(() {
            _yaw -= d.delta.dx * 0.010;
            _pitch = (_pitch + d.delta.dy * 0.006).clamp(-0.9, 1.35);
          });
          _render();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_image != null)
              RawImage(image: _image, fit: BoxFit.fill)
            else
              const Center(child: CircularProgressIndicator()),
            Positioned(
              left: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'yaw ' +
                        (_yaw * 180 / 3.14159).round().toString() +
                        '°  pitch ' +
                        (_pitch * 180 / 3.14159).round().toString() +
                        '°  ' +
                        _tris.toString() +
                        ' 三角形',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '左右拖 = 绕 Y 轴转圈 · 上下拖 = 俯仰',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}