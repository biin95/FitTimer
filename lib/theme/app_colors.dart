import 'package:flutter/material.dart';

/// FitTimer 统一颜色常量
/// 所有颜色集中管理，修改一处即可全局生效
class AppColors {
  // ── 语义色 ──
  static const Color success = Colors.green;
  static const Color danger = Colors.red;
  static const Color warning = Colors.orange;
  static const Color info = Colors.purple;
  static const Color tip = Colors.amber;

  // ── 训练段类型色 ──
  static const Color exerciseSegment = Colors.orange;
  static const Color restSegment = Colors.green;

  // ── 难度色 ──
  static const Color difficultyBeginner = Colors.green;
  static const Color difficultyIntermediate = Colors.orange;
  static const Color difficultyAdvanced = Colors.red;
  static const Color difficultyDefault = Colors.grey;

  // ── 中性色 ──
  static const Color onColoredBadge = Colors.white;
  static const Color disabled = Color(0xFFBDBDBD); // grey[300]
  static const Color placeholder = Color(0xFF9E9E9E); // grey[500]
  static const Color subtitle = Color(0xFF757575); // grey[600]
  static const Color secondaryText = Color(0xFF616161); // grey[700]
  static const Color futureItem = Color(0xFFBDBDBD); // grey[400]

  // ── 图表色 ──
  static const Color chartBar = Colors.orange;
}
