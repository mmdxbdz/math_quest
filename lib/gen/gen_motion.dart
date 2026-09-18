import 'dart:math';
import '../models.dart';
import 'util.dart';

const List<String> _symChars = ['田', '王', '中', '日', '一', '十', '品', '木', '美', '人', '天', '山', '出', '工'];
const List<String> _asymChars = ['我', '们', '数', '学', '好', '玩', '猫', '狗', '飞', '边', '题', '空', '路', '比'];
const List<String> _pingyi = ['拉抽屉', '电梯升降', '推箱子', '升国旗', '缆车滑动', '滑滑梯'];
const List<String> _rotate = ['风车转动', '拧水龙头', '摩天轮转动', '钟表指针走动', '风扇叶片转动', '拧瓶盖'];

String _pick(List<String> list, Random r) => list[ri(r, 0, list.length - 1)];

/// u3l1 轴对称
List<Question> genSymmetry(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 4; t++) {
    final sym = _pick(_symChars, r);
    var a1 = _pick(_asymChars, r);
    var a2 = _pick(_asymChars, r);
    var guard = 0;
    while ((a2 == a1) && guard++ < 20) a2 = _pick(_asymChars, r);
    if (stage == 0) {
      qs.add(choiceQ('下面的字中，沿中线对折后两边能完全重合（对称）的是（　）', sym, [a1, a2],
          '"' + sym + '"是对称的，对折后两边完全一样。', 'u3l1', r: r));
      qs.add(choiceQ('下面的字中，不是对称的是（　）', a1, [sym, a2],
          '"' + a1 + '"对折后两边不能重合。', 'u3l1', r: r));
    } else if (stage == 1) {
      final sym2 = _pick(['0', '8', '王', '日', '中'], r);
      qs.add(choiceQ('对折后能完全重合的数字或字是（　）', sym2, [a1, a2],
          '"' + sym2 + '"左右两边完全一样。', 'u3l1', r: r));
      qs.add(choiceQ('对称图形沿对称轴对折，两边（　）', '完全重合', ['会变大', '差一点'], '对称图形对折后两边完全重合。', 'u3l1', r: r));
    } else {
      qs.add(choiceQ('下面的活动中，利用了对称的是（　）', '把纸对折后剪出花纹', ['把箱子推直走', '把瓶盖拧开'],
          '剪纸就是利用对称图形的原理。', 'u3l1', r: r));
      qs.add(choiceQ('把纸对折 2 次，剪出小人手拉手，展开最多能出现几个手拉手的小人？', '4 个', ['2 个', '8 个'],
          '对折 1 次是 2 个，对折 2 次就是 4 个。', 'u3l1', r: r));
    }
  }
  return dedupe(qs, 12);
}

/// u3l2 平移
List<Question> genTranslate(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 3; t++) {
    final good = _pick(_pingyi, r);
    var b1 = _pick(_rotate, r);
    var b2 = _pick(_rotate, r);
    var guard = 0;
    while (b2 == b1 && guard++ < 20) b2 = _pick(_rotate, r);
    if (stage == 0) {
      qs.add(choiceQ('下列哪种现象是平移？', good, [b1, b2],
          '"' + good + '"是沿着直线移动，是平移。', 'u3l2', r: r));
    } else if (stage == 1) {
      final bad = _pick(_rotate, r);
      qs.add(choiceQ('下列哪种现象不是平移？', bad, [good, _pick(_pingyi, r)],
          '"' + bad + '"是转圈运动，是旋转。', 'u3l2', r: r));
    } else {
      qs.add(choiceQ('物体平移后，它的大小和形状（　）', '都不变', ['会变大', '会变形'], '平移只是位置变了，大小形状都不变。', 'u3l2', r: r));
      qs.add(choiceQ('升国旗时，国旗的运动是（　）', '平移', ['旋转', '对称'], '国旗沿旗杆直直地上升，是平移。', 'u3l2', r: r));
    }
  }
  return dedupe(qs, 9);
}

/// u3l3 旋转
List<Question> genRotate(Random r, int stage) {
  final qs = <Question>[];
  for (var t = 0; t < 3; t++) {
    final good = _pick(_rotate, r);
    var p1 = _pick(_pingyi, r);
    var p2 = _pick(_pingyi, r);
    var guard = 0;
    while (p2 == p1 && guard++ < 20) p2 = _pick(_pingyi, r);
    if (stage == 0) {
      qs.add(choiceQ('风车迎风转动是（　）现象', '旋转', ['平移', '对称'], '风车绕着中心转圈，是旋转。', 'u3l3', r: r));
      qs.add(choiceQ('下列现象中属于旋转的是（　）', good, [p1, p2],
          '"' + good + '"是绕着一个中心转圈，是旋转。', 'u3l3', r: r));
    } else if (stage == 1) {
      qs.add(choiceQ('拧开瓶盖，瓶盖的运动是（　）', '旋转', ['平移', '下落'], '拧瓶盖是绕中心转圈。', 'u3l3', r: r));
      qs.add(choiceQ('钟面上分针从 12 走到 3，分针的运动是（　）', '旋转', ['平移', '跳跃'], '指针绕着钟面中心转。', 'u3l3', r: r));
    } else {
      qs.add(choiceQ('下面既不是平移也不是旋转的是（　）', '拍皮球', ['拉抽屉', '转动方向盘'], '拍皮球是上下弹跳，不是平移也不是旋转。', 'u3l3', r: r));
      qs.add(choiceQ('汽车在直路上行驶，车身运动是（　）；车轮运动是（　）。这组答案正确的是（　）',
          '平移；旋转', ['旋转；平移', '都是平移'], '车身直行是平移，车轮转圈是旋转。', 'u3l3', r: r));
    }
  }
  return dedupe(qs, 9);
}
