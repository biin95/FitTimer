import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workout_record.dart';
import '../theme/app_colors.dart';
import '../widgets/badge_number.dart';
import '../widgets/delete_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/move_arrows.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/countdown_overlay.dart';
import '../models/exercise_record.dart';
import '../models/workout_template.dart';
import '../models/template_exercise.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import 'interval_config_screen.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final DateTime date;

  const WorkoutSessionScreen({super.key, required this.date});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> with WidgetsBindingObserver {
  static const _vibrateChannel = MethodChannel('com.fittimer/vibrate');
  static const _restServiceChannel = MethodChannel('com.fittimer/rest_service');

  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();

  WorkoutRecord? _workoutRecord;
  List<_SessionExercise> _exercises = [];
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  bool _draftSaved = false;
  bool _isSorting = false; // 排序模式

  // Rest timer
  int _restRemaining = 0;
  int _restTotal = 0;
  Timer? _restTimer;
  Timer? _reminderTimer;
  String _restExerciseName = '';
  int _reminderDuration = 3;
  int _restDuration = 0; // total rest duration for notification
  DateTime? _restEndTime; // 绝对结束时间，用于息屏恢复

  // Notification service
  final NotificationService _notif = NotificationService();
  final SoundService _soundService = SoundService();

  // Highlight state
  int? _highlightedExerciseIndex;
  int? _highlightedSetIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notif.initialize();
    _loadOrCreateWorkout();
    _checkExactAlarmPermission();
  }

  /// 检查精确闹钟权限，如果没有则提示用户开启
  Future<void> _checkExactAlarmPermission() async {
    final canSchedule = await _notif.canScheduleExactAlarms();
    if (!canSchedule && mounted) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('需要精确闹钟权限'),
          content: const Text('为了在息屏时准确提醒休息结束，请开启"精确闹钟"权限。\n\n点击"去开启"会跳转到设置页面。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('稍后'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去开启'),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        await _notif.openExactAlarmSettings();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _reminderTimer?.cancel();
    _notif.cancelAll();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App 从后台恢复，用绝对时间重新计算剩余时间
      _syncRestTimerOnResume();
    }
  }

  /// App 恢复时同步倒计时状态
  void _syncRestTimerOnResume() {
    if (_restEndTime == null || _restRemaining <= 0) return;

    final now = DateTime.now();
    final remaining = _restEndTime!.difference(now).inSeconds;

    if (remaining <= 0) {
      // 倒计时已结束
      _restTimer?.cancel();
      _restTimer = null;
      _restEndTime = null;
      setState(() {
        _restRemaining = 0;
      });
      // 清除所有通知（倒计时 + 提醒）
      _notif.cancelRestNotification();
      _notif.cancelReminderNotification();
      // 不调用 _startReminder！
      // AlarmManager 闹钟会自动触发 RestAlarmReceiver 处理震动和通知
      // 如果闹钟已触发，RestAlarmReceiver 已经处理过了
      // 如果闹钟还没触发，它会在稍后触发
      log.log('VIBRATE', 'App恢复，倒计时已结束，等待 RestAlarmReceiver 处理');
    } else {
      // 更新剩余时间（不重启 Timer，只同步 UI）
      setState(() {
        _restRemaining = remaining;
      });
      // 更新通知
      _notif.showRestCountdown(
        exerciseName: _restExerciseName,
        totalSeconds: _restDuration,
        remainingSeconds: remaining,
      );
    }
  }

  // --- Date helpers ---
  int get _startOfDay =>
      DateTime(widget.date.year, widget.date.month, widget.date.day)
          .millisecondsSinceEpoch;
  int get _endOfDay =>
      DateTime(widget.date.year, widget.date.month, widget.date.day, 23, 59, 59)
          .millisecondsSinceEpoch;

  // --- Load existing workout or show empty ---
  Future<void> _loadOrCreateWorkout() async {
    setState(() => _isLoading = true);
    try {
      final reminder = await _db.getSetting('rest_reminder_duration');
      _reminderDuration = int.tryParse(reminder ?? '') ?? 3;
    } catch (_) {}
    try {
      final existing = await _db.getWorkoutRecordForDate(_startOfDay, _endOfDay);
      if (existing != null) {
        _workoutRecord = existing;
        final exerciseRecords = await _db.getExerciseRecordsForWorkout(existing.id!);
        // Group by exercise name
        final grouped = <String, List<ExerciseRecord>>{};
        for (final er in exerciseRecords) {
          grouped.putIfAbsent(er.exerciseName, () => []).add(er);
        }
        _exercises = grouped.entries.map((e) {
          e.value.sort((a, b) => a.setNumber.compareTo(b.setNumber));
          final first = e.value.first;
          if (first.exerciseType == 'interval') {
            return _SessionExercise(
              name: e.key,
              restDuration: 0,
              sets: [],
              exerciseType: 'interval',
              durationMinutes: first.durationMinutes,
              intervalRounds: first.intervalRounds,
            );
          }
          if (first.exerciseType == 'cardio') {
            return _SessionExercise(
              name: e.key,
              restDuration: 0,
              sets: [],
              exerciseType: 'cardio',
              durationMinutes: first.durationMinutes,
              distanceKm: first.distanceKm,
              speed: first.speed,
              incline: first.incline,
            );
          }
          return _SessionExercise(
            name: e.key,
            restDuration: first.restDuration,
            exerciseType: 'strength',
            sets: e.value.map((er) => _SessionSet(
              id: er.id,
              targetReps: er.targetReps,
              actualReps: er.actualReps,
              targetWeight: er.targetWeight,
              actualWeight: er.actualWeight,
              isCompleted: er.isCompleted,
            )).toList(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading workout: $e');
    }
    _updateHighlight();
    setState(() => _isLoading = false);
  }

  // --- Create workout record if needed ---
  Future<void> _ensureWorkoutRecord() async {
    if (_workoutRecord != null) return;
    final id = await _db.insertWorkoutRecord(WorkoutRecord(
      date: _startOfDay,
      sportType: 'strength',
      startedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    _workoutRecord = WorkoutRecord(
      id: id,
      date: _startOfDay,
      sportType: 'strength',
      startedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // --- Add exercise manually ---
  void _addExercise() {
    _addStrengthExercise();
  }

  void _addStrengthExercise() {
    setState(() {
      _exercises.add(_SessionExercise(
        name: '',
        restDuration: 60,
        exerciseType: 'strength',
        sets: [_SessionSet(targetReps: 10, targetWeight: 0)],
      ));
      _hasUnsavedChanges = true;
      _draftSaved = false;
    });
    _scrollToBottom();
  }

  void _addCardioExercise() {
    setState(() {
      _exercises.add(_SessionExercise(
        name: '',
        restDuration: 0,
        exerciseType: 'cardio',
        sets: [],
        durationMinutes: 0,
        distanceKm: 0,
        speed: 0,
        incline: 0,
      ));
      _hasUnsavedChanges = true;
      _draftSaved = false;
    });
    _scrollToBottom();
  }

  Future<void> _addIntervalTraining() async {
    // 导航到间歇训练配置页面，等待训练结果
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => const IntervalConfigScreen(),
      ),
    );

    // 训练完成，保存记录
    if (result != null && mounted) {
      await _saveIntervalTrainingResult(result);
    }
  }

  /// 保存间歇训练结果到数据库
  Future<void> _saveIntervalTrainingResult(Map<String, dynamic> result) async {
    try {
      await _ensureWorkoutRecord();

      final trainingName = result['trainingName'] as String? ?? '间歇训练';
      final rounds = result['rounds'] as int? ?? 0;
      final totalDuration = result['totalDuration'] as int? ?? 0;
      final exerciseDuration = result['exerciseDuration'] as int? ?? 0;
      final completed = result['completed'] as bool? ?? false;
      final startedAt = result['startedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final completedAt = result['completedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;

      // 保存为 exercise_record (type=interval)
      await _db.insertExerciseRecord(ExerciseRecord(
        workoutId: _workoutRecord!.id!,
        exerciseName: trainingName,
        setNumber: 1,
        targetReps: rounds,
        actualReps: rounds,
        targetWeight: 0,
        actualWeight: null,
        restDuration: 0,
        createdAt: startedAt,
        exerciseType: 'interval',
        durationMinutes: totalDuration ~/ 60,
        isCompleted: completed,
        intervalRounds: rounds,
      ));

      // 更新 workout_record 的 sport_type
      final hasStrength = _exercises.any((e) => e.exerciseType == 'strength');
      final hasCardio = _exercises.any((e) => e.exerciseType == 'cardio');
      String sportType = 'interval';
      if (hasStrength || hasCardio) {
        sportType = 'mixed';
      }
      final updated = WorkoutRecord(
        id: _workoutRecord!.id,
        date: _workoutRecord!.date,
        sportType: sportType,
        startedAt: _workoutRecord!.startedAt,
        completedAt: completedAt,
        isCompleted: completed,
      );
      await _db.updateWorkoutRecord(updated);
      _workoutRecord = updated;

      // 刷新列表
      await _loadOrCreateWorkout();

      if (mounted) {
        showSuccessSnackBar(context, '间歇训练已记录：$trainingName ${rounds}轮');
      }
    } catch (e) {
      debugPrint('保存间歇训练记录失败: $e');
      if (mounted) {
        showErrorSnackBar(context, '保存失败: $e');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Apply template ---
  Future<void> _applyTemplate() async {
    final templates = await _db.getTemplates();
    if (!mounted) return;

    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无模板，请先创建模板')),
      );
      return;
    }

    final selected = await showModalBottomSheet<WorkoutTemplate>(
      context: context,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: templates.length,
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.fitness_center),
          title: Text(templates[i].name),
          onTap: () => Navigator.pop(ctx, templates[i]),
        ),
      ),
    );

    if (selected == null) return;

    final templateExercises = await _db.getTemplateExercises(selected.id!);
    if (!mounted) return;

    setState(() {
      for (final te in templateExercises) {
        if (te.exerciseType == 'cardio') {
          _exercises.add(_SessionExercise(
            name: te.exerciseName,
            restDuration: 0,
            sets: [],
            exerciseType: 'cardio',
            durationMinutes: te.durationMinutes,
            distanceKm: te.distanceKm,
            speed: te.speed,
            incline: te.incline,
          ));
        } else {
          _exercises.add(_SessionExercise(
            name: te.exerciseName,
            restDuration: te.restDuration,
            exerciseType: 'strength',
            sets: List.generate(te.targetSets, (_) => _SessionSet(
              targetReps: te.targetReps,
              targetWeight: te.targetWeight,
            )),
          ));
        }
      }
      _hasUnsavedChanges = true;
      _draftSaved = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Toggle set completion & start rest timer ---
  void _toggleSet(int exerciseIndex, int setIndex) {
    final exercise = _exercises[exerciseIndex];
    final s = exercise.sets[setIndex];

    setState(() {
      if (s.isCompleted) {
        // Uncheck — keep actualReps/actualWeight so re-check preserves values
        s.isCompleted = false;
        _hasUnsavedChanges = true;
        _updateHighlight();
      } else {
        // Complete
        s.isCompleted = true;
        s.actualReps = s.actualReps ?? s.targetReps;
        s.actualWeight = s.actualWeight ?? s.targetWeight;
        _hasUnsavedChanges = true;


        // Start rest timer if not last set
        if (setIndex < exercise.sets.length - 1 && exercise.restDuration > 0) {
          _startRestTimer(exercise.restDuration, exercise.name);
        } else {
          // Last set or no rest → check if there's a next exercise
          bool hasNextExercise = false;
          for (int i = exerciseIndex + 1; i < _exercises.length; i++) {
            if (_exercises[i].exerciseType == 'strength' && _exercises[i].sets.isNotEmpty) {
              hasNextExercise = true;
              break;
            }
          }


          if (hasNextExercise && exercise.restDuration > 0) {
            // 还有下一个动作 → 启动休息
            _startRestTimer(exercise.restDuration, exercise.name);
          } else {
            // 全部完成或无休息 → 直接跳高亮
            _updateHighlight();
          }
        }
      }
    });
  }

  void _startRestTimer(int seconds, String exerciseName) async {
    log.log('VIBRATE', '开始休息计时: $exerciseName, 休息${seconds}秒');
    _restTimer?.cancel();
    _reminderTimer?.cancel();
    _vibrateChannel.invokeMethod('cancel');
    _notif.cancelAll();
    _restEndTime = DateTime.now().add(Duration(seconds: seconds));
    // 检查精确闹钟权限
    final canSchedule = await _notif.canScheduleExactAlarms();
    if (canSchedule) {
      // 有权限，预定原生闹钟，息屏时由 AlarmManager 触发震动
      _notif.scheduleVibrationReminder(exerciseName, _restEndTime!).catchError((e) {
        log.log('VIBRATE', 'scheduleVibrationReminder 失败: $e');
      });
      log.log('VIBRATE', '已调用 scheduleVibrationReminder, endTime=$_restEndTime');
    } else {
      log.log('VIBRATE', '无精确闹钟权限，跳过 scheduleVibrationReminder');
    }
    setState(() {
      _restRemaining = seconds;
      _restTotal = seconds;
      _restDuration = seconds;
      _restExerciseName = exerciseName;
    });
    // 前台服务已禁用，只保留倒计时通知
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restRemaining <= 1) {
        log.log('VIBRATE', '休息倒计时结束, _restRemaining=$_restRemaining');
        timer.cancel();
        _restTimer = null;
        // 注意：不清理 _restEndTime！让 _syncRestTimerOnResume 知道 alarm 已设置
        setState(() {
          _restRemaining = 0;
        });
        // 清除倒计时通知（RestAlarmReceiver 也会清除，这里双保险）
        _notif.cancelRestNotification();
        // 播放结束提示音
        _soundService.playEndAlert();
        // 不调用 _startReminder！
        // AlarmManager 闹钟会自动触发 RestAlarmReceiver 处理震动和通知
        log.log('VIBRATE', '前台倒计时结束，等待 RestAlarmReceiver 处理');
      } else {
        setState(() {
          _restRemaining--;
          // 更新通知栏倒计时
          _notif.showRestCountdown(
            exerciseName: _restExerciseName,
            totalSeconds: _restDuration,
            remainingSeconds: _restRemaining,
          );
        });
      }
    });
  }

  Future<void> _startReminder(String exerciseName) async {
    log.log('VIBRATE', '_startReminder 被调用, _reminderDuration=$_reminderDuration');
    _notif.cancelRestNotification();
    // 注意：不要在这里取消 alarm！
    // 如果 App 从后台恢复，alarm 可能还没触发，取消它会导致息屏震动失效
    // 如果 alarm 已经触发了，cancelAlarm 是无害的
    // 让 alarm 自然触发或过期

    // 检查是否有精确闹钟权限，有则说明 alarm 可能已触发或即将触发
    final canSchedule = await _notif.canScheduleExactAlarms();
    if (canSchedule) {
      // 有权限时，alarm 已设置，不显示重复的 Dart 震动和通知
      // 等 RestAlarmReceiver 自己处理
      log.log('VIBRATE', '有精确闹钟权限，等待 RestAlarmReceiver 处理');
    } else {
      // 无权限时，用 Dart 方案作为 fallback
      log.log('VIBRATE', '无精确闹钟权限，使用 Dart 震动 fallback');
      _notif.showVibrationReminder(exerciseName);
      try {
        await _vibrateChannel.invokeMethod('vibrate', {'duration': _reminderDuration * 1000});
      } catch (e) {
        log.log('VIBRATE', '震动 MethodChannel 异常: $e');
      }
    }
    _reminderTimer = Timer(Duration(seconds: _reminderDuration), () {
      _reminderTimer = null;
      _notif.cancelAll();
      setState(() {
        _restExerciseName = '';
      });
      _updateHighlight();
    });
  }

  void _adjustRest(int delta) {
    setState(() {
      _restRemaining = (_restRemaining + delta).clamp(0, 9999);
    });
  }

  // --- Highlight next set ---
  void _updateHighlight() {
    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      if (ex.exerciseType == 'cardio') continue;
      for (int j = 0; j < ex.sets.length; j++) {
        if (!ex.sets[j].isCompleted) {
          _highlightedExerciseIndex = i;
          _highlightedSetIndex = j;
          return;
        }
      }
    }
    // All done
    _highlightedExerciseIndex = null;
    _highlightedSetIndex = null;
  }

  void _scrollToExercise(int index) {
    if (!_scrollController.hasClients) return;
    final offset = (index * 220.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // --- Save workout ---
  Future<void> _saveWorkout({required bool markCompleted}) async {
    // 如果所有动作都被删了，清理空记录而不是保存空 workout
    if (_exercises.isEmpty) {
      if (_workoutRecord != null) {
        await _db.deleteExerciseRecordsForWorkout(_workoutRecord!.id!);
        await _db.deleteWorkoutRecord(_workoutRecord!.id!);
        _workoutRecord = null;
      }
      _hasUnsavedChanges = false;
      return;
    }

    await _ensureWorkoutRecord();

    // Determine sport type from exercise types
    final hasStrength = _exercises.any((e) => e.exerciseType == 'strength');
    final hasCardio = _exercises.any((e) => e.exerciseType == 'cardio');
    final hasInterval = _exercises.any((e) => e.exerciseType == 'interval');
    String sportType = 'strength';
    final typeCount = (hasStrength ? 1 : 0) + (hasCardio ? 1 : 0) + (hasInterval ? 1 : 0);
    if (typeCount > 1) {
      sportType = 'mixed';
    } else if (hasInterval) {
      sportType = 'interval';
    } else if (hasCardio) {
      sportType = 'cardio';
    }

    // Update workout record
    final updated = WorkoutRecord(
      id: _workoutRecord!.id,
      date: _workoutRecord!.date,
      sportType: sportType,
      startedAt: _workoutRecord!.startedAt,
      completedAt: markCompleted ? DateTime.now().millisecondsSinceEpoch : null,
      isCompleted: markCompleted,
    );
    await _db.updateWorkoutRecord(updated);
    _workoutRecord = updated;

    // Delete old exercise records and re-insert
    await _db.deleteExerciseRecordsForWorkout(_workoutRecord!.id!);
    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      if (ex.exerciseType == 'interval') {
        await _db.insertExerciseRecord(ExerciseRecord(
          workoutId: _workoutRecord!.id!,
          exerciseName: ex.name.isEmpty ? '间歇训练 ${i + 1}' : ex.name,
          setNumber: 1,
          targetReps: ex.intervalRounds ?? 0,
          actualReps: ex.intervalRounds,
          targetWeight: 0,
          actualWeight: null,
          restDuration: 0,
          exerciseType: 'interval',
          durationMinutes: ex.durationMinutes,
          isCompleted: true,
          intervalRounds: ex.intervalRounds,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      } else if (ex.exerciseType == 'cardio') {
        await _db.insertExerciseRecord(ExerciseRecord(
          workoutId: _workoutRecord!.id!,
          exerciseName: ex.name.isEmpty ? '有氧运动 ${i + 1}' : ex.name,
          setNumber: 1,
          targetReps: 0,
          actualReps: null,
          targetWeight: 0,
          actualWeight: null,
          restDuration: 0,
          exerciseType: 'cardio',
          durationMinutes: ex.durationMinutes,
          distanceKm: ex.distanceKm,
          speed: ex.speed,
          incline: ex.incline,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      } else {
        for (int j = 0; j < ex.sets.length; j++) {
          final s = ex.sets[j];
          await _db.insertExerciseRecord(ExerciseRecord(
            workoutId: _workoutRecord!.id!,
            exerciseName: ex.name.isEmpty ? '动作 ${i + 1}' : ex.name,
            setNumber: j + 1,
            targetReps: s.targetReps,
            actualReps: s.actualReps ?? s.targetReps,
            targetWeight: s.targetWeight,
            actualWeight: s.actualWeight ?? s.targetWeight,
            restDuration: ex.restDuration,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            isCompleted: s.isCompleted,
          ));
        }
      }
    }

    _hasUnsavedChanges = false;
  }

  // --- Back button handling ---
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges && _workoutRecord == null) return true;
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存训练？'),
        content: const Text('当前训练有未保存的修改，是否保存？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('放弃'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    // Helper to clean up empty workout records on exit
    Future<void> cleanupEmpty() async {
      if (_exercises.isEmpty && _workoutRecord != null) {
        await _db.deleteExerciseRecordsForWorkout(_workoutRecord!.id!);
        await _db.deleteWorkoutRecord(_workoutRecord!.id!);
      }
    }

    if (result == 'save') {
      if (_exercises.isEmpty && _workoutRecord != null) {
        await cleanupEmpty();
      } else if (_exercises.isNotEmpty) {
        await _saveWorkout(markCompleted: false);
      }
      return true;
    } else if (result == 'discard') {
      await cleanupEmpty();
      return true;
    }
    return false; // cancel back
  }

  // --- Complete training ---
  Future<void> _completeTraining() async {
    if (_exercises.isEmpty) {
      showWarningSnackBar(context, '当前没有训练内容，请先添加训练动作');
      return;
    }

    // Auto-check all unchecked sets with target values (strength only)
    for (final exercise in _exercises) {
      if (exercise.exerciseType != 'cardio') {
        for (final s in exercise.sets) {
          if (!s.isCompleted) {
            s.isCompleted = true;
            s.actualReps = s.actualReps ?? s.targetReps;
            s.actualWeight = s.actualWeight ?? s.targetWeight;
          }
        }
      }
    }

    await _saveWorkout(markCompleted: true);
    if (mounted) {
      HapticFeedback.heavyImpact();
      showSuccessSnackBar(context, '训练已完成！');
      Navigator.of(context).pop();
    }
  }

  // --- Remove exercise ---
  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  // --- Edit set values ---
  Future<void> _editSet(int exerciseIndex, int setIndex) async {
    final s = _exercises[exerciseIndex].sets[setIndex];
    final currentReps = (s.actualReps ?? s.targetReps).toString();
    final currentWeight = (s.actualWeight ?? s.targetWeight).toStringAsFixed(1);
    final repsCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('第 ${setIndex + 1} 组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: repsCtrl,
              decoration: InputDecoration(
                labelText: '次数',
                hintText: currentReps,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              decoration: InputDecoration(
                labelText: '重量 (kg)',
                hintText: currentWeight,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        s.actualReps = repsCtrl.text.isEmpty
            ? (s.actualReps ?? s.targetReps)
            : int.tryParse(repsCtrl.text) ?? s.targetReps;
        s.actualWeight = weightCtrl.text.isEmpty
            ? (s.actualWeight ?? s.targetWeight)
            : double.tryParse(weightCtrl.text) ?? s.targetWeight;
        _hasUnsavedChanges = true;
      });
    }
  }

  // --- 排序功能 ---
  void _moveExerciseUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _exercises.removeAt(index);
      _exercises.insert(index - 1, item);
      _hasUnsavedChanges = true;
      _updateHighlight();
    });
  }

  void _moveExerciseDown(int index) {
    if (index >= _exercises.length - 1) return;
    setState(() {
      final item = _exercises.removeAt(index);
      _exercises.insert(index + 1, item);
      _hasUnsavedChanges = true;
      _updateHighlight();
    });
  }

  Widget _buildSortView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: Text(
            '点击 ↑↓ 按钮调整动作顺序，完成后点击右上角"完成"',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: _exercises.length,
            itemBuilder: (context, index) {
              final ex = _exercises[index];
              final isFirst = index == 0;
              final isLast = index == _exercises.length - 1;
              final isCardio = ex.exerciseType == 'cardio';
              final isInterval = ex.exerciseType == 'interval';
              final completedSets = ex.sets.where((s) => s.isCompleted).length;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // 序号
                      BadgeNumber(
                        color: isInterval
                            ? AppColors.info
                            : isCardio
                                ? AppColors.warning
                                : Theme.of(context).colorScheme.primary,
                        number: index + 1,
                      ),
                      const SizedBox(width: 12),
                      // 动作名称和详情
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name.isEmpty ? '(未命名)' : ex.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            if (isInterval)
                              Text(
                                '间歇训练 ${ex.intervalRounds ?? 0}轮 · ${ex.durationMinutes ?? 0}分钟',
                                style: TextStyle(fontSize: 12, color: AppColors.subtitle),
                              )
                            else if (isCardio)
                              Text('有氧运动', style: TextStyle(fontSize: 12, color: AppColors.subtitle))
                            else if (ex.sets.isNotEmpty)
                              Text(
                                '$completedSets/${ex.sets.length} 组 · ${ex.sets.first.targetReps}次'
                                '${ex.sets.first.targetWeight > 0 ? ' @ ${ex.sets.first.targetWeight}kg' : ''}',
                                style: TextStyle(fontSize: 12, color: AppColors.subtitle),
                              ),
                          ],
                        ),
                      ),
                      // ↑↓ 按钮
                      MoveArrows(
                        isFirst: isFirst,
                        isLast: isLast,
                        onMoveUp: () => _moveExerciseUp(index),
                        onMoveDown: () => _moveExerciseDown(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
        appBar: AppBar(
          title: Text(_isSorting ? '调整顺序' : '$dateStr 训练'),
          centerTitle: true,
          leading: _isSorting
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _isSorting = false),
                )
              : null,
          actions: [
            if (_isSorting)
              TextButton(
                onPressed: () => setState(() => _isSorting = false),
                child: const Text('完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            if (!_isSorting && _exercises.length > 1)
              IconButton(
                icon: const Icon(Icons.sort),
                onPressed: () => setState(() => _isSorting = true),
                tooltip: '调整顺序',
              ),
            if (!_isSorting)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'template') _applyTemplate();
                  if (v == 'add') _addExercise();
                  if (v == 'add_cardio') _addCardioExercise();
                  if (v == 'add_interval') _addIntervalTraining();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'template', child: Text('套用模板')),
                  const PopupMenuItem(value: 'add', child: Text('添加力量训练')),
                  const PopupMenuItem(value: 'add_cardio', child: Text('添加有氧运动')),
                  const PopupMenuItem(value: 'add_interval', child: Text('添加间歇训练')),
                ],
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isSorting
                ? _buildSortView()
                : Stack(
                children: [
                  Column(
                    children: [
                      // Rest timer bar
                      _buildRestTimerBar(),

                      // Exercise list
                      Expanded(
                        child: _exercises.isEmpty
                            ? EmptyState(
                                icon: Icons.add_circle_outline,
                                message: '点击添加训练动作或套用模板',
                                onTap: _addExercise,
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _exercises.length,
                                itemBuilder: (_, i) {
                                  final ex = _exercises[i];
                                  if (ex.exerciseType == 'interval') return _buildIntervalCard(i);
                                  if (ex.exerciseType == 'cardio') return _buildCardioCard(i);
                                  return _buildExerciseCard(i);
                                },
                              ),
                      ),

                      // Bottom buttons
                      if (!_isSorting) _buildBottomBar(),
                    ],
                  ),

                  // 最后 10 秒全屏遮罩
                  CountdownOverlay(
                    remaining: _restRemaining,
                    total: _restTotal,
                    visible: _restRemaining <= 10 && _restRemaining > 0,
                  ),
                ],
              ),
        floatingActionButton: (_exercises.isEmpty || _draftSaved || _isSorting)
            ? null
            : Container(
                margin: const EdgeInsets.only(bottom: 80),
                child: FloatingActionButton(
                  onPressed: _addExercise,
                  tooltip: '添加动作',
                  mini: true,
                  child: const Icon(Icons.add),
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    ),
    );
  }

  Widget _buildRestTimerBar() {
    final isCountingDown = _restRemaining > 0;
    final progress =
        _restTotal > 0 ? _restRemaining / _restTotal : 0.0;
    final minutes = _restRemaining ~/ 60;
    final seconds = _restRemaining % 60;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isCountingDown
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      child: isCountingDown
          ? Row(
              children: [
                const Icon(Icons.timer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, fontFeatures: [
                    FontFeature.tabularFigures(),
                  ]),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove, size: 20),
                  onPressed: () => _adjustRest(-10),
                  tooltip: '-10秒',
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _adjustRest(10),
                  tooltip: '+10秒',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _restTimer?.cancel();
                    _restTimer = null;
                    _reminderTimer?.cancel();
                    _notif.cancelAll();
                    _vibrateChannel.invokeMethod('cancel');
                    _restEndTime = null;
                    setState(() {
                      _restRemaining = 0;
                      _restExerciseName = '';
                    });
                  },
                ),
              ],
            )
          : Center(
              child: Text(
                _restExerciseName.isEmpty
                    ? '完成一组后开始休息'
                    : '休息 ${_restExerciseName}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
    );
  }

  Widget _buildExerciseCard(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final completedSets =
        exercise.sets.where((s) => s.isCompleted).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                BadgeNumber(
                  color: Theme.of(context).colorScheme.primary,
                  number: exerciseIndex + 1,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: exercise.name.isEmpty
                      ? TextField(
                          decoration: const InputDecoration(
                            hintText: '输入动作名称',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onChanged: (v) {
                            exercise.name = v;
                            _hasUnsavedChanges = true;
                          },
                        )
                      : GestureDetector(
                          onTap: () {
                            // 点击编辑动作名称
                            final nameCtrl = TextEditingController(text: exercise.name);
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('编辑动作名称'),
                                content: TextField(
                                  controller: nameCtrl,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: '动作名称',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        exercise.name = nameCtrl.text;
                                        _hasUnsavedChanges = true;
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('确定'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
                Text('$completedSets/${exercise.sets.length} 组',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    setState(() {
                      final lastSet = exercise.sets.isNotEmpty
                          ? exercise.sets.last
                          : _SessionSet(targetReps: 10, targetWeight: 0);
                      exercise.sets.add(_SessionSet(
                        targetReps: lastSet.targetReps,
                        targetWeight: lastSet.targetWeight,
                      ));
                      _hasUnsavedChanges = true;
                    });
                  },
                  tooltip: '加一组',
                ),
                DeleteButton(
                  onPressed: () => _removeExercise(exerciseIndex),
                  tooltip: '删除动作',
                ),
              ],
            ),

            // Rest time setting
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Text('组间休息: ', style: TextStyle(fontSize: 12)),
                  SizedBox(
                    width: 60,
                    height: 30,
                    child: TextField(
                      controller: TextEditingController(),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: OutlineInputBorder(),
                        suffixText: '秒',
                        suffixStyle: TextStyle(fontSize: 10),
                        hintText: exercise.restDuration.toString(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) {
                        if (v.isNotEmpty) {
                          exercise.restDuration = int.tryParse(v) ?? exercise.restDuration;
                          _hasUnsavedChanges = true;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // Sets
            ...List.generate(exercise.sets.length, (setIndex) {
              final s = exercise.sets[setIndex];
              return _buildSetRow(exerciseIndex, setIndex, s);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCardioCard(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final durationCtrl = TextEditingController(
        text: exercise.durationMinutes != null && exercise.durationMinutes! > 0
            ? '${exercise.durationMinutes}' : '');
    final distanceCtrl = TextEditingController(
        text: exercise.distanceKm != null && exercise.distanceKm! > 0
            ? '${exercise.distanceKm}' : '');
    final speedCtrl = TextEditingController(
        text: exercise.speed != null && exercise.speed! > 0
            ? '${exercise.speed}' : '');
    final inclineCtrl = TextEditingController(
        text: exercise.incline != null && exercise.incline! > 0
            ? '${exercise.incline}' : '');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + name + delete
            Row(
              children: [
                BadgeNumber(
                  color: AppColors.warning,
                  number: exerciseIndex + 1,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.directions_run, size: 20, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: exercise.name.isEmpty
                      ? TextField(
                          decoration: const InputDecoration(
                            hintText: '运动名称（如：跑步、爬坡）',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onChanged: (v) {
                            exercise.name = v;
                            _hasUnsavedChanges = true;
                          },
                        )
                      : GestureDetector(
                          onTap: () {
                            // Allow editing name by tapping
                            final nameCtrl = TextEditingController(text: exercise.name);
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('编辑运动名称'),
                                content: TextField(
                                  controller: nameCtrl,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: '运动名称',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        exercise.name = nameCtrl.text;
                                        _hasUnsavedChanges = true;
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('确定'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
                DeleteButton(
                  onPressed: () => _removeExercise(exerciseIndex),
                  tooltip: '删除动作',
                ),
              ],
            ),
            const Divider(height: 16),
            // Duration + Distance row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '时长',
                      suffixText: '分钟',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      exercise.durationMinutes = int.tryParse(v);
                      _hasUnsavedChanges = true;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: distanceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '距离',
                      suffixText: 'km',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      exercise.distanceKm = double.tryParse(v);
                      _hasUnsavedChanges = true;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Speed + Incline row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: speedCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '速度',
                      suffixText: 'km/h',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      exercise.speed = double.tryParse(v);
                      _hasUnsavedChanges = true;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: inclineCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '坡度',
                      suffixText: '%',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      exercise.incline = double.tryParse(v);
                      _hasUnsavedChanges = true;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalCard(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final duration = exercise.durationMinutes ?? 0;
    final rounds = exercise.intervalRounds ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            BadgeNumber(
              color: AppColors.info,
              number: exerciseIndex + 1,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.timer, size: 20, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name.isEmpty ? '间歇训练' : exercise.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${rounds}轮 · ${duration}分钟',
                    style: TextStyle(fontSize: 12, color: AppColors.subtitle),
                  ),
                ],
              ),
            ),
            DeleteButton(
              onPressed: () => _removeExercise(exerciseIndex),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() {
      _exercises[exerciseIndex].sets.removeAt(setIndex);
      _hasUnsavedChanges = true;
    });
  }

  Widget _buildSetRow(int exerciseIndex, int setIndex, _SessionSet s) {
    final exercise = _exercises[exerciseIndex];
    final label = '第 ${setIndex + 1} 组';
    final displayReps = s.actualReps ?? s.targetReps;
    final displayWeight = s.actualWeight ?? s.targetWeight;
    final detail = '${displayReps}次 × ${displayWeight.toStringAsFixed(1)}kg';
    final isHighlighted = exerciseIndex == _highlightedExerciseIndex && setIndex == _highlightedSetIndex;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: isHighlighted
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Checkbox(
              value: s.isCompleted,
              onChanged: (_) => _toggleSet(exerciseIndex, setIndex),
            ),
            SizedBox(
              width: 70,
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _editSet(exerciseIndex, setIndex),
                child: Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13,
                    color: s.isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    decoration:
                        s.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
            if (exercise.sets.length > 1)
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                onPressed: () => _removeSet(exerciseIndex, setIndex),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            if (s.isCompleted)
              Icon(Icons.check_circle,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isCompleted = _workoutRecord?.isCompleted == true;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _saveWorkout(markCompleted: false);
                  setState(() => _draftSaved = true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('训练已保存')),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('保存草稿'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: isCompleted ? null : _completeTraining,
                icon: Icon(
                    isCompleted ? Icons.check_circle : Icons.flag),
                label: Text(isCompleted ? '已完成' : '训练完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Internal data classes ---

class _SessionExercise {
  String name;
  int restDuration;
  List<_SessionSet> sets;
  String exerciseType; // 'strength' / 'cardio' / 'interval'
  int? durationMinutes;
  double? distanceKm;
  double? speed;
  double? incline;
  int? intervalRounds;

  _SessionExercise({
    required this.name,
    required this.restDuration,
    required this.sets,
    this.exerciseType = 'strength',
    this.durationMinutes,
    this.distanceKm,
    this.speed,
    this.incline,
    this.intervalRounds,
  });
}

class _SessionSet {
  final int? id;
  int targetReps;
  double targetWeight;
  int? actualReps;
  double? actualWeight;
  bool isCompleted;

  _SessionSet({
    this.id,
    required this.targetReps,
    required this.targetWeight,
    this.actualReps,
    this.actualWeight,
    this.isCompleted = false,
  });
}
