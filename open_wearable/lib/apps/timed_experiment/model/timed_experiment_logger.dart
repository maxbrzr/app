import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Represents a single step event record
class StepEvent {
  final String stepName;
  final String description;
  final int duration;
  final DateTime startTime;
  final DateTime? endTime;
  final int relativeStartTime; // ms since session start
  final int? relativeEndTime; // ms since session start

  StepEvent({
    required this.stepName,
    required this.description,
    required this.duration,
    required this.startTime,
    this.endTime,
    required this.relativeStartTime,
    this.relativeEndTime,
  });

  /// Convert step event to CSV row
  List<String> toCsvRow() {
    return [
      stepName,
      description,
      duration.toString(),
      startTime.toIso8601String(),
      endTime?.toIso8601String() ?? '',
      relativeStartTime.toString(),
      relativeEndTime?.toString() ?? '',
    ];
  }
}

/// Manages CSV logging for timed experiment sessions
class TimedExperimentLogger {
  static const String _csvHeader =
      'Session ID,Step Name,Description,Duration (s),Start Time,End Time,Relative Start (ms),Relative End (ms),Sensor Configurations';

  late File _csvFile;
  late DateTime _sessionStartTime;
  final List<StepEvent> _currentSessionEvents = [];

  late String _sensorConfigurations;
  late String _sessionId;

  /// Initialize the CSV logger with a file prefix
  Future<void> initialize([String filePrefix = 'timed_experiment']) async {
    final directory = await getApplicationDocumentsDirectory();
    _csvFile = File('${directory.path}/${filePrefix}_log.csv');

    // Create file with header if it doesn't exist
    if (!await _csvFile.exists()) {
      await _csvFile.writeAsString('$_csvHeader\n');
    }
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

  /// Start a new session
  void startSession(String configurations, String sessionId) {
    print("Starting session: $sessionId");
    _sessionStartTime = DateTime.now();
    _currentSessionEvents.clear();
    _sensorConfigurations = configurations;
    _sessionId = sessionId;
  }

  /// Log a step start event
  void logStepStart(String stepName, String description, int duration) {
    print("Logging step start: $stepName");
    final now = DateTime.now();
    final relativeTime = now.difference(_sessionStartTime).inMilliseconds;

    final event = StepEvent(
      stepName: stepName,
      description: description,
      duration: duration,
      startTime: now,
      relativeStartTime: relativeTime,
    );

    _currentSessionEvents.add(event);
  }

  /// Log a step end event
  void logStepEnd() {
    print("Logging step end");
    if (_currentSessionEvents.isEmpty) return;

    final now = DateTime.now();
    final relativeTime = now.difference(_sessionStartTime).inMilliseconds;

    // Update the last event with end time
    final lastEvent = _currentSessionEvents.last;
    final updatedEvent = StepEvent(
      stepName: lastEvent.stepName,
      description: lastEvent.description,
      duration: lastEvent.duration,
      startTime: lastEvent.startTime,
      endTime: now,
      relativeStartTime: lastEvent.relativeStartTime,
      relativeEndTime: relativeTime,
    );

    _currentSessionEvents[_currentSessionEvents.length - 1] = updatedEvent;
  }

  void discardLastStep() {
    if (_currentSessionEvents.isNotEmpty) {
      _currentSessionEvents.removeLast();
    }
  }

  /// Finalize and save the current session to CSV
  Future<void> finalizeSession() async {
    print("Finalizing session");
    if (_currentSessionEvents.isEmpty) return;

    final rows = <List<String>>[];

    // Add session separator
    final now = DateTime.now();
    final duration = now.difference(_sessionStartTime).inSeconds;
    rows.add([
      _sessionId,
      '',
      '',
      duration.toString(),
      _sessionStartTime.toIso8601String(),
      now.toIso8601String(),
      '',
      '',
      _sensorConfigurations
    ]);

    // Add all events for this session
    for (final event in _currentSessionEvents) {
      rows.add(['', ...event.toCsvRow()]);
    }

    // Add empty row after session
    rows.add(['']);

    const converter = ListToCsvConverter();
    final csvData = converter.convert(rows);

    await _csvFile.writeAsString(csvData, mode: FileMode.append);

    _currentSessionEvents.clear();
  }

  /// Get the path to the current CSV file
  String get csvFilePath => _csvFile.path;

  /// Get the CSV file for sharing
  File get csvFile => _csvFile;

  /// Get all session data as a formatted string for preview
  Future<String> getSessionSummary() async {
    if (_currentSessionEvents.isEmpty) return 'No data recorded';

    final buffer = StringBuffer();
    buffer.writeln('Session started: ${_sessionStartTime.toString()}');
    buffer.writeln('Steps recorded: ${_currentSessionEvents.length}');
    buffer.writeln();

    for (int i = 0; i < _currentSessionEvents.length; i++) {
      final event = _currentSessionEvents[i];
      buffer.writeln('Step ${i + 1}: ${event.stepName}');
      buffer.writeln('  Description: ${event.description}');
      buffer.writeln('  Duration: ${event.duration}s');
      buffer.writeln(
          '  Started: ${event.relativeStartTime.toStringAsFixed(1)}s relative');
      if (event.relativeEndTime != null) {
        buffer.writeln(
            '  Ended: ${event.relativeEndTime!.toStringAsFixed(1)}s relative');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
