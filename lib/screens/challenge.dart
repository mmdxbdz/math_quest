import 'package:flutter/material.dart';
import '../store.dart';
import '../content/challenge.dart';
import 'quiz.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore();
    final badges = store.challengeBadges;
    final total = allChallengeLevels.length;
    final earned =
        allChallengeLevels.where((l) => badges.containsKey(l.id)).length;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(title: const Text('🧠 思维小挑战 · 动动脑')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _progressCard(earned, total),
          const SizedBox(height: 12),
          for (final theme in challengeThemes) _themeCard(context, store, theme),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _progressCard(int earned, int total) {
    final allDone = earned >= total;
    return Card(
      color: allDone ? Colors.amber.shade100 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Text(allDone ? '🧠' : '🎯',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    allDone ? '思维大师！9 关全部拿下！' : '每关全对得金牌、错 1 题得银牌',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : earned / total,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.amber,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                const SizedBox(width: 10),
                Text('徽章 ' + earned.toString() + ' / ' + total.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeCard(
      BuildContext context, ProgressStore store, ChallengeTheme theme) {
    final badges = store.challengeBadges;
    final themeBadge = themeDone(theme, badges);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(theme.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(theme.title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text(theme.desc,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (themeBadge)
                  const Icon(Icons.military_tech, color: Colors.amber, size: 26),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final level in theme.levels)
                  Expanded(child: _levelChip(context, store, theme, level)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelChip(
      BuildContext context, ProgressStore store, ChallengeTheme theme,
      ChallengeLevel level) {
    final badge = store.challengeBadges[level.id];
    final Color bg = badge == 'gold'
        ? Colors.amber.shade100
        : (badge == 'silver' ? Colors.blueGrey.shade100 : Colors.grey.shade200);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => QuizScreen(
              title: theme.title + ' · ' + level.title,
              isChallenge: true,
              challengeKey: level.id,
              builder: () => buildChallengeQuestions(level),
            ),
          )),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(level.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(level.qCount.toString() + ' 题',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  badge == 'gold'
                      ? '🏅'
                      : (badge == 'silver' ? '🥈' : '开始 →'),
                  style: TextStyle(
                      fontSize: badge == null ? 12 : 18,
                      fontWeight: FontWeight.bold,
                      color: badge == null ? Colors.blueGrey : Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
