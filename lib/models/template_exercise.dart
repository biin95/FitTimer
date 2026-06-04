class TemplateExercise {
  final int? id;
  final int templateId;
  final String exerciseName;
  final int targetSets;
  final int targetReps;
  final double targetWeight;
  final int restDuration; // seconds
  final int sortOrder;
  final String exerciseType; // 'strength' / 'cardio' / 'interval'
  final int? durationMinutes; // cardio/interval only
  final double? distanceKm; // cardio only
  final double? speed; // cardio only (km/h)
  final double? incline; // cardio only (percentage)
  final int? intervalRounds; // 间歇训练轮数（仅 interval 类型）

  TemplateExercise({
    this.id,
    required this.templateId,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    required this.targetWeight,
    required this.restDuration,
    required this.sortOrder,
    this.exerciseType = 'strength',
    this.durationMinutes,
    this.distanceKm,
    this.speed,
    this.incline,
    this.intervalRounds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'template_id': templateId,
      'exercise_name': exerciseName,
      'target_sets': targetSets,
      'target_reps': targetReps,
      'target_weight': targetWeight,
      'rest_duration': restDuration,
      'sort_order': sortOrder,
      'exercise_type': exerciseType,
      'duration_minutes': durationMinutes,
      'distance_km': distanceKm,
      'speed': speed,
      'incline': incline,
      'interval_rounds': intervalRounds,
    };
  }

  factory TemplateExercise.fromMap(Map<String, dynamic> map) {
    return TemplateExercise(
      id: map['id'] as int?,
      templateId: map['template_id'] as int,
      exerciseName: map['exercise_name'] as String,
      targetSets: map['target_sets'] as int,
      targetReps: map['target_reps'] as int,
      targetWeight: (map['target_weight'] as num).toDouble(),
      restDuration: map['rest_duration'] as int,
      sortOrder: map['sort_order'] as int,
      exerciseType: map['exercise_type'] as String? ?? 'strength',
      durationMinutes: map['duration_minutes'] as int?,
      distanceKm: map['distance_km'] != null
          ? (map['distance_km'] as num).toDouble()
          : null,
      speed: map['speed'] != null
          ? (map['speed'] as num).toDouble()
          : null,
      incline: map['incline'] != null
          ? (map['incline'] as num).toDouble()
          : null,
      intervalRounds: map['interval_rounds'] as int?,
    );
  }
}
