import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 排序用上下移按钮组
///
/// 用于排序模式中调整动作/段的顺序，边界位置自动禁用。
class MoveArrows extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const MoveArrows({
    super.key,
    required this.isFirst,
    required this.isLast,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            icon: Icon(Icons.arrow_upward, size: 20, color: isFirst ? AppColors.disabled : null),
            onPressed: isFirst ? null : onMoveUp,
            padding: EdgeInsets.zero,
            tooltip: '上移',
          ),
        ),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            icon: Icon(Icons.arrow_downward, size: 20, color: isLast ? AppColors.disabled : null),
            onPressed: isLast ? null : onMoveDown,
            padding: EdgeInsets.zero,
            tooltip: '下移',
          ),
        ),
      ],
    );
  }
}
