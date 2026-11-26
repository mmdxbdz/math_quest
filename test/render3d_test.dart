import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/render3d/render3d.dart';

const Color kBg = Color(0xFFBDE4F7);

List<MeshInstance> demoScene() => [
      MeshInstance(
        Mesh.plane(26, tiles: 13, color: const Color(0xFF86C862)),
        M4.identity(),
      ),
      MeshInstance(
        Mesh.cube(1.7,
            color: const Color(0xFFE9A23B),
            top: const Color(0xFFFFC46B),
            side: const Color(0xFFD98A28)),
        M4.translate(const V3(-1.7, 0.85, 0.5)),
      ),
      MeshInstance(
        Mesh.sphere(1.15, color: const Color(0xFF4C9FE0)),
        M4.translate(const V3(1.9, 1.15, -0.9)),
      ),
    ];

Rasterizer3D rasterFor(int w, int h) {
  final r = Rasterizer3D(
    width: w,
    height: h,
    lightDir: const V3(-0.55, 0.78, 0.42),
    ambient: 0.30,
    fogNear: 15,
    fogFar: 34,
    skyColor: kBg,
  )..clear(kBg);
  return r;
}

/// 数"不是背景色"的像素：物体在屏幕上占了多少
int countNotBackground(Uint8List px) {
  var n = 0;
  for (var i = 0; i < px.length; i += 4) {
    if ((px[i] - 0xBD).abs() > 14 ||
        (px[i + 1] - 0xE4).abs() > 14 ||
        (px[i + 2] - 0xF7).abs() > 14) n++;
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('4x4 矩阵：视图矩阵和投影矩阵把点送到该去的地方', () {
    // 相机在 (0,0,5) 看向原点：世界原点的视图坐标应是 (0,0,-5)
    final view = M4.lookAt(eye: const V3(0, 0, 5), target: V3.zero);
    final p = view.transformPoint(V3.zero);
    expect(p.x, closeTo(0, 1e-9));
    expect(p.y, closeTo(0, 1e-9));
    expect(p.z, closeTo(-5, 1e-9));
    expect(p.w, closeTo(1, 1e-9));

    // 投影：视野正中的点在 NDC 中心；近的点 w 小、远的点 w 大
    final proj = M4.perspective(fovY: 1.0, aspect: 1.5, near: 0.1, far: 100);
    final nearPoint = proj.transformPoint(const V3(0, 0, -5));
    final farPoint = proj.transformPoint(const V3(0, 0, -10));
    expect(nearPoint.x / nearPoint.w, closeTo(0, 1e-9));
    expect(nearPoint.y / nearPoint.w, closeTo(0, 1e-9));
    // 透视除法之后：远处的东西在屏幕上更靠近屏幕中心
    final nearNdcZ = nearPoint.z / nearPoint.w;
    final farNdcZ = farPoint.z / farPoint.w;
    expect(farNdcZ, greaterThan(nearNdcZ), reason: 'NDC z 随距离单调增');
    expect(farPoint.w, greaterThan(nearPoint.w), reason: 'w 就是深度');
  });

  test('透视除法成立：同一个立方体距离翻倍，屏幕面积约变成 1/4', () {
    final cube = Mesh.cube(1.6, color: const Color(0xFFE03030));
    // 两种距离，相机焦距固定
    int pixelsAt(double z) {
      final r = rasterFor(240, 240);
      r.renderScene(
        [MeshInstance(cube, M4.translate(V3(0, 0, -z)))],
        const Camera3D(position: V3.zero, target: V3(0, 0, -1), fovY: 1.0),
      );
      return countNotBackground(r.pixels);
    }

    final near = pixelsAt(4);
    final far = pixelsAt(8);
    expect(near, greaterThan(0));
    // 距离 ×2 → 线性尺寸 ÷2 → 面积 ÷4（允许 25% 误差，因为有光照与边缘像素）
    final ratio = near / far;
    expect(ratio, greaterThan(3.0));
    expect(ratio, lessThan(6.0));
  });

  test('Z-buffer：近的方块挡住远的方块', () {
    final r = rasterFor(200, 200);
    // 两块一样大的片子，红的近、蓝的远，屏幕上重叠
    Mesh quad(Color c) => Mesh([
          Tri3D(const V3(-1, -1, 0), const V3(1, -1, 0), const V3(1, 1, 0),
              const V3(0, 0, 1), const V3(0, 0, 1), const V3(0, 0, 1), c),
          Tri3D(const V3(-1, -1, 0), const V3(1, 1, 0), const V3(-1, 1, 0),
              const V3(0, 0, 1), const V3(0, 0, 1), const V3(0, 0, 1), c),
        ]);
    r.renderScene([
      MeshInstance(quad(const Color(0xFF3050E0)), M4.translate(const V3(0, 0, -6))),
      MeshInstance(quad(const Color(0xFFE03030)), M4.translate(const V3(0, 0, -3))),
    ], const Camera3D(position: V3.zero, target: V3(0, 0, -1), fovY: 1.0));

    // 画面正中的像素必须是近处那块（红）
    final o = ((100 * 200) + 100) * 4;
    expect(r.pixels[o], greaterThan(r.pixels[o + 2] + 40),
        reason: '近的红块应该盖住远的蓝块');
  });

  test('四种相机角度渲染出四张真正不同的图，并写成 PNG', () async {
    const w = 420, h = 560;
    final images = <Uint8List>[];
    for (var i = 0; i < 4; i++) {
      final yaw = i * pi / 2; // 0° / 90° / 180° / 270°
      final r = rasterFor(w, h);
      r.renderScene(
        demoScene(),
        Camera3D.orbit(
          target: const V3(0, 1.05, 0),
          radius: 7.2,
          yaw: yaw,
          pitch: 0.30,
          fovY: 0.95,
        ),
      );
      images.add(Uint8List.fromList(r.pixels));

      final img = await r.toImage();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/preview');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('build/preview/demo3d_${i * 90}deg.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
    }

    // 两两比较：轮廓/遮挡不同 → 像素差异必须很大（换位置糊弄是过不了的）
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        var diff = 0;
        final a = images[i], b = images[j];
        for (var k = 0; k < a.length; k += 4) {
          if ((a[k] - b[k]).abs() > 12 ||
              (a[k + 1] - b[k + 1]).abs() > 12 ||
              (a[k + 2] - b[k + 2]).abs() > 12) diff++;
        }
        final ratio = diff / (w * h);
        expect(ratio, greaterThan(0.12),
            reason: '第 ${i * 90}° 和第 ${j * 90}° 的画面差异只有 '
                '${(ratio * 100).toStringAsFixed(1)}%，像同一张图挪了位置');
      }
    }
  });
}