import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:intl/intl.dart';
import 'package:open_wearable/apps/chew_side_detection/model/block.dart';
import 'package:open_wearable/apps/chew_side_detection/model/config.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'logger.dart';

enum ExperimentState {
  notStarted,
  configuringSensors,
  waitingToStart,
  running,
  stepComplete,
  experimentComplete,
}

class ExperimentManager with ChangeNotifier {
  final ExperimentConfig experimentConfig;
  final Wearable leftWearable;
  final SensorConfigurationProvider leftConfigProvider;
  final Wearable rightWearable;
  final SensorConfigurationProvider rightConfigProvider;
  final ExperimentLogger logger;
  final TextEditingController _experimentIdController = TextEditingController();
  late String experimentID;

  late List<SensorConfiguration> _sensorConfigurations;
  late Map<String, SensorConfiguration> _sensorIdToConfigMap;

  // Indices
  int _currentBlockIndex = 0;
  int _currentBlockTaskIndex = 0;
  int _currentTaskIndex = 0;

  // State
  ExperimentState _state = ExperimentState.notStarted;
  DateTime? _sessionStartTime;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  bool _sensorsConfigured = false;
  String sessionId = _generateSessionId();

  ExperimentManager({
    required this.experimentConfig,
    required this.leftWearable,
    required this.leftConfigProvider,
    required this.rightWearable,
    required this.rightConfigProvider,
    required this.logger,
  }) {
    if (leftWearable is SensorConfigurationManager) {
      // Get all available sensor configurations
      _sensorConfigurations =
          (leftWearable as SensorConfigurationManager).sensorConfigurations;
      _sensorIdToConfigMap = {};

      // Create a mapping from sensor IDs to their configurations
      for (var configuration in _sensorConfigurations) {
        // Map the sensor ID to the configuration
        _sensorIdToConfigMap[configuration.name] = configuration;
      }
    } else {
      throw Exception(
          "The left wearable does not support sensor configuration");
    }
    if (rightWearable is SensorConfigurationManager) {
      // Get all available sensor configurations
      _sensorConfigurations =
          (rightWearable as SensorConfigurationManager).sensorConfigurations;
      _sensorIdToConfigMap = {};

      // Create a mapping from sensor IDs to their configurations
      for (var configuration in _sensorConfigurations) {
        // Map the sensor ID to the configuration
        _sensorIdToConfigMap[configuration.name] = configuration;
      }
    } else {
      throw Exception(
          "The right wearable does not support sensor configuration");
    }
    // for (var blockEntry in experimentConfig.blocks.asMap().entries) {
    //   final blockIndex = blockEntry.key;
    //   final instruction = blockEntry.value.instruction;
    //   final block = blockEntry.value;

    //   for (var taskEntry in block.tasks.asMap().entries) {
    //     final taskIndex = taskEntry.key;
    //     final task = taskEntry.value;

    //     print(
    //         'Block $blockIndex, Instruction: $instruction, Task $taskIndex: ${task.name}');
    //   }
    // }
  }

  int get currentBlockIndex => _currentBlockIndex;
  int get currentBlockTaskIndex => _currentBlockTaskIndex;
  int get currentTaskIndex => _currentTaskIndex;

  ExperimentBlock get currentBlock =>
      experimentConfig.blocks[_currentBlockIndex];

  Task? get currentTask {
    final block = experimentConfig.blocks[_currentBlockIndex];
    if (block.tasks.isEmpty) return null;
    return block.tasks[_currentBlockTaskIndex];
  }

  int get totalNumTasks =>
      experimentConfig.blocks.fold(0, (sum, block) => sum + block.tasks.length);

  ExperimentState get state => _state;
  int get elapsedSeconds => _elapsedSeconds;
  DateTime? get sessionStartTime => _sessionStartTime;

  double get progress {
    // No current task or experiment hasn't started yet
    if (currentTask == null ||
        _state == ExperimentState.notStarted ||
        _state == ExperimentState.waitingToStart) {
      return 0.0;
    }

    // Prevent division by zero
    final duration = currentTask!.duration;
    if (duration == 0) return 0.0;

    // Calculate progress
    return _elapsedSeconds / duration;
  }

  TextEditingController get experimentIdController => _experimentIdController;

  bool get isLastBlockStep {
    if (currentBlock.tasks.isEmpty) return true;
    return currentBlockTaskIndex == currentBlock.tasks.length - 1;
  }

  bool get isLastStep {
    return _currentTaskIndex == totalNumTasks - 1;
  }

  bool get hasCurrentStepTimer {
    if (currentBlock.tasks.isEmpty) return false;
    return true;
  }

  static String _generateSessionId() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final Random random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        5,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Start the experiment session
  Future<void> startExperiment() async {
    if (_state != ExperimentState.notStarted) return;

    try {
      _state = ExperimentState.configuringSensors;
      notifyListeners();

      // Get experiment ID from text field
      experimentID = _experimentIdController.text.trim();

      // 🔹 Initialize the logger with experiment ID
      await logger.initialize(experimentID);

      var timestamp = DateFormat('yyMMdd_HH_mm').format(DateTime.now());
      await _setSensorLogFilePrefix(
        "${timestamp}_${experimentID}_${sessionId}_",
      );

      var selectedConfigurations = await _configureSensors();
      _sensorsConfigured = true;

      String configurations = selectedConfigurations.map(
        (entry) {
          String name = entry.$1.name;
          String frequency = entry.$2 is SensorFrequencyConfigurationValue
              ? "${(entry.$2 as SensorFrequencyConfigurationValue).frequencyHz}Hz"
              : "configured";
          return "$name: $frequency";
        },
      ).join("; ");

      logger.startSession();
      _sessionStartTime = DateTime.now();

      // Prepare the first step but don't start the timer yet
      _prepareCurrentStep();
    } catch (e) {
      _state = ExperimentState.notStarted;
      notifyListeners();
      rethrow;
    }
  }

  /// Prepare the current step (without starting the timer)
  void _prepareCurrentStep() {
    _elapsedSeconds = 0;
    _state = ExperimentState.waitingToStart;
    notifyListeners();
  }

  /// Start the timer for the current step (called manually by user)
  void startCurrentStepTimer() {
    if (_state != ExperimentState.waitingToStart) return;

    _state = ExperimentState.running;

    // If there's no task, do nothing
    final task = currentTask;
    if (task == null) return;

    _state = ExperimentState.running;

    // Log step start
    logger.logStepStart(
      currentBlock.number,
      currentBlock.instruction,
      task.name,
      task.duration,
    );

    // Start the progress timer
    _progressTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();

      if (_elapsedSeconds >= task.duration) {
        _completeCurrentStep();
      }
    });

    notifyListeners();
  }

  /// Complete the current step
  void _completeCurrentStep() {
    _progressTimer?.cancel();
    _progressTimer = null;

    logger.logStepEnd();
    _state = ExperimentState.stepComplete;
    notifyListeners();
  }

  /// Move to the next step in the experiment process
  void nextStep() {
    print("currentBlockIndex: $_currentBlockIndex");
    print("currentBlockTaskIndex: $_currentBlockTaskIndex");
    print("currentTaskIndex: $_currentTaskIndex");
    print("isLastStep: $isLastStep");
    print("isLastBlockStep: $isLastBlockStep");

    if (isLastStep) {
      stop();
      return;
    }

    if (isLastBlockStep) {
      _currentTaskIndex++;
      _currentBlockIndex++;
      _currentBlockTaskIndex = 0;
      notifyListeners();
      _prepareCurrentStep();
      return;
    }

    _currentTaskIndex++;
    _currentBlockTaskIndex++;
    _prepareCurrentStep(); // Prepare the next step but don't start timer
  }

  Future<void> _setSensorLogFilePrefix(String prefix) async {
    if (leftWearable is EdgeRecorderManager) {
      // Set the log file prefix for the wearable
      await (leftWearable as EdgeRecorderManager).setFilePrefix(prefix);
    } else {
      throw Exception(
        "The left wearable does not support setting a log file prefix",
      );
    }
    if (rightWearable is EdgeRecorderManager) {
      // Set the log file prefix for the wearable
      await (rightWearable as EdgeRecorderManager).setFilePrefix(prefix);
    } else {
      throw Exception(
        "The right wearable does not support setting a log file prefix",
      );
    }
  }

  /// Configure sensors based on global configuration
  Future<
      List<
          (
            SensorConfiguration<SensorConfigurationValue>,
            SensorConfigurationValue
          )>> _configureSensors() async {
    if ((leftWearable is! SensorConfigurationManager ||
        rightWearable is! SensorConfigurationManager)) {
      throw Exception("The wearable does not support sensor configuration");
    }

    // Configure each sensor according to the global configuration
    for (var experimentSensorConfig in experimentConfig.globalSensorConfigs) {
      final sensorName = experimentSensorConfig.sensor.toLowerCase();

      // Get the sensor ID from the configuration
      final sensorId = experimentConfig.getSensorId(sensorName);

      if (sensorId != null && _sensorIdToConfigMap.containsKey(sensorId)) {
        final configuration = _sensorIdToConfigMap[sensorId]!;

        if (configuration is SensorFrequencyConfiguration) {
          List<SensorConfigurationValue> values = leftConfigProvider
              .getSensorConfigurationValues(configuration, distinct: true);

          // Find the closest sample rate
          SensorFrequencyConfigurationValue? bestMatch;
          double minDiff = 1000000;

          for (var value in values) {
            if (value is SensorFrequencyConfigurationValue) {
              double diff =
                  (value.frequencyHz - experimentSensorConfig.sampleRate).abs();
              if (diff < minDiff) {
                minDiff = diff;
                bestMatch = value;
              }
              if (minDiff == 0) {
                break;
              }
            }
          }

          if (bestMatch != null) {
            leftConfigProvider.addSensorConfiguration(
              configuration,
              bestMatch,
            );
            rightConfigProvider.addSensorConfiguration(
              configuration,
              bestMatch,
            );
          }
        }

        if (configuration is ConfigurableSensorConfiguration) {
          if (configuration.availableOptions
              .contains(RecordSensorConfigOption())) {
            leftConfigProvider.addSensorConfigurationOption(
              configuration,
              RecordSensorConfigOption(),
            );
            rightConfigProvider.addSensorConfigurationOption(
              configuration,
              RecordSensorConfigOption(),
            );
          }
        }
      }
    }

    var selectedConfigurations = leftConfigProvider.getSelectedConfigurations();
    for (var entry in selectedConfigurations) {
      SensorConfiguration config = entry.$1;
      SensorConfigurationValue value = entry.$2;
      config.setConfiguration(value);
    }

    return selectedConfigurations;
  }

  /// Deactivate all configured sensors
  Future<void> _deactivateSensors() async {
    if ((leftWearable is! SensorConfigurationManager ||
        rightWearable is! SensorConfigurationManager)) {
      return;
    }

    // Deactivate each configured sensor by removing their options
    for (var sensorConfig in experimentConfig.globalSensorConfigs) {
      final sensorName = sensorConfig.sensor.toLowerCase();
      final sensorId = experimentConfig.getSensorId(sensorName);

      if (sensorId != null && _sensorIdToConfigMap.containsKey(sensorId)) {
        final configuration = _sensorIdToConfigMap[sensorId]!;
        if (configuration is ConfigurableSensorConfiguration) {
          // Remove streaming option to disable the sensor
          leftConfigProvider.removeSensorConfigurationOption(
            configuration,
            RecordSensorConfigOption(),
          );
          rightConfigProvider.removeSensorConfigurationOption(
            configuration,
            RecordSensorConfigOption(),
          );
          var value =
              leftConfigProvider.getSelectedConfigurationValue(configuration);
          if (value != null) {
            configuration.setConfiguration(
                value as ConfigurableSensorConfigurationValue);
          }
        }
      }
    }
  }

  /// Reset the current step timer back to 0
  void resetCurrentStepTimer() {
    if (_state == ExperimentState.running ||
        _state == ExperimentState.stepComplete) {
      _progressTimer?.cancel();
      _progressTimer = null;
      _elapsedSeconds = 0;

      logger.discardLastStep();

      // Return to waiting state
      _state = ExperimentState.waitingToStart;
      notifyListeners();
    }
  }

  /// Stop the experiment completely
  Future<void> stop() async {
    _progressTimer?.cancel();
    _progressTimer = null;

    if (_sensorsConfigured) {
      await _deactivateSensors();
      _sensorsConfigured = false;
    }

    // Finalize the session logging if we have data
    print("_sessionStartTime: $_sessionStartTime");
    if (_sessionStartTime != null) {
      await logger.finalizeSession();
    }

    _state = ExperimentState.notStarted;
    _currentTaskIndex = 0;
    _elapsedSeconds = 0;
    _sessionStartTime = null;
    sessionId = _generateSessionId();
    notifyListeners();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}
