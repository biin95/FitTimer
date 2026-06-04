import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workout_template.dart';
import '../models/template_exercise.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/badge_number.dart';
import '../widgets/delete_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/move_arrows.dart';
import '../widgets/snackbar_helper.dart';

class TemplateEditScreen extends StatefulWidget {
  final WorkoutTemplate? template;

  const TemplateEditScreen({super.key, this.template});

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  final DatabaseService _db = DatabaseService();
  late TextEditingController _nameController;
  List<_ExerciseItem> _exercises = [];
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSorting = false; // 排序模式
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.template != null;
    _nameController = TextEditingController(
      text: widget.template?.name ?? '',
    );
    if (_isEditing) {
      _loadExistingExercises();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingExercises() async {
    setState(() => _isLoading = true);
    try {
      final exercises = await _db.getTemplateExercises(widget.template!.id!);
      setState(() {
        _exercises = exercises
            .map((e) => _ExerciseItem.fromTemplateExercise(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading exercises: $e');
    }
  }

  void _addExercise() {
    setState(() {
      _exercises.add(_ExerciseItem(exerciseType: 'strength'));
    });
    _scrollToBottom();
  }

  void _addCardioExercise() {
    setState(() {
      _exercises.add(_ExerciseItem(
        exerciseType: 'cardio',
        sets: 0,
        reps: 0,
        rest: 0,
      ));
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

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
  }

  void _moveExerciseUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _exercises.removeAt(index);
      _exercises.insert(index - 1, item);
    });
  }

  void _moveExerciseDown(int index) {
    if (index >= _exercises.length - 1) return;
    setState(() {
      final item = _exercises.removeAt(index);
      _exercises.insert(index + 1, item);
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

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // 序号
                      BadgeNumber(
                        color: isCardio ? AppColors.warning : Theme.of(context).colorScheme.primary,
                        number: index + 1,
                      ),
                      const SizedBox(width: 12),
                      // 动作名称
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.nameController.text.isEmpty ? '(未命名)' : ex.nameController.text,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            if (isCardio)
                              Text('有氧运动', style: TextStyle(fontSize: 12, color: AppColors.subtitle))
                            else
                              Text(
                                '${ex.setsController.text}组 × ${ex.repsController.text}次'
                                '${ex.weightController.text.isNotEmpty ? ' @ ${ex.weightController.text}kg' : ''}',
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

  Future<void> _saveTemplate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入模板名称')),
      );
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个训练动作')),
      );
      return;
    }

    // Validate exercises
    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      if (ex.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('第 ${i + 1} 个动作名称不能为空')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      int templateId;

      if (_isEditing && widget.template!.id != null) {
        // Update existing template
        await _db.updateTemplate(WorkoutTemplate(
          id: widget.template!.id,
          name: name,
          createdAt: widget.template!.createdAt,
        ));
        templateId = widget.template!.id!;

        // Delete old exercises and insert new ones
        await _db.deleteTemplateExercisesForTemplate(templateId);
      } else {
        // Create new template
        templateId = await _db.insertTemplate(WorkoutTemplate(
          name: name,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }

      // Insert all exercises
      for (int i = 0; i < _exercises.length; i++) {
        final ex = _exercises[i];
        if (ex.exerciseType == 'cardio') {
          await _db.insertTemplateExercise(TemplateExercise(
            templateId: templateId,
            exerciseName: ex.nameController.text.trim(),
            targetSets: 0,
            targetReps: 0,
            targetWeight: 0,
            restDuration: 0,
            sortOrder: i,
            exerciseType: 'cardio',
            durationMinutes: int.tryParse(ex.durationController.text),
            distanceKm: double.tryParse(ex.distanceController.text),
            speed: double.tryParse(ex.speedController.text),
            incline: double.tryParse(ex.inclineController.text),
          ));
        } else {
          await _db.insertTemplateExercise(TemplateExercise(
            templateId: templateId,
            exerciseName: ex.nameController.text.trim(),
            targetSets: int.tryParse(ex.setsController.text) ?? 0,
            targetReps: int.tryParse(ex.repsController.text) ?? 0,
            targetWeight: double.tryParse(ex.weightController.text) ?? 0.0,
            restDuration: int.tryParse(ex.restController.text) ?? 60,
            sortOrder: i,
          ));
        }
      }

      if (mounted) {
        showSuccessSnackBar(context, _isEditing ? '模板已更新' : '模板已创建');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error saving template: $e');
      if (mounted) {
        showErrorSnackBar(context, '保存失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSorting
            ? '调整顺序'
            : (_isEditing ? '编辑模板' : '创建模板')),
        centerTitle: true,
        actions: [
          if (!_isSorting && _exercises.length > 1)
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () => setState(() => _isSorting = true),
              tooltip: '调整顺序',
            ),
          if (_isSorting)
            TextButton(
              onPressed: () => setState(() => _isSorting = false),
              child: const Text('完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          if (!_isSorting)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'add_cardio') _addCardioExercise();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'add_cardio', child: Text('添加有氧运动')),
              ],
            ),
          if (!_isSorting)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _saveTemplate();
                    },
                    child: const Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
        ],
      ),
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : _isSorting
              ? _buildSortView()
              : Column(
              children: [
                // Template name field
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '模板名称',
                      hintText: '例如：胸肌训练日',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),

                // Exercises header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        '训练动作',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_exercises.length} 个动作',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Exercise list
                Expanded(
                  child: _exercises.isEmpty
                      ? EmptyState(
                          icon: Icons.add_circle_outline,
                          message: '点击添加训练动作',
                          onTap: _addExercise,
                        )
                      : CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildExerciseCard(_exercises[index], index),
                                  childCount: _exercises.length,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: _isSorting
          ? null
          : FloatingActionButton(
              onPressed: _addExercise,
              tooltip: '添加训练动作',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildExerciseCard(_ExerciseItem exercise, int index) {
    if (exercise.exerciseType == 'cardio') {
      return _buildCardioExerciseCard(exercise, index);
    }
    return Card(
      key: ValueKey(index),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Reorder handle
                Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),

                // Exercise number
                BadgeNumber(
                  color: Theme.of(context).colorScheme.primary,
                  number: index + 1,
                ),
                const SizedBox(width: 12),

                // Exercise name
                Expanded(
                  child: TextField(
                    controller: exercise.nameController,
                    decoration: const InputDecoration(
                      hintText: '动作名称',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),

                const SizedBox(width: 8),

                // Delete button
                DeleteButton(
                  onPressed: () => _removeExercise(index),
                  tooltip: '删除动作',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Numeric fields row 1: Sets & Reps
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: exercise.setsController,
                    decoration: const InputDecoration(
                      labelText: '组数',
                      hintText: '3',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: exercise.repsController,
                    decoration: const InputDecoration(
                      labelText: '每组次数',
                      hintText: '10',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Numeric fields row 2: Weight & Rest
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: exercise.weightController,
                    decoration: const InputDecoration(
                      labelText: '重量(kg)',
                      hintText: '20.0',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: exercise.restController,
                    decoration: const InputDecoration(
                      labelText: '组间休息(秒)',
                      hintText: '60',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardioExerciseCard(_ExerciseItem exercise, int index) {
    return Card(
      key: ValueKey('cardio_$index'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                BadgeNumber(
                  color: AppColors.warning,
                  number: index + 1,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.directions_run, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: exercise.nameController,
                    decoration: const InputDecoration(
                      hintText: '运动名称（如：跑步、爬坡）',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                DeleteButton(
                  onPressed: () => _removeExercise(index),
                  tooltip: '删除动作',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: exercise.durationController,
                    decoration: const InputDecoration(
                      labelText: '时长',
                      suffixText: '分钟',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: exercise.distanceController,
                    decoration: const InputDecoration(
                      labelText: '距离',
                      suffixText: 'km',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: exercise.speedController,
                    decoration: const InputDecoration(
                      labelText: '速度',
                      suffixText: 'km/h',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: exercise.inclineController,
                    decoration: const InputDecoration(
                      labelText: '坡度',
                      suffixText: '%',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Holds the controllers for a single exercise row.
class _ExerciseItem {
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final TextEditingController restController;
  final TextEditingController durationController;
  final TextEditingController distanceController;
  final TextEditingController speedController;
  final TextEditingController inclineController;
  String exerciseType; // 'strength' or 'cardio'

  _ExerciseItem({
    String name = '',
    int sets = 3,
    int reps = 10,
    double weight = 0,
    int rest = 60,
    this.exerciseType = 'strength',
    int? durationMinutes,
    double? distanceKm,
    double? speed,
    double? incline,
  })  : nameController = TextEditingController(text: name),
        setsController = TextEditingController(text: sets.toString()),
        repsController = TextEditingController(text: reps.toString()),
        weightController = TextEditingController(
            text: weight > 0 ? weight.toString() : ''),
        restController = TextEditingController(text: rest.toString()),
        durationController = TextEditingController(
            text: durationMinutes != null && durationMinutes > 0
                ? durationMinutes.toString() : ''),
        distanceController = TextEditingController(
            text: distanceKm != null && distanceKm > 0
                ? distanceKm.toString() : ''),
        speedController = TextEditingController(
            text: speed != null && speed > 0
                ? speed.toString() : ''),
        inclineController = TextEditingController(
            text: incline != null && incline > 0
                ? incline.toString() : '');

  factory _ExerciseItem.fromTemplateExercise(TemplateExercise exercise) {
    return _ExerciseItem(
      name: exercise.exerciseName,
      sets: exercise.targetSets,
      reps: exercise.targetReps,
      weight: exercise.targetWeight,
      rest: exercise.restDuration,
      exerciseType: exercise.exerciseType,
      durationMinutes: exercise.durationMinutes,
      distanceKm: exercise.distanceKm,
      speed: exercise.speed,
      incline: exercise.incline,
    );
  }

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
    restController.dispose();
    durationController.dispose();
    distanceController.dispose();
    speedController.dispose();
    inclineController.dispose();
  }
}
