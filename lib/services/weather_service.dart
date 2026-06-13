import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// 天气数据模型
class WeatherData {
  final String desc;        // 天气描述
  final String temp;        // 温度
  final String humidity;    // 湿度
  final String city;        // 城市
  final String icon;        // 天气图标
  final String feelsLike;   // 体感温度
  final String windSpeed;   // 风速
  final String tip;         // 训练建议

  const WeatherData({
    required this.desc,
    required this.temp,
    required this.humidity,
    required this.city,
    required this.icon,
    required this.feelsLike,
    required this.windSpeed,
    required this.tip,
  });

  Map<String, dynamic> toJson() => {
    'desc': desc,
    'temp': temp,
    'humidity': humidity,
    'city': city,
    'icon': icon,
    'feelsLike': feelsLike,
    'windSpeed': windSpeed,
    'tip': tip,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      desc: json['desc'] ?? '',
      temp: json['temp'] ?? '',
      humidity: json['humidity'] ?? '',
      city: json['city'] ?? '',
      icon: json['icon'] ?? '',
      feelsLike: json['feelsLike'] ?? '',
      windSpeed: json['windSpeed'] ?? '',
      tip: json['tip'] ?? '',
    );
  }
}

/// 定位结果
class Location {
  final double lat;
  final double lon;

  const Location({required this.lat, required this.lon});
}

/// 城市信息
class LocationInfo {
  final String locationId;
  final String cityName;

  const LocationInfo({required this.locationId, required this.cityName});
}

/// 天气服务 - 单例模式
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  // API 配置（默认值，用户可在设置中覆盖）
  static const _defaultWeatherApiKey = '642e66acb9ca46c58e6372aef43eb5de';
  static const _defaultAmapApiKey = '183980b98d04cf8e9acb5c6804ba315c';
  static const _weatherHost = 'j554e6799f.re.qweatherapi.com';

  // 超时配置
  static const _amapTimeout = Duration(seconds: 8);
  static const _ipinfoTimeout = Duration(seconds: 5);
  static const _weatherTimeout = Duration(seconds: 10);

  // 缓存相关
  static const _cacheKey = 'weather_cache';
  static const _cacheDateKey = 'weather_last_date';
  static const _cacheDuration = Duration(hours: 24);

  /// 检查天气功能是否启用
  Future<bool> isEnabled() async {
    final db = DatabaseService();
    final enabled = await db.getSetting('weather_enabled');
    return enabled == 'true';
  }

  /// 获取用户设置的 API key
  Future<String> getAmapApiKey() async {
    final db = DatabaseService();
    final key = await db.getSetting('amap_api_key');
    return (key != null && key.isNotEmpty) ? key : _defaultAmapApiKey;
  }

  /// 获取天气数据
  /// [forceRefresh] 是否强制刷新（忽略缓存）
  Future<WeatherData?> fetchWeather({bool forceRefresh = false}) async {
    try {
      // 检查天气功能是否启用
      if (!await isEnabled()) {
        debugPrint('[Weather] 天气功能未启用');
        return null;
      }

      // 1. 检查缓存
      if (!forceRefresh) {
        final cached = await _loadFromCache();
        if (cached != null) {
          debugPrint('[Weather] 使用缓存数据');
          return cached;
        }
      }

      debugPrint('[Weather] 开始获取天气数据...');

      // 2. 获取定位
      final location = await _getLocation();
      debugPrint('[Weather] 定位结果: ${location.lat}, ${location.lon}');

      // 3. 获取城市信息和天气
      final client = http.Client();
      try {
        // 获取城市 ID 和名称
        final locationInfo = await _getLocationInfo(client, location);
        if (locationInfo == null) {
          debugPrint('[Weather] 获取城市信息失败');
          return null;
        }

        // 获取天气数据
        final weather = await _fetchWeatherData(client, locationInfo.locationId, locationInfo.cityName);
        if (weather != null) {
          // 4. 缓存数据
          await _saveToCache(weather);
          debugPrint('[Weather] 天气数据获取成功');
        }
        return weather;
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      debugPrint('[Weather] 获取天气失败: $e');
      debugPrint('[Weather] $stackTrace');
      return null;
    }
  }

  /// 获取定位信息
  Future<Location> _getLocation() async {
    // 方案 1: 高德 IP 定位
    final amapLocation = await _getAmapLocation();
    if (amapLocation != null) {
      debugPrint('[Weather] 使用高德定位');
      return amapLocation;
    }

    // 方案 2: ipinfo.io 兜底
    final ipinfoLocation = await _getIpinfoLocation();
    if (ipinfoLocation != null) {
      debugPrint('[Weather] 使用 ipinfo 定位');
      return ipinfoLocation;
    }

    // 方案 3: 默认坐标（上海）
    debugPrint('[Weather] 使用默认定位（上海）');
    return const Location(lat: 31.23, lon: 121.47);
  }

  /// 高德 IP 定位（带重试）
  Future<Location?> _getAmapLocation() async {
    final amapApiKey = await getAmapApiKey();
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final url = 'https://restapi.amap.com/v3/ip?key=$amapApiKey&output=json';
        debugPrint('[Weather] 高德定位请求(尝试${attempt + 1}): $url');
        final response = await http.get(Uri.parse(url)).timeout(_amapTimeout);

        debugPrint('[Weather] 高德定位HTTP状态: ${response.statusCode}');
        if (response.statusCode != 200) {
          debugPrint('[Weather] 高德定位HTTP错误: ${response.statusCode}');
          continue;
        }

        final data = jsonDecode(response.body);
        debugPrint('[Weather] 高德响应: status=${data['status']}, info=${data['info']}, infocode=${data['infocode']}');

        if (data['status'] != '1') {
          debugPrint('[Weather] 高德定位失败: ${data['info']} (infocode: ${data['infocode']})');
          continue;
        }

        // 检查 rectangle 字段是否存在且有效
        final rect = data['rectangle']?.toString();
        if (rect == null || rect.isEmpty) {
          debugPrint('[Weather] 高德返回空rectangle，尝试用city字段');
          // 尝试用 city 字段获取坐标（需要另一个API），这里直接返回null
          continue;
        }

        final corners = rect.split(';');
        if (corners.length != 2) {
          debugPrint('[Weather] 高德rectangle格式异常: $rect');
          continue;
        }

        final p1 = corners[0].split(',');
        final p2 = corners[1].split(',');
        if (p1.length != 2 || p2.length != 2) {
          debugPrint('[Weather] 高德坐标点格式异常');
          continue;
        }

        final lng1 = double.tryParse(p1[0]);
        final lat1 = double.tryParse(p1[1]);
        final lng2 = double.tryParse(p2[0]);
        final lat2 = double.tryParse(p2[1]);

        if (lng1 == null || lat1 == null || lng2 == null || lat2 == null) {
          debugPrint('[Weather] 高德坐标解析失败');
          continue;
        }

        final lat = (lat1 + lat2) / 2;
        final lon = (lng1 + lng2) / 2;
        debugPrint('[Weather] 高德定位成功: lat=$lat, lon=$lon');
        return Location(lat: lat, lon: lon);
      } catch (e) {
        debugPrint('[Weather] 高德定位异常(尝试${attempt + 1}): $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    debugPrint('[Weather] 高德定位全部失败');
    return null;
  }

  /// ipinfo.io 定位
  Future<Location?> _getIpinfoLocation() async {
    try {
      debugPrint('[Weather] ipinfo定位请求...');
      final response = await http.get(
        Uri.parse('https://ipinfo.io/json'),
      ).timeout(_ipinfoTimeout);

      debugPrint('[Weather] ipinfo HTTP状态: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('[Weather] ipinfo HTTP错误: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      debugPrint('[Weather] ipinfo响应: city=${data['city']}, region=${data['region']}, loc=${data['loc']}');
      final loc = data['loc']?.toString() ?? '';
      final parts = loc.split(',');

      if (parts.length != 2) {
        debugPrint('[Weather] ipinfo loc格式异常: $loc');
        return null;
      }

      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());

      if (lat == null || lon == null) {
        debugPrint('[Weather] ipinfo坐标解析失败');
        return null;
      }

      debugPrint('[Weather] ipinfo定位成功: lat=$lat, lon=$lon');
      return Location(lat: lat, lon: lon);
    } catch (e) {
      debugPrint('[Weather] ipinfo定位异常: $e');
      return null;
    }
  }

  /// 获取城市信息（ID 和名称，带重试）
  Future<LocationInfo?> _getLocationInfo(http.Client client, Location location) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final url = 'https://$_weatherHost/geo/v2/city/lookup'
            '?location=${location.lon},${location.lat}&number=1';

        debugPrint('[Weather] 城市查询(尝试${attempt + 1}): $url');
        final response = await client.get(
          Uri.parse(url),
          headers: {
            'X-QW-Api-Key': _defaultWeatherApiKey,
            'Accept-Encoding': 'identity',
          },
        ).timeout(_weatherTimeout);

        debugPrint('[Weather] 城市查询HTTP状态: ${response.statusCode}');
        if (response.statusCode != 200) {
          debugPrint('[Weather] 城市查询HTTP错误: ${response.statusCode}, body=${response.body}');
          continue;
        }

        final data = jsonDecode(response.body);
        debugPrint('[Weather] 城市查询响应: code=${data['code']}');

        if (data['code'] != '200') {
          debugPrint('[Weather] 城市查询API错误: ${data['code']}, msg=${data['msg']}');
          continue;
        }

        if (data['location'] == null || (data['location'] as List).isEmpty) {
          debugPrint('[Weather] 城市查询返回空location');
          continue;
        }

        final locationData = data['location'][0];
        final locationId = locationData['id'] as String;
        final cityName = locationData['name'] ?? locationData['adm2'] ?? '';

        debugPrint('[Weather] 城市信息: $cityName (ID: $locationId)');
        return LocationInfo(locationId: locationId, cityName: cityName);
      } catch (e) {
        debugPrint('[Weather] 获取城市信息异常(尝试${attempt + 1}): $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    return null;
  }

  /// 获取天气数据（带重试）
  Future<WeatherData?> _fetchWeatherData(http.Client client, String locationId, String cityName) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final url = 'https://$_weatherHost/v7/weather/now?location=$locationId';

        debugPrint('[Weather] 天气查询(尝试${attempt + 1}): $url');
        final response = await client.get(
          Uri.parse(url),
          headers: {
            'X-QW-Api-Key': _defaultWeatherApiKey,
            'Accept-Encoding': 'identity',
          },
        ).timeout(_weatherTimeout);

        debugPrint('[Weather] 天气查询HTTP状态: ${response.statusCode}');
        if (response.statusCode != 200) {
          debugPrint('[Weather] 天气查询HTTP错误: ${response.statusCode}, body=${response.body}');
          continue;
        }

        final data = jsonDecode(response.body);
        debugPrint('[Weather] 天气查询响应: code=${data['code']}');

        if (data['code'] != '200') {
          debugPrint('[Weather] 天气查询API错误: ${data['code']}, msg=${data['msg']}');
          continue;
        }

        if (data['now'] == null) {
          debugPrint('[Weather] 天气查询返回空now字段');
          continue;
        }

        final now = data['now'];
        final temp = (now['temp'] ?? '').toString().trim();
        final humidity = (now['humidity'] ?? '').toString().trim();
        final desc = (now['text'] ?? '').toString().trim();
        final feelsLike = (now['feelsLike'] ?? '').toString().trim();
        final windSpeed = (now['windSpeed'] ?? '').toString().trim();
        final iconCode = (now['icon'] ?? '100').toString();

        return WeatherData(
          desc: desc,
          temp: temp,
          humidity: humidity,
          city: cityName,
          icon: _getWeatherIcon(iconCode),
          feelsLike: feelsLike,
          windSpeed: windSpeed,
          tip: _getWeatherTip(temp, humidity, desc, feelsLike),
        );
      } catch (e) {
        debugPrint('[Weather] 获取天气数据失败(尝试${attempt + 1}): $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    return null;
  }

  /// 从缓存加载天气数据
  Future<WeatherData?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;

      final data = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int? ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // 检查缓存是否过期
      if (DateTime.now().difference(cacheTime) > _cacheDuration) {
        debugPrint('[Weather] 缓存已过期（${DateTime.now().difference(cacheTime).inHours}小时）');
        return null;
      }

      return WeatherData.fromJson(data);
    } catch (e) {
      debugPrint('[Weather] 读取缓存失败: $e');
      return null;
    }
  }

  /// 保存天气数据到缓存
  Future<void> _saveToCache(WeatherData weather) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(weather.toJson()));
      await prefs.setString(_cacheDateKey, _formatDate(DateTime.now()));
      debugPrint('[Weather] 缓存已更新');
    } catch (e) {
      debugPrint('[Weather] 保存缓存失败: $e');
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  /// 获取天气图标
  String _getWeatherIcon(String iconCode) {
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

  /// 获取训练建议
  String _getWeatherTip(String temp, String humidity, String text, String feelsLike) {
    final t = int.tryParse(temp) ?? 0;
    final h = int.tryParse(humidity) ?? 0;
    final fl = int.tryParse(feelsLike) ?? 0;

    if (t >= 38 || fl >= 40) return '🥵极端高温，减少户外活动';
    if (t >= 35 || fl >= 38) return '🔥高温预警，注意防暑降温';
    if (t >= 30) return '☀️天气炎热，注意防晒补水';
    if (text.contains('雨')) return '🌧️出门记得带伞';
    if (text.contains('雷')) return '⛈️雷雨天气，注意安全';
    if (text.contains('风') && t < 15) return '🌬️大风降温，注意保暖';
    if (h >= 85) return '💧湿度较高，注意补水';
    if (t <= 5) return '🥶天气寒冷，注意保暖';
    if (t <= 10) return '🧥天气较冷，适当添衣';
    return '💪天气不错，适合训练';
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheDateKey);
      debugPrint('[Weather] 缓存已清除');
    } catch (e) {
      debugPrint('[Weather] 清除缓存失败: $e');
    }
  }
}
