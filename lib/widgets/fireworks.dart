import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../soundfx.dart';

/// 满屏烟花：火箭从底部上升，到顶点爆炸成彩色火花，受重力下落淡出。
/// 播完 [waves] 波后自动停止。
class Fireworks extends StatefulWidget {
  /// 烟花波数（波 = 一批火箭同时升空）
  final int waves;

  /// 每波火箭数量（越大越密）
  final int intensity;

  /// 波与波的间隔
  final Duration gap;

  const Fireworks({
    super.key,
    this.waves = 1,
    this.intensity = 3,
    this.gap = const Duration(milliseconds: 450),
  });

  @override
  State<Fireworks> createState() => _FireworksState();
}

class _Particle {
  double x, y, vx, vy;
  double age = 0;
  double life;
  Color color;
  double size;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
    this.size = 3,
  });
}

class _FireworksState extends State<Fireworks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final List<_Particle> _parts = [];
  final math.Random _rng = math.Random();
  int _waveCount = 0;
  int _lastWaveMs = 0;
  Size _lastSize = Size.zero;
  bool _boomFired = false; // 每波只响一声"嘭"

  static const _palette = [
    Color(0xFFFF5252), // 红
    Color(0xFFFF9100), // 橙
    Color(0xFFFFEA00), // 黄
    Color(0xFF69F0AE), // 绿
    Color(0xFF40C4FF), // 青
    Color(0xFF448AFF), // 蓝
    Color(0xFFE040FB), // 紫
    Color(0xFFFF4081), // 粉
    Color(0xFFFFFFFF), // 白
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _c.addListener(_tick);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tick() {
    final ms = _c.lastElapsedDuration?.inMilliseconds ?? 0;
    const dt = 0.016; // 约 60fps

    // 推进粒子
    final alive = <_Particle>[];
    for (final p in _parts) {
      p.age += dt;
      if (p.age >= p.life) continue;
      if (p.vx.abs() > 900 || p.y > _lastSize.height + 60) continue; // 出界
      if (p is _Rocket) {
        p.vy += 100 * dt; // 上升减速
        if (p.vy >= -70) {
          _explode(p);
          continue;
        }
      } else {
        p.vy += 240 * dt; // 重力
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      alive.add(p);
    }
    _parts
      ..clear()
      ..addAll(alive);

    // 发射新一波
    if (_waveCount < widget.waves &&
        ms - _lastWaveMs >= widget.gap.inMilliseconds) {
      _launchWave();
      _waveCount++;
      _lastWaveMs = ms;
    }

    // 播完且粒子清空后停止
    if (_waveCount >= widget.waves && _parts.isEmpty) {
      _c.stop();
    }

    if (mounted) setState(() {});
  }

  void _launchWave() {
    if (_lastSize.isEmpty) return;
    final w = _lastSize.width;
    final h = _lastSize.height;
    for (var i = 0; i < widget.intensity; i++) {
      _parts.add(_Rocket(
        x: 40 + _rng.nextDouble() * (w - 80),
        y: h + 10,
        vx: (_rng.nextDouble() - 0.5) * 60,
        vy: -420 - _rng.nextDouble() * 240,
        color: _palette[_rng.nextInt(_palette.length)],
        life: 3.0,
        size: 3.5,
      ));
    }
    // 火箭齐发："嗖"
    SoundFx.whoosh();
    _boomFired = false;
  }

  void _explode(_Rocket r) {
    if (!_boomFired) {
      _boomFired = true;
      SoundFx.boom(); // 第一颗爆炸："嘭"
    }
    final n = 18 + _rng.nextInt(12);
    final baseColor = r.color;
    for (var i = 0; i < n; i++) {
      final ang = (i / n) * 2 * math.pi + _rng.nextDouble() * 0.6;
      final speed = 90 + _rng.nextDouble() * 140;
      _parts.add(_Spark(
        x: r.x,
        y: r.y,
        vx: math.cos(ang) * speed,
        vy: math.sin(ang) * speed,
        color: _rng.nextBool()
            ? baseColor
            : _palette[_rng.nextInt(_palette.length)],
        life: 0.55 + _rng.nextDouble() * 0.55,
        size: 2.2 + _rng.nextDouble() * 2.2,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          painter: _FireworksPainter(_parts),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Rocket extends _Particle {
  _Rocket({
    required super.x,
    required super.y,
    required super.vx,
    required super.vy,
    required super.color,
    required super.life,
    super.size,
  });
}

class _Spark extends _Particle {
  _Spark({
    required super.x,
    required super.y,
    required super.vx,
    required super.vy,
    required super.color,
    required super.life,
    super.size,
  });
}

class _FireworksPainter extends CustomPainter {
  final List<_Particle> parts;
  _FireworksPainter(this.parts);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parts) {
      final t = (p.age / p.life).clamp(0.0, 1.0);
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.size * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) => true;
}
