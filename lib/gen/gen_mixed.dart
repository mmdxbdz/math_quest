import 'dart:math';
import '../models.dart';
import 'util.dart';

/// u5l1 同级运算（从左往右）
List<Question> genMixedSame(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 4; t++) {
    if (stage == 0) {
      final a = ri(r, 10, 40);
      final b = ri(r, 2, 20);
      final c = ri(r, 1, 9);
      qs.add(inputQ(a.toString() + '＋' + b.toString() + '－' + c.toString() + '＝？', a + b - c,
          '从左往右算：' + a.toString() + '＋' + b.toString() + '=' + (a + b).toString() + '，再减 ' + c.toString() + '。', 'u5l1'));
      final d = ri(r, 2, 6);
      final e = ri(r, 2, 6);
      final divs = [2, 3, 4, 5, 6, 7, 8, 9].where((k) => (d * e) % k == 0).toList();
      final f = divs[ri(r, 0, divs.length - 1)];
      qs.add(inputQ(d.toString() + '×' + e.toString() + '÷' + f.toString() + '＝？', d * e ~/ f,
          '从左往右算：' + d.toString() + '×' + e.toString() + '=' + (d * e).toString() + '，再除以 ' + f.toString() + '。', 'u5l1'));
    } else if (stage == 1) {
      final a = ri(r, 2, 9);
      final b = ri(r, 2, 9);
      final c = ri(r, 2, 6);
      qs.add(inputQ((a * b).toString() + '÷' + a.toString() + '×' + c.toString() + '＝？', b * c,
          '从左往右：' + (a * b).toString() + '÷' + a.toString() + '=' + b.toString() + '，再乘 ' + c.toString() + '。', 'u5l1'));
      final x = ri(r, 20, 60);
      final y = ri(r, 5, 15);
      final z = ri(r, 5, 15);
      qs.add(inputQ(x.toString() + '－' + y.toString() + '－' + z.toString() + '＝？', x - y - z,
          '从左往右：先减 ' + y.toString() + ' 再减 ' + z.toString() + '。', 'u5l1'));
    } else {
      final a = ri(r, 2, 9);
      final b = ri(r, 2, 9);
      final c = ri(r, 2, 9);
      final d = ri(r, 2, 9);
      final cmp = (a * b).compareTo(c * d) >= 0 ? (a * b == c * d ? '=' : '＞') : '＜';
      qs.add(compareQ(a.toString() + '×' + b.toString(), c.toString() + '×' + d.toString(), cmp,
          a.toString() + '×' + b.toString() + '=' + (a * b).toString() + '，' + c.toString() + '×' + d.toString() + '=' + (c * d).toString() + '。', 'u5l1'));
      final e = ri(r, 3, 9);
      final f = ri(r, 2, 9);
      final g = ri(r, 2, 9);
      qs.add(inputQ(e.toString() + '×' + f.toString() + '×' + g.toString() + '＝？', e * f * g,
          '从左往右：' + e.toString() + '×' + f.toString() + '=' + (e * f).toString() + '，再乘 ' + g.toString() + '。', 'u5l1'));
    }
  }
  return dedupe(qs, 12);
}

/// u5l2 含两级运算（先乘除后加减）
List<Question> genMixedTwoLevel(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 4; t++) {
    final a = ri(r, 2, 9);
    final b = ri(r, 2, 9);
    final p = a * b;
    if (stage == 0) {
      final c = ri(r, 1, 20);
      if (r.nextBool()) {
        qs.add(inputQ(c.toString() + '＋' + a.toString() + '×' + b.toString() + '＝？', c + p,
            '先算乘法：' + a.toString() + '×' + b.toString() + '=' + p.toString() + '，再算加法。', 'u5l2'));
      } else {
        qs.add(inputQ(p.toString() + '－' + c.toString() + '＝？', p - c,
            '先算乘法，再算减法。', 'u5l2'));
      }
    } else if (stage == 1) {
      final d = ri(r, 2, 9);
      final dd = a * d;
      qs.add(inputQ((p + dd).toString() + '－' + b.toString() + '×' + d.toString() + '＝？', p,
          '先算两个乘法，再算减法。', 'u5l2'));
      final e = ri(r, 10, 30);
      final f = ri(r, 2, 5);
      final g = ri(r, 2, 9);
      qs.add(inputQ(e.toString() + '＋' + f.toString() + '×' + g.toString() + '－' + (f * g).toString() + '＝？', e,
          '先算 ' + f.toString() + '×' + g.toString() + '=' + (f * g).toString() + '，加起来再减，正好剩 ' + e.toString() + '。', 'u5l2'));
    } else {
      final x = ri(r, 2, 6);
      final y = ri(r, 2, 9);
      final z = ri(r, 2, 9);
      qs.add(compareQ(x.toString() + '×' + y.toString(), y.toString() + '×' + z.toString(), cmpOf(x * y, y * z),
          '分别算出两边再比较。', 'u5l2'));
      final m = ri(r, 12, 25);
      final n = ri(r, 2, 4);
      final k = ri(r, 2, 6);
      qs.add(inputQ(m.toString() + '－' + n.toString() + '×' + k.toString() + '＋' + (n * k).toString() + '＝？', m,
          n.toString() + '×' + k.toString() + '=' + (n * k).toString() + '，减去又加上，结果不变。', 'u5l2'));
    }
  }
  return dedupe(qs, 12);
}

String cmpOf(int l, int r2) => l < r2 ? '＜' : (l > r2 ? '＞' : '=');

/// u5l3 含小括号的运算
List<Question> genMixedParen(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 3; t++) {
    final a = ri(r, 2, 9);
    final b = ri(r, 2, 9);
    final c = ri(r, 2, 9);
    if (stage == 0) {
      qs.add(inputQ('（' + a.toString() + '＋' + b.toString() + '）×' + c.toString() + '＝？', (a + b) * c,
          '先算小括号里的：' + (a + b).toString() + '，再乘 ' + c.toString() + '。', 'u5l3'));
      final s = a + b;
      final p = s * c;
      qs.add(inputQ(p.toString() + '÷（' + a.toString() + '＋' + b.toString() + '）＝？', c,
          '先算括号里的 ' + s.toString() + '，再算除法。', 'u5l3'));
    } else if (stage == 1) {
      qs.add(choiceQ('算式 ' + (a + b * c).toString() + '　的题：20－3×5 要先算（　）', '3×5',
          ['20－3', '从左往右都行'], '有乘有加，先算乘法。', 'u5l3', r: r));
      final e = ri(r, 2, 6);
      final f = ri(r, 4, 8);
      final k = ri(r, 1, 2);
      final d = e * k;
      qs.add(inputQ('（' + (e * f).toString() + '－' + d.toString() + '）÷' + e.toString() + '＝？', f - k,
          '先算括号里的减法，再除以 ' + e.toString() + '。', 'u5l3'));
    } else {
      final g = ri(r, 2, 5);
      final target = ri(r, 2, 9);
      qs.add(inputQ('9×（　＋4）＝81，括号里填几？', 5, '81÷9=9，9－4=5。', 'u5l3'));
      qs.add(inputQ('（' + g.toString() + '＋' + target.toString() + '）×3＝' + ((g + target) * 3).toString() + '，括号里填的数是多少？', target,
          '先算 ' + ((g + target) * 3).toString() + '÷3=' + (g + target).toString() + '，再减 ' + g.toString() + '。', 'u5l3'));
    }
  }
  return dedupe(qs, 9);
}

/// u5l4 解决问题（两步计算）
List<Question> genMixedStory(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 3; t++) {
    if (stage == 0) {
      final price = ri(r, 3, 6);
      final cnt = ri(r, 4, 7);
      final pay = price * cnt + ri(r, 5, 20);
      qs.add(inputQ('面包每个 ' + price.toString() + ' 元，买 ' + cnt.toString() + ' 个付给 ' + pay.toString() + ' 元，找回几元？',
          pay - price * cnt, '先算花了多少：' + price.toString() + '×' + cnt.toString() + '=' + (price * cnt).toString() + '，再用付的钱减去。', 'u5l4'));
    } else if (stage == 1) {
      final pages = ri(r, 5, 9);
      final days = ri(r, 4, 7);
      final total = pages * days + ri(r, 5, 30);
      qs.add(inputQ('一本书 ' + total.toString() + ' 页，每天看 ' + pages.toString() + ' 页，看了 ' + days.toString() + ' 天，还剩多少页？',
          total - pages * days, '先算已看的：' + pages.toString() + '×' + days.toString() + '=' + (pages * days).toString() + '，再用总页数减。', 'u5l4'));
    } else {
      qs.add(choiceQ('每枝笔 4 元，买 6 枝，付了 50 元，求找回多少元。列式正确的是（　）', '50－4×6',
          ['50－4', '50÷6'], '先算 6 枝笔的钱 4×6=24，再算找回：50－24=26（元）。', 'u5l4', r: r));
      final box = ri(r, 6, 9);
      final boxes = ri(r, 3, 6);
      final total2 = box * boxes;
      final sold = ri(r, 5, total2 - 5 > 30 ? 30 : total2 - 5);
      qs.add(inputQ('商店运来 ' + boxes.toString() + ' 箱橘子，每箱 ' + box.toString() + ' 千克，卖出 ' + sold.toString() + ' 千克，还剩多少千克？',
          box * boxes - sold, '先算一共：' + box.toString() + '×' + boxes.toString() + '=' + (box * boxes).toString() + '，再减卖出的。', 'u5l4'));
    }
  }
  return dedupe(qs, 9);
}
