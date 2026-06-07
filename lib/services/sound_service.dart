import 'package:flutter/services.dart';
import 'log_service.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const _soundChannel = MethodChannel('com.fittimer/sound');

  /// 初始化（保留接口兼容）
  Future<void> initialize() async {}

  /// 播放倒计时结束提示音
  Future<void> playEndAlert() async {
    try {
      await _soundChannel.invokeMethod('playAlert');
    } catch (e) {
      log.log('SoundService', '播放失败: $e');
    }
  }

  /// 释放资源
  void dispose() {}
}
