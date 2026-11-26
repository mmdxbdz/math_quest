import 'dart:math';
import '../models.dart';
import 'util.dart';

const List<String> _items = ['苹果', '糖果', '气球', '铅笔', '橡皮', '贴纸'];

/// u2l1 平均分
List<Question> genAvgDiv(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 30; t++) {
    final item = _items[ri(r, 0, _items.length - 1)];
    final n = ri(r, 2, 6);
    final each = ri(r, 2, 6);
    final total = n * each;
    final who = ri(r, 2, 5);

    if (stage == 0) {
      switch (t % 4) {
        case 0:
          qs.add(inputQ('$total 个$item，平均分成 $n 份，每份几个？',
              each, '$total÷$n＝$each（个）', 'u2l1'));
        case 1:
          qs.add(inputQ('$item有 $total 个，每 $each 个装一盘，能装几盘？',
              n, '$total÷$each＝$n（盘）', 'u2l1'));
        case 2:
          qs.add(inputQ('把 $total 个$item平均分成 $n 堆，每堆几个？',
              each, '$total÷$n＝$each（个）', 'u2l1'));
        default:
          qs.add(inputQ('$total 个$item，每人分 $each 个，可以分给几人？',
              n, '$total÷$each＝$n（人）', 'u2l1'));
      }
    } else if (stage == 1) {
      switch (t % 3) {
        case 0:
          qs.add(inputQ('把 $total 块糖平均分给 $who 个小朋友，每人分到几块？',
              total ~/ who, '$total÷$who＝${total ~/ who}（块）', 'u2l1'));
        case 1:
          {
            final k = ri(r, 2, 6);
            qs.add(choiceQ('下面哪种分法才是"平均分"？', '每份都是 $k 个',
                ['有的多、有的少', '想怎么分就怎么分'],
                '每份分得同样多，才叫平均分。', 'u2l1', r: r));
          }
        default:
          qs.add(inputQ('$who 个小朋友，每人分 $each 颗糖，一共要准备几颗糖？',
              who * each, '$who×$each＝${who * each}（颗）', 'u2l1'));
      }
    } else {
      switch (t % 3) {
        case 0:
          {
            final extra = ri(r, 1, 3);
            qs.add(inputQ(
                '$total 个$item，平均分成 $n 份后，还剩 $extra 个没分出去。原来一共有多少个？',
                total + extra,
                '先算分掉的：$n×$each＝$total，再加上剩下的 $extra 个。', 'u2l1'));
          }
        case 1:
          qs.add(inputQ('$total 个$item，每人分 $each 个，可以分给几个人？',
              n, '$total÷$each＝$n（人）', 'u2l1'));
        default:
          {
            final left = ri(r, 1, 4);
            qs.add(inputQ(
                '有 ${total + left} 个$item，平均分给 $n 个小朋友，每人分到几个？还剩几个？（只填每人分到几个）',
                each,
                '${total + left}÷$n＝$each……$left，每人 $each 个。', 'u2l1'));
          }
      }
    }
  }
  // 只保留不重复的题，绝不用重复补位
  final seen = <String>{};
  final out = <Question>[];
  for (final q in qs) {
    if (seen.add(q.stem)) out.add(q);
    if (out.length >= 12) break;
  }
  return out;
}

/// u2l2 除法的初步认识
List<Question> genDivMeaning(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 30; t++) {
    final a = ri(r, 2, 9);
    final b = ri(r, 2, 9);
    final p = a * b;
    if (stage == 0) {
      switch (t % 4) {
        case 0:
          qs.add(choiceQ('$p÷$a=$b　读作（　）',
              '$p除以$a等于$b',
              ['$p除$a等于$b', '$a除以$p等于$b'],
              '除法算式从被除数读起：$p 除以 $a 等于 $b。', 'u2l2', r: r));
        case 1:
          qs.add(choiceQ('在 $p÷$a=$b 中，$b 是（　）', '商',
              ['被除数', '除数'],
              '除号前面是被除数，除号后面是除数，等号后面是商。', 'u2l2', r: r));
        case 2:
          qs.add(choiceQ('在 $p÷$a=$b 中，$a 是（　）', '除数',
              ['被除数', '商'],
              '除号后面的数是除数。', 'u2l2', r: r));
        default:
          qs.add(choiceQ('在 $p÷$a=$b 中，$p 是（　）', '被除数',
              ['除数', '商'],
              '除号前面的数是被除数。', 'u2l2', r: r));
      }
    } else if (stage == 1) {
      switch (t % 3) {
        case 0:
          qs.add(doubleQ('$p÷$a=$b，表示把 $p 平均分成（　）份，每份是（　）。',
              a, b, '$p÷$a：把 $p 平均分成 $a 份，每份 $b。', 'u2l2',
              labels: ['份数', '每份的个数']));
        case 1:
          qs.add(inputQ('被除数是 $p，除数是 $a，商是几？', b,
              '$p÷$a=$b', 'u2l2'));
        default:
          qs.add(inputQ('$b 个 $a 是多少？', p, '$a×$b=$p。', 'u2l2'));
      }
    } else {
      switch (t % 3) {
        case 0:
          {
            final a6 = a == 6 ? 7 : a;
            qs.add(choiceQ('把 6×$a6＝${6 * a6} 改写成除法算式，错误的是（　）',
                '$a6÷${6 * a6}=6',
                ['${6 * a6}÷$a6=6', '${6 * a6}÷6=$a6'],
                '被除数是乘法算式的积，要写在除号前面。', 'u2l2', r: r));
          }
        case 1:
          qs.add(inputQ('$p 里面有 $b 个几？', a,
              '$p÷$b=$a，所以是 $b 个 $a。', 'u2l2'));
        default:
          qs.add(inputQ('把 $p 平均分成 $a 份，每份是几个？', b,
              '$p÷$a=$b，每份 $b 个。', 'u2l2'));
      }
    }
  }
  final seen = <String>{};
  final out = <Question>[];
  for (final q in qs) {
    if (seen.add(q.stem)) out.add(q);
    if (out.length >= 12) break;
  }
  return out;
}

/// u2l3 用 2~6 的乘法口诀求商
List<Question> genDivFacts26(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 20; t++) {
    final a = ri(r, 2, 6);
    final b = ri(r, 2, 6);
    final p = a * b;
    if (stage == 0) {
      qs.add(inputQ(p.toString() + '÷' + a.toString() + '＝？', b,
          '想口诀"' + kouJue(a, b) + '"，所以 ' + p.toString() + '÷' + a.toString() + '=' + b.toString() + '。', 'u2l3'));
      qs.add(inputQ(p.toString() + '÷' + b.toString() + '＝？', a,
          '想口诀"' + kouJue(a, b) + '"，所以 ' + p.toString() + '÷' + b.toString() + '=' + a.toString() + '。', 'u2l3'));
    } else if (stage == 1) {
      qs.add(inputQ('从 ' + p.toString() + ' 里连续减去 ' + a.toString() + '，减几次正好减完？', b,
          p.toString() + '÷' + a.toString() + '=' + b.toString() + '，所以要减 ' + b.toString() + ' 次。', 'u2l3'));
      qs.add(inputQ('一道除法题，除数是 ' + a.toString() + '，商是 ' + b.toString() + '，被除数是几？', p,
          '被除数＝除数×商：' + a.toString() + '×' + b.toString() + '=' + p.toString() + '。', 'u2l3'));
    } else {
      final c = ri(r, 3, 7);
      final m = a * c - 1;
      qs.add(inputQ('（　）里最大能填几？　' + a.toString() + '×（　）＜ ' + m.toString(), c - 1,
          a.toString() + '×' + (c - 1).toString() + '=' + (a * (c - 1)).toString() + '＜' + m.toString() + '，再大就超过 ' + m.toString() + ' 了。', 'u2l3'));
      qs.add(choiceQ('被除数和除数相同（都不为 0），商是（　）', '1', ['0', '它本身'],
          '比如 5÷5=1，相同的数相除商是 1。', 'u2l3', r: r));
    }
  }
  return dedupe(qs, 12);
}

/// u2l4 用除法解决问题
List<Question> genDivStory1(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 16; t++) {
    final a = ri(r, 3, 9);
    final b = ri(r, 3, 9);
    final p = a * b;
    if (stage == 0) {
      qs.add(inputQ(p.toString() + '个球，每 ' + a.toString() + ' 个装一盒，可以装几盒？', b,
          p.toString() + '÷' + a.toString() + '=' + b.toString() + '（盒）', 'u2l4'));
      qs.add(inputQ(p.toString() + '朵花，平均插在 ' + b.toString() + ' 个花瓶里，每个花瓶插几朵？', a,
          p.toString() + '÷' + b.toString() + '=' + a.toString() + '（朵）', 'u2l4'));
    } else if (stage == 1) {
      qs.add(inputQ('一支笔 ' + a.toString() + ' 元，' + p.toString() + ' 元可以买几支？', b,
          p.toString() + '÷' + a.toString() + '=' + b.toString() + '（支）', 'u2l4'));
      qs.add(inputQ('每盒装 ' + a.toString() + ' 个球，' + b.toString() + ' 盒一共装多少个？', p,
          a.toString() + '×' + b.toString() + '=' + p.toString() + '（个）', 'u2l4'));
    } else {
      final eat = ri(r, 2, 5);
      qs.add(inputQ('有 ' + p.toString() + ' 个苹果，吃掉 ' + eat.toString() + ' 个，剩下的每 ' + a.toString() + ' 个装一盘，能装几盘？',
          (p - eat) ~/ a, '先算剩下的：' + p.toString() + '－' + eat.toString() + '=' + (p - eat).toString() + '，再除以每盘的个数。', 'u2l4'));
      qs.add(inputQ('一本书 ' + a.toString() + ' 元，小明带的钱正好能买 ' + b.toString() + ' 本。小明带了多少元？', p,
          a.toString() + '×' + b.toString() + '=' + p.toString() + '（元）', 'u2l4'));
    }
  }
  return dedupe(qs, 12);
}
