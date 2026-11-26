import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_info.dart';
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

  /// 粘贴存档码恢复整份进度（换手机 / 重装 App 后的救命按钮）
  Future<void> _restoreFromCode() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴存档码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '把之前「复制存档码」得到的那一长串贴进来。\n'
              '恢复后，当前这台手机上的旧进度会被覆盖。',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '在这里粘贴…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (code == null || code.trim().isEmpty) return;
    final ok = store.importCode(code);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '存档已经恢复好啦～' : '这串存档码读不懂，检查一下有没有漏抄'),
      duration: const Duration(seconds: 3),
    ));
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('🔊 答题语音鼓励'),
          subtitle: const Text('答对夸一夸，答错打打气（系统语音）'),
          value: store.soundOn,
          onChanged: (v) => setState(() => store.setSoundOn(v)),
        ),
        const SizedBox(height: 12),
        const Text('📊 各单元掌握情况',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final unit in units) _unitStat(unit),
        const SizedBox(height: 20),
        const Text('🎯 知识点诊断',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text('正确率 < 70% 标红，今日任务会优先练短板',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        for (final skill in _orderedSkills()) _skillRow(skill),
        const SizedBox(height: 20),
        const Text('💰 奖惩制度',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text('闯关结束自动判定：全对 +100 ／ 90%以上 +50 ／ 80%以下 -50 ／ 70%以下 -100',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        if (store.pendingRewardCount > 0)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active,
                    color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '有 ' + store.pendingRewardCount.toString() +
                        ' 次奖惩待实施（合计 ' +
                        (store.pendingRewardNet >= 0 ? '+' : '') +
                        store.pendingRewardNet.toString() + '）',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => store.markAllRewardsImplemented()),
                  child: const Text('全部已实施'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (store.rewards.isEmpty)
          const Text('还没有奖惩记录，先去闯关吧',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        for (final r in store.rewards.reversed)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.dateKey + ' · ' + r.lesson,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    (r.score * 100).round().toString() + '分',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    r.amount > 0 ? '+' + r.amount.toString() : r.amount.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: r.amount > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  r.implemented
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 18)
                      : TextButton(
                          onPressed: () => setState(() =>
                              store.markRewardImplemented(
                                  store.rewards.indexOf(r))),
                          style: TextButton.styleFrom(
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('已实施'),
                        ),
                ],
              ),
            ),
        const SizedBox(height: 20),
        const Text('💾 存档备份（换手机 / 重装 App 用）',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text(
            '平时升级版本直接覆盖安装就行，进度不会丢。'
            '想多上一道保险，就点「复制存档码」，把那一长串存到微信/备忘录里。',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                      ClipboardData(text: store.exportCode()));
                  messenger.showSnackBar(const SnackBar(
                    content: Text('存档码已复制，粘到备忘录里存好就行'),
                    duration: Duration(seconds: 2),
                  ));
                },
                icon: const Icon(Icons.copy_all),
                label: const Text('复制存档码'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _restoreFromCode,
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('粘贴恢复'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('🐻 宠物动画（给娃看开头的动画）',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text('"再看一遍"不删数据；"清空宠物"会连宠物和小家一起清掉',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  store.setReplayIntro(true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('回首页就能重新看一遍拉～'),
                    duration: Duration(seconds: 2),
                  ));
                },
                icon: const Icon(Icons.replay),
                label: const Text('再看一遍动画'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('清空宠物和小家？'),
              content: const Text(
                  '宠物、成长进度、收到的家具都会没掉，回到"第一次进游戏"的样子（关卡进度和星星不动）。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('取消')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => store.resetPets());
                    },
                    child: const Text('清空')),
              ],
            ),
          ),
          icon: const Icon(Icons.pets),
          label: const Text('清空宠物（回到第一次）'),
        ),
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
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('关于 ' + AppInfo.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('版本 ' + AppInfo.versionLabel,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  for (final p in AppInfo.privacyPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 14)),
                          Expanded(
                            child: Text(p,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('知道了')),
              ],
            ),
          ),
          icon: const Icon(Icons.privacy_tip_outlined),
          label: const Text('关于与隐私'),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  /// 有答题数据的知识点按正确率从低到高排前面，未练的放最后
  List<String> _orderedSkills() {
    final ids = <String>[
      for (final l in allLessons) l.id,
      'u6l1:compute',
      'u6l1:rule',
    ];
    final hasData = ids.where((id) {
      final st = store.skillStat(id);
      return st != null && st[0] > 0;
    }).toList();
    hasData.sort((a, b) {
      final sa = store.skillStat(a)!;
      final sb = store.skillStat(b)!;
      return (sa[1] / sa[0]).compareTo(sb[1] / sb[0]);
    });
    final noData = ids.where((id) {
      final st = store.skillStat(id);
      return st == null || st[0] == 0;
    });
    return [...hasData, ...noData];
  }

  Widget _skillRow(String skill) {
    final st = store.skillStat(skill);
    final n = st?[0] ?? 0;
    final rate = n == 0 ? null : st![1] / n;
    final weak = rate != null && rate < 0.7;
    final ft = store.firstTryRate(skill);
    final ftWeak = ft != null && ft < 0.6;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(skillTitle(skill),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: weak ? Colors.red : Colors.black87,
                        fontWeight: weak ? FontWeight.bold : FontWeight.normal)),
                if (ft != null)
                  Text(
                    '一次答对 ' + (ft * 100).round().toString() + '%' + (ftWeak ? ' ⚠️' : ''),
                    style: TextStyle(
                        fontSize: 11,
                        color: ftWeak ? Colors.red : Colors.blueGrey),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: weak ? Colors.red : Colors.orange,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              rate == null ? '未练' : (rate * 100).toStringAsFixed(0) + '%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  color: weak ? Colors.red : Colors.grey,
                  fontWeight: weak ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
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
