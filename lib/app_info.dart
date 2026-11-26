/// 应用信息（改名只需改这里 + AndroidManifest 的 android:label）
class AppInfo {
  static const String name = '数学闯关岛';
  static const String version = '1.0.0';
  /// 安装包序号（和 pubspec.yaml 版本号 + 后面那个数字一致），
  /// 家长面板会显示，用来确认手机上装的是不是最新那版
  static const String build = '5';
  static const String versionLabel = '$version ($build)';

  /// 隐私与关于说明（家长面板展示，上架/审核用）
  static const List<String> privacyPoints = [
    '本应用纯离线运行，不需要网络、不需要注册账号。',
    '不收集任何个人信息：没有账号、没有统计上报、没有广告。',
    '所有学习记录（星星、金币、错题、奖惩）只保存在本机。',
    '题目由程序随机生成，教学内容为原创，知识点范围参考义务教育数学课程标准（二年级）。',
    '未使用任何教材原文、例题与插图；不代表或关联任何教材出版机构。',
    '如需彻底清除数据：家长面板「重置全部进度」，或卸载应用。',
  ];
}
