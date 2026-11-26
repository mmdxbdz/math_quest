import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../app_info.dart';
import '../content/curriculum.dart';
import '../pets.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/island_map.dart';
import '../widgets/pet_visit.dart';
import '../speech.dart';
import 'mistakes.dart';
import 'parent.dart';
import 'pets_house.dart';
import 'quiz.dart';
import 'challenge.dart';

/// 首页：一座长长的立体海岛，一关一级台阶，往上就是更高的关。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ProgressStore store = ProgressStore();
  Timer? _greetTimer;

  /// 宠物自己跳出来舔一口（不说话，纯动作）
  bool _visiting = false;

  /// 第一次进游戏：北极熊幼仔自己跑到屏幕上等她
  bool _intro = false;

  /// 刚到家、还没演动画的新朋友（存 speciesId）
  final List<String> _arrivalQueue = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Speech.warmup();
    store.addListener(_onStoreChanged);
    // 进门前就已经到家的新朋友，先演给娃看
    if (store.newArrivals.isNotEmpty) {
      _arrivalQueue.addAll(store.newArrivals);
      store.clearNewArrivals();
    }
    _greetTimer = Timer(const Duration(milliseconds: 700), _onEnter);
  }

  void _onEnter() {
    if (!mounted || _intro || _visiting || _arrivalQueue.isNotEmpty) return;
    if (!store.hasPet || store.replayIntro) {
      setState(() => _intro = true);
    } else {
      setState(() => _visiting = true);
    }
  }

  /// 家长页点了「再看一遍动画」/「清空宠物」/ 通了新关有新朋友，都从这里进场
  void _onStoreChanged() {
    if (!mounted) return;
    if (store.newArrivals.isNotEmpty && !_intro) {
      setState(() {
        _arrivalQueue.addAll(store.newArrivals);
        store.clearNewArrivals();
      });
      return;
    }
    if (_intro || _visiting || _arrivalQueue.isNotEmpty) return;
    if (store.replayIntro || !store.hasPet) {
      setState(() => _intro = true);
    }
  }

  /// 新朋友动画演完：可以留下来陪她，也可以去它的家看看
  void _closeArrival({bool goHouse = false}) {
    if (_arrivalQueue.isEmpty) return;
    final species = _arrivalQueue.removeAt(0);
    if (goHouse) {
      final pets = store.pets;
      final i = pets.indexWhere((p) => p.speciesId == species);
      if (i >= 0) store.setCompanion(i);
      _openPets();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 手机切回来：它再跳出来舔一口
    if (state == AppLifecycleState.resumed) _onEnter();
  }

  /// 抱抱它：正式收养这只北极熊幼仔（已经在养的就只是再看一遍）
  void _adoptIt() {
    if (!store.hasPet) store.adoptStarterPet();
    store.setReplayIntro(false);
    setState(() {
      _intro = false;
      _visiting = true;
    });
    Speech.cheer();
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    WidgetsBinding.instance.removeObserver(this);
    _greetTimer?.cancel();
    super.dispose();
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _startLevel(MapLevel level) {
    if (!level.unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('先过前一关，这一关就亮啦～'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    final rng = Random();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizScreen(
        title: level.lesson.title + ' · ' + kStageNames[level.stage],
        levelKey: level.key,
        builder: () =>
            level.lesson.gen(rng, level.stage).take(store.qsPerLevel).toList(),
      ),
    ));
  }

  void _openPets() => _push(const PetsHouseScreen());

  void _startToday() {
    if (store.currentLesson.isEmpty) {
      _push(const ParentScreen());
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizScreen(
        title: '今日任务',
        isToday: true,
        builder: () => buildTodayQuestions(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF9EDBF7),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(
              child: IslandMap(
                store: store,
                onStartLevel: _startLevel,
                onPetHouseTap: _openPets,
                bottomInset: 96,
              ),
            ),
            // 顶部一层淡淡的暗角，保证标题在任何背景上都看得清
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 130,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(bottom: false, child: _topBar()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _dock()),
            ),
            // 宠物自己跳出来舔一口（点它就去它的家）
            if (_visiting && store.companion != null)
              Positioned.fill(
                child: PetVisitOverlay(
                  pet: store.companion!,
                  hungry: store.companionHungry,
                  onTap: _openPets,
                  onDone: () {
                    if (mounted) setState(() => _visiting = false);
                  },
                ),
              ),
            // 第一次进游戏：门口的小北极熊
            if (_intro)
              Positioned.fill(
                child: _IntroOverlay(
                  pet: store.companion ?? _IntroOverlay.starterBear,
                  onAdopt: _adoptIt,
                ),
              ),
            // 新朋友跑到家里来了
            if (_arrivalQueue.isNotEmpty && !_intro)
              Positioned.fill(
                child: _ArrivalOverlay(
                  speciesId: _arrivalQueue.first,
                  onStay: () => _closeArrival(),
                  onGoHouse: () => _closeArrival(goHouse: true),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppInfo.name,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 1)),
                  ],
                ),
              ),
              const Spacer(),
              _iconButton('🧠', () => _push(const ChallengeScreen())),
              const SizedBox(width: 6),
              _statPill('⭐', store.totalStars),
              const SizedBox(width: 6),
              _statPill('🪙', store.coins),
            ],
          ),
          if (store.pendingRewardCount > 0) ...[
            const SizedBox(height: 6),
            _rewardPill(),
          ],
        ],
      ),
    );
  }

  Widget _iconButton(String emoji, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _statPill(String emoji, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(value.toString(),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: QuietBook.ink)),
        ],
      ),
    );
  }

  Widget _rewardPill() {
    return Material(
      color: Colors.orange.shade100.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _push(const ParentScreen()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '💰 有 ' + store.pendingRewardCount.toString() + ' 件事待兑现',
            style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
          ),
        ),
      ),
    );
  }

  Widget _dock() {
    final todayDone = store.todayDone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _dockItem(
                '☀️',
                todayDone ? '今日完成' : '今日任务',
                highlight: !todayDone,
                badge: todayDone ? 0 : store.dueMistakeCount,
                onTap: _startToday,
              ),
            ),
            Expanded(
              child: _dockItem(
                '🐾',
                store.companion?.name ?? '宠物',
                icon: store.companion == null
                    ? null
                    : PetAvatar(
                        species: store.companion!.species,
                        stage: store.companion!.stage,
                        hatIndex: store.companion!.hatIndex,
                        size: 24,
                      ),
                highlight: store.companion != null,
                badge: store.companionHungry ? 1 : 0,
                onTap: _openPets,
              ),
            ),
            Expanded(
              child: _dockItem('📝', '错题本',
                  badge: store.mistakes.length,
                  onTap: () => _push(const MistakesScreen())),
            ),
            Expanded(
              child: _dockItem('👪', '家长',
                  onTap: () => _push(const ParentScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dockItem(
    String emoji,
    String label, {
    VoidCallback? onTap,
    bool highlight = false,
    int badge = 0,
    Widget? icon,
  }) {
    return Material(
      color: highlight ? Colors.orange.shade100 : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (icon != null)
                    SizedBox(width: 24, height: 24, child: Center(child: icon))
                  else
                    Text(emoji, style: const TextStyle(fontSize: 19)),
                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge.toString(),
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                    color: highlight ? Colors.deepOrange : QuietBook.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 第一次进游戏：小北极熊自己跑到屏幕上，凑过来舔一口
class _IntroOverlay extends StatelessWidget {
  final Pet pet;
  final VoidCallback onAdopt;

  const _IntroOverlay({required this.pet, required this.onAdopt});

  static const Pet starterBear = Pet(
      speciesId: kStarterPetSpecies, name: kStarterPetName, feeds: 0, slot: 0);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 底下一层薄薄的暗色，挡住地图的点击
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(color: Colors.black.withValues(alpha: 0.22)),
          ),
        ),
        // 小熊一直跳出来舔
        Positioned.fill(
          child: PetVisitOverlay(
            pet: pet,
            loop: true,
            sizeFactor: 0.62,
            bottomInset: 210,
          ),
        ),
        // 抱抱它
        Positioned(
          left: 24,
          right: 24,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: onAdopt,
                    child: const Text('❤️ 抱抱它',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '抱住它，它以后就住在这里啦',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 通了关卡，新朋友跑到家里来了
class _ArrivalOverlay extends StatelessWidget {
  final String speciesId;
  final VoidCallback onStay;
  final VoidCallback onGoHouse;

  const _ArrivalOverlay({
    required this.speciesId,
    required this.onStay,
    required this.onGoHouse,
  });

  @override
  Widget build(BuildContext context) {
    final sp = petSpeciesOf(speciesId);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),
        ),
        Positioned.fill(
          child: PetVisitOverlay(
            pet: Pet(speciesId: speciesId, name: sp.defaultName, feeds: 0, slot: 0),
            loop: true,
            sizeFactor: 0.58,
            bottomInset: 230,
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '🎉 ${sp.title}${sp.defaultName} 来啦！',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '恭喜你又领到一位新朋友',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: onGoHouse,
                    child: const Text('❤️ 领它回家',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onStay,
                  child: const Text('等会儿再领',
                      style:
                          TextStyle(fontSize: 13, color: Colors.white70)),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

