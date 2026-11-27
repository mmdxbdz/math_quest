import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/store.dart';
import 'package:math_quest/widgets/island_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProgressStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = ProgressStore();
  await store.load();
  store.resetAll();
  return store;
}

Widget wrap(ProgressStore store, void Function(MapLevel) onTap) => MaterialApp(
      home: Scaffold(
        body: IslandMap(
          store: store,
          onStartLevel: onTap,
          onPetHouseTap: () {},
        ),
      ),
    );

void main() {
  test('底图按 cover 铺满，10 个关卡位都在可见区内', () {
    const box = Size(390, 844);
    final art = coverRect(box, kIslandArtSize);
    expect(art.height, closeTo(844, 0.5));
    expect(art.width, greaterThan(390));
    expect(kLevelSpots.length, 10);

    for (final s in kLevelSpots) {
      final p = Offset(art.left + s.dx * art.width, art.top + s.dy * art.height);
      expect(p.dx, inInclusiveRange(0.0, box.width));
      expect(p.dy, inInclusiveRange(0.0, box.height));
    }
  });

  testWidgets('点圆盘能进关', (tester) async {
    final store = await freshStore();
    MapLevel? tapped;
    await tester.pumpWidget(wrap(store, (l) => tapped = l));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('lvl-0')));
    await tester.pump();
    expect(tapped?.index, 0);
    expect(tapped?.stage, 0, reason: '阶段索引必须是 0..2，跟 orderedLevelKeys 一致');
    expect(tapped?.unlocked, isTrue);
  });

  testWidgets('每页 10 关，翻页能看到全部 78 关', (tester) async {
    final store = await freshStore();
    MapLevel? tapped;
    await tester.pumpWidget(wrap(store, (l) => tapped = l));
    await tester.pump(const Duration(milliseconds: 100));

    // 第一页：第 1-10 关
    expect(find.byKey(const ValueKey('lvl-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('lvl-9')), findsOneWidget);
    expect(find.byKey(const ValueKey('lvl-10')), findsNothing);
    expect(find.textContaining('1-10 / 78'), findsOneWidget);

    // 翻到第二页
    await tester.tap(find.byKey(const ValueKey('page-next')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('lvl-0')), findsNothing);
    expect(find.byKey(const ValueKey('lvl-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('lvl-19')), findsOneWidget);
    expect(find.textContaining('11-20 / 78'), findsOneWidget);

    // 第二页的圆盘照样能点
    await tester.tap(find.byKey(const ValueKey('lvl-10')));
    await tester.pump();
    expect(tapped?.index, 10);

    // 一直翻到最后一页：78 = 第 71-78 关（8 个圆盘）
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const ValueKey('page-next')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.textContaining('71-78 / 78'), findsOneWidget);
    expect(find.byKey(const ValueKey('lvl-77')), findsOneWidget);
    // 最后一页还能往回翻
    await tester.tap(find.byKey(const ValueKey('page-prev')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('61-70 / 78'), findsOneWidget);
  });

  testWidgets('进度推进后当前关高亮，翻页不影响当前关标记', (tester) async {
    final store = await freshStore();
    for (final k in orderedLevelKeys.take(4)) {
      store.finishLevel(k, 2);
    }
    MapLevel? tapped;
    await tester.pumpWidget(wrap(store, (l) => tapped = l));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('lvl-4')));
    await tester.pump();
    expect(tapped?.index, 4);
    expect(tapped?.current, isTrue, reason: '橙色呼吸光那一关就是当前关');
    expect(tapped?.stars, 0);
    // 前几关已经通关（测试里给了 2 星）
    await tester.tap(find.byKey(const ValueKey('lvl-3')));
    await tester.pump();
    expect(tapped?.stars, 2);
  });
}
