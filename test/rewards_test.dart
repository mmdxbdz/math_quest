import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_quest/content/rewards.dart';
import 'package:math_quest/models.dart';
import 'package:math_quest/store.dart';

void main() {
  test('奖惩规则分档正确', () {
    expect(rewardRuleFor(1.0).amount, 100); // 全对
    expect(rewardRuleFor(0.95).amount, 50); // 90分以上
    expect(rewardRuleFor(0.9).amount, 50); // 90 整也算以上
    expect(rewardRuleFor(0.85).amount, 0); // 80~89 无
    expect(rewardRuleFor(0.8).amount, 0); // 80 整不罚
    expect(rewardRuleFor(0.75).amount, -50); // 80分以下
    expect(rewardRuleFor(0.7).amount, -50); // 70 整是"80以下"档
    expect(rewardRuleFor(0.65).amount, -100); // 70分以下
    expect(rewardRuleFor(0.0).amount, -100);
  });

  test('奖惩记录持久化与待实施统计', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore();
    store.resetAll();
    await store.load();

    store.addReward(RewardRecord(
        lesson: '乘法入门', dateKey: '2026-01-01', score: 1.0, amount: 100, rule: '全对'));
    store.addReward(RewardRecord(
        lesson: '除法', dateKey: '2026-01-02', score: 0.6, amount: -100, rule: '70分以下'));
    expect(store.pendingRewardCount, 2);
    expect(store.pendingRewardNet, 0); // 100 - 100

    store.markRewardImplemented(0);
    expect(store.pendingRewardCount, 1);
    expect(store.pendingRewardNet, -100);

    // 重新加载验证持久化
    final s2 = ProgressStore();
    await s2.load();
    expect(s2.rewards.length, 2);
    expect(s2.rewards[0].implemented, true);
    expect(s2.rewards[0].score, 1.0);
    expect(s2.rewards[1].amount, -100);

    // 全部标记后不再提醒
    store.markAllRewardsImplemented();
    expect(store.pendingRewardCount, 0);
  });
}
