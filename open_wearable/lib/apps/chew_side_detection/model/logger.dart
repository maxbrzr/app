import 'dart:io';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Represents a single step event
class StepEvent {
  final int blockNumber;
  final String instruction;
  final String taskName;
  final int duration;
  final DateTime startTime;
  DateTime? endTime;
  final int relativeStartTime;
  int? relativeEndTime;

  StepEvent({
    required this.blockNumber,
    required this.instruction,
    required this.taskName,
    required this.duration,
    required this.startTime,
    this.endTime,
    required this.relativeStartTime,
    this.relativeEndTime,
  });

  List<String> toCsvRow() {
    return [
      blockNumber.toString(),
      instruction,
      taskName,
      duration.toString(),
      startTime.toIso8601String(),
      endTime?.toIso8601String() ?? '',
      relativeStartTime.toString(),
      relativeEndTime?.toString() ?? '',
    ];
  }
}

/// Logger for ExperimentManager
class ExperimentLogger {
  static const String _csvHeader =
      'Block,Instruction,Task,Duration (s),Start Time,End Time,Relative Start (ms),Relative End (ms),Sensor Configurations';

  late File _csvFile;
  late DateTime _sessionStartTime;
  // late String _sessionId;
  // late String _sensorConfig;

  final List<StepEvent> _events = [];

  Future<void> initialize([String prefix = 'experiment']) async {
    print("prefix = $prefix");
    final dir = await getApplicationDocumentsDirectory();
    _csvFile = File('${dir.path}/${prefix}_log.csv');
    if (!await _csvFile.exists()) {
      await _csvFile.writeAsString('$_csvHeader\n');
    }
  }

  void startSession() {
    _events.clear();
    _sessionStartTime = DateTime.now();
    // _sessionId = sessionId;
    // _sensorConfig = sensorConfig;
  }

  void logStepStart(
    int blockNumber,
    String instruction,
    String taskName,
    int duration,
  ) {
    final now = DateTime.now();
    final relative = now.difference(_sessionStartTime).inMilliseconds;
    final event = StepEvent(
      blockNumber: blockNumber,
      instruction: instruction,
      taskName: taskName,
      duration: duration,
      startTime: now,
      relativeStartTime: relative,
    );
    print(event.toCsvRow());
    _events.add(event);
  }

  void logStepEnd() {
    if (_events.isEmpty) return;

    final now = DateTime.now();
    final relative = now.difference(_sessionStartTime).inMilliseconds;

    final event = _events.last;
    event.endTime = now;
    event.relativeEndTime = relative;
    print(event.toCsvRow());
  }

  void discardLastStep() {
    if (_events.isNotEmpty) _events.removeLast();
  }

  Future<void> finalizeSession() async {
    print("Finalizing session");
    if (_events.isEmpty) return;

    final rows = <List<String>>[];
    for (final e in _events) {
      rows.add(e.toCsvRow());
    }

    final converter = ListToCsvConverter();
    final csvData = converter.convert(rows);

    await _csvFile.writeAsString(csvData, mode: FileMode.append);

    _events.clear();
  }

  String get csvPath => _csvFile.path;
  File get csvFile => _csvFile;

  // Future<String> getSessionSummary() async {
  //   if (_events.isEmpty) return 'No data recorded';

  //   final buffer = StringBuffer();
  //   buffer.writeln('Session started: $_sessionStartTime');
  //   buffer.writeln('Steps recorded: ${_events.length}\n');

  //   for (var i = 0; i < _events.length; i++) {
  //     final e = _events[i];
  //     buffer.writeln('Step ${i + 1} [${e.blockNumber}]: ${e.taskName}');
  //     buffer.writeln('  Description: ${e.instruction}');
  //     buffer.writeln('  Duration: ${e.duration}s');
  //     buffer.writeln('  Started: ${e.relativeStartTime} ms relative');
  //     if (e.relativeEndTime != null) {
  //       buffer.writeln('  Ended: ${e.relativeEndTime} ms relative');
  //     }
  //     buffer.writeln();
  //   }
  //   return buffer.toString();
  // }

  /// Get all log files in the documents directory
  static Future<List<File>> getAllLogFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = <File>[];

    try {
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.endsWith('log.csv')) {
          files.add(entity);
        }
      }
    } catch (e) {
      print('Error listing log files: $e');
    }

    // Sort by modification date, newest first
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Archive the current log file by renaming it with a timestamp prefix, similar to log rotation
  Future<File> archiveLogFile() async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    final path = _csvFile.path;
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    var newFileName = '${timestamp}_${path.substring(lastSeparator + 1)}';
    var newPath = path.substring(0, lastSeparator + 1) + newFileName;

    if (await _csvFile.exists()) {
      // rename old file and init new file
      await _csvFile.rename(newPath);
      await _csvFile.writeAsString('$_csvHeader\n');
    }

    return File(newPath);
  }

  /// Delete a log file
  static Future<void> deleteLogFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
