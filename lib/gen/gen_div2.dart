import 'dart:math';
import '../models.dart';
import 'util.dart';

/// u4l1 用 7、8、9 的乘法口诀求商
List<Question> genDivFacts789(Random r, int stage) {
  final qs = <Question>[];
  const cn = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  for (var t = 0; t < 24; t++) {
    final a = ri(r, 4, 9);
    final b = ri(r, 4, 9);
    final p = a * b;
    if (stage == 0) {
      qs.add(inputQ(p.toString() + '÷' + a.toString() + '＝？', b,
          '想口诀"' + kouJue(a, b) + '"，所以 ' + p.toString() + '÷' + a.toString() + '=' + b.toString() + '。', 'u4l1'));
      qs.add(inputQ(p.toString() + '÷' + b.toString() + '＝？', a,
          '想口诀"' + kouJue(a, b) + '"，所以 ' + p.toString() + '÷' + b.toString() + '=' + a.toString() + '。', 'u4l1'));
    } else if (stage == 1) {
      switch (t % 4) {
        case 0:
          qs.add(inputQ('（　）×$a＝$p，括号里填几？', b,
              '想口诀"${kouJue(a, b)}"，$a×$b＝$p。', 'u4l1'));
        case 1:
          {
            // 口诀里两个因数都在 6~9，空出的那一位才好选
            final aa = ri(r, 6, 9);
            final bb = ri(r, 6, 9);
            final k = kouJue(aa, bb);
            final right = cn[bb];
            final ds = ['六', '七', '八', '九'].where((e) => e != right).toList();
            ds.shuffle(r);
            qs.add(choiceQ('把口诀补充完整：${k[0]}（　）${k.substring(2)}',
                right, ds.take(2).toList(),
                '$aa×$bb＝${aa * bb}，口诀是"$k"。', 'u4l1', r: r));
          }
        case 2:
          {
            final q = ri(r, 6, 9);
            final good = q * q;
            final side = (q - 1) * (q + 1);
            qs.add(choiceQ('商是 $q 的算式是（　）', '$good÷$q',
                ['$side÷${q - 1}', '$side÷${q + 1}'],
                '$good÷$q＝$q，口诀"${kouJue(q, q)}"。', 'u4l1', r: r));
          }
        default:
          qs.add(inputQ('一个数除以 $a 得 $b，这个数是几？', p,
              '$a×$b＝$p，所以这个数是 $p。', 'u4l1'));
      }
    } else {
      switch (t % 4) {
        case 0:
          qs.add(inputQ('$p 除以 $a，商是几？', b,
              '想口诀"${kouJue(a, b)}"，$p÷$a＝$b。', 'u4l1'));
        case 1:
          qs.add(inputQ('两个数相乘的积是 $p，其中一个因数是 $a，另一个是几？', b,
              '$p÷$a＝$b，想口诀"${kouJue(a, b)}"。', 'u4l1'));
        case 2:
          {
            final n = ri(r, 6, 9);
            final m = ri(r, 6, 9);
            qs.add(numChoice('$n 的 $m 倍是多少？', n * m, r,
                '$n×$m＝${n * m}，口诀"${kouJue(n, m)}"。', 'u4l1',
                min: 10, max: 99));
          }
        default:
          {
            final n = ri(r, 6, 9);
            final m = ri(r, 6, 9);
            qs.add(numChoice('${n * m} 是 $n 的几倍？', m, r,
                '${n * m}÷$n＝$m，是 $m 倍。', 'u4l1', min: 2, max: 12));
          }
      }
    }
  }
  return dedupe(qs, 12);
}

/// u4l2 解决问题（含"倍"的认识）
List<Question> genDivStory2(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 24; t++) {
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
  return dedupe(qs, 12);
}
