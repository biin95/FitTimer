import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _soundEnabled = true;
  bool _notificationEnabled = true;
  String? _customRingtonePath;
  bool _autoStartNextSet = true;
  int _reminderDuration = 3;
  String _exportPath = '';
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService();
    final vibration = await db.getSetting('vibration_enabled');
    final sound = await db.getSetting('sound_enabled');
    final notification = await db.getSetting('notification_enabled');
    final ringtone = await db.getSetting('custom_ringtone_path');
    final autoStart = await db.getSetting('auto_start_next_set');
    final reminder = await db.getSetting('rest_reminder_duration');
    final exportPath = await db.getSetting('export_path');
    setState(() {
      _vibrationEnabled = vibration != 'false';
      _soundEnabled = sound != 'false';
      _notificationEnabled = notification != 'false';
      _customRingtonePath = ringtone;
      _autoStartNextSet = autoStart != 'false';
      _reminderDuration = int.tryParse(reminder ?? '') ?? 3;
      _exportPath = exportPath ?? '';
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

  Future<void> _toggleSound(bool value) async {
    setState(() => _soundEnabled = value);
    await _setSetting('sound_enabled', value.toString());
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() => _notificationEnabled = value);
    await _setSetting('notification_enabled', value.toString());
  }

  Future<void> _pickCustomRingtone() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() => _customRingtonePath = path);
      await _setSetting('custom_ringtone_path', path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('自定义铃声已设置')),
        );
      }
    }
  }

  Future<void> _toggleAutoStart(bool value) async {
    setState(() => _autoStartNextSet = value);
    await _setSetting('auto_start_next_set', value.toString());
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
            child: const Text('确定导入', style: TextStyle(color: Colors.red)),
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
          Text('提醒设置', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('震动提醒'),
            subtitle: const Text('休息结束时震动提示'),
            value: _vibrationEnabled,
            onChanged: _toggleVibration,
          ),
          SwitchListTile(
            title: const Text('声音提醒'),
            subtitle: const Text('休息结束时播放提示音'),
            value: _soundEnabled,
            onChanged: _toggleSound,
          ),
          SwitchListTile(
            title: const Text('通知栏提醒'),
            subtitle: const Text('在通知栏显示倒计时'),
            value: _notificationEnabled,
            onChanged: _toggleNotification,
          ),
          ListTile(
            title: const Text('自定义铃声'),
            subtitle: Text(
              _customRingtonePath != null
                  ? _customRingtonePath!.split(Platform.pathSeparator).last
                  : '使用默认铃声',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickCustomRingtone,
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
 subtitle: Text('休息结束后震动/声音持续 $_reminderDuration 秒'),
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
          const ListTile(
            title: Text('FitTimer'),
            subtitle: Text('版本 1.2.3'),
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
