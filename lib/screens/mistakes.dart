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
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: ms.length,
                    itemBuilder: (context, i) {
                      final m = ms[i];
                      final q = Question.fromJson(m['q'] as Map<String, dynamic>);
                      final correct =
                          q.kind == AnswerKind.double ? q.answer + '……' + q.answer2 : q.answer;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(q.stem.replaceAll('\n', ' '),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('你的答案：' + (m['given'] as String? ?? '?') +
                              '　✓ 正确：' + correct),
                          isThreeLine: false,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
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
                              .map((m) => Question.fromJson(m['q'] as Map<String, dynamic>))
                              .toList(),
                        ),
                      )),
                      icon: const Icon(Icons.fitness_center),
                      label: const Text('全部重练（答对即移出）'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
