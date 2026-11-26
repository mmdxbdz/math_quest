import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_quest/content/challenge.dart';
import 'package:math_quest/models.dart';
import 'package:math_quest/store.dart';

void main() {
  test('思维挑战 9 关：题量正确且题目合法', () {
    final r = Random(7);
    for (final theme in challengeThemes) {
      for (final level in theme.levels) {
        final qs = level.gen(r, level.stage).take(level.qCount).toList();
        expect(qs.length, level.qCount, reason: level.id + ' 题量不足');
        for (final q in qs) {
          expect(q.skill, isNotEmpty, reason: q.stem);
          if (q.kind == AnswerKind.choice) {
            expect(q.options.contains(q.answer), isTrue, reason: q.stem);
            expect(q.options.toSet().length, q.options.length,
                reason: '选项重复: ' + q.stem);
          }
          if (q.kind == AnswerKind.input) {
            final v = int.tryParse(q.answer);
            expect(v, isNotNull, reason: '非数字答案: ' + q.stem);
            expect(v, greaterThanOrEqualTo(0), reason: '负数答案: ' + q.stem);
          }
          if (q.kind == AnswerKind.double) {
            expect(int.tryParse(q.answer), isNotNull, reason: q.stem);
            expect(int.tryParse(q.answer2), isNotNull, reason: q.stem);
            expect(q.slotLabels.length, 2, reason: q.stem);
          }
        }
      }
    }
  });

  test('生成器候选题量 ≥ 关卡题量（随机多轮）', () {
    for (var i = 0; i < 30; i++) {
      final r = Random(i);
      for (final theme in challengeThemes) {
        for (final level in theme.levels) {
          final qs = level.gen(r, level.stage);
          expect(qs.length, greaterThanOrEqualTo(level.qCount),
              reason: level.id + ' 候选不足');
        }
      }
    }
  });

  test('徽章记录：金不降级，主题徽章判定', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    store.resetAll();
    await store.load();

    store.markChallengeDone('ch-seq-1', 'silver');
    expect(store.challengeBadges['ch-seq-1'], 'silver');
    store.markChallengeDone('ch-seq-1', 'gold');
    expect(store.challengeBadges['ch-seq-1'], 'gold');
    // 已获金牌后拿银牌不降级
    store.markChallengeDone('ch-seq-1', 'silver');
    expect(store.challengeBadges['ch-seq-1'], 'gold');

    expect(themeDone(challengeThemes[0], store.challengeBadges), isFalse);
    store.markChallengeDone('ch-seq-2', 'gold');
    store.markChallengeDone('ch-seq-3', 'gold');
    expect(themeDone(challengeThemes[0], store.challengeBadges), isTrue);
    expect(allChallengesDone(store.challengeBadges), isFalse);
  });
}
