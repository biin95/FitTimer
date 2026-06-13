import 'package:flutter_test/flutter_test.dart';
import 'package:fittimer/services/interval_timer_service.dart';
import 'package:fittimer/models/interval_segment.dart';

void main() {
  group('IntervalTimerService', () {
    late IntervalTimerService timer;

    setUp(() {
      timer = IntervalTimerService();
    });

    tearDown(() {
      timer.dispose();
    });

    // Helper: create a simple work/rest segment list
    List<IntervalSegment> createSegments() {
      return [
        IntervalSegment(sortOrder: 0, type: 'work', durationSec: 3, name: '深蹲'),
        IntervalSegment(sortOrder: 1, type: 'rest', durationSec: 2, name: '休息'),
      ];
    }

    test('初始状态应该是停止', () {
      expect(timer.isRunning, false);
      expect(timer.isPaused, false);
      expect(timer.currentRound, 1);
      expect(timer.currentSegmentIndex, 0);
    });

    test('start() 应该启动训练', () {
      timer.start(createSegments(), 1);
      expect(timer.isRunning, true);
      expect(timer.currentRound, 1);
      expect(timer.currentSegmentIndex, 0);
      expect(timer.remaining, 3);
    });

    test('pause() 应该暂停倒计时', () {
      timer.start(createSegments(), 1);
      timer.pause();
      expect(timer.isPaused, true);
      expect(timer.remaining, greaterThan(0));
    });

    test('resume() 应该恢复倒计时', () {
      timer.start(createSegments(), 1);
      timer.pause();
      timer.resume();
      expect(timer.isPaused, false);
      expect(timer.isRunning, true);
    });

    test('stop() 应该重置所有状态', () {
      timer.start(createSegments(), 3);
      timer.stop();
      expect(timer.isRunning, false);
      expect(timer.isPaused, false);
      expect(timer.currentRound, 1);
      expect(timer.currentSegmentIndex, 0);
    });

    test('skipSegment() 应该跳到下一段', () {
      timer.start(createSegments(), 1);
      timer.skipSegment();
      expect(timer.currentSegmentIndex, 1);
    });

    test('跳过最后一段应该触发训练完成', () {
      bool completed = false;
      timer.onTrainingComplete = () => completed = true;
      timer.start(createSegments(), 1);
      timer.skipSegment(); // 跳到 rest
      timer.skipSegment(); // 训练完成
      expect(completed, true);
      expect(timer.isRunning, false);
    });

    test('多轮训练应该正确轮转', () {
      int roundCompletes = 0;
      timer.onRoundComplete = () => roundCompletes++;
      timer.start(createSegments(), 2);
      timer.skipSegment(); // round 1 work done, rest
      timer.skipSegment(); // round 1 complete → round 2
      expect(timer.currentRound, 2);
      expect(roundCompletes, 1);
    });

    test('nextSegment 应该返回正确值', () {
      timer.start(createSegments(), 2);
      expect(timer.nextSegment, isNotNull);
      expect(timer.nextSegment!.type, 'rest');
    });

    test('nextSegment 在最后一段应该返回下一轮的第一段', () {
      timer.start(createSegments(), 2);
      timer.skipSegment(); // 跳到 rest
      // 现在是 rest 段，下一段是下一轮的第一个
      expect(timer.nextSegment, isNotNull);
      expect(timer.nextSegment!.type, 'work');
    });

    test('adjustTime() 应该调整剩余时间', () {
      timer.start(createSegments(), 1);
      timer.adjustTime(10);
      expect(timer.remaining, 13);
    });

    test('未运行时 adjustTime() 不应生效', () {
      timer.adjustTime(10);
      expect(timer.remaining, 0);
    });

    test('空的 segments 列表应该不启动', () {
      timer.start([], 1);
      expect(timer.isRunning, false);
    });

    test('progress 在开始时应该为 0', () {
      timer.start(createSegments(), 1);
      expect(timer.progress, closeTo(0.0, 0.01));
    });

    test('overallProgress 在开始时应该接近 0', () {
      timer.start(createSegments(), 1);
      expect(timer.overallProgress, closeTo(0.0, 0.01));
    });

    test('currentSegment 应该返回正确的段', () {
      timer.start(createSegments(), 1);
      expect(timer.currentSegment.name, '深蹲');
    });

    test('formatted 应该正确格式化时间', () {
      timer.start(createSegments(), 1);
      expect(timer.formatted, '00:03');
    });
  });
}
