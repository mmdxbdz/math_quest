import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import 'quiz.dart';

class MistakesScreen extends StatelessWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore();
    final ms = store.mistakes;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(title: Text('错题本 (' + ms.length.toString() + ')')),
      body: ms.isEmpty
          ? const Center(
              child: Text('太棒了，暂时没有错题！', style: TextStyle(fontSize: 18)),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(
                    '答错第 2、4、8、16 天会回到今日任务，连续 4 轮答对才算掌握。'
                    '今天有 ' + store.dueMistakeCount.toString() + ' 道到期。',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: ms.length,
                    itemBuilder: (context, i) {
                      final m = ms[i];
                      final q = Question.fromJson(m['q'] as Map<String, dynamic>);
                      final correct =
                          q.kind == AnswerKind.double ? q.answer + '……' + q.answer2 : q.answer;
                      final wrongCount = (m['wrongCount'] as num?)?.toInt() ?? 1;
                      final stage = (m['stage'] as num?)?.toInt() ?? 0;
                      final due = store.mistakeDue(m);
                      final stageText = stage >= 4
                          ? '已掌握 ✓'
                          : '第 ' + (stage + 1).toString() + ' 轮复习'
                              + (due ? '（今天该练）' : '（' + ProgressStore.stageDays[stage].toString() + ' 天后）');
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(q.stem.replaceAll('\n', ' '),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('你的答案：' + (m['given'] as String? ?? '?') +
                              '　✓ 正确：' + correct +
                              '\n错 ' + wrongCount.toString() + ' 次 · ' + stageText),
                          isThreeLine: true,
                          trailing: due
                              ? const Icon(Icons.alarm, color: Colors.deepOrange, size: 20)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: store.dueMistakeCount == 0
                              ? null
                              : () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => QuizScreen(
                                      title: '到期错题复习',
                                      isMistakeDrill: true,
                                      builder: () => store.dueMistakes()
                                          .map((m) => Question.fromJson(
                                              m['q'] as Map<String, dynamic>))
                                          .toList(),
                                    ),
                                  )),
                          icon: const Icon(Icons.alarm),
                          label: const Text('练到期的'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              title: '错题重练',
                              isMistakeDrill: true,
                              builder: () => store.mistakes
                                  .take(10)
                                  .map((m) => Question.fromJson(
                                      m['q'] as Map<String, dynamic>))
                                  .toList(),
                            ),
                          )),
                          icon: const Icon(Icons.fitness_center),
                          label: const Text('全部重练'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
