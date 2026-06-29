import 'dart:async';
import 'package:flutter/material.dart';
import '../services/log_service.dart';

/// 独立管理的组间休息倒计时条。
///
/// 内部持有 Timer.periodic，每秒 tick 只触发自身重建，
/// 避免父级全树 rebuild。
class RestTimerBar extends StatefulWidget {
  final String exerciseName;
  final int initialSeconds;

  /// 每秒回调（剩余秒数），父级可在此更新通知栏
  final ValueChanged<int>? onTick;

  /// 倒计时启动时的回调，传递绝对结束时间，父级可在此预定原生闹钟
  final ValueChanged<DateTime>? onStarted;

  /// 倒计时结束回调
  final VoidCallback? onRestEnd;

  /// 倒计时被用户取消/跳过
  final VoidCallback? onCancelled;

  const RestTimerBar({
    super.key,
    required this.exerciseName,
    required this.initialSeconds,
    this.onTick,
    this.onStarted,
    this.onRestEnd,
    this.onCancelled,
  });

  @override
  State<RestTimerBar> createState() => RestTimerBarState();
}

class RestTimerBarState extends State<RestTimerBar>
    with WidgetsBindingObserver {
  int _remaining = 0;
  int _total = 0;
  Timer? _timer;
  DateTime? _endTime;

  // ── Lifecycle ──

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialSeconds > 0) {
      _start(widget.initialSeconds);
    }
  }

  @override
  void didUpdateWidget(RestTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRunning && widget.initialSeconds > 0) {
      _start(widget.initialSeconds);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncOnResume();
    }
  }

  // ── Public API ──

  bool get _isRunning => _timer != null && _remaining > 0;
  int get remaining => _remaining;

  /// 外部可调：重启倒计时
  void start(int seconds) => _start(seconds);

  /// 外部可调：调整剩余时间
  void adjustTime(int delta) {
    if (!_isRunning) return;
    _remaining = (_remaining + delta).clamp(0, 9999);
    _endTime = DateTime.now().add(Duration(seconds: _remaining));
    widget.onTick?.call(_remaining);
    if (_remaining <= 0) {
      _finish();
    } else {
      setState(() {});
    }
  }

  /// 外部可调：取消/跳过
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _remaining = 0;
    _endTime = null;
    widget.onCancelled?.call();
    setState(() {});
  }

  // ── Internal ──

  void _start(int seconds) {
    _timer?.cancel();
    _remaining = seconds;
    _total = seconds;
    _endTime = DateTime.now().add(Duration(seconds: seconds));
    widget.onStarted?.call(_endTime!);
    widget.onTick?.call(_remaining);
    setState(() {});
    _startTimer();
  }

  /// 创建 timer（内部方法，供 _start / _syncOnResume 共用）
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  void _onTimerTick(Timer timer) {
    final wallRemaining = _endTime!.difference(DateTime.now()).inSeconds;
    widget.onTick?.call(_remaining);
    if (wallRemaining <= 0) {
      _timer?.cancel();
      _timer = null;
      _remaining = 0;
      _endTime = null;
      _finish();
    } else {
      _remaining = wallRemaining;
      setState(() {});
    }
  }

  void _syncOnResume() {
    if (_endTime == null || _remaining <= 0) return;

    // 先取消旧 timer，防止积压的 tick 继续触发（浮窗/分屏恢复时常见问题）
    _timer?.cancel();
    _timer = null;

    final now = DateTime.now();
    final remaining = _endTime!.difference(now).inSeconds;

    log.log('RestBar', 'syncOnResume: oldRem=$_remaining newRem=$remaining');

    if (remaining <= 0) {
      _remaining = 0;
      _endTime = null;
      widget.onRestEnd?.call();
      setState(() {});
    } else {
      _remaining = remaining;
      _endTime = DateTime.now().add(Duration(seconds: _remaining));
      widget.onTick?.call(_remaining);
      setState(() {});
      _startTimer();
    }
  }

  void _finish() {
    widget.onRestEnd?.call();
    setState(() {});
  }

  // ── UI ──

  String get _formatted {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => _total > 0 ? _remaining / _total : 0.0;

  @override
  Widget build(BuildContext context) {
    final isCountingDown = _remaining > 0;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isCountingDown
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      child: isCountingDown
          ? Row(
              children: [
                const Icon(Icons.timer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: _progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatted,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove, size: 20),
                  onPressed: () => adjustTime(-10),
                  tooltip: '-10秒',
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => adjustTime(10),
                  tooltip: '+10秒',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: cancel,
                ),
              ],
            )
          : Center(
              child: Text(
                widget.exerciseName.isEmpty
                    ? '完成一组后开始休息'
                    : '休息 ${widget.exerciseName}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
    );
  }
}
