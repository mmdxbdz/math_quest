import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/pets.dart';
import 'package:math_quest/screens/pets_house.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/store.dart';
import 'package:math_quest/widgets/photo_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
  });

  test('还没宠物时喂食不报错、也不会凭空出现宠物', () {
    final store = ProgressStore();
    expect(store.companion, isNull);
    expect(store.feedCompanion(), isFalse);
    expect(store.petCount, 0);
  });

  test('领养一只宠物：自动成为陪伴，并写进存档', () async {
    final store = ProgressStore();
    final pet = store.adoptPet('cat', 0);
    expect(pet.name, '喵喵');
    expect(store.petCount, 1);
    expect(store.companion!.speciesId, 'cat');
    expect(store.petOfSlot(0)!.name, '喵喵');
    expect(store.petOfSlot(1), isNull);

    // 重新加载存档，宠物还在
    await store.load();
    expect(store.petCount, 1);
    expect(store.companion!.name, '喵喵');
  });

  test('喂 3 顿长大一阶，喂满封顶在最高阶', () {
    final store = ProgressStore();
    store.adoptPet('dog', 0);

    expect(store.feedCompanion(), isFalse);
    expect(store.companion!.stage, 0);
    expect(store.feedCompanion(), isFalse);
    expect(store.companion!.stage, 0);
    // 第三顿：长大
    expect(store.feedCompanion(), isTrue);
    expect(store.companion!.stage, 1);
    expect(store.companion!.feeds, 3);

    // 一直喂到顶
    for (var i = 0; i < 40; i++) {
      store.feedCompanion();
    }
    expect(store.companion!.stage, kPetStages - 1);
    expect(store.companion!.maxed, isTrue);
    expect(store.companion!.growProgress, 1.0);
    expect(store.feedCompanion(), isFalse);
  });

  test('换成另一只陪伴后，喂的是新的那只', () {
    final store = ProgressStore();
    store.adoptPet('cat', 0);
    store.adoptPet('rabbit', 1);
    expect(store.companion!.speciesId, 'rabbit'); // 新领养的自动陪伴

    store.setCompanion(0);
    expect(store.companion!.speciesId, 'cat');
    store.feedCompanion();
    expect(store.petOfSlot(0)!.feeds, 1);
    expect(store.petOfSlot(1)!.feeds, 0);
  });

  test('随机招领：优先来没养过的种类', () {
    final owned = <String>[];
    for (var i = 0; i < kPetSpecies.length; i++) {
      final s = randomNewSpecies(owned);
      expect(owned.contains(s.id), isFalse, reason: '不该重复出现 ${s.id}');
      owned.add(s.id);
    }
    // 全都养过了之后，允许重复
    final again = randomNewSpecies(owned);
    expect(kPetSpecies.any((s) => s.id == again.id), isTrue);
  });

  test('成长数值：阶段、还差几顿、整体进度', () {
    const p0 = Pet(speciesId: 'cat', name: 'a', feeds: 0, slot: 0);
    expect(p0.stage, 0);
    expect(p0.feedsToNext, kFeedsPerStage);
    expect(p0.growProgress, 0);

    const p1 = Pet(speciesId: 'cat', name: 'a', feeds: 4, slot: 0);
    expect(p1.stage, 1);
    expect(p1.feedsToNext, kFeedsPerStage - 1);
    expect(p1.sizeScale, greaterThan(p0.sizeScale));

    final maxFeeds = (kPetStages - 1) * kFeedsPerStage;
    final pMax = Pet(speciesId: 'cat', name: 'a', feeds: maxFeeds, slot: 0);
    expect(pMax.maxed, isTrue);
    expect(pMax.stageProgress, 1.0);
  });

  test('今天没喂就会饿（放学回来正好该喂）', () {
    final store = ProgressStore();
    store.adoptPet('cat', 0);
    expect(store.companionHungry, isFalse);

    final last = store.lastFeedAt;
    const day = 24 * 3600 * 1000;
    expect(store.hungryAt(last), isFalse);
    expect(store.hungryAt(last + 1000), isFalse); // 同一天
    expect(store.hungryAt(last + day), isTrue); // 第二天

    store.feedCompanion();
    expect(store.companionHungry, isFalse);
    expect(store.hungryAt(store.lastFeedAt + day), isTrue);
  });

  test('开局领养的就是北极熊幼仔', () {
    final store = ProgressStore();
    expect(store.hasPet, isFalse);
    final pet = store.adoptStarterPet();
    expect(pet.speciesId, 'polar');
    expect(pet.species.title, '北极熊');
    expect(pet.name, kStarterPetName);
    expect(pet.stage, 0);
    expect(store.hasPet, isTrue);
    expect(store.companion!.speciesId, 'polar');
  });

  test('闯关掉落的礼品：自动摆上、可收起、收齐后换成金币', () {
    final store = ProgressStore();
    store.adoptStarterPet();
    expect(store.ownedGifts, isEmpty);

    final rng = Random(7);
    final g = store.grantRandomGift(rng);
    expect(g, isNotNull);
    expect(store.ownedGiftIds.contains(g!.id), isTrue);
    // 自动摆进客厅对应位置
    expect(store.giftPlacedAt('living', g.slot)?.id, g.id);

    store.placeGift('living', g.slot, null);
    expect(store.giftPlacedAt('living', g.slot), isNull);

    while (!store.allGiftsOwned) {
      store.grantRandomGift(rng);
    }
    expect(store.ownedGifts.length, kPetGifts.length);

    final coins = store.coins;
    expect(store.grantRandomGift(rng), isNull);
    expect(store.coins, coins + 10); // 收齐了改成金币
  });

  test('家具可以摆到不同房间，位置会存下来；房间按收集数量解锁', () async {
    final store = ProgressStore();
    store.adoptStarterPet();
    final rng = Random(11);
    while (store.giftIds.length < 4) {
      store.grantRandomGift(rng);
    }

    final living = petRoomOf('living');
    final bedroom = petRoomOf('bedroom');
    final snow = petRoomOf('snow');
    expect(store.roomUnlocked(living), isTrue);
    expect(store.roomUnlocked(bedroom), isTrue); // 4 件家具就开卧室
    expect(store.roomUnlocked(snow), isFalse); // 雪屋要 10 件

    // 把一件家具摆进卧室
    final gift = store.ownedGifts.first;
    store.placeGift('bedroom', gift.slot, gift.id);
    expect(store.giftPlacedAt('bedroom', gift.slot)?.id, gift.id);

    // 拖动位置（0~1），松手保存
    final slot = bedroom.slots.firstWhere((s) => s.type == gift.slot);
    expect(store.itemPos(bedroom, slot).dx, slot.dx); // 默认位置
    store.moveItem(bedroom, slot, 0.42, 0.66);
    store.saveItems();
    expect(store.itemPos(bedroom, slot).dx, closeTo(0.42, 0.001));

    // 超出范围会被夹住
    store.moveItem(bedroom, slot, 2.0, -1.0);
    expect(store.itemPos(bedroom, slot).dx, 1.0);
    expect(store.itemPos(bedroom, slot).dy, 0.0);

    // 重新加载还在
    await store.load();
    expect(store.giftPlacedAt('bedroom', gift.slot)?.id, gift.id);
    expect(store.itemPos(bedroom, slot).dx, 1.0);
  });

  test('改名、戴帽子都会存档；帽子要长到对应阶才解锁', () async {
    final store = ProgressStore();
    store.adoptPet('cat', 0);

    store.renamePet(0, '雪球');
    expect(store.companion!.name, '雪球');

    // 0 阶只能不戴
    store.setPetHat(0, 4);
    expect(store.companion!.hatIndex, 0);

    // 喂满到最高阶
    for (var i = 0; i < (kPetStages - 1) * kFeedsPerStage; i++) {
      store.feedCompanion();
    }
    expect(store.companion!.stage, kPetStages - 1);

    store.setPetHat(0, 4);
    expect(store.companion!.hatIndex, 4);

    await store.load();
    expect(store.companion!.name, '雪球');
    expect(store.companion!.hatIndex, 4);
  });

  testWidgets('宠物住所能正常显示，不出现布局溢出', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    store.grantRandomGift(Random(3));
    store.grantRandomGift(Random(5));

    tester.view.physicalSize = const Size(400, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('宠物住所'), findsWidgets);
    expect(find.text(kStarterPetName), findsWidgets);
    expect(find.text('客厅'), findsWidgets);
    expect(find.text('卧室'), findsWidgets);
    expect(find.text('小窝'), findsWidgets);
    // 往下面翻：宠物家的礼物箱
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('礼物箱'), findsWidgets);
  });

  testWidgets('饿了会跑到饭碗边，头顶挂一份鱼（不写字）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    // 造一个"昨天喂的"状态 → 今天还没喂
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

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.byKey(const ValueKey('pet-hungry')), findsWidgets);
  });

  testWidgets('宠物不说话：住所里没有任何宠物台词', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    store.lastFeedAt = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.textContaining('主人'), findsNothing);
    expect(find.textContaining('咕噜'), findsNothing);
    expect(find.textContaining('好想你'), findsNothing);
    // 名字、状态这些界面文字照旧
    expect(find.text(kStarterPetName), findsWidgets);
  });

  testWidgets('点房间里的相框会弹出和宠物的合影卡', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();

    // 一直掉直到拿到合影相框
    var guard = 0;
    while (!store.ownedGiftIds.contains('de_photo') && guard < 60) {
      store.grantRandomGift(Random(guard));
      guard++;
    }
    expect(store.ownedGiftIds.contains('de_photo'), isTrue);
    store.placeGift('living', 'decor', 'de_photo');

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PhotoThumb), findsWidgets);

    await tester.tap(find.byType(PhotoThumb).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('的合影'), findsWidgets);
    expect(find.textContaining('年'), findsWidgets);

    // 关掉合影卡
    await tester.tap(find.text('收好啦'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('的合影'), findsNothing);
  });

  test('每个宠物吃自己的东西：北极熊吃鱼，不是骨头', () {
    expect(petSpeciesOf('polar').food, '🐟');
    expect(petSpeciesOf('cat').food, '🐟');
    expect(petSpeciesOf('rabbit').food, '🥕');
    expect(petSpeciesOf('panda').food, '🎋');
    for (final s in kPetSpecies) {
      expect(s.food, isNotEmpty, reason: s.id + ' 没有食物');
    }
    // 只有小狗啃骨头
    expect(petSpeciesOf('polar').food, isNot('🍖'));
    expect(petSpeciesOf('dog').food, '🍖');
  });

  test('每通 6 关来一位新朋友：能养好多好多', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    expect(store.petCount, 0);
    store.adoptStarterPet();
    expect(store.petCount, 1);
    expect(store.companion!.speciesId, kStarterPetSpecies);

    // 通 5 关：还是只有一位
    for (var i = 0; i < 5; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    expect(store.petCount, 1);
    expect(store.levelsToNextPet, 1);

    // 第 6 关：新朋友来了
    store.finishLevel(orderedLevelKeys[5], 3);
    expect(store.petCount, 2);
    expect(store.newArrivals.length, 1);
    // 陪伴的那只没被换掉，新朋友是别的种类
    expect(store.companion!.speciesId, kStarterPetSpecies);
    final ids = store.pets.map((p) => p.speciesId).toList();
    expect(ids.toSet().length, 2);

    // 通关到 12 关：第三位
    for (var i = 6; i < 12; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    expect(store.petCount, 3);
  });

  test('宠物最多到种类数，全齐后不再多给', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    for (var i = 0; i < orderedLevelKeys.length; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    expect(store.petCount, kPetSpecies.length);
    expect(store.levelsToNextPet, 0);
    expect(store.giftNewPet(), isNull);
  });

  test('新朋友会存档，重开游戏还在', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    for (var i = 0; i < 6; i++) {
      store.finishLevel(orderedLevelKeys[i], 3);
    }
    expect(store.petCount, 2);
    final ids = store.pets.map((p) => p.speciesId).toList();

    // 重新读一次存档（模拟下次打开 app）
    await store.load();
    expect(store.petCount, 2);
    expect(store.pets.map((p) => p.speciesId).toList(), ids);
  });

  // ── 食盒与真实动作 ─────────────────────────────────────────

  test('食盒里有粮才吃得着：吃一口少一份，碗空了它就饿', () {
    final store = ProgressStore();
    store.adoptPet('dog', 0);
    // 新来的先装好一盒
    expect(store.foodLeft, kFoodBowlCap);
    expect(store.bowlEmpty, isFalse);

    expect(store.eatOneBite(), isFalse); // 第一口还没长大
    expect(store.foodLeft, kFoodBowlCap - 1);
    expect(store.companion!.feeds, 1);

    for (var i = 1; i < kFoodBowlCap; i++) {
      store.eatOneBite();
    }
    expect(store.foodLeft, 0);
    expect(store.bowlEmpty, isTrue);
    expect(store.eatOneBite(), isFalse); // 碗空了吃不到
    expect(store.companion!.feeds, kFoodBowlCap);
    expect(store.companionHungry, isTrue); // 碗空 = 饿
  });

  test('装食盒：补满就停在上限，存档也会记住余粮', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    store.eatOneBite();
    final left = store.foodLeft;
    expect(left, kFoodBowlCap - 1);
    expect(store.addFood(99), kFoodBowlCap);

    // 存一次、读一次，余粮还在
    store.foodLeft = left;
    store.addFood(0);
    await store.load();
    expect(store.foodLeft, left);
  });

  testWidgets('点「喂它」：它自己跑去食盒边，吃掉一份粮食', (tester) async {
    SharedPreferences.setMockInitialValues({});
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

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 食盒上写着还有几份粮食
    expect(find.byKey(const ValueKey('pet-food-count')), findsOneWidget);
    expect(find.text('×$kFoodBowlCap'), findsOneWidget);
    expect(store.companion!.feeds, 0);

    await tester.tap(find.byKey(const ValueKey('pet-act-feed')));
    await tester.pump();
    // 走过去 1.15 秒 + 咬一口
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(store.foodLeft, kFoodBowlCap - 1); // 真的吃掉一份
    expect(store.companion!.feeds, 1); // 成长计数 +1
    expect(find.text('×${kFoodBowlCap - 1}'), findsOneWidget);
  });

  testWidgets('点「睡觉」：自己走到床上躺下（眯眼 + 飘 Z），点「叫醒」就起来', (tester) async {
    SharedPreferences.setMockInitialValues({});
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

    Iterable<PetAvatar> sleepingAvatars() => tester
        .widgetList<PetAvatar>(find.byType(PetAvatar))
        .where((a) => a.sleeping);

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(sleepingAvatars(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('pet-act-sleep')));
    await tester.pump();
    // 走到床边 1.4 秒 + 躺下
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sleepingAvatars(), isNotEmpty); // 真的躺下了
    expect(find.text('叫醒'), findsOneWidget); // 按钮变成叫醒

    await tester.tap(find.byKey(const ValueKey('pet-act-sleep')));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sleepingAvatars(), isEmpty);
    expect(find.text('睡觉'), findsOneWidget);
  });

  testWidgets('食盒空了点「装食盒」就补满，吃了还会有碎屑动作', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
    store.adoptStarterPet();
    store.foodLeft = 0;

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('空'), findsOneWidget); // 食盒空了

    await tester.tap(find.byKey(const ValueKey('pet-act-refill')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(store.foodLeft, kFoodBowlCap);
    expect(find.text('×$kFoodBowlCap'), findsOneWidget);
  });

  testWidgets('点水碗：它跑去喝水', (tester) async {
    SharedPreferences.setMockInitialValues({});
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

    await tester.pumpWidget(const MaterialApp(home: PetsHouseScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const ValueKey('pet-act-drink')));
    await tester.pump();
    // 走到水碗边 1.3 秒 + 三次低头
    var drinkingSeen = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester
          .widgetList<PetAvatar>(find.byType(PetAvatar))
          .any((a) => a.drinking)) {
        drinkingSeen = true;
      }
    }
    expect(drinkingSeen, isTrue);
    // 喝水不消耗粮食
    expect(store.foodLeft, kFoodBowlCap);
  });
}