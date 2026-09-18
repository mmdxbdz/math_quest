import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../content/curriculum.dart';
import '../widgets/bars.dart';
import 'quiz.dart';

class LessonsScreen extends StatelessWidget {
  final Unit unit;
  const LessonsScreen({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore();
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(title: Text(unit.emoji + ' ' + unit.title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final lesson in unit.lessons) _lessonCard(context, store, lesson),
        ],
      ),
    );
  }

  Widget _lessonCard(BuildContext context, ProgressStore store, Lesson lesson) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var s = 0; s < 3; s++)
                  Expanded(child: _stageChip(context, store, lesson, s)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageChip(
      BuildContext context, ProgressStore store, Lesson lesson, int stage) {
    final key = lesson.id + ':s' + stage.toString();
    final globalIdx = orderedLevelKeys.indexOf(key);
    final unlocked = store.levelUnlocked(orderedLevelKeys, globalIdx);
    final stars = store.stageStars(lesson.id, stage);
    const stageNames = ['基础', '提高', '挑战'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: unlocked
            ? (stage == 2 ? Colors.deepOrange.shade200 : Colors.blue.shade100)
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: unlocked
              ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => QuizScreen(
                      title: lesson.title + ' · ' + stageNames[stage],
                      levelKey: key,
                      builder: () {
                        final r = Random();
                        return lesson.gen(r, stage).take(store.qsPerLevel).toList();
                      },
                    ),
                  ))
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  unlocked ? stageNames[stage] : '🔒',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                StarRow(stars, size: 14),
                if (unlocked)
                  const Text('开始 →', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
