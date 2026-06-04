import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/interval_segment.dart';
import '../theme/app_colors.dart';
import '../widgets/delete_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/move_arrows.dart';
import 'interval_training_screen.dart';

class IntervalConfigScreen extends StatefulWidget {
  const IntervalConfigScreen({
    super.key,
  });

  @override
  State<IntervalConfigScreen> createState() => _IntervalConfigScreenState();
}

class _IntervalConfigScreenState extends State<IntervalConfigScreen> {
  final TextEditingController _nameController = TextEditingController(text: '间歇训练');
  final TextEditingController _roundsController = TextEditingController(text: '3');
  final ScrollController _scrollController = ScrollController();

  List<_SegmentItem> _segments = [];

  @override
  void initState() {
    super.initState();
    // 默认：一段休息 + 一段运动
    _segments = [
      _SegmentItem(type: 'rest', durationSec: 120),
      _SegmentItem(type: 'exercise', durationSec: 60),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roundsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _totalDuration {
    final rounds = int.tryParse(_roundsController.text) ?? 1;
    final oneRoundDuration = _segments.fold(0, (sum, s) => sum + s.durationSec);
    return oneRoundDuration * rounds;
  }

  String get _formattedTotalDuration {
    final minutes = _totalDuration ~/ 60;
    final seconds = _totalDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _readableDuration {
    final minutes = _totalDuration ~/ 60;
    final seconds = _totalDuration % 60;
    if (minutes > 0 && seconds > 0) {
      return '$minutes 分 $seconds 秒';
    } else if (minutes > 0) {
      return '$minutes 分钟';
    } else {
      return '$seconds 秒';
    }
  }

  void _addSegment(String type) {
    setState(() {
      _segments.add(_SegmentItem(
        type: type,
        durationSec: type == 'exercise' ? 120 : 60,
      ));
    });
    _scrollToBottom();
  }

  void _removeSegment(int index) {
    setState(() {
      _segments.removeAt(index);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _moveSegmentUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _segments.removeAt(index);
      _segments.insert(index - 1, item);
    });
  }

  void _moveSegmentDown(int index) {
    if (index >= _segments.length - 1) return;
    setState(() {
      final item = _segments.removeAt(index);
      _segments.insert(index + 1, item);
    });
  }

  Future<void> _startTraining() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入训练名称')),
      );
      return;
    }

    if (_segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个训练段')),
      );
      return;
    }

    final rounds = int.tryParse(_roundsController.text) ?? 1;
    final segments = _segments.asMap().entries.map((entry) {
      return entry.value.toSegment(sortOrder: entry.key);
    }).toList();

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntervalTrainingScreen(
          trainingName: name,
          segments: segments,
          rounds: rounds,
        ),
      ),
    );

    // 训练完成后，把结果返回给上一级页面
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('间歇训练配置'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 训练名称和轮数
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '训练名称',
                    hintText: '例如：HIIT 间歇训练',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('重复轮数: ', style: TextStyle(fontSize: 16)),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _roundsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '轮',
                      style: TextStyle(fontSize: 16, color: AppColors.subtitle),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 段列表
          Expanded(
            child: _segments.isEmpty
                ? const EmptyState(
                    icon: Icons.timer_outlined,
                    message: '点击下方按钮添加训练段',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _segments.length,
                    itemBuilder: (context, index) => _buildSegmentCard(index),
                  ),
          ),

          // 预计总时长
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, size: 20),
                const SizedBox(width: 8),
                Text(
                  '预计总时长: $_readableDuration',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // 底部按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addSegment('exercise'),
                      icon: const Icon(Icons.directions_run),
                      label: const Text('添加运动'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addSegment('rest'),
                      icon: const Icon(Icons.hotel),
                      label: const Text('添加休息'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _startTraining,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('开始训练'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(int index) {
    final segment = _segments[index];
    final isExercise = segment.type == 'exercise';
    final isFirst = index == 0;
    final isLast = index == _segments.length - 1;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 序号和类型图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isExercise ? AppColors.exerciseSegment : AppColors.restSegment,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(
                  isExercise ? Icons.directions_run : Icons.hotel,
                  color: AppColors.onColoredBadge,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 段信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    segment.formattedDuration,
                    style: TextStyle(fontSize: 14, color: AppColors.subtitle),
                  ),
                ],
              ),
            ),

            // 时长输入
            SizedBox(
              width: 80,
              child: TextField(
                controller: segment.durationController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '秒',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                onChanged: (v) {
                  final seconds = int.tryParse(v) ?? 0;
                  setState(() {
                    segment.durationSec = seconds;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),

            // 操作按钮
            Column(
              children: [
                MoveArrows(
                  isFirst: isFirst,
                  isLast: isLast,
                  onMoveUp: () => _moveSegmentUp(index),
                  onMoveDown: () => _moveSegmentDown(index),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: DeleteButton(
                    onPressed: () => _removeSegment(index),
                    tooltip: '删除',
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentItem {
  final TextEditingController nameController;
  final TextEditingController durationController;
  String type; // 'exercise' or 'rest'
  int durationSec;

  _SegmentItem({
    String? name,
    required this.type,
    required this.durationSec,
  })  : nameController = TextEditingController(text: name ?? ''),
        durationController = TextEditingController(text: durationSec.toString());

  factory _SegmentItem.fromSegment(IntervalSegment segment) {
    return _SegmentItem(
      name: segment.name,
      type: segment.type,
      durationSec: segment.durationSec,
    );
  }

  IntervalSegment toSegment({int sortOrder = 0, int? trainingId}) {
    return IntervalSegment(
      sortOrder: sortOrder,
      type: type,
      durationSec: durationSec,
      name: nameController.text.isNotEmpty ? nameController.text : null,
      trainingId: trainingId,
    );
  }

  String get formattedDuration {
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get displayName {
    if (nameController.text.isNotEmpty) return nameController.text;
    return type == 'exercise' ? '运动' : '休息';
  }

  void dispose() {
    nameController.dispose();
    durationController.dispose();
  }
}
