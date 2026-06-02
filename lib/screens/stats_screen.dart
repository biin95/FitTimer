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

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;

  _Period _period = _Period.week;
  DateTime? _customStart;
  DateTime? _customEnd;

  bool _loading = true;

  // Computed stats
  int _trainingCount = 0;
  int _totalExercises = 0;
  int _totalSets = 0;
  double _totalVolume = 0; // kg·次
  int _weekCompletedCount = 0;
  int _monthCompletedCount = 0;

  // PR records: exerciseName → { bestWeight, bestVolume }
  Map<String, _PRRecord> _prRecords = {};

  // Weekly frequency: list of (weekLabel, count)
  List<_WeekCount> _weeklyCounts = [];

  // Monthly frequency: list of (monthLabel, count)
  List<_MonthCount> _monthlyCounts = [];

  // Custom range frequency: list of (dateLabel, count)
  List<_DayCount> _customDayCounts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final newPeriod = _Period.values[_tabController.index];
    if (newPeriod != _period) {
      setState(() => _period = newPeriod);
      if (newPeriod != _Period.custom) {
        _loadStats();
      } else if (_customStart != null && _customEnd != null) {
        _loadStats();
      }
    }
  }

  DateTimeRange get _currentRange {
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        // Monday of this week
        final weekday = now.weekday; // 1=Mon, 7=Sun
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday - 1));
        return DateTimeRange(start: start, end: now);
      case _Period.month:
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: now);
      case _Period.custom:
        return DateTimeRange(
          start: _customStart ?? now.subtract(const Duration(days: 7)),
          end: _customEnd ?? now,
        );
    }
  }

  Future<void> _loadStats() async {
    // 自定义模式下未选择日期范围时不加载数据
    if (_period == _Period.custom && (_customStart == null || _customEnd == null)) {
      setState(() {
        _loading = false;
        _trainingCount = 0;
        _totalExercises = 0;
        _totalSets = 0;
        _totalVolume = 0;
        _prRecords = {};
        _customDayCounts = [];
      });
      return;
    }

    setState(() => _loading = true);

    final range = _currentRange;
    final startMs = range.start.millisecondsSinceEpoch;
    // Include full end day
    final endMs = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59)
        .millisecondsSinceEpoch;

    final workouts = await _db.getWorkoutRecordsByDateRange(startMs, endMs);

    int totalSets = 0;
    double totalVolume = 0;
    final Set<String> exerciseNames = {};
    final Map<String, double> bestWeightMap = {};
    final Map<String, double> bestVolumeMap = {};

    // Collect exercise records per workout
    for (final w in workouts) {
      final exercises = await _db.getExerciseRecordsForWorkout(w.id!);
      for (final e in exercises) {
        // 只统计已完成的组
        if (!e.isCompleted) continue;
        totalSets++;
        exerciseNames.add(e.exerciseName);

        final weight = e.actualWeight ?? 0;
        final reps = e.actualReps ?? 0;
        final volume = weight * reps;
        totalVolume += volume;

        // PR tracking (strength only - check exerciseType field)
        if (e.exerciseType != 'cardio' && e.exerciseType != 'Cardio') {
          if (weight > (bestWeightMap[e.exerciseName] ?? 0)) {
            bestWeightMap[e.exerciseName] = weight;
          }
          if (volume > (bestVolumeMap[e.exerciseName] ?? 0)) {
            bestVolumeMap[e.exerciseName] = volume;
          }
        }
      }
    }

    // Build PR records (exclude cardio - only exercises with weight > 0)
    final prRecords = <String, _PRRecord>{};
    for (final name in exerciseNames) {
      final bw = bestWeightMap[name] ?? 0;
      final bv = bestVolumeMap[name] ?? 0;
      if (bw > 0 || bv > 0) {
        prRecords[name] = _PRRecord(
          bestWeight: bw,
          bestVolume: bv,
        );
      }
    }

    // Weekly frequency
    final weeklyCounts = _computeWeeklyCounts(workouts, range.start, range.end);

    // Completed workout counts for current week and month
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStartMs = weekStart.millisecondsSinceEpoch;
    final monthStartMs = monthStart.millisecondsSinceEpoch;
    final todayEndMs = DateTime(now.year, now.month, now.day, 23, 59, 59)
        .millisecondsSinceEpoch;

    // Monthly frequency (last 6 months) - 独立查询，不受当前选择范围限制
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1).millisecondsSinceEpoch;
    final allWorkoutsForChart = await _db.getWorkoutRecordsByDateRange(sixMonthsAgo, todayEndMs);
    final monthlyCounts = _computeMonthlyCounts(allWorkoutsForChart);

    // Custom range frequency - 按天统计选中范围内的训练频率
    final customDayCounts = _period == _Period.custom
        ? _computeCustomDayCounts(workouts, range.start, range.end)
        : <_DayCount>[];

    final allWorkouts = await _db.getWorkoutRecordsByDateRange(
        monthStartMs > weekStartMs ? weekStartMs : monthStartMs, todayEndMs);

    int weekCompleted = 0;
    int monthCompleted = 0;
    for (final w in allWorkouts) {
      if (w.isCompleted) {
        if (w.date >= weekStartMs) weekCompleted++;
        if (w.date >= monthStartMs) monthCompleted++;
      }
    }

    setState(() {
      _trainingCount = workouts.length;
      _totalExercises = exerciseNames.length;
      _totalSets = totalSets;
      _totalVolume = totalVolume;
      _prRecords = prRecords;
      _weeklyCounts = weeklyCounts;
      _monthlyCounts = monthlyCounts;
      _customDayCounts = customDayCounts;
      _weekCompletedCount = weekCompleted;
      _monthCompletedCount = monthCompleted;
      _loading = false;
    });
  }

  List<_WeekCount> _computeWeeklyCounts(
      List<WorkoutRecord> workouts, DateTime start, DateTime end) {
    // Group workouts by ISO week
    final Map<String, int> weekMap = {};
    // Initialize all weeks in range
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final weekStart = cursor.subtract(Duration(days: cursor.weekday - 1));
      final key = DateFormat('MM/dd').format(weekStart);
      weekMap.putIfAbsent(key, () => 0);
      cursor = cursor.add(const Duration(days: 1));
    }

    for (final w in workouts) {
      final date = DateTime.fromMillisecondsSinceEpoch(w.date);
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final key = DateFormat('MM/dd').format(weekStart);
      weekMap[key] = (weekMap[key] ?? 0) + 1;
    }

    final sorted = weekMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => _WeekCount(e.key, e.value)).toList();
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
      _loadStats();
    }
  }

  void _onPeriodChanged(_Period? p) {
    if (p == null) return;
    setState(() => _period = p);
    _tabController.index = p.index;
    if (p != _Period.custom) {
      _loadStats();
    } else if (_customStart != null && _customEnd != null) {
      _loadStats();
    }
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
          onTap: (index) => _onPeriodChanged(_Period.values[index]),
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
      onRefresh: _loadStats,
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
      onRefresh: _loadStats,
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
      onRefresh: _loadStats,
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
                _statTile('训练次数', '$_trainingCount', '次', theme),
                _statTile('动作数', '$_totalExercises', '个', theme),
                _statTile('总组数', '$_totalSets', '组', theme),
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

  // ──────────────────── Weekly Chart ────────────────────

  Widget _buildWeeklyChart(ThemeData theme) {
    if (_weeklyCounts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('暂无训练数据', style: theme.textTheme.bodyLarge),
        ),
      );
    }

    final maxCount =
        _weeklyCounts.fold<int>(0, (m, w) => w.count > m ? w.count : m);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('每周训练频率', style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _weeklyCounts.map((wc) {
                  final ratio = maxCount > 0 ? wc.count / maxCount : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${wc.count}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: ratio * 100,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            wc.label,
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

  // ──────────────────── Custom Day Chart ────────────────────

  Widget _buildCustomDayChart(ThemeData theme) {
    if (_customDayCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxCount =
        _customDayCounts.fold<int>(0, (m, d) => d.count > m ? d.count : m);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('训练频率', style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _customDayCounts.map((dc) {
                  final ratio = maxCount > 0 ? dc.count / maxCount : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (dc.count > 0)
                            Text(
                              '${dc.count}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: ratio * 100,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dc.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 8,
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
    if (_prRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('暂无PR记录', style: theme.textTheme.bodyLarge),
        ),
      );
    }

    final sortedNames = _prRecords.keys.toList()..sort();

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
              final pr = _prRecords[name]!;
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

class _WeekCount {
  final String label;
  final int count;
  const _WeekCount(this.label, this.count);
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
