import 'package:flutter/material.dart';

/// 列表 stagger 入场动画包装器
/// 将子组件列表包装为依次从下方滑入 + 淡入的动画效果
class StaggerAnimationList extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay; // 每个 item 之间的延迟
  final Duration itemDuration; // 单个 item 的动画时长
  final double slideOffset; // 滑入距离

  const StaggerAnimationList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.slideOffset = 30.0,
  });

  @override
  State<StaggerAnimationList> createState() => _StaggerAnimationListState();
}

class _StaggerAnimationListState extends State<StaggerAnimationList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.itemDuration.inMilliseconds +
            widget.itemDelay.inMilliseconds * widget.children.length,
      ),
    );
    // 延迟一帧启动，确保 layout 完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasAnimated) {
        _hasAnimated = true;
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(StaggerAnimationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      // 列表长度变化时重新播放动画
      _controller.duration = Duration(
        milliseconds: widget.itemDuration.inMilliseconds +
            widget.itemDelay.inMilliseconds * widget.children.length,
      );
      _controller.reset();
      _hasAnimated = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAnimated) {
          _hasAnimated = true;
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.children.length, (index) {
        final itemStart =
            (widget.itemDelay.inMilliseconds * index) / _controller.duration!.inMilliseconds;
        final itemEnd =
            (widget.itemDelay.inMilliseconds * index + widget.itemDuration.inMilliseconds) /
                _controller.duration!.inMilliseconds;

        final curvedInterval = CurvedAnimation(
          parent: _controller,
          curve: Interval(itemStart.clamp(0.0, 1.0), itemEnd.clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        );

        return AnimatedBuilder(
          animation: curvedInterval,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, widget.slideOffset * (1 - curvedInterval.value)),
              child: Opacity(
                opacity: curvedInterval.value,
                child: child,
              ),
            );
          },
          child: widget.children[index],
        );
      }),
    );
  }
}

/// 单个 widget 的入场动画包装（用于 ListView.builder 中的单个 item）
class StaggerItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final double slideOffset;

  const StaggerItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 400),
    this.slideOffset = 30.0,
  });

  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // 根据 index 延迟启动
    Future.delayed(Duration(milliseconds: widget.delay.inMilliseconds * widget.index), () {
      if (mounted && !_hasAnimated) {
        _hasAnimated = true;
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
