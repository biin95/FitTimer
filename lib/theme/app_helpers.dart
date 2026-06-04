import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 根据难度等级返回对应颜色
Color difficultyColor(String? difficulty) {
  switch (difficulty?.toLowerCase()) {
    case 'beginner':
      return AppColors.difficultyBeginner;
    case 'intermediate':
      return AppColors.difficultyIntermediate;
    case 'advanced':
      return AppColors.difficultyAdvanced;
    default:
      return AppColors.difficultyDefault;
  }
}
