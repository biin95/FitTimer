import 'package:flutter_test/flutter_test.dart';
import 'package:fittimer/services/interval_timer_service.dart';
import 'package:fittimer/models/interval_segment.dart';

void main() {
  group('IntervalTimerService pause/resume', () {
    late IntervalTimerService service;

    setUp(() {
      service = IntervalTimerService();
    });

    tearDown(() {
      service.dispose();
    });

    test('pause stops timer, resume restarts it', () async {
      final segments = [
        IntervalSegment(sortOrder: 0, type: 'exercise', durationSec: 10),
      ];

      service.start(segments, 1);
      expect(service.isRunning, true);
      expect(service.isPaused, false);
      expect(service.remaining, 10);

      // 等 2 秒
      await Future.delayed(const Duration(seconds: 2));
      expect(service.remaining, 8);

      // 暂停
      service.pause();
      expect(service.isPaused, true);
      final remainingAfterPause = service.remaining;

      // 等 2 秒，remaining 不变
      await Future.delayed(const Duration(seconds: 2));
      expect(service.remaining, remainingAfterPause);

      // 恢复
      service.resume();
      expect(service.isPaused, false);

      // 等 2 秒，remaining 继续减少
      await Future.delayed(const Duration(seconds: 2));
      expect(service.remaining, lessThan(remainingAfterPause));
    });

    test('multiple pause/resume cycles work correctly', () async {
      final segments = [
        IntervalSegment(sortOrder: 0, type: 'exercise', durationSec: 10),
      ];

      service.start(segments, 1);

      // 第一次暂停/恢复
      await Future.delayed(const Duration(seconds: 1));
      service.pause();
      await Future.delayed(const Duration(milliseconds: 100));
      service.resume();

      // 第二次暂停/恢复
      await Future.delayed(const Duration(seconds: 1));
      service.pause();
      await Future.delayed(const Duration(milliseconds: 100));
      service.resume();

      // 验证仍在运行
      expect(service.isRunning, true);
      expect(service.isPaused, false);
      expect(service.remaining, lessThan(10));
    });
  });
}
