import 'package:flutter/material.dart';
import '../models/workout_template.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import 'template_edit_screen.dart';

class TemplateScreen extends StatefulWidget {
  const TemplateScreen({super.key});

  @override
  State<TemplateScreen> createState() => _TemplateScreenState();
}

/// 模板额外数据（练习数量、是否有有氧）
class _TemplateExtraData {
  final int exerciseCount;
  final bool hasCardio;

  const _TemplateExtraData({
    required this.exerciseCount,
    required this.hasCardio,
  });
}

class _TemplateScreenState extends State<TemplateScreen> {
  final DatabaseService _db = DatabaseService();
  List<WorkoutTemplate> _templates = [];
  Map<int, _TemplateExtraData> _templateData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final templates = await _db.getTemplates();
      final templateData = <int, _TemplateExtraData>{};

      // 一次性加载所有模板的练习信息
      for (final t in templates) {
        if (t.id != null) {
          final exercises = await _db.getTemplateExercises(t.id!);
          templateData[t.id!] = _TemplateExtraData(
            exerciseCount: exercises.length,
            hasCardio: exercises.any((e) => e.exerciseType == 'cardio'),
          );
        }
      }

      setState(() {
        _templates = templates;
        _templateData = templateData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading templates: $e');
    }
  }

  Future<void> _deleteTemplate(WorkoutTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除模板「${template.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && template.id != null) {
      await _db.deleteTemplate(template.id!);
      _loadTemplates();
    }
  }

  Future<void> _navigateToCreate() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
    );
    if (result == true) {
      _loadTemplates();
    }
  }

  Future<void> _navigateToEdit(WorkoutTemplate template) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TemplateEditScreen(template: template),
      ),
    );
    if (result == true) {
      _loadTemplates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练模板'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _buildEmptyState()
              : _buildTemplateList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.fitness_center,
      message: '还没有训练模板，点击下方按钮创建',
      iconSize: 80,
    );
  }

  Widget _buildTemplateList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final template = _templates[index];
        final extraData = template.id != null ? _templateData[template.id!] : null;
        return _TemplateCard(
          template: template,
          exerciseCount: extraData?.exerciseCount ?? 0,
          hasCardio: extraData?.hasCardio ?? false,
          onTap: () => _navigateToEdit(template),
          onDelete: () => _deleteTemplate(template),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final int exerciseCount;
  final bool hasCardio;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.exerciseCount,
    required this.hasCardio,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(template.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle the actual deletion in the callback
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: AppColors.onColoredBadge),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasCardio ? Icons.directions_run : Icons.fitness_center,
              color: hasCardio ? AppColors.warning : Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            template.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$exerciseCount 个动作 · 创建于 ${_formatDate(template.createdAt)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 13,
              ),
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
