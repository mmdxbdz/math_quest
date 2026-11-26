import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/pets.dart';
import 'package:math_quest/screens/home.dart';
import 'package:math_quest/screens/pets_house.dart';
import 'package:math_quest/store.dart';
import 'package:math_quest/widgets/pet_visit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('进首页：宠物自己跳出来舔一口，舔完自己跳走', (tester) async {
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 200));

    // 没有任何文字气泡，只有动作
    expect(find.byType(PetVisitOverlay), findsOneWidget);
    expect(find.textContaining('主人'), findsNothing);

    // 舔三下之后自己跳走
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byType(PetVisitOverlay), findsNothing);
  });

  testWidgets('第一次进首页：小熊自己跑出来，抱一下就算收养', (tester) async {
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    expect(store.hasPet, isFalse);

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PetVisitOverlay), findsOneWidget);
    expect(find.text('❤️ 抱抱它'), findsOneWidget);
    expect(find.textContaining('主人'), findsNothing);

    await tester.tap(find.text('❤️ 抱抱它'));
    await tester.pump();
    expect(store.hasPet, isTrue);
    // 抱完之后它继续凑过来舔
    expect(find.byType(PetVisitOverlay), findsOneWidget);
    expect(find.text('❤️ 抱抱它'), findsNothing);
  });

  testWidgets('饿了的时候它会举着自己爱吃的鱼（不写字）', (tester) async {
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    store.lastFeedAt = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;
    expect(store.companionHungry, isTrue);

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PetVisitOverlay), findsOneWidget);
    // 北极熊吃鱼，不是骨头
    expect(find.text('🐟'), findsWidgets);
    expect(find.text('🍖'), findsNothing);
  });

  testWidgets('家长点「再看一遍动画」：回首页重新演一遍开头，宠物不清空', (tester) async {
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    store.feedCompanion(3); // 养大一点，验证不会被重置
    final feedsBefore = store.companion!.feeds;

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));
    // 一开始是普通打招呼（没有"抱抱它"按钮）
    expect(find.text('❤️ 抱抱它'), findsNothing);

    // 等这一遍演完
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byType(PetVisitOverlay), findsNothing);

    // 家长页按下"再看一遍动画"
    store.setReplayIntro(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 开场动画又来了
    expect(find.text('❤️ 抱抱它'), findsOneWidget);
    await tester.tap(find.text('❤️ 抱抱它'));
    await tester.pump();

    // 宠物和成长都还在，只是这一遍演完
    expect(store.hasPet, isTrue);
    expect(store.companion!.feeds, feedsBefore);
    expect(store.replayIntro, isFalse);
    expect(find.byType(PetVisitOverlay), findsOneWidget);
  });

  test('清空宠物：回到第一次，但关卡星星还在', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    store.grantRandomGift();
    store.finishLevel('u1.l1.s1', 3);
    final starsBefore = store.stars.length;

    store.resetPets();
    expect(store.hasPet, isFalse);
    expect(store.ownedGifts, isEmpty);
    expect(store.stars.length, starsBefore);
    expect(store.replayIntro, isFalse);
  });

  testWidgets('通了第 6 关：新朋友自己跑到首页来，可以领它回家', (tester) async {
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    for (var i = 0; i < 6; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    expect(store.petCount, 2);
    expect(store.newArrivals.length, 1);
    final newSpecies = petSpeciesOf(store.newArrivals.first);

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // 新朋友的通知 + 领它回家
    expect(find.textContaining('新朋友'), findsWidgets);
    expect(find.textContaining(newSpecies.defaultName), findsWidgets);
    expect(find.text('❤️ 领它回家'), findsOneWidget);

    // 点"等会儿再领"就回去正常首页
    await tester.tap(find.text('等会儿再领'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('❤️ 领它回家'), findsNothing);
  });

  testWidgets('宠物住所：能换着陪哪只宠物玩', (tester) async {
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    store.giftNewPet();
    expect(store.petCount, 2);
    store.clearNewArrivals();

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('我的朋友们'), findsOneWidget);
    final second = store.pets[1].name;
    await tester.tap(find.text(second));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.companionIndex, 1);
  });
}