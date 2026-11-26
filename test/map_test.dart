import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/pets.dart';
import 'package:math_quest/store.dart';
import 'package:math_quest/widgets/island_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('路线往上走：第 1 关在最下面，越往后越往上', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();

    final layout = MapLayout.build(const Size(390, 844), units, store);
    expect(layout.levels.length, orderedLevelKeys.length);

    // 屏幕 y 越小 = 越靠上
    for (var i = 1; i < layout.levels.length; i++) {
      expect(layout.levels[i].y, lessThan(layout.levels[i - 1].y),
          reason: '第 ${i + 1} 关应该在上一关上面');
    }
    // 第 1 关贴近岛的最下方
    expect(layout.levels.first.y, greaterThan(layout.height * 0.85));
    // 标题木牌在它那一段关卡的下方（从下往上爬的时候先看到木牌）
    final sign = layout.signs.first;
    expect(sign.y, greaterThan(layout.levels.first.y));
    // 小路也是按 y 从小到大排好的
    for (var i = 1; i < layout.trail.length; i++) {
      expect(layout.trail[i].dy, greaterThanOrEqualTo(layout.trail[i - 1].dy));
    }
  });

  testWidgets('手指往下划，地图跟着往下走，上面的关卡就露出来', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IslandMap(store: store, onStartLevel: (_) {}),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 第 2 关在第 1 关上面
    final l1 = tester.getCenter(find.text('1'));
    final l2 = tester.getCenter(find.text('2'));
    expect(l2.dy, lessThan(l1.dy));

    // 手指往下扒拉 → 地图跟着往下走
    await tester.drag(find.byType(IslandMap), const Offset(0, 170));
    await tester.pump();

    final l2after = tester.getCenter(find.text('2'));
    expect(l2after.dy, greaterThan(l2.dy + 60),
        reason: '手指往下滑，上面的第 2 关应该跟着往下走近镜头');

    // 往反方向推回去，地图也往回走（不会反着跳）
    await tester.drag(find.byType(IslandMap), const Offset(0, -170));
    await tester.pump();
    final l2back = tester.getCenter(find.text('2'));
    expect(l2back.dy, lessThan(l2after.dy - 40));
  });

  test('宠物房开在"满了 6 关"的那一关和下一关中间，门框上是具体宠物', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();

    final layout = MapLayout.build(const Size(390, 844), units, store);
    // 9 种宠物：开场送北极熊，后面 8 只需要闯出来，所以岛上 8 间房
    expect(layout.houses.length, kPetSpecies.length - 1);
    // 顺序固定：小猫 → 小兔 → 小狗 …
    expect(layout.houses.map((h) => h.speciesId).toList(),
        kPetUnlockOrder.skip(1).toList());
    for (var k = 0; k < layout.houses.length; k++) {
      final h = layout.houses[k];
      expect(h.owned, isFalse, reason: '还没通到就不该显示已领');
      // 位置：在"第 6(k+1) 关"上面、"第 6(k+1)+1 关"下面（y 越小越靠上）
      final after = layout.levels[kPetUnlockEveryLevels * (k + 1) - 1];
      final before = layout.levels[kPetUnlockEveryLevels * (k + 1)];
      expect(h.y, lessThan(after.y), reason: '宠物房应该在它前面那一关的上面');
      expect(h.y, greaterThan(before.y), reason: '宠物房应该在它后面那一关的下面');
    }

    // 通了 6 关：第一间房就"有人住了"，第二间还没
    for (var i = 0; i < kPetUnlockEveryLevels; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    final layout2 = MapLayout.build(const Size(390, 844), units, store);
    expect(layout2.houses.first.owned, isTrue);
    expect(layout2.houses[1].owned, isFalse);
    // 下一间（第二间，小兔）挂金圈
    expect(layout2.houses[1].next, isTrue);
    expect(layout2.houses.first.next, isFalse);
  });

  testWidgets('把地图往上翻，能看到挂着宠物头像的宠物房', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IslandMap(store: store, onStartLevel: (_) {}),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 宠物房在岛上（门框上挂着具体宠物的头像）
    final before = tester.widgetList(find.byType(PetAvatar)).length;

    // 往下扒拉一大段，把第 6 关后面那间房翻进视野
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(IslandMap), const Offset(0, 400));
      await tester.pump();
    }
    expect(tester.widgetList(find.byType(PetAvatar)).length, greaterThan(0));
    expect(before, lessThanOrEqualTo(tester.widgetList(find.byType(PetAvatar)).length));
  });
}