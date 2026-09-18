# 数学闯关 · 二年级下册（人教版）

给二年级小朋友的数学闯关练习 App（Flutter / Android），纯离线运行。

## 功能

- **关卡地图**：按人教版二年级下册（经典版）10 个单元 → 每课时 3 关（基础/提高/挑战），通关解锁下一关。
- **按课时出题**：每课时有专属题目生成器（题目每次随机生成，不是固定题库）。
- **今日任务**：家长设置"当前学到哪一课"后，每天生成 8 题综合任务（当前课时 + 薄弱课时复习 + 错题），完成奖励金币。
- **错题本**：答错的题自动收录，可一键重练，答对自动移出。
- **家长面板**：入口有"超纲"乘法验证门（孩子进不去）；可设置学习进度、每关题量、查看各单元掌握率、重置进度。
- **激励机制**：星星（按错误数 1~3 星）、金币、连闯解锁。
- 所有进度保存在手机本地，无需联网、无需账号。

## 项目结构

```
lib/
  main.dart                 应用入口
  models.dart               Question/Lesson/Unit 数据模型
  store.dart                进度存档（shared_preferences）
  content/curriculum.dart   课程表（单元→课时→生成器）+ 今日任务组题
  gen/                      各单元题目生成器（纯 Dart，可单测）
    util.dart                 随机/干扰项/口诀工具
    gen_stats.dart            U1 数据收集整理
    gen_div1.dart             U2 表内除法(一)
    gen_motion.dart           U3 图形的运动
    gen_div2.dart             U4 表内除法(二)
    gen_mixed.dart            U5 混合运算
    gen_remainder.dart        U6 有余数的除法
    gen_bignum.dart           U7 万以内数的认识
    gen_weight.dart           U8 克和千克
    gen_reasoning.dart        U9 数学广角——推理
  screens/                  界面（首页/课时/答题/结算/错题本/家长）
  widgets/                  数字键盘、星星爱心等组件
test/gen_test.dart          生成器单元测试
```

## 开发环境（本机已装好）

- Flutter SDK：`D:devlutter`
- JDK 17：`D:devjdk17`
- Android SDK：`D:devandroid-sdk`
- 环境变量脚本：`D:devdsh-env.ps1`（构建前先 `. D:devdsh-env.ps1`）

## 构建与安装到手机

```powershell
. D:devdsh-env.ps1
cd D:myselfProjectsmath_quest
flutter pub get
flutter analyze          # 静态检查
flutter test             # 生成器测试
flutter build apk --release
```

产物在 `buildappoutputslutter-apkapp-release.apk`。

安装到手机：
1. 把 APK 传到手机（微信文件传输助手 / 数据线 / 网盘均可）。
2. 手机上点开 APK，允许"安装未知来源应用"。
3. 装好后桌面出现「数学闯关」图标，点开即用，全程无需联网。

（如果手机打开 USB 调试并连电脑，也可以直接 `flutter install`。）

## 教材版本说明

题库按**人教版二年级下册（经典版）**10 个单元组织：数据收集整理 / 表内除法(一) / 图形的运动(一) / 表内除法(二) / 混合运算 / 有余数的除法 / 万以内数的认识 / 克和千克 / 数学广角——推理 / 总复习。

2026 春起人教版有修订新教材（单元重排：有余数的除法、数量间的乘除关系、万以内数的认识、万以内的加减法等）。如果孩子已换用新版课本，只需调整 `lib/content/curriculum.dart` 里的单元课时表并新增/调整对应生成器，界面逻辑无需改动。

## 调整难度 / 内容

- 每关题量：家长面板可直接改（6/8/10）。
- 题目数字范围、题型比例：改 `lib/gen/` 里对应生成器的 `ri(...)` 参数即可。
- 新增课时：在 `curriculum.dart` 的 `units` 里加一个 `Lesson(id, 标题, 生成函数)`。
