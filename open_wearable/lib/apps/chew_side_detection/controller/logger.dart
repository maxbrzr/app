import 'dart:io';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

/// Represents a single step event
class StepEvent {
  final int blockNumber;
  final String instruction;
  final String taskId;
  final int duration;
  final DateTime startTime;
  DateTime? endTime;
  final int relativeStartTime;
  int? relativeEndTime;

  StepEvent({
    required this.blockNumber,
    required this.instruction,
    required this.taskId,
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
      taskId,
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
  final String taskId;
  final DateTime timestamp;
  final int relativeTime;
  final String eventType;

  OtherEvent({
    required this.blockNumber,
    required this.instruction,
    required this.taskId,
    required this.timestamp,
    required this.relativeTime,
    required this.eventType,
  });

  List<String> toCsvRow() {
    return [
      blockNumber.toString(),
      instruction,
      taskId,
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
  final List<StepEvent> _stepEvents = [];
  final List<OtherEvent> _otherEvents = [];

  File get csvFile => _stepsCsvFile;

  Future<void> initialize(String prefix) async {
    print("prefix = $prefix");
    final dir = await getApplicationDocumentsDirectory();

    _stepsCsvFile = File('${dir.path}/${prefix}_steps_log.csv');
    _otherCsvFile = File('${dir.path}/${prefix}_other_log.csv');

    await Future.wait([
      () async {
        if (!await _stepsCsvFile.exists()) {
          await _stepsCsvFile.writeAsString('$_stepsCsvHeader\n');
        }
      }(),
      () async {
        if (!await _otherCsvFile.exists()) {
          await _otherCsvFile.writeAsString('$_otherCsvHeader\n');
        }
      }(),
    ]);
  }

  void startLogging() {
    _stepEvents.clear();
    _sessionStartTime = DateTime.now();
  }

  void logOtherEvent(
    int blockNumber,
    String instruction,
    String taskId,
    String eventType,
  ) {
    final now = DateTime.now();
    final relative = now.difference(_sessionStartTime).inMilliseconds;
    final event = OtherEvent(
      blockNumber: blockNumber,
      instruction: instruction,
      taskId: taskId,
      timestamp: now,
      relativeTime: relative,
      eventType: eventType,
    );
    print(event.toCsvRow());
    _otherEvents.add(event);
  }

  void logTaskStart(
    int blockNumber,
    String instruction,
    String taskId,
    int duration,
  ) {
    final now = DateTime.now();
    final relative = now.difference(_sessionStartTime).inMilliseconds;
    final event = StepEvent(
      blockNumber: blockNumber,
      instruction: instruction,
      taskId: taskId,
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

  void discardLastTask() {
    if (_stepEvents.isNotEmpty) _stepEvents.removeLast();
  }

  Future<void> stopAndWriteLogging() async {
    print("Finalizing experiment");

    final stepsRows = <List<String>>[];
    for (final e in _stepEvents) {
      stepsRows.add(e.toCsvRow());
    }

    final otherRows = <List<String>>[];
    for (final e in _otherEvents) {
      otherRows.add(e.toCsvRow());
    }

    final converter = ListToCsvConverter();
    final stepsCsvData = converter.convert(stepsRows);
    final otherCsvData = converter.convert(otherRows);

    await Future.wait([
      _stepsCsvFile.writeAsString(stepsCsvData, mode: FileMode.append),
      _otherCsvFile.writeAsString(otherCsvData, mode: FileMode.append),
    ]);

    _stepEvents.clear();
    _otherEvents.clear();
  }

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

  /// Delete a log file
  static Future<void> deleteLogFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
