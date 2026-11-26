import 'dart:math';
import '../models.dart';

/// [a,b] 闭区间随机整数
int ri(Random r, int a, int b) => a + r.nextInt(b - a + 1);

void swapShuffle(List l, Random r) {
  for (var i = l.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final t = l[i];
    l[i] = l[j];
    l[j] = t;
  }
}

/// 生成 [correct] 附近、互不相同、且不等于 correct 的数字干扰项
List<int> nearNums(Random r, int correct, int count, {int min = 0, int max = 999}) {
  final out = <int>{};
  var guard = 0;
  while (out.length < count && guard++ < 500) {
    var v = correct + ri(r, -9, 9);
    if (r.nextBool()) v = correct + ri(r, 1, 6) * (r.nextBool() ? 1 : -1);
    if (v == correct || v < min || v > max) continue;
    out.add(v);
  }
  var k = 1;
  while (out.length < count) {
    final v = correct + k * (k % 2 == 0 ? 1 : -1) * 10;
    if (v >= min && v <= max && v != correct) out.add(v);
    k++;
  }
  return out.toList();
}

Question choiceQ(String stem, String correct, List<String> distractors,
    String explain, String lessonId,
    {Random? r, String? skill}) {
  final opts = [correct, ...distractors];
  if (r != null) swapShuffle(opts, r);
  return Question(
      kind: AnswerKind.choice,
      stem: stem,
      options: opts,
      answer: correct,
      explain: explain,
      lessonId: lessonId,
      skill: skill);
}

Question numChoice(String stem, int correct, Random r, String explain,
    String lessonId,
    {int n = 3, int min = 0, int max = 999, String? skill}) {
  final ds = nearNums(r, correct, n - 1, min: min, max: max).map((e) => '$e').toList();
  return choiceQ(stem, '$correct', ds, explain, lessonId, r: r, skill: skill);
}

Question inputQ(String stem, int answer, String explain, String lessonId,
    {String unit = '', String? skill}) {
  return Question(
      kind: AnswerKind.input,
      stem: stem,
      answer: '$answer',
      explain: explain,
      lessonId: lessonId,
      skill: skill);
}

Question compareQ(String left, String right, String cmp, String explain,
    String lessonId,
    {String? skill}) {
  return Question(
      kind: AnswerKind.compare,
      stem: '$left  ○  $right',
      answer: cmp,
      explain: explain,
      lessonId: lessonId,
      skill: skill);
}

Question doubleQ(String stem, int a1, int a2, String explain, String lessonId,
    {List<String> labels = const ['第一个空', '第二个空'], String? skill}) {
  return Question(
      kind: AnswerKind.double,
      stem: stem,
      answer: '$a1',
      answer2: '$a2',
      explain: explain,
      lessonId: lessonId,
      slotLabels: labels,
      skill: skill);
}

/// 保留题干互不重复的题，最多 [count] 道。
/// 候选不够就少出几道，**绝不重复补位**（重复的题会让娃觉得"怎么老一套"）。
List<Question> dedupe(List<Question> qs, int count) {
  final seen = <String>{};
  final out = <Question>[];
  for (final q in qs) {
    if (seen.add(q.stem)) out.add(q);
    if (out.length >= count) break;
  }
  return out;
}

const List<String> _cn = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

/// 乘法口诀：4×5→四五二十，2×2→二二得四
String kouJue(int a, int b) {
  final p = a * b;
  if (p < 10) return _cn[a] + _cn[b] + '得' + _cn[p];
  final t = p ~/ 10;
  final o = p % 10;
  return _cn[a] + _cn[b] + (t > 0 ? _cn[t] : '') + (o > 0 ? _cn[o] : '');
}
