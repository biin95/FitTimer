import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 红色删除图标按钮
///
/// 统一的删除按钮样式，用于动作、组、模板等的删除操作。
class DeleteButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final double size;

  const DeleteButton({
    super.key,
    required this.onPressed,
    this.tooltip = '删除',
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.delete_outline, color: AppColors.danger, size: size),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
