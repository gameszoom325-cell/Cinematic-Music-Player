import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Global persistent crash logger.
/// Writes unhandled errors, stack traces, and critical diagnostics to a local log file:
///   `<Documents>/CinematicMusicPlayer/logs/app.log`
/// Allows diagnosis of crashes in release builds where debugPrint is discarded.
class CrashLogger {
  static final CrashLogger instance = CrashLogger._();
  CrashLogger._();

  File? _logFile;
  File? get logFile => _logFile;
  bool _initialized = false;
  final List<String> _pendingLogs = [];

  Future<void> init() async {
    if (_initialized) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final logDir = Directory(p.join(docDir.path, 'CinematicMusicPlayer', 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _logFile = File(p.join(logDir.path, 'app.log'));

      // If log file exceeds 5MB, rotate it
      if (await _logFile!.exists()) {
        final length = await _logFile!.length();
        if (length > 5 * 1024 * 1024) {
          final oldFile = File(p.join(logDir.path, 'app.old.log'));
          if (await oldFile.exists()) await oldFile.delete();
          await _logFile!.rename(oldFile.path);
          _logFile = File(p.join(logDir.path, 'app.log'));
        }
      }

      _initialized = true;

      // Flush any early logs captured before directory was ready
      if (_pendingLogs.isNotEmpty) {
        for (final entry in _pendingLogs) {
          await _writeSync(entry);
        }
        _pendingLogs.clear();
      }

      logInfo("=== Cinematic Music Player Started [${DateTime.now().toIso8601String()}] ===");
    } catch (e) {
      debugPrint("CrashLogger init notice: $e");
    }
  }

  Future<void> _writeSync(String line) async {
    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  void logInfo(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = "[$timestamp] [INFO] $message";
    debugPrint(entry);
    if (_initialized && _logFile != null) {
      _writeSync(entry);
    } else {
      _pendingLogs.add(entry);
    }
  }

  void logError(Object error, [StackTrace? stack, String? context]) {
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer();
    buffer.writeln("[$timestamp] [ERROR] ${context != null ? '($context) ' : ''}$error");
    if (stack != null) {
      buffer.writeln("--- Stack Trace ---");
      buffer.writeln(stack.toString().trim());
      buffer.writeln("-------------------");
    }
    final entry = buffer.toString().trim();
    debugPrint(entry);

    if (_initialized && _logFile != null) {
      _writeSync(entry);
    } else {
      _pendingLogs.add(entry);
    }
  }

  String? get logFilePath => _logFile?.path;
}
