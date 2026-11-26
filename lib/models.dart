import 'dart:math';

/// 题目的作答形式
enum AnswerKind { choice, input, compare, double }

/// 一道题
class Question {
  final AnswerKind kind;

  /// 题干，可包含多行（\n）与"___"空位
  final String stem;

  /// choice：选项；compare：固定 ＜ ＝ ＞，不用这里
  final List<String> options;

  /// 标准答案（input：数字字符串；compare：'<' '=' '>'；choice：选项原文）
  final String answer;

  /// double 题的第二个空
  final String answer2;

  /// 答错时的讲解
  final String explain;

  /// 所属课时 id（用于统计/错题归档）
  final String lessonId;

  /// 知识点 id：默认等于课时 id；可细分如 'u6l1:rule'（用于知识点级诊断）
  final String skill;

  /// double 题两个空的提示标签
  final List<String> slotLabels;

  Question({
    required this.kind,
    required this.stem,
    required this.answer,
    required this.lessonId,
    this.answer2 = '',
    this.options = const [],
    this.explain = '',
    this.slotLabels = const [],
    String? skill,
  }) : skill = skill ?? lessonId;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'stem': stem,
        'options': options,
        'answer': answer,
        'answer2': answer2,
        'explain': explain,
        'lessonId': lessonId,
        'skill': skill,
        'slotLabels': slotLabels,
      };

  static Question fromJson(Map<String, dynamic> j) => Question(
        kind: AnswerKind.values.firstWhere(
          (e) => e.name == (j['kind'] as String? ?? 'input'),
          orElse: () => AnswerKind.input,
        ),
        stem: j['stem'] as String? ?? '',
        options: (j['options'] as List?)?.cast<String>() ?? const [],
        answer: j['answer'] as String? ?? '',
        answer2: j['answer2'] as String? ?? '',
        explain: j['explain'] as String? ?? '',
        lessonId: j['lessonId'] as String? ?? '',
        skill: j['skill'] as String? ?? (j['lessonId'] as String? ?? ''),
        slotLabels: (j['slotLabels'] as List?)?.cast<String>() ?? const [],
      );
}

/// 生成器：给定随机源和难度阶段(0基础/1提高/2挑战)，产出一批题
typedef QuestionGen = List<Question> Function(Random rng, int stage);

class Lesson {
  final String id;
  final String title;
  final QuestionGen gen;
  const Lesson(this.id, this.title, this.gen);
}

class Unit {
  final String id;
  final String title;
  final String emoji;
  final List<Lesson> lessons;
  const Unit(this.id, this.title, this.emoji, this.lessons);
}

/// 一次奖惩记录（现实奖惩：家长按规则给孩子奖励/扣减）
class RewardRecord {
  /// 关卡标题
  final String lesson;

  /// 日期 yyyy-MM-dd
  final String dateKey;

  /// 本轮正确率 0~1
  final double score;

  /// 奖惩金额：>0 奖励，<0 罚，0 无奖惩（amount==0 时不生成记录）
  final int amount;

  /// 命中的规则名（'全对' / '90分以上' / '80分以下' / '70分以下'）
  final String rule;

  /// 家长是否已实施（标记后不再提醒）
  bool implemented;

  RewardRecord({
    required this.lesson,
    required this.dateKey,
    required this.score,
    required this.amount,
    required this.rule,
    this.implemented = false,
  });

  Map<String, dynamic> toJson() => {
        'lesson': lesson,
        'dateKey': dateKey,
        'score': score,
        'amount': amount,
        'rule': rule,
        'implemented': implemented,
      };

  factory RewardRecord.fromJson(Map<String, dynamic> j) => RewardRecord(
        lesson: j['lesson'] as String? ?? '',
        dateKey: j['dateKey'] as String? ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        rule: j['rule'] as String? ?? '',
        implemented: j['implemented'] as bool? ?? false,
      );
}
