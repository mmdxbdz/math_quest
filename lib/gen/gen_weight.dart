import 'dart:math';
import '../models.dart';
import 'util.dart';

/// u8l1 认识克和千克
List<Question> genWeight(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 4; t++) {
    if (stage == 0) {
      qs.add(inputQ('1 千克＝（　）克', 1000, '千克和克之间的进率是 1000。', 'u8l1'));
      qs.add(choiceQ('一个西瓜约重 4（　）', '千克', ['克', '米'], '西瓜比较重，用千克作单位。', 'u8l1', r: r));
      qs.add(choiceQ('一枚一元硬币约重 6（　）', '克', ['千克', '厘米'], '硬币很轻，用克作单位。', 'u8l1', r: r));
    } else if (stage == 1) {
      qs.add(compareQ('3000 克', '3 千克', '=', '1 千克＝1000 克，3000 克就是 3 千克。', 'u8l1'));
      final kg = ri(r, 2, 9);
      final g = ri(r, 1, 9) * 100;
      qs.add(inputQ(kg.toString() + ' 千克＋' + g.toString() + ' 克＝（　）克', kg * 1000 + g,
          '先把千克换成克：' + kg.toString() + ' 千克＝' + (kg * 1000).toString() + ' 克，再加。', 'u8l1'));
      qs.add(inputQ('6000 克＝（　）千克', 6, '6000 里面有 6 个 1000。', 'u8l1'));
    } else {
      final apples = ri(r, 4, 6);
      final groups = ri(r, 2, 5);
      qs.add(inputQ(apples.toString() + ' 个苹果约重 1 千克，' + (apples * groups).toString() + ' 个这样的苹果约重几千克？',
          groups, (apples * groups).toString() + ' 里有 ' + groups.toString() + ' 个 ' + apples.toString() + '，所以约重 ' + groups.toString() + ' 千克。', 'u8l1'));
      qs.add(choiceQ('下面最重的是（　）', '3 千克', ['2900 克', '500 克'],
          '3 千克＝3000 克，比 2900 克重。', 'u8l1', r: r));
      qs.add(compareQ('2 千克', '1500 克', '＞', '2 千克＝2000 克，比 1500 克重。', 'u8l1'));
    }
  }
  return dedupe(qs, 12);
}
