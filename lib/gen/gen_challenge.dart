import 'dart:math';
import '../models.dart';
import 'util.dart';

/// 生成一个与排除集合不同的数（默认 1~9）
int diffFrom(Random r, Set<int> exclude, {int min = 1, int max = 9}) {
  var v = ri(r, min, max);
  var guard = 0;
  while (exclude.contains(v) && guard++ < 30) {
    v = ri(r, min, max);
  }
  if (exclude.contains(v)) {
    for (var i = min; i <= max; i++) {
      if (!exclude.contains(i)) return i;
    }
  }
  return v;
}

/// ===== 思维挑战 · 找规律（数列）=====
List<Question> genSeqChallenge(Random r, int stage) {
  final qs = <Question>[];

  if (stage == 0) {
    // 等差递增，缺末项
    for (var t = 0; t < 24; t++) {
      final a1 = ri(r, 2, 5);
      final d = ri(r, 2, 4);
      final seq = [a1, a1 + d, a1 + 2 * d, a1 + 3 * d, a1 + 4 * d];
      qs.add(inputQ(seq.sublist(0, 4).join('，') + '，□',
          seq[4], '相邻两个数都相差 ' + d.toString() + '，□ 里填 ' + (a1 + 4 * d).toString() + '。', 'ch-seq'));
    }
    // 等差，缺中间项
    final b1 = ri(r, 3, 6);
    final d2 = ri(r, 2, 3);
    qs.add(inputQ(b1.toString() + '，□，' + (b1 + 2 * d2).toString() + '，' + (b1 + 3 * d2).toString(),
        b1 + d2, '每两个数之间相差 ' + d2.toString() + '，所以 □ 里是 ' + (b1 + d2).toString() + '。', 'ch-seq'));
    // 较大的等差
    final c1 = ri(r, 10, 20);
    final d3 = ri(r, 5, 10);
    qs.add(inputQ(c1.toString() + '，' + (c1 + d3).toString() + '，' + (c1 + 2 * d3).toString() + '，□',
        c1 + 3 * d3, '每次都加 ' + d3.toString() + '，最后一项是 ' + (c1 + 3 * d3).toString() + '。', 'ch-seq'));
  } else if (stage == 1) {
    // 交替规律：a,b,a,b,a,□
    final a = ri(r, 1, 9);
    final b = a >= 5 ? a - ri(r, 1, 4) : a + ri(r, 1, 4);
    final d1 = diffFrom(r, {b, a});
    qs.add(choiceQ(a.toString() + '，' + b.toString() + '，' + a.toString() + '，' + b.toString() + '，' + a.toString() + '，□',
        b.toString(), [a.toString(), d1.toString()],
        '两个数交替出现，第 6 个和第 2、4 个一样，是 ' + b.toString() + '。', 'ch-seq', r: r));
    // 三数循环：x,y,z,x,y,z,□
    final x = ri(r, 1, 9);
    final y = x >= 5 ? x - ri(r, 1, 4) : x + ri(r, 1, 4);
    final z = diffFrom(r, {x, y});
    qs.add(choiceQ(x.toString() + '，' + y.toString() + '，' + z.toString() + '，' + x.toString() + '，' + y.toString() + '，' + z.toString() + '，□',
        x.toString(), [y.toString(), z.toString()],
        '三个数一循环，第 7 个和每组的第 1 个一样，是 ' + x.toString() + '。', 'ch-seq', r: r));
    // 等差缺中项（较大）
    final c1 = ri(r, 2, 5);
    final d = ri(r, 3, 4);
    qs.add(inputQ(c1.toString() + '，' + (c1 + d).toString() + '，' + (c1 + 2 * d).toString() + '，□，' + (c1 + 4 * d).toString(),
        c1 + 3 * d, '每两个数相差 ' + d.toString() + '，所以 □ 里是 ' + (c1 + 3 * d).toString() + '。', 'ch-seq'));
    // 递减等差
    final c2 = ri(r, 25, 40);
    final d2 = ri(r, 3, 5);
    qs.add(inputQ(c2.toString() + '，' + (c2 - d2).toString() + '，' + (c2 - 2 * d2).toString() + '，' + (c2 - 3 * d2).toString() + '，□',
        c2 - 4 * d2, '每次都减 ' + d2.toString() + '，最后是 ' + (c2 - 4 * d2).toString() + '。', 'ch-seq'));
  } else {
    // 等比 / 斐波那契 / 交叉 / 平方数……多换几种，别总出同一道
    for (var t = 0; t < 24; t++) {
      switch (t % 7) {
        case 0:
          {
            final a1 = ri(r, 2, 5);
            final k = ri(r, 2, 3); // ×2 或 ×3
            final seq = [a1, a1 * k, a1 * k * k, a1 * k * k * k];
            qs.add(inputQ(seq.sublist(0, 3).join('，') + '，□', seq[3],
                '后面的数都是前面的 $k 倍，所以是 ${seq[3]}。', 'ch-seq'));
          }
        case 1:
          {
            final f1 = ri(r, 1, 3);
            final f2 = ri(r, 1, 4);
            final f3 = f1 + f2, f4 = f2 + f3, f5 = f3 + f4, f6 = f4 + f5;
            qs.add(inputQ(
                '$f1，$f2，$f3，$f4，$f5，□',
                f6,
                '从第 3 个数开始，每个数都是前两个数的和：$f4＋$f5＝$f6。', 'ch-seq'));
          }
        case 2:
          {
            final o = ri(r, 2, 5);
            final e = ri(r, 2, 4);
            qs.add(inputQ(
                '$o，$e，${o + 1}，${e * 2}，${o + 2}，${e * 3}，□',
                o + 3,
                '隔一个看：$o，${o + 1}，${o + 2}，…每次加 1，所以 □ 里是 ${o + 3}。', 'ch-seq'));
          }
        case 3:
          {
            final c2 = ri(r, 40, 70);
            final d2 = ri(r, 4, 7);
            qs.add(inputQ(
                '$c2，${c2 - d2}，${c2 - 2 * d2}，${c2 - 3 * d2}，□',
                c2 - 4 * d2,
                '每次都减 $d2，最后是 ${c2 - 4 * d2}。', 'ch-seq'));
          }
        case 4:
          {
            final n = ri(r, 2, 7);
            qs.add(inputQ(
                '${n * n}，${(n + 1) * (n + 1)}，${(n + 2) * (n + 2)}，□',
                (n + 3) * (n + 3),
                '这些数是 $n×$n、${n + 1}×${n + 1}…下一个是 ${n + 3}×${n + 3}＝${(n + 3) * (n + 3)}。',
                'ch-seq'));
          }
        case 5:
          {
            final a1 = ri(r, 2, 6);
            final d = ri(r, 3, 9);
            qs.add(inputQ(
                '$a1，${a1 + d}，${a1 + 2 * d}，${a1 + 3 * d}，${a1 + 4 * d}，□',
                a1 + 5 * d,
                '每次都加 $d，所以 □ 里是 ${a1 + 5 * d}。', 'ch-seq'));
          }
        default:
          {
            final x = ri(r, 2, 9);
            final y = ri(r, 2, 9);
            final z = ri(r, 2, 9);
            qs.add(choiceQ(
                '$x，$y，$z，$x，$y，$z，□',
                x.toString(),
                [y.toString(), z.toString()],
                '三个数一循环，第 7 个和每组的第 1 个一样，是 $x。', 'ch-seq', r: r));
          }
      }
    }
  }
  return dedupe(qs, 6);
}

/// ===== 思维挑战 · 巧算 =====
List<Question> genSmartChallenge(Random r, int stage) {
  final qs = <Question>[];

  if (stage == 0) {
    // 两项凑 100
    for (var t = 0; t < 24; t++) {
      final p = ri(r, 10, 49);
      final q = 100 - p;
      final rr = ri(r, 10, 49);
      qs.add(inputQ(p.toString() + '＋' + q.toString() + '＋' + rr.toString() + '＝？',
          p + q + rr, '先算 ' + p.toString() + '＋' + q.toString() + '＝100，再加 ' + rr.toString() + '，得 ' + (100 + rr).toString() + '。', 'ch-smart'));
    }
    // 99 + n
    final n = ri(r, 11, 89);
    qs.add(inputQ('99＋' + n.toString() + '＝？', 99 + n,
        '99 接近 100：先算 100＋' + n.toString() + '＝' + (100 + n).toString() + '，再减 1，得 ' + (99 + n).toString() + '。', 'ch-smart'));
    // 个位凑整十：a+b 个位相加为 10，再加 c
    final at = ri(r, 1, 8);
    final ax = ri(r, 1, 9);
    final bt = ri(r, 1, 8);
    final a = at * 10 + ax;
    final b = bt * 10 + (10 - ax);
    final c = ri(r, 11, 99);
    qs.add(inputQ(a.toString() + '＋' + b.toString() + '＋' + c.toString() + '＝？',
        a + b + c, a.toString() + ' 和 ' + b.toString() + ' 的个位相加正好是 10，先算它们：' + (a + b).toString() + '，再加 ' + c.toString() + '。', 'ch-smart'));
  } else if (stage == 1) {
    // 减法凑整：m - a - b，a+b=100
    for (var t = 0; t < 24; t++) {
      final m = ri(r, 120, 200);
      final a = ri(r, 30, 70);
      final b = 100 - a;
      qs.add(inputQ(m.toString() + '－' + a.toString() + '－' + b.toString() + '＝？',
          m - 100, '先算 ' + a.toString() + '＋' + b.toString() + '＝100，再用 ' + m.toString() + ' 减 100，得 ' + (m - 100).toString() + '。', 'ch-smart'));
    }
    // 四项两两凑 100
    final a = ri(r, 20, 80);
    final c = 100 - a;
    final b = ri(r, 20, 80);
    final d = 100 - b;
    qs.add(inputQ(a.toString() + '＋' + c.toString() + '＋' + b.toString() + '＋' + d.toString() + '＝？',
        200, '两两凑整：' + a.toString() + '＋' + c.toString() + '＝100，' + b.toString() + '＋' + d.toString() + '＝100，一共 200。', 'ch-smart'));
    // 1~9 / 1~10 求和（配对凑 10）
    if (r.nextBool()) {
      qs.add(inputQ('1＋2＋3＋4＋5＋6＋7＋8＋9＝？', 45,
          '配成 4 组 10（1＋9、2＋8、3＋7、4＋6）再加中间的 5，得 45。', 'ch-smart'));
    } else {
      qs.add(inputQ('1＋2＋3＋4＋5＋6＋7＋8＋9＋10＝？', 55,
          '配成 5 组 10（1＋10、2＋9、3＋8、4＋7、5＋6），得 55。', 'ch-smart'));
    }
    // n - 99
    final n = ri(r, 110, 200);
    qs.add(inputQ(n.toString() + '－99＝？', n - 99,
        '99 接近 100：先算 ' + n.toString() + '－100＝' + (n - 100).toString() + '，再加回 1，得 ' + (n - 99).toString() + '。', 'ch-smart'));
  } else {
    // 25×4 系列
    for (var t = 0; t < 24; t++) {
      final n = ri(r, 2, 6);
      qs.add(inputQ('25×4×' + n.toString() + '＝？', 100 * n,
          '先算 25×4＝100，再乘 ' + n.toString() + '，得 ' + (100 * n).toString() + '。', 'ch-smart'));
    }
    // 125×8 系列
    final n2 = ri(r, 1, 4);
    qs.add(inputQ('125×8×' + n2.toString() + '＝？', 1000 * n2,
        '先算 125×8＝1000，再乘 ' + n2.toString() + '，得 ' + (1000 * n2).toString() + '。', 'ch-smart'));
    // 分配律启蒙：a×b ＋ c×b
    final a = ri(r, 2, 6);
    final c = ri(r, 2, 6);
    final b = ri(r, 2, 9);
    qs.add(inputQ(a.toString() + '×' + b.toString() + '＋' + c.toString() + '×' + b.toString() + '＝？',
        (a + c) * b, '都有 ' + b.toString() + '，可以合起来：(' + a.toString() + '＋' + c.toString() + ')×' + b.toString() + '＝' + (a + c).toString() + '×' + b.toString() + '＝' + ((a + c) * b).toString() + '。', 'ch-smart'));
    // 99×n ＋ n
    final n3 = ri(r, 2, 9);
    qs.add(inputQ('99×' + n3.toString() + '＋' + n3.toString() + '＝？', n3 * 100,
        '99 个 ' + n3.toString() + ' 再加 1 个，是 100 个 ' + n3.toString() + '，得 ' + (n3 * 100).toString() + '。', 'ch-smart'));
    // a+b 个位凑整十再减 c
    final at = ri(r, 1, 8);
    final ax = ri(r, 1, 9);
    final bt = ri(r, 1, 8);
    final ab = (at + bt + 1) * 10;
    final c2 = ri(r, 10, ab);
    qs.add(inputQ((at * 10 + ax).toString() + '＋' + (bt * 10 + 10 - ax).toString() + '－' + c2.toString() + '＝？',
        ab - c2, '先算前两个数：' + ab.toString() + '，再减 ' + c2.toString() + '，得 ' + (ab - c2).toString() + '。', 'ch-smart'));
  }
  return dedupe(qs, 6);
}

/// ===== 思维挑战 · 简单推理 =====
List<Question> genLogicChallenge(Random r, int stage) {
  final qs = <Question>[];
  const names = ['小红', '小明', '小刚'];
  const items = ['苹果', '香蕉', '梨'];

  if (stage == 0) {
    // 排除法：拿的不是 X 也不是 Y
    for (var t = 0; t < 24; t++) {
      final holder = names[ri(r, 0, 2)];
      final held = items[ri(r, 0, 2)];
      final others = items.where((i) => i != held).toList();
      final others2 = names.where((n) => n != holder).toList();
      qs.add(choiceQ(holder + '、' + others2[0] + '、' + others2[1] +
          '分别拿着苹果、香蕉、梨。' + holder + '拿的不是' + others[0] + '，也不是' + others[1] + '，' + holder + '拿的是（　）',
          held, [others[0], others[1]],
          '不是' + others[0] + '也不是' + others[1] + '，剩下的就是' + held + '。', 'ch-logic', r: r));
    }
    // 〇＋〇
    final half = ri(r, 2, 9);
    qs.add(inputQ('〇＋〇＝' + (half * 2).toString() + '，〇＝？', half,
        '两个相同的数相加得 ' + (half * 2).toString() + '，就是 ' + half.toString() + '。', 'ch-logic'));
    // 两步数字谜
    final base = ri(r, 2, 9);
    final target = ri(r, base + 1, 18);
    qs.add(inputQ('〇＋〇＝' + (base * 2).toString() + '，〇＋△＝' + target.toString() + '，△＝？',
        target - base, '〇＝' + base.toString() + '，△＝' + target.toString() + '－' + base.toString() + '＝' + (target - base).toString() + '。', 'ch-logic'));
  } else if (stage == 1) {
    // 两式相加：△＋○＝s，△－○＝d
    for (var t = 0; t < 24; t++) {
      final tri = ri(r, 3, 9);
      final cir = ri(r, 1, tri - 1);
      qs.add(inputQ('△＋○＝' + (tri + cir).toString() + '，△－○＝' + (tri - cir).toString() + '，△＝？',
          tri, '两个式子加起来：2 个△＝' + (2 * tri).toString() + '，△＝' + tri.toString() + '。', 'ch-logic'));
    }
    // 赛跑排序
    final fi = ri(r, 0, 2);
    final fast = names[fi];
    final slow = names[(fi + 1) % 3];
    final mid = names[(fi + 2) % 3];
    qs.add(choiceQ(names[0] + '、' + names[1] + '、' + names[2] + '赛跑，' + fast + '比' + slow + '快，' + mid + '比' + fast + '快，（　）最快？',
        mid, [fast, slow],
        '从快到慢：' + mid + '、' + fast + '、' + slow + '。', 'ch-logic', r: r));
    // 平方数字谜
    final n = ri(r, 2, 9);
    qs.add(numChoice('△×△＝' + (n * n).toString() + '，△＝？', n, r,
        '哪个数乘自己等于 ' + (n * n).toString() + '？' + n.toString() + '×' + n.toString() + '＝' + (n * n).toString() + '。', 'ch-logic'));
    // 排除进阶：一人已知，另一人排除
    final h1 = names[ri(r, 0, 2)];
    final held1 = items[ri(r, 0, 2)];
    final held2 = items[(items.indexOf(held1) + 1) % 3];
    final held3 = items[(items.indexOf(held1) + 2) % 3];
    final p2 = names[(names.indexOf(h1) + 1) % 3];
    final p3 = names[(names.indexOf(h1) + 2) % 3];
    qs.add(choiceQ(h1 + '拿着' + held1 + '，' + p2 + '和' + p3 + '分别拿着' + held2 + '和' + held3 + '。' + p2 + '拿的不是' + held3 + '，' + p2 + '拿的是（　）',
        held2, [held3, held1],
        p2 + '拿的不是' + held3 + '，也不可能是' + held1 + '（那是' + h1 + '的），所以是' + held2 + '。', 'ch-logic', r: r));
  } else {
    // 三数两两和：求 B
    final a = ri(r, 2, 6);
    final b = ri(r, 2, 6);
    final c = ri(r, 2, 6);
    qs.add(inputQ('A＋B＝' + (a + b).toString() + '，B＋C＝' + (b + c).toString() + '，A＋C＝' + (a + c).toString() + '，B＝？',
        b, '把前两个式子相加减去第三个：(' + (a + b).toString() + '＋' + (b + c).toString() + '－' + (a + c).toString() + ')÷2＝' + b.toString() + '。', 'ch-logic'));
    // 天平：●＋▲＝a，▲＋★＝b，●＋★＝c，求 ▲
    final x = ri(r, 1, 5);
    final y = ri(r, 1, 5);
    final z = ri(r, 1, 5);
    qs.add(inputQ('●＋▲＝' + (x + y).toString() + '，▲＋★＝' + (y + z).toString() + '，●＋★＝' + (x + z).toString() + '，▲＝？',
        y, '像上面那样：(' + (x + y).toString() + '＋' + (y + z).toString() + '－' + (x + z).toString() + ')÷2＝' + y.toString() + '。', 'ch-logic'));
    // 四个相同符号
    final p = ri(r, 2, 6);
    qs.add(inputQ('□＋□＋□＋□＝' + (p * 4).toString() + '，□＝？', p,
        '4 个相同的数相加得 ' + (p * 4).toString() + '，就是 ' + p.toString() + '。', 'ch-logic'));
    // 四人比较链
    qs.add(choiceQ('甲比乙高，乙比丙高，丙比丁高。（　）最高？', '甲', ['乙', '丙'],
        '从高到矮：甲、乙、丙、丁，甲最高。', 'ch-logic', r: r));
    // double：○＝△＋2，○＋△＝s
    final t = ri(r, 2, 8);
    final o = t + 2;
    qs.add(doubleQ('○＝△＋2，○＋△＝' + (o + t).toString() + '，△＝？　○＝？',
        t, o, '把 △＋2 当作 ○：两个 △ 加 2 等于 ' + (o + t).toString() + '，△＝' + t.toString() + '，○＝' + o.toString() + '。', 'ch-logic',
        labels: ['△', '○']));
  }
  return dedupe(qs, 6);
}
