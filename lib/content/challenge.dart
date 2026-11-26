import 'dart:math';
import '../models.dart';
import '../gen/gen_challenge.dart';

/// 思维挑战 · 一关
class ChallengeLevel {
  final String id;    // 如 'ch-seq-1'
  final String title; // '入门' / '进阶' / '挑战'
  final int stage;    // 生成器难度档 0/1/2
  final int qCount;   // 每关题数 3/4/5
  final QuestionGen gen;
  const ChallengeLevel(this.id, this.title, this.stage, this.qCount, this.gen);
}

/// 思维挑战 · 一个主题
class ChallengeTheme {
  final String id;
  final String title;
  final String emoji;
  final String desc;
  final List<ChallengeLevel> levels;
  const ChallengeTheme(this.id, this.title, this.emoji, this.desc, this.levels);
}

ChallengeTheme _theme(String id, String title, String emoji, String desc,
    QuestionGen gen) {
  return ChallengeTheme(id, title, emoji, desc, [
    ChallengeLevel('ch-' + id + '-1', '入门', 0, 3, gen),
    ChallengeLevel('ch-' + id + '-2', '进阶', 1, 4, gen),
    ChallengeLevel('ch-' + id + '-3', '挑战', 2, 5, gen),
  ]);
}

/// 思维挑战全部主题
final List<ChallengeTheme> challengeThemes = [
  _theme('seq', '找规律', '🔍', '数列规律：等差、交替、等比、斐波那契…', genSeqChallenge),
  _theme('smart', '巧算', '⚡', '凑整速算：100 凑整、25×4、分配律启蒙…', genSmartChallenge),
  _theme('logic', '推理', '🧩', '排除法、数字谜、比较推理…', genLogicChallenge),
];

List<ChallengeLevel> get allChallengeLevels {
  final out = <ChallengeLevel>[];
  for (final t in challengeThemes) {
    out.addAll(t.levels);
  }
  return out;
}

/// 该主题 3 关是否都拿到徽章（金/银都算）
bool themeDone(ChallengeTheme theme, Map<String, String> badges) =>
    theme.levels.every((l) => badges.containsKey(l.id));

/// 该关徽章：null=未获得；'gold'=全对；'silver'=错 1 题
String? badgeOf(ChallengeLevel level, Map<String, String> badges) =>
    badges[level.id];

/// 9 关全部拿徽章 → 思维大师
bool allChallengesDone(Map<String, String> badges) =>
    allChallengeLevels.every((l) => badges.containsKey(l.id));

/// 给某关出题
List<Question> buildChallengeQuestions(ChallengeLevel level) {
  final r = Random();
  return level.gen(r, level.stage).take(level.qCount).toList();
}
