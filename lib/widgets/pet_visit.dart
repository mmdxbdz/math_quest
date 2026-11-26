import 'dart:math';
import 'package:flutter/material.dart';
import '../pets.dart';
import '../soundfx.dart';

/// 会伸舌头舔屏幕的宠物（舔的程度 0~1 由外部动画驱动）
class PetFace extends StatelessWidget {
  /// 盒子比本体高出来的一截（留给舌头），摆位置时要算上
  static const double extraHeight = 0.30;

  final Pet pet;
  final double size;
  final double lick;
  final bool hungry;

  /// 动作姿势（走路 / 低头吃饭喝水 / 张嘴 / 睡觉），原样传给 PetAvatar
  final double pawPhase;
  final double dip;
  final bool eating;
  final bool drinking;
  final bool sleeping;
  final bool blink;

  const PetFace({
    super.key,
    required this.pet,
    required this.size,
    this.lick = 0,
    this.hungry = false,
    this.pawPhase = 0,
    this.dip = 0,
    this.eating = false,
    this.drinking = false,
    this.sleeping = false,
    this.blink = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = lick.clamp(0.0, 1.0);
    final tongueW = size * 0.16;
    final tongueH = size * (0.06 + 0.30 * l);
    return SizedBox(
      width: size,
      height: size * 1.30,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          PetAvatar(
            species: pet.species,
            stage: pet.stage,
            hatIndex: pet.hatIndex,
            size: size,
            pawPhase: pawPhase,
            dip: dip,
            eating: eating,
            drinking: drinking,
            sleeping: sleeping,
            blink: blink,
          ),
          // 舌头
          if (l > 0.02)
            Positioned(
              top: size * 0.60,
              child: Container(
                width: tongueW,
                height: tongueH,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF90A9), Color(0xFFFF6B8B)],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(tongueW * 0.1),
                    bottom: Radius.circular(tongueW * 0.55),
                  ),
                ),
              ),
            ),
          // 舌头上的一小滴口水
          if (l > 0.55)
            Positioned(
              top: size * 0.60 + tongueH + 1,
              child: Container(
                width: tongueW * 0.42,
                height: tongueW * 0.42,
                decoration: BoxDecoration(
                  color: const Color(0xFFBFE9FF),
                  borderRadius: BorderRadius.circular(tongueW),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 宠物自己跳出来，凑到屏幕跟前舔一口，然后跳走。
/// 全程不写一个字——只用动作和声音交流。
class PetVisitOverlay extends StatefulWidget {
  final Pet pet;
  final bool hungry;
  final VoidCallback? onTap;
  final VoidCallback? onDone;
  final bool loop;
  final double bottomInset;
  final double sizeFactor;
  final Duration duration;

  const PetVisitOverlay({
    super.key,
    required this.pet,
    this.hungry = false,
    this.onTap,
    this.onDone,
    this.loop = false,
    this.bottomInset = 108,
    this.sizeFactor = 0.5,
    this.duration = const Duration(milliseconds: 3400),
  });

  @override
  State<PetVisitOverlay> createState() => _PetVisitOverlayState();
}

class _PetVisitOverlayState extends State<PetVisitOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const List<double> _lickStart = [0.32, 0.50, 0.68];
  int _licked = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _c.addListener(_tick);
    if (widget.loop) {
      _c.repeat();
    } else {
      _c.forward();
    }
  }

  void _tick() {
    for (var i = _licked; i < _lickStart.length; i++) {
      if (_c.value >= _lickStart[i]) {
        _licked = i + 1;
        SoundFx.lick();
      }
    }
    if (!widget.loop && _c.isCompleted && !_finished) {
      _finished = true;
      widget.onDone?.call();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _lickAt(double t) {
    for (final s in _lickStart) {
      final p = (t - s) / 0.13;
      if (p > 0 && p < 1) return sin(p * pi);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return LayoutBuilder(builder: (context, c) {
          final size = min(c.maxWidth * widget.sizeFactor, 250.0);
          // 进场：从屏幕下面弹上来
          final enter = (t / 0.20).clamp(0.0, 1.0);
          final enterY = (1 - Curves.elasticOut.transform(enter)) * (size * 1.5);
          // 退场：跳下去（循环时不退场）
          final exit = widget.loop || t < 0.88
              ? 0.0
              : Curves.easeInBack.transform(((t - 0.88) / 0.12).clamp(0.0, 1.0));
          final exitY = exit * size * 1.6;
          final lick = _lickAt(t);
          final bob = sin(t * pi * 16) * 2.2;
          final hover = sin(t * pi * 8) * 2.0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 舔的时候整只往前凑一点
              Positioned(
                left: (c.maxWidth - size) / 2,
                bottom:
                    widget.bottomInset + enterY + exitY + bob + lick * 10,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Transform.scale(
                    scale: 1 + 0.10 * lick,
                    child: PetFace(
                      pet: widget.pet,
                      size: size,
                      lick: lick,
                      hungry: widget.hungry,
                    ),
                  ),
                ),
              ),
              // 舔的时候冒出来的爱心
              for (var i = 0; i < _lickStart.length; i++)
                ..._hearts(t, _lickStart[i], c.maxWidth, size),
              // 饿了：头顶飘一份它爱吃的东西
              if (widget.hungry)
                Positioned(
                  left: (c.maxWidth - size) / 2 + size * 0.72,
                  bottom: widget.bottomInset + enterY + size * 0.95 + hover,
                  child: Transform.rotate(
                    angle: sin(t * pi * 10) * 0.18,
                    child: Text(widget.pet.species.food,
                        style: TextStyle(fontSize: size * 0.26)),
                  ),
                ),
            ],
          );
        });
      },
    );
  }

  List<Widget> _hearts(
      double t, double start, double width, double size) {
    final p = (t - start) / 0.30;
    if (p <= 0 || p >= 1) return const [];
    final out = <Widget>[];
    for (var i = 0; i < 3; i++) {
      final pp = (p - i * 0.10).clamp(0.0, 1.0);
      if (pp <= 0) continue;
      final dx = (i - 1) * size * 0.22 + sin(pp * pi) * 10 * (i - 1);
      out.add(Positioned(
        left: (width - size) / 2 + size * 0.55 + dx,
        bottom: 108 + size * 0.72 + pp * size * 0.7,
        child: Opacity(
          opacity: (1 - pp).clamp(0.0, 1.0),
          child: Text(
            ['❤️', '💗', '💛'][i],
            style: TextStyle(fontSize: size * (0.16 + 0.05 * i)),
          ),
        ),
      ));
    }
    return out;
  }
}