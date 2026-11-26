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

/// 课程表：按知识点主题组织（标题为自拟名称，知识点范围参考课标，不使用教材原文与章节名）
final List<Unit> units = [
  Unit('u1', '小小调查员', '📊', [
    Lesson('u1l1', '数一数、排一排', genStats),
  ]),
  Unit('u2', '平均分东西', '➗', [
    Lesson('u2l1', '一样多', genAvgDiv),
    Lesson('u2l2', '认识除法', genDivMeaning),
    Lesson('u2l3', '口诀找商（2～6）', genDivFacts26),
    Lesson('u2l4', '除法小故事', genDivStory1),
  ]),
  Unit('u3', '图形的魔法', '🎡', [
    Lesson('u3l1', '照镜子（对称）', genSymmetry),
    Lesson('u3l2', '滑一滑（平移）', genTranslate),
    Lesson('u3l3', '转一转（旋转）', genRotate),
  ]),
  Unit('u4', '除法闯关营', '🧮', [
    Lesson('u4l1', '口诀找商（7～9）', genDivFacts789),
    Lesson('u4l2', '除法应用题', genDivStory2),
  ]),
  Unit('u5', '算式大冒险', '🔢', [
    Lesson('u5l1', '从左往右算', genMixedSame),
    Lesson('u5l2', '先乘除后加减', genMixedTwoLevel),
    Lesson('u5l3', '小括号优先', genMixedParen),
    Lesson('u5l4', '算式小故事', genMixedStory),
  ]),
  Unit('u6', '分不完怎么办', '🍪', [
    Lesson('u6l1', '分不完的余数', genRemBasic),
    Lesson('u6l2', '竖式试商', genRemTry),
    Lesson('u6l3', '余数应用题', genRemStory),
    Lesson('u6l4', '周期规律', genRemCycle),
  ]),
  Unit('u7', '大数王国', '🎯', [
    Lesson('u7l1', '千以内的数', genNum1000),
    Lesson('u7l2', '万以内的数', genNum10000),
    Lesson('u7l3', '整百整十算一算', genRoundAdd),
    Lesson('u7l4', '比大小、估一估', genNumCompare),
  ]),
  Unit('u8', '掂掂轻重', '⚖️', [
    Lesson('u8l1', '克与千克', genWeight),
  ]),
  Unit('u9', '小侦探推理', '🕵️', [
    Lesson('u9l1', '找找谁是谁', genReasonSimple),
    Lesson('u9l2', '数字符号谜', genReasonGrid),
  ]),
  Unit('u10', '综合大挑战', '🏆', [
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

/// 今日任务（8 题，精准复习）：
/// 1. 今天到期的错题（间隔复习回炉，最多 3 道）
/// 2. 正确率最低的知识点专项（最多 2 题）
/// 3. 当前课时新课（4 题）
/// 4. 不足 8 题时用当前课时基础题兜底
List<Question> buildTodayQuestions() {
  final r = Random();
  final store = ProgressStore();
  final cur = allLessons.firstWhere((l) => l.id == currentLessonIdOrDefault(),
      orElse: () => allLessons.first);
  final qs = <Question>[];

  // 1. 到期错题
  for (final m in store.dueMistakes().take(3)) {
    qs.add(Question.fromJson(m['q'] as Map<String, dynamic>));
  }
  // 2. 弱点知识点
  final weak = store.weakestSkill();
  if (weak != null) {
    qs.addAll(genForSkill(weak, r, 2));
  }
  // 3. 当前课时新课（提高难度）
  qs.addAll(cur.gen(r, 1).take(4));
  // 4. 兜底：当前课时基础题补满 8 道（与已有题不重复）
  final base = cur.gen(r, 0);
  var i = 0;
  while (qs.length < 8 && base.isNotEmpty && i < 60) {
    final q = base[i % base.length];
    if (!qs.any((e) => e.stem == q.stem)) qs.add(q);
    i++;
  }
  return dedupe(qs, 8);
}

String currentLessonIdOrDefault() => ProgressStore().currentLesson;

/// 知识点 -> 可读名称（细分 skill 有专门名字，否则用课时名）
String skillTitle(String skill) {
  const sub = {
    'u6l1:compute': '分不完的余数 · 算商和余数',
    'u6l1:rule': '分不完的余数 · 余数比除数小',
  };
  final s = sub[skill];
  if (s != null) return s;
  return lessonTitle(skill);
}

/// skill -> 所属课时（细分 skill 取前缀课时 id）
Lesson? lessonOfSkill(String skill) {
  final id = skill.contains(':') ? skill.substring(0, skill.indexOf(':')) : skill;
  for (final l in allLessons) {
    if (l.id == id) return l;
  }
  return null;
}

/// 按知识点出题：
/// - 课时粒度的 skill：直接生成该课时基础题
/// - 细分 skill：生成各阶段候选后按 skill 过滤（保证出的都是该知识点）
List<Question> genForSkill(String skill, Random r, int n) {
  final lesson = lessonOfSkill(skill);
  if (lesson == null) return [];
  if (!skill.contains(':')) {
    return dedupe(lesson.gen(r, 0), n);
  }
  final candidates = <Question>[];
  for (var s = 0; s < 3 && candidates.length < n * 6; s++) {
    candidates.addAll(lesson.gen(r, s));
  }
  final out = candidates.where((q) => q.skill == skill).toList();
  if (out.length >= n) return dedupe(out, n);
  return dedupe(lesson.gen(r, 0), n);
}
