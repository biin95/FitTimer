import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 居中图标+文字的空状态提示
///
/// 用于列表为空时的占位显示，可选点击回调。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onTap;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.onTap,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: AppColors.futureItem),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: AppColors.subtitle, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
