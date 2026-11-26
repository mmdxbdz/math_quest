/// 奖惩规则：按一轮正确率自动分档（家长定义的现实奖惩制度）
class RewardRule {
  final String name;
  final int amount; // >0 奖励，<0 罚，0 无奖惩
  final String desc;
  const RewardRule(this.name, this.amount, this.desc);
}

/// 按正确率(0~1)判定奖惩：
/// 全对 → +100；90分以上 → +50；80~89 → 无；80分以下 → -50；70分以下 → -100
RewardRule rewardRuleFor(double score) {
  if (score >= 1.0) {
    return const RewardRule('全对', 100, '一个都没错，奖励 100！');
  }
  if (score >= 0.9) {
    return const RewardRule('90分以上', 50, '正确率 90% 以上，奖励 50！');
  }
  if (score >= 0.8) {
    return const RewardRule('保持', 0, '80~89 分，没有奖惩，保持哦。');
  }
  if (score >= 0.7) {
    return const RewardRule('80分以下', -50, '正确率不到 80%，罚 50。');
  }
  return const RewardRule('70分以下', -100, '正确率不到 70%，罚 100。');
}

/// 奖惩规则表（家长面板展示用）
const rewardRulesTable = [
  ('全对（100%）', '+100', '一次都不能错'),
  ('90% 以上', '+50', '优秀'),
  ('80% ~ 89%', '0', '无奖惩'),
  ('70% ~ 79%', '-50', '罚'),
  ('70% 以下', '-100', '罚'),
];
