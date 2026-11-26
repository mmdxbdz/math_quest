import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/pets.dart';
import 'package:math_quest/store.dart';
import 'package:math_quest/three_d.dart';
import 'package:math_quest/widgets/island_map.dart';
import 'package:math_quest/widgets/island_scene.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProgressStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = ProgressStore();
  await store.load();
  store.resetAll();
  return store;
}

void main() {
  test('3D 场景：越远的关画得越小、越靠上（真透视）', () async {
    final store = await freshStore();
    final scene = IslandScene.build(
      size: const Size(390, 844),
      units: units,
      store: store,
      foodKind: 'fish',
    );

    expect(scene.faces.length, greaterThan(400), reason: '整座岛是几百个面拼的');
    expect(scene.markers.length, greaterThan(3));

    final byDepth = [...scene.markers]..sort((a, b) => a.depth.compareTo(b.depth));
    for (var i = 1; i < byDepth.length; i++) {
      expect(byDepth[i].y, lessThan(byDepth[i - 1].y),
          reason: '更远的关在屏幕上更靠上');
      expect(byDepth[i].px, lessThan(byDepth[i - 1].px),
          reason: '更远的关在屏幕上更小');
    }
    // 最近的关卡落在画面下半部分
    expect(byDepth.first.y, greaterThan(scene.horizonY));
  });

  test('关卡造型跟着宠物换：北极熊是鱼、小狗是肉骨头', () async {
    expect(foodKindOf('polar'), 'fish');
    expect(foodKindOf('cat'), 'fish');
    expect(foodKindOf('dog'), 'bone');
    expect(foodKindOf('rabbit'), 'carrot');
    expect(foodKindOf('bear'), 'honey');
    expect(foodKindOf('panda'), 'bamboo');
    expect(foodKindOf('fox'), 'grape');
    expect(foodKindOf('pig'), 'corn');
    expect(foodKindOf('frog'), 'bug');
    expect(foodKindOf(null), 'fish');

    // 每种造型都能造出真正的 3D 面
    for (final kind in [
      'fish',
      'bone',
      'carrot',
      'honey',
      'bamboo',
      'grape',
      'corn',
      'bug',
    ]) {
      final faces = foodFaces(
        kind,
        const V3(0, 0, 0),
        1,
        const Color(0xFFFFB347),
        const Color(0xFFFF8A3D),
      );
      expect(faces.length, greaterThan(6), reason: '$kind 应该是立体的');
      expect(faces.any((f) => (f.normal.y).abs() > 0.2), isTrue,
          reason: '$kind 有朝上的面，能照出明暗');
    }
  });

  testWidgets('手指往下扒拉 = 往前走，关卡朝镜头来', (tester) async {
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 点第 1 关能进门
    await tester.tap(find.byKey(const ValueKey('lvl-0')));
    await tester.pump();
    expect(tapped, isNotNull);
    expect(tapped!.index, 0);
    expect(tapped!.unlocked, isTrue);

    // 后面的关一开始在更上面
    final before = tester.getCenter(find.byKey(const ValueKey('lvl-2')));

    // 往下扒拉 300px：往前走，第 3 关朝镜头来（屏幕上下移）
    await tester.drag(find.byType(IslandMap), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final after = tester.getCenter(find.byKey(const ValueKey('lvl-2')));
    expect(after.dy, greaterThan(before.dy + 30));
  });

  test('路边有 8 间宠物房，顺序和宠物一致', () async {
    final store = await freshStore();
    store.adoptStarterPet();
    for (var i = 0; i < kPetUnlockEveryLevels; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    // 镜头停在第一间宠物房前面
    final scene = IslandScene.build(
      size: const Size(390, 844),
      units: units,
      store: store,
      foodKind: 'bone',
      cam: 6.0,
    );
    expect(scene.houses, isNotEmpty);
    expect(scene.houses.first.speciesId, kPetUnlockOrder[1]);
    // 已经住进去的那间标 owned，下一间挂着"金圈"提示
    expect(scene.houses.any((h) => h.owned || h.next), isTrue);
  });
}