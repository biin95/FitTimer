class WorkoutRecord {
  final int? id;
  final int date; // timestamp
  final String sportType; // strength / cardio / mixed
  final int startedAt;
  final int? completedAt;
  final bool isCompleted;

  WorkoutRecord({
    this.id,
    required this.date,
    required this.sportType,
    required this.startedAt,
    this.completedAt,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'sport_type': sportType,
      'started_at': startedAt,
      'completed_at': completedAt,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory WorkoutRecord.fromMap(Map<String, dynamic> map) {
    return WorkoutRecord(
      id: map['id'] as int?,
      date: map['date'] as int,
      sportType: map['sport_type'] as String,
      startedAt: map['started_at'] as int,
      completedAt: map['completed_at'] as int?,
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }
}
