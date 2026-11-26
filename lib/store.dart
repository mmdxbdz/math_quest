import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'pets.dart';

/// 全局进度存档（本地持久化）
class ProgressStore extends ChangeNotifier {
  static const _key = 'progress_v1';

  /// 上一份能正常读出来的存档（换版本、万一写坏了好回退）
  static const _backupKey = 'progress_v1_backup';

  /// 关卡(key = 'lessonId:s阶段') -> 最佳星数 1..3
  final Map<String, int> stars = {};

  /// 金币
  int coins = 0;

  /// 课时 -> [答题数, 答对数]
  final Map<String, List<int>> kp = {};

  /// 知识点 -> [答题数, 答对数]（skill 粒度，默认等于课时 id）
  final Map<String, List<int>> skillKp = {};

  /// 错题（复习条目）：
  /// {'q': questionJson, 'given': 学生答案,
  ///  'ts': 首次答错时间, 'wrongCount': 累计答错次数,
  ///  'lastWrongAt': 最近答错时间, 'lastCorrectAt': 最近练对时间(0=还没练对过),
  ///  'stage': 复习阶段 0..3（答对一轮 +1，连续 4 轮答对判定已掌握移出）}
  final List<Map<String, dynamic>> mistakes = [];

  /// 家长设置
  String currentLesson = '';
  int qsPerLevel = 8;

  /// 最近一次完成"今日任务"的日期 yyyy-M-d
  String todayDoneKey = '';

  /// 已学的课时（含之前的），用于复习出题
  final Set<String> learned = {};

  /// 思维挑战徽章：关卡 key -> 'gold'(全对) | 'silver'(错1题)
  final Map<String, String> challengeBadges = {};

  /// 一次答对统计：skill -> [一次答对数, 一次尝试数]（第一遍作答，用于发现蒙/不稳）
  final Map<String, List<int>> firstTryKp = {};

  /// 答题语音鼓励开关
  bool soundOn = true;

  /// 奖惩记录（现实奖惩，家长实施后标记）
  final List<RewardRecord> rewards = [];

  /// 宠物：[{'s': 种类 id, 'n': 名字, 'f': 已喂顿数, 'i': 第几个招领处}]
  final List<Map<String, dynamic>> petData = [];

  /// 当前陪伴的宠物（petData 下标）
  int companionIndex = 0;

  /// 上次喂养的时间戳（毫秒），用来判断宠物饿不饿
  int lastFeedAt = 0;

  /// 食盒里还剩几份粮食（0 = 空了，它就饿了）。喂一次吃掉一份。
  int foodLeft = 0;

  /// 闯关收集到的家具（kPetGifts 的 id）
  final List<String> giftIds = [];

  /// 宠物家里每个位置摆的东西：'房间.位置' -> giftId
  final Map<String, String> homeSlots = {};

  /// 家具在房间里的位置（0~1 的比例）：'房间.位置' -> Offset
  final Map<String, Offset> homePos = {};

  bool loaded = false;

  static ProgressStore? _inst;
  factory ProgressStore() => _inst ??= ProgressStore._();
  ProgressStore._();

  /// 各复习阶段的间隔天数：答错当天(0)次日回炉；之后 3 / 7 / 15 天
  static const List<int> stageDays = [1, 3, 7, 15];

  String _todayKey() {
    final n = DateTime.now();
    return n.year.toString() + '-' + n.month.toString() + '-' + n.day.toString();
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static int _daysSince(int ts) {
    if (ts <= 0) return 9999;
    return (_now() - ts) ~/ 86400000;
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_key);
    final bak = sp.getString(_backupKey);
    var ok = _loadFrom(s);
    if (!ok && bak != null) {
      // 主存档读不出来：退回上一份备份，绝不让娃白玩
      ok = _loadFrom(bak);
      if (ok) await _save();
    }
    if (ok && s != null && s.isNotEmpty) {
      // 这份能读，顺手留一份备份吃个定心丸
      await sp.setString(_backupKey, s);
    }
    // 旧版本没有 skillKp：从课时统计迁移（默认 skill = 课时 id）
    if (skillKp.isEmpty) {
      kp.forEach((k, v) => skillKp[k] = [v[0], v[1]]);
    }
    loaded = true;
    notifyListeners();
    // 已经通了足够多关卡的老玩家，把该来的新朋友补上
    claimNewPets();
  }

  /// 把一段存档文本读进内存；空文本 / 坏档返回 false（调用方可以退回备份）
  bool _loadFrom(String? s) {
    // 追加型集合先清空，保证重复 load 幂等
    mistakes.clear();
    learned.clear();
    rewards.clear();
    petData.clear();
    if (s == null || s.isEmpty) return false;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      _applyMap(j);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyMap(Map<String, dynamic> j) {
    (j['stars'] as Map?)?.forEach((k, v) => stars[k.toString()] = (v as num).toInt());
    coins = (j['coins'] as num?)?.toInt() ?? 0;
    (j['kp'] as Map?)?.forEach((k, v) {
      final list = (v as List).cast<num>().map((e) => e.toInt()).toList();
      if (list.length >= 2) kp[k.toString()] = [list[0], list[1]];
    });
    (j['skillKp'] as Map?)?.forEach((k, v) {
      final list = (v as List).cast<num>().map((e) => e.toInt()).toList();
      if (list.length >= 2) skillKp[k.toString()] = [list[0], list[1]];
    });
    final ms = j['mistakes'] as List?;
    if (ms != null) {
      for (final raw in ms.cast<Map<String, dynamic>>()) {
        final m = Map<String, dynamic>.from(raw);
        // 兼容旧存档：补复习字段
        m['wrongCount'] = (m['wrongCount'] as num?)?.toInt() ?? 1;
        m['lastWrongAt'] = (m['lastWrongAt'] as num?)?.toInt() ?? (m['ts'] as num?)?.toInt() ?? 0;
        m['lastCorrectAt'] = (m['lastCorrectAt'] as num?)?.toInt() ?? 0;
        m['stage'] = (m['stage'] as num?)?.toInt() ?? 0;
        mistakes.add(m);
      }
    }
    currentLesson = j['currentLesson'] as String? ?? '';
    qsPerLevel = (j['qsPerLevel'] as num?)?.toInt() ?? 8;
    todayDoneKey = j['todayDoneKey'] as String? ?? '';
    learned.addAll(((j['learned'] as List?) ?? const []).cast<String>());
    (j['challengeBadges'] as Map?)?.forEach((k, v) =>
        challengeBadges[k.toString()] = v.toString());
    (j['firstTryKp'] as Map?)?.forEach((k, v) {
      final list = (v as List).cast<num>().map((e) => e.toInt()).toList();
      if (list.length >= 2) firstTryKp[k.toString()] = [list[0], list[1]];
    });
    soundOn = j['soundOn'] as bool? ?? true;
    (j['rewards'] as List?)?.forEach((e) {
      rewards.add(RewardRecord.fromJson((e as Map).cast<String, dynamic>()));
    });
    (j['pets'] as List?)?.forEach((e) {
      petData.add((e as Map).cast<String, dynamic>());
    });
    companionIndex = (j['companion'] as num?)?.toInt() ?? 0;
    lastFeedAt = (j['lastFeedAt'] as num?)?.toInt() ?? 0;
    foodLeft = (j['food'] as num?)?.toInt() ?? (petData.isEmpty ? 0 : kFoodBowlCap);
    giftIds.clear();
    giftIds.addAll(((j['gifts'] as List?) ?? const []).cast<String>());
    homeSlots.clear();
    (j['home'] as Map?)?.forEach((k, v) {
      final id = v?.toString() ?? '';
      if (id.isEmpty) return;
      var key = k.toString();
      if (!key.contains('.')) key = 'living.' + key; // 老存档没有房间
      homeSlots[key] = id;
    });
    homePos.clear();
    (j['homePos'] as Map?)?.forEach((k, v) {
      final list = (v as List?) ?? const [];
      if (list.length < 2) return;
      var key = k.toString();
      if (!key.contains('.')) key = 'living.' + key;
      homePos[key] = Offset(
        (list[0] as num).toDouble().clamp(0.0, 1.0),
        (list[1] as num).toDouble().clamp(0.0, 1.0),
      );
    });
    if (companionIndex < 0 || companionIndex >= petData.length) {
      companionIndex = petData.isEmpty ? 0 : petData.length - 1;
    }
  }

  /// 整个存档序列化成可存的 Map（_save / 导出存档码都用它）
  Map<String, dynamic> toJson() => {
        'stars': stars,
        'coins': coins,
        'kp': kp,
        'skillKp': skillKp,
        'mistakes': mistakes,
        'currentLesson': currentLesson,
        'qsPerLevel': qsPerLevel,
        'todayDoneKey': todayDoneKey,
        'learned': learned.toList(),
        'challengeBadges': challengeBadges,
        'firstTryKp': firstTryKp,
        'soundOn': soundOn,
        'rewards': rewards.map((r) => r.toJson()).toList(),
        'pets': petData,
        'companion': companionIndex,
        'lastFeedAt': lastFeedAt,
        'food': foodLeft,
        'gifts': giftIds,
        'home': homeSlots,
        'homePos': {
          for (final e in homePos.entries) e.key: [e.value.dx, e.value.dy],
        },
      };

  /// 导出「存档码」：一串文字，换手机 / 重装 App 时贴回去就能接着玩
  String exportCode() =>
      base64Url.encode(utf8.encode(jsonEncode(toJson())));

  /// 用「存档码」恢复整份存档；成功返回 true
  bool importCode(String code) {
    final clean = code.replaceAll(RegExp(r'\s'), '');
    if (clean.isEmpty) return false;
    String raw;
    try {
      raw = utf8.decode(base64Url.decode(clean));
    } catch (_) {
      // 也允许直接贴 JSON
      raw = clean;
    }
    if (!_loadFrom(raw)) return false;
    if (skillKp.isEmpty) {
      kp.forEach((k, v) => skillKp[k] = [v[0], v[1]]);
    }
    _save();
    notifyListeners();
    return true;
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(toJson()));
  }

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  int stageStars(String lessonId, int stage) => stars[lessonId + ':s' + stage.toString()] ?? 0;

  bool levelUnlocked(List<String> orderedKeys, int index) {
    if (index <= 0) return true;
    return (stars[orderedKeys[index - 1]] ?? 0) >= 1;
  }

  void finishLevel(String key, int earned) {
    if (earned > (stars[key] ?? 0)) stars[key] = earned;
    _save();
    notifyListeners();
    // 通了新关卡就看看是不是又能来一位新朋友
    claimNewPets();
  }

  /// 记录一次作答，同时更新：课时统计、知识点统计、错题复习条目。
  /// [firstTry] 为 true 表示这是该题在本轮第一次作答（用于"一次答对率"监控）
  void recordAnswer(Question q, bool correct, String given,
      {bool firstTry = false}) {
    final cur = kp[q.lessonId] ?? [0, 0];
    cur[0] += 1;
    if (correct) cur[1] += 1;
    kp[q.lessonId] = cur;

    final sk = skillKp[q.skill] ?? [0, 0];
    sk[0] += 1;
    if (correct) sk[1] += 1;
    skillKp[q.skill] = sk;

    if (firstTry) {
      final ft = firstTryKp[q.skill] ?? [0, 0];
      ft[1] += 1;
      if (correct) ft[0] += 1;
      firstTryKp[q.skill] = ft;
    }

    final idx = _mistakeIndex(q.stem);
    if (!correct) {
      if (idx >= 0) {
        final m = mistakes[idx];
        m['given'] = given;
        m['wrongCount'] = ((m['wrongCount'] as num?)?.toInt() ?? 1) + 1;
        m['stage'] = 0; // 再答错，复习重新开始
        m['lastWrongAt'] = _now();
        mistakes.removeAt(idx);
        mistakes.insert(0, m);
      } else {
        mistakes.insert(0, {
          'q': q.toJson(),
          'given': given,
          'ts': _now(),
          'wrongCount': 1,
          'lastWrongAt': _now(),
          'lastCorrectAt': 0,
          'stage': 0,
        });
      }
      while (mistakes.length > 60) {
        mistakes.removeLast();
      }
    } else if (idx >= 0) {
      // 答对：复习阶段 +1，连续 4 轮答对 → 已掌握，移出错题本
      final m = mistakes[idx];
      final st = ((m['stage'] as num?)?.toInt() ?? 0) + 1;
      m['stage'] = st;
      m['lastCorrectAt'] = _now();
      mistakes.removeAt(idx);
      if (st >= 4) {
        // 已掌握
      } else {
        mistakes.insert(0, m);
      }
    }
    _save();
    notifyListeners();
  }

  int _mistakeIndex(String stem) {
    for (var i = 0; i < mistakes.length; i++) {
      if ((mistakes[i]['q'] as Map)['stem'] == stem) return i;
    }
    return -1;
  }

  /// 这道错题今天是否到期该复习
  bool mistakeDue(Map<String, dynamic> m) {
    final stage = ((m['stage'] as num?)?.toInt() ?? 0).clamp(0, stageDays.length - 1).toInt();
    final lastWrong = (m['lastWrongAt'] as num?)?.toInt() ?? (m['ts'] as num?)?.toInt() ?? 0;
    final lastCorrect = (m['lastCorrectAt'] as num?)?.toInt() ?? 0;
    final lastTs = lastCorrect > lastWrong ? lastCorrect : lastWrong;
    return _daysSince(lastTs) >= stageDays[stage];
  }

  /// 今天到期的错题（错题本顺序，新的在前）
  List<Map<String, dynamic>> dueMistakes() =>
      mistakes.where(mistakeDue).toList();

  int get dueMistakeCount => mistakes.where(mistakeDue).length;

  bool get todayDone => todayDoneKey == _todayKey();

  void markTodayDone(int bonus) {
    todayDoneKey = _todayKey();
    coins += bonus;
    _save();
    notifyListeners();
  }

  void addCoins(int n) {
    coins += n;
    _save();
    notifyListeners();
  }

  // ── 宠物系统 ──────────────────────────────────────────────

  List<Pet> get pets => petData.map(Pet.fromData).toList();

  int get petCount => petData.length;

  /// 某个招领处（从 0 开始）领到的宠物，没有则 null
  Pet? petOfSlot(int slot) {
    for (final m in petData) {
      if (((m['i'] as num?)?.toInt() ?? -1) == slot) return Pet.fromData(m);
    }
    return null;
  }

  /// 当前陪伴的宠物（闯关喂的是它）
  Pet? get companion {
    if (petData.isEmpty) return null;
    var i = companionIndex;
    if (i < 0) i = 0;
    if (i >= petData.length) i = petData.length - 1;
    return Pet.fromData(petData[i]);
  }

  /// 随机挑一只还没养过的种类
  PetSpecies randomPetSpecies([Random? rng]) =>
      randomNewSpecies(petData.map((m) => (m['s'] ?? '').toString()), rng);

  /// 领养一只宠物，成为当前陪伴
  Pet adoptPet(String speciesId, int slot, {String? name}) {
    final sp = petSpeciesOf(speciesId);
    final data = <String, dynamic>{
      's': sp.id,
      'n': name ?? sp.defaultName,
      'f': 0,
      'i': slot,
    };
    petData.add(data);
    companionIndex = petData.length - 1;
    lastFeedAt = _now();
    // 新来的先给它装好一盒粮食
    if (foodLeft <= 0) foodLeft = kFoodBowlCap;
    _save();
    notifyListeners();
    return Pet.fromData(data);
  }

  // ── 新宠物解锁 ────────────────────────────────────────────

  /// 已经拿到星星的关卡数
  int get doneLevelCount => stars.values.where((s) => s >= 1).length;

  /// 按进度应该拥有几只宠物（第 1 只是开场就送的）
  int get petUnlockTarget => min(
      kPetSpecies.length, 1 + doneLevelCount ~/ kPetUnlockEveryLevels);

  /// 还差几关能来下一位新朋友（已经全齐就是 0）
  int get levelsToNextPet {
    if (petUnlockTarget >= kPetSpecies.length) return 0;
    final next = petUnlockTarget * kPetUnlockEveryLevels;
    return max(0, next - doneLevelCount);
  }

  /// 下一位要来的新朋友（首页提前告诉娃"过了这关就能领小猫"）
  PetSpecies? get nextPetSpecies {
    final owned = petData.map((m) => (m['s'] ?? '').toString()).toSet();
    for (final id in kPetUnlockOrder) {
      if (!owned.contains(id)) return petSpeciesOf(id);
    }
    for (final sp in kPetSpecies) {
      if (!owned.contains(sp.id)) return sp;
    }
    return null;
  }

  /// 已经领到几只
  int get ownedPetKinds => petData.map((m) => (m['s'] ?? '').toString()).toSet().length;

  /// 刚刚到家的新朋友（界面演完动画后清掉）
  final List<String> newArrivals = [];

  /// 按闯关进度补发新宠物（按固定顺序来，不会抢走正在陪伴的那只）
  List<Pet> claimNewPets() {
    final added = <Pet>[];
    if (petData.isEmpty) return added; // 还没收养第一只，先不补发
    var guard = 0;
    while (petData.length < petUnlockTarget &&
        petData.length < kPetSpecies.length &&
        guard++ < 12) {
      final sp = nextPetSpecies;
      if (sp == null) break;
      final keepCompanion = companionIndex;
      final pet = adoptPet(sp.id, petData.length);
      companionIndex = keepCompanion;
      newArrivals.add(sp.id);
      added.add(pet);
    }
    if (added.isNotEmpty) {
      _save();
      notifyListeners();
    }
    return added;
  }

  /// 直接送一只新朋友（只给测试用，界面上没有入口）
  Pet? giftNewPet() {
    if (petData.length >= kPetSpecies.length) return null;
    final sp = nextPetSpecies ?? randomPetSpecies();
    final keepCompanion = companionIndex;
    final pet = adoptPet(sp.id, petData.length);
    companionIndex = keepCompanion;
    newArrivals.add(sp.id);
    _save();
    notifyListeners();
    return pet;
  }

  void clearNewArrivals() => newArrivals.clear();

  /// 喂当前陪伴的宠物一顿，返回它是否长大了一阶。
  /// 注意：界面上真正喂饭要走「食盒 → 它跑过去吃」，这里给测试和旧逻辑用。
  bool feedCompanion([int meals = 1]) {
    if (petData.isEmpty) return false;
    addFood(meals);
    var grew = false;
    for (var i = 0; i < meals; i++) {
      if (eatOneBite()) grew = true;
    }
    return grew;
  }

  // ── 食盒（余粮）─────────────────────────────────────────

  /// 往食盒里装粮食（闯关过关 / 娃自己装），最多 [kFoodBowlCap] 份
  int addFood([int n = 1]) {
    foodLeft = min(kFoodBowlCap, foodLeft + n);
    _save();
    notifyListeners();
    return foodLeft;
  }

  /// 它吃一口：食盒少一份，成长计数 +1。返回是否长大了一阶
  bool eatOneBite() {
    if (petData.isEmpty || foodLeft <= 0) return false;
    foodLeft -= 1;
    var i = companionIndex;
    if (i < 0) i = 0;
    if (i >= petData.length) i = petData.length - 1;
    final before = Pet.fromData(petData[i]).stage;
    final cur = (petData[i]['f'] as num?)?.toInt() ?? 0;
    petData[i]['f'] = cur + 1;
    lastFeedAt = _now();
    final after = Pet.fromData(petData[i]).stage;
    _save();
    notifyListeners();
    return after > before;
  }

  /// 食盒是不是空的（空了它就饿）
  bool get bowlEmpty => foodLeft <= 0;

  void setCompanion(int index) {
    if (index < 0 || index >= petData.length) return;
    companionIndex = index;
    _save();
    notifyListeners();
  }

  void renamePet(int index, String name) {
    if (index < 0 || index >= petData.length) return;
    final n = name.trim();
    if (n.isEmpty) return;
    petData[index]['n'] = n;
    _save();
    notifyListeners();
  }

  /// 给宠物戴帽子（kPetHats 下标）
  void setPetHat(int index, int hat) {
    if (index < 0 || index >= petData.length) return;
    final pet = Pet.fromData(petData[index]);
    if (!petHatUnlocked(hat, pet.stage)) return;
    petData[index]['h'] = hat;
    _save();
    notifyListeners();
  }

  /// 距离上次喂养过了多久
  Duration get sinceLastFeed => Duration(milliseconds: _now() - lastFeedAt);

  /// 某时刻的日期 key（yyyy-M-d）
  static String dayKeyOf(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return d.year.toString() + '-' + d.month.toString() + '-' + d.day.toString();
  }

  /// 判断"今天还没喂"——娃放学回来正好该喂它一顿
  bool hungryAt(int nowMs) {
    if (petData.isEmpty) return false;
    if (bowlEmpty) return true; // 食盒空了，它当然饿
    if (lastFeedAt <= 0) return true;
    return dayKeyOf(lastFeedAt) != dayKeyOf(nowMs);
  }

  bool get companionHungry => hungryAt(_now());

  // ── 宠物的小家（闯关收集的家具）───────────────────────────

  bool get hasPet => petData.isNotEmpty;

  /// 开局的北极熊幼仔
  Pet adoptStarterPet({String? name}) =>
      adoptPet(kStarterPetSpecies, 0, name: name ?? kStarterPetName);

  Set<String> get ownedGiftIds => giftIds.toSet();

  List<PetGift> get ownedGifts =>
      kPetGifts.where((g) => giftIds.contains(g.id)).toList();

  bool get allGiftsOwned => giftIds.length >= kPetGifts.length;

  PetGift? giftPlacedAt(String roomId, String type) =>
      petGiftById(homeSlots[roomId + '.' + type]);

  /// 这个房间解锁了吗（收集够家具才开）
  bool roomUnlocked(PetRoomDef room) => giftIds.length >= room.unlockGifts;

  /// 家具在房间里的位置（没拖过就用默认位置）
  Offset itemPos(PetRoomDef room, RoomSlotDef slot) =>
      homePos[room.keyOf(slot.type)] ?? Offset(slot.dx, slot.dy);

  /// 拖动家具：只改内存位置，松手时再 saveItems()
  void moveItem(PetRoomDef room, RoomSlotDef slot, double nx, double ny) {
    homePos[room.keyOf(slot.type)] =
        Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
    notifyListeners();
  }

  void saveItems() => _save();

  /// 闯关掉一件家具；收齐了就换成金币
  PetGift? grantRandomGift([Random? rng]) {
    final pool = kPetGifts.where((g) => !giftIds.contains(g.id)).toList();
    if (pool.isEmpty) {
      coins += 10;
      _save();
      notifyListeners();
      return null;
    }
    final g = pool[(rng ?? Random()).nextInt(pool.length)];
    giftIds.add(g.id);
    homeSlots.putIfAbsent('living.' + g.slot, () => g.id);
    _save();
    notifyListeners();
    return g;
  }

  /// 把某件家具摆到某个房间的位置（giftId 传 null = 收起来）
  void placeGift(String roomId, String type, String? giftId) {
    final key = roomId + '.' + type;
    if (giftId == null) {
      homeSlots.remove(key);
    } else {
      if (!giftIds.contains(giftId)) return;
      homeSlots[key] = giftId;
    }
    _save();
    notifyListeners();
  }

  /// 家长设置"学到哪一课"：orderedLessons 为全部课时 id 的全局顺序
  void setCurrentLesson(String lessonId, List<String> orderedLessons) {
    currentLesson = lessonId;
    final idx = orderedLessons.indexOf(lessonId);
    learned.clear();
    if (idx >= 0) {
      learned.addAll(orderedLessons.take(idx + 1));
    }
    _save();
    notifyListeners();
  }

  void setQsPerLevel(int n) {
    qsPerLevel = n;
    _save();
    notifyListeners();
  }

  /// 正确率最低的已学课时（答题数>=minN）
  String? weakestLesson({int minN = 4}) {
    String? best;
    double bestRate = 2;
    for (final id in learned) {
      final st = kp[id];
      if (st == null || st[0] < minN) continue;
      final rate = st[1] / st[0];
      if (rate < bestRate) {
        bestRate = rate;
        best = id;
      }
    }
    return best;
  }

  /// 正确率最低的知识点（答题数>=minN），用于今日任务精准复习
  String? weakestSkill({int minN = 3}) {
    String? best;
    double bestRate = 2;
    skillKp.forEach((id, st) {
      if (st[0] < minN) return;
      final rate = st[1] / st[0];
      if (rate < bestRate) {
        bestRate = rate;
        best = id;
      }
    });
    return best;
  }

  /// 某知识点的答题数与答对数（没有则返回 null）
  List<int>? skillStat(String skill) => skillKp[skill];

  /// 某课时知识点的答题数与答对数
  List<int>? lessonStat(String lessonId) => kp[lessonId];

  /// 某知识点的一次答对率：null = 没有数据
  double? firstTryRate(String skill) {
    final st = firstTryKp[skill];
    if (st == null || st[1] == 0) return null;
    return st[0] / st[1];
  }

  /// 记录思维挑战徽章：已获金牌不降级
  void markChallengeDone(String key, String badge) {
    if (badge == 'gold' || !challengeBadges.containsKey(key)) {
      challengeBadges[key] = badge;
    }
    _save();
    notifyListeners();
  }

  void setSoundOn(bool on) {
    soundOn = on;
    _save();
    notifyListeners();
  }

  /// 待实施奖惩次数
  int get pendingRewardCount =>
      rewards.where((r) => !r.implemented).length;

  /// 待实施奖惩净额（奖励为正、罚为负）
  int get pendingRewardNet {
    var net = 0;
    for (final r in rewards) {
      if (!r.implemented) net += r.amount;
    }
    return net;
  }

  void addReward(RewardRecord r) {
    rewards.add(r);
    _save();
    notifyListeners();
  }

  void markRewardImplemented(int index) {
    if (index < 0 || index >= rewards.length) return;
    rewards[index].implemented = true;
    _save();
    notifyListeners();
  }

  void markAllRewardsImplemented() {
    var changed = false;
    for (final r in rewards) {
      if (!r.implemented) {
        r.implemented = true;
        changed = true;
      }
    }
    if (changed) {
      _save();
      notifyListeners();
    }
  }

  void resetAll() {
    stars.clear();
    coins = 0;
    kp.clear();
    skillKp.clear();
    firstTryKp.clear();
    mistakes.clear();
    currentLesson = '';
    todayDoneKey = '';
    learned.clear();
    challengeBadges.clear();
    rewards.clear();
    petData.clear();
    companionIndex = 0;
    lastFeedAt = 0;
    foodLeft = 0;
    giftIds.clear();
    homeSlots.clear();
    homePos.clear();
    newArrivals.clear();
    replayIntro = false;
    _save();
    notifyListeners();
  }

  /// 家长「再看一遍开头动画」：不删任何数据，下次回首页把开场再演一遍
  bool replayIntro = false;
  void setReplayIntro(bool on) {
    replayIntro = on;
    notifyListeners();
  }

  /// 只清空宠物和小家，回到「第一次进游戏」的样子
  void resetPets() {
    petData.clear();
    companionIndex = 0;
    lastFeedAt = 0;
    foodLeft = 0;
    giftIds.clear();
    homeSlots.clear();
    homePos.clear();
    newArrivals.clear();
    replayIntro = false;
    _save();
    notifyListeners();
  }
}
