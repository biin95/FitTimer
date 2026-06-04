class IntervalSegment {
  final int? id;
  final int? trainingId; // 关联的间歇训练 ID
  final int sortOrder; // 排序序号
  final String type; // 'exercise' / 'rest'
  final int durationSec; // 时长（秒）
  final String? name; // 可选名称（如 "运动"、"休息"）

  IntervalSegment({
    this.id,
    this.trainingId,
    required this.sortOrder,
    required this.type,
    required this.durationSec,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'training_id': trainingId,
      'sort_order': sortOrder,
      'type': type,
      'duration_sec': durationSec,
      'name': name,
    };
  }

  factory IntervalSegment.fromMap(Map<String, dynamic> map) {
    return IntervalSegment(
      id: map['id'] as int?,
      trainingId: map['training_id'] as int?,
      sortOrder: map['sort_order'] as int,
      type: map['type'] as String,
      durationSec: map['duration_sec'] as int,
      name: map['name'] as String?,
    );
  }

  /// 格式化时长为 MM:SS
  String get formattedDuration {
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 是否为运动段
  bool get isExercise => type == 'exercise';

  /// 是否为休息段
  bool get isRest => type == 'rest';

  /// 获取显示名称
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    return isExercise ? '运动' : '休息';
  }

  /// 复制并修改
  IntervalSegment copyWith({
    int? id,
    int? trainingId,
    int? sortOrder,
    String? type,
    int? durationSec,
    String? name,
  }) {
    return IntervalSegment(
      id: id ?? this.id,
      trainingId: trainingId ?? this.trainingId,
      sortOrder: sortOrder ?? this.sortOrder,
      type: type ?? this.type,
      durationSec: durationSec ?? this.durationSec,
      name: name ?? this.name,
    );
  }
}
