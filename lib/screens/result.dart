import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../content/rewards.dart';
import '../pets.dart';
import '../soundfx.dart';
import '../store.dart';
import '../widgets/bubbles.dart';
import '../widgets/fireworks.dart';
import 'quiz.dart';
import 'home.dart';

class ResultScreen extends StatefulWidget {
  final String title;
  final int? stars;
  final int coins;
  final int total;
  final int wrongCount;
  final int firstTryMiss; // 本轮第一遍没答对的题数
  final RewardRule? rewardRule; // 本轮奖惩判定
  final List<Question> wrongList;
  final bool todayBonus;
  final bool isMistakeDrill;

  /// 思维挑战模式
  final bool isChallenge;
  final String? challengeBadge; // 'gold' | 'silver' | null

  final NextQuizInfo? next;
  final QuizScreen retry;

  /// 这一轮有没有喂宠物，以及它是不是长大了一阶
  final bool petFed;
  final bool petGrew;
  final PetGift? gift;

  const ResultScreen({
    super.key,
    required this.title,
    required this.stars,
    required this.coins,
    required this.total,
    required this.wrongCount,
    this.firstTryMiss = 0,
    this.rewardRule,
    required this.wrongList,
    required this.todayBonus,
    required this.isMistakeDrill,
    this.isChallenge = false,
    this.challengeBadge,
    required this.next,
    required this.retry,
    this.petFed = false,
    this.petGrew = false,
    this.gift,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int shownStars = 0;
  Timer? timer;
  Timer? chewTimer;

  @override
  void initState() {
    super.initState();
    final target = widget.stars ?? 0;
    for (var i = 1; i <= target; i++) {
      timer = Timer(Duration(milliseconds: 400 * i), () {
        if (mounted) setState(() => shownStars = i);
      });
    }
    // 食盒添了粮食：晚 0.6 秒"叮"一下（不再提前替它咀嚼，喂饭交给娃自己）
    if (widget.petFed) {
      chewTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) SoundFx.chime();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    chewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.total - widget.wrongCount;
    // 烟花：成功才放；全对更盛大
    final win = widget.stars != null ||
        (widget.isChallenge && widget.challengeBadge != null);
    final perfect = widget.stars == 3 || widget.challengeBadge == 'gold';
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3D6),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.isChallenge
                      ? '挑战完成！🎉'
                      : (widget.isMistakeDrill ? '错题重练完成！🎉' : '闯关成功！🎉'),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (widget.isChallenge) ...[
                  Icon(
                    widget.challengeBadge == 'gold'
                        ? Icons.military_tech
                        : (widget.challengeBadge == 'silver'
                            ? Icons.emoji_events
                            : Icons.sentiment_dissatisfied),
                    color: widget.challengeBadge == 'gold'
                        ? Colors.amber
                        : (widget.challengeBadge == 'silver'
                            ? Colors.blueGrey
                            : Colors.grey),
                    size: 72,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.challengeBadge == 'gold'
                        ? '🏅 金牌徽章！全对！'
                        : (widget.challengeBadge == 'silver'
                            ? '🥈 银牌徽章！只错 1 题'
                            : '差一点！错 2 题以上拿不到徽章，再试一次'),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: widget.challengeBadge == 'gold'
                            ? Colors.deepOrange
                            : (widget.challengeBadge == 'silver'
                                ? Colors.blueGrey
                                : Colors.grey)),
                  ),
                ] else if (widget.stars != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [0, 1, 2]
                        .map((i) => AnimatedScale(
                              scale: i < shownStars ? 1.0 : 0.4,
                              duration: const Duration(milliseconds: 250),
                              child: Icon(
                                i < (widget.stars ?? 0) ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 64,
                              ),
                            ))
                        .toList(),
                  )
                else
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 72),
                if (widget.stars != null ||
                    (widget.isChallenge && widget.challengeBadge != null)) ...[
                  const SizedBox(height: 8),
                  const PartyRow(),
                ],
                const SizedBox(height: 16),
                Text('答对 ' + correct.toString() + ' / ' + widget.total.toString() + ' 题',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.orange, size: 26),
                    const SizedBox(width: 6),
                    Text('+' + widget.coins.toString() + ' 金币',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  ],
                ),
                if (widget.todayBonus)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('今日任务完成，奖励 10 金币！', style: TextStyle(color: Colors.deepOrange)),
                  ),
                if (widget.petFed) ...[
                  const SizedBox(height: 14),
                  _petCard(),
                ],
                if (widget.gift != null) ...[
                  const SizedBox(height: 12),
                  _giftCard(widget.gift!),
                ],
                const SizedBox(height: 18),
                if (widget.rewardRule != null &&
                    widget.rewardRule!.amount > 0 &&
                    !widget.isChallenge &&
                    !widget.isMistakeDrill) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.rewardRule!.amount >= 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      border: Border.all(
                        color: widget.rewardRule!.amount >= 0
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.rewardRule!.amount >= 0
                              ? Icons.card_giftcard
                              : Icons.warning_amber,
                          color: widget.rewardRule!.amount >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.rewardRule!.amount > 0
                                ? '🎁 规则「' + widget.rewardRule!.name +
                                    '」：应奖励 ' + widget.rewardRule!.amount.toString() +
                                    '！记得兑现哦～'
                                : (widget.rewardRule!.amount < 0
                                    ? '⚠️ 规则「' + widget.rewardRule!.name +
                                        '」：应罚 ' +
                                        (-widget.rewardRule!.amount).toString() +
                                        '，家长记得实施～'
                                    : '🤝 ' + widget.rewardRule!.desc),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.firstTryMiss > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '👀 本轮有 ' + widget.firstTryMiss.toString() +
                          ' 道题不是一次答对，已记录，之后会自动复习',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.wrongList.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📝 本轮错题', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        for (final wq in widget.wrongList.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '· ' + wq.stem.split('\n').last +
                                  (wq.kind == AnswerKind.double
                                      ? '　答案：' + wq.answer + '……' + wq.answer2
                                      : '　答案：' + wq.answer),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        if (widget.wrongList.length > 5)
                          Text('…… 还有 ' + (widget.wrongList.length - 5).toString() + ' 道已存入错题本',
                              style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      ),
                      child: const Text('返回地图'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => widget.retry),
                      ),
                      child: const Text('再来一次'),
                    ),
                  ],
                ),
                if (widget.next != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => widget.next!.quiz),
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: Text('下一关：' + widget.next!.title),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
        if (win)
          Positioned.fill(
            child: IgnorePointer(
              child: Fireworks(
                waves: perfect ? 12 : 8,
                intensity: perfect ? 6 : 3,
                gap: Duration(milliseconds: perfect ? 400 : 550),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 闯关奖励卡片：给宠物的食盒添了一份粮食（喂饭要娃自己去喂）
  Widget _petCard() {
    final store = ProgressStore();
    final pet = store.companion;
    if (pet == null) return const SizedBox.shrink();
    final food = store.foodLeft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.12),
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
            size: 66,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.petGrew
                      ? '🍚 食盒里添了一份粮食'
                      : '🍚 食盒已经装满啦',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  '食盒里还有 ' +
                      food.toString() +
                      ' 份 · 去宠物住所点「喂它」，' +
                      pet.name +
                      '就跑过去吃啦',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pet.growProgress,
                    minHeight: 9,
                    backgroundColor: Colors.orange.shade50,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 闯关小礼品：给宠物家添置的家具
  Widget _giftCard(PetGift gift) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF7FF), Color(0xFFE6F3FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.lightBlue.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(gift.emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎁 闯关小礼品',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlue)),
                const SizedBox(height: 2),
                Text(
                  '得到一个' + gift.name + '！',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '已经摆进宠物的小家，也可以去宠物住所重新布置',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


