import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_quest/content/curriculum.dart';
import 'package:math_quest/pets.dart';
import 'package:math_quest/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 娃已经玩了一半的存档，升级版本后必须原样接上，绝不能让她重做。
void main() {
  /// 造一份"老版本"存档：没有 food、宠物没有帽子字段、错题没有复习字段
  String oldSave({int levels = 8}) {
    final stars = <String, int>{};
    for (var i = 0; i < levels; i++) {
      stars[orderedLevelKeys[i]] = 2 + (i % 2);
    }
    return jsonEncode({
      'stars': stars,
      'coins': 137,
      'kp': {'u1l1': [20, 17]},
      'mistakes': [
        {
          'q': {
            'kind': 'num',
            'stem': '7 + 8 = ?',
            'answer': 15,
            'options': const <int>[],
          },
          'given': 14,
          'ts': 1700000000000,
        }
      ],
      'currentLesson': 'u2l1',
      'qsPerLevel': 8,
      'todayDoneKey': '2026-1-1',
      'learned': ['u1l1', 'u1l2'],
      'challengeBadges': {'ch-seq-1': 'gold'},
      'firstTryKp': {'u1l1': [10, 11]},
      'soundOn': false,
      'rewards': [
        {
          'dateKey': '2026-1-1',
          'score': 1.0,
          'amount': 2,
          'rule': '满分奖励',
          'implemented': true,
        }
      ],
      // 老存档的宠物没有帽子字段 'h'，也没有 'food'
      'pets': [
        {'s': 'polar', 'n': '雪球', 'f': 4, 'i': 0}
      ],
      'companion': 0,
      'lastFeedAt': 1700000000000,
      'gifts': ['de_photo'],
      'home': {'bed': 'bed_basket'},
      'homePos': {
        'living.bed': [0.2, 0.7]
      },
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    await store.load();
    store.resetAll();
  });

  test('老版本存档升级后：星星、金币、错题、宠物全都还在', () async {
    SharedPreferences.setMockInitialValues({'progress_v1': oldSave()});
    final store = ProgressStore();
    await store.load();

    // 关卡星星：一道不少，星数原样
    expect(store.doneLevelCount, 8);
    expect(store.stageStars('', 0), 0); // 只是确保 API 正常
    expect(store.stars[orderedLevelKeys[0]], 2);
    expect(store.stars[orderedLevelKeys[1]], 3);

    // 金币、设置、错题本
    expect(store.coins, 137);
    expect(store.soundOn, isFalse);
    expect(store.currentLesson, 'u2l1');
    expect(store.todayDoneKey, '2026-1-1');
    expect(store.mistakes.length, 1);
    expect(store.mistakes.first['stage'], 0); // 老错题自动补复习字段
    expect(store.learned, containsAll(['u1l1', 'u1l2']));
    expect(store.challengeBadges['ch-seq-1'], 'gold');
    expect(store.rewards.length, 1);
    expect(store.rewards.first.implemented, isTrue);

    // 宠物：成长顿数还在，没帽子字段也不崩
    final polar = store.pets.firstWhere((p) => p.speciesId == 'polar');
    expect(polar.name, '雪球');
    expect(polar.feeds, 4);
    expect(polar.hatIndex, 0);

    // 老存档没有 food：直接给满一盒粮食，马上就能喂
    expect(store.foodLeft, kFoodBowlCap);

    // 已经通了 8 关：该来的新朋友照样补上，但原来那只没被换掉
    expect(store.petCount, greaterThanOrEqualTo(2));
    expect(store.companion!.speciesId, 'polar');

    // 家具和小家的摆放也保住了
    expect(store.ownedGiftIds, contains('de_photo'));
    expect(store.giftPlacedAt('living', 'bed'), isNotNull);
  });

  test('主存档坏了会退回上一份备份，不让娃白玩', () async {
    // 主存档是一段坏 JSON，备份是好的
    SharedPreferences.setMockInitialValues({
      'progress_v1': '{"stars": {oops',
      'progress_v1_backup': oldSave(levels: 5),
    });
    final store = ProgressStore();
    await store.load();

    expect(store.doneLevelCount, 5);
    expect(store.coins, 137);
    expect(store.pets, isNotEmpty);
  });

  test('正常的存档读进来后会留一份备份，下次坏档能用', () async {
    SharedPreferences.setMockInitialValues({'progress_v1': oldSave(levels: 3)});
    final store = ProgressStore();
    await store.load();

    final sp = await SharedPreferences.getInstance();
    final bak = sp.getString('progress_v1_backup');
    expect(bak, isNotNull);
    expect(bak, contains('"stars"'));
  });

  test('存档码：导出再导入，进度一模一样', () async {
    SharedPreferences.setMockInitialValues({'progress_v1': oldSave(levels: 6)});
    final store = ProgressStore();
    await store.load();
    final code = store.exportCode();
    expect(code.isNotEmpty, isTrue);
    final starsBefore = Map<String, int>.from(store.stars);
    final coinsBefore = store.coins;
    final petNames = store.pets.map((p) => p.name).toList();
    final feedsBefore = store.pets.map((p) => p.feeds).toList();

    // 换一台"新手机"：进度是空的
    SharedPreferences.setMockInitialValues({});
    final fresh = ProgressStore();
    fresh.resetAll();
    expect(fresh.doneLevelCount, 0);
    expect(fresh.pets, isEmpty);

    // 贴存档码恢复
    expect(fresh.importCode(code), isTrue);
    expect(fresh.stars, starsBefore);
    expect(fresh.coins, coinsBefore);
    expect(fresh.pets.map((p) => p.name).toList(), petNames);
    expect(fresh.pets.map((p) => p.feeds).toList(), feedsBefore);

    // 恢复完还会存到本地，重启也还在
    await fresh.load();
    expect(fresh.doneLevelCount, starsBefore.length);
  });

  test('存档码读不懂也不会把进度清空', () async {
    SharedPreferences.setMockInitialValues({'progress_v1': oldSave(levels: 4)});
    final store = ProgressStore();
    await store.load();
    expect(store.doneLevelCount, 4);

    expect(store.importCode('这不是存档码'), isFalse);
    expect(store.doneLevelCount, 4); // 原进度还在
  });
}