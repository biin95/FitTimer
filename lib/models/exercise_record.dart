class ExerciseRecord {
  final int? id;
  final int workoutId;
  final String exerciseName;
  final int setNumber;
  final int targetReps;
  final int? actualReps;
  final double targetWeight;
  final double? actualWeight;
  final int restDuration; // seconds
  final int createdAt;
  final String exerciseType; // 'strength' or 'cardio'
  final int? durationMinutes; // cardio only
  final double? distanceKm; // cardio only
  final double? speed; // cardio only (km/h)
  final double? incline; // cardio only (percentage)

  ExerciseRecord({
    this.id,
    required this.workoutId,
    required this.exerciseName,
    required this.setNumber,
    required this.targetReps,
    this.actualReps,
    required this.targetWeight,
    this.actualWeight,
    required this.restDuration,
    required this.createdAt,
    this.exerciseType = 'strength',
    this.durationMinutes,
    this.distanceKm,
    this.speed,
    this.incline,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'exercise_name': exerciseName,
      'set_number': setNumber,
      'target_reps': targetReps,
      'actual_reps': actualReps,
      'target_weight': targetWeight,
      'actual_weight': actualWeight,
      'rest_duration': restDuration,
      'created_at': createdAt,
      'exercise_type': exerciseType,
      'duration_minutes': durationMinutes,
      'distance_km': distanceKm,
      'speed': speed,
      'incline': incline,
    };
  }

  factory ExerciseRecord.fromMap(Map<String, dynamic> map) {
    return ExerciseRecord(
      id: map['id'] as int?,
      workoutId: map['workout_id'] as int,
      exerciseName: map['exercise_name'] as String,
      setNumber: map['set_number'] as int,
      targetReps: map['target_reps'] as int,
      actualReps: map['actual_reps'] as int?,
      targetWeight: (map['target_weight'] as num).toDouble(),
      actualWeight: map['actual_weight'] != null
          ? (map['actual_weight'] as num).toDouble()
          : null,
      restDuration: map['rest_duration'] as int,
      createdAt: map['created_at'] as int,
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
    );
  }
}
