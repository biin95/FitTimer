/// 训练动作信息模型，用于动作演示功能。
class ExerciseInfo {
  final String id;
  final String name;
  final String category;
  final List<String> targetMuscles;
  final String description;
  final List<String> steps;
  final List<String> tips;
  final String difficulty; // 'beginner' | 'intermediate' | 'advanced'
  final String imageAssetPath;

  const ExerciseInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.targetMuscles,
    required this.description,
    required this.steps,
    required this.tips,
    required this.difficulty,
    required this.imageAssetPath,
  });

  String get difficultyLabel {
    switch (difficulty) {
      case 'beginner':
        return '初级';
      case 'intermediate':
        return '中级';
      case 'advanced':
        return '高级';
      default:
        return difficulty;
    }
  }
}
