import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workout_record.dart';
import '../models/exercise_record.dart';
import '../models/workout_template.dart';
import '../models/template_exercise.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final DateTime date;

  const WorkoutSessionScreen({super.key, required this.date});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  static const _vibrateChannel = MethodChannel('com.fittimer/vibrate');
  static const _restServiceChannel = MethodChannel('com.fittimer/rest_service');

  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();

  WorkoutRecord? _workoutRecord;
  List<_SessionExercise> _exercises = [];
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  bool _draftSaved = false;

  // Rest timer
  int _restRemaining = 0;
  int _restTotal = 0;
  Timer? _restTimer;
  Timer? _reminderTimer;
  String _restExerciseName = '';
  int _reminderDuration = 3;

  @override
  void initState() {
    super.initState();
    _loadOrCreateWorkout();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _reminderTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
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
              isCompleted: er.actualReps != null,
            )).toList(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading workout: $e');
    }
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择训练类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fitness_center, color: Colors.blue),
              title: const Text('力量训练'),
              subtitle: const Text('组数、次数、重量'),
              onTap: () {
                Navigator.pop(ctx);
                _addStrengthExercise();
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run, color: Colors.orange),
              title: const Text('有氧运动'),
              subtitle: const Text('时间、距离、速度'),
              onTap: () {
                Navigator.pop(ctx);
                _addCardioExercise();
              },
            ),
          ],
        ),
      ),
    );
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
      } else {
        // Complete
        s.isCompleted = true;
        s.actualReps = s.actualReps ?? s.targetReps;
        s.actualWeight = s.actualWeight ?? s.targetWeight;
        _hasUnsavedChanges = true;

        // Start rest timer if not last set
        if (setIndex < exercise.sets.length - 1 && exercise.restDuration > 0) {
          _startRestTimer(exercise.restDuration, exercise.name);
        }
      }
    });
  }

  void _startRestTimer(int seconds, String exerciseName) {
    log.log('VIBRATE', '开始休息计时: $exerciseName, 休息${seconds}秒');
    _restTimer?.cancel();
    _reminderTimer?.cancel();
    _vibrateChannel.invokeMethod('cancel');
    setState(() {
      _restRemaining = seconds;
      _restTotal = seconds;
      _restExerciseName = exerciseName;
    });
    // Start foreground service to keep timer alive when screen is off
    log.log('VIBRATE', '前台服务 start: exercise=$exerciseName, seconds=$seconds');
    _restServiceChannel.invokeMethod('start', {
      'exerciseName': exerciseName,
      'seconds': seconds,
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restRemaining <= 1) {
        log.log('VIBRATE', '休息倒计时结束, _restRemaining=$_restRemaining');
        timer.cancel();
        setState(() {
          _restRemaining = 0;
        });
        _startReminder(exerciseName);
      } else {
        setState(() => _restRemaining--);
      }
    });
  }

  Future<void> _startReminder(String exerciseName) async {
    log.log('VIBRATE', '_startReminder 被调用, _reminderDuration=$_reminderDuration');
    // Start continuous vibration for _reminderDuration seconds
    log.log('VIBRATE', '调用震动 MethodChannel: duration=${_reminderDuration * 1000}ms');
    try {
      await _vibrateChannel.invokeMethod('vibrate', {'duration': _reminderDuration * 1000});
      log.log('VIBRATE', '震动 MethodChannel 调用成功');
    } catch (e) {
      log.log('VIBRATE', '震动 MethodChannel 异常: $e');
    }
    _reminderTimer = Timer(Duration(seconds: _reminderDuration), () {
      _reminderTimer = null;
      _restServiceChannel.invokeMethod('stop');
      setState(() {
        _restExerciseName = '';
      });
    });
  }

  void _adjustRest(int delta) {
    setState(() {
      _restRemaining = (_restRemaining + delta).clamp(0, 9999);
    });
  }

  // --- Save workout ---
  Future<void> _saveWorkout({required bool markCompleted}) async {
    await _ensureWorkoutRecord();

    // Determine sport type from exercise types
    final hasStrength = _exercises.any((e) => e.exerciseType == 'strength');
    final hasCardio = _exercises.any((e) => e.exerciseType == 'cardio');
    String sportType = 'strength';
    if (hasStrength && hasCardio) {
      sportType = 'mixed';
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
      if (ex.exerciseType == 'cardio') {
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
            actualReps: s.isCompleted ? (s.actualReps ?? s.targetReps) : null,
            targetWeight: s.targetWeight,
            actualWeight: s.isCompleted ? (s.actualWeight ?? s.targetWeight) : null,
            restDuration: ex.restDuration,
            createdAt: DateTime.now().millisecondsSinceEpoch,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前没有训练内容，请先添加训练动作'),
          backgroundColor: Colors.orange,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('训练已完成！'),
          backgroundColor: Colors.green,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

    return PopScope(
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
          title: Text('$dateStr 训练'),
          centerTitle: true,
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'template') _applyTemplate();
                if (v == 'add') _addExercise();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'template', child: Text('套用模板')),
                const PopupMenuItem(value: 'add', child: Text('手动添加动作')),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Rest timer bar
                  if (_restRemaining > 0) _buildRestTimerBar(),

                  // Exercise list
                  Expanded(
                    child: _exercises.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    size: 64,
                                    color:
                                        Theme.of(context).colorScheme.outline),
                                const SizedBox(height: 12),
                                const Text('点击右上角添加训练动作或套用模板'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _exercises.length,
                            itemBuilder: (_, i) =>
                                _exercises[i].exerciseType == 'cardio'
                                    ? _buildCardioCard(i)
                                    : _buildExerciseCard(i),
                          ),
                  ),

                  // Bottom buttons
                  _buildBottomBar(),
                ],
              ),
        floatingActionButton: (_exercises.isEmpty || _draftSaved)
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
    );
  }

  Widget _buildRestTimerBar() {
    final progress =
        _restTotal > 0 ? _restRemaining / _restTotal : 0.0;
    final minutes = _restRemaining ~/ 60;
    final seconds = _restRemaining % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          const Icon(Icons.timer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_restExerciseName 组间休息',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
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
              _reminderTimer?.cancel();
              _vibrateChannel.invokeMethod('cancel');
              _restServiceChannel.invokeMethod('stop');
              setState(() {
                _restRemaining = 0;
                _restExerciseName = '';
              });
            },
          ),
        ],
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
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '${exerciseIndex + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
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
                      : Text(
                          exercise.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
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
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
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
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '${exerciseIndex + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.directions_run, size: 20, color: Colors.orange),
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
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
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
  String exerciseType; // 'strength' or 'cardio'
  int? durationMinutes;
  double? distanceKm;
  double? speed;
  double? incline;

  _SessionExercise({
    required this.name,
    required this.restDuration,
    required this.sets,
    this.exerciseType = 'strength',
    this.durationMinutes,
    this.distanceKm,
    this.speed,
    this.incline,
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
