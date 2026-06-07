import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../theme/app_colors.dart';

/// 全屏倒计时遮罩，用于最后 10 秒强化显示
/// 脉冲弹跳 + 红光闪烁，视觉冲击力拉满
class CountdownOverlay extends StatefulWidget {
  /// 当前剩余秒数
  final int remaining;

  /// 是否显示遮罩（一般 remaining <= 10 时为 true）
  final bool visible;

  /// 进度条颜色（运动段橙色 / 休息段绿色）
  final Color? accentColor;

  const CountdownOverlay({
    super.key,
    required this.remaining,
    required this.visible,
    this.accentColor,
  });

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _breatheController;
  late AnimationController _flashController;
  int _lastRemaining = -1;

  @override
  void initState() {
    super.initState();
    // 脉冲弹跳动画（数字切换时触发）
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    // 呼吸缩放动画（持续微缩放）
    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    // 红光闪烁动画（最后3秒）
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(CountdownOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remaining != _lastRemaining && widget.visible) {
      _lastRemaining = widget.remaining;
      _pulseController.forward(from: 0);
      // 最后3秒震一下
      if (widget.remaining <= 3) {
        HapticFeedback.heavyImpact();
        _flashController.repeat(reverse: true);
      } else {
        _flashController.stop();
        _flashController.value = 0;
      }
    }
    if (!widget.visible) {
      _flashController.stop();
      _flashController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _breatheController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = widget.remaining <= 3;
    final color = widget.accentColor ?? AppColors.exerciseSegment;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _breatheController, _flashController]),
          builder: (context, child) {
            // 脉冲缩放：从1.3弹到1.0
            final pulseScale = 1.0 + 0.3 * (1.0 - Curves.elasticOut.transform(_pulseController.value));
            // 呼吸缩放：0.97 ~ 1.03
            final breatheScale = 1.0 + 0.03 * sin(_breatheController.value * pi);
            final totalScale = pulseScale * breatheScale;

            // 红光闪烁透明度
            final flashOpacity = isUrgent ? _flashController.value * 0.3 : 0.0;

            return Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Stack(
                children: [
                  // 红光边框闪烁
                  if (isUrgent)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: flashOpacity),
                            width: 8,
                          ),
                        ),
                      ),
                    ),
                  // 中心数字
                  Center(
                    child: Transform.scale(
                      scale: totalScale,
                      child: Text(
                        '${widget.remaining}',
                        style: TextStyle(
                          fontSize: 200,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: isUrgent ? AppColors.danger : Colors.white,
                          shadows: [
                            Shadow(
                              color: (isUrgent ? AppColors.danger : color)
                                  .withValues(alpha: 0.8),
                              blurRadius: isUrgent ? 60 : 30,
                            ),
                            if (isUrgent)
                              Shadow(
                                color: AppColors.danger.withValues(alpha: 0.4),
                                blurRadius: 100,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
