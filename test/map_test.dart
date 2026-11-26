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
  test('真透视：远处的关在上面、更小，近处的关在下面、更大', () async {
    final store = await freshStore();
    const size = Size(390, 844);
    final layout = MapLayout.build(size, units, store);

    expect(layout.levels.length, orderedLevelKeys.length);

    // 第 1 关离镜头最近，越往后越远
    for (var i = 1; i < layout.levels.length; i++) {
      expect(layout.levels[i].depth, greaterThan(layout.levels[i - 1].depth),
          reason: '第 ${i + 1} 关应该在第 $i 关更远处');
    }
    // 越远越靠上（屏幕 y 越小）
    for (var i = 1; i < layout.levels.length; i++) {
      expect(layout.levels[i].y, lessThan(layout.levels[i - 1].y));
    }
    // 越远越小：这就是近大远小
    for (var i = 1; i < 12; i++) {
      expect(layout.levels[i].scale, lessThan(layout.levels[i - 1].scale),
          reason: '第 ${i + 1} 关应该画得比第 $i 关小');
    }
    // 全部落在地平线以下
    expect(layout.levels.first.y, greaterThan(layout.horizonY));
    expect(layout.levels.first.y, lessThan(size.height + 400));
    // 终点的路收敛到地平线附近
    expect(layout.levels.last.y, lessThan(layout.horizonY + 400));
  });

  test('往前走（cam 变大）：关卡朝镜头靠近、往下走、变大', () async {
    final store = await freshStore();
    const size = Size(390, 844);

    final a = MapLayout.build(size, units, store);
    final b = MapLayout.build(size, units, store, cam: a.cam + 3.0);

    final a0 = a.levels.first;
    final b0 = b.levels.first;
    expect(b0.depth, lessThan(a0.depth), reason: '走 3 格之后第 1 关更近了');
    expect(b0.y, greaterThan(a0.y), reason: '更近 → 在屏幕上更靠下');
    expect(b0.scale, greaterThan(a0.scale), reason: '更近 → 画得更大');
  });

  testWidgets('手指往下扒拉 = 往前走，关卡跟着下来', (tester) async {
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

    // 第 1 关在屏幕上，第 2 关比它更靠上（更远）
    final p1 = tester.getCenter(find.text('1'));
    final p2 = tester.getCenter(find.text('2'));
    expect(p2.dy, lessThan(p1.dy));

    // 点第 1 关能进门
    await tester.tap(find.text('1').first);
    await tester.pump();
    expect(tapped, isNotNull);

    // 往下扒拉 → 往前走 → 后面的关朝镜头来（屏幕上下移）
    await tester.drag(find.byType(IslandMap), const Offset(0, 160));
    await tester.pump();
    final p2after = tester.getCenter(find.text('2'));
    expect(p2after.dy, greaterThan(p2.dy + 20));
  });

  test('路边一共有 8 间宠物房，顺序和宠物一致', () async {
    final store = await freshStore();
    store.adoptStarterPet();

    final layout = MapLayout.build(const Size(390, 844), units, store);
    expect(layout.houses.length, kPetSpecies.length - 1);
    expect(layout.houses.map((h) => h.speciesId).toList(),
        kPetUnlockOrder.skip(1).toList());
    for (final h in layout.houses) {
      expect(h.owned, isFalse);
    }

    // 通了 6 关：第一间房有人住了，第二间挂金圈
    for (var i = 0; i < kPetUnlockEveryLevels; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    final after = MapLayout.build(const Size(390, 844), units, store);
    expect(after.houses.first.owned, isTrue);
    expect(after.houses.first.next, isFalse);
    expect(after.houses[1].next, isTrue);
  });
}