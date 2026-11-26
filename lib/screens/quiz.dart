import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../pets.dart';
import '../store.dart';
import '../content/curriculum.dart';
import '../content/rewards.dart';
import '../widgets/bars.dart';
import '../widgets/numpad.dart';
import '../widgets/bubbles.dart';
import '../widgets/fireworks.dart';
import '../speech.dart';
import 'result.dart';

String _norm(String s) => s
    .trim()
    .replaceAll('＝', '=')
    .replaceAll('＞', '>')
    .replaceAll('＜', '<');

class NextQuizInfo {
  final String title;
  final QuizScreen quiz;
  NextQuizInfo(this.title, this.quiz);
}

NextQuizInfo? buildNextQuiz(String levelKey, QuizScreen current) {
  final i = orderedLevelKeys.indexOf(levelKey);
  if (i < 0 || i + 1 >= orderedLevelKeys.length) return null;
  final nk = orderedLevelKeys[i + 1];
  final parts = nk.split(':s');
  final lessonId = parts[0];
  final stage = int.parse(parts[1]);
  Lesson lesson;
  try {
    lesson = allLessons.firstWhere((l) => l.id == lessonId);
  } catch (_) {
    return null;
  }
  return NextQuizInfo(
    lesson.title + ' · 第' + (stage + 1).toString() + '关',
    QuizScreen(
      title: lesson.title,
      levelKey: nk,
      builder: () {
        final rr = Random();
        return lesson.gen(rr, stage).take(ProgressStore().qsPerLevel).toList();
      },
    ),
  );
}

class QuizScreen extends StatefulWidget {
  final String title;
  final List<Question> Function() builder;
  final String? levelKey;
  final bool isToday;
  final bool isMistakeDrill;

  /// 思维挑战模式：全对金徽章、错 1 题银徽章
  final bool isChallenge;
  final String? challengeKey;

  const QuizScreen({
    super.key,
    required this.title,
    required this.builder,
    this.levelKey,
    this.isToday = false,
    this.isMistakeDrill = false,
    this.isChallenge = false,
    this.challengeKey,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final ProgressStore store = ProgressStore();
  late List<Question> questions;
  int idx = 0;
  int hearts = 3;
  int firstTry = 0;
  int wrongCount = 0;
  bool wrongThis = false;
  bool showExplain = false;
  bool advancing = false;
  final Set<int> disabledOpts = {};

  /// 第一遍答错的题（跳过攒到这里，主循环结束后重做一遍）
  final List<Question> pendingReview = [];
  bool inReview = false;
  int firstTryMiss = 0; // 本轮第一遍没答对的题数
  int reviewWrong = 0; // 复习阶段还答错的题数
  int reviewCount = 0; // 复习题总数
  int totalQuestions = 0; // 主循环题数

  /// 点题气泡：-1 无；>=0 是选项/符号 index；-99 是输入区
  int _bubbleAt = -1;
  bool _bubbleOk = false;
  final List<Question> wrongList = [];
  String input1 = '';
  String input2 = '';
  int activeSlot = 0;

  @override
  void initState() {
    super.initState();
    questions = widget.builder();
    totalQuestions = questions.length;
  }

  Question get q => questions[idx];

  void clearInputs() {
    input1 = '';
    input2 = '';
    activeSlot = 0;
  }

  void restart() {
    setState(() {
      questions = widget.builder();
      totalQuestions = questions.length;
      idx = 0;
      hearts = 3;
      firstTry = 0;
      wrongCount = 0;
      wrongThis = false;
      showExplain = false;
      advancing = false;
      disabledOpts.clear();
      wrongList.clear();
      pendingReview.clear();
      inReview = false;
      firstTryMiss = 0;
      reviewWrong = 0;
      reviewCount = 0;
      _bubbleAt = -1;
      clearInputs();
    });
  }

  void onWrong(String given) {
    if (!wrongThis) {
      wrongThis = true;
      wrongCount++;
      if (!wrongList.any((e) => e.stem == q.stem)) wrongList.add(q);
      store.recordAnswer(q, false, given, firstTry: !inReview);
      if (!inReview) {
        // 第一次答错：跳过，攒到轮末复习题里（不允许蒙）
        firstTryMiss++;
        if (!pendingReview.any((e) => e.stem == q.stem)) pendingReview.add(q);
      } else {
        reviewWrong++;
      }
    }
    setState(() {
      hearts--;
      showExplain = true;
      disabledOpts.addAll(_wrongChoiceIdx);
      clearInputs();
    });
    Speech.encourage();
    if (hearts <= 0) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('闯关失败 💪'),
          content: const Text('别灰心！看看讲解，再试一次吧。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('回去练习'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                restart();
              },
              child: const Text('再试一次'),
            ),
          ],
        ),
      );
    } else {
      // 看讲解后自动进入下一题（第一遍错的题攒到复习阶段）
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        advance();
      });
    }
  }

  Set<int> get _wrongChoiceIdx {
    // choice 答错后禁用的选项由点击处传入，这里返回空集占位
    return <int>{};
  }

  void onCorrect(String given) {
    store.recordAnswer(q, true, given, firstTry: !inReview);
    if (!wrongThis) firstTry++;
    // 注意：recordAnswer 已处理错题复习（答对升阶段，4 轮后移出）
    setState(() {
      showExplain = false;
      advancing = true;
    });
    Speech.cheer();
    // 答对停留 900ms，让烟花和泡泡看得清楚
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      advance();
    });
  }

  /// 前进：主循环走完 → 进入复习阶段；复习走完 → 结算
  void advance() {
    if (idx + 1 >= questions.length) {
      if (!inReview && pendingReview.isNotEmpty) {
        reviewCount = pendingReview.length;
        setState(() {
          inReview = true;
          questions = List.of(pendingReview);
          pendingReview.clear();
          idx = 0;
          wrongThis = false;
          showExplain = false;
          advancing = false;
          disabledOpts.clear();
          _bubbleAt = -1;
          clearInputs();
        });
        return;
      }
      finish();
      return;
    }
    setState(() {
      idx++;
      wrongThis = false;
      showExplain = false;
      advancing = false;
      disabledOpts.clear();
      _bubbleAt = -1;
      clearInputs();
    });
  }

  void finish() {
    int? stars;
    int coins = firstTry;
    bool todayBonus = false;
    String? challengeBadge;
    RewardRule? rewardRule;
    if (widget.isChallenge) {
      // 思维挑战：全对金徽章、错 1 题银徽章、错 2 题以上重试
      if (wrongCount == 0) {
        challengeBadge = 'gold';
        coins += 20;
      } else if (wrongCount <= 1) {
        challengeBadge = 'silver';
        coins += 10;
      }
      if (challengeBadge != null && widget.challengeKey != null) {
        store.markChallengeDone(widget.challengeKey!, challengeBadge);
      }
    } else {
      if (widget.levelKey != null) {
        stars = wrongCount == 0 ? 3 : (wrongCount == 1 ? 2 : 1);
        if (stars == 3) coins += 5;
        store.finishLevel(widget.levelKey!, stars);
      }
      if (widget.isToday && !store.todayDone) {
        store.markTodayDone(10);
        coins += 10;
        todayBonus = true;
      }
      // 奖惩判定：正常闯关（不含思维挑战/错题重练）
      if (!widget.isChallenge && !widget.isMistakeDrill) {
        final totalAnswers = totalQuestions + reviewCount;
        if (totalAnswers > 0) {
          final score = (totalAnswers - firstTryMiss - reviewWrong) / totalAnswers;
          rewardRule = rewardRuleFor(score);
          if (rewardRule.amount != 0) {
            final dn = DateTime.now();
            final y = dn.year.toString();
            final mo = dn.month.toString().padLeft(2, '0');
            final d = dn.day.toString().padLeft(2, '0');
            store.addReward(RewardRecord(
              lesson: widget.title,
              dateKey: y + '-' + mo + '-' + d,
              score: score,
              amount: rewardRule.amount,
              rule: rewardRule.name,
            ));
          }
        }
      }
    }
    // 闯关奖励：往食盒里添一份粮食（回宠物住所要娃亲手喂它，不再静默喂掉）
    final hadPet = store.companion != null;
    final foodAdded = hadPet && store.foodLeft < kFoodBowlCap;
    if (hadPet) store.addFood(1);
    // 闯关小礼品：掉一件宠物家的家具（收齐了就换成金币）
    final PetGift? gift = hadPet ? store.grantRandomGift() : null;

    store.addCoins(coins);
    final next = widget.levelKey != null ? buildNextQuiz(widget.levelKey!, widget) : null;
    final retry = QuizScreen(
      title: widget.title,
      builder: widget.builder,
      levelKey: widget.levelKey,
      isToday: widget.isToday,
      isMistakeDrill: widget.isMistakeDrill,
      isChallenge: widget.isChallenge,
      challengeKey: widget.challengeKey,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(
        title: widget.title,
        stars: stars,
        coins: coins,
        total: questions.length,
        wrongCount: wrongCount,
        firstTryMiss: firstTryMiss,
        rewardRule: rewardRule,
        wrongList: wrongList,
        todayBonus: todayBonus,
        isMistakeDrill: widget.isMistakeDrill,
        isChallenge: widget.isChallenge,
        challengeBadge: challengeBadge,
        next: next,
        retry: retry,
        petFed: hadPet,
        petGrew: foodAdded,
        gift: gift,
      ),
    ));
  }

  bool checkInput(String val, String ans) {
    final a = int.tryParse(_norm(val));
    final b = int.tryParse(_norm(ans));
    if (a != null && b != null) return a == b;
    return _norm(val) == _norm(ans);
  }

  void submitInput() {
    if (advancing || showExplain) return;
    if (q.kind == AnswerKind.double) {
      if (input1.isNotEmpty && input2.isNotEmpty) {
        final ok = checkInput(input1, q.answer) && checkInput(input2, q.answer2);
        final given = input1 + ' , ' + input2;
        setState(() {
          _bubbleAt = -99;
          _bubbleOk = ok;
        });
        ok ? onCorrect(given) : onWrong(given);
      } else if (input1.isNotEmpty && activeSlot == 0) {
        setState(() => activeSlot = 1);
      }
      return;
    }
    if (input1.isEmpty) return;
    final ok = checkInput(input1, q.answer);
    setState(() {
      _bubbleAt = -99;
      _bubbleOk = ok;
    });
    ok ? onCorrect(input1) : onWrong(input1);
  }

  @override
  Widget build(BuildContext context) {
    final isNumKind = q.kind == AnswerKind.input || q.kind == AnswerKind.double;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('要退出吗？'),
                  content: const Text('退出后本关进度不会保存哦。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('继续答题')),
                    FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        },
                        child: const Text('退出')),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            HeartsBar(hearts < 0 ? 0 : hearts),
          ],
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    inReview
                        ? '🔁 复习 ' + (idx + 1).toString() + ' / ' + questions.length.toString() + ' 题'
                        : '第 ' + (idx + 1).toString() + ' / ' + questions.length.toString() + ' 题',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: questions.isEmpty ? 0 : (idx + (advancing ? 1 : 0)) / questions.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _questionCard(
                          key: ValueKey('q' + idx.toString() + inReview.toString())),
                    ),
                    if (showExplain)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('💡 ' + q.explain,
                                style: const TextStyle(fontSize: 16, height: 1.4)),
                            if (!inReview)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text('这道题先跳过啦，等一下会再考你一次，不许蒙哦～',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.deepOrange)),
                              ),
                          ],
                        ),
                      ),
                    if (advancing)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: AnswerPop(ok: true, text: '答对啦！'),
                      ),
                  ],
                ),
              ),
            ),
            if (isNumKind)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: NumPad(
                  onDigit: (d) {
                    if (advancing || showExplain) return;
                    setState(() {
                      if (q.kind == AnswerKind.double && activeSlot == 1) {
                        if (input2.length < 4) input2 += d;
                      } else if (input1.length < 4) {
                        input1 += d;
                      }
                    });
                  },
                  onClear: () {
                    if (advancing || showExplain) return;
                    setState(() {
                      if (q.kind == AnswerKind.double && activeSlot == 1 && input2.isNotEmpty) {
                        input2 = input2.substring(0, input2.length - 1);
                      } else if (input1.isNotEmpty) {
                        input1 = input1.substring(0, input1.length - 1);
                      }
                    });
                  },
                  onOk: submitInput,
                  okEnabled: q.kind == AnswerKind.double
                      ? (input1.isNotEmpty && input2.isNotEmpty)
                      : input1.isNotEmpty,
                ),
              ),
            ],
          ),
        ),
        if (advancing)
          const Positioned.fill(
            child: IgnorePointer(
              child: Fireworks(
                waves: 2,
                intensity: 4,
                gap: Duration(milliseconds: 350),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard({Key? key}) {
    final stemLines = q.stem.split('\n');
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...stemLines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, height: 1.5, fontWeight: FontWeight.w600),
                ),
              )),
          const SizedBox(height: 14),
          _answerArea(),
        ],
      ),
    );
  }

  Widget _answerArea() {
    switch (q.kind) {
      case AnswerKind.choice:
        return Column(
          children: [
            for (var i = 0; i < q.options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // 用普通子节点给 Stack 提供确定高度（避免滚动容器里无界崩溃）
                      SizedBox(
                        width: double.infinity,
                        child: Material(
                          color: disabledOpts.contains(i)
                              ? Colors.grey.shade300
                              : (advancing && q.options[i] == q.answer
                                  ? Colors.green.shade200
                                  : Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: (advancing ||
                                    showExplain ||
                                    disabledOpts.contains(i))
                                ? null
                                : () {
                                    final ok = q.options[i] == q.answer;
                                    setState(() {
                                      _bubbleAt = i;
                                      _bubbleOk = ok;
                                      disabledOpts.add(i);
                                    });
                                    ok ? onCorrect(q.options[i]) : onWrong(q.options[i]);
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 10),
                              child: Text(
                                q.options[i],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_bubbleAt == i)
                        Positioned(
                          right: 2,
                          top: -22,
                          child: TapBubble(ok: _bubbleOk),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case AnswerKind.compare:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < ['＜', '＝', '＞'].length; i++)
              Stack(
                children: [
                  Material(
                    color: advancing &&
                            _norm(['＜', '＝', '＞'][i]) == _norm(q.answer)
                        ? Colors.green.shade200
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: (advancing || showExplain)
                          ? null
                          : () {
                              final sym = ['＜', '＝', '＞'][i];
                              final ok = _norm(sym) == _norm(q.answer);
                              setState(() {
                                _bubbleAt = i;
                                _bubbleOk = ok;
                              });
                              ok ? onCorrect(sym) : onWrong(sym);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 26),
                        child: Text(['＜', '＝', '＞'][i],
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  if (_bubbleAt == i)
                    Positioned(
                      top: -22,
                      child: TapBubble(ok: _bubbleOk),
                    ),
                ],
              ),
          ],
        );
      case AnswerKind.input:
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              children: [
                Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey, width: 2),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Text(
                    input1.isEmpty ? '？' : input1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (_bubbleAt == -99)
              Positioned(
                top: -24,
                child: TapBubble(ok: _bubbleOk),
              ),
          ],
        );
      case AnswerKind.double:
        final labels = q.slotLabels.isNotEmpty ? q.slotLabels : ['第一个空', '第二个空'];
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _slotBox(labels[0], input1, activeSlot == 0, () => setState(() => activeSlot = 0)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('……', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                _slotBox(labels[1], input2, activeSlot == 1, () => setState(() => activeSlot = 1)),
              ],
            ),
            if (_bubbleAt == -99)
              Positioned(
                top: -24,
                child: TapBubble(ok: _bubbleOk),
              ),
          ],
        );
    }
  }

  Widget _slotBox(String label, String val, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: showExplain ? null : onTap,
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
          const SizedBox(height: 4),
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: active ? Colors.orange : Colors.blueGrey, width: active ? 3 : 2),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Text(
              val.isEmpty ? '？' : val,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
