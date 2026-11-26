import 'dart:math';
import 'package:flutter/material.dart';

/// 宠物系统：开局就有一只北极熊幼仔等她；每闯一关喂它一顿，
/// 喂够 [kFeedsPerStage] 顿就长大一阶，闯关还会掉落可以布置小家的家具。
const int kFeedsPerStage = 3; // 每 3 顿长大一次
const int kPetStages = 5; // 0 小奶崽 → 4 胖乎乎

/// 能戴的帽子：下标 0 = 不戴；帽子 i 需要长到第 i 阶才解锁
const List<String> kPetHats = ['', '🎀', '🧢', '👒', '👑'];

int petHatUnlockStage(int hat) => hat;

bool petHatUnlocked(int hat, int stage) => stage >= petHatUnlockStage(hat);

/// 开局就等在家里的那只北极熊幼仔
const String kStarterPetSpecies = 'polar';
const String kStarterPetName = '雪球';

/// 每闯满这么多关，就有一位新朋友跑到家里来（第 1 只是开场送的）
const int kPetUnlockEveryLevels = 6;

/// 食盒最多能装几份粮食（一份 = 吃一口 = 长一阶计数 +1）
const int kFoodBowlCap = 5;

/// 新朋友到家的固定顺序：开场北极熊 → 小猫 → 小兔 → 小狗 → 熊猫 → 小熊 → 狐狸 → 小猪 → 青蛙。
/// 顺序固定，娃才能在首页看到"下一个是谁"。
const List<String> kPetUnlockOrder = [
  'polar',
  'cat',
  'rabbit',
  'dog',
  'panda',
  'bear',
  'fox',
  'pig',
  'frog',
];

// ─────────────────────────────────────────────────────────────
// 小品礼：闯关掉落的家具，可以摆进宠物的小家
// ─────────────────────────────────────────────────────────────

class PetGift {
  final String id;
  final String name;
  final String emoji;
  final String slot; // 属于哪个位置：bed / pillow / appliance / decor

  const PetGift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.slot,
  });
}

/// 宠物家里的一个摆放位置
class RoomSlotDef {
  final String type; // bed / pillow / appliance / decor
  final String name;
  final String hint;
  final double dx; // 默认位置（房间里 0~1 的比例）
  final double dy;
  final double size; // 图标字号

  const RoomSlotDef({
    required this.type,
    required this.name,
    required this.hint,
    required this.dx,
    required this.dy,
    required this.size,
  });
}

/// 宠物家的一个房间
class PetRoomDef {
  final String id;
  final String name;
  final String emoji;
  final int unlockGifts; // 收集到多少件家具才解锁
  final List<Color> wall;
  final List<Color> floor;
  final String windowEmoji;
  final bool night;
  final List<RoomSlotDef> slots;

  const PetRoomDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.unlockGifts,
    required this.wall,
    required this.floor,
    required this.windowEmoji,
    required this.slots,
    this.night = false,
  });

  String keyOf(String type) => id + '.' + type;
}

const List<PetRoomDef> kPetRooms = [
  PetRoomDef(
    id: 'living',
    name: '客厅',
    emoji: '🛋️',
    unlockGifts: 0,
    wall: [Color(0xFFEAF6FF), Color(0xFFFFF0D8)],
    floor: [Color(0xFFEBD3AE), Color(0xFFD9B684)],
    windowEmoji: '❄️',
    slots: [
      RoomSlotDef(type: 'bed', name: '小窝', hint: '睡觉的地方', dx: 0.02, dy: 0.72, size: 50),
      RoomSlotDef(type: 'pillow', name: '枕头', hint: '靠着打盹', dx: 0.33, dy: 0.80, size: 26),
      RoomSlotDef(type: 'appliance', name: '家电', hint: '生活小电器', dx: 0.74, dy: 0.70, size: 46),
      RoomSlotDef(type: 'decor', name: '摆件', hint: '装饰一下', dx: 0.52, dy: 0.08, size: 30),
    ],
  ),
  PetRoomDef(
    id: 'bedroom',
    name: '卧室',
    emoji: '🌙',
    unlockGifts: 4,
    wall: [Color(0xFF2E3A5C), Color(0xFF4A4368)],
    floor: [Color(0xFF6B5A7A), Color(0xFF554969)],
    windowEmoji: '🌙',
    night: true,
    slots: [
      RoomSlotDef(type: 'bed', name: '小床', hint: '晚上睡这里', dx: 0.04, dy: 0.68, size: 52),
      RoomSlotDef(type: 'pillow', name: '枕头', hint: '枕着睡', dx: 0.40, dy: 0.78, size: 28),
      RoomSlotDef(type: 'appliance', name: '小夜灯', hint: '睡觉不害怕', dx: 0.76, dy: 0.52, size: 40),
      RoomSlotDef(type: 'decor', name: '挂饰', hint: '挂起来', dx: 0.50, dy: 0.06, size: 30),
    ],
  ),
  PetRoomDef(
    id: 'snow',
    name: '雪屋',
    emoji: '🏔️',
    unlockGifts: 10,
    wall: [Color(0xFFDFF3FF), Color(0xFFFFFFFF)],
    floor: [Color(0xFFC9E8F7), Color(0xFFAFD9EE)],
    windowEmoji: '🌨️',
    slots: [
      RoomSlotDef(type: 'bed', name: '雪窝', hint: '暖暖的窝', dx: 0.03, dy: 0.70, size: 50),
      RoomSlotDef(type: 'pillow', name: '抱枕', hint: '软软的', dx: 0.34, dy: 0.80, size: 26),
      RoomSlotDef(type: 'appliance', name: '小暖炉', hint: '取暖用', dx: 0.75, dy: 0.62, size: 44),
      RoomSlotDef(type: 'decor', name: '冰雕', hint: '摆着好看', dx: 0.54, dy: 0.10, size: 32),
    ],
  ),
];

PetRoomDef petRoomOf(String id) => kPetRooms.firstWhere(
      (r) => r.id == id,
      orElse: () => kPetRooms.first,
    );

const List<PetGift> kPetGifts = [
  // 小窝
  PetGift(id: 'bed_basket', name: '竹篮窝', emoji: '🧺', slot: 'bed'),
  PetGift(id: 'bed_sofa', name: '小沙发', emoji: '🛋️', slot: 'bed'),
  PetGift(id: 'bed_tent', name: '小帐篷', emoji: '⛺', slot: 'bed'),
  PetGift(id: 'bed_wood', name: '小木床', emoji: '🛏️', slot: 'bed'),
  // 枕头
  PetGift(id: 'pil_bear', name: '小熊抱枕', emoji: '🧸', slot: 'pillow'),
  PetGift(id: 'pil_cloud', name: '云朵枕头', emoji: '☁️', slot: 'pillow'),
  PetGift(id: 'pil_star', name: '星星靠垫', emoji: '⭐', slot: 'pillow'),
  PetGift(id: 'pil_heart', name: '爱心抱枕', emoji: '💗', slot: 'pillow'),
  // 家电
  PetGift(id: 'ap_tv', name: '小电视', emoji: '📺', slot: 'appliance'),
  PetGift(id: 'ap_lamp', name: '小台灯', emoji: '💡', slot: 'appliance'),
  PetGift(id: 'ap_fan', name: '小风扇', emoji: '🌀', slot: 'appliance'),
  PetGift(id: 'ap_fridge', name: '小冰箱', emoji: '🧊', slot: 'appliance'),
  PetGift(id: 'ap_tablet', name: '小平板', emoji: '💻', slot: 'appliance'),
  // 摆件
  PetGift(id: 'de_plant', name: '小仙人掌', emoji: '🌵', slot: 'decor'),
  PetGift(id: 'de_ball', name: '小皮球', emoji: '🏀', slot: 'decor'),
  PetGift(id: 'de_balloon', name: '小气球', emoji: '🎈', slot: 'decor'),
  PetGift(id: 'de_photo', name: '合影相框', emoji: '🖼️', slot: 'decor'),
  PetGift(id: 'de_flower', name: '小盆栽', emoji: '🌸', slot: 'decor'),
];

PetGift? petGiftById(String? id) {
  if (id == null) return null;
  for (final g in kPetGifts) {
    if (g.id == id) return g;
  }
  return null;
}

List<PetGift> giftsForSlot(String slot) =>
    kPetGifts.where((g) => g.slot == slot).toList();

/// 宠物种类（全部用代码画，不依赖图片资源）
class PetSpecies {
  final String id;
  final String title;
  final String defaultName;
  final String food; // 它吃的东西（北极熊吃鱼，小兔吃胡萝卜…）
  final Color body;
  final Color belly;
  final Color ear;
  final Color patch;
  final int earStyle; // 0 圆耳 1 尖耳 2 长耳 3 猪耳

  /// 脖子上的小配饰：scarf 围巾 / bow 蝴蝶结 / harness 胸背带 / none
  final String accessory;
  final Color accColor;

  const PetSpecies({
    required this.id,
    required this.title,
    required this.defaultName,
    required this.body,
    required this.belly,
    required this.ear,
    required this.patch,
    this.food = '🐟',
    this.earStyle = 0,
    this.accessory = 'none',
    this.accColor = const Color(0xFFFF8FB0),
  });
}

const List<PetSpecies> kPetSpecies = [
  PetSpecies(
    id: 'cat',
    title: '小猫',
    defaultName: '喵喵',
    food: '🐟',
    body: Color(0xFFFFC98B),
    belly: Color(0xFFFFEBD2),
    ear: Color(0xFFF3A85F),
    patch: Color(0xFFFFA1A1),
    earStyle: 1,
    accessory: 'bow',
    accColor: Color(0xFFFF7FA8),
  ),
  PetSpecies(
    id: 'dog',
    title: '小狗',
    defaultName: '豆豆',
    food: '🍖',
    body: Color(0xFFF0D3A8),
    belly: Color(0xFFFDF4E3),
    ear: Color(0xFFD2A46B),
    patch: Color(0xFFFFA1A1),
    earStyle: 0,
    accessory: 'harness',
    accColor: Color(0xFF5FCB6C),
  ),
  PetSpecies(
    id: 'rabbit',
    title: '小兔',
    defaultName: '白团',
    food: '🥕',
    body: Color(0xFFFDF6F6),
    belly: Color(0xFFFFEEF4),
    ear: Color(0xFFF6C9D6),
    patch: Color(0xFFFF9DB4),
    earStyle: 2,
    accessory: 'bow',
    accColor: Color(0xFFFF9EC4),
  ),
  PetSpecies(
    id: 'bear',
    title: '小熊',
    defaultName: '棕棕',
    food: '🍯',
    body: Color(0xFFC89B78),
    belly: Color(0xFFE7C9AF),
    ear: Color(0xFFA97A56),
    patch: Color(0xFFF0A0A0),
    earStyle: 0,
    accessory: 'scarf',
    accColor: Color(0xFFF6A94A),
  ),
  PetSpecies(
    id: 'panda',
    title: '熊猫',
    defaultName: '团团',
    food: '🎋',
    body: Color(0xFFF7F7F7),
    belly: Color(0xFFFFFFFF),
    ear: Color(0xFF3B3B3B),
    patch: Color(0xFF3B3B3B),
    earStyle: 0,
    accessory: 'scarf',
    accColor: Color(0xFFE8615A),
  ),
  PetSpecies(
    id: 'fox',
    title: '小狐狸',
    defaultName: '橙子',
    food: '🍇',
    body: Color(0xFFFFAE6B),
    belly: Color(0xFFFFF0DE),
    ear: Color(0xFFF08A3C),
    patch: Color(0xFFFF9C9C),
    earStyle: 1,
    accessory: 'scarf',
    accColor: Color(0xFF7FC4E8),
  ),
  PetSpecies(
    id: 'pig',
    title: '小猪',
    defaultName: '圆宝',
    food: '🌽',
    body: Color(0xFFFFC2D1),
    belly: Color(0xFFFFE2EA),
    ear: Color(0xFFF5A0B6),
    patch: Color(0xFFFF8FA8),
    earStyle: 3,
    accessory: 'bow',
    accColor: Color(0xFFFF8FB0),
  ),
  PetSpecies(
    id: 'polar',
    title: '北极熊',
    defaultName: '雪球',
    food: '🐟',
    body: Color(0xFFF6FBFF),
    belly: Color(0xFFFFFFFF),
    ear: Color(0xFFD3E8F7),
    patch: Color(0xFFFFA8BC),
    earStyle: 0,
    accessory: 'scarf',
    accColor: Color(0xFF8FD0F0),
  ),
  PetSpecies(
    id: 'frog',
    title: '青蛙',
    defaultName: '呱呱',
    food: '🦟',
    body: Color(0xFFA8DF87),
    belly: Color(0xFFE3F7CF),
    ear: Color(0xFF7FC463),
    patch: Color(0xFFFFA1A1),
    earStyle: 0,
    accessory: 'bow',
    accColor: Color(0xFFFFD166),
  ),
];

PetSpecies petSpeciesOf(String id) {
  for (final s in kPetSpecies) {
    if (s.id == id) return s;
  }
  return kPetSpecies.first;
}

/// 一只宠物（不可变视图，真正存的是 store 里的 Map）
class Pet {
  final String speciesId;
  final String name;
  final int feeds;
  final int slot; // 第几个招领处领的（从 0 开始）
  final int hatIndex; // 戴的帽子（kPetHats 下标）

  const Pet({
    required this.speciesId,
    required this.name,
    required this.feeds,
    required this.slot,
    this.hatIndex = 0,
  });

  factory Pet.fromData(Map<String, dynamic> m) => Pet(
        speciesId: (m['s'] ?? 'cat').toString(),
        name: (m['n'] ?? '小宠物').toString(),
        feeds: (m['f'] as num?)?.toInt() ?? 0,
        slot: (m['i'] as num?)?.toInt() ?? 0,
        hatIndex: (m['h'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toData() => {
        's': speciesId,
        'n': name,
        'f': feeds,
        'i': slot,
        'h': hatIndex,
      };

  PetSpecies get species => petSpeciesOf(speciesId);

  int get stage {
    final s = feeds ~/ kFeedsPerStage;
    return s > kPetStages - 1 ? kPetStages - 1 : s;
  }

  bool get maxed => stage >= kPetStages - 1;

  /// 这一阶还差几顿
  int get feedsToNext => maxed ? 0 : kFeedsPerStage - (feeds % kFeedsPerStage);

  double get stageProgress =>
      maxed ? 1.0 : (feeds % kFeedsPerStage) / kFeedsPerStage;

  /// 离长大还差多少（0~1），给进度条用
  double get growProgress => maxed ? 1.0 : m13(feeds / ((kPetStages - 1) * kFeedsPerStage));

  static double m13(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  /// 体型：0 阶最小，4 阶最胖
  double get sizeScale => 1 + stage * 0.11;
  double get chubbyScale => 1 + stage * 0.055;

  String get stageName =>
      const ['小奶崽', '会走啦', '圆滚滚', '胖乎乎', '超级胖'][stage.clamp(0, 4)];
}

/// 画出来的宠物头像，stage 越高越大越胖。
/// 还能摆姿势：走路（小爪交替）、低头吃饭/喝水、张嘴、眨眼、睡觉。
class PetAvatar extends StatelessWidget {
  final PetSpecies species;
  final int stage;
  final double size;
  final bool sleeping;
  final int hatIndex;

  /// 走路：0~1 循环，小爪一前一后
  final double pawPhase;

  /// 低头（0 抬头，1 埋进碗里）
  final double dip;

  /// 张嘴（吃饭）
  final bool eating;

  /// 伸舌头喝水
  final bool drinking;

  /// 眨眼
  final bool blink;

  const PetAvatar({
    super.key,
    required this.species,
    required this.stage,
    this.size = 88,
    this.sleeping = false,
    this.hatIndex = 0,
    this.pawPhase = 0,
    this.dip = 0,
    this.eating = false,
    this.drinking = false,
    this.blink = false,
  });

  /// 走路时小爪的上下偏移（-1~1），[i] = 0 左 / 1 右
  double pawOffset(int i) =>
      sin((pawPhase * 2 * pi) + (i == 0 ? 0 : pi));

  @override
  Widget build(BuildContext context) {
    final st = stage.clamp(0, kPetStages - 1);
    final r = size * (0.17 + st * 0.026);
    final hat = (hatIndex >= 0 && hatIndex < kPetHats.length)
        ? kPetHats[hatIndex]
        : '';
    // 低头的时候帽子跟着脑袋一起下去
    final dipY = dip * r * 0.75;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _PetPainter(
              species: species,
              stage: st,
              sleeping: sleeping,
              pawPhase: pawPhase,
              dip: dip,
              eating: eating,
              drinking: drinking,
              blink: blink,
            ),
          ),
          if (hat.isNotEmpty)
            Positioned(
              top: size * 0.60 - r * 1.95 + dipY,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    hat,
                    style: TextStyle(fontSize: r * 1.05),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PetPainter extends CustomPainter {
  final PetSpecies species;
  final int stage;
  final bool sleeping;
  final double pawPhase;
  final double dip;
  final bool eating;
  final bool drinking;
  final bool blink;

  _PetPainter({
    required this.species,
    required this.stage,
    required this.sleeping,
    this.pawPhase = 0,
    this.dip = 0,
    this.eating = false,
    this.drinking = false,
    this.blink = false,
  });

  /// 走路时小爪的上下偏移（-1~1）
  double _paw(int i) => sin((pawPhase * 2 * pi) + (i == 0 ? 0 : pi));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final baseCy = h * 0.60; // 站着的中心
    final r = w * (0.17 + stage * 0.026); // 半径随阶段变大
    final wf = 1.0 + stage * 0.055; // 越来越宽（胖）
    // 低头：整个身子往下压
    final cy = baseCy + dip * r * 0.75;

    // 地面影子（软一点，像黏土摆在桌上）
    final shadowRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 1.10),
      width: r * 2.5 * wf,
      height: r * 0.68,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.20),
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(shadowRect),
    );

    // 耳朵（画在身体后面）
    final earPaint = Paint()..color = species.ear;
    switch (species.earStyle) {
      case 1: // 尖耳
        for (final dir in [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(cx + dir * r * 0.45, cy - r * 0.72)
            ..lineTo(cx + dir * r * 0.95, cy - r * 1.45)
            ..lineTo(cx + dir * r * 1.02, cy - r * 0.42)
            ..close();
          canvas.drawPath(p, earPaint);
        }
        break;
      case 2: // 长耳
        for (final dir in [-1.0, 1.0]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx + dir * r * 0.42, cy - r * 1.35),
              width: r * 0.42,
              height: r * 1.15,
            ),
            earPaint,
          );
        }
        break;
      case 3: // 猪耳
        for (final dir in [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(cx + dir * r * 0.55, cy - r * 0.80)
            ..lineTo(cx + dir * r * 1.15, cy - r * 1.15)
            ..lineTo(cx + dir * r * 0.95, cy - r * 0.45)
            ..close();
          canvas.drawPath(p, earPaint);
        }
        break;
      default: // 圆耳
        for (final dir in [-1.0, 1.0]) {
          canvas.drawCircle(
            Offset(cx + dir * r * 0.62, cy - r * 0.92),
            r * 0.34,
            earPaint,
          );
        }
    }

    // 身体：黏土质感 = 左上打光 + 底部暗面 + 一圈高光
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: r * 2.2 * wf,
      height: r * 2.0,
    );
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.15,
          colors: [
            Color.lerp(species.body, Colors.white, 0.45)!,
            species.body,
            Color.lerp(species.body, const Color(0xFF6B4A33), 0.22)!,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(bodyRect),
    );
    // 左上一点柔光，黏土的反光
    canvas.save();
    canvas.clipPath(Path()..addOval(bodyRect));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - r * 0.62, cy - r * 0.66),
        width: r * 1.05,
        height: r * 0.72,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCenter(
          center: Offset(cx - r * 0.62, cy - r * 0.66),
          width: r * 1.05,
          height: r * 0.72,
        )),
    );
    canvas.restore();

    // 肚皮（软软的一大块，边上晕开）
    final bellyRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.40),
      width: r * 1.30 * wf,
      height: r * 1.12,
    );
    canvas.drawOval(
      bellyRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.0,
          colors: [
            species.belly,
            Color.lerp(species.belly, species.body, 0.55)!,
          ],
          stops: const [0.55, 1.0],
        ).createShader(bellyRect),
    );

    // 嘴鼻那一块浅浅的白色（参考图里猫狗熊都有）
    final muzzleRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.16),
      width: r * 0.98,
      height: r * 0.70,
    );
    canvas.drawOval(
      muzzleRect,
      Paint()..color = Color.lerp(species.belly, Colors.white, 0.55)!
          .withValues(alpha: species.id == 'panda' ? 0.0 : 0.92),
    );

    // 脖子上的小配饰
    _paintAccessory(canvas, cx, cy, r, wf);

    // 熊猫黑眼圈
    if (species.id == 'panda') {
      for (final dir in [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + dir * r * 0.42, cy - r * 0.34),
            width: r * 0.52,
            height: r * 0.44,
          ),
          Paint()..color = species.patch,
        );
      }
    }

    // 鼻子：圆钝的小鼻头 + 一点高光
    if (!(eating || drinking)) {
      final noseRect = Rect.fromCenter(
        center: Offset(cx, cy + r * 0.02),
        width: r * 0.30,
        height: r * 0.22,
      );
      canvas.drawOval(
        noseRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7E5850), Color(0xFF4E332E)],
          ).createShader(noseRect),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - r * 0.05, cy - r * 0.01),
          width: r * 0.10,
          height: r * 0.06,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }

    // 眼睛：大眼白 + 深色眼珠 + 两点高光（黏土玩偶那种亮亮的眼睛）
    const eyeDark = Color(0xFF3A2C28);
    if (sleeping) {
      for (final dir in [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(cx + dir * r * 0.42 - r * 0.16, cy - r * 0.34)
          ..quadraticBezierTo(
              cx + dir * r * 0.42, cy - r * 0.20, cx + dir * r * 0.42 + r * 0.16, cy - r * 0.34);
        canvas.drawPath(
          p,
          Paint()
            ..color = eyeDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.09
            ..strokeCap = StrokeCap.round,
        );
      }
    } else if (blink) {
      for (final dir in [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(cx + dir * r * 0.42 - r * 0.15, cy - r * 0.32),
          Offset(cx + dir * r * 0.42 + r * 0.15, cy - r * 0.32),
          Paint()
            ..color = eyeDark
            ..strokeWidth = r * 0.09
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      for (final dir in [-1.0, 1.0]) {
        final eyeCenter = Offset(cx + dir * r * 0.42, cy - r * 0.36);
        final ew = r * 0.36;
        final white = Rect.fromCenter(
          center: eyeCenter,
          width: ew,
          height: ew * 1.16,
        );
        canvas.drawOval(white, Paint()..color = Colors.white);
        final iris = Rect.fromCenter(
          center: eyeCenter + Offset(0, r * 0.015),
          width: ew * 0.78,
          height: ew * 0.90,
        );
        canvas.drawOval(
          iris,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(0, 0.55),
              colors: [Color(0xFF6E4B3E), eyeDark],
              stops: [0.0, 0.75],
            ).createShader(iris),
        );
        canvas.drawCircle(
          eyeCenter + Offset(-ew * 0.18, -ew * 0.24),
          ew * 0.19,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          eyeCenter + Offset(ew * 0.16, ew * 0.20),
          ew * 0.09,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }
    }

    if (eating || drinking) {
      // 张大嘴（吃饭/喝水）：黑黑的嘴巴 + 里面一点舌头
      final openW = r * (drinking ? 0.34 : 0.54);
      final openH = r * (drinking ? 0.30 : 0.48);
      final mouthRect = Rect.fromCenter(
        center: Offset(cx, cy + r * 0.20),
        width: openW,
        height: openH,
      );
      canvas.drawOval(mouthRect, Paint()..color = const Color(0xFF5B2E22));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy + r * 0.30),
          width: openW * 0.55,
          height: openH * 0.45,
        ),
        Paint()..color = const Color(0xFFFF8FA8),
      );
    } else {
      // 嘴巴
      final mouth = Path()
        ..moveTo(cx - r * 0.20, cy + r * 0.06)
        ..quadraticBezierTo(cx, cy + r * 0.30, cx + r * 0.20, cy + r * 0.06);
      canvas.drawPath(
        mouth,
        Paint()
          ..color = const Color(0xFF8A5A3B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08
          ..strokeCap = StrokeCap.round,
      );
    }

    // 腮红
    for (final dir in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + dir * r * 0.72, cy + r * 0.10),
          width: r * 0.36,
          height: r * 0.24,
        ),
        Paint()..color = species.patch.withValues(alpha: 0.45),
      );
    }

    // 四个小爪：走路时一前一后抬起来，肉垫是浅色的
    final pawY = baseCy + r * 0.95; // 小爪始终踩在地上
    for (var i = 0; i < 2; i++) {
      final dir = i == 0 ? -1.0 : 1.0;
      final lift = _paw(i) * r * 0.16;
      final pawRect = Rect.fromCenter(
        center: Offset(cx + dir * r * 0.62 * wf, pawY + lift),
        width: r * 0.52,
        height: r * 0.36,
      );
      canvas.drawOval(
        pawRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            radius: 1.1,
            colors: [
              Color.lerp(species.ear, Colors.white, 0.35)!,
              species.ear,
            ],
          ).createShader(pawRect),
      );
      // 肉垫：一大两小
      final padColor = species.patch.withValues(alpha: 0.55);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, 1) + Offset(cx + dir * r * 0.62 * wf, pawY + lift),
          width: r * 0.17,
          height: r * 0.13,
        ),
        Paint()..color = padColor,
      );
      for (final ox in [-0.13, 0.0, 0.13]) {
        canvas.drawCircle(
          Offset(cx + dir * r * 0.62 * wf + r * ox, pawY + lift - r * 0.10),
          r * 0.035,
          Paint()..color = padColor,
        );
      }
    }

    // 边线让轮廓更清楚
    canvas.drawOval(
      bodyRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06,
    );
  }

  /// 脖子上的小配饰（参考图里的围巾 / 蝴蝶结 / 胸背带）
  void _paintAccessory(Canvas canvas, double cx, double cy, double r, double wf) {
    final acc = species.accessory;
    if (acc == 'none') return;
    final base = species.accColor;
    final dark = Color.lerp(base, const Color(0xFF3A2C28), 0.28)!;
    final light = Color.lerp(base, Colors.white, 0.35)!;
    final y = cy + r * 0.52;

    switch (acc) {
      case 'scarf':
        // 围在脖子上一圈
        final band = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, y),
            width: r * 1.22 * wf,
            height: r * 0.24,
          ),
          Radius.circular(r * 0.12),
        );
        canvas.drawRRect(
          band,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [light, base, dark],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(band.outerRect),
        );
        // 尾巴：往右下飘出去一小截
        final tail = Path()
          ..moveTo(cx + r * 0.14, y + r * 0.04)
          ..lineTo(cx + r * 0.54, y + r * 0.20)
          ..lineTo(cx + r * 0.44, y + r * 0.42)
          ..lineTo(cx + r * 0.06, y + r * 0.16)
          ..close();
        canvas.drawPath(
          tail,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, dark],
            ).createShader(tail.getBounds()),
        );
        break;
      case 'bow':
        // 蝴蝶结：两侧三角 + 中间结
        for (final dir in [-1.0, 1.0]) {
          final wing = Path()
            ..moveTo(cx, y)
            ..lineTo(cx + dir * r * 0.30, y - r * 0.17)
            ..lineTo(cx + dir * r * 0.30, y + r * 0.17)
            ..close();
          canvas.drawPath(
            wing,
            Paint()
              ..shader = LinearGradient(
                begin: dir < 0 ? Alignment.centerRight : Alignment.centerLeft,
                end: dir < 0 ? Alignment.centerLeft : Alignment.centerRight,
                colors: [base, light],
              ).createShader(wing.getBounds()),
          );
        }
        canvas.drawCircle(
          Offset(cx, y),
          r * 0.10,
          Paint()..color = dark,
        );
        canvas.drawCircle(
          Offset(cx - r * 0.03, y - r * 0.04),
          r * 0.032,
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
        break;
      default: // harness 胸背带：两条带子 + 一个扣
        final strap = Paint()..color = base;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy + r * 0.34),
              width: r * 1.10 * wf,
              height: r * 0.15,
            ),
            Radius.circular(r * 0.08),
          ),
          strap,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy + r * 0.80),
              width: r * 0.94 * wf,
              height: r * 0.14,
            ),
            Radius.circular(r * 0.07),
          ),
          strap,
        );
        // 中间的金属扣
        canvas.drawCircle(
          Offset(cx, cy + r * 0.56),
          r * 0.11,
          Paint()..color = const Color(0xFFFFE7A8),
        );
        canvas.drawCircle(
          Offset(cx, cy + r * 0.56),
          r * 0.06,
          Paint()..color = const Color(0xFFE6B75C),
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_PetPainter old) =>
      old.stage != stage ||
      old.species.id != species.id ||
      old.sleeping != sleeping ||
      old.pawPhase != pawPhase ||
      old.dip != dip ||
      old.eating != eating ||
      old.drinking != drinking ||
      old.blink != blink;
}

/// 随机挑一只还没养过的宠物种类
PetSpecies randomNewSpecies(Iterable<String> ownedIds, [Random? rng]) {
  final owned = ownedIds.toSet();
  final pool = kPetSpecies.where((s) => !owned.contains(s.id)).toList();
  final list = pool.isEmpty ? kPetSpecies : pool;
  return list[(rng ?? Random()).nextInt(list.length)];
}