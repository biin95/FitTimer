import 'dart:math';
import 'package:flutter/material.dart';

/// 训练完成庆祝动画覆盖层
class CelebrationOverlay extends StatefulWidget {
  final bool visible;
  final VoidCallback? onDismiss;

  const CelebrationOverlay({
    super.key,
    required this.visible,
    this.onDismiss,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didUpdateWidget(CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _playCelebration();
    } else if (!widget.visible && oldWidget.visible) {
      _scaleController.reset();
      _confettiController.reset();
    }
  }

  void _playCelebration() {
    _scaleController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _confettiController]),
      builder: (context, child) {
        return Stack(
          children: [
            // 半透明背景
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                color: Colors.black54,
              ),
            ),

            // 彩花粒子
            ..._buildConfetti(),

            // 中心卡片
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildCelebrationCard(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCelebrationCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 庆祝图标
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),

          // 标题
          Text(
            '训练完成！',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          // 副标题
          Text(
            '太棒了，继续保持！💪',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // 确认按钮
          FilledButton(
            onPressed: widget.onDismiss,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('完成', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildConfetti() {
    final progress = _confettiController.value;
    if (progress == 0) return [];

    final random = Random(42); // 固定种子，保证一致性
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.yellow,
      Colors.cyan,
    ];

    return List.generate(30, (i) {
      final color = colors[i % colors.length];
      final startX = random.nextDouble();
      final endX = startX + (random.nextDouble() - 0.5) * 0.5;
      final size = random.nextDouble() * 8 + 4;
      final rotationSpeed = random.nextDouble() * 4 + 1;

      // 抛物线运动
      final x = startX + (endX - startX) * progress;
      final y = -0.3 + progress * 1.5 + sin(progress * pi * rotationSpeed) * 0.1;
      final opacity = (1 - progress).clamp(0.0, 1.0);

      return Positioned(
        left: MediaQuery.of(context).size.width * x,
        top: MediaQuery.of(context).size.height * y,
        child: Transform.rotate(
          angle: progress * pi * rotationSpeed,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size * 1.5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    });
  }
}
