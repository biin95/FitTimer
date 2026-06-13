/// 一次训练会话中的单个动作（含实时状态）
class SessionExercise {
  String name;
  int restDuration;
  List<SessionSet> sets;
  String exerciseType; // 'strength' / 'cardio' / 'interval'
  int? durationMinutes;
  double? distanceKm;
  double? speed;
  double? incline;
  int? intervalRounds;

  SessionExercise({
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

/// 一次训练会话中的单组数据（含实时状态）
class SessionSet {
  final int? id;
  int targetReps;
  double targetWeight;
  int? actualReps;
  double? actualWeight;
  bool isCompleted;

  SessionSet({
    this.id,
    required this.targetReps,
    required this.targetWeight,
    this.actualReps,
    this.actualWeight,
    this.isCompleted = false,
  });
}
