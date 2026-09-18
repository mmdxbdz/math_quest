import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../content/curriculum.dart';
import '../widgets/bars.dart';
import 'lessons.dart';
import 'mistakes.dart';
import 'parent.dart';
import 'quiz.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProgressStore store = ProgressStore();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('数学闯关 · 二下',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Row(children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 2),
            Text(store.totalStars.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(width: 12),
          CoinsBadge(store.coins),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _todayCard(),
          const SizedBox(height: 6),
          for (final unit in units) _unitCard(unit),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _bottomButton(
                  icon: Icons.assignment_late,
                  label: '错题本 (' + store.mistakes.length.toString() + ')',
                  color: Colors.deepOrange.shade100,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MistakesScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bottomButton(
                  icon: Icons.family_restroom,
                  label: '家长面板',
                  color: Colors.blueGrey.shade100,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ParentScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _bottomButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayCard() {
    final hasCur = store.currentLesson.isNotEmpty;
    return Card(
      color: Colors.orange.shade300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (!hasCur) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ParentScreen()));
            return;
          }
          final weak = store.weakestLesson();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => QuizScreen(
              title: '今日任务',
              isToday: true,
              builder: () => buildTodayQuestions(store.mistakes, weak),
            ),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny, size: 34, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('今日任务',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(
                      hasCur
                          ? (store.todayDone
                              ? '已完成，真棒！可以再练一轮巩固'
                              : '围绕「' + lessonTitle(store.currentLesson) + '」闯 8 题')
                          : '点我先设置今天学到哪一课',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (store.todayDone)
                const Icon(Icons.check_circle, color: Colors.white),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unitCard(Unit unit) {
    final levelCount = unit.lessons.length * 3;
    var done = 0;
    for (final l in unit.lessons) {
      for (var s = 0; s < 3; s++) {
        if (store.stageStars(l.id, s) > 0) done++;
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => LessonsScreen(unit: unit))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(unit.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: levelCount == 0 ? 0 : done / levelCount,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(done.toString() + '/' + levelCount.toString(),
                  style: const TextStyle(color: Colors.grey)),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
