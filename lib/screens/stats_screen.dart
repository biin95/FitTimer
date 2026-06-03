import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/workout_record.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

enum _Period { week, month, custom }

class _StatsData {
  final int trainingCount;
  final int totalExercises;
  final int totalSets;
  final Map<String, _PRRecord> prRecords;
  final List<_DayCount> dayCounts;
  const _StatsData({
    required this.trainingCount,
    required this.totalExercises,
    required this.totalSets,
    required this.prRecords,
    required this.dayCounts,
  });
  static const empty = _StatsData(
    trainingCount: 0, totalExercises: 0, totalSets: 0,
    prRecords: {}, dayCounts: [],
  );
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;

  _Period _period = _Period.week;
  DateTime? _customStart;
  DateTime? _customEnd;

  bool _loading = true;

  // Per-tab cached data — switching tabs is instant
  _StatsData _weekData = _StatsData.empty;
  _StatsData _monthData = _StatsData.empty;
  _StatsData _customData = _StatsData.empty;

  // Always up-to-date completion counts
  int _weekCompletedCount = 0;
  int _monthCompletedCount = 0;

  // Monthly chart data (last 6 months, independent of tab)
  List<_MonthCount> _monthlyCounts = [];

  _StatsData get _displayData {
    switch (_period) {
      case _Period.week: return _weekData;
      case _Period.month: return _monthData;
      case _Period.custom: return _customData;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.animation!.addListener(_onTabAnimationChanged);
    _loadInitialStats();
  }

  @override
  void dispose() {
    _tabController.animation!.removeListener(_onTabAnimationChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabAnimationChanged() {
    final value = _tabController.animation!.value;
    if (value != value.roundToDouble()) return;
    final index = value.round();
    final newPeriod = _Period.values[index];
    if (newPeriod == _period) return;
    setState(() => _period = newPeriod);
  }


  // ── Data loading ──

  Future<void> _loadInitialStats() async {
    try {
      final now = DateTime.now();
      final weekStartMs = _weekRange.start.millisecondsSinceEpoch;
      final monthStartMs = _monthRange.start.millisecondsSinceEpoch;
      final todayEndMs = DateTime(now.year, now.month, now.day, 23, 59, 59)
          .millisecondsSinceEpoch;

      final sixMonthsAgo = DateTime(now.year, now.month - 5, 1).millisecondsSinceEpoch;

      // 并行查询：周范围 + 月范围 + 6个月趋势 + 完成计数
      final results = await Future.wait([
        _db.getWorkoutRecordsByDateRange(weekStartMs, todayEndMs),
        _db.getWorkoutRecordsByDateRange(monthStartMs, todayEndMs),
        _db.getWorkoutRecordsByDateRange(sixMonthsAgo, todayEndMs),
        _db.getWorkoutRecordsByDateRange(
            monthStartMs > weekStartMs ? weekStartMs : monthStartMs, todayEndMs),
      ]);

      // 并行构建周和月的统计数据
      final weekData = await _buildStatsData(results[0], _weekRange, isCustom: false);
      final monthData = await _buildStatsData(results[1], _monthRange, isCustom: false);

      if (!mounted) return;
      setState(() {
        _weekData = weekData;
        _monthData = monthData;
        _monthlyCounts = _computeMonthlyCounts(results[2]);
        _updateCompletionCounts(results[3]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('加载统计数据失败: $e');
    }
  }

  Future<void> _loadCustomStats() async {
    if (_customStart == null || _customEnd == null) {
      setState(() => _customData = _StatsData.empty);
      return;
    }
    try {
      final range = _customRange;
      final startMs = range.start.millisecondsSinceEpoch;
      final endMs = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59)
          .millisecondsSinceEpoch;
      final workouts = await _db.getWorkoutRecordsByDateRange(startMs, endMs);
      final data = await _buildStatsData(workouts, range, isCustom: true);
      if (!mounted) return;
      setState(() => _customData = data);
    } catch (e) {
      debugPrint('加载自定义统计数据失败: $e');
    }
  }

  // ── Helpers ──

  DateTimeRange get _weekRange {
    final now = DateTime.now();
    final weekday = now.weekday;
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));
    return DateTimeRange(start: start, end: now);
  }

  DateTimeRange get _monthRange {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  DateTimeRange get _customRange {
    final now = DateTime.now();
    return DateTimeRange(
      start: _customStart ?? now.subtract(const Duration(days: 7)),
      end: _customEnd ?? now,
    );
  }

  Future<_StatsData> _buildStatsData(List<WorkoutRecord> workouts, DateTimeRange range,
      {required bool isCustom}) async {
    int totalSets = 0;
    final Set<String> exerciseNames = {};
    final Map<String, double> bestWeightMap = {};
    final Map<String, double> bestVolumeMap = {};

    for (final w in workouts) {
      final exercises = await _db.getExerciseRecordsForWorkout(w.id!);
      for (final e in exercises) {
        if (!e.isCompleted) continue;
        totalSets++;
        exerciseNames.add(e.exerciseName);
        final weight = e.actualWeight ?? 0;
        final reps = e.actualReps ?? 0;
        final volume = weight * reps;
        if (e.exerciseType != 'cardio' && e.exerciseType != 'Cardio') {
          if (weight > (bestWeightMap[e.exerciseName] ?? 0)) bestWeightMap[e.exerciseName] = weight;
          if (volume > (bestVolumeMap[e.exerciseName] ?? 0)) bestVolumeMap[e.exerciseName] = volume;
        }
      }
    }

    final prRecords = <String, _PRRecord>{};
    for (final name in exerciseNames) {
      final bw = bestWeightMap[name] ?? 0;
      final bv = bestVolumeMap[name] ?? 0;
      if (bw > 0 || bv > 0) prRecords[name] = _PRRecord(bestWeight: bw, bestVolume: bv);
    }

    final dayCounts = isCustom
        ? _computeCustomDayCounts(workouts, range.start, range.end)
        : <_DayCount>[];

    return _StatsData(
      trainingCount: workouts.length,
      totalExercises: exerciseNames.length,
      totalSets: totalSets,
      prRecords: prRecords,
      dayCounts: dayCounts,
    );
  }

  void _updateCompletionCounts(List<WorkoutRecord> allWorkouts) {
    final now = DateTime.now();
    final weekStartMs = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)).millisecondsSinceEpoch;
    final monthStartMs = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    int weekCompleted = 0;
    int monthCompleted = 0;
    for (final w in allWorkouts) {
      if (w.isCompleted) {
        if (w.date >= weekStartMs) weekCompleted++;
        if (w.date >= monthStartMs) monthCompleted++;
      }
    }
    _weekCompletedCount = weekCompleted;
    _monthCompletedCount = monthCompleted;
  }

  List<_MonthCount> _computeMonthlyCounts(List<WorkoutRecord> workouts) {
    // Group workouts by month (last 6 months)
    final now = DateTime.now();
    final Map<String, int> monthMap = {};
    // Initialize last 6 months
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('yyyy-MM').format(m);
      monthMap[key] = 0;
    }
    for (final w in workouts) {
      final date = DateTime.fromMillisecondsSinceEpoch(w.date);
      final key = DateFormat('yyyy-MM').format(date);
      if (monthMap.containsKey(key)) {
        monthMap[key] = (monthMap[key] ?? 0) + 1;
      }
    }
    final sorted = monthMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => _MonthCount(
      DateFormat('M月').format(DateFormat('yyyy-MM').parse(e.key)),
      e.value,
    )).toList();
  }

  List<_DayCount> _computeCustomDayCounts(
      List<WorkoutRecord> workouts, DateTime start, DateTime end) {
    final daysInRange = end.difference(start).inDays + 1;

    if (daysInRange <= 31) {
      // 31天以内：按天统计
      final Map<String, int> dayMap = {};
      var cursor = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!cursor.isAfter(endDay)) {
        final key = DateFormat('MM/dd').format(cursor);
        dayMap[key] = 0;
        cursor = cursor.add(const Duration(days: 1));
      }

      for (final w in workouts) {
        final date = DateTime.fromMillisecondsSinceEpoch(w.date);
        final key = DateFormat('MM/dd').format(date);
        if (dayMap.containsKey(key)) {
          dayMap[key] = (dayMap[key] ?? 0) + 1;
        }
      }

      final sorted = dayMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return sorted.map((e) => _DayCount(e.key, e.value)).toList();
    } else {
      // 超过31天：按周统计
      final Map<String, int> weekMap = {};
      var cursor = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!cursor.isAfter(endDay)) {
        // 每周的起始（周一）
        final weekStart = cursor.subtract(Duration(days: cursor.weekday - 1));
        final key = DateFormat('MM/dd').format(weekStart);
        weekMap.putIfAbsent(key, () => 0);
        cursor = cursor.add(const Duration(days: 7));
      }

      for (final w in workouts) {
        final date = DateTime.fromMillisecondsSinceEpoch(w.date);
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final key = DateFormat('MM/dd').format(weekStart);
        if (weekMap.containsKey(key)) {
          weekMap[key] = (weekMap[key] ?? 0) + 1;
        }
      }

      final sorted = weekMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return sorted.map((e) => _DayCount('${e.key}周', e.value)).toList();
    }
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_customStart ?? now.subtract(const Duration(days: 30)))
        : (_customEnd ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStart = picked;
        } else {
          _customEnd = picked;
        }
      });
      _loadCustomStats();
    }
  }

  Future<void> _refreshAll() async {
    await _loadInitialStats();
    if (_customStart != null && _customEnd != null) await _loadCustomStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('训练统计'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '本周'),
            Tab(text: '本月'),
            Tab(text: '自定义'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeekView(theme),
                _buildMonthView(theme),
                _buildCustomView(theme),
              ],
            ),
    );
  }

  // ──────────────────── Week View ────────────────────

  Widget _buildWeekView(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(theme),
          const SizedBox(height: 20),
          _buildPRSection(theme),
        ],
      ),
    );
  }

  // ──────────────────── Month View ────────────────────

  Widget _buildMonthView(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(theme),
          const SizedBox(height: 20),
          _buildMonthlyChart(theme),
          const SizedBox(height: 20),
          _buildPRSection(theme),
        ],
      ),
    );
  }

  // ──────────────────── Custom View ────────────────────

  Widget _buildCustomView(ThemeData theme) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final hasRange = _customStart != null && _customEnd != null;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCustomDatePickers(dateFormat, theme),
          const SizedBox(height: 20),
          if (!hasRange) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Center(
                  child: Text(
                    '请选择日期范围',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[500]),
                  ),
                ),
              ),
            ),
          ] else ...[
            _buildSummaryCard(theme),
            const SizedBox(height: 20),
            _buildPRSection(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomDatePickers(DateFormat fmt, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择日期范围', style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _customStart != null ? fmt.format(_customStart!) : '开始日期',
                    ),
                    onPressed: () => _pickCustomDate(isStart: true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('—'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _customEnd != null ? fmt.format(_customEnd!) : '结束日期',
                    ),
                    onPressed: () => _pickCustomDate(isStart: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Summary Card ────────────────────

  Widget _buildSummaryCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('训练概览', style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            Row(
              children: [
                _statTile('训练次数', '${_displayData.trainingCount}', '次', theme),
                _statTile('动作数', '${_displayData.totalExercises}', '个', theme),
                _statTile('总组数', '${_displayData.totalSets}', '组', theme),
              ],
            ),
            const SizedBox(height: 12),
            if (_period != _Period.custom) ...[
              Row(
                children: [
                  _statTile('本周训练', '$_weekCompletedCount', '次', theme),
                  _statTile('本月训练', '$_monthCompletedCount', '次', theme),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, String unit, ThemeData theme) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$label ($unit)',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ──────────────────── Monthly Chart ────────────────────

  Widget _buildMonthlyChart(ThemeData theme) {
    if (_monthlyCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxCount =
        _monthlyCounts.fold<int>(0, (m, w) => w.count > m ? w.count : m);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('每月训练频率', style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _monthlyCounts.map((mc) {
                  final ratio = maxCount > 0 ? mc.count / maxCount : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${mc.count}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: ratio * 100,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mc.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── PR Section ────────────────────

  Widget _buildPRSection(ThemeData theme) {
    if (_displayData.prRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('暂无PR记录', style: theme.textTheme.bodyLarge),
        ),
      );
    }

    final sortedNames = _displayData.prRecords.keys.toList()..sort();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('个人记录 (PR)', style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 12),
            ...sortedNames.map((name) {
              final pr = _displayData.prRecords[name]!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${pr.bestWeight.toStringAsFixed(1)} kg',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '最大重量',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Helper classes ──

class _PRRecord {
  final double bestWeight;
  final double bestVolume;
  const _PRRecord({required this.bestWeight, required this.bestVolume});
}

class _MonthCount {
  final String label;
  final int count;
  const _MonthCount(this.label, this.count);
}

class _DayCount {
  final String label;
  final int count;
  const _DayCount(this.label, this.count);
}
