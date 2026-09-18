import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/gen/gen_remainder.dart';
import 'package:math_quest/models.dart';

void main() {
  test('每个课时每个阶段都能生成足够的题目', () {
    final r = Random(42);
    for (final lesson in allLessons) {
      for (var stage = 0; stage < 3; stage++) {
        final qs = lesson.gen(r, stage);
        expect(qs.length, greaterThanOrEqualTo(8),
            reason: lesson.id + ' 第' + stage.toString() + '阶段题目不足');
      }
    }
  });

  test('选择题答案必须在选项中且选项不重复', () {
    final r = Random(7);
    for (final lesson in allLessons) {
      for (var stage = 0; stage < 3; stage++) {
        for (final q in lesson.gen(r, stage)) {
          if (q.kind == AnswerKind.choice) {
            expect(q.options.contains(q.answer), isTrue,
                reason: '选项缺少答案: ' + q.stem);
            expect(q.options.toSet().length, q.options.length,
                reason: '选项重复: ' + q.stem);
            expect(q.options.length, inInclusiveRange(3, 4), reason: q.stem);
          }
        }
      }
    }
  });

  test('double 题必须有两个答案与两个标签', () {
    final r = Random(99);
    for (final lesson in allLessons) {
      for (var stage = 0; stage < 3; stage++) {
        for (final q in lesson.gen(r, stage)) {
          if (q.kind == AnswerKind.double) {
            expect(q.answer, isNotEmpty, reason: q.stem);
            expect(q.answer2, isNotEmpty, reason: q.stem);
            expect(q.slotLabels.length, 2, reason: q.stem);
            expect(int.tryParse(q.answer), isNotNull, reason: q.stem);
            expect(int.tryParse(q.answer2), isNotNull, reason: q.stem);
          }
        }
      }
    }
  });

  test('数字题答案必须是合法整数', () {
    final r = Random(1234);
    for (final lesson in allLessons) {
      for (var stage = 0; stage < 3; stage++) {
        for (final q in lesson.gen(r, stage)) {
          if (q.kind == AnswerKind.input) {
            final v = int.tryParse(q.answer);
            expect(v, isNotNull, reason: '非数字答案: ' + q.stem);
            expect(v, greaterThanOrEqualTo(0), reason: '负数答案: ' + q.stem);
          }
        }
      }
    }
  });

  test('有余数的除法：余数必须小于除数（抽查规律题外的除法题）', () {
    final r = Random(555);
    for (var i = 0; i < 200; i++) {
      for (final q in genRemBasic(r, 0)) {
        // u6l1 的 double 题：商……余数，题目里带除数 d：形如 p÷d
        if (q.kind == AnswerKind.double && q.stem.contains('÷')) {
          final m = RegExp(r'(\d+)÷(\d+)').firstMatch(q.stem);
          if (m != null) {
            final d = int.parse(m.group(2)!);
            expect(int.parse(q.answer2), lessThan(d), reason: q.stem);
          }
        }
      }
    }
  });
}
