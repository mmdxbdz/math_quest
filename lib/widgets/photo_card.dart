import 'dart:math';
import 'package:flutter/material.dart';
import '../pets.dart';
import '../speech.dart';

/// 和宠物的合影画：不用相机，直接画一张（雪地 + 小女孩 + 北极熊）
class PhotoScene extends StatelessWidget {
  final Pet pet;
  final double width;
  final double height;
  final bool frame;

  const PhotoScene({
    super.key,
    required this.pet,
    required this.width,
    required this.height,
    this.frame = true,
  });

  @override
  Widget build(BuildContext context) {
    final pad = frame ? width * 0.055 : 0.0;
    final innerW = width - pad * 2;
    final innerH = height - pad * 2;
    final scene = ClipRect(
      child: SizedBox(
        width: innerW,
        height: innerH,
        child: Stack(
          children: [
            // 天空
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFBFE9FF), Color(0xFFF4FBFF)],
                  ),
                ),
              ),
            ),
            // 雪花
            for (final p in const [
              [0.12, 0.10],
              [0.78, 0.06],
              [0.46, 0.16],
              [0.88, 0.26],
              [0.22, 0.30],
            ])
              Positioned(
                left: innerW * p[0],
                top: innerH * p[1],
                child: Text('❄️',
                    style: TextStyle(fontSize: innerH * 0.075)),
              ),
            // 雪地
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: innerH * 0.34,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFFFFF), Color(0xFFE2F3FF)],
                  ),
                ),
              ),
            ),
            // 雪堆
            Positioned(
              left: innerW * 0.06,
              right: innerW * 0.06,
              bottom: innerH * 0.20,
              child: Container(
                height: innerH * 0.12,
                decoration: const BoxDecoration(
                  color: Color(0xFFF2FAFF),
                  borderRadius: BorderRadius.all(Radius.elliptical(200, 40)),
                ),
              ),
            ),
            // 小女孩
            Positioned(
              left: innerW * 0.10,
              bottom: innerH * 0.10,
              child: CustomPaint(
                size: Size(innerW * 0.36, innerH * 0.62),
                painter: _KidPainter(),
              ),
            ),
            // 北极熊
            Positioned(
              right: innerW * 0.04,
              bottom: innerH * 0.06,
              child: PetAvatar(
                species: pet.species,
                stage: pet.stage,
                hatIndex: pet.hatIndex,
                size: innerH * 0.52,
              ),
            ),
            // 爱心
            for (final (fx, fy, icon) in const [
              (0.46, 0.42, '❤️'),
              (0.58, 0.30, '💛'),
              (0.36, 0.28, '💗'),
            ])
              Positioned(
                left: innerW * fx,
                top: innerH * fy,
                child: Text(icon, style: TextStyle(fontSize: innerH * 0.10)),
              ),
          ],
        ),
      ),
    );

    if (!frame) return scene;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: width * 0.10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.03),
        child: scene,
      ),
    );
  }
}

/// 弹出合影卡
Future<void> showPhotoCard(BuildContext context, Pet pet) {
  Speech.say(photoMoment());
  final mq = MediaQuery.of(context);
  final cardW = (mq.size.width * 0.78).clamp(240.0, 360.0);
  final sceneW = cardW - cardW * 0.10;
  final now = DateTime.now();
  final date = now.year.toString() +
      '年' +
      now.month.toString() +
      '月' +
      now.day.toString() +
      '日';
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
                cardW * 0.05, cardW * 0.05, cardW * 0.05, cardW * 0.07),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF8),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhotoScene(
                  pet: pet,
                  width: sceneW,
                  height: sceneW * 1.12,
                  frame: false,
                ),
                const SizedBox(height: 10),
                Text(
                  '我和' + pet.name + '的合影',
                  style: TextStyle(
                    fontSize: cardW * 0.058,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B4A2B),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('❤️', style: TextStyle(fontSize: cardW * 0.045)),
                    const SizedBox(width: 5),
                    Text(
                      date,
                      style: TextStyle(
                          fontSize: cardW * 0.036, color: Colors.black54),
                    ),
                    const SizedBox(width: 5),
                    Text('❄️', style: TextStyle(fontSize: cardW * 0.045)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6B4A2B),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('收好啦'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 画一个扎着两个小揪揪的小女孩
class _KidPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final cx = w * 0.5;

    final skinPaint = Paint()..color = const Color(0xFFFFDFC2);
    final hairPaint = Paint()..color = const Color(0xFF6B4630);
    final dressPaint = Paint()..color = const Color(0xFFFF9DB5);
    final dressDark = Paint()..color = const Color(0xFFF0799A);
    final shoePaint = Paint()..color = const Color(0xFF4A3A33);
    final darkPaint = Paint()..color = const Color(0xFF3A2A22);
    final blushPaint = Paint()..color = const Color(0xFFFF8FA8);

    final headR = w * 0.26;
    final headCy = h * 0.26;

    // 腿
    final legPaint = Paint()
      ..color = const Color(0xFFFFDFC2)
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - w * 0.10, h * 0.70),
        Offset(cx - w * 0.12, h * 0.93), legPaint);
    canvas.drawLine(Offset(cx + w * 0.10, h * 0.70),
        Offset(cx + w * 0.12, h * 0.93), legPaint);
    // 小鞋子
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx - w * 0.13, h * 0.95),
            width: w * 0.20,
            height: h * 0.075),
        shoePaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx + w * 0.13, h * 0.95),
            width: w * 0.20,
            height: h * 0.075),
        shoePaint);

    // 裙子
    final dress = Path()
      ..moveTo(cx - headR * 0.72, headCy + headR * 1.02)
      ..lineTo(cx + headR * 0.72, headCy + headR * 1.02)
      ..quadraticBezierTo(cx + headR * 1.25, h * 0.58, cx + headR * 1.18,
          h * 0.74)
      ..quadraticBezierTo(cx, h * 0.79, cx - headR * 1.18, h * 0.74)
      ..quadraticBezierTo(cx - headR * 1.25, h * 0.58,
          cx - headR * 0.72, headCy + headR * 1.02)
      ..close();
    canvas.drawPath(dress, dressPaint);
    // 裙摆
    canvas.drawPath(
      Path()
        ..moveTo(cx - headR * 1.18, h * 0.74)
        ..quadraticBezierTo(cx, h * 0.79, cx + headR * 1.18, h * 0.74)
        ..lineTo(cx + headR * 1.10, h * 0.68)
        ..quadraticBezierTo(cx, h * 0.73, cx - headR * 1.10, h * 0.68)
        ..close(),
      dressDark,
    );

    // 手臂（右手伸向小熊）
    final armPaint = Paint()
      ..color = const Color(0xFFFFDFC2)
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx - headR * 0.65, headCy + headR * 1.15),
        Offset(cx - headR * 1.45, headCy + headR * 1.75),
        armPaint);
    canvas.drawLine(
        Offset(cx + headR * 0.65, headCy + headR * 1.15),
        Offset(cx + headR * 1.55, headCy + headR * 1.65),
        armPaint);

    // 头发（后脑 + 两个小揪揪）
    canvas.drawCircle(Offset(cx, headCy), headR * 1.12, hairPaint);
    canvas.drawCircle(
        Offset(cx - headR * 1.18, headCy - headR * 0.35), headR * 0.42,
        hairPaint);
    canvas.drawCircle(
        Offset(cx + headR * 1.18, headCy - headR * 0.35), headR * 0.42,
        hairPaint);

    // 脸
    canvas.drawCircle(Offset(cx, headCy), headR, skinPaint);

    // 刘海
    canvas.drawPath(
      Path()
        ..moveTo(cx - headR, headCy - headR * 0.18)
        ..quadraticBezierTo(cx - headR * 0.5, headCy - headR * 1.18,
            cx + headR * 0.05, headCy - headR * 0.95)
        ..quadraticBezierTo(cx + headR * 0.7, headCy - headR * 1.18, cx + headR,
            headCy - headR * 0.15)
        ..quadraticBezierTo(cx, headCy - headR * 0.70,
            cx - headR, headCy - headR * 0.18)
        ..close(),
      hairPaint,
    );

    // 眼睛
    canvas.drawCircle(
        Offset(cx - headR * 0.36, headCy + headR * 0.05), headR * 0.11,
        darkPaint);
    canvas.drawCircle(
        Offset(cx + headR * 0.36, headCy + headR * 0.05), headR * 0.11,
        darkPaint);
    // 笑脸
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, headCy + headR * 0.34),
          width: headR * 0.62,
          height: headR * 0.52),
      0.15 * pi,
      0.7 * pi,
      false,
      darkPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.10
        ..strokeCap = StrokeCap.round,
    );
    // 腮红
    canvas.drawCircle(
        Offset(cx - headR * 0.62, headCy + headR * 0.34), headR * 0.17,
        blushPaint);
    canvas.drawCircle(
        Offset(cx + headR * 0.62, headCy + headR * 0.34), headR * 0.17,
        blushPaint);
  }

  @override
  bool shouldRepaint(covariant _KidPainter oldDelegate) => false;
}

/// 合影卡在房间里的小缩略图
class PhotoThumb extends StatelessWidget {
  final Pet pet;
  final double size;

  const PhotoThumb({super.key, required this.pet, required this.size});

  @override
  Widget build(BuildContext context) {
    return PhotoScene(
      pet: pet,
      width: size,
      height: size * 1.18,
      frame: true,
    );
  }
}

/// 随机的合影祝福语（点相框时用）
String photoMoment() {
  const lines = [
    '咔嚓！这是我和主人的合影～',
    '我要把这张照片挂在墙上，天天看！',
    '主人笑一个，我们再拍一张！',
  ];
  return lines[Random().nextInt(lines.length)];
}