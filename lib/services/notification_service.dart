import 'package:flutter/foundation.dart';

/// Notification service for rest timer alerts.
///
/// Phase 5 will implement full local notifications using
/// flutter_local_notifications. For now this is a stub.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Show a local notification when the rest timer finishes.
  /// Stub: logs to debug console. Will be implemented with
  /// flutter_local_notifications in phase 5.
  Future<void> showRestTimerNotification(int seconds) async {
    debugPrint('[NotificationService] Rest timer complete ($seconds s) — notification stub');
  }

  /// Initialize notification permissions and channels.
  /// Stub for phase 5.
  Future<void> initialize() async {
    debugPrint('[NotificationService] Initialized (stub)');
  }
}
