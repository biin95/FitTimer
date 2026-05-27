import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<String> _logs = [];
  int _maxLogs = 500;

  void log(String tag, String message) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';
    final entry = '[$ts][$tag] $message';
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    _writeToFile(entry);
  }

  List<String> getLogs() => List.unmodifiable(_logs);

  String getLogsAsString() => _logs.join('\n');

  void clear() {
    _logs.clear();
  }

  Future<void> _writeToFile(String entry) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fittimer_debug.log');
      await file.writeAsString('$entry\n', mode: FileMode.append);
    } catch (_) {}
  }

  Future<String> getLogFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/fittimer_debug.log';
  }

  Future<void> clearFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fittimer_debug.log');
      if (await file.exists()) {
        await file.writeAsString('');
      }
    } catch (_) {}
  }
}

final log = LogService();
