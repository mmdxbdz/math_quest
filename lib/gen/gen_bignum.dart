import 'dart:math';
import '../models.dart';
import 'util.dart';

int _pickNum(List<int> l, Random r) => l[ri(r, 0, l.length - 1)];

/// u7l1 1000 以内数的认识
List<Question> genNum1000(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 24; t++) {
    final h = ri(r, 2, 9);
    final te = ri(r, 0, 9);
    final on = ri(r, 0, 9);
    final num = h * 100 + te * 10 + on;
    if (stage == 0) {
      if (te > 0) {
        qs.add(inputQ(h.toString() + ' 个百和 ' + te.toString() + ' 个十组成的数是多少？', h * 100 + te * 10,
            h.toString() + ' 个百是 ' + (h * 100).toString() + '，' + te.toString() + ' 个十是 ' + (te * 10).toString() + '，合起来是 ' + (h * 100 + te * 10).toString() + '。', 'u7l1'));
      } else {
        qs.add(inputQ(h.toString() + ' 个百组成的数是多少？', h * 100,
            h.toString() + ' 个百就是 ' + (h * 100).toString() + '。', 'u7l1'));
      }
      final placeNames = ['百位', '十位', '个位'];
      final digits = [h, te, on];
      var pIdx = ri(r, 0, 2);
      var guard2 = 0;
      while (guard2++ < 20 && digits.where((e) => e == digits[pIdx]).length > 1) {
        pIdx = ri(r, 0, 2);
      }
      if (digits.where((e) => e == digits[pIdx]).length > 1) {
        qs.add(inputQ('由 ' + h.toString() + ' 个百、' + te.toString() + ' 个十和 ' + on.toString() + ' 个一组成的数是多少？', num,
            '百位写 ' + h.toString() + '，十位写 ' + te.toString() + '，个位写 ' + on.toString() + '。', 'u7l1'));
      } else {
        final digit = digits[pIdx];
        final place = placeNames[pIdx];
        qs.add(choiceQ(num.toString() + ' 中，' + digit.toString() + ' 在（　）上。', place,
            placeNames.where((s) => s != place).toList(),
            '从右边起：第一位是个位，第二位是十位，第三位是百位。', 'u7l1', r: r));
      }
    } else if (stage == 1) {
      qs.add(choiceQ(num.toString() + '　读作（　）', _readNum(h, te, on),
          [_readNum(h, te, on).contains('零') ? _readNum(h, te, on).replaceAll('零', '') : _readNum(h, te, on) + '零' + _cn2[on],
           '千' + _readNum(h, te, on)],
          '中间有 0 要读出来，末尾的 0 不读。', 'u7l1', r: r));
      if (num <= 899) {
        qs.add(inputQ('比 ' + num.toString() + ' 大 100 的数是多少？', num + 100, '大 100 就是百位加 1。', 'u7l1'));
      } else {
        qs.add(inputQ('比 ' + num.toString() + ' 小 100 的数是多少？', num - 100, '小 100 就是百位减 1。', 'u7l1'));
      }
    } else {
      qs.add(inputQ('最大的三位数是多少？', 999, '每一位都取最大的 9。', 'u7l1'));
      qs.add(inputQ('一个数，百位是 ' + h.toString() + '，十位是 0，个位是 ' + on.toString() + '，这个数是几？',
          h * 100 + on, '十位是 0 也要占位：' + h.toString() + '0' + on.toString() + '。', 'u7l1'));
    }
  }
  return dedupe(qs, 12);
}

const List<String> _cn2 = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

String _readNum(int h, int te, int on) {
  final sb = StringBuffer();
  sb.write(_cn2[h]);
  sb.write('百');
  if (te == 0 && on == 0) return sb.toString();
  if (te == 0) {
    sb.write('零');
    sb.write(_cn2[on]);
    return sb.toString();
  }
  sb.write(_cn2[te]);
  sb.write('十');
  if (on > 0) sb.write(_cn2[on]);
  return sb.toString();
}

/// u7l2 10000 以内数的认识
List<Question> genNum10000(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 24; t++) {
    final th = ri(r, 1, 9);
    final h = ri(r, 0, 9);
    final te = ri(r, 0, 9);
    final on = ri(r, 0, 9);
    final num = th * 1000 + h * 100 + te * 10 + on;
    if (stage == 0) {
      qs.add(inputQ(th.toString() + ' 个千和 ' + te.toString() + ' 个十组成的数是多少？', th * 1000 + te * 10,
          th.toString() + ' 个千是 ' + (th * 1000).toString() + '，' + te.toString() + ' 个十是 ' + (te * 10).toString() + '，十位和百位用 0 占位。', 'u7l2'));
      qs.add(inputQ('999 后面的一个数是多少？', 1000, '999 再数一个数就是 1000。', 'u7l2'));
    } else if (stage == 1) {
      qs.add(choiceQ(num.toString() + ' 是一个（　）位数。', ['四', '三', '五'][num >= 1000 ? 0 : (num >= 100 ? 1 : 2)],
          ['四位数', '三位数', '五位数'].where((s) => s != (num >= 1000 ? '四位数' : '三位数')).toList(),
          '有几位就是几位数，最高位不能是 0。', 'u7l2', r: r));
      qs.add(inputQ('一个四位数，千位是 ' + th.toString() + '，其余各位都是 0，这个数是几？', th * 1000,
          '其他位用 0 占位。', 'u7l2'));
    } else {
      switch (t % 3) {
        case 0:
          {
            final big = _pickNum([9999, 1000, 999, 10000], r);
            qs.add(inputQ(
                big == 9999
                    ? '最大的四位数是多少？'
                    : (big == 1000 ? '最小的四位数是多少？' : '万以内最大的三位数是多少？'),
                big,
                big == 9999
                    ? '四个数位都是 9，就是 9999。'
                    : (big == 1000 ? '一千位最小的非零数 1，后面全是 0，是 1000。' : '三个数位都是 9。'),
                'u7l2'));
          }
        case 1:
          {
            final base = th * 1000 + h * 100;
            final add = _pickNum([1000, 1000, 100], r);
            qs.add(inputQ('比 $base ${add == 1000 ? '大 1000' : '大 100'} 的数是多少？',
                base + add, '把${add == 1000 ? '千' : '百'}位加 1 就是 ${base + add}。',
                'u7l2'));
          }
        default:
          {
            final n = th * 1000 + te * 10;
            qs.add(inputQ('$n 里面有几个千？', th,
                '$n 的千位是 $th，所以有 $th 个千。', 'u7l2'));
            final near = num + _pickNum([1, 10, 100], r);
            qs.add(inputQ('比 $num 大 1 的数是多少？', num + 1,
                '$num 后面接着数一个就是 ${num + 1}。', 'u7l2'));
            if (near > num + 1) {
              qs.add(inputQ('比 $num 大 ${near - num} 的数是多少？', near,
                  '把对应的数位加上 ${near - num}。', 'u7l2'));
            }
          }
      }
    }
  }
  return dedupe(qs, 12);
}

/// u7l3 整百、整十数加减法
List<Question> genRoundAdd(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 24; t++) {
    if (stage == 0) {
      final a = ri(r, 2, 8) * 100;
      final b = ri(r, 2, 9) * 100;
      qs.add(inputQ(a.toString() + '＋' + b.toString() + '＝？', a + b,
          a.toString() + ' 加 ' + b.toString() + '，想 ' + (a ~/ 100).toString() + '＋' + (b ~/ 100).toString() + ' 个百。', 'u7l3'));
      final c = ri(r, 5, 9) * 100;
      final d = ri(r, 1, 4) * 100;
      qs.add(inputQ(c.toString() + '－' + d.toString() + '＝？', c - d,
          '想 ' + (c ~/ 100).toString() + ' 个百减 ' + (d ~/ 100).toString() + ' 个百。', 'u7l3'));
    } else if (stage == 1) {
      final a = ri(r, 2, 9) * 100;
      final b = ri(r, 1, 9) * 10;
      qs.add(inputQ(a.toString() + '＋' + b.toString() + '＝？', a + b, '整百加整十，十位直接加。', 'u7l3'));
      final c = ri(r, 12, 19) * 100;
      final d = ri(r, 2, 9) * 100;
      qs.add(inputQ(c.toString() + '－' + d.toString() + '＝？', c - d, '15 个百减 3 个百这样的想法。', 'u7l3'));
    } else {
      final a = ri(r, 3, 9) * 100;
      final b = ri(r, 1, 9) * 10;
      qs.add(inputQ(a.toString() + '－' + b.toString() + '＝？', a - b, '整百减整十，注意十位变化。', 'u7l3'));
      final x = ri(r, 3, 9) * 10;
      final y = ri(r, 3, 9) * 10;
      qs.add(inputQ(x.toString() + '＋' + y.toString() + '＝？', x + y, '几个十加几个十。', 'u7l3'));
    }
  }
  return dedupe(qs, 12);
}

/// u7l4 数的大小比较与近似数
List<Question> genNumCompare(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 24; t++) {
    if (stage == 0) {
      final a = ri(r, 100, 999);
      var b = ri(r, 100, 999);
      if (b == a) b = a + 1;
      qs.add(compareQ(a.toString(), b.toString(), a < b ? '＜' : '＞',
          '位数相同时，从最高位比起。', 'u7l4'));
      final c = ri(r, 1000, 9999);
      qs.add(compareQ(a.toString(), c.toString(), '＜',
          a.toString() + ' 是三位数，' + c.toString() + ' 是四位数，位数多的数大。', 'u7l4'));
    } else if (stage == 1) {
      final base = ri(r, 2, 9) * 100;
      final opts = [base - 13, base - 2, base + 3];
      qs.add(choiceQ('最接近 ' + base.toString() + ' 的数是（　）', (base - 2).toString(),
          [opts[0].toString(), opts[2].toString()],
          base.toString() + '－' + (base - 2).toString() + '＝2，相差最小。', 'u7l4', r: r));
      qs.add(choiceQ(base.toString() + '－13 的近似数（大约是几百）是（　）', base.toString(),
          [(base - 100).toString(), (base + 100).toString()],
          '接近 ' + base.toString() + '，就约是 ' + base.toString() + '。', 'u7l4', r: r));
    } else {
      final a = ri(r, 300, 899);
      final b = a + ri(r, 1, 9);
      final c = a - ri(r, 1, 9);
      qs.add(inputQ('请写出 ' + a.toString() + '、' + b.toString() + '、' + c.toString() + ' 中最小的数。', c,
          '先比百位，百位相同比十位、个位。', 'u7l4'));
      qs.add(choiceQ('一台电视机 ' + (ri(r, 20, 30) * 100).toString() + ' 元，大约是几千元？这道题是让我们求（　）',
          '近似数', ['准确数', '总数'], '用"大约"描述的数是近似数。', 'u7l4', r: r));
    }
  }
  return dedupe(qs, 12);
}
