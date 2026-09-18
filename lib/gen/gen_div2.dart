import 'dart:math';
import '../models.dart';
import 'util.dart';

/// u4l1 用 7、8、9 的乘法口诀求商
List<Question> genDivFacts789(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 4; t++) {
    final a = ri(r, 4, 9);
    final b = ri(r, 4, 9);
    final p = a * b;
    if (stage == 0) {
      qs.add(inputQ(p.toString() + '÷' + a.toString() + '＝？', b,
          '想口诀"' + kouJue(a, b) + '"，所以 ' + p.toString() + '÷' + a.toString() + '=' + b.toString() + '。', 'u4l1'));
      qs.add(inputQ(p.toString() + '÷' + b.toString() + '＝？', a,
          '想口诀"' + kouJue(a, b) + '"，所以 ' + p.toString() + '÷' + b.toString() + '=' + a.toString() + '。', 'u4l1'));
    } else if (stage == 1) {
      final q = ri(r, 5, 9);
      final good = q * q;
      final side = (q - 1) * (q + 1);
      qs.add(choiceQ('商是 ' + q.toString() + ' 的算式是（　）', good.toString() + '÷' + q.toString(),
          [side.toString() + '÷' + (q - 1).toString(), side.toString() + '÷' + (q + 1).toString()],
          good.toString() + '÷' + q.toString() + '=' + q.toString() + '，口诀"' + kouJue(q, q) + '"。', 'u4l1', r: r));
      qs.add(inputQ('把口诀补充完整：八（　）七十二', 9, '八九七十二。', 'u4l1'));
    } else {
      qs.add(inputQ('72 除以 8，商是几？', 9, '八九七十二，72÷8=9。', 'u4l1'));
      final a2 = ri(r, 6, 9);
      final b2 = ri(r, 6, 9);
      qs.add(inputQ('两个数相乘的积是 ' + (a2 * b2).toString() + '，其中一个因数是 ' + a2.toString() + '，另一个是几？', b2,
          (a2 * b2).toString() + '÷' + a2.toString() + '=' + b2.toString() + '，想口诀"' + kouJue(a2, b2) + '"。', 'u4l1'));
    }
  }
  return dedupe(qs, 12);
}

/// u4l2 解决问题（含"倍"的认识）
List<Question> genDivStory2(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 3; t++) {
    final a = ri(r, 6, 9);
    final b = ri(r, 3, 9);
    final p = a * b;
    if (stage == 0) {
      final base = ri(r, 3, 9);
      final mult = ri(r, 2, 5);
      qs.add(inputQ('红花有 ' + base.toString() + ' 朵，黄花是红花的 ' + mult.toString() + ' 倍，黄花有多少朵？',
          base * mult, base.toString() + '×' + mult.toString() + '=' + (base * mult).toString() + '（朵）', 'u4l2'));
      qs.add(inputQ(p.toString() + ' 名同学做操，每行站 ' + a.toString() + ' 人，可以站几行？', b,
          p.toString() + '÷' + a.toString() + '=' + b.toString() + '（行）', 'u4l2'));
    } else if (stage == 1) {
      qs.add(inputQ('买 ' + a.toString() + ' 本书一共花了 ' + p.toString() + ' 元，平均每本书几元？', b,
          p.toString() + '÷' + a.toString() + '=' + b.toString() + '（元）', 'u4l2'));
      final base = ri(r, 4, 9);
      final mult = ri(r, 3, 8);
      qs.add(inputQ('甲数是 ' + base.toString() + '，乙数是甲数的 ' + mult.toString() + ' 倍，乙数是多少？',
          base * mult, base.toString() + '×' + mult.toString() + '=' + (base * mult).toString() + '，求一个数的几倍用乘法。', 'u4l2'));
    } else {
      final base = ri(r, 6, 9);
      final mult = ri(r, 2, 6);
      qs.add(inputQ('甲数是 ' + base.toString() + '，乙数是甲数的 ' + mult.toString() + ' 倍，乙数比甲数多多少？',
          base * (mult - 1), '乙数是 ' + (base * mult).toString() + '，比甲数多 ' + (base * mult - base).toString() + '。也可以想：多几倍就多几个 ' + base.toString() + '。', 'u4l2'));
      qs.add(inputQ(p.toString() + ' 里面有 ' + b.toString() + ' 个几？', a,
          p.toString() + '÷' + b.toString() + '=' + a.toString() + '。', 'u4l2'));
    }
  }
  return dedupe(qs, 9);
}
