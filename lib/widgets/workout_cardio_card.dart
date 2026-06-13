import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/badge_number.dart';
import '../widgets/delete_button.dart';

/// 有氧运动编辑卡片
class WorkoutCardioCard extends StatefulWidget {
  final int index;
  final String name;
  final int? durationMinutes;
  final double? distanceKm;
  final double? speed;
  final double? incline;

  final ValueChanged<String> onNameChanged;
  final ValueChanged<int?> onDurationChanged;
  final ValueChanged<double?> onDistanceChanged;
  final ValueChanged<double?> onSpeedChanged;
  final ValueChanged<double?> onInclineChanged;
  final VoidCallback onDelete;

  const WorkoutCardioCard({
    super.key,
    required this.index,
    required this.name,
    this.durationMinutes,
    this.distanceKm,
    this.speed,
    this.incline,
    required this.onNameChanged,
    required this.onDurationChanged,
    required this.onDistanceChanged,
    required this.onSpeedChanged,
    required this.onInclineChanged,
    required this.onDelete,
  });

  @override
  State<WorkoutCardioCard> createState() => _WorkoutCardioCardState();
}

class _WorkoutCardioCardState extends State<WorkoutCardioCard> {
  late TextEditingController _durationCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _speedCtrl;
  late TextEditingController _inclineCtrl;

  @override
  void initState() {
    super.initState();
    _durationCtrl = TextEditingController(
        text: widget.durationMinutes != null && widget.durationMinutes! > 0
            ? '${widget.durationMinutes}' : '');
    _distanceCtrl = TextEditingController(
        text: widget.distanceKm != null && widget.distanceKm! > 0
            ? '${widget.distanceKm}' : '');
    _speedCtrl = TextEditingController(
        text: widget.speed != null && widget.speed! > 0
            ? '${widget.speed}' : '');
    _inclineCtrl = TextEditingController(
        text: widget.incline != null && widget.incline! > 0
            ? '${widget.incline}' : '');
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _distanceCtrl.dispose();
    _speedCtrl.dispose();
    _inclineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + name + delete
            Row(
              children: [
                BadgeNumber(
                  color: AppColors.warning,
                  number: widget.index + 1,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.directions_run, size: 20, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: widget.name.isEmpty
                      ? TextField(
                          decoration: const InputDecoration(
                            hintText: '运动名称（如：跑步、爬坡）',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onChanged: widget.onNameChanged,
                        )
                      : GestureDetector(
                          onTap: () {
                            final nameCtrl = TextEditingController(text: widget.name);
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('编辑运动名称'),
                                content: TextField(
                                  controller: nameCtrl,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: '运动名称',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      widget.onNameChanged(nameCtrl.text);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('确定'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            widget.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
                DeleteButton(onPressed: widget.onDelete, tooltip: '删除动作'),
              ],
            ),
            const Divider(height: 16),
            // Duration + Distance row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '时长',
                      suffixText: '分钟',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => widget.onDurationChanged(int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _distanceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '距离',
                      suffixText: 'km',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => widget.onDistanceChanged(double.tryParse(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Speed + Incline row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _speedCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '速度',
                      suffixText: 'km/h',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => widget.onSpeedChanged(double.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inclineCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '坡度',
                      suffixText: '%',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => widget.onInclineChanged(double.tryParse(v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
;
  }
}
