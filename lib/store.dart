import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// 全局进度存档（本地持久化）
class ProgressStore extends ChangeNotifier {
  static const _key = 'progress_v1';

  /// 关卡(key = 'lessonId:s阶段') -> 最佳星数 1..3
  final Map<String, int> stars = {};

  /// 金币
  int coins = 0;

  /// 课时 -> [答题数, 答对数]
  final Map<String, List<int>> kp = {};

  /// 错题：{'q': questionJson, 'given': 学生的答案, 'ts': 时间}
  final List<Map<String, dynamic>> mistakes = [];

  /// 家长设置
  String currentLesson = '';
  int qsPerLevel = 8;

  /// 最近一次完成"今日任务"的日期 yyyy-M-d
  String todayDoneKey = '';

  /// 已学的课时（含之前的），用于复习出题
  final Set<String> learned = {};

  bool loaded = false;

  static ProgressStore? _inst;
  factory ProgressStore() => _inst ??= ProgressStore._();
  ProgressStore._();

  String _todayKey() {
    final n = DateTime.now();
    return n.year.toString() + '-' + n.month.toString() + '-' + n.day.toString();
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_key);
    if (s != null) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        (j['stars'] as Map?)?.forEach((k, v) => stars[k.toString()] = (v as num).toInt());
        coins = (j['coins'] as num?)?.toInt() ?? 0;
        (j['kp'] as Map?)?.forEach((k, v) {
          final list = (v as List).cast<num>().map((e) => e.toInt()).toList();
          if (list.length >= 2) kp[k.toString()] = [list[0], list[1]];
        });
        final ms = j['mistakes'] as List?;
        if (ms != null) mistakes.addAll(ms.cast<Map<String, dynamic>>());
        currentLesson = j['currentLesson'] as String? ?? '';
        qsPerLevel = (j['qsPerLevel'] as num?)?.toInt() ?? 8;
        todayDoneKey = j['todayDoneKey'] as String? ?? '';
        learned.addAll(((j['learned'] as List?) ?? const []).cast<String>());
      } catch (_) {
        // 存档损坏则忽略，重新开始
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode({
      'stars': stars,
      'coins': coins,
      'kp': kp,
      'mistakes': mistakes,
      'currentLesson': currentLesson,
      'qsPerLevel': qsPerLevel,
      'todayDoneKey': todayDoneKey,
      'learned': learned.toList(),
    }));
  }

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  int stageStars(String lessonId, int stage) => stars[lessonId + ':s' + stage.toString()] ?? 0;

  bool levelUnlocked(List<String> orderedKeys, int index) {
    if (index <= 0) return true;
    return (stars[orderedKeys[index - 1]] ?? 0) >= 1;
  }

  void finishLevel(String key, int earned) {
    if (earned > (stars[key] ?? 0)) stars[key] = earned;
    _save();
    notifyListeners();
  }

  void recordAnswer(Question q, bool correct, String given) {
    final cur = kp[q.lessonId] ?? [0, 0];
    cur[0] += 1;
    if (correct) cur[1] += 1;
    kp[q.lessonId] = cur;
    if (!correct) {
      mistakes.removeWhere((m) => (m['q'] as Map)['stem'] == q.stem);
      mistakes.insert(0, {'q': q.toJson(), 'given': given, 'ts': DateTime.now().millisecondsSinceEpoch});
      while (mistakes.length > 60) {
        mistakes.removeLast();
      }
    }
    _save();
    notifyListeners();
  }

  void resolveMistake(String stem) {
    final n0 = mistakes.length;
    mistakes.removeWhere((m) => (m['q'] as Map)['stem'] == stem);
    if (mistakes.length != n0) {
      _save();
      notifyListeners();
    }
  }

  bool get todayDone => todayDoneKey == _todayKey();

  void markTodayDone(int bonus) {
    todayDoneKey = _todayKey();
    coins += bonus;
    _save();
    notifyListeners();
  }

  void addCoins(int n) {
    coins += n;
    _save();
    notifyListeners();
  }

  /// 家长设置"学到哪一课"：orderedLessons 为全部课时 id 的全局顺序
  void setCurrentLesson(String lessonId, List<String> orderedLessons) {
    currentLesson = lessonId;
    final idx = orderedLessons.indexOf(lessonId);
    learned.clear();
    if (idx >= 0) {
      learned.addAll(orderedLessons.take(idx + 1));
    }
    _save();
    notifyListeners();
  }

  void setQsPerLevel(int n) {
    qsPerLevel = n;
    _save();
    notifyListeners();
  }

  /// 正确率最低的已学课时（答题数>=minN）
  String? weakestLesson({int minN = 4}) {
    String? best;
    double bestRate = 2;
    for (final id in learned) {
      final st = kp[id];
      if (st == null || st[0] < minN) continue;
      final rate = st[1] / st[0];
      if (rate < bestRate) {
        bestRate = rate;
        best = id;
      }
    }
    return best;
  }

  void resetAll() {
    stars.clear();
    coins = 0;
    kp.clear();
    mistakes.clear();
    currentLesson = '';
    todayDoneKey = '';
    learned.clear();
    _save();
    notifyListeners();
  }
}
