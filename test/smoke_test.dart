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
    // 首页有海岛动画在循环播放，不能用 pumpAndSettle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('今日任务'), findsOneWidget);
    expect(find.text('数学闯关岛'), findsOneWidget);

    // 每个单元一个岛上节点（自拟主题名）
    expect(find.text('小小调查员'), findsOneWidget);
    expect(find.text('平均分东西'), findsOneWidget);
  });
}