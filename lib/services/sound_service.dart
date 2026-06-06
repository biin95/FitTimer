import 'package:flutter/services.dart';
import 'log_service.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const _soundChannel = MethodChannel('com.fittimer/sound');
  bool _nativeAvailable = true; // 假设原生可用，失败后切换

  /// 初始化（单例模式下无需操作，保留兼容性）
  Future<void> initialize() async {}

  /// 播放倒计时结束提示音（2-3 秒强烈音效）
  /// 优先使用原生 ToneGenerator（不受音频焦点限制，听歌时也能响）
  Future<void> playEndAlert() async {
    if (_nativeAvailable) {
      try {
        await _soundChannel.invokeMethod('playAlert');
        log.log('SoundService', '原生提示音播放完成');
        return;
      } catch (e) {
        log.log('SoundService', '原生提示音失败，切换到 SystemSound: $e');
        _nativeAvailable = false;
      }
    }

    // fallback: 连续播放系统提示音
    try {
      for (int i = 0; i < 8; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {}
  }

  /// 释放资源（单例模式下实际不需要）
  void dispose() {}
}
