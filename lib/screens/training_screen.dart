import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/badge_number.dart';
import '../models/workout_record.dart';
import '../models/exercise_record.dart';
import '../models/workout_template.dart';
import '../models/template_exercise.dart';
import '../services/database_service.dart';
import '../services/timer_service.dart';
import '../services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal data models for the training session
// ─────────────────────────────────────────────────────────────────────────────

class _TrainingExercise {
  final String name;
  final int targetSets;
  final int targetReps;
  final double targetWeight;
  final int restDuration; // default rest seconds for this exercise
  final List<_SetState> sets;

  _TrainingExercise({
    required this.name,
    required this.targetSets,
    required this.targetReps,
    required this.targetWeight,
    required this.restDuration,
  }) : sets = List.generate(
          targetSets,
          (i) => _SetState(
            setNumber: i + 1,
            targetReps: targetReps,
            targetWeight: targetWeight,
          ),
        );

  factory _TrainingExercise.fromTemplateExercise(TemplateExercise e) {
    return _TrainingExercise(
      name: e.exerciseName,
      targetSets: e.targetSets,
      targetReps: e.targetReps,
      targetWeight: e.targetWeight,
      restDuration: e.restDuration,
    );
  }

  /// How many sets are done.
  int get completedSets => sets.where((s) => s.isCompleted).length;
  bool get isFullyCompleted => completedSets == targetSets;
}

class _SetState {
  final int setNumber;
  final int targetReps;
  final double targetWeight;
  int? actualReps;
  double? actualWeight;
  bool isCompleted = false;

  _SetState({
    required this.setNumber,
    required this.targetReps,
    required this.targetWeight,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Training Screen
// ─────────────────────────────────────────────────────────────────────────────

class TrainingScreen extends StatefulWidget {
  /// Start from a template (normal flow).
  final WorkoutTemplate? template;
  final List<TemplateExercise>? templateExercises;

  /// Start with a manual exercise list (ad-hoc training).
  final List<ManualExercise>? manualExercises;

  const TrainingScreen({
    super.key,
    this.template,
    this.templateExercises,
    this.manualExercises,
  }) : assert(
          template != null || manualExercises != null,
          'Provide either a template or manual exercises',
        );

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

/// Lightweight holder for manually-added exercises.
class ManualExercise {
  final String name;
  final int sets;
  final int reps;
  final double weight;
  final int restDuration;

  const ManualExercise({
    required this.name,
    this.sets = 3,
    this.reps = 10,
    this.weight = 0,
    this.restDuration = 60,
  });
}

class _TrainingScreenState extends State<TrainingScreen> with WidgetsBindingObserver {
  // ── Services ──
  final DatabaseService _db = DatabaseService();
  final TimerService _restTimer = TimerService();
  final NotificationService _notif = NotificationService();

  // ── Session state ──
  late List<_TrainingExercise> _exercises;
  late String _sportType; // 'strength' | 'cardio' | 'mixed'
  WorkoutRecord? _workoutRecord;
  bool _isInitializing = true;
  bool _autoStartNextSet = true;

  // ── Rest timer UI ──
  bool _isResting = false;
  int _restDurationForCurrentSet = 0; // the base duration for the current set

  // ── Input controllers: [exerciseIndex][setIndex] ──
  late List<List<TextEditingController>> _weightCtrls;
  late List<List<TextEditingController>> _repsCtrls;

  // ── Scroll controller to auto-scroll to active exercise ──
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sportType = 'strength'; // default
    _restTimer.onComplete = _onRestComplete;
    _initSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restTimer.syncOnResume();
    }
  }

  Future<void> _initSession() async {
    // Build exercise list
    if (widget.templateExercises != null) {
      _exercises = widget.templateExercises!
          .map(_TrainingExercise.fromTemplateExercise)
          .toList();
    } else if (widget.manualExercises != null) {
      _exercises = widget.manualExercises!
          .map((m) => _TrainingExercise(
                name: m.name,
                targetSets: m.sets,
                targetReps: m.reps,
                targetWeight: m.weight,
                restDuration: m.restDuration,
              ))
          .toList();
    } else {
      _exercises = [];
    }

    // Build text controllers
    _weightCtrls = [];
    _repsCtrls = [];
    for (final ex in _exercises) {
      final wCtrls = <TextEditingController>[];
      final rCtrls = <TextEditingController>[];
      for (final s in ex.sets) {
        wCtrls.add(TextEditingController(
          text: s.targetWeight > 0 ? s.targetWeight.toString() : '',
        ));
        rCtrls.add(TextEditingController(
          text: s.targetReps > 0 ? s.targetReps.toString() : '',
        ));
      }
      _weightCtrls.add(wCtrls);
      _repsCtrls.add(rCtrls);
    }

    // Create WorkoutRecord in DB
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = WorkoutRecord(
      date: now,
      sportType: _sportType,
      startedAt: now,
    );
    final id = await _db.insertWorkoutRecord(record);
    _workoutRecord = WorkoutRecord(
      id: id,
      date: record.date,
      sportType: record.sportType,
      startedAt: record.startedAt,
    );

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer.dispose();
    _scrollController.dispose();
    for (final row in _weightCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _repsCtrls) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Set completion
  // ───────────────────────────────────────────────────────────────────────────

  /// Index of the first exercise that is not fully completed.
  int get _currentExerciseIndex {
    for (int i = 0; i < _exercises.length; i++) {
      if (!_exercises[i].isFullyCompleted) return i;
    }
    return _exercises.length - 1; // all done
  }

  /// Index of the first incomplete set in the current exercise.
  int get _currentSetIndex {
    final ex = _exercises[_currentExerciseIndex];
    for (int i = 0; i < ex.sets.length; i++) {
      if (!ex.sets[i].isCompleted) return i;
    }
    return ex.sets.length - 1;
  }

  bool get _allDone => _exercises.every((e) => e.isFullyCompleted);

  Future<void> _completeSet(int exIdx, int setIdx) async {
    final ex = _exercises[exIdx];
    final s = ex.sets[setIdx];

    // Parse actual values from controllers
    final weightText = _weightCtrls[exIdx][setIdx].text.trim();
    final repsText = _repsCtrls[exIdx][setIdx].text.trim();
    final actualWeight = double.tryParse(weightText) ?? s.targetWeight;
    final actualReps = int.tryParse(repsText) ?? s.targetReps;

    s.actualWeight = actualWeight;
    s.actualReps = actualReps;
    s.isCompleted = true;

    // Save ExerciseRecord to DB
    final record = ExerciseRecord(
      workoutId: _workoutRecord!.id!,
      exerciseName: ex.name,
      setNumber: s.setNumber,
      targetReps: s.targetReps,
      actualReps: actualReps,
      targetWeight: s.targetWeight,
      actualWeight: actualWeight,
      restDuration: ex.restDuration,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      isCompleted: true,
    );
    await _db.insertExerciseRecord(record);

    // Haptic feedback
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    setState(() {});

    // Check if everything is done
    if (_allDone) {
      _showCompletePrompt();
      return;
    }

    // Determine what's next
    final nextExIdx = _currentExerciseIndex;

    if (nextExIdx != exIdx) {
      // Moved to next exercise — no rest needed, just scroll
      _scrollToExercise(nextExIdx);
      return;
    }

    // More sets in the same exercise → start rest timer
    _startRest(ex.restDuration);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rest timer
  // ───────────────────────────────────────────────────────────────────────────

  void _startRest(int duration) {
    _restDurationForCurrentSet = duration;
    _isResting = true;
    _restTimer.start(duration);
    setState(() {});
  }

  void _onRestComplete() {
    setState(() => _isResting = false);

    // Alert: vibration + sound
    _triggerRestAlert();

    // Notification: rest complete reminder
    final exName = _allDone ? '训练' : _exercises[_currentExerciseIndex].name;
    _notif.showVibrationReminder(exName);

    // Auto-advance to next set if enabled
    if (_autoStartNextSet && !_allDone) {
      // Small delay so user sees the transition
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _scrollToExercise(_currentExerciseIndex);
      });
    }
  }

  Future<void> _triggerRestAlert() async {
    // Vibration via HapticFeedback
    try {
      HapticFeedback.vibrate();
    } catch (_) {
      // platform not supported
    }

    // Sound alert handled by notification + vibration
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Training completion
  // ───────────────────────────────────────────────────────────────────────────

  void _showCompletePrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 训练完成！'),
        content: const Text('所有组都已完成，点击确认结束本次训练。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _finishTraining();
            },
            child: const Text('确认完成'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishTraining() async {
    // Cancel rest timer if running
    _restTimer.cancel();

    // Update WorkoutRecord
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = WorkoutRecord(
      id: _workoutRecord!.id,
      date: _workoutRecord!.date,
      sportType: _sportType,
      startedAt: _workoutRecord!.startedAt,
      completedAt: now,
      isCompleted: true,
    );
    await _db.updateWorkoutRecord(updated);

    if (!mounted) return;

    // Calculate summary stats
    int totalSets = 0;
    double totalVolume = 0;
    for (final ex in _exercises) {
      for (final s in ex.sets) {
        if (s.isCompleted) {
          totalSets++;
          totalVolume += (s.actualWeight ?? 0) * (s.actualReps ?? 0);
        }
      }
    }

    // Show summary dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('📊 训练总结'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('动作数量', '${_exercises.length} 个'),
              _summaryRow('完成组数', '$totalSets 组'),
              _summaryRow('总训练量', '${totalVolume.toStringAsFixed(1)} kg·次'),
              _summaryRow('训练时长', _formatDuration(now - _workoutRecord!.startedAt)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // close dialog
                Navigator.of(context).pop(); // back to home
              },
              child: const Text('返回主页'),
            ),
          ],
        ),
      );
    }
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final secs = ms ~/ 1000;
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m > 0) return '$m 分 $s 秒';
    return '$s 秒';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Cancel / abandon training
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _abandonTraining() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃训练？'),
        content: const Text('当前训练进度将不会保存。确定要放弃吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续训练'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('放弃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _restTimer.cancel();
      // Delete the incomplete workout record and its exercise records
      if (_workoutRecord?.id != null) {
        await _db.deleteExerciseRecordsForWorkout(_workoutRecord!.id!);
        await _db.deleteWorkoutRecord(_workoutRecord!.id!);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI helpers
  // ───────────────────────────────────────────────────────────────────────────

  void _scrollToExercise(int index) {
    if (!_scrollController.hasClients) return;
    // Approximate each card is ~200px; scroll to bring it into view
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

  String _sportTypeEmoji(String type) {
    switch (type) {
      case 'strength':
        return '🏋️';
      case 'cardio':
        return '🏃';
      case 'mixed':
        return '🏋️🏃';
      default:
        return '💪';
    }
  }

  String _sportTypeLabel(String type) {
    switch (type) {
      case 'strength':
        return '力量';
      case 'cardio':
        return '有氧';
      case 'mixed':
        return '混合';
      default:
        return type;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _abandonTraining();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Motivational quote
            _buildQuoteBanner(),

            // Sport type selector
            _buildSportTypeSelector(),

            // Auto-start toggle
            _buildAutoStartToggle(),

            // Exercise list (scrollable)
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _exercises.length,
                itemBuilder: (context, index) =>
                    _buildExerciseCard(_exercises[index], index),
              ),
            ),

            // Rest timer (shown when resting)
            if (_isResting) _buildRestTimerBar(),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        '${_sportTypeEmoji(_sportType)} 训练中',
        style: const TextStyle(fontSize: 18),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _abandonTraining,
        tooltip: '放弃训练',
      ),
      actions: [
        // Finish button — only enabled when all done, or as force-finish
        TextButton(
          onPressed: _allDone
              ? _finishTraining
              : () {
                  // Confirm early finish
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('提前结束？'),
                      content: Text(
                        '还有 ${_exercises.where((e) => !e.isFullyCompleted).length} 个动作未完成。确定要结束训练吗？',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('继续训练'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _finishTraining();
                          },
                          style:
                              TextButton.styleFrom(foregroundColor: AppColors.warning),
                          child: const Text('结束训练'),
                        ),
                      ],
                    ),
                  );
                },
          child: Text(
            '完成训练',
            style: TextStyle(
              color: _allDone ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ── Quote banner ──

  Widget _buildQuoteBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        currentQuote.text,
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Sport type selector ──

  Widget _buildSportTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Text('类型: ', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          ...['strength', 'cardio', 'mixed'].map((type) {
            final selected = _sportType == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${_sportTypeEmoji(type)} ${_sportTypeLabel(type)}'),
                selected: selected,
                onSelected: (_) {
                  setState(() => _sportType = type);
                  // Update the workout record sport type
                  if (_workoutRecord != null) {
                    _db.updateWorkoutRecord(WorkoutRecord(
                      id: _workoutRecord!.id,
                      date: _workoutRecord!.date,
                      sportType: type,
                      startedAt: _workoutRecord!.startedAt,
                      completedAt: _workoutRecord!.completedAt,
                      isCompleted: _workoutRecord!.isCompleted,
                    ));
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Auto-start toggle ──

  Widget _buildAutoStartToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.autorenew, size: 18),
          const SizedBox(width: 6),
          const Text('自动开始下一组', style: TextStyle(fontSize: 13)),
          const Spacer(),
          Switch(
            value: _autoStartNextSet,
            onChanged: (v) => setState(() => _autoStartNextSet = v),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  // ── Exercise card ──

  Widget _buildExerciseCard(_TrainingExercise ex, int exIdx) {
    final isCurrentExercise = exIdx == _currentExerciseIndex && !_allDone;
    final isDone = ex.isFullyCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentExercise
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Exercise header ──
            Row(
              children: [
                // Number badge
                BadgeNumber(
                  color: isCurrentExercise
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.futureItem,
                  number: exIdx + 1,
                  done: isDone,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        '目标: ${ex.targetSets}组 × ${ex.targetReps}次'
                        '${ex.targetWeight > 0 ? ' @ ${ex.targetWeight}kg' : ''}'
                        ' · 休息${ex.restDuration}秒',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtitle,
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress indicator
                Text(
                  '${ex.completedSets}/${ex.targetSets}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDone ? AppColors.success : null,
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // ── Sets ──
            ...List.generate(ex.targetSets, (setIdx) {
              return _buildSetRow(ex, exIdx, setIdx);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(_TrainingExercise ex, int exIdx, int setIdx) {
    final s = ex.sets[setIdx];
    final isActive = exIdx == _currentExerciseIndex &&
        setIdx == _currentSetIndex &&
        !_allDone;

    if (s.isCompleted) {
      // Completed set — show summary
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                '第 ${s.setNumber} 组',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text(
              '${s.actualWeight ?? 0}kg × ${s.actualReps ?? 0}次',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            const Spacer(),
            Text(
              '✅',
              style: TextStyle(fontSize: 13, color: AppColors.futureItem),
            ),
          ],
        ),
      );
    }

    if (isActive) {
      // Active set — show input fields + button
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    '第 ${s.setNumber}/${ex.targetSets} 组',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Weight input
                Expanded(
                  child: TextField(
                    controller: _weightCtrls[exIdx][setIdx],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: '重量(kg)',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('×', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                // Reps input
                Expanded(
                  child: TextField(
                    controller: _repsCtrls[exIdx][setIdx],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '次数',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _completeSet(exIdx, setIdx);
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('完成本组'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: AppColors.onColoredBadge,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Future set — grey placeholder
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              '第 ${s.setNumber} 组',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.futureItem,
              ),
            ),
          ),
          Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.disabled),
          const SizedBox(width: 8),
          Text(
            '${s.targetWeight > 0 ? '${s.targetWeight}kg × ' : ''}${s.targetReps}次',
            style: TextStyle(fontSize: 13, color: AppColors.futureItem),
          ),
        ],
      ),
    );
  }

  // ── Rest timer bar ──

  Widget _buildRestTimerBar() {
    return AnimatedBuilder(
      animation: _restTimer,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1), // shadow color - keep as is
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '组间休息',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // −10s button
                  IconButton(
                    onPressed: () => _restTimer.adjustTime(-10),
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: '-10秒',
                    iconSize: 32,
                  ),

                  // Countdown display
                  SizedBox(
                    width: 120,
                    child: Text(
                      _restTimer.formatted,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: _restTimer.remaining <= 5
                            ? AppColors.danger
                            : Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                      ),
                    ),
                  ),

                  // +10s button
                  IconButton(
                    onPressed: () => _restTimer.adjustTime(10),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: '+10秒',
                    iconSize: 32,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Skip rest button
              TextButton(
                onPressed: () {
                  _restTimer.cancel();
                  setState(() => _isResting = false);
                },
                child: const Text('跳过休息', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}


