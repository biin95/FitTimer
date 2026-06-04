import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart' show currentQuote;
import '../services/database_service.dart';
import '../services/weather_service.dart';
import 'workout_session_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;
  const HomeScreen({super.key, this.onDataChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _currentMonth;
  late DatabaseService _databaseService;
  Map<DateTime, List<String>> _workoutTypes = {};
  Set<DateTime> _completedDates = {};
  bool _isLoading = true;
  WeatherData? _weatherData;
  bool _weatherLoading = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _databaseService = DatabaseService();
    _loadWorkouts();
    _loadWeather();
  }

  Future<void> _loadWorkouts() async {
    setState(() => _isLoading = true);

    try {
      final startMs = DateTime(_currentMonth.year, _currentMonth.month, 1).millisecondsSinceEpoch;
      final endMs = DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59).millisecondsSinceEpoch;

      final records = await _databaseService.getWorkoutRecordsByDateRange(startMs, endMs);

      final workoutTypes = <DateTime, List<String>>{};
      final completedDates = <DateTime>{};

      for (final record in records) {
        final date = DateTime.fromMillisecondsSinceEpoch(record.date);
        final dateKey = DateTime(date.year, date.month, date.day);

        if (!workoutTypes.containsKey(dateKey)) {
          workoutTypes[dateKey] = [];
        }
        workoutTypes[dateKey]!.add(record.sportType);

        if (record.isCompleted) {
          completedDates.add(dateKey);
        }
      }

      setState(() {
        _workoutTypes = workoutTypes;
        _completedDates = completedDates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading workouts: $e');
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadWorkouts();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadWorkouts();
  }

  void _navigateToDay(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(date: date),
      ),
    ).then((_) {
      // Refresh calendar after returning from workout session
      _loadWorkouts();
      // 通知统计页面刷新数据
      widget.onDataChanged?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitTimer'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Motivational Quote
                  _buildQuoteCard(),

                  // Calendar
                  _buildCalendar(),

                  // Weather
                  _buildWeatherCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildQuoteCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              currentQuote.text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            if (currentQuote.translation != null) ...[
              const SizedBox(height: 8),
              Text(
                currentQuote.translation!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;

    // 计算实际需要的行数（大部分月份 5 行就够了）
    final totalCells = (firstDayWeekday - 1 + daysInMonth + 6) ~/ 7 * 7;
    final rows = totalCells ~/ 7;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMonthNavigation(),
            const SizedBox(height: 16),
            _buildWeekdayHeaders(),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                final cellDay = index - firstDayWeekday + 2;

                if (cellDay < 1 || cellDay > daysInMonth) {
                  return const SizedBox();
                }

                final date = DateTime(
                  _currentMonth.year,
                  _currentMonth.month,
                  cellDay,
                );

                final isToday = _isToday(date);
                final types = _workoutTypes[date] ?? [];

                return _buildDayCell(date, isToday, types);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
        ),
        Text(
          DateFormat('yyyy年 M月').format(_currentMonth),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) => Text(
        day,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      )).toList(),
    );
  }

  Widget _buildDayCell(DateTime date, bool isToday, List<String> types) {
    String icons = '';
    for (final type in types) {
      switch (type) {
        case 'strength':
          icons += '🏋️';
          break;
        case 'cardio':
          icons += '🏃';
          break;
        case 'interval':
          icons += '⏱️';
          break;
        case 'mixed':
          icons += '🏋️🏃';
          break;
      }
    }

    final isCompleted = _completedDates.contains(date);

    return GestureDetector(
      onTap: () => _navigateToDay(date),
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : null,
          borderRadius: BorderRadius.circular(4),
          border: isToday
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            if (types.isNotEmpty || isCompleted)
              Text(
                '$icons${isCompleted ? '✅' : ''}',
                style: const TextStyle(fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    setState(() => _weatherLoading = true);

    final weather = await WeatherService().fetchWeather(forceRefresh: forceRefresh);

    if (mounted) {
      setState(() {
        _weatherData = weather;
        _weatherLoading = false;
      });
    }
  }

  Widget _buildWeatherCard() {
    if (_weatherLoading) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('加载天气...', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_weatherData == null || _weatherData!.temp.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, size: 28, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _weatherData?.desc.isEmpty ?? true ? '天气数据加载失败' : _weatherData!.desc,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final weather = _weatherData!;

    return GestureDetector(
      onTap: () => _loadWeather(forceRefresh: true),
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(weather.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: desc + temp | tip
                    Row(
                      children: [
                        Expanded(
                          child: Text('${weather.desc}  ${weather.temp}°C',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        if (weather.tip.isNotEmpty)
                          Text(
                            weather.tip,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Row 2: city + feelsLike | humidity + wind
                    Row(
                      children: [
                        Expanded(
                          child: Text('${weather.city}  体感${weather.feelsLike}°C',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                        if (weather.humidity.isNotEmpty || weather.windSpeed.isNotEmpty)
                          Text('湿度${weather.humidity}%  风速${weather.windSpeed}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
