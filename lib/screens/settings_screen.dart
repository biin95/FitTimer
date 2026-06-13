import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _vibrationEnabled = true;
  bool _notificationEnabled = true;
  bool _autoStartNextSet = true;
  int _reminderDuration = 3;
  String _exportPath = '';
  ThemeMode _themeMode = ThemeMode.system;
  String _appVersion = '1.6.0'; // 默认值，异步加载后更新

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (_) {
      // 保持默认值
    }
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService();
    final vibration = await db.getSetting('vibration_enabled');
    final notification = await db.getSetting('notification_enabled');
    final autoStart = await db.getSetting('auto_start_next_set');
    final reminder = await db.getSetting('rest_reminder_duration');
    final exportPath = await db.getSetting('export_path');
    final darkMode = await db.getSetting('dark_mode');
    setState(() {
      _vibrationEnabled = vibration != 'false';
      _notificationEnabled = notification != 'false';
      _autoStartNextSet = autoStart != 'false';
      _reminderDuration = int.tryParse(reminder ?? '') ?? 3;
      _exportPath = exportPath ?? '';
      switch (darkMode) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    });
  }

  Future<void> _setSetting(String key, String value) async {
    final db = DatabaseService();
    await db.setSetting(key, value);
  }

  Future<void> _toggleVibration(bool value) async {
    setState(() => _vibrationEnabled = value);
    await _setSetting('vibration_enabled', value.toString());
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() => _notificationEnabled = value);
    await _setSetting('notification_enabled', value.toString());
  }

  Future<void> _toggleAutoStart(bool value) async {
    setState(() => _autoStartNextSet = value);
    await _setSetting('auto_start_next_set', value.toString());
  }

  String get _themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.light:
        return '始终浅色';
      case ThemeMode.dark:
        return '始终深色';
      default:
        return '跟随系统';
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    themeModeNotifier.value = mode;
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      default:
        value = 'system';
    }
    await _setSetting('dark_mode', value);
  }

  Widget _buildExportPathTile() {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: const Text('导出路径'),
      subtitle: Text(_exportPath.isEmpty ? '默认路径' : _exportPath),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final path = await FilePicker.getDirectoryPath();
        if (path != null) {
          await _setSetting('export_path', path);
          setState(() => _exportPath = path);
        }
      },
    );
  }

  Widget _buildWeatherSettings() {
    return FutureBuilder<bool>(
      future: _isWeatherEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;
        return Column(
          children: [
            SwitchListTile(
              title: const Text('天气显示'),
              subtitle: const Text('在首页显示当前天气信息'),
              value: isEnabled,
              onChanged: (value) async {
                if (value) {
                  // 开启时弹出 API key 设置弹窗
                  _showWeatherApiKeyDialog();
                } else {
                  // 关闭时直接保存
                  await _setSetting('weather_enabled', 'false');
                  setState(() {});
                }
              },
            ),
            if (isEnabled)
              FutureBuilder<String?>(
                future: _getMaskedApiKey(),
                builder: (context, snapshot) {
                  final maskedKey = snapshot.data ?? '未设置';
                  return ListTile(
                    leading: const Icon(Icons.vpn_key),
                    title: const Text('高德 API Key'),
                    subtitle: Text(maskedKey),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showWeatherApiKeyDialog,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<bool> _isWeatherEnabled() async {
    final db = DatabaseService();
    final enabled = await db.getSetting('weather_enabled');
    return enabled == 'true';
  }

  Future<String?> _getMaskedApiKey() async {
    final db = DatabaseService();
    final key = await db.getSetting('amap_api_key');
    if (key == null || key.isEmpty) return '未设置';
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }

  void _showWeatherApiKeyDialog() {
    final db = DatabaseService();
    final keyController = TextEditingController();
    bool obscureText = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 读取已保存的 key（仅在首次显示时）
          if (keyController.text.isEmpty) {
            db.getSetting('amap_api_key').then((savedKey) {
              if (savedKey != null && savedKey.isNotEmpty) {
                keyController.text = savedKey;
              }
            });
          }

          return AlertDialog(
            title: const Text('天气功能设置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '天气功能需要使用高德 API 进行定位，请按以下步骤获取：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('1. 访问高德开放平台：'),
                  SelectableText(
                    'https://lbs.amap.com',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  const Text('2. 注册并登录账号'),
                  const Text('3. 进入「控制台」→「应用管理」→「创建新应用」'),
                  const Text('4. 添加 Key，服务平台选择「Web服务」'),
                  const Text('5. 复制生成的 Key 粘贴到下方输入框'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: keyController,
                    obscureText: obscureText,
                    decoration: InputDecoration(
                      labelText: '高德 API Key',
                      hintText: '粘贴你的高德 Key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setDialogState(() => obscureText = !obscureText);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  final key = keyController.text.trim();
                  if (key.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入 API Key')),
                    );
                    return;
                  }
                  await db.setSetting('amap_api_key', key);
                  await db.setSetting('weather_enabled', 'true');
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('天气功能已开启')),
                    );
                  }
                },
                child: const Text('保存并开启'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final db = DatabaseService();
      final data = await db.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName = 'fittimer_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      final exportDir = _exportPath.isNotEmpty ? _exportPath : directory.path;
      final file = File('$exportDir/$fileName');
      await file.writeAsString(jsonStr, encoding: utf8);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出到: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入数据'),
        content: const Text('导入将覆盖所有现有数据，包括训练记录、模板和设置。\n\n确定继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定导入', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString(encoding: utf8);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final db = DatabaseService();
      await db.importData(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据导入成功')),
        );
        _loadSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('显示设置', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('深色模式'),
            subtitle: Text(_themeModeLabel),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android, size: 18)),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
              ],
              selected: {_themeMode},
              onSelectionChanged: (modes) => _setThemeMode(modes.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const Divider(height: 32),
          Text('提醒设置', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('震动提醒'),
            subtitle: const Text('休息结束时震动提示'),
            value: _vibrationEnabled,
            onChanged: _toggleVibration,
          ),
          SwitchListTile(
            title: const Text('通知栏提醒'),
            subtitle: const Text('在通知栏显示倒计时'),
            value: _notificationEnabled,
            onChanged: _toggleNotification,
          ),
          const Divider(height: 32),
          Text('训练设置', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('自动开始下一组'),
            subtitle: const Text('组间休息结束后自动开始下一组'),
            value: _autoStartNextSet,
            onChanged: _toggleAutoStart,
          ),
          ListTile(
            title: const Text('提醒时长'),
 subtitle: Text('休息结束后震动持续 $_reminderDuration 秒'),
            trailing: DropdownButton<int>(
              value: _reminderDuration,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 秒')),
                DropdownMenuItem(value: 2, child: Text('2 秒')),
                DropdownMenuItem(value: 3, child: Text('3 秒')),
                DropdownMenuItem(value: 5, child: Text('5 秒')),
              ],
              onChanged: (v) async {
                if (v != null) {
                  setState(() => _reminderDuration = v);
                  await _setSetting('rest_reminder_duration', v.toString());
                }
              },
            ),
          ),

          const Divider(height: 32),
          Text('天气设置', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildWeatherSettings(),

          const Divider(height: 32),
          Text('数据管理', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildExportPathTile(),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('导出数据'),
            subtitle: const Text('导出所有训练记录、模板和设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('导入数据'),
            subtitle: const Text('从JSON文件导入数据（将覆盖现有数据）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _importData,
          ),
          const Divider(height: 32),
          Text('调试', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('查看调试日志'),
            subtitle: const Text('显示震动、天气等运行日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDebugLogs(),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('清除日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              log.clear();
              await log.clearFile();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('日志已清除')),
                );
              }
            },
          ),
          const Divider(height: 32),
          Text('关于', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('FitTimer'),
            subtitle: Text('版本 $_appVersion'),
          ),
        ],
      ),
    );
  }

  void _showDebugLogs() {
    final logs = log.getLogsAsString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('调试日志'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SelectableText(
            logs.isEmpty ? '暂无日志' : logs,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
