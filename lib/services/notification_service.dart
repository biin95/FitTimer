import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// 通知服务：休息倒计时 + 震动提醒
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _restChannelId = 'fittimer_rest';
  static const _restChannelName = '组间休息';
  static const _reminderChannelId = 'fittimer_reminder';
  static const _reminderChannelName = '训练提醒';

  static const _restNotificationId = 1001;
  static const _reminderNotificationId = 2001;

  /// 初始化通知权限和频道
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _restChannelId,
          _restChannelName,
          description: '组间休息倒计时通知',
          importance: Importance.low,
          enableVibration: false,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _reminderChannelId,
          _reminderChannelName,
          description: '休息结束震动提醒',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
    }

    // Android 13+ 需要请求通知权限
    final androidPlugin2 = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin2 != null) {
      final granted = await androidPlugin2.requestNotificationsPermission();
      debugPrint('[NotificationService] 通知权限: $granted');
    }

    debugPrint('[NotificationService] 已初始化');
  }

  /// 显示休息倒计时通知（带进度条）
  Future<void> showRestCountdown({
    required String exerciseName,
    required int totalSeconds,
    required int remainingSeconds,
  }) async {
    debugPrint('[NotificationService] showRestCountdown: $exerciseName, 剩余${remainingSeconds}秒');
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final androidDetails = AndroidNotificationDetails(
      _restChannelId,
      _restChannelName,
      channelDescription: '组间休息倒计时通知',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showProgress: true,
      maxProgress: totalSeconds,
      progress: totalSeconds - remainingSeconds,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _restNotificationId,
      '$exerciseName 休息中',
      '剩余 $timeStr',
      details,
    );
  }

  /// 休息结束时显示震动提醒通知
  Future<void> showVibrationReminder(String exerciseName) async {
    debugPrint('[NotificationService] showVibrationReminder: $exerciseName');
    final androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      channelDescription: '休息结束震动提醒',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _reminderNotificationId,
      '休息结束',
      '$exerciseName 准备开始下一组',
      details,
    );
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 取消休息倒计时通知
  Future<void> cancelRestNotification() async {
    await _plugin.cancel(_restNotificationId);
  }

  /// 取消提醒通知
  Future<void> cancelReminderNotification() async {
    await _plugin.cancel(_reminderNotificationId);
  }
}
