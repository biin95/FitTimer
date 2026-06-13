import 'package:flutter/material.dart';
import '../models/exercise_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_helpers.dart';
import '../widgets/badge_number.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final ExerciseInfo exercise;
  final List<ExerciseInfo>? exerciseList;
  final int? initialIndex;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    this.exerciseList,
    this.initialIndex,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late int _currentIndex;
  late List<ExerciseInfo> _exercises;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _exercises = widget.exerciseList ?? [widget.exercise];
    _currentIndex = widget.initialIndex ?? _exercises.indexOf(widget.exercise);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ExerciseInfo get _currentExercise => _exercises[_currentIndex];

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 循环到最后一个
      _pageController.animateToPage(
        _exercises.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < _exercises.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 循环到第一个
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final hasMultiple = _exercises.length > 1;

    return Scaffold(
      body: Column(
        children: [
          // ── 通知栏占位 ──
          SizedBox(height: statusBarHeight),

          // ── 返回按钮栏 ──
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    _currentExercise.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasMultiple) ...[
                  // 左右切换按钮
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _goToPrevious,
                  ),
                  Text(
                    '${_currentIndex + 1}/${_exercises.length}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _goToNext,
                  ),
                ],
              ],
            ),
          ),

          // ── 可滑动内容 ──
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _exercises.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return _buildExerciseContent(context, exercise, colorScheme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseContent(BuildContext context, ExerciseInfo exercise, ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 图片 ──
          _buildImageHeader(exercise, colorScheme),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 名称 + 标签 ──
                _buildHeader(context, exercise),
                const SizedBox(height: 20),

                // ── 目标肌群 ──
                _buildSectionTitle(context, '目标肌群'),
                const SizedBox(height: 8),
                _buildMuscleChips(context, exercise),
                const SizedBox(height: 20),

                // ── 动作描述 ──
                _buildSectionTitle(context, '动作描述'),
                const SizedBox(height: 8),
                Text(
                  exercise.description,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 20),

                // ── 动作步骤 ──
                _buildSectionTitle(context, '动作步骤'),
                const SizedBox(height: 8),
                _buildSteps(context, exercise),
                const SizedBox(height: 20),

                // ── 要领提示 ──
                _buildSectionTitle(context, '要领提示'),
                const SizedBox(height: 8),
                _buildTips(exercise),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader(ExerciseInfo exercise, ColorScheme colorScheme) {
    return Container(
      height: 240,
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      child: Image.asset(
        exercise.imageAssetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                exercise.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ExerciseInfo exercise) {
    return Row(
      children: [
        Expanded(
          child: Text(
            exercise.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 难度标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: difficultyColor(exercise.difficulty).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            exercise.difficultyLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: difficultyColor(exercise.difficulty),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 分类标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            exercise.category,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildMuscleChips(BuildContext context, ExerciseInfo exercise) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: exercise.targetMuscles.map((muscle) {
        return Chip(
          label: Text(muscle, style: const TextStyle(fontSize: 13)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildSteps(BuildContext context, ExerciseInfo exercise) {
    return Column(
      children: List.generate(exercise.steps.length, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BadgeNumber(
                color: Theme.of(context).colorScheme.primary,
                number: i + 1,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exercise.steps[i],
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTips(ExerciseInfo exercise) {
    return Column(
      children: exercise.tips.map((tip) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.tip),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tip,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
