import 'dart:math';
import '../models.dart';
import 'util.dart';

const List<String> _animals = ['🐶 小狗', '🐰 小兔', '🐠 小鱼', '🐢 乌龟', '🐱 小猫', '🐔 小鸡'];

/// 生成一张不并列的统计表，返回 [四个名字, 四个人数, 表格题干]
List _makeTable(Random r) {
  while (true) {
    final pool = [..._animals];
    swapShuffle(pool, r);
    final names = pool.sublist(0, 4);
    final counts = List.generate(4, (_) => ri(r, 2, 9));
    final maxC = counts.reduce((a, b) => a > b ? a : b);
    final minC = counts.reduce((a, b) => a < b ? a : b);
    if (counts.where((c) => c == maxC).length == 1 &&
        counts.where((c) => c == minC).length == 1) {
      final sb = StringBuffer();
      sb.writeln('二（1）班同学最喜欢的小动物统计如下：');
      for (var i = 0; i < 4; i++) {
        sb.writeln(names[i] + '：' + counts[i].toString() + ' 人');
      }
      return [names, counts, sb.toString()];
    }
  }
}

List<Question> genStats(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 40; t++) {
    final mk = _makeTable(r);
    final names = mk[0] as List<String>;
    final counts = mk[1] as List<int>;
    final table = mk[2] as String;
    final maxI = counts.indexOf(counts.reduce((a, b) => a > b ? a : b));
    final minI = counts.indexOf(counts.reduce((a, b) => a < b ? a : b));

    if (stage == 0) {
      switch (t % 4) {
        case 0:
          qs.add(choiceQ(table + '\n哪种动物喜欢的人最多？', names[maxI],
              [names[(maxI + 1) % 4], names[(maxI + 2) % 4]],
              '人数最多的就是最喜欢的。', 'u1l1', r: r));
        case 1:
          qs.add(choiceQ(table + '\n哪种动物喜欢的人最少？', names[minI],
              [names[(minI + 1) % 4], names[(minI + 2) % 4]],
              '人数最少的就是最不喜欢的。', 'u1l1', r: r));
        case 2:
          {
            final i = ri(r, 0, 3);
            qs.add(choiceQ(
                table + '\n喜欢' + names[i].substring(3) + '的有几人？',
                counts[i].toString() + ' 人',
                [
                  (counts[i] + 1).toString() + ' 人',
                  max(0, counts[i] - 1).toString() + ' 人'
                ],
                '直接从表格里数一数，' + names[i] + '是 ' + counts[i].toString() + ' 人。',
                'u1l1',
                r: r));
          }
        default:
          {
            final multi = counts[maxI] - counts[minI];
            qs.add(choiceQ(
                table + '\n喜欢' + names[maxI].substring(3) + '的比喜欢' + names[minI].substring(3) + '的多几人？',
                multi.toString() + ' 人',
                ['${multi - 1} 人', '${multi + 1} 人'],
                '${counts[maxI]}－${counts[minI]}＝$multi（人）。', 'u1l1',
                r: r));
          }
      }
    } else if (stage == 1) {
      final sum = counts.fold(0, (a, b) => a + b);
      switch (t % 3) {
        case 0:
          qs.add(inputQ(table + '\n一共有多少人参加了调查？', sum,
              '把四个数加起来：' + counts.join(' + ') + ' = ' + sum.toString() + '。', 'u1l1'));
        case 1:
          {
            final a = ri(r, 0, 3);
            var b = ri(r, 0, 3);
            if (b == a) b = (b + 1) % 4;
            final big = counts[a] > counts[b] ? a : b;
            final small = counts[a] > counts[b] ? b : a;
            qs.add(inputQ(
                table + '\n喜欢' + names[big].substring(3) + '的比喜欢' + names[small].substring(3) + '的多几人？',
                counts[big] - counts[small],
                names[big] + '有' + counts[big].toString() + '人，' + names[small] + '有' + counts[small].toString() + '人，用减法。',
                'u1l1'));
          }
        default:
          {
            final a = ri(r, 0, 3);
            var b = ri(r, 0, 3);
            if (b == a) b = (b + 1) % 4;
            qs.add(inputQ(
                table + '\n喜欢' + names[a].substring(3) + '的和喜欢' + names[b].substring(3) + '的一共有多少人？',
                counts[a] + counts[b],
                '${counts[a]}＋${counts[b]}＝${counts[a] + counts[b]}（人）。', 'u1l1'));
          }
      }
    } else {
      switch (t % 4) {
        case 0:
          {
            final i = ri(r, 0, 3);
            final add = ri(r, 2, 5);
            qs.add(inputQ(
                table + '\n又转来 $add 名喜欢' + names[i].substring(3) + '的同学，现在喜欢' + names[i].substring(3) + '的有多少人？',
                counts[i] + add,
                '原来' + counts[i].toString() + '人，加上转来的 ' + add.toString() + ' 人。', 'u1l1'));
          }
        case 1:
          {
            final i = ri(r, 0, 3);
            final j = (i + 1) % 4;
            qs.add(inputQ(
                table + '\n喜欢' + names[i].substring(3) + '的和喜欢' + names[j].substring(3) + '的一共有多少人？',
                counts[i] + counts[j],
                names[i] + counts[i].toString() + '人，' + names[j] + counts[j].toString() + '人，合起来用加法。',
                'u1l1'));
          }
        case 2:
          qs.add(inputQ(
              table + '\n如果每个同学画一朵花，一共要画多少朵？',
              counts.fold(0, (a, b) => a + b),
              '人数加起来：' + counts.join(' + ') + '。', 'u1l1'));
        default:
          {
            final drop = ri(r, 1, 3);
            final i = ri(r, 0, 3);
            qs.add(inputQ(
                table + '\n有 $drop 名喜欢' + names[i].substring(3) + '的同学转学了，现在喜欢' + names[i].substring(3) + '的有多少人？',
                counts[i] - drop,
                '${counts[i]}－$drop＝${counts[i] - drop}（人）。', 'u1l1'));
          }
      }
    }
  }
  // 每轮只出一题，多跑几轮凑够不重复的题（不要用补位重复）
  final seen = <String>{};
  final out = <Question>[];
  for (final q in qs) {
    if (seen.add(q.stem)) out.add(q);
    if (out.length >= 14) break;
  }
  return out;
}
