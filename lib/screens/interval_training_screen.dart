import 'package:flutter/material.dart';
import '../models/interval_segment.dart';
import '../theme/app_colors.dart';
import '../services/interval_timer_service.dart';
import '../services/sound_service.dart';
import '../services/notification_service.dart';
import '../services/log_service.dart';
import '../widgets/countdown_overlay.dart';

class IntervalTrainingScreen extends StatefulWidget {
  final String trainingName;
  final List<IntervalSegment> segments;
  final int rounds;

  const IntervalTrainingScreen({
    super.key,
    required this.trainingName,
    required this.segments,
    required this.rounds,
  });

  @override
  State<IntervalTrainingScreen> createState() => _IntervalTrainingScreenState();
}

class _IntervalTrainingScreenState extends State<IntervalTrainingScreen> with WidgetsBindingObserver {
  final IntervalTimerService _timerService = IntervalTimerService();
  final SoundService _soundService = SoundService();
  final NotificationService _notif = NotificationService();

  bool _isCompleted = false;
  int _completedRounds = 0;
  DateTime? _trainingStartTime;
  bool _userPaused = false; // 用户手动暂停标志
  bool _isAppActive = true; // App 是否在前台（防止浮窗切换时 Semantics 自动触发 skip）

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trainingStartTime = DateTime.now();

    // 先同步启动计时器，确保首次 build 时 _remaining 已是正确值
    _timerService.onSegmentComplete = _onSegmentComplete;
    _timerService.onRoundComplete = _onRoundComplete;
    _timerService.onTrainingComplete = _onTrainingComplete;
    _timerService.addListener(_onTimerUpdate);
    _timerService.start(widget.segments, widget.rounds);

    // 异步初始化音效和通知（不阻塞 UI）
    _initServices();
  }

  Future<void> _initServices() async {
    await _soundService.initialize();
    await _notif.initialize();
  }

  void _onTimerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSegmentComplete() {
    if (!mounted) return;

    log.log('IntervalTraining', '段完成: segment=${_timerService.currentSegmentIndex} round=${_timerService.currentRound}/${_timerService.totalRounds}');

    // 判断是否是最后一轮最后一个段
    final isLastSegment = _timerService.currentSegmentIndex >= _timerService.totalSegments - 1;
    final isLastRound = _timerService.currentRound >= _timerService.totalRounds;

    // 最后一轮最后一个动作不播提示音
    if (!(isLastSegment && isLastRound)) {
      _soundService.playEndAlert();
    }

    // 显示通知
    final nextSegment = _timerService.nextSegment;
    if (nextSegment != null) {
      _notif.showRestCountdown(
        exerciseName: nextSegment.displayName,
        totalSeconds: nextSegment.durationSec,
        remainingSeconds: nextSegment.durationSec,
      );
    }
  }

  void _onRoundComplete() {
    _completedRounds++;
  }

  void _onTrainingComplete() {
    log.log('IntervalTraining', '训练完成!');

    setState(() {
      _isCompleted = true;
    });

    // 播放完成音效
    _soundService.playEndAlert();

    // 清除通知
    _notif.cancelAll();

    // 显示完成对话框
    _showCompleteDialog();
  }

  /// 构建返回给上一级的结果数据
  Map<String, dynamic> _buildResult({required bool completed}) {
    // 计算运动段总时长
    int exerciseDuration = 0;
    for (final seg in widget.segments) {
      if (seg.isExercise) {
        exerciseDuration += seg.durationSec;
      }
    }
    final totalExerciseDuration = exerciseDuration * widget.rounds;
    // 总时长（含休息）
    final totalDuration = widget.segments.fold(0, (sum, s) => sum + s.durationSec) * widget.rounds;
    final actualRounds = completed ? widget.rounds : _completedRounds;

    return {
      'trainingName': widget.trainingName,
      'rounds': actualRounds,
      'totalRounds': widget.rounds,
      'totalDuration': totalDuration,
      'exerciseDuration': totalExerciseDuration,
      'completed': completed,
      'startedAt': _trainingStartTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'completedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void _showCompleteDialog() {
    final result = _buildResult(completed: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 训练完成！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('训练名称: ${widget.trainingName}'),
            const SizedBox(height: 8),
            Text('完成轮数: ${widget.rounds} 轮'),
            const SizedBox(height: 8),
            Text('总时长: ${_formatDuration(result['totalDuration'] as int)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(result);
            },
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _togglePause() {
    if (_timerService.isPaused) {
      _userPaused = false;
      _timerService.resume();
      log.log('IntervalTraining', '用户手动恢复');
    } else {
      _userPaused = true;
      _timerService.pause();
      log.log('IntervalTraining', '用户手动暂停');
    }
  }

  void _skipSegment() {
    if (!_isAppActive) return; // 防止浮窗切换时 Semantics 自动触发
    _timerService.skipSegment();
  }

  void _stopTraining() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束训练？'),
        content: const Text('确定要提前结束训练吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('继续训练'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _timerService.stop();
              _notif.cancelAll();
              final result = _buildResult(completed: false);
              Navigator.of(context).pop(result);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('结束训练'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log.log('LC', '$state | running=${_timerService.isRunning} paused=${_timerService.isPaused} rem=${_timerService.remaining} userPaused=$_userPaused');

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _isAppActive = false; // 后台，禁止 skip
    } else if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
      if (_timerService.isRunning && !_timerService.isPaused) {
        _timerService.syncOnResume();
      }
      if (_isCompleted && mounted) {
        _showCompleteDialog();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerService.removeListener(_onTimerUpdate);
    _timerService.dispose();
    _notif.cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopTraining();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.trainingName),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _stopTraining,
            tooltip: '结束训练',
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // 当前段信息
                _buildCurrentSegmentInfo(),

                // 倒计时显示
                Expanded(
                  child: _buildCountdownDisplay(),
                ),

                // 进度信息
                _buildProgressInfo(),

                // 下一段预览
                _buildNextSegmentPreview(),

                // 控制按钮
                _buildControlButtons(),
              ],
            ),

            // 最后 10 秒全屏遮罩
            CountdownOverlay(
              remaining: _timerService.remaining,
              total: _timerService.currentSegment.durationSec,
              visible: _timerService.remaining <= 10 && _timerService.remaining > 0 && !_isCompleted,
              accentColor: _timerService.currentSegment.isExercise
                  ? AppColors.exerciseSegment
                  : AppColors.restSegment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSegmentInfo() {
    final segment = _timerService.currentSegment;
    final isExercise = segment.isExercise;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      color: isExercise
          ? AppColors.exerciseSegment.withValues(alpha: 0.2)
          : AppColors.restSegment.withValues(alpha: 0.2),
      child: Column(
        children: [
          Text(
            isExercise ? '🏃 运动' : '😴 休息',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isExercise ? AppColors.exerciseSegment : AppColors.restSegment,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '第 ${_timerService.currentSegmentIndex + 1} 段 / 共 ${_timerService.totalSegments} 段',
            style: TextStyle(fontSize: 16, color: AppColors.subtitle),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 大号倒计时
          Text(
            _timerService.formatted,
            style: TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: _timerService.remaining <= 5
                  ? AppColors.danger
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // 进度条
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: _timerService.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: AppColors.disabled,
              valueColor: AlwaysStoppedAnimation<Color>(
                _timerService.currentSegment.isExercise
                    ? AppColors.exerciseSegment
                    : AppColors.restSegment,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 暂停/恢复按钮
          if (!_isCompleted)
            IconButton(
              onPressed: _togglePause,
              icon: Icon(
                _timerService.isPaused ? Icons.play_arrow : Icons.pause,
                size: 48,
              ),
              tooltip: _timerService.isPaused ? '继续' : '暂停',
            ),
        ],
      ),
    );
  }

  Widget _buildProgressInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.repeat, size: 20),
          const SizedBox(width: 8),
          Text(
            '第 ${_timerService.currentRound} 轮 / 共 ${_timerService.totalRounds} 轮',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSegmentPreview() {
    final nextSegment = _timerService.nextSegment;

    return SizedBox(
      height: 48,
      child: nextSegment == null
          ? const SizedBox.shrink()
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  nextSegment.isExercise ? Icons.directions_run : Icons.hotel,
                  size: 20,
                  color: AppColors.subtitle,
                ),
                const SizedBox(width: 8),
                Text(
                  _timerService.nextSegmentDescription,
                  style: TextStyle(fontSize: 14, color: AppColors.subtitle),
                ),
              ],
            ),
    );
  }

  Widget _buildControlButtons() {
    if (_isCompleted) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 跳过按钮
            ElevatedButton.icon(
              onPressed: _skipSegment,
              icon: const Icon(Icons.skip_next),
              label: const Text('跳过'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.exerciseSegment,
                foregroundColor: AppColors.onColoredBadge,
              ),
            ),

            // 调整时间按钮
            Row(
              children: [
                IconButton(
                  onPressed: () => _timerService.adjustTime(-10),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: '-10秒',
                  iconSize: 32,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _timerService.adjustTime(10),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: '+10秒',
                  iconSize: 32,
                ),
              ],
            ),

            // 停止按钮
            ElevatedButton.icon(
              onPressed: _stopTraining,
              icon: const Icon(Icons.stop),
              label: const Text('停止'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.onColoredBadge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
