import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../content/curriculum.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final ProgressStore store = ProgressStore();
  bool unlocked = false;
  late int ga;
  late int gb;
  final gateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final r = Random();
    ga = r.nextInt(8) + 12; // 12~19
    gb = r.nextInt(6) + 4; // 4~9
  }

  @override
  void dispose() {
    gateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('家长面板')),
      body: unlocked ? _panel() : _gate(),
    );
  }

  Widget _gate() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 44, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text('家长验证：请计算 ' + ga.toString() + ' × ' + gb.toString() + ' = ?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(
            controller: gateCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '答案',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(gateCtrl.text.trim());
              if (v == ga * gb) {
                setState(() => unlocked = true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('不对哦，这道题超出二年级范围啦')));
              }
            },
            child: const Text('进入'),
          ),
        ],
      ),
    );
  }

  Widget _panel() {
    final current = store.currentLesson;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('📍 当前学到哪一课？',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButton<String>(
          isExpanded: true,
          value: current.isEmpty ? null : current,
          hint: const Text('选择课时'),
          items: [
            for (final lesson in allLessons)
              DropdownMenuItem(
                value: lesson.id,
                child: Text(
                  (unitOfLesson(lesson.id)?.title ?? '') + ' · ' + lesson.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => store.setCurrentLesson(
                  v, allLessons.map((l) => l.id).toList()));
            }
          },
        ),
        const SizedBox(height: 20),
        const Text('📝 每关题量',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 6, label: Text('6 题')),
            ButtonSegment(value: 8, label: Text('8 题')),
            ButtonSegment(value: 10, label: Text('10 题')),
          ],
          selected: {store.qsPerLevel},
          onSelectionChanged: (s) => setState(() => store.setQsPerLevel(s.first)),
        ),
        const SizedBox(height: 20),
        const Text('📊 各单元掌握情况',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final unit in units) _unitStat(unit),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('重置全部进度？'),
              content: const Text('星星、金币、错题本和统计都会清空，且无法恢复。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('取消')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => store.resetAll());
                    },
                    child: const Text('确认重置')),
              ],
            ),
          ),
          icon: const Icon(Icons.delete_forever),
          label: const Text('重置全部进度'),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _unitStat(Unit unit) {
    var n = 0;
    var c = 0;
    for (final l in unit.lessons) {
      final st = store.kp[l.id];
      if (st != null) {
        n += st[0];
        c += st[1];
      }
    }
    final rate = n == 0 ? null : c / n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(unit.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              rate == null ? '未练习' : (rate * 100).toStringAsFixed(0) + '%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
