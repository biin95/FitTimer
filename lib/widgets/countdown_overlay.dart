import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 全屏倒计时遮罩，用于最后 10 秒强化显示
/// 用法：放在 Stack 的顶层，通过 [visible] 控制显隐
class CountdownOverlay extends StatelessWidget {
  /// 当前剩余秒数
  final int remaining;

  /// 总秒数（用于计算进度条）
  final int total;

  /// 是否显示遮罩（一般 remaining <= 10 时为 true）
  final bool visible;

  /// 进度条颜色（运动段橙色 / 休息段绿色）
  final Color? accentColor;

  const CountdownOverlay({
    super.key,
    required this.remaining,
    required this.total,
    required this.visible,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.exerciseSegment;
    final isUrgent = remaining <= 3;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 超大倒计时数字（纯数字，不带格式）
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: isUrgent ? 160 : 140,
                    fontWeight: FontWeight.w900,
                    color: isUrgent ? AppColors.danger : Colors.white,
                    shadows: isUrgent
                        ? [
                            Shadow(
                              color: AppColors.danger.withValues(alpha: 0.6),
                              blurRadius: 30,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$remaining',
                  ),
                ),
                const SizedBox(height: 32),

                // 进度条
                SizedBox(
                  width: 240,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total > 0 ? remaining / total : 0,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isUrgent ? AppColors.danger : color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
