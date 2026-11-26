import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_quest/models.dart';
import 'package:math_quest/store.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/screens/quiz.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('答完第一关后再次进入不空白', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    store.resetAll();
    await store.load();

    final lesson = allLessons.firstWhere((l) => l.id == 'u1l1');
    final qs = lesson.gen(Random(1), 0).take(8).toList();

    QuizScreen makeQuiz() => QuizScreen(
          title: '收集与整理数据 · 基础',
          levelKey: 'u1l1:s0',
          builder: () => List.of(qs),
        );

    // 第一次进入
    await tester.pumpWidget(MaterialApp(home: makeQuiz()));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '第一次进入');

    // 答完 8 题（全部答对）
    for (final q in qs) {
      if (q.kind == AnswerKind.choice) {
        await tester.tap(find.text(q.answer).last);
      }
      // 等 advance(900ms) + AnimatedSwitcher(380ms) 完成
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull, reason: '答题中: ' + q.stem.substring(0, 8));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: '结算页');

    // 等烟花播完（12 波 × 400ms + 火花寿命）再退出
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    // 第二次进入
    await tester.pumpWidget(MaterialApp(home: makeQuiz()));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '第二次进入');
  });
}