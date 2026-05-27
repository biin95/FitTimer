import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show currentQuote;
import '../services/database_service.dart';
import '../services/log_service.dart';
import 'workout_session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _currentMonth;
  late DatabaseService _databaseService;
  Map<DateTime, List<String>> _workoutTypes = {};
  Set<DateTime> _completedDates = {};
  bool _isLoading = true;
  String _weatherDesc = '';
  String _weatherTemp = '';
  String _weatherHumidity = '';
  String _weatherCity = '';
  String _weatherIcon = '';
  String _weatherFeelsLike = '';
  String _weatherWindSpeed = '';
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

    // Grid needs 6 rows (max possible) with 7 columns
    const totalCells = 42;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Month Navigation
            _buildMonthNavigation(),

            const SizedBox(height: 16),

            // Weekday Headers
            _buildWeekdayHeaders(),

            const SizedBox(height: 8),

            // Calendar Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
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
            if (types.isNotEmpty)
              Text(
                icons,
                style: const TextStyle(fontSize: 10),
              ),
            // Completed training indicator (green checkmark)
            if (isCompleted)
              const Text(
                '✅',
                style: TextStyle(fontSize: 10),
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

  Future<void> _loadWeather() async {
    log.log('WEATHER', '=== 开始加载天气 ===');
    try {
      const apiKey = '642e66acb9ca46c58e6372aef43eb5de';
      final prefs = await SharedPreferences.getInstance();
      log.log('WEATHER', 'API Key: ${apiKey.substring(0,8)}...');

      // Check if weather was already loaded today
      final lastWeatherDate = prefs.getString('weather_last_date');
      final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      if (lastWeatherDate == today) {
        // Load from cache, skip network
        final cached = prefs.getString('weather_cache');
        if (cached != null) {
          final data = jsonDecode(cached);
          setState(() {
            _weatherDesc = data['desc'] ?? '';
            _weatherTemp = data['temp'] ?? '';
            _weatherHumidity = data['humidity'] ?? '';
            _weatherCity = data['city'] ?? '';
            _weatherIcon = data['icon'] ?? '';
            _weatherFeelsLike = data['feelsLike'] ?? '';
            _weatherWindSpeed = data['windSpeed'] ?? '';
            _weatherLoading = false;
          });
          log.log('WEATHER', '今天已加载过，从缓存读取');
          return;
        }
      }

      // Try to get location
      double lat = 31.23;
      double lon = 121.47;

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        log.log('WEATHER', '定位服务: $serviceEnabled');
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          log.log('WEATHER', '定位权限: $permission');
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            log.log('WEATHER', '请求权限后: $permission');
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            // Try getLastKnownPosition first (instant)
            try {
              final lastPos = await Geolocator.getLastKnownPosition();
              if (lastPos != null) {
                lat = lastPos.latitude;
                lon = lastPos.longitude;
                log.log('WEATHER', '用lastKnown位置: $lat, $lon');
              } else {
                Position position = await Geolocator.getCurrentPosition(
                  timeLimit: const Duration(seconds: 8),
                  desiredAccuracy: LocationAccuracy.medium,
                );
                lat = position.latitude;
                lon = position.longitude;
                log.log('WEATHER', '获取到位置: $lat, $lon');
              }
            } catch (e) {
              log.log('WEATHER', '定位失败, 用默认位置: $e');
            }
          }
        }
      } catch (e) {
        log.log('WEATHER', '定位异常: $e');
      }

      // Get location ID via GeoAPI
      const host = 'j554e6799f.re.qweatherapi.com';
      final geoUrl = 'https://$host/geo/v2/city/lookup?location=$lon,$lat&number=1';
      log.log('WEATHER', 'GeoAPI URL: $geoUrl');
      
      final client = http.Client();
      try {
        final geoResponse = await client.get(
          Uri.parse(geoUrl),
          headers: {
            'X-QW-Api-Key': apiKey,
            'Accept-Encoding': 'identity',
          },
        ).timeout(const Duration(seconds: 10));

        log.log('WEATHER', 'GeoAPI 状态码: ${geoResponse.statusCode}');
        log.log('WEATHER', 'GeoAPI 响应头: ${geoResponse.headers}');
        log.log('WEATHER', 'GeoAPI Body (前300字): ${geoResponse.body.substring(0, geoResponse.body.length.clamp(0, 300))}');

        String locationId = '';
        if (geoResponse.statusCode == 200) {
          final geoData = jsonDecode(geoResponse.body);
          log.log('WEATHER', 'GeoAPI code: ${geoData['code']}');
          if (geoData['code'] == '200' && geoData['location'] != null && (geoData['location'] as List).isNotEmpty) {
            locationId = geoData['location'][0]['id'];
            _weatherCity = geoData['location'][0]['name'] ?? '';
            log.log('WEATHER', '城市ID: $locationId, 城市名: $_weatherCity');
          } else {
            log.log('WEATHER', 'GeoAPI 返回异常: ${geoData['code']}');
          }
        }

        if (locationId.isEmpty) {
          log.log('WEATHER', '城市ID为空, 放弃');
          setState(() => _weatherLoading = false);
          return;
        }

        // Get current weather
        final weatherUrl = 'https://$host/v7/weather/now?location=$locationId';
        log.log('WEATHER', 'Weather URL: $weatherUrl');
        final weatherResponse = await client.get(
          Uri.parse(weatherUrl),
          headers: {
            'X-QW-Api-Key': apiKey,
            'Accept-Encoding': 'identity',
          },
        ).timeout(const Duration(seconds: 10));

        log.log('WEATHER', 'Weather 状态码: ${weatherResponse.statusCode}');
        log.log('WEATHER', 'Weather Body (前300字): ${weatherResponse.body.substring(0, weatherResponse.body.length.clamp(0, 300))}');

        if (weatherResponse.statusCode == 200) {
          final weatherData = jsonDecode(weatherResponse.body);
          log.log('WEATHER', 'Weather code: ${weatherData['code']}');
          if (weatherData['code'] == '200' && weatherData['now'] != null) {
            final now = weatherData['now'];
            setState(() {
              _weatherDesc = now['text'] ?? '';
              _weatherTemp = now['temp'] ?? '';
              _weatherHumidity = now['humidity'] ?? '';
              _weatherFeelsLike = now['feelsLike'] ?? '';
              _weatherWindSpeed = now['windSpeed'] ?? '';
              _weatherIcon = _getWeatherIcon(now['icon'] ?? '100');
              _weatherLoading = false;
            });
            log.log('WEATHER', '天气数据设置成功: $_weatherDesc $_weatherTemp°C');
          } else {
            log.log('WEATHER', 'Weather 返回异常: ${weatherData['code']}');
          }
        }

        // Cache weather data
        await prefs.setString('weather_cache', jsonEncode({
          'desc': _weatherDesc,
          'temp': _weatherTemp,
          'humidity': _weatherHumidity,
          'city': _weatherCity,
          'icon': _weatherIcon,
          'feelsLike': _weatherFeelsLike,
          'windSpeed': _weatherWindSpeed,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
        await prefs.setString('weather_last_date', '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}');
        log.log('WEATHER', '天气数据已缓存');
      } finally {
        client.close();
      }

      log.log('WEATHER', '=== 天气加载完成 ===');
    } catch (e, stackTrace) {
      log.log('WEATHER', '异常: $e');
      log.log('WEATHER', '堆栈: $stackTrace');
      // Try loading from cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('weather_cache');
        if (cached != null) {
          final data = jsonDecode(cached);
          final cacheTime = data['timestamp'] as int? ?? 0;
          if (DateTime.now().millisecondsSinceEpoch - cacheTime < 6 * 3600 * 1000) {
            setState(() {
              _weatherDesc = data['desc'] ?? '';
              _weatherTemp = data['temp'] ?? '';
              _weatherHumidity = data['humidity'] ?? '';
              _weatherCity = data['city'] ?? '';
              _weatherIcon = data['icon'] ?? '';
              _weatherFeelsLike = data['feelsLike'] ?? '';
              _weatherWindSpeed = data['windSpeed'] ?? '';
              _weatherLoading = false;
            });
            log.log('WEATHER', '从缓存加载天气成功');
            return;
          }
        }
      } catch (_) {}
      setState(() => _weatherLoading = false);
      log.log('WEATHER', '天气加载失败');
    }
  }

  String _getWeatherIcon(String iconCode) {
    // QWeather icon codes: https://dev.qweather.com/docs/start/icons/
    final code = int.tryParse(iconCode) ?? 100;
    if (code == 100) return '☀️';
    if (code == 101 || code == 102) return '⛅';
    if (code == 103) return '🌤️';
    if (code == 104) return '☁️';
    if (code >= 300 && code < 400) return '🌧️';
    if (code >= 400 && code < 500) return '🌨️';
    if (code >= 500 && code < 600) return '🌫️';
    if (code >= 600 && code < 700) return '🌧️';
    if (code >= 800 && code < 900) return '⛈️';
    return '🌤️';
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

    if (_weatherTemp.isEmpty || _weatherDesc.contains('配置')) {
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
                  _weatherDesc.isEmpty ? '天气数据加载失败' : _weatherDesc,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Text(_weatherIcon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_weatherDesc  $_weatherTemp°C',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('$_weatherCity  体感${_weatherFeelsLike}°C',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildWeatherDetail(Icons.water_drop_outlined, '湿度 $_weatherHumidity%'),
                const SizedBox(width: 16),
                _buildWeatherDetail(Icons.air, '风速 ${_weatherWindSpeed}km/h'),

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
