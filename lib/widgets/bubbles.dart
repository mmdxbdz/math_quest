import 'package:flutter/material.dart';

/// 水泡泡样式：半透明渐变 + 高光弧 + 反光点 + 白色描边
class _WaterBubble extends StatelessWidget {
  final bool ok;
  final double size;
  final Widget child;
  const _WaterBubble({required this.ok, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = ok ? Colors.green : Colors.red;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.15,
          colors: ok
              ? [Colors.green.shade100, Colors.green.shade300, Colors.green.shade600]
              : [Colors.red.shade100, Colors.red.shade300, Colors.red.shade600],
          stops: const [0, 0.55, 1],
        ),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.85), width: 1.8),
        boxShadow: [
          BoxShadow(
              color: base.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Center(child: child),
          // 左上高光弧
          Positioned(
            top: size * 0.09,
            left: size * 0.14,
            child: Container(
              width: size * 0.36,
              height: size * 0.14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
            ),
          ),
          // 底部反光点
          Positioned(
            right: size * 0.16,
            bottom: size * 0.14,
            child: Container(
              width: size * 0.08,
              height: size * 0.08,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 点击答案时弹出的水泡泡：弹出 → 向上飘 → 淡出
class TapBubble extends StatelessWidget {
  final bool ok;

  /// 气泡直径（默认 46，比以前大）
  final double size;
  const TapBubble({super.key, required this.ok, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutBack,
      builder: (context, v, child) {
        final appear = (v * 5).clamp(0.0, 1.0); // 前 1/5 渐现
        final fade = ((1 - v) * 3).clamp(0.0, 1.0); // 后 1/3 渐隐
        final opacity = (appear * fade).clamp(0.0, 1.0);
        final scale = 0.4 + 0.7 * v;
        final rise = -40 * v; // 向上飘
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, rise),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: _WaterBubble(
        ok: ok,
        size: size,
        child: Icon(
          ok ? Icons.check : Icons.close,
          color: Colors.white,
          size: size * 0.5,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

/// 中央弹出的大水泡泡（答对/答错反馈），弹跳出现后淡出
class AnswerPop extends StatelessWidget {
  final bool ok;
  final String text;
  const AnswerPop({super.key, required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, v, child) {
        final scale = 0.5 + 0.5 * v;
        return Opacity(
          opacity: (v * 1.2).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: _WaterBubble(
        ok: ok,
        size: 130,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
              size: 42,
              shadows: const [
                Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// 庆祝粒子：从星星/徽章处迸出飘散
class PartyRow extends StatelessWidget {
  const PartyRow({super.key});

  @override
  Widget build(BuildContext context) {
    const parts = ['🎉', '✨', '🎊', '⭐'];
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < parts.length; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 700 + i * 180),
              curve: Curves.easeOut,
              builder: (context, v, child) {
                final spread = (i - (parts.length - 1) / 2) * 46;
                return Transform.translate(
                  offset: Offset(spread * v, -90 * v),
                  child: Transform.scale(
                    scale: 0.4 + 0.6 * v,
                    child: Opacity(
                      opacity: (1 - v).clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: Text(parts[i], style: const TextStyle(fontSize: 26)),
            ),
        ],
      ),
    );
  }
}
