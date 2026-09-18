import 'dart:math';
import '../models.dart';
import '../gen/util.dart';
import '../gen/gen_stats.dart';
import '../gen/gen_div1.dart';
import '../gen/gen_motion.dart';
import '../gen/gen_div2.dart';
import '../gen/gen_mixed.dart';
import '../gen/gen_remainder.dart';
import '../gen/gen_bignum.dart';
import '../gen/gen_weight.dart';
import '../gen/gen_reasoning.dart';
import '../store.dart';

/// 人教版二年级下册（经典版）课时划分
final List<Unit> units = [
  Unit('u1', '数据收集整理', '📊', [
    Lesson('u1l1', '收集与整理数据', genStats),
  ]),
  Unit('u2', '表内除法（一）', '➗', [
    Lesson('u2l1', '平均分', genAvgDiv),
    Lesson('u2l2', '除法的初步认识', genDivMeaning),
    Lesson('u2l3', '用 2～6 的口诀求商', genDivFacts26),
    Lesson('u2l4', '解决问题', genDivStory1),
  ]),
  Unit('u3', '图形的运动（一）', '🎡', [
    Lesson('u3l1', '轴对称', genSymmetry),
    Lesson('u3l2', '平移', genTranslate),
    Lesson('u3l3', '旋转', genRotate),
  ]),
  Unit('u4', '表内除法（二）', '🧮', [
    Lesson('u4l1', '用 7/8/9 的口诀求商', genDivFacts789),
    Lesson('u4l2', '解决问题', genDivStory2),
  ]),
  Unit('u5', '混合运算', '🔢', [
    Lesson('u5l1', '同级运算', genMixedSame),
    Lesson('u5l2', '两级运算', genMixedTwoLevel),
    Lesson('u5l3', '含小括号', genMixedParen),
    Lesson('u5l4', '解决问题', genMixedStory),
  ]),
  Unit('u6', '有余数的除法', '🍪', [
    Lesson('u6l1', '认识有余数的除法', genRemBasic),
    Lesson('u6l2', '竖式与试商', genRemTry),
    Lesson('u6l3', '解决问题', genRemStory),
    Lesson('u6l4', '找规律', genRemCycle),
  ]),
  Unit('u7', '万以内数的认识', '🎯', [
    Lesson('u7l1', '1000 以内的数', genNum1000),
    Lesson('u7l2', '10000 以内的数', genNum10000),
    Lesson('u7l3', '整百整十加减', genRoundAdd),
    Lesson('u7l4', '比较与近似数', genNumCompare),
  ]),
  Unit('u8', '克和千克', '⚖️', [
    Lesson('u8l1', '克和千克', genWeight),
  ]),
  Unit('u9', '数学广角——推理', '🕵️', [
    Lesson('u9l1', '简单推理', genReasonSimple),
    Lesson('u9l2', '数与符号', genReasonGrid),
  ]),
  Unit('u10', '总复习', '🏆', [
    Lesson('u10l1', '综合大闯关', genReview),
  ]),
];

final List<Lesson> allLessons = () {
  final out = <Lesson>[];
  for (final u in units) {
    out.addAll(u.lessons);
  }
  return out;
}();

/// 全部关卡 key 的全局顺序（lessonId:s阶段）
final List<String> orderedLevelKeys = () {
  final out = <String>[];
  for (final l in allLessons) {
    for (var s = 0; s < 3; s++) {
      out.add(l.id + ':s' + s.toString());
    }
  }
  return out;
}();

String lessonTitle(String id) {
  for (final l in allLessons) {
    if (l.id == id) return l.title;
  }
  return id;
}

Unit? unitOfLesson(String id) {
  for (final u in units) {
    for (final l in u.lessons) {
      if (l.id == id) return u;
    }
  }
  return null;
}

/// 总复习：从其他所有课时抽题混合
List<Question> genReview(Random r, int stage) {
  final pool = allLessons.where((l) => l.id != 'u10l1').toList();
  final qs = <Question>[];
  var tries = 0;
  while (qs.length < 18 && tries++ < 300) {
    final lesson = pool[ri(r, 0, pool.length - 1)];
    qs.addAll(lesson.gen(r, stage).take(2));
  }
  swapShuffle(qs, r);
  return dedupe(qs, 18);
}

/// 今日任务：当前课时为主 + 薄弱复习 + 错题
List<Question> buildTodayQuestions(List<Map<String, dynamic>> mistakes, String? weakId) {
  final r = Random();
  final cur = allLessons.firstWhere((l) => l.id == currentLessonIdOrDefault(),
      orElse: () => allLessons.first);
  final qs = <Question>[];
  qs.addAll(cur.gen(r, 1).take(4));
  if (weakId != null && weakId != cur.id) {
    qs.addAll(allLessons.firstWhere((l) => l.id == weakId).gen(r, 0).take(2));
  } else {
    qs.addAll(cur.gen(r, 0).take(2));
  }
  if (mistakes.isNotEmpty) {
    qs.addAll(mistakes.take(2).map((m) => Question.fromJson(m['q'] as Map<String, dynamic>)));
  } else {
    qs.addAll(cur.gen(r, 0).take(2));
  }
  swapShuffle(qs, r);
  return qs.take(8).toList();
}

String currentLessonIdOrDefault() => ProgressStore().currentLesson;
