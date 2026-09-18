import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import 'quiz.dart';
import 'home.dart';

class ResultScreen extends StatefulWidget {
  final String title;
  final int? stars;
  final int coins;
  final int total;
  final int wrongCount;
  final List<Question> wrongList;
  final bool todayBonus;
  final bool isMistakeDrill;
  final NextQuizInfo? next;
  final QuizScreen retry;

  const ResultScreen({
    super.key,
    required this.title,
    required this.stars,
    required this.coins,
    required this.total,
    required this.wrongCount,
    required this.wrongList,
    required this.todayBonus,
    required this.isMistakeDrill,
    required this.next,
    required this.retry,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int shownStars = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    final target = widget.stars ?? 0;
    for (var i = 1; i <= target; i++) {
      timer = Timer(Duration(milliseconds: 400 * i), () {
        if (mounted) setState(() => shownStars = i);
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.total - widget.wrongCount;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3D6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.isMistakeDrill ? '错题重练完成！🎉' : '闯关成功！🎉',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (widget.stars != null)
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
                  ),
                if (widget.stars == null)
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 72),
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
                const SizedBox(height: 18),
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
    );
  }
}
