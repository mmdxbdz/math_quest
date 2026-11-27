import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/main.dart';
import 'package:math_quest/render3d/island_shader.dart';
import 'package:math_quest/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => kUseGpuIsland = false);
  tearDown(() => kUseGpuIsland = true);

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

    // 首页是往上走的岛路：脚下就是第 1 关和它的主题木牌
    expect(find.textContaining('小小调查员'), findsWidgets);
    // 第 1 关的点击热区在（关卡是 3D 画出来的，这里认 key）
    expect(find.byKey(const Key('lvl-0')), findsOneWidget);
  });
}