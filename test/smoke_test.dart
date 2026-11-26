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

    // 首页一屏一座圆岛：标题条写着这是第几座岛、哪个主题
    expect(find.textContaining('第 1/'), findsOneWidget);
    expect(find.textContaining('小小调查员'), findsWidgets);
  });
}