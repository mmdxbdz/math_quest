import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/content/curriculum.dart';

/// 每个课时的每个阶段都要有足够多的不重复题，
/// 否则一关 10 道题里就会出现重复的题（曾经图形单元只有 1~2 道）。
void main() {
  test('每关都有足够多的不重复题目', () {
    final r = Random(7);
    final bad = <String>[];
    for (final l in allLessons) {
      for (var s = 0; s < 3; s++) {
        final seen = <String>{};
        for (var i = 0; i < 30; i++) {
          for (final q in l.gen(r, s)) {
            seen.add(q.stem);
          }
        }
        if (seen.length < 15) {
          bad.add('${l.id}:s$s 只有 ${seen.length} 道不重复的题');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('一关 10 道题不会有重复', () {
    for (final seed in [1, 2, 3, 4, 5, 6, 11, 42]) {
      final r = Random(seed);
      for (final l in allLessons) {
        for (var s = 0; s < 3; s++) {
          final qs = l.gen(r, s);
          final stems = qs.map((q) => q.stem).toList();
          final uniq = stems.toSet().length;
          expect(uniq, qs.length,
              reason: 'seed=$seed ${l.id}:s$s 生成 ${qs.length} 道题但只有 $uniq 道不重复');
          // 每关（默认 10 题）要能被填满
          expect(qs.length, greaterThanOrEqualTo(10),
              reason: 'seed=$seed ${l.id}:s$s 只生成了 ${qs.length} 道题，不够一关');
          // 选择题里正确答案必须真的在选项里，且选项不重复
          for (final q in qs) {
            if (q.options.isEmpty) continue;
            expect(q.options.contains(q.answer), isTrue,
                reason: '${l.id} 题干「${q.stem}」的答案不在选项里');
            expect(q.options.toSet().length, q.options.length,
                reason: '${l.id} 题干「${q.stem}」选项有重复');
          }
          // 题干、答案都不该是空的
          for (final q in qs) {
            expect(q.stem.trim(), isNotEmpty);
            expect(q.answer.trim(), isNotEmpty);
          }
        }
      }
    }
  });
}