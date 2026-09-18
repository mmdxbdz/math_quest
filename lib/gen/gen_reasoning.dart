import 'dart:math';
import '../models.dart';
import 'util.dart';

/// u9l1 简单推理
List<Question> genReasonSimple(Random r, int stage) {
  final qs = <Question>[];
  const pool = ['小红', '小明', '小刚', '小丽', '小强'];
  for (var t = 0; t < 3; t++) {
    final p3 = [...pool];
    swapShuffle(p3, r);
    final a = p3[0], b = p3[1], c = p3[2];
    if (stage == 0) {
      qs.add(choiceQ(a + '比' + b + '高，' + b + '比' + c + '高。（　）最高？', a, [b, c],
          '个子从高到矮：' + a + '、' + b + '、' + c + '。', 'u9l1', r: r));
      qs.add(choiceQ(a + '比' + b + '高，' + b + '比' + c + '高。（　）最矮？', c, [a, b],
          '个子从高到矮：' + a + '、' + b + '、' + c + '，最后一位最矮。', 'u9l1', r: r));
    } else if (stage == 1) {
      const books = ['语文书', '数学书', '英语书'];
      final held = books[ri(r, 0, 2)];
      final others = books.where((s) => s != held).toList();
      qs.add(choiceQ('三个小朋友分别拿着语文书、数学书、英语书各一本。小明拿的不是' + others[0] + '，也不是' + others[1] + '，小明拿的是（　）',
          held, [others[0], others[1]], '用排除法：不是这两本，剩下的那本就是。', 'u9l1', r: r));
      final s1 = ri(r, 2, 9);
      final s2 = ri(r, 2, 9);
      final more = s2 > s1 ? '小丽' : '小红';
      final less = more == '小丽' ? '小红' : '小丽';
      qs.add(choiceQ('小红和小丽跳绳，小红跳的下数比 ' + (s2 * 10).toString() + ' 下少，比 ' + ((s2 - 1) * 10).toString() + ' 下多。谁跳得多？',
          more, [less, '一样多'], '小红在下 ' + ((s2 - 1) * 10).toString() + ' 到 ' + (s2 * 10).toString() + ' 之间，比小丽的 ' + (s2 * 10).toString() + ' 少。', 'u9l1', r: r));
    } else {
      qs.add(choiceQ('甲、乙、丙三人，甲不是最高的，但比丙高。最高的是（　）', '乙', ['甲', '丙'],
          '甲比丙高又不是最高，所以从高到矮是：乙、甲、丙。', 'u9l1', r: r));
      final c1 = ri(r, 2, 5);
      final d1 = c1 + ri(r, 1, 6);
      qs.add(inputQ('○＋○＝' + (c1 * 2).toString() + '，△＋○＝' + (c1 + d1).toString() + '，△＝？', d1 - c1,
          '先算出 ○＝' + c1.toString() + '，再算 △＝' + (c1 + d1).toString() + '－' + c1.toString() + '＝' + (d1 - c1).toString() + '。', 'u9l1'));
    }
  }
  return dedupe(qs, 9);
}

/// u9l2 数与符号推理
List<Question> genReasonGrid(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 3; t++) {
    if (stage == 0) {
      final s = ri(r, 2, 5);
      final o = s + ri(r, 1, 5);
      qs.add(inputQ('□＋□＝' + (s * 2).toString() + '，○＋□＝' + (s + o).toString() + '，○＝？', o,
          '先算 □＝' + (s * 2).toString() + '÷2＝' + s.toString() + '，再算 ○＝' + (s + o).toString() + '－' + s.toString() + '＝' + o.toString() + '。', 'u9l2'));
      final tr = ri(r, 4, 6);
      qs.add(choiceQ('△、○、□ 分别代表 4、5、6 中的一个。△＋△＝' + (tr * 2).toString() + '，△是（　）',
          tr.toString(), [4, 5, 6].where((e) => e != tr).map((e) => e.toString()).toList(),
          '两个相同的数相加得 ' + (tr * 2).toString() + '，就是 ' + tr.toString() + '。', 'u9l2', r: r));
    } else if (stage == 1) {
      final t2 = ri(r, 4, 8);
      final o2 = ri(r, 1, t2 - 1);
      qs.add(inputQ('△＋○＝' + (t2 + o2).toString() + '，△－○＝' + (t2 - o2).toString() + '，△＝？', t2,
          '两式相加：2 个△＝' + (2 * t2).toString() + '，△＝' + t2.toString() + '。', 'u9l2'));
      final c2 = ri(r, 2, 4);
      final target = ri(r, 9, 15);
      qs.add(inputQ('○×3＝' + (c2 * 3).toString() + '，○＋□＝' + target.toString() + '，□＝？', target - c2,
          '○＝' + c2.toString() + '，□＝' + target.toString() + '－' + c2.toString() + '＝' + (target - c2).toString() + '。', 'u9l2'));
    } else {
      final a3 = ri(r, 2, 6);
      final b3 = a3 + 1;
      final c3 = a3 * b3;
      qs.add(choiceQ('□×○＝' + c3.toString() + '，□－○＝1，□和○哪个大？', '□',
          ['○', '一样大'], '□比○大 1。', 'u9l2', r: r));
      final t3 = ri(r, 5, 9);
      final o3 = ri(r, 1, t3 - 2);
      final d3 = ri(r, 1, o3 - 1 > 0 ? o3 - 1 : 1);
      if (d3 < o3) {
        qs.add(choiceQ('△－○＝' + (t3 - o3).toString() + '，△－□＝' + (t3 - d3).toString() + '，○和□谁大？', '○',
            ['□', '一样大'], '△相同，减得越少说明原来的数越大。', 'u9l2', r: r));
      } else {
        qs.add(choiceQ('△－○＝' + (t3 - o3).toString() + '，△－□＝' + (t3 - o3 - 1).toString() + '，○和□谁大？', '□',
            ['○', '一样大'], '△相同，减得越少说明原来的数越大。', 'u9l2', r: r));
      }
    }
  }
  return dedupe(qs, 9);
}
