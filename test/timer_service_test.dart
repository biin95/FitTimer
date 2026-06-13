import 'package:flutter_test/flutter_test.dart';
import 'package:fittimer/services/timer_service.dart';

void main() {
  group('TimerService', () {
    late TimerService timer;

    setUp(() {
      timer = TimerService();
    });

    tearDown(() {
      timer.dispose();
    });

    test('初始状态应该是未运行且剩余0秒', () {
      expect(timer.isRunning, false);
      expect(timer.remaining, 0);
      expect(timer.formatted, '00:00');
    });

    test('start() 应该启动倒计时', () {
      timer.start(60);
      expect(timer.isRunning, true);
      expect(timer.remaining, 60);
      expect(timer.formatted, '01:00');
    });

    test('cancel() 应该停止倒计时并重置', () {
      timer.start(60);
      timer.cancel();
      expect(timer.isRunning, false);
      expect(timer.remaining, 0);
    });

    test('adjustTime() 应该增加剩余时间', () {
      timer.start(60);
      timer.adjustTime(10);
      expect(timer.remaining, 70);
      expect(timer.formatted, '01:10');
    });

    test('adjustTime() 应该减少剩余时间', () {
      timer.start(60);
      timer.adjustTime(-10);
      expect(timer.remaining, 50);
    });

    test('adjustTime() 负数调整到0时应该触发完成', () {
      bool completed = false;
      timer.onComplete = () => completed = true;
      timer.start(5);
      timer.adjustTime(-10);
      expect(timer.isRunning, false);
      expect(timer.remaining, 0);
      expect(completed, true);
    });

    test('adjustTime() 不会使剩余时间低于0', () {
      timer.start(60);
      timer.adjustTime(-9999);
      expect(timer.remaining, 0);
      expect(timer.isRunning, false);
    });

    test('cancel() 后 adjustTime() 不应生效', () {
      timer.start(60);
      timer.cancel();
      timer.adjustTime(10);
      expect(timer.remaining, 0);
    });

    test('cancel() 后 start() 应该重新开始', () {
      timer.start(60);
      timer.cancel();
      timer.start(30);
      expect(timer.isRunning, true);
      expect(timer.remaining, 30);
    });

    test('syncOnResume() 在未运行时不应报错', () {
      // 应该安全地什么都不做
      timer.syncOnResume();
      expect(timer.isRunning, false);
    });

    test('格式化小于10秒时显示为 00:0X', () {
      timer.start(9);
      expect(timer.formatted, '00:09');
    });

    test('格式化5分钟显示为 05:00', () {
      timer.start(300);
      expect(timer.formatted, '05:00');
    });

    test('多次 start() 应该重置', () {
      timer.start(60);
      timer.start(30);
      expect(timer.remaining, 30);
    });

    test('应该通知监听者', () {
      int notifyCount = 0;
      timer.addListener(() => notifyCount++);
      timer.start(60);
      expect(notifyCount, greaterThan(0));
    });
  });
}
