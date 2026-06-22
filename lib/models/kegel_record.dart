class KegelRecord {
  final int? id;
  final int date; // timestamp (start of day)
  final int totalSets;
  final int completedSets;
  final int createdAt; // timestamp

  KegelRecord({
    this.id,
    required this.date,
    required this.totalSets,
    required this.completedSets,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'total_sets': totalSets,
      'completed_sets': completedSets,
      'created_at': createdAt,
    };
  }

  factory KegelRecord.fromMap(Map<String, dynamic> map) {
    return KegelRecord(
      id: map['id'] as int?,
      date: map['date'] as int,
      totalSets: map['total_sets'] as int,
      completedSets: map['completed_sets'] as int,
      createdAt: map['created_at'] as int,
    );
  }
}
