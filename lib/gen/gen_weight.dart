import 'dart:math';
import '../models.dart';
import 'util.dart';

/// 常见物品 + 它该用的质量单位
const List<List<String>> _heavier = [
  ['一个西瓜', '4 千克'],
  ['一个书包', '3 千克'],
  ['一袋大米', '10 千克'],
  ['一头大象', '2000 千克'],
  ['一只小猫', '3 千克'],
  ['一箱牛奶', '5 千克'],
  ['一台电视机', '15 千克'],
];

const List<List<String>> _lighter = [
  ['一枚一元硬币', '6 克'],
  ['一个鸡蛋', '50 克'],
  ['一支铅笔', '5 克'],
  ['一本数学书', '200 克'],
  ['一颗糖', '5 克'],
  ['一根香蕉', '120 克'],
  ['一个苹果', '200 克'],
  ['一块橡皮', '10 克'],
];

/// u8l1 认识克和千克
List<Question> genWeight(Random r, int stage) {
  final qs = <Question>[];

  for (var t = 0; t < 24; t++) {
    if (stage == 0) {
      switch (t % 8) {
        case 0:
          {
            final kg = ri(r, 2, 9);
            qs.add(inputQ('$kg 千克＝（　）克', kg * 1000,
                '1 千克＝1000 克，$kg 千克就是 ${kg * 1000} 克。', 'u8l1'));
          }
        case 1:
          {
            final kg = ri(r, 2, 9);
            qs.add(inputQ('${kg * 1000} 克＝（　）千克', kg,
                '1000 克＝1 千克，${kg * 1000} 克里有 $kg 个 1000 克。', 'u8l1'));
          }
        case 2:
          {
            final item = _lighter[ri(r, 0, _lighter.length - 1)];
            qs.add(choiceQ('${item[0]}约重 ${item[1]}（　）',
                '克', ['千克', '米'], '${item[0]}很轻，用克作单位。', 'u8l1',
                r: r));
          }
        case 3:
          {
            final item = _heavier[ri(r, 0, _heavier.length - 1)];
            qs.add(choiceQ('${item[0]}约重 ${item[1]}（　）',
                '千克', ['克', '厘米'], '${item[0]}很重，用千克作单位。', 'u8l1',
                r: r));
          }
        case 4:
          {
            final w = _pick([50, 100, 200, 250, 500], r);
            final name = _lighter.firstWhere((e) => e[1] == '$w 克',
                orElse: () => ['这样的东西', '$w 克'])[0];
            qs.add(inputQ(
                '$name 约重 $w 克，（　）个这样的东西约重 1 千克',
                1000 ~/ w,
                '1000÷$w＝${1000 ~/ w}（个）。', 'u8l1'));
          }
        case 5:
          qs.add(choiceQ('称比较轻的物品，常用（　）作单位', '克',
              ['千克', '米'], '轻的东西用克作单位。', 'u8l1', r: r));
        case 6:
          qs.add(choiceQ('称比较重的物品，常用（　）作单位', '千克',
              ['克', '厘米'], '重的东西用千克作单位。', 'u8l1', r: r));
        default:
          {
            final n = _pick([2, 3, 4, 5, 6], r);
            qs.add(inputQ('${n * 500} 克里有几个 500 克？', n,
                '${n * 500}÷500＝$n。', 'u8l1'));
          }
      }
    } else if (stage == 1) {
      switch (t % 5) {
        case 0:
          {
            final kg = ri(r, 2, 9);
            qs.add(compareQ('${kg * 1000} 克', '$kg 千克', '=',
                '1 千克＝1000 克，${kg * 1000} 克就是 $kg 千克。', 'u8l1'));
          }
        case 1:
          {
            final kg = ri(r, 2, 9);
            final g = ri(r, 1, 9) * 100;
            qs.add(inputQ('$kg 千克＋$g 克＝（　）克', kg * 1000 + g,
                '先把千克换成克：$kg 千克＝${kg * 1000} 克，再加 $g 克。', 'u8l1'));
          }
        case 2:
          {
            final kg = ri(r, 2, 6);
            final g = ri(r, 1, 9) * 100;
            qs.add(inputQ('${kg * 1000 + g} 克＝（　）千克（　）克', kg * 1000 + g,
                '${kg * 1000 + g} 克里有 $kg 个 1000 克，也就是 $kg 千克 $g 克。',
                'u8l1'));
          }
        case 3:
          {
            final a = ri(r, 1, 4);
            final b = ri(r, 5, 9);
            qs.add(compareQ('$a 千克', '${b * 100} 克', '<',
                '$a 千克＝${a * 1000} 克，比 ${b * 100} 克少。', 'u8l1'));
          }
        default:
          {
            final a = ri(r, 3, 9);
            final b = ri(r, 1, 9) * 100;
            qs.add(compareQ('$a 千克', '$b 克', '＞',
                '$a 千克＝${a * 1000} 克，比 $b 克重。', 'u8l1'));
          }
      }
    } else {
      switch (t % 5) {
        case 0:
          {
            final apples = ri(r, 4, 6);
            final groups = ri(r, 2, 5);
            qs.add(inputQ(
                '$apples 个苹果约重 1 千克，${apples * groups} 个这样的苹果约重几千克？',
                groups,
                '${apples * groups} 里有 $groups 个 $apples，所以约重 $groups 千克。',
                'u8l1'));
          }
        case 1:
          {
            final kg = ri(r, 2, 5);
            final near = kg * 1000 - ri(r, 1, 9) * 50;
            final far = ri(r, 1, 9) * 100;
            qs.add(choiceQ('下面最重的是（　）', '$kg 千克',
                ['$near 克', '$far 克'],
                '$kg 千克＝${kg * 1000} 克，比 $near 克重。', 'u8l1', r: r));
          }
        case 2:
          {
            final bag = ri(r, 2, 5);
            final each = ri(r, 2, 5) * 100;
            qs.add(inputQ(
                '一袋米重 $bag 千克，吃了 $each 克，还剩多少克？',
                bag * 1000 - each,
                '$bag 千克＝${bag * 1000} 克，${bag * 1000}－$each＝${bag * 1000 - each} 克。',
                'u8l1'));
          }
        case 3:
          {
            final n = ri(r, 3, 6);
            qs.add(inputQ('1 个西瓜约重 $n 千克，${n * 2} 个这样的西瓜约重几千克？',
                n * 2, '$n×2＝${n * 2}（千克）。', 'u8l1'));
          }
        default:
          {
            final left = ri(r, 2, 4);
            final right = left + ri(r, 1, 3);
            qs.add(choiceQ('$left 千克 和 ${right * 1000} 克，哪个重？',
                '${right * 1000} 克', ['$left 千克', '一样重'],
                '$left 千克＝${left * 1000} 克，比 ${right * 1000} 克轻。', 'u8l1',
                r: r));
          }
      }
    }
  }
  return dedupe(qs, 12);
}

/// 从整数池里随机取一个
int _pick(List<int> list, Random r) => list[ri(r, 0, list.length - 1)];