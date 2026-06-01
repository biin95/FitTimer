import 'dart:async';
import 'package:flutter/foundation.dart';

/// A countdown timer service for rest periods between sets.
///
/// Usage:
/// ```dart
/// final timer = TimerService();
/// timer.onComplete = () => print('done!');
/// timer.start(60); // 60 seconds
/// // UI listens to timer.remaining and timer.isRunning
/// timer.adjustTime(10); // +10 seconds
/// timer.adjustTime(-10); // -10 seconds
/// timer.cancel();
/// ```
class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _remaining = 0; // seconds
  bool _isRunning = false;
  DateTime? _endTime; // 绝对结束时间，用于息屏恢复

  /// Callback fired when countdown reaches 0.
  VoidCallback? onComplete;

  /// Current remaining seconds.
  int get remaining => _remaining;

  /// Whether the timer is actively counting down.
  bool get isRunning => _isRunning;

  /// Formatted remaining time as "MM:SS".
  String get formatted {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Start a countdown for [durationSeconds].
  /// If already running, restarts with the new duration.
  void start(int durationSeconds) {
    cancel();
    _remaining = durationSeconds;
    _isRunning = true;
    _endTime = DateTime.now().add(Duration(seconds: durationSeconds));
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining--;
      notifyListeners();

      if (_remaining <= 0) {
        _timer?.cancel();
        _timer = null;
        _isRunning = false;
        _endTime = null;
        _remaining = 0;
        notifyListeners();
        onComplete?.call();
      }
    });
  }

  /// 同步剩余时间（用于 app 从后台恢复时调用）
  void syncOnResume() {
    if (_endTime == null || !_isRunning) return;
    final now = DateTime.now();
    final remaining = _endTime!.difference(now).inSeconds;
    if (remaining <= 0) {
      // 倒计时已结束
      _timer?.cancel();
      _timer = null;
      _isRunning = false;
      _endTime = null;
      _remaining = 0;
      notifyListeners();
      onComplete?.call();
    } else {
      _remaining = remaining;
      notifyListeners();
    }
  }

  /// Adjust remaining time by [seconds] (positive to add, negative to subtract).
  /// Multiple calls accumulate. Does not restart the timer.
  void adjustTime(int seconds) {
    if (!_isRunning) return;
    _remaining = (_remaining + seconds).clamp(0, 9999);
    _endTime = DateTime.now().add(Duration(seconds: _remaining));
    notifyListeners();

    // If adjustment brought it to 0, fire complete immediately
    if (_remaining <= 0) {
      _timer?.cancel();
      _timer = null;
      _isRunning = false;
      _endTime = null;
      notifyListeners();
      onComplete?.call();
    }
  }

  /// Cancel the running timer and reset state.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _endTime = null;
    _remaining = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
