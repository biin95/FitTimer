import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/kegel_record.dart';
import 'kegel_training_screen.dart';

class KegelScreen extends StatefulWidget {
  const KegelScreen({super.key});

  @override
  State<KegelScreen> createState() => _KegelScreenState();
}

class _KegelScreenState extends State<KegelScreen> {
  final DatabaseService _db = DatabaseService();

  // Config
  int _tightenSeconds = 5;
  int _relaxSeconds = 10;
  int _rounds = 3;

  // Stats
  int _todayCount = 0;
  int _weekCount = 0;

  // History
  List<KegelRecord> _records = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadData();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tightenSeconds = prefs.getInt('kegel_tighten_sec') ?? 5;
      _relaxSeconds = prefs.getInt('kegel_relax_sec') ?? 10;
      _rounds = prefs.getInt('kegel_rounds') ?? 3;
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('kegel_tighten_sec', _tightenSeconds);
    await prefs.setInt('kegel_relax_sec', _relaxSeconds);
    await prefs.setInt('kegel_rounds', _rounds);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final today = await _db.getKegelTodayCount();
      final week = await _db.getKegelWeekCount();

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59).millisecondsSinceEpoch;
      final records = await _db.getKegelRecordsByDateRange(startOfMonth, endOfMonth);

      if (mounted) {
        setState(() {
          _todayCount = today;
          _weekCount = week;
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startTraining() async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => KegelTrainingScreen(
          tightenSeconds: _tightenSeconds,
          relaxSeconds: _relaxSeconds,
          rounds: _rounds,
        ),
      ),
    );
    if (result != null) {
      _loadData();
    }
  }

  void _showConfigDialog() {
    int tSec = _tightenSeconds;
    int rSec = _relaxSeconds;
    int rds = _rounds;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('训练设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildConfigRow(ctx, setDialogState, '收紧 (秒)', tSec, (v) => tSec = v),
              const SizedBox(height: 12),
              _buildConfigRow(ctx, setDialogState, '放松 (秒)', rSec, (v) => rSec = v),
              const SizedBox(height: 12),
              _buildConfigRow(ctx, setDialogState, '轮数', rds, (v) => rds = v),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _tightenSeconds = tSec;
                  _relaxSeconds = rSec;
                  _rounds = rds;
                });
                _saveConfig();
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(BuildContext ctx, void Function(void Function()) setDS,
      String label, int value, void Function(int) onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1
              ? () => setDS(() {
                    onChanged(value - 1);
                    value = value - 1;
                  })
              : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => setDS(() {
                onChanged(value + 1);
                value = value + 1;
              }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('凯格尔训练'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showConfigDialog,
            tooltip: '训练设置',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('今日', '$_todayCount 组', Icons.today, Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard('本周', '$_weekCount 组', Icons.date_range, Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Config preview
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildConfigItem('收紧', '$_tightenSeconds 秒'),
                              Container(height: 30, width: 1, color: Colors.grey.shade300),
                              _buildConfigItem('放松', '$_relaxSeconds 秒'),
                              Container(height: 30, width: 1, color: Colors.grey.shade300),
                              _buildConfigItem('轮数', '$_rounds 轮'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _startTraining,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('开始训练', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // History
                  Text('训练记录', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_records.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('暂无记录', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    )
                  else
                    ..._records.map((r) => _buildHistoryItem(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHistoryItem(KegelRecord record) {
    final dt = DateTime.fromMillisecondsSinceEpoch(record.date);
    final dateStr = '${dt.month}/${dt.day}';
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除 $dateStr 的凯格尔训练记录吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('删除')),
            ],
          ),
        );
        if (confirmed == true && record.id != null) {
          await _db.deleteKegelRecord(record.id!);
          _loadData();
        }
        return false; // Always false, we handle removal via _loadData
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.fitness_center, color: Colors.teal),
          title: Text('$dateStr  ${record.completedSets}/${record.totalSets} 组'),
          trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ),
      ),
    );
  }
}
