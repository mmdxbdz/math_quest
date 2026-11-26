import 'dart:math';
import '../models.dart';
import 'util.dart';

// ── 素材池 ───────────────────────────────────────────────────

/// 左右（或上下）对折后能完全重合的字
const List<String> _symChars = [
  '田', '王', '中', '日', '一', '十', '品', '木', '美', '人',
  '天', '山', '出', '工', '口', '目', '大', '二', '三', '丰',
  '串', '吕', '京', '喜', '伞', '本', '土', '干', '早', '古',
];

/// 对折后两边不一样的字
const List<String> _asymChars = [
  '我', '们', '数', '学', '好', '玩', '猫', '狗', '飞', '边',
  '题', '空', '路', '比', '的', '了', '少', '多', '足', '吃',
  '跑', '唱', '爬', '游', '花', '草', '朋', '友', '秋', '春',
];

/// 对折后能重合的字母
const List<String> _symLetters = ['A', 'H', 'M', 'O', 'T', 'U', 'V', 'W', 'X', 'Y'];

/// 对折后不重合的字母
const List<String> _asymLetters = ['B', 'C', 'D', 'E', 'F', 'G', 'J', 'K', 'L', 'N', 'P', 'R', 'S', 'Z'];

/// 本来就对称的图案
const List<String> _symPatterns = ['蝴蝶', '雪花', '五角星', '窗花', '京剧脸谱', '剪纸喜字', '蜻蜓', '六角雪花', '对称的花布'];

/// 不是对称的图案
const List<String> _asymPatterns = ['被撕破的纸', '随手画的云朵', '歪倒的塔', '打了结的绳', '一片残叶', '随手涂的圈'];

/// 平移现象
const List<String> _pingyi = [
  '拉抽屉', '电梯上升', '推箱子', '升国旗', '缆车沿索道滑行', '沿直滑梯下滑',
  '推拉门滑动', '火车在直轨道上行驶', '扶梯向上运行', '拉窗帘', '打印纸从打印机里出来',
  '拨算盘珠', '把铅笔盒从左边推到右边', '沿直线推购物车',
];

/// 旋转现象
const List<String> _rotate = [
  '风车迎风转动', '拧水龙头', '摩天轮转动', '钟表指针走动', '风扇叶片转动', '拧瓶盖',
  '转动方向盘', '陀螺旋转', '旋转木马转动', '地球仪转动', '洗衣机滚筒转动', '打开水龙头把手',
];

/// 既不是平移也不是旋转
const List<String> _neither = ['拍皮球上下弹跳', '拉伸橡皮筋', '把纸揉成一团', '抖被子'];

String _pick(List<String> list, Random r) => list[ri(r, 0, list.length - 1)];

/// 从池里随机取 n 个互不相同的
List<String> _pickN(List<String> list, Random r, int n) {
  final pool = [...list]..shuffle(r);
  return pool.take(n).toList();
}

String _join(List<String> items) => items.join('、');

// ── u3l1 轴对称（照镜子） ─────────────────────────────────────

List<Question> genSymmetry(Random r, int stage) {
  final qs = <Question>[];
  const id = 'u3l1';

  for (var t = 0; t < 24; t++) {
    // 1. 找出对称的字
    {
      final sym = _pick(_symChars, r);
      final bad = _pickN(_asymChars, r, 2);
      qs.add(choiceQ(
          '下面的字中，沿中线对折后两边能完全重合（对称）的是（　）',
          sym,
          bad,
          '"' + sym + '"左右两边一模一样，是对称的。', id,
          r: r));
    }
    // 2. 找出不对称的字
    {
      final bad = _pick(_asymChars, r);
      final good = _pickN(_symChars, r, 2);
      qs.add(choiceQ('下面的字中，不是对称的是（　）', bad, good,
          '"' + bad + '"对折后两边对不上，不是对称的。', id, r: r));
    }
    // 3. 对称的图案
    {
      final good = _pick(_symPatterns, r);
      final bad = _pickN(_asymPatterns, r, 2);
      qs.add(choiceQ('下面哪种图案左右两边一模一样（对称）？', good,
          bad, '"' + good + '"的左右两边完全一样。', id, r: r));
    }
    // 4. 镜子里的字母
    {
      final symLetter = _pick(_symLetters, r);
      final asymLetter = _pick(_asymLetters, r);
      final flip = r.nextBool();
      if (flip) {
        qs.add(choiceQ('把 $symLetter 照镜子，镜子里的样子和原来（　）',
            '一模一样', ['变成反的', '少了一半'], '$symLetter 是对称的，镜子里的样子和原来一样。', id,
            r: r));
      } else {
        qs.add(choiceQ('把 $asymLetter 照镜子，镜子里的样子和原来（　）',
            '左右反过来', ['一模一样', '不见了'], '$asymLetter 左右不对称，照镜子会左右反过来。', id,
            r: r));
      }
    }
    // 5. 对折剪图案
    {
      final n = ri(r, 1, 3);
      final pieces = 1 << n;
      qs.add(choiceQ(
          '把一张纸对折 $n 次后剪出一朵花，展开后有（　）朵一样的花',
          '$pieces 朵',
          [(pieces * 2).toString() + ' 朵', max(1, pieces ~/ 2).toString() + ' 朵'],
          '对折 1 次变 2 朵，对折 $n 次就是 $pieces 朵。', id,
          r: r));
    }
    // 6. 对称轴条数（基础/提高才有，挑战换成应用）
    if (stage >= 1) {
      const axes = {
        '正方形': '4 条',
        '长方形': '2 条',
        '圆': '很多条',
      };
      final shape = _pick(axes.keys.toList(), r);
      final correct = axes[shape]!;
      final ds = axes.values.where((v) => v != correct).toList();
      qs.add(choiceQ('$shape 的对称轴有（　）', correct, ds,
          '$shape 沿这些线对折都能完全重合。', id, r: r));
    }
    // 7. 哪些是对称的数量统计
    {
      final syms = _pickN(_symPatterns, r, 2);
      final asyms = _pickN(_asymPatterns, r, 2);
      final items = [syms[0], asyms[0], syms[1], asyms[1]]..shuffle(r);
      qs.add(choiceQ(
          '${_join(items)}，其中左右对称的有（　）个',
          '2 个',
          ['1 个', '3 个'],
          '${syms[0]} 和 ${syms[1]} 左右对称，另外两个不对称。', id,
          r: r));
    }
    // 8. 判断一句话
    {
      final pair = _pickN(_symChars, r, 2);
      final ask = r.nextBool();
      qs.add(choiceQ(
          ask
              ? '"${pair[0]}" 沿中间竖线对折后两边能完全重合吗？'
              : '"${pair[1]}" 是轴对称图形吗？',
          '能',
          ['不能', '只有一半能'],
          '这两个字左右两边完全一样，是轴对称的。', id,
          r: r));
    }
    // 9. 挑战：生活里的对称
    if (stage >= 2) {
      qs.add(choiceQ('下面哪种做法用到了对称？', '把纸对折后剪花纹',
          ['把箱子直直地推走', '把瓶盖拧开'], '剪纸就是把纸对折，剪出的花纹左右一样。', id,
          r: r));
      qs.add(choiceQ('剪纸时，想让剪出来的图案左右对称，应该先把纸（　）',
          '对折', ['揉成一团', '剪成两半'], '对折以后两边花纹才会一样。', id, r: r));
      qs.add(choiceQ('一个轴对称图形沿它的对称轴对折，两边（　）', '完全重合',
          ['差一点', '会变大'], '对称轴两边是完全一样的两半。', id, r: r));
      qs.add(choiceQ('下面几个字里，对称的有（　）个：${_pickN(_symChars, r, 2).join('、')}、${_pick(_asymChars, r)}',
          '2 个', ['1 个', '3 个'], '前两个字左右对称，最后那个不对称。', id, r: r));
    }
  }
  return dedupe(qs, 12);
}

// ── u3l2 平移（滑一滑） ───────────────────────────────────────

List<Question> genTranslate(Random r, int stage) {
  final qs = <Question>[];
  const id = 'u3l2';

  for (var t = 0; t < 24; t++) {
    // 1. 找平移
    {
      final good = _pick(_pingyi, r);
      final bad = _pickN(_rotate, r, 2);
      qs.add(choiceQ('下列哪种现象是平移？', good, bad,
          '"$good"是沿直线移动，是平移。', id, r: r));
    }
    // 2. 找不是平移的
    {
      final bad = _pick(_rotate, r);
      final good = _pickN(_pingyi, r, 2);
      qs.add(choiceQ('下列哪种现象不是平移？', bad, good,
          '"$bad"是绕着一个圈转，是旋转。', id, r: r));
    }
    // 3. 平移后大小形状
    {
      final act = _pick(_pingyi, r);
      qs.add(choiceQ('"$act"时，物体只改变了位置，它的大小和形状（　）',
          '都不变', ['会变大', '会变形'], '平移只是位置变了，大小和形状都不变。', id,
          r: r));
    }
    // 4. 方向
    {
      final up = r.nextBool();
      final from = ri(r, 1, 6);
      final to = from + ri(r, 2, 9);
      qs.add(choiceQ(
          up
              ? '电梯从 $from 楼升到 $to 楼，电梯是向（　）平移'
              : '电梯从 $to 楼降到 $from 楼，电梯是向（　）平移',
          up ? '上' : '下',
          up ? ['下', '左'] : ['上', '右'],
          '电梯是直上直下地移动，属于平移。', id,
          r: r));
    }
    // 5. 平移了几格
    {
      final a = ri(r, 2, 6);
      final b = ri(r, 2, 6);
      qs.add(numChoice(
          '在方格纸上，小旗先向右平移 $a 格，又向右平移 $b 格，一共向右平移了几格？',
          a + b, r, '两次都向右，把格数加起来：$a + $b = ${a + b}。', id,
          min: 1, max: 20));
    }
    // 6. 方向不变
    qs.add(choiceQ('图形平移以后，它的方向会改变吗？', '不会变',
        ['会转过头', '会上下颠倒'], '平移不改变方向，只是整体挪了位置。', id, r: r));
    // 7. 三选一里挑平移的
    {
      final good = _pick(_pingyi, r);
      final bad = _pickN(_rotate, r, 2);
      final items = [good, bad[0], bad[1]]..shuffle(r);
      qs.add(choiceQ(
          '①${items[0]}　②${items[1]}　③${items[2]}，其中是平移的是（　）',
          ['①', '②', '③'][items.indexOf(good)],
          ['①', '②', '③']..remove(['①', '②', '③'][items.indexOf(good)]),
          '"$good"是平移，另外两个都是旋转。', id,
          r: r));
    }
    // 8. 生活小场景
    {
      final a = _pick(_pingyi, r);
      final dir = _pick(['一直线', '一条直线'], r);
      qs.add(choiceQ('"$a"是沿着$dir移动的，所以它是（　）', '平移',
          ['旋转', '对称'], '沿直线移动的运动叫平移。', id, r: r));
    }
    // 9. 提高：既有平移又有旋转
    if (stage >= 1) {
      qs.add(choiceQ('汽车在笔直的公路上行驶，车身和车轮分别是什么运动？',
          '车身平移、车轮旋转', ['都平移', '都旋转'], '车身一直往前走是平移，车轮转圈是旋转。', id,
          r: r));
      qs.add(choiceQ('下面哪种运动既有平移又有旋转？', '正在行驶的汽车',
          ['上升的电梯', '转动的风扇'], '汽车车身平移、车轮旋转，两种都有。', id, r: r));
    }
    // 10. 挑战：易错点
    if (stage >= 2) {
      qs.add(choiceQ('下列说法正确的是（　）', '平移后图形大小不变',
          ['平移后图形会变大', '平移后图形会转过来'], '平移只改变位置。', id, r: r));
      qs.add(choiceQ('把 ${_pick(_symChars, r)} 向右平移 3 格，它的大小（　）',
          '不变', ['变大 3 倍', '变大一点点'], '平移不改变大小。', id, r: r));
      final n1 = ri(r, 2, 5);
      qs.add(numChoice(
          '一个小圆点先向上平移 $n1 格，再向下平移 $n1 格，它回到原来的位置了吗？（回原位算 0 格）它离原来的位置有几格？',
          0, r, '向上 $n1 格又向下 $n1 格，正好回到原位，所以是 0 格。', id,
          min: 0, max: 12));
    }
  }
  return dedupe(qs, 10);
}

// ── u3l3 旋转（转一转） ───────────────────────────────────────

List<Question> genRotate(Random r, int stage) {
  final qs = <Question>[];
  const id = 'u3l3';

  for (var t = 0; t < 24; t++) {
    // 1. 找旋转
    {
      final good = _pick(_rotate, r);
      final bad = _pickN(_pingyi, r, 2);
      qs.add(choiceQ('下列现象中属于旋转的是（　）', good, bad,
          '"$good"是绕着一个中心转圈，是旋转。', id, r: r));
    }
    // 2. 找不是旋转的
    {
      final bad = _pick(_pingyi, r);
      final good = _pickN(_rotate, r, 2);
      qs.add(choiceQ('下列现象中不是旋转的是（　）', bad, good,
          '"$bad"是沿直线移动，是平移。', id, r: r));
    }
    // 3. 风车/风扇/陀螺……
    {
      final act = _pick(_rotate, r);
      qs.add(choiceQ('"$act"是什么现象？', '旋转', ['平移', '对称'],
          '"$act"绕着中心转圈，是旋转。', id, r: r));
    }
    // 4. 绕着中心
    {
      final act = _pick(_rotate, r);
      final center = _pick(['自己的中心', '中间的轴', '固定的中心'], r);
      qs.add(choiceQ('旋转时，"$act"绕着（　）转', center,
          ['一点都不动', '一条直线平移'], '旋转总要绕着一个固定的中心或轴。', id,
          r: r));
    }
    // 5. 旋转后大小形状
    {
      final act = _pick(_rotate, r);
      qs.add(choiceQ('"$act"时，物体的大小和形状（　）', '不变',
          ['会变大', '会变成别的形状'], '旋转只改变方向，大小和形状都不变。', id, r: r));
    }
    // 6. 钟面
    {
      final to = _pick(['3', '6', '9'], r);
      qs.add(choiceQ('钟面上分针从 12 走到 $to，分针的运动是（　）', '旋转',
          ['平移', '跳动'], '指针绕着钟面的中心转，是旋转。', id, r: r));
    }
    // 7. 三选一
    {
      final good = _pick(_rotate, r);
      final bad = _pickN(_pingyi, r, 2);
      final items = [good, bad[0], bad[1]]..shuffle(r);
      final labels = ['①', '②', '③'];
      qs.add(choiceQ(
          '①${items[0]}　②${items[1]}　③${items[2]}，其中是旋转的是（　）',
          labels[items.indexOf(good)],
          labels.where((l) => l != labels[items.indexOf(good)]).toList(),
          '"$good"是旋转，另外两个是平移。', id,
          r: r));
    }
    // 8. 生活问答
    {
      final dev = _pick(['电风扇的叶片', '风车的叶片', '摩天轮的座舱', '陀螺'], r);
      qs.add(choiceQ('$dev 在运动时是（　）', '旋转', ['平移', '不动的'],
          '$dev 绕着中心转圈。', id, r: r));
    }
    // 9. 提高：两种都有
    if (stage >= 1) {
      qs.add(choiceQ('汽车在直路上行驶，车身和车轮分别是什么运动？',
          '车身平移、车轮旋转', ['都是平移', '都是旋转'], '车身平移，车轮旋转。', id,
          r: r));
    }
    // 10. 挑战：排除
    if (stage >= 2) {
      final neither = _pick(_neither, r);
      final bad = _pickN(_pingyi, r, 2);
      qs.add(choiceQ('下面哪个既不是平移也不是旋转？', neither, bad,
          '"$neither"不是沿直线移动，也不是绕中心转圈。', id, r: r));
      qs.add(choiceQ('旋转和平移相同的点是（　）', '大小和形状都不变',
          ['方向都不变', '都会滚起来'], '平移和旋转都不改变图形的大小和形状。', id, r: r));
      qs.add(choiceQ('把风车换一个方向摆放，再让它转，它还是（　）', '旋转',
          ['平移', '对称'], '不管朝哪边，绕着中心转就是旋转。', id, r: r));
    }
  }
  return dedupe(qs, 10);
}