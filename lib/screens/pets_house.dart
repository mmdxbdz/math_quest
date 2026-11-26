import 'dart:math';
import 'package:flutter/material.dart';
import '../pets.dart';
import '../soundfx.dart';
import '../speech.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/pet_visit.dart';
import '../widgets/photo_card.dart';

/// 宠物住所：热情的北极熊、能拖动布置的小家、收集来的家具
class PetsHouseScreen extends StatefulWidget {
  const PetsHouseScreen({super.key});

  @override
  State<PetsHouseScreen> createState() => _PetsHouseScreenState();
}

class _PetsHouseScreenState extends State<PetsHouseScreen>
    with SingleTickerProviderStateMixin {
  final ProgressStore store = ProgressStore();

  /// 一进来就热情欢迎（爱心飘起来）
  late final AnimationController _welcome = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  PetRoomDef _room = kPetRooms.first;

  static const List<double> _lickBeats = [0.10, 0.26, 0.42];
  int _licked = 0;

  /// 娃刚按的动作（喂它 / 喝水 / 睡觉），配合 _actToken 触发一次
  _PetAct _act = _PetAct.idle;
  int _actToken = 0;
  bool _dreaming = false;

  @override
  void initState() {
    super.initState();
    _welcome.addListener(_onWelcomeTick);
    _welcome.forward(from: 0);
  }

  /// 一进门它就凑过来舔几下（只有动作和声音，不说话）
  void _onWelcomeTick() {
    for (var i = _licked; i < _lickBeats.length; i++) {
      if (_welcome.value >= _lickBeats[i]) {
        _licked = i + 1;
        SoundFx.lick();
      }
    }
  }

  @override
  void dispose() {
    _welcome.removeListener(_onWelcomeTick);
    _welcome.dispose();
    super.dispose();
  }

  // ── 动作：喂它 / 喝水 / 睡觉 ──────────────────────────────

  void _command(_PetAct act) {
    if (act == _PetAct.eat && store.foodLeft <= 0) {
      _refillBowl();
      return;
    }
    setState(() {
      if (act == _PetAct.sleep) _dreaming = true;
      if (act == _PetAct.wake) _dreaming = false;
      // 吃饭、喝水的时候它会自己醒过来
      if (act == _PetAct.eat || act == _PetAct.drink) _dreaming = false;
      _act = act;
      _actToken++;
    });
  }

  /// 往食盒里装满粮食（免费，娃点了就有）
  void _refillBowl() {
    if (store.foodLeft >= kFoodBowlCap) return;
    store.addFood(kFoodBowlCap);
    SoundFx.chime();
    setState(() => _act = _PetAct.idle);
  }

  /// 它咬了一口：食盒少一份，成长 +1
  void _onBite() {
    final grew = store.eatOneBite();
    if (grew) {
      SoundFx.chime();
      Speech.cheer();
    }
  }

  void _onSip() {
    // 喝水：动作和声音都在宠物身上，这里只记一下
  }

  /// 一排按钮：喂它 / 喝水 / 睡觉 / 装食盒
  Widget _actionBar() {
    final food = store.foodLeft;
    return Row(
      children: [
        Expanded(
          child: _actButton(
            key: const ValueKey('pet-act-feed'),
            emoji: '🍚',
            label: '喂它',
            note: food > 0 ? '还有 $food 份' : '食盒空了',
            enabled: food > 0,
            onTap: () => _command(_PetAct.eat),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actButton(
            key: const ValueKey('pet-act-drink'),
            emoji: '💧',
            label: '喝水',
            note: '去水碗',
            onTap: () => _command(_PetAct.drink),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actButton(
            key: const ValueKey('pet-act-sleep'),
            emoji: _dreaming ? '☀️' : '🌙',
            label: _dreaming ? '叫醒' : '睡觉',
            note: _dreaming ? '它睡着了' : '回小床',
            onTap: () => _command(_dreaming ? _PetAct.wake : _PetAct.sleep),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actButton(
            key: const ValueKey('pet-act-refill'),
            emoji: '🧺',
            label: '装食盒',
            note: food >= kFoodBowlCap ? '已装满' : '装满粮食',
            onTap: _refillBowl,
          ),
        ),
      ],
    );
  }

  Widget _actButton({
    required Key key,
    required String emoji,
    required String label,
    required String note,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? Colors.orange.shade300 : Colors.black12,
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 19)),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: enabled ? Colors.black87 : Colors.black38,
              ),
            ),
            Text(
              note,
              style: TextStyle(
                fontSize: 9,
                color: enabled ? Colors.black45 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E4),
      appBar: AppBar(
        title: const Text('宠物住所'),
        backgroundColor: const Color(0xFFFFF6E4),
        foregroundColor: QuietBook.ink,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final pet = store.companion;
          if (pet == null) return const _EmptyHouse();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
            children: [
              _helloCard(pet),
              const SizedBox(height: 10),
              _petSwitcher(),
              const SizedBox(height: 10),
              _roomTabs(),
              const SizedBox(height: 8),
              _PetRoomView(
                store: store,
                pet: pet,
                room: _room,
                hungry: store.companionHungry,
                welcome: _welcome,
                onPetTap: _petIt,
                act: _act,
                actToken: _actToken,
                onBite: _onBite,
                onSip: _onSip,
                onFoodTap: () => _command(_PetAct.eat),
                onRefillTap: _refillBowl,
                onWaterTap: () => _command(_PetAct.drink),
              ),
              const SizedBox(height: 8),
              _actionBar(),
              const SizedBox(height: 10),
              _progressRow(pet),
              const SizedBox(height: 14),
              _homeSlotsRow(),
              const SizedBox(height: 16),
              _giftBox(),
            ],
          );
        },
      ),
    );
  }

  // ── 朋友们 ───────────────────────────────────────────────

  /// 一横排：养到的所有朋友 + 下一个还没到的位置
  Widget _petSwitcher() {
    final pets = store.pets;
    final more = store.petUnlockTarget < kPetSpecies.length;
    final left = store.levelsToNextPet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('我的朋友们（${pets.length}）',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (more && left > 0)
              Text('再闯 $left 关来新朋友',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: pets.length + (more ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i >= pets.length) return _lockedPetSlot(left);
              final p = pets[i];
              final active = i == store.companionIndex;
              return GestureDetector(
                onTap: () => setState(() => store.setCompanion(i)),
                child: Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.orange.shade50
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active
                          ? Colors.orange.shade400
                          : Colors.orange.shade100,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PetAvatar(
                        species: p.species,
                        stage: p.stage,
                        hatIndex: p.hatIndex,
                        size: 42,
                      ),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _lockedPetSlot(int left) {
    final next = store.nextPetSpecies;
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (next != null)
                  Opacity(
                    opacity: 0.42,
                    child: PetAvatar(
                      species: next,
                      stage: 0,
                      hatIndex: 0,
                      size: 38,
                    ),
                  )
                else
                  const Text('🔒', style: TextStyle(fontSize: 22)),
                Positioned(
                  right: 8,
                  bottom: 0,
                  child: Text(left <= 1 ? '🎁' : '🔒',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Text(
            next == null
                ? '新朋友'
                : (left > 0 ? '再 $left 关领${next.title}' : '领${next.title}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  // ── 名字和朋友 ───────────────────────────────────────────

  Widget _helloCard(Pet pet) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          PetAvatar(
            species: pet.species,
            stage: pet.stage,
            hatIndex: pet.hatIndex,
            size: 46,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  pet.species.title + ' · ' + pet.stageName,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          _roundButton('✏️', _rename),
          const SizedBox(width: 6),
          _roundButton('🎩', _pickHat),
        ],
      ),
    );
  }

  // ── 房间切换 ─────────────────────────────────────────────

  Widget _roomTabs() {
    return Row(
      children: [
        for (final r in kPetRooms) ...[
          Expanded(child: _roomTab(r)),
          if (r != kPetRooms.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _roomTab(PetRoomDef r) {
    final unlocked = store.roomUnlocked(r);
    final selected = r.id == _room.id;
    final need = r.unlockGifts - store.giftIds.length;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (!unlocked) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('再收集 ' + need.toString() + ' 件家具，'
                + r.name + '就开门啦～'),
            duration: const Duration(seconds: 2),
          ));
          return;
        }
        setState(() => _room = r);
        Speech.cheer();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.orange.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.orange : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(unlocked ? r.emoji : '🔒',
                style: TextStyle(
                    fontSize: 18, color: unlocked ? null : Colors.grey)),
            const SizedBox(height: 2),
            Text(
              r.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: unlocked ? Colors.black87 : Colors.grey,
              ),
            ),
            Text(
              unlocked
                  ? (r.id == _room.id ? '正在这里' : '去看看')
                  : '再收 ' + need.toString() + ' 件',
              style: TextStyle(
                fontSize: 9,
                color: unlocked
                    ? (r.id == _room.id ? Colors.deepOrange : Colors.grey)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 成长进度 ─────────────────────────────────────────────

  Widget _progressRow(Pet pet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              pet.species.title + ' · ' + pet.stageName,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const Spacer(),
            Text(
              pet.maxed
                ? '已吃成圆滚滚'
                : '再吃 ' +
                    pet.feedsToNext.toString() +
                    ' 口长大 · 食盒还有 ' +
                    store.foodLeft.toString() +
                    ' 份',
              style: const TextStyle(fontSize: 12.5, color: Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pet.growProgress,
            minHeight: 9,
            backgroundColor: Colors.orange.shade50,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      ],
    );
  }

  // ── 小家配置 ─────────────────────────────────────────────

  Widget _homeSlotsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.home, size: 16, color: Colors.lightBlue),
            const SizedBox(width: 6),
            Text(_room.name + '的布置',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: QuietBook.ink)),
            const Spacer(),
            Text('点一下换 · 按住拖动挪位置',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final slot in _room.slots) ...[
              Expanded(child: _slotCard(slot)),
              if (slot != _room.slots.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _slotCard(RoomSlotDef slot) {
    final gift = store.giftPlacedAt(_room.id, slot.type);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _configure(_room, slot),
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gift == null
                ? Colors.black.withValues(alpha: 0.07)
                : Colors.lightBlue.shade200,
            width: gift == null ? 1 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gift?.emoji ?? '➕',
              style: TextStyle(
                fontSize: gift == null ? 18 : 24,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                slot.name,
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                gift?.name ?? slot.hint,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 9,
                    color: gift == null
                        ? Colors.grey.shade500
                        : Colors.lightBlue.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _configure(PetRoomDef room, RoomSlotDef slot) {
    final owned = giftsForSlot(slot.type)
        .where((g) => store.ownedGiftIds.contains(g.id))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFFBF2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slot.name + ' 放什么？',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              owned.isEmpty
                  ? '还没有这类家具，闯关会掉落小礼品哦～'
                  : '挑一件摆在这里，也可以按住它拖动位置',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _giftChoice(ctx, room, slot, null),
                for (final g in owned) _giftChoice(ctx, room, slot, g),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _giftChoice(
      BuildContext ctx, PetRoomDef room, RoomSlotDef slot, PetGift? gift) {
    final current = store.giftPlacedAt(room.id, slot.type);
    final selected = current?.id == gift?.id;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        store.placeGift(room.id, slot.type, gift?.id);
        Navigator.of(ctx).pop();
        Speech.cheer();
      },
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.lightBlue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.lightBlue : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(gift?.emoji ?? '🚫', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              gift?.name ?? '收起来',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── 礼物箱 ───────────────────────────────────────────────

  Widget _giftBox() {
    final owned = store.ownedGifts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.card_giftcard, size: 16, color: Colors.deepOrange),
            const SizedBox(width: 6),
            const Text('礼物箱',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: QuietBook.ink)),
            const SizedBox(width: 6),
            Text('${owned.length}/${kPetGifts.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('闯关就能得到新家具，点一下直接摆进当前房间',
            style: TextStyle(fontSize: 11.5, color: Colors.black54)),
        const SizedBox(height: 10),
        if (owned.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '还空空的，去闯一关吧～',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.black45),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final g in owned) _giftChip(g),
            ],
          ),
      ],
    );
  }

  Widget _giftChip(PetGift g) {
    final placed = store.homeSlots[_room.keyOf(g.slot)] == g.id;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        store.placeGift(_room.id, g.slot, g.id);
        Speech.cheer();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('把' + g.name + '摆到' + _room.name + '啦～'),
          duration: const Duration(seconds: 2),
        ));
      },
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: placed ? Colors.lightBlue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: placed ? Colors.lightBlue.shade200 : Colors.black12,
          ),
        ),
        child: Column(
          children: [
            Text(g.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 3),
            Text(
              g.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5),
            ),
            Text(
              placed ? '摆在中' : '点我摆上',
              style: TextStyle(
                fontSize: 9,
                color: placed ? Colors.lightBlue : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 互动 ─────────────────────────────────────────────────

  void _petIt() {
    // 睡着了就摸醒，醒着就舔一口
    if (_dreaming) {
      _command(_PetAct.wake);
      return;
    }
    Speech.cheer();
    _welcome.forward(from: 0);
  }

  void _rename() async {
    final pet = store.companion;
    if (pet == null) return;
    final controller = TextEditingController(text: pet.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('给它取个名字'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          decoration: const InputDecoration(hintText: '比如 雪球、团子、北极'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('算了')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('就叫这个'),
          ),
        ],
      ),
    );
    if (name == null) return;
    store.renamePet(store.companionIndex, name);
    Speech.cheer();
  }

  void _pickHat() {
    final pet = store.companion;
    if (pet == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('挑个帽子戴'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < kPetHats.length; i++) _hatOption(ctx, i, pet),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('好了')),
        ],
      ),
    );
  }

  Widget _hatOption(BuildContext ctx, int i, Pet pet) {
    final unlocked = petHatUnlocked(i, pet.stage);
    final selected = pet.hatIndex == i;
    final label = i == 0 ? '不戴' : kPetHats[i];
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: unlocked
          ? () {
              store.setPetHat(store.companionIndex, i);
              Navigator.of(ctx).pop();
            }
          : null,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.orange.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.orange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(i == 0 ? '🚫' : kPetHats[i],
                style: TextStyle(
                    fontSize: 24, color: unlocked ? null : Colors.grey)),
            const SizedBox(height: 4),
            Text(
              unlocked ? label : '第 ' + petHatUnlockStage(i).toString() + ' 阶',
              style: TextStyle(
                fontSize: 11,
                color: unlocked ? Colors.black87 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(String emoji, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF6F1E8),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Text(emoji, style: const TextStyle(fontSize: 15)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 房间本体：可拖动的家具 + 走来走去（饿了会跑去吃饭）的宠物
// ─────────────────────────────────────────────────────────────

class _PetRoomView extends StatefulWidget {
  final ProgressStore store;
  final Pet pet;
  final PetRoomDef room;
  final bool hungry;
  final Animation<double> welcome;
  final VoidCallback onPetTap;

  /// 娃刚按了什么动作（喂它 / 喝水 / 睡觉 / 叫醒）
  final _PetAct act;
  final int actToken;
  final VoidCallback onBite;
  final VoidCallback onSip;

  /// 点食盒 = 喂它 / 点空食盒 = 装粮 / 点水碗 = 喝水
  final VoidCallback onFoodTap;
  final VoidCallback onRefillTap;
  final VoidCallback onWaterTap;

  const _PetRoomView({
    required this.store,
    required this.pet,
    required this.room,
    required this.hungry,
    required this.welcome,
    required this.onPetTap,
    required this.act,
    required this.actToken,
    required this.onBite,
    required this.onSip,
    required this.onFoodTap,
    required this.onRefillTap,
    required this.onWaterTap,
  });

  @override
  State<_PetRoomView> createState() => _PetRoomViewState();
}

class _PetRoomViewState extends State<_PetRoomView> {
  static const double _h = 264;
  static const double _floorH = 80;

  /// 宠物在房间里的显示尺寸
  static const double _petSize = 116;

  /// 食盒 / 水碗的中心位置（像素）
  static const double _bowlCenterPx = 46;
  static const double _waterCenterPx = 52;

  /// 拖动中的临时位置（0~1）
  final Map<String, Offset> _drag = {};

  /// 把"碗中心的像素位置"换算成宠物左边的归一化位置
  double _anchor(double roomW, double centerPx) {
    final travel = (roomW - _petSize - 20).clamp(1.0, 9999.0);
    return ((centerPx - _petSize / 2) / travel).clamp(0.0, 1.0);
  }

  /// 睡觉上哪儿：如果摆了床就睡床，否则睡右边垫子上
  double _bedCenterPx(double roomW) {
    for (final slot in widget.room.slots) {
      if (slot.type != 'bed') continue;
      if (widget.store.giftPlacedAt(widget.room.id, 'bed') == null) continue;
      final pos = widget.store.itemPos(widget.room, slot);
      final iw = slot.size * 1.15;
      final travelX = (roomW - iw).clamp(1.0, 9999.0);
      return (pos.dx * travelX + iw / 2).clamp(40.0, roomW - 40.0);
    }
    return roomW * 0.68;
  }

  /// 食盒：碗的正面写着还剩几份粮食，点一下就喂它 / 空了就点我装粮
  Widget _foodBowl(double roomW) {
    final n = widget.store.foodLeft;
    final full = n > 0;
    return Positioned(
      left: _bowlCenterPx - 26,
      bottom: 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: full ? widget.onFoodTap : widget.onRefillTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 碗里露出来的粮食
            Text(
              full ? widget.pet.species.food : '💨',
              style: TextStyle(fontSize: full ? 13 : 10),
            ),
            // 碗（正面写着余粮）
            Container(
              width: 52,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: full
                      ? const [Color(0xFFE8B87C), Color(0xFFB58149)]
                      : const [Color(0xFFD0D0D0), Color(0xFFA5A5A5)],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4), bottom: Radius.circular(14)),
                border: Border.all(color: const Color(0xFF8A5A31), width: 1.5),
              ),
              child: Text(
                full ? '×$n' : '空',
                key: const ValueKey('pet-food-count'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: full ? Colors.white : Colors.white70,
                ),
              ),
            ),
            Text(
              full ? '食盒' : '点我装粮',
              style: TextStyle(
                fontSize: 8.5,
                color: full ? Colors.black54 : Colors.deepOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 水碗：点一下就跑去喝水
  Widget _waterBowl(double roomW) {
    return Positioned(
      right: _waterCenterPx - 24,
      bottom: 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onWaterTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💧', style: TextStyle(fontSize: 12)),
            Container(
              width: 48,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF9BD8F2), Color(0xFF5FAFD1)],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4), bottom: Radius.circular(13)),
                border: Border.all(color: const Color(0xFF3E8FB0), width: 1.5),
              ),
              child: const Text(
                '水',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            const Text('喝水',
                style: TextStyle(fontSize: 8.5, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final store = widget.store;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: _h,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            children: [
              // 墙
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: room.wall,
                    ),
                  ),
                ),
              ),
              // 窗户
              Positioned(
                top: 14,
                right: 22,
                child: Container(
                  width: 58,
                  height: 44,
                  decoration: BoxDecoration(
                    color: room.wall.last.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                      child: Text(room.windowEmoji,
                          style: const TextStyle(fontSize: 15))),
                ),
              ),
              // 地板
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _floorH,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: room.floor,
                    ),
                  ),
                ),
              ),
              // 地毯
              Positioned(
                left: 22,
                right: 22,
                bottom: 12,
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius:
                        const BorderRadius.all(Radius.elliptical(180, 22)),
                  ),
                ),
              ),
              // 家具（可以拖动）
              for (final slot in room.slots) ...[
                if (store.giftPlacedAt(room.id, slot.type) != null)
                  _draggableItem(room, slot, w),
              ],
              // 宠物（它自己会在屋里走）
              Positioned.fill(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _PetActor(
                      pet: widget.pet,
                      size: _petSize,
                      roomWidth: w,
                      floorH: _floorH,
                      hungry: widget.hungry,
                      welcome: widget.welcome,
                      onTap: widget.onPetTap,
                      act: widget.act,
                      actToken: widget.actToken,
                      bowlX: _anchor(w, _bowlCenterPx + 4),
                      waterX: _anchor(w, w - _waterCenterPx - 4),
                      bedX: _anchor(w, _bedCenterPx(w)),
                      onBite: widget.onBite,
                      onSip: widget.onSip,
                    ),
                  ],
                ),
              ),
              // 食盒（画在宠物前面：看着就像它站在自己碗后面吃）
              _foodBowl(w),
              // 水碗（右边，点一下就去喝水）
              _waterBowl(w),
              // 欢迎的爱心
              for (var i = 0; i < 5; i++)
                AnimatedBuilder(
                  animation: widget.welcome,
                  builder: (context, _) {
                    final t = (widget.welcome.value - i * 0.08).clamp(0.0, 1.0);
                    return Positioned(
                      left: w * (0.34 + 0.08 * i),
                      bottom: 118 + t * 50,
                      child: Opacity(
                        opacity: t == 0 ? 0 : (1 - t).clamp(0.0, 1.0),
                        child: Text(
                          const ['❤️', '💛', '💙', '💗', '💚'][i],
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                  },
                ),
              // 提示：可以拖动
              Positioned(
                left: 0,
                right: 0,
                top: 6,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '按住家具拖动 · 点合影相框看照片',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _draggableItem(PetRoomDef room, RoomSlotDef slot, double roomW) {
    final gift = widget.store.giftPlacedAt(room.id, slot.type)!;
    final iw = slot.size * 1.15;
    final ih = slot.size * 1.35;
    final travelX = (roomW - iw).clamp(1.0, 9999.0);
    final travelY = (_PetRoomViewState._h - ih).clamp(1.0, 9999.0);
    final pos = _drag[slot.type] ??
        widget.store.itemPos(room, slot);

    return Positioned(
      left: pos.dx * travelX,
      top: pos.dy * travelY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: gift.id == 'de_photo'
            ? () => showPhotoCard(context, widget.pet)
            : null,
        onPanStart: (_) {
          setState(() => _drag[slot.type] = pos);
        },
        onPanUpdate: (d) {
          final cur = _drag[slot.type] ?? pos;
          setState(() {
            _drag[slot.type] = Offset(
              (cur.dx + d.delta.dx / travelX).clamp(0.0, 1.0),
              (cur.dy + d.delta.dy / travelY).clamp(0.0, 1.0),
            );
          });
        },
        onPanEnd: (_) {
          final p = _drag.remove(slot.type);
          if (p != null) {
            widget.store.moveItem(room, slot, p.dx, p.dy);
            widget.store.saveItems();
          }
          setState(() {});
        },
        child: SizedBox(
          width: iw,
          height: ih,
          child: Center(
            child: gift.id == 'de_photo'
                ? PhotoThumb(pet: widget.pet, size: slot.size * 1.05)
                : Text(gift.emoji, style: TextStyle(fontSize: slot.size)),
          ),
        ),
      ),
    );
  }
}

/// 宠物在屋里能干的事
enum _PetAct { idle, eat, drink, sleep, wake }

/// 房间里正在演的一小步（走路 / 咬一口 / 躺下……）
class _PetStep {
  final double dur;
  final void Function(double t)? apply;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;

  const _PetStep({
    required this.dur,
    this.apply,
    this.onStart,
    this.onEnd,
  });
}

/// 房间里真正的宠物：自己来回走、跑去吃饭、喝水、上床睡觉。
/// 不写字不说话，全靠动作 + 声音。
class _PetActor extends StatefulWidget {
  final Pet pet;
  final double size;
  final double roomWidth;
  final double floorH;
  final bool hungry;
  final Animation<double> welcome;
  final VoidCallback onTap;

  /// 娃按了哪个按钮（配合 [actToken] 触发一次）
  final _PetAct act;
  final int actToken;

  /// 三个落脚点（宠物左边的归一化位置）
  final double bowlX;
  final double waterX;
  final double bedX;

  /// 咬了一口（扣一份粮食）
  final VoidCallback onBite;

  /// 喝了一口水
  final VoidCallback onSip;

  const _PetActor({
    required this.pet,
    required this.size,
    required this.roomWidth,
    required this.floorH,
    required this.hungry,
    required this.welcome,
    required this.onTap,
    required this.act,
    required this.actToken,
    required this.bowlX,
    required this.waterX,
    required this.bedX,
    required this.onBite,
    required this.onSip,
  });

  @override
  State<_PetActor> createState() => _PetActorState();
}

class _PetActorState extends State<_PetActor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  double _lastV = 0;
  double _time = 0;

  double _x = 0.55; // 宠物左边的归一化位置
  bool _facingRight = false;
  double _walk = 0; // 走路相位（小爪一前一后）
  bool _moving = false;
  double _dip = 0; // 低头 0~1
  bool _eating = false;
  bool _drinking = false;
  bool _sleeping = false;
  bool _blink = false;
  double _blinkT = 0;

  List<_PetStep> _script = [];
  double _stepT = 0;
  bool _stepStarted = false;
  double _from = 0;

  bool get isSleeping => _sleeping;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_tick);
    if (widget.act != _PetAct.idle) _runAct(widget.act);
  }

  @override
  void didUpdateWidget(covariant _PetActor old) {
    super.didUpdateWidget(old);
    if (old.actToken != widget.actToken) _runAct(widget.act);
  }

  @override
  void dispose() {
    _clock.removeListener(_tick);
    _clock.dispose();
    super.dispose();
  }

  void _tick() {
    final v = _clock.value;
    var dt = v - _lastV;
    if (dt < 0) dt += 1.0;
    _lastV = v;
    _time += dt;
    _advance(dt);
    if (mounted) setState(() {});
  }

  void _advance(double dt) {
    // 偶尔眨一下眼
    _blinkT += dt;
    if (_blinkT > 2.8) {
      _blink = true;
      if (_blinkT > 2.95) {
        _blink = false;
        _blinkT = 0;
      }
    }

    if (_script.isNotEmpty) {
      final step = _script.first;
      if (!_stepStarted) {
        _stepStarted = true;
        step.onStart?.call();
      }
      _stepT += dt;
      final t = (_stepT / step.dur).clamp(0.0, 1.0);
      step.apply?.call(t);
      if (t >= 1) {
        step.onEnd?.call();
        _script.removeAt(0);
        _stepT = 0;
        _stepStarted = false;
        if (_script.isEmpty) _settle();
      }
      return;
    }
    if (_sleeping) return;
    _wander(dt);
  }

  /// 没事的时候在屋里慢慢走；食盒空了就溜达到食盒边上等
  void _wander(double dt) {
    final target = widget.hungry ? widget.bowlX + 0.02 : 0.42 + 0.26 * sin(_time * 0.32);
    final dx = target - _x;
    if (dx.abs() > 0.012) {
      _x += dx.sign * min(0.11 * dt, dx.abs());
      _facingRight = dx > 0;
      _moving = true;
      _walk += dt * 3.4;
    } else {
      _moving = false;
    }
  }

  void _settle() {
    _eating = false;
    _drinking = false;
    _moving = false;
    if (!_sleeping) _dip = 0;
  }

  void _runAct(_PetAct act) {
    _script = [];
    _stepT = 0;
    _stepStarted = false;
    switch (act) {
      case _PetAct.eat:
        _sleeping = false;
        _script = [
          _walkTo(widget.bowlX + 0.02, 1.15),
          const _PetStep(dur: 0.18),
          _chew(bite: true),
          _chew(),
          const _PetStep(dur: 0.16),
          _chew(),
        ];
      case _PetAct.drink:
        _sleeping = false;
        _script = [
          _walkTo(widget.waterX - 0.02, 1.3),
          const _PetStep(dur: 0.14),
          _sip(),
          _sip(),
          _sip(),
        ];
      case _PetAct.sleep:
        _script = [
          _walkTo(widget.bedX, 1.4),
          _lie(),
        ];
      case _PetAct.wake:
        _script = [_wake()];
      case _PetAct.idle:
        break;
    }
    setState(() {});
  }

  _PetStep _walkTo(double target, double dur) {
    return _PetStep(
      dur: dur,
      onStart: () {
        _from = _x;
        _moving = true;
      },
      apply: (t) {
        final e = Curves.easeInOut.transform(t);
        final nx = _from + (target - _from) * e;
        final d = nx - _x;
        _facingRight = target > _from;
        _walk += d.abs() * 26;
        _x = nx.clamp(0.0, 1.0);
      },
      onEnd: () => _moving = false,
    );
  }

  _PetStep _chew({bool bite = false}) {
    return _PetStep(
      dur: 0.36,
      onStart: () {
        _eating = true;
        SoundFx.chew();
        if (bite) widget.onBite();
      },
      apply: (t) => _dip = sin(t * pi) * 1.0,
      onEnd: () {
        _eating = false;
        _dip = 0;
      },
    );
  }

  _PetStep _sip() {
    return _PetStep(
      dur: 0.3,
      onStart: () {
        _drinking = true;
        SoundFx.lick();
        widget.onSip();
      },
      apply: (t) => _dip = sin(t * pi) * 0.85,
      onEnd: () {
        _drinking = false;
        _dip = 0;
      },
    );
  }

  _PetStep _lie() {
    return _PetStep(
      dur: 0.45,
      onStart: () {
        _sleeping = true;
        _dip = 0.22;
      },
      apply: (t) => _dip = 0.22 + sin(t * pi) * 0.05,
      onEnd: () => _dip = 0.22,
    );
  }

  _PetStep _wake() {
    return _PetStep(
      dur: 0.35,
      onStart: () => _sleeping = false,
      apply: (t) => _dip = 0.22 * (1 - t),
      onEnd: () => _dip = 0,
    );
  }

  double _lickAt(double v) {
    for (final s in _PetsHouseScreenState._lickBeats) {
      final p = (v - s) / 0.13;
      if (p > 0 && p < 1) return sin(p * pi);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_clock, widget.welcome]),
      builder: (context, _) {
        final travel =
            (widget.roomWidth - widget.size - 20).clamp(1.0, 9999.0);
        // 走路时身体一颠一颠，站着时轻轻呼吸
        final bob = _moving
            ? sin(_walk * 2 * pi).abs() * 2.4
            : sin(_time * 2.1) * 1.1;
        final lick = _lickAt(widget.welcome.value);
        final scaleY = _sleeping ? 0.66 : (1 + 0.05 * lick);
        return Positioned(
          left: _x * travel,
          bottom: widget.floorH -
              widget.size * (0.72 + PetFace.extraHeight) +
              bob +
              lick * 6 +
              (_sleeping ? -6 : 0),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Transform.scale(
              scaleX: _facingRight ? 1 : -1,
              scaleY: scaleY,
              alignment: Alignment.bottomCenter,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 睡着了：它身子底下有个软垫子（没摆床也不至于睡地板）
                  if (_sleeping)
                    Positioned(
                      bottom: -6,
                      left: widget.size * 0.04,
                      child: Container(
                        width: widget.size * 0.92,
                        height: widget.size * 0.24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE6C2),
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(
                                widget.size * 0.92, widget.size * 0.24),
                          ),
                          border: Border.all(
                              color: const Color(0xFFE0B072), width: 2),
                        ),
                      ),
                    ),
                  PetFace(
                    pet: widget.pet,
                    size: widget.size,
                    lick: lick,
                    hungry: widget.hungry,
                    pawPhase: _walk,
                    dip: _dip,
                    eating: _eating,
                    drinking: _drinking,
                    sleeping: _sleeping,
                    blink: _blink,
                  ),
                  // 吃饭时溅出来的小碎屑
                  if (_eating)
                    Positioned(
                      top: widget.size * (0.62 + 0.18 * _dip),
                      left: widget.size * 0.30,
                      child: _Crumbs(t: _time),
                    ),
                  // 睡觉：飘几个 Z
                  if (_sleeping)
                    Positioned(
                      top: widget.size * 0.02,
                      right: -10,
                      child: _Zzz(t: _time),
                    ),
                  // 饿了：头顶飘着它爱吃的东西（不写字）
                  if (widget.hungry && !_sleeping)
                    Positioned(
                      top: -widget.size * 0.10,
                      left: widget.size * 0.44,
                      child: _HungryIcon(food: widget.pet.species.food),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 吃饭时的小碎屑
class _Crumbs extends StatelessWidget {
  final double t;

  const _Crumbs({required this.t});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 18,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: 4.0 + i * 7 + sin(t * 9 + i) * 2,
              top: ((t * 26 + i * 6) % 14).toDouble(),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFB98A5B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 睡觉的 Z
class _Zzz extends StatelessWidget {
  final double t;

  const _Zzz({required this.t});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: 4.0 + i * 4,
              bottom: ((t * 22 + i * 12) % 32).toDouble(),
              child: Opacity(
                opacity: (1 - ((t * 22 + i * 12) % 32) / 32).clamp(0.15, 1.0),
                child: Text(
                  'z',
                  style: TextStyle(
                    fontSize: 9.0 + i * 3,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8D6E63),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 饿了的标志：它爱吃的东西飘在头顶（不写字）
class _HungryIcon extends StatefulWidget {
  final String food;

  const _HungryIcon({this.food = '🐟'});

  @override
  State<_HungryIcon> createState() => _HungryIconState();
}

class _HungryIconState extends State<_HungryIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.rotate(
        angle: (_c.value - 0.5) * 0.5,
        child: child,
      ),
      child: Container(
        key: const ValueKey('pet-hungry'),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(widget.food, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

class _EmptyHouse extends StatelessWidget {
  const _EmptyHouse();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🏠', style: TextStyle(fontSize: 72)),
            SizedBox(height: 14),
            Text('房子还空着',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              '回到岛上，门口有只北极熊幼仔在等你哦～',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
