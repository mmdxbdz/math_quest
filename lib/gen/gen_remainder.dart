import 'dart:math';
import '../models.dart';
import 'util.dart';

/// u6l1 有余数除法的认识
List<Question> genRemBasic(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 4; t++) {
    final d = ri(r, 3, 9);
    final q0 = ri(r, 2, 9);
    final rem = ri(r, 1, d - 1);
    final p = d * q0 + rem;
    if (stage == 0) {
      qs.add(doubleQ(p.toString() + '÷' + d.toString() + '＝（　）……（　）', q0, rem,
          p.toString() + '＝' + d.toString() + '×' + q0.toString() + '＋' + rem.toString() + '，商 ' + q0.toString() + ' 余 ' + rem.toString() + '。', 'u6l1',
          labels: ['商', '余数']));
      qs.add(choiceQ('在有余数的除法里，余数一定要比除数（　）', '小', ['大', '相等'],
          '余数如果等于或超过除数，说明还能再分一次。', 'u6l1', r: r));
    } else if (stage == 1) {
      qs.add(inputQ(p.toString() + '÷' + d.toString() + '＝' + q0.toString() + '……（　）', rem,
          p.toString() + '－' + (d * q0).toString() + '＝' + rem.toString() + '，余数是 ' + rem.toString() + '。', 'u6l1'));
      qs.add(inputQ('（　）÷' + d.toString() + '＝' + q0.toString() + '……' + rem.toString() + '，被除数是几？', p,
          '被除数＝除数×商＋余数：' + d.toString() + '×' + q0.toString() + '＋' + rem.toString() + '＝' + p.toString() + '。', 'u6l1'));
    } else {
      qs.add(inputQ('14 个★，每 4 个分一组，可以分几组？', 3,
          '14÷4＝3（组）……2（个），商是 3 组。', 'u6l1'));
      final d3 = ri(r, 4, 9);
      final q3 = ri(r, 2, 9);
      final p3 = d3 * q3 + 3;
      qs.add(choiceQ('下面哪道算式的余数是 3？', p3.toString() + '÷' + d3.toString(),
          [(p3 - 1).toString() + '÷' + d3.toString(), (p3 - 2).toString() + '÷' + d3.toString()],
          p3.toString() + '÷' + d3.toString() + '＝' + q3.toString() + '……3，其余算式的余数不是 3。', 'u6l1', r: r));
    }
  }
  return dedupe(qs, 12);
}

/// u6l2 竖式与试商
List<Question> genRemTry(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 4; t++) {
    if (stage == 0) {
      qs.add(inputQ('□÷6＝8……□，余数最大是几？', 5, '余数要比除数小，最大是 6－1＝5。', 'u6l2'));
      final d4 = ri(r, 4, 9);
      final q4 = ri(r, 2, 9);
      final rem4 = ri(r, 1, d4 - 1);
      final p4 = d4 * q4 + rem4;
      qs.add(inputQ(p4.toString() + '÷' + d4.toString() + ' 的商是几？', q4,
          d4.toString() + '×' + q4.toString() + '＝' + (d4 * q4).toString() + '，最接近 ' + p4.toString() + '，所以商是 ' + q4.toString() + '。', 'u6l2'));
    } else if (stage == 1) {
      final d = ri(r, 4, 9);
      final q0 = ri(r, 3, 9);
      qs.add(inputQ('□÷' + d.toString() + '＝' + q0.toString() + '……□，被除数最大是几？', d * q0 + d - 1,
          '余数最大是 ' + (d - 1).toString() + '，被除数＝' + d.toString() + '×' + q0.toString() + '＋' + (d - 1).toString() + '＝' + (d * q0 + d - 1).toString() + '。', 'u6l2'));
      final m = ri(r, 30, 60);
      final k = ri(r, 6, 9);
      qs.add(inputQ('（　）里最大能填几？　' + k.toString() + '×（　）＜ ' + m.toString(), (m - 1) ~/ k,
          k.toString() + '×' + ((m - 1) ~/ k).toString() + '＝' + (k * ((m - 1) ~/ k)).toString() + '＜' + m.toString() + '，再大就超过了。', 'u6l2'));
    } else {
      qs.add(inputQ('一道除法算式，除数是 8，商是 5，余数是 3，被除数是几？', 43,
          '8×5＋3＝43。', 'u6l2'));
      final d2 = ri(r, 5, 9);
      final rem2 = ri(r, 1, d2 - 1);
      final q2 = ri(r, 3, 8);
      qs.add(inputQ('一道除法算式的商是 ' + q2.toString() + '，余数是 ' + rem2.toString() + '，除数是 ' + d2.toString() + '，被除数是多少？',
          d2 * q2 + rem2, d2.toString() + '×' + q2.toString() + '＋' + rem2.toString() + '＝' + (d2 * q2 + rem2).toString() + '。', 'u6l2'));
    }
  }
  return dedupe(qs, 12);
}

/// u6l3 解决问题（进一法 / 去尾法）
List<Question> genRemStory(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 3; t++) {
    final d = ri(r, 4, 8);
    final q0 = ri(r, 3, 8);
    final rem = ri(r, 1, d - 1);
    final p = d * q0 + rem;
    if (stage == 0) {
      qs.add(inputQ(p.toString() + ' 人划船，每条船最多坐 ' + d.toString() + ' 人，至少要租几条船？', q0 + 1,
          p.toString() + '÷' + d.toString() + '＝' + q0.toString() + '（条）……' + rem.toString() + '（人），剩下的人也要坐船，所以要 ' + (q0 + 1).toString() + ' 条。', 'u6l3'));
      qs.add(inputQ(p.toString() + ' 元钱，买 ' + d.toString() + ' 元一本的本子，最多能买几本？', q0,
          p.toString() + '÷' + d.toString() + '＝' + q0.toString() + '（本）……' + rem.toString() + '（元），钱不够再买一本，所以最多买 ' + q0.toString() + ' 本。', 'u6l3'));
    } else if (stage == 1) {
      qs.add(inputQ(p.toString() + ' 个苹果，每盘放 ' + d.toString() + ' 个，全部放完至少要几个盘子？', q0 + 1,
          '多出 ' + rem.toString() + ' 个也要用一个盘子，用"进一法"。', 'u6l3'));
      qs.add(inputQ('做一个风筝要 ' + d.toString() + ' 米布，' + p.toString() + ' 米布最多能做几个？', q0,
          '剩下 ' + rem.toString() + ' 米不够做一个，用"去尾法"。', 'u6l3'));
    } else {
      final bus = ri(r, 20, 45);
      final cap = ri(r, 6, 9);
      qs.add(inputQ(bus.toString() + ' 名同学去春游，每辆车最多坐 ' + cap.toString() + ' 人，全部出发至少要租几辆车？',
          (bus ~/ cap) + (bus % cap == 0 ? 0 : 1), '看除完后有没有余数，有余数就要多租一辆。', 'u6l3'));
      qs.add(inputQ('每 ' + d.toString() + ' 个●串一串，' + p.toString() + ' 个●能串几串？', q0,
          p.toString() + '÷' + d.toString() + '＝' + q0.toString() + '（串）……' + rem.toString() + '（个）', 'u6l3'));
    }
  }
  return dedupe(qs, 9);
}

/// u6l4 找规律（周期问题）
List<Question> genRemCycle(Random r, int stage) {
  final qs = <Question>[];
  const shapes = ['□', '△', '○', '☆'];
  const colors = ['红', '黄', '蓝', '绿'];
  for (var t = 0; t < 4; t++) {
    final len = stage == 0 ? 3 : ri(r, 3, 4);
    final cyc = <String>[];
    final useColor = r.nextBool();
    for (var i = 0; i < len; i++) {
      cyc.add(useColor ? colors[i] : shapes[i]);
    }
    final pattern = cyc.join();
    final pos = ri(r, 8, 25);
    final idx = (pos - 1) % len;
    final correct = cyc[idx];
    if (stage == 0) {
      qs.add(choiceQ('按"' + pattern + pattern + '……"的顺序排列，第 ' + pos.toString() + ' 个是（　）', correct,
          [cyc[(idx + 1) % len], cyc[(idx + 2) % len]],
          '每 ' + len.toString() + ' 个一循环：' + pos.toString() + '÷' + len.toString() + '＝' + (pos ~/ len).toString() + '……' + ((pos - 1) % len + 1 - 1).toString() + '，余几就是循环里的第几个。', 'u9l4', r: r));
    } else if (stage == 1) {
      qs.add(choiceQ('彩灯按"' + pattern + '"的顺序重复亮起，第 ' + pos.toString() + ' 盏是什么颜色？', correct,
          cyc.where((c) => c != correct).toList(),
          '第 ' + pos.toString() + ' 盏：' + pos.toString() + '÷' + len.toString() + ' 余 ' + idx.toString() + '，是循环里的第 ' + (idx + 1).toString() + ' 个。', 'u6l4', r: r));
    } else {
      qs.add(inputQ('按"' + pattern + '"排列，第 ' + pos.toString() + ' 个是循环里的第几个？（填 1～' + len.toString() + '）', idx + 1,
          (pos - 1).toString() + '÷' + len.toString() + '……用余数判断：余 ' + idx.toString() + ' 就是第 ' + (idx + 1).toString() + ' 个。', 'u6l4'));
      qs.add(inputQ('按"' + pattern + '"排列，前 ' + (len * 4).toString() + ' 个里有几组完整的？', 4,
          len.toString() + ' 个一组，' + (len * 4).toString() + '÷' + len.toString() + '＝4（组）。', 'u6l4'));
    }
  }
  return dedupe(qs, 12);
}
