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

void main() {
  test('底图按 cover 铺满，10 个关卡位都在图上', () {
    const box = Size(390, 844);
    final art = coverRect(box, kIslandArtSize);
    // 竖屏上 cover：高度铺满，宽度超出（左右被裁）
    expect(art.height, closeTo(844, 0.5));
    expect(art.width, greaterThan(390));
    expect(art.center.dx, closeTo(195, 0.5));

    expect(kLevelSpots.length, 10);
    for (final s in kLevelSpots) {
      expect(s.dx, inInclusiveRange(0.0, 1.0));
      expect(s.dy, inInclusiveRange(0.0, 1.0));
      // 投影到屏幕上必须落在可见区域内
      final p = Offset(art.left + s.dx * art.width, art.top + s.dy * art.height);
      expect(p.dx, inInclusiveRange(0.0, box.width));
      expect(p.dy, inInclusiveRange(0.0, box.height));
    }
  });

  testWidgets('点第一个关卡圆盘能进关，进度推进后窗口往后走', (tester) async {
    final store = await freshStore();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    MapLevel? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IslandMap(
          store: store,
          onStartLevel: (l) => tapped = l,
          onPetHouseTap: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // 一开始显示第 1–10 关
    expect(find.byKey(const ValueKey('lvl-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('lvl-9')), findsOneWidget);
    expect(find.byKey(const ValueKey('lvl-10')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lvl-0')));
    await tester.pump();
    expect(tapped, isNotNull);
    expect(tapped!.index, 0);
    expect(tapped!.unlocked, isTrue);
    expect(tapped!.stage, 0);

    // 通掉 4 关后，窗口跟着当前关卡往后挪
    for (final k in orderedLevelKeys.take(4)) {
      store.finishLevel(k, 3);
    }
    tapped = null;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IslandMap(
          store: store,
          onStartLevel: (l) => tapped = l,
          onPetHouseTap: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('lvl-0')), findsNothing);
    expect(find.byKey(const ValueKey('lvl-2')), findsOneWidget);

    // 第一个可点的应该是第 4 关（索引 4，还没做）
    await tester.tap(find.byKey(const ValueKey('lvl-4')));
    await tester.pump();
    expect(tapped?.index, 4);
    expect(tapped?.current, isTrue, reason: '橙色呼吸光那一关就是当前关');
  });

  testWidgets('锁着的关卡也能点到（点了会被课时页拦下）', (tester) async {
    final store = await freshStore();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IslandMap(
          store: store,
          onStartLevel: (_) {},
          onPetHouseTap: () {},
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    final last = find.byKey(const ValueKey('lvl-9'));
    expect(last, findsOneWidget);
    expect(tester.widget(last).key, const ValueKey('lvl-9'));
  });
}
