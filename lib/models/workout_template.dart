class WorkoutTemplate {
  final int? id;
  final String name;
  final int createdAt;

  WorkoutTemplate({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }

  factory WorkoutTemplate.fromMap(Map<String, dynamic> map) {
    return WorkoutTemplate(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['created_at'] as int,
    );
  }
}
