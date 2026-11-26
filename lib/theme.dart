import 'package:flutter/material.dart';

/// 安静书（Quiet Book）配色：奶油底 + 马卡龙粉彩 + 暖棕字。
/// 所有软乎乎的界面都用这里的颜色，统一风格。
class QuietBook {
  static const Color cream = Color(0xFFFFF8E7);
  static const Color ink = Color(0xFF6D4C41);
  static const Color inkSoft = Color(0xFF9E7E6B);

  static const Color sage = Color(0xFFE8F5E9);
  static const Color blush = Color(0xFFFCE4EC);
  static const Color sky = Color(0xFFE3F2FD);
  static const Color peach = Color(0xFFFFF3E0);
  static const Color lavender = Color(0xFFEDE7F6);
  static const Color butter = Color(0xFFFFF8E1);
  static const Color lilac = Color(0xFFF3E5F5);
  static const Color sand = Color(0xFFFFEFDF);
  static const Color mint = Color(0xFFE0F2F1);
  static const Color rose = Color(0xFFFCE8EC);

  /// 每个单元一页、一页一个底色（顺序与 units 一致）
  static const List<Color> pageColors = [
    sage,
    blush,
    sky,
    peach,
    lavender,
    butter,
    lilac,
    sand,
    mint,
    rose,
  ];

  static Color pageColor(int index) =>
      pageColors[index % pageColors.length];
}