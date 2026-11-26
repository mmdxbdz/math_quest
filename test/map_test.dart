import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/pets.dart';
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
  test('沿着岛上的路往上走：第 1 关在岛脚，越往后越往上', () async {
    final store = await freshStore();
    const size = Size(390, 844);

    final layout = MapLayout.build(size, units, store);
    expect(layout.levels.length, orderedLevelKeys.length);

    // 屏幕 y 越小 = 越靠上（山越高）
    for (var i = 1; i < layout.levels.length; i++) {
      expect(layout.levels[i].y, lessThan(layout.levels[i - 1].y),
          reason: '第 ${i + 1} 关应该在上一关上面');
    }
    // 第 1 关贴近岛脚
    expect(layout.levels.first.y, greaterThan(layout.height * 0.85));
    // 木牌在它那一段关卡的下方
    expect(layout.signs.first.y, greaterThan(layout.levels.first.y));
    // 小路按 y 从小到大排好
    for (var i = 1; i < layout.trail.length; i++) {
      expect(layout.trail[i].dy, greaterThanOrEqualTo(layout.trail[i - 1].dy));
    }
  });

  test('前面只露出几关，走几关路才往上延伸一截', () async {
    final store = await freshStore();
    const size = Size(390, 844);

    final before = MapLayout.build(size, units, store);
    final revealedBefore =
        before.levels.where((l) => l.y > before.revealY).length;
    // 刚开局：只看得见脚下 2~4 关
    expect(revealedBefore, inInclusiveRange(2, 4));
    // 更上面的关卡都在云雾里
    expect(before.levels.last.y, lessThan(before.revealY));

    // 连过 3 关 → 路往上一截
    for (var i = 0; i < 3; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    final after = MapLayout.build(size, units, store);
    final revealedAfter =
        after.levels.where((l) => l.y > after.revealY).length;
    expect(revealedAfter, greaterThan(revealedBefore));
    expect(after.revealY, lessThan(before.revealY));
  });

  testWidgets('手指往下扒拉，路跟着下来，一关一关往上走', (tester) async {
    final store = await freshStore();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: IslandMap(store: store, onStartLevel: (_) {})),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 第 2 关在第 1 关上面
    final l1 = tester.getCenter(find.text('1'));
    final l2 = tester.getCenter(find.text('2'));
    expect(l2.dy, lessThan(l1.dy));

    // 手指往下扒拉 → 上面的关卡跟着下来（继续往上走）
    await tester.drag(find.byType(IslandMap), const Offset(0, 150));
    await tester.pump();
    final l2after = tester.getCenter(find.text('2'));
    expect(l2after.dy, greaterThan(l2.dy + 50));

    // 还没走到的地方不显示（在云雾里）
    expect(find.text('9'), findsNothing);
  });

  testWidgets('能点到关卡进入', (tester) async {
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
        body: IslandMap(store: store, onStartLevel: (l) => tapped = l),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('1').first, warnIfMissed: false);
    await tester.pump();
    expect(tapped, isNotNull);
    expect(tapped!.index, 0);
  });

  test('宠物房开在"满了 6 关"的那一关和下一关中间，门框上是具体宠物', () async {
    final store = await freshStore();
    store.adoptStarterPet();

    final layout = MapLayout.build(const Size(390, 844), units, store);
    // 9 种宠物：开场送北极熊，后面 8 只需要闯出来，所以路上 8 间房
    expect(layout.houses.length, kPetSpecies.length - 1);
    expect(layout.houses.map((h) => h.speciesId).toList(),
        kPetUnlockOrder.skip(1).toList());
    for (var k = 0; k < layout.houses.length; k++) {
      final h = layout.houses[k];
      expect(h.owned, isFalse, reason: '还没通到就不该显示已领');
      final after = layout.levels[kPetUnlockEveryLevels * (k + 1) - 1];
      final before = layout.levels[kPetUnlockEveryLevels * (k + 1)];
      expect(h.y, lessThan(after.y), reason: '宠物房应该在它前面那一关的上面');
      expect(h.y, greaterThan(before.y), reason: '宠物房应该在它后面那一关的下面');
    }

    // 通了 6 关：第一间房就"有人住了"，第二间还没、挂金圈
    for (var i = 0; i < kPetUnlockEveryLevels; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    final layout2 = MapLayout.build(const Size(390, 844), units, store);
    expect(layout2.houses.first.owned, isTrue);
    expect(layout2.houses.first.next, isFalse);
    expect(layout2.houses[1].owned, isFalse);
    expect(layout2.houses[1].next, isTrue);
  });
}