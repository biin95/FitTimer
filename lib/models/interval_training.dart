class IntervalTraining {
  final int? id;
  final String name; // 训练名称（如 "HIIT 间歇训练"）
  final int rounds; // 重复轮数
  final int totalDuration; // 总时长（秒，计算得出）
  final int createdAt; // 创建时间戳

  IntervalTraining({
    this.id,
    required this.name,
    required this.rounds,
    required this.totalDuration,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rounds': rounds,
      'total_duration': totalDuration,
      'created_at': createdAt,
    };
  }

  factory IntervalTraining.fromMap(Map<String, dynamic> map) {
    return IntervalTraining(
      id: map['id'] as int?,
      name: map['name'] as String,
      rounds: map['rounds'] as int,
      totalDuration: map['total_duration'] as int,
      createdAt: map['created_at'] as int,
    );
  }

  /// 格式化总时长为 MM:SS
  String get formattedTotalDuration {
    final minutes = totalDuration ~/ 60;
    final seconds = totalDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化总时长为可读字符串
  String get readableDuration {
    final minutes = totalDuration ~/ 60;
    final seconds = totalDuration % 60;
    if (minutes > 0 && seconds > 0) {
      return '$minutes 分 $seconds 秒';
    } else if (minutes > 0) {
      return '$minutes 分钟';
    } else {
      return '$seconds 秒';
    }
  }

  /// 复制并修改
  IntervalTraining copyWith({
    int? id,
    String? name,
    int? rounds,
    int? totalDuration,
    int? createdAt,
  }) {
    return IntervalTraining(
      id: id ?? this.id,
      name: name ?? this.name,
      rounds: rounds ?? this.rounds,
      totalDuration: totalDuration ?? this.totalDuration,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 计算总时长（静态方法）
  static int calculateTotalDuration(List<int> segmentDurations, int rounds) {
    final oneRoundDuration = segmentDurations.fold(0, (sum, d) => sum + d);
    return oneRoundDuration * rounds;
  }
}
