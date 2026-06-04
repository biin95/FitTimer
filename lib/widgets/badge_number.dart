import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 圆形编号/完成徽章
///
/// 用于动作列表中的编号显示，支持完成态（勾号）和自定义颜色。
class BadgeNumber extends StatelessWidget {
  final Color color;
  final int? number;
  final bool done;
  final double size;

  const BadgeNumber({
    super.key,
    required this.color,
    this.number,
    this.done = false,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: done ? AppColors.success : color,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: done
            ? Icon(Icons.check, size: size * 0.57, color: AppColors.onColoredBadge)
            : Text(
                '${number ?? ''}',
                style: TextStyle(
                  color: AppColors.onColoredBadge,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
