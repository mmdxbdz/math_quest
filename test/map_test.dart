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
  test('一座岛 = 一个主题单元，一屏装得下；所有岛的关卡加起来是全部关卡', () async {
    final store = await freshStore();
    const size = Size(390, 844);

    var total = 0;
    for (var i = 0; i < units.length; i++) {
      final layout = MapLayout.build(size, units, store, unitIndex: i);
      expect(layout.unitIndex, i);
      expect(layout.unitCount, units.length);
      // 这座岛只放这个单元的关卡
      expect(layout.levels.length, units[i].lessons.length * 3);
      for (final l in layout.levels) {
        expect(units[i].lessons.contains(l.lesson), isTrue);
      }
      total += layout.levels.length;

      // 关卡都在岛的椭圆范围内（一屏之内）
      final c = MapLayout.islandCenter(size);
      final rx = MapLayout.islandWidth(size) / 2;
      final ry = MapLayout.islandHeight(size) / 2;
      for (final l in layout.levels) {
        final dx = (l.x - c.dx) / rx;
        final dy = (l.y - c.dy) / ry;
        expect(dx * dx + dy * dy, lessThanOrEqualTo(1.0),
            reason: '第 ${l.index + 1} 关跑到海里去了');
        expect(l.y, inInclusiveRange(0, size.height));
      }
    }
    expect(total, orderedLevelKeys.length);
  });

  test('岛底是第 1 关，越往后越往上盘，山顶是最后一关', () async {
    final store = await freshStore();
    const size = Size(390, 844);
    final layout = MapLayout.build(size, units, store);

    // 第一关在岛的最下面
    expect(layout.levels.first.y, greaterThan(layout.levels.last.y));
    expect(layout.levels.first.y, greaterThan(size.height * 0.7));
    // 木牌在整座关卡的下方
    expect(layout.signs.first.y, greaterThan(layout.levels.first.y));
    // 小路从木牌出发、第一站就是第 1 关
    expect(layout.trail.length, greaterThanOrEqualTo(layout.levels.length));
    expect(layout.trail.first.dy, greaterThan(layout.trail[1].dy));
  });

  test('当前进度自动落在对应的那座岛上', () async {
    final store = await freshStore();
    const size = Size(390, 844);

    // 前 6 个单元的关卡全部通关
    var n = 0;
    for (var u = 0; u < 6; u++) {
      for (final lesson in units[u].lessons) {
        for (var stage = 0; stage < 3; stage++) {
          store.finishLevel('${lesson.id}:s$stage', 3);
          n++;
        }
      }
    }
    expect(n, greaterThan(6));
    final layout = MapLayout.build(size, units, store);
    expect(layout.unitIndex, 6);
    // 岛上有一关是"现在这一关"
    expect(layout.levels.where((l) => l.current).length, 1);
  });

  test('宠物房开在"满了 6 关"的那一关后面，门框上是具体宠物', () async {
    final store = await freshStore();
    store.adoptStarterPet();
    const size = Size(390, 844);

    // 8 间房分散在不同的岛上
    final all = <MapPetHouse>[];
    for (var i = 0; i < units.length; i++) {
      all.addAll(MapLayout.build(size, units, store, unitIndex: i).houses);
    }
    expect(all.length, kPetSpecies.length - 1);
    expect(all.map((h) => h.speciesId).toList(), kPetUnlockOrder.skip(1).toList());
    for (final h in all) {
      expect(h.owned, isFalse, reason: '还没通到就不该显示已领');
    }

    // 通了 6 关：第一间房就"有人住了"，第二间还没、挂金圈
    for (var i = 0; i < kPetUnlockEveryLevels; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    final after = <MapPetHouse>[];
    for (var i = 0; i < units.length; i++) {
      after.addAll(MapLayout.build(size, units, store, unitIndex: i).houses);
    }
    expect(after.first.owned, isTrue);
    expect(after.first.next, isFalse);
    expect(after[1].owned, isFalse);
    expect(after[1].next, isTrue);
  });

  testWidgets('首页是圆岛：能点到关卡，也能翻到别的岛', (tester) async {
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

    // 标题条显示第 1 座岛
    expect(find.textContaining('第 1/${units.length} 座岛'), findsOneWidget);

    // 点第 1 关 → 进入
    await tester.tap(find.text('1').first, warnIfMissed: false);
    await tester.pump();
    expect(tapped, isNotNull);

    // 点右箭头 → 翻到下一座岛
    await tester.tap(find.text('▶'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('第 2/${units.length} 座岛'), findsOneWidget);
    // 翻走了以后出现"回到现在这座岛"的按钮
    expect(find.text('🎯'), findsOneWidget);
  });
}