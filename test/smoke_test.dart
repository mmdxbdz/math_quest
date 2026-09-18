import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/main.dart';
import 'package:math_quest/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('首页与课时页能正常渲染', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();

    await tester.pumpWidget(const MathQuestApp());
    await tester.pumpAndSettle();

    expect(find.text('今日任务'), findsOneWidget);
    expect(find.text('数学闯关 · 二下'), findsOneWidget);

    // 单元卡片存在
    expect(find.text('数据收集整理'), findsOneWidget);
    expect(find.text('表内除法（一）'), findsOneWidget);
  });
}
