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

class OtherEvent {
  final int blockNumber;
  final String instruction;
  final String taskName;
  final DateTime timestamp;
  final int relativeTime;
  final String eventType;

  OtherEvent({
    required this.blockNumber,
    required this.instruction,
    required this.taskName,
    required this.timestamp,
    required this.relativeTime,
    required this.eventType,
  });

  List<String> toCsvRow() {
    return [
      blockNumber.toString(),
      instruction,
      taskName,
      timestamp.toIso8601String(),
      relativeTime.toString(),
      eventType,
    ];
  }
}

/// Logger for ExperimentManager
class ExperimentLogger {
  static const String _stepsCsvHeader =
      'Block,Instruction,Task,DurationS,StartTime,EndTime,RelativeStartMS,RelativeEndMS';
  static const String _otherCsvHeader =
      'Block,Instruction,Task,Time,RelativeTimeMS,EventType';

  late File _stepsCsvFile;
  late File _otherCsvFile;

  late DateTime _sessionStartTime;
  // late String _sessionId;
  // late String _sensorConfig;

  final List<StepEvent> _stepEvents = [];
  final List<OtherEvent> _otherEvents = [];

  Future<void> initialize([String prefix = 'experiment']) async {
    print("prefix = $prefix");
    final dir = await getApplicationDocumentsDirectory();

    _stepsCsvFile = File('${dir.path}/${prefix}_steps_log.csv');
    if (!await _stepsCsvFile.exists()) {
      await _stepsCsvFile.writeAsString('$_stepsCsvHeader\n');
    }

    _otherCsvFile = File('${dir.path}/${prefix}_other_log.csv');
    if (!await _otherCsvFile.exists()) {
      await _otherCsvFile.writeAsString('$_otherCsvHeader\n');
    }
  }

  void startTask() {
    _stepEvents.clear();
    _sessionStartTime = DateTime.now();
    // _sessionId = sessionId;
    // _sensorConfig = sensorConfig;
  }

  void logOtherEvent(
    int blockNumber,
    String instruction,
    String taskName,
    String eventType,
  ) {
    final now = DateTime.now();
    final relative = now.difference(_sessionStartTime).inMilliseconds;
    final event = OtherEvent(
      blockNumber: blockNumber,
      instruction: instruction,
      taskName: taskName,
      timestamp: now,
      relativeTime: relative,
      eventType: eventType,
    );
    print(event.toCsvRow());
    _otherEvents.add(event);
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
    _stepEvents.add(event);
  }

  void logTaskEnd() {
    if (_stepEvents.isEmpty) return;

    final now = DateTime.now();
    final relative = now.difference(_sessionStartTime).inMilliseconds;

    final event = _stepEvents.last;
    event.endTime = now;
    event.relativeEndTime = relative;
    print(event.toCsvRow());
  }

  void discardLastStep() {
    if (_stepEvents.isNotEmpty) _stepEvents.removeLast();
  }

  Future<void> finalizeSession() async {
    print("Finalizing session");
    if (_stepEvents.isEmpty) return;

    final rows = <List<String>>[];
    for (final e in _stepEvents) {
      rows.add(e.toCsvRow());
    }

    final converter = ListToCsvConverter();
    final csvData = converter.convert(rows);

    await _stepsCsvFile.writeAsString(csvData, mode: FileMode.append);

    _stepEvents.clear();

    if (_otherEvents.isEmpty) return;

    final otherRows = <List<String>>[];
    for (final e in _otherEvents) {
      otherRows.add(e.toCsvRow());
    }

    final otherConverter = ListToCsvConverter();
    final otherCsvData = otherConverter.convert(otherRows);

    await _otherCsvFile.writeAsString(otherCsvData, mode: FileMode.append);

    _otherEvents.clear();
  }

  String get csvPath => _stepsCsvFile.path;
  File get csvFile => _stepsCsvFile;

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

    final path = _stepsCsvFile.path;
    final lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    var newFileName = '${timestamp}_${path.substring(lastSeparator + 1)}';
    var newPath = path.substring(0, lastSeparator + 1) + newFileName;

    if (await _stepsCsvFile.exists()) {
      // rename old file and init new file
      await _stepsCsvFile.rename(newPath);
      await _stepsCsvFile.writeAsString('$_stepsCsvHeader\n');
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
