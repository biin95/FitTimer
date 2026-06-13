import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/badge_number.dart';

/// 间歇训练卡片（只读展示）
class WorkoutIntervalCard extends StatelessWidget {
  final int index;
  final String name;
  final int rounds;
  final int durationMinutes;
  final VoidCallback? onDelete;

  const WorkoutIntervalCard({
    super.key,
    required this.index,
    required this.name,
    required this.rounds,
    required this.durationMinutes,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            BadgeNumber(
              color: AppColors.info,
              number: index + 1,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.timer, size: 20, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? '间歇训练' : name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$rounds轮 · $durationMinutes分钟',
                    style: TextStyle(fontSize: 12, color: AppColors.subtitle),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: AppColors.danger),
                onPressed: onDelete,
                tooltip: '删除',
              ),
          ],
        ),
      ),
    );
  }
}
