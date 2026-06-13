import 'package:flutter/material.dart';
import '../data/exercise_catalog.dart';
import '../models/exercise_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_helpers.dart';
import '../utils/page_transitions.dart';
import '../utils/stagger_animation.dart';
import 'exercise_detail_screen.dart';

class ExerciseCatalogScreen extends StatefulWidget {
  const ExerciseCatalogScreen({super.key});

  @override
  State<ExerciseCatalogScreen> createState() => _ExerciseCatalogScreenState();
}

class _ExerciseCatalogScreenState extends State<ExerciseCatalogScreen> {
  int _selectedCategoryIndex = 0;

  List<String> get _categories => ExerciseCatalog.categories;

  List<ExerciseInfo> get _currentExercises =>
      ExerciseCatalog.getByCategory(_categories[_selectedCategoryIndex]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动作库'),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // ── 左侧分类列表 ──
          _buildCategoryList(),

          // ── 分隔线 ──
          const VerticalDivider(width: 1),

          // ── 右侧动作列表 ──
          Expanded(child: _buildExerciseList()),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      width: 88,
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedCategoryIndex;
          final category = _categories[index];
          final count = ExerciseCatalog.getByCategory(category).length;

          return InkWell(
            onTap: () => setState(() => _selectedCategoryIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _categoryIcon(category),
                    size: 22,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.subtitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.7)
                          : AppColors.placeholder,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseList() {
    final exercises = _currentExercises;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final ex = exercises[index];
        return StaggerItem(
          index: index,
          child: _buildExerciseTile(ex),
        );
      },
    );
  }

  Widget _buildExerciseTile(ExerciseInfo ex) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Image.asset(
            ex.imageAssetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.fitness_center,
                color: colorScheme.primary.withValues(alpha: 0.6),
                size: 22,
              ),
            ),
          ),
        ),
      ),
      title: Text(
        ex.name,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        ex.targetMuscles.take(3).join('、'),
        style: TextStyle(fontSize: 12, color: colorScheme.outline),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: difficultyColor(ex.difficulty).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          ex.difficultyLabel,
          style: TextStyle(
            fontSize: 11,
            color: difficultyColor(ex.difficulty),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onTap: () {
        final exercises = _currentExercises;
        final index = exercises.indexOf(ex);
        pushSlideFade(
          context,
          ExerciseDetailScreen(
            exercise: ex,
            exerciseList: exercises,
            initialIndex: index >= 0 ? index : 0,
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '胸部':
        return Icons.fitness_center;
      case '背部':
        return Icons.accessibility_new;
      case '腿部':
        return Icons.directions_run;
      case '肩部':
        return Icons.sports_gymnastics;
      case '手臂':
        return Icons.sports_martial_arts;
      case '核心':
        return Icons.self_improvement;
      case '有氧':
        return Icons.favorite;
      default:
        return Icons.fitness_center;
    }
  }

}
