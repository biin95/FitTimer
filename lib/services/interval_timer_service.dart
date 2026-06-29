import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/interval_segment.dart';

class IntervalTimerService extends ChangeNotifier {
  // ── 状态 ──
  List<IntervalSegment> _segments = [];
  int _currentSegmentIndex = 0;
  int _currentRound = 1;
  int _totalRounds = 1;
  int _remaining = 0; // 当前段剩余秒数
  bool _isRunning = false;
  bool _isPaused = false;
  DateTime? _endTime; // 绝对结束时间（用于息屏恢复）
  Timer? _timer;

  // ── 回调 ──
  VoidCallback? onSegmentComplete;
  VoidCallback? onRoundComplete;
  VoidCallback? onTrainingComplete;

  // ── Getter ──
  int get currentSegmentIndex => _currentSegmentIndex;
  IntervalSegment get currentSegment {
    if (_segments.isEmpty || _currentSegmentIndex >= _segments.length) {
      return IntervalSegment(sortOrder: 0, type: 'rest', durationSec: 0);
    }
    return _segments[_currentSegmentIndex];
  }
  int get remaining => _remaining;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get currentRound => _currentRound;
  int get totalRounds => _totalRounds;
  int get totalSegments => _segments.length;

  /// 格式化剩余时间为 MM:SS
  String get formatted {
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 当前段进度 (0.0 - 1.0)
  double get progress {
    if (_segments.isEmpty || _currentSegmentIndex >= _segments.length) return 0.0;
    final totalDuration = _segments[_currentSegmentIndex].durationSec;
    if (totalDuration <= 0) return 0.0;
    return 1.0 - (_remaining / totalDuration);
  }

  /// 整体进度 (0.0 - 1.0)
  double get overallProgress {
    if (_segments.isEmpty || _totalRounds <= 0) return 0.0;

    // 计算已完成的段数
    int completedSegments = 0;
    for (int round = 1; round < _currentRound; round++) {
      completedSegments += _segments.length;
    }
    completedSegments += _currentSegmentIndex;

    // 计算总段数
    final totalSegments = _segments.length * _totalRounds;

    // 加上当前段的进度
    final currentSegmentProgress = progress / totalSegments;

    return (completedSegments / totalSegments) + currentSegmentProgress;
  }

  /// 获取下一段信息
  IntervalSegment? get nextSegment {
    if (_segments.isEmpty) return null;

    if (_currentSegmentIndex < _segments.length - 1) {
      // 还有下一段
      return _segments[_currentSegmentIndex + 1];
    } else if (_currentRound < _totalRounds) {
      // 还有下一轮
      return _segments[0];
    }
    return null;
  }

  /// 获取下一段的描述
  String get nextSegmentDescription {
    final next = nextSegment;
    if (next == null) return '训练结束';

    if (_currentSegmentIndex < _segments.length - 1) {
      return '下一段: ${next.displayName} ${next.formattedDuration}';
    } else if (_currentRound < _totalRounds) {
      return '下一轮: ${next.displayName} ${next.formattedDuration}';
    }
    return '训练结束';
  }

  /// 启动间歇训练
  void start(List<IntervalSegment> segments, int rounds) {
    if (segments.isEmpty) return;

    _segments = List.from(segments);
    _totalRounds = rounds;
    _currentRound = 1;
    _currentSegmentIndex = 0;
    _isRunning = true;
    _isPaused = false;

    _startCurrentSegment();
  }

  /// 启动当前段
  void _startCurrentSegment() {
    if (_segments.isEmpty || _currentSegmentIndex >= _segments.length) {
      _isRunning = false;
      notifyListeners();
      return;
    }

    final segment = _segments[_currentSegmentIndex];
    _remaining = segment.durationSec;
    _endTime = DateTime.now().add(Duration(seconds: _remaining));

    _startTimerLoop();

    notifyListeners();
  }

  /// 启动/重启 timer 循环（不重置 _remaining，供 syncOnResume 使用）
  void _startTimerLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  /// timer 每秒回调：从墙钟计算剩余时间
  void _onTimerTick(Timer timer) {
    final wallRemaining = _endTime!.difference(DateTime.now()).inSeconds;
    if (wallRemaining <= 0) {
      timer.cancel();
      _timer = null;
      _remaining = 0;
      notifyListeners();
      _onSegmentComplete();
    } else {
      _remaining = wallRemaining;
      notifyListeners();
    }
  }

  /// 段完成处理
  void _onSegmentComplete() {
    onSegmentComplete?.call();

    // 检查是否还有下一段
    if (_currentSegmentIndex < _segments.length - 1) {
      // 还有下一段
      _currentSegmentIndex++;
      _startCurrentSegment();
    } else if (_currentRound < _totalRounds) {
      // 还有下一轮
      _currentRound++;
      _currentSegmentIndex = 0;
      onRoundComplete?.call();
      _startCurrentSegment();
    } else {
      // 训练完成
      _isRunning = false;
      onTrainingComplete?.call();
      notifyListeners();
    }
  }

  /// 暂停
  void pause() {
    if (!_isRunning || _isPaused) return;

    _timer?.cancel();
    _timer = null;
    _isPaused = true;
    notifyListeners();
  }

  /// 恢复
  void resume() {
    if (!_isRunning || !_isPaused) return;

    _isPaused = false;
    _endTime = DateTime.now().add(Duration(seconds: _remaining));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        _timer = null;
        _remaining = 0;
        notifyListeners();
        _onSegmentComplete();
      } else {
        _remaining--;
        notifyListeners();
      }
    });

    notifyListeners();
  }

  /// 跳过当前段
  void skipSegment() {
    if (!_isRunning) return;

    _timer?.cancel();
    _timer = null;
    _remaining = 0;
    notifyListeners();
    _onSegmentComplete();
  }

  /// 停止训练
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _isPaused = false;
    _remaining = 0;
    _segments = [];
    _currentSegmentIndex = 0;
    _currentRound = 1;
    notifyListeners();
  }

  /// 息屏/浮窗/分屏恢复时同步状态
  void syncOnResume() {
    if (!_isRunning || _isPaused || _endTime == null) return;

    // 先取消旧 timer，防止积压的 tick 继续触发（浮窗/分屏恢复时常见问题）
    _timer?.cancel();
    _timer = null;

    final now = DateTime.now();
    final remaining = _endTime!.difference(now).inSeconds;


    if (remaining <= 0) {
      // 倒计时已结束
      _remaining = 0;
      notifyListeners();
      _onSegmentComplete();
    } else {
      // 只更新剩余时间 + _endTime，不调 _startCurrentSegment（会重置 _remaining）
      _remaining = remaining;
      _endTime = DateTime.now().add(Duration(seconds: _remaining));
      _startTimerLoop();
      notifyListeners();
    }
  }

  /// 调整当前段时间（+/-秒）
  void adjustTime(int seconds) {
    if (!_isRunning) return;

    _remaining = (_remaining + seconds).clamp(0, 9999);
    _endTime = DateTime.now().add(Duration(seconds: _remaining));

    if (_remaining <= 0) {
      _timer?.cancel();
      _timer = null;
      notifyListeners();
      _onSegmentComplete();
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
