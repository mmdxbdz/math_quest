import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../content/curriculum.dart';
import '../widgets/bars.dart';
import '../widgets/numpad.dart';
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

  const QuizScreen({
    super.key,
    required this.title,
    required this.builder,
    this.levelKey,
    this.isToday = false,
    this.isMistakeDrill = false,
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
  final List<Question> wrongList = [];
  String input1 = '';
  String input2 = '';
  int activeSlot = 0;

  @override
  void initState() {
    super.initState();
    questions = widget.builder();
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
      idx = 0;
      hearts = 3;
      firstTry = 0;
      wrongCount = 0;
      wrongThis = false;
      showExplain = false;
      advancing = false;
      disabledOpts.clear();
      wrongList.clear();
      clearInputs();
    });
  }

  void onWrong(String given) {
    if (!wrongThis) {
      wrongThis = true;
      wrongCount++;
      wrongList.add(q);
      store.recordAnswer(q, false, given);
    }
    setState(() {
      hearts--;
      showExplain = true;
      disabledOpts.addAll(_wrongChoiceIdx);
      clearInputs();
    });
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
    }
  }

  Set<int> get _wrongChoiceIdx {
    // choice 答错后禁用的选项由点击处传入，这里返回空集占位
    return <int>{};
  }

  void onCorrect(String given) {
    store.recordAnswer(q, true, given);
    if (!wrongThis) firstTry++;
    if (widget.isMistakeDrill) store.resolveMistake(q.stem);
    setState(() {
      showExplain = false;
      advancing = true;
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (idx + 1 >= questions.length) {
        finish();
      } else {
        setState(() {
          idx++;
          wrongThis = false;
          showExplain = false;
          advancing = false;
          disabledOpts.clear();
          clearInputs();
        });
      }
    });
  }

  void finish() {
    int? stars;
    int coins = firstTry;
    bool todayBonus = false;
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
    store.addCoins(coins);
    final next = widget.levelKey != null ? buildNextQuiz(widget.levelKey!, widget) : null;
    final retry = QuizScreen(
      title: widget.title,
      builder: widget.builder,
      levelKey: widget.levelKey,
      isToday: widget.isToday,
      isMistakeDrill: widget.isMistakeDrill,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(
        title: widget.title,
        stars: stars,
        coins: coins,
        total: questions.length,
        wrongCount: wrongCount,
        wrongList: wrongList,
        todayBonus: todayBonus,
        isMistakeDrill: widget.isMistakeDrill,
        next: next,
        retry: retry,
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
    if (advancing) return;
    if (q.kind == AnswerKind.double) {
      if (input1.isNotEmpty && input2.isNotEmpty) {
        final ok = checkInput(input1, q.answer) && checkInput(input2, q.answer2);
        final given = input1 + ' , ' + input2;
        ok ? onCorrect(given) : onWrong(given);
      } else if (input1.isNotEmpty && activeSlot == 0) {
        setState(() => activeSlot = 1);
      }
      return;
    }
    if (input1.isEmpty) return;
    checkInput(input1, q.answer) ? onCorrect(input1) : onWrong(input1);
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('第 ' + (idx + 1).toString() + ' / ' + questions.length.toString() + ' 题',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    _questionCard(),
                    if (showExplain)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('💡 ' + q.explain,
                            style: const TextStyle(fontSize: 16, height: 1.4)),
                      ),
                    if (advancing)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('✓ 答对啦！', style: TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
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
                    if (advancing) return;
                    setState(() {
                      if (q.kind == AnswerKind.double && activeSlot == 1) {
                        if (input2.length < 4) input2 += d;
                      } else if (input1.length < 4) {
                        input1 += d;
                      }
                    });
                  },
                  onClear: () {
                    if (advancing) return;
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
    );
  }

  Widget _questionCard() {
    final stemLines = q.stem.split('\n');
    return Container(
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
                  child: Material(
                    color: disabledOpts.contains(i)
                        ? Colors.grey.shade300
                        : (advancing && q.options[i] == q.answer
                            ? Colors.green.shade200
                            : Colors.blue.shade50),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: (advancing || disabledOpts.contains(i))
                          ? null
                          : () {
                              if (q.options[i] == q.answer) {
                                onCorrect(q.options[i]);
                              } else {
                                setState(() => disabledOpts.add(i));
                                onWrong(q.options[i]);
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        child: Text(
                          q.options[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      case AnswerKind.compare:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final sym in ['＜', '＝', '＞'])
              Material(
                color: advancing && _norm(sym) == _norm(q.answer)
                    ? Colors.green.shade200
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: advancing
                      ? null
                      : () {
                          _norm(sym) == _norm(q.answer) ? onCorrect(sym) : onWrong(sym);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 26),
                    child: Text(sym, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        );
      case AnswerKind.input:
        return Column(
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
        );
      case AnswerKind.double:
        final labels = q.slotLabels.isNotEmpty ? q.slotLabels : ['第一个空', '第二个空'];
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _slotBox(labels[0], input1, activeSlot == 0, () => setState(() => activeSlot = 0)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('……', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            _slotBox(labels[1], input2, activeSlot == 1, () => setState(() => activeSlot = 1)),
          ],
        );
    }
  }

  Widget _slotBox(String label, String val, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
