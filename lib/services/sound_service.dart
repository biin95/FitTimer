import 'package:flutter/services.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const _channel = MethodChannel('com.fittimer/sound');
  bool _initialized = false;

  /// 初始化声音服务
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// 播放段切换提示音（2-3秒）
  Future<void> playSegmentChange() async {
    if (!_initialized) await initialize();

    try {
      await _channel.invokeMethod('playAlert');
    } catch (_) {
      // fallback: 连续播放系统音
      try {
        for (int i = 0; i < 3; i++) {
          await SystemSound.play(SystemSoundType.alert);
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (_) {}
    }
  }

  /// 播放训练完成音效
  Future<void> playTrainingComplete() async {
    if (!_initialized) await initialize();

    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // 忽略声音播放失败
    }
  }

  /// 释放资源
  void dispose() {
    _initialized = false;
  }
}
