import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_quest/store.dart';
import 'package:math_quest/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ProgressStore store = ProgressStore();

  Future<void> fresh() async {
    SharedPreferences.setMockInitialValues({});
    store.resetAll();
    await store.load();
  }

  Question mk(String stem, String lessonId, {String? skill}) => Question(
      kind: AnswerKind.input,
      stem: stem,
      answer: '7',
      lessonId: lessonId,
      skill: skill);

  test('答错进错题本并标记复习；再错重置阶段', () async {
    await fresh();
    final q = mk('3+4＝？', 'u5l1');
    store.recordAnswer(q, false, '6');
    expect(store.mistakes.length, 1);
    expect(store.mistakes.first['wrongCount'], 1);
    expect(store.mistakes.first['stage'], 0);

    store.recordAnswer(q, false, '5');
    expect(store.mistakes.length, 1);
    expect(store.mistakes.first['wrongCount'], 2);
    expect(store.mistakes.first['stage'], 0);
  });

  test('答对升级复习阶段，连续 4 轮答对才移出', () async {
    await fresh();
    final q = mk('6+7＝？', 'u5l1');
    store.recordAnswer(q, false, '10');
    for (var i = 1; i <= 3; i++) {
      store.recordAnswer(q, true, '13');
      expect(store.mistakes.length, 1, reason: '第 ' + i.toString() + ' 轮答对后不应移出');
      expect(store.mistakes.first['stage'], i);
    }
    store.recordAnswer(q, true, '13');
    expect(store.mistakes.length, 0, reason: '连续 4 轮答对应判定已掌握');
  });

  test('知识点统计按 skill 粒度累计', () async {
    await fresh();
    final q = mk('10÷3＝？', 'u6l1', skill: 'u6l1:compute');
    store.recordAnswer(q, true, '3');
    store.recordAnswer(q, false, '4');
    final st = store.skillStat('u6l1:compute');
    expect(st, [2, 1]);
    // 课时统计同步更新
    expect(store.lessonStat('u6l1'), [2, 1]);
  });

  test('一次答对统计：仅第一遍作答计入', () async {
    await fresh();
    final q1 = mk('3×4＝？', 'u2l3');
    store.recordAnswer(q1, true, '12', firstTry: true); // 一次答对
    store.recordAnswer(q1, true, '12'); // 复习阶段答对，不计入一次答对
    final q2 = mk('5×6＝？', 'u2l3');
    store.recordAnswer(q2, false, '20', firstTry: true); // 一次答错
    expect(store.firstTryRate('u2l3'), 0.5);
  });

  test('weakestSkill 找出正确率最低的知识点', () async {
    await fresh();
    final q1 = mk('2×3＝？', 'u2l3');
    store.recordAnswer(q1, true, '6');
    store.recordAnswer(q1, true, '6');
    store.recordAnswer(q1, true, '6');
    final q2 = mk('5×5＝？', 'u2l3');
    store.recordAnswer(q2, false, '10');
    store.recordAnswer(q2, false, '10');
    // u2l3: 3/5；u6l1 无数据。weakest 应为 u2l3
    expect(store.weakestSkill(), 'u2l3');
  });
}
