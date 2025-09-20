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
  final Wearable rightWearable;
  final SensorConfigurationProvider leftConfigProvider;
  final SensorConfigurationProvider rightConfigProvider;
  final ExperimentLogger logger;
  final TextEditingController _experimentIdController = TextEditingController();
  late String experimentID;

  late List<SensorConfiguration> _leftSensorConfigurations;
  late List<SensorConfiguration> _rightSensorConfigurations;
  late Map<String, SensorConfiguration> _leftSensorIdToConfigMap;
  late Map<String, SensorConfiguration> _rightSensorIdToConfigMap;

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

  // test stream
  // StreamSubscription? subscription;

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
      _leftSensorConfigurations =
          (leftWearable as SensorConfigurationManager).sensorConfigurations;
      _leftSensorIdToConfigMap = {};

      // Create a mapping from sensor IDs to their configurations
      for (var cfg in _leftSensorConfigurations) {
        // Map the sensor ID to the configuration
        _leftSensorIdToConfigMap[cfg.name] = cfg;
      }
    } else {
      throw Exception(
        "The left wearable does not support sensor configuration",
      );
    }
    if (rightWearable is SensorConfigurationManager) {
      // Get all available sensor configurations
      _rightSensorConfigurations =
          (rightWearable as SensorConfigurationManager).sensorConfigurations;
      _rightSensorIdToConfigMap = {};

      // Create a mapping from sensor IDs to their configurations
      for (var configuration in _rightSensorConfigurations) {
        // Map the sensor ID to the configuration
        _rightSensorIdToConfigMap[configuration.name] = configuration;
      }
    } else {
      throw Exception(
        "The right wearable does not support sensor configuration",
      );
    }
  }

  // Index getters
  int get currentBlockIndex => _currentBlockIndex;
  int get currentBlockTaskIndex => _currentBlockTaskIndex;
  int get currentTaskIndex => _currentTaskIndex;

  // Getters
  ExperimentBlock get currentBlock =>
      experimentConfig.blocks[_currentBlockIndex];

  Task? get currentTask {
    final block = experimentConfig.blocks[_currentBlockIndex];
    if (block.tasks.isEmpty) return null;
    return block.tasks[_currentBlockTaskIndex];
  }

  // Number getters
  int get totalNumTasks =>
      experimentConfig.blocks.fold(0, (sum, block) => sum + block.tasks.length);

  int get totalNumBlocks =>
      experimentConfig.blocks.fold(0, (sum, block) => sum + 1);

  int get totalNumBlockTasks =>
      experimentConfig.blocks[_currentBlockIndex].tasks.length;

  bool get isLastBlockStep {
    if (currentBlock.tasks.isEmpty) return true;
    return currentBlockTaskIndex == currentBlock.tasks.length - 1;
  }

  bool get isLastStep {
    return _currentTaskIndex == totalNumTasks - 1;
  }

  // State getters
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

      // Initialize the logger with experiment ID
      await logger.initialize(experimentID);

      var timestamp = DateFormat('yyMMdd_HH_mm').format(DateTime.now());
      await _setSensorLogFilePrefix(
        "${experimentID}_${timestamp}_",
      );

      var (leftSelectedCfgs, rightSelectedCfgs) = await _configureSensors();
      _sensorsConfigured = true;

      // if (leftWearable is SensorManager) {
      //   List<Sensor> sensors = (leftWearable as SensorManager).sensors;
      //   for (Sensor sensor in sensors) {
      //     print("Sensor: ${sensor.sensorName}");
      //     if (sensor.sensorName == "TEMPERATURE_SENSOR") {
      //       subscription = sensor.sensorStream.listen(
      //         (value) {
      //           // Handle the new sensor value
      //           print("Timestamp: ${value.timestamp}");
      //           print("Values: ${value.valueStrings}");
      //         },
      //       );
      //     }
      //   }
      // }
      String leftSelectedCfgsString = leftSelectedCfgs.map(
        (entry) {
          String name = entry.$1.name;
          String frequency = entry.$2 is SensorFrequencyConfigurationValue
              ? "${(entry.$2 as SensorFrequencyConfigurationValue).frequencyHz}Hz"
              : "configured";
          return "$name: $frequency";
        },
      ).join("; ");

      String rightSelectedCfgsString = rightSelectedCfgs.map(
        (entry) {
          String name = entry.$1.name;
          String frequency = entry.$2 is SensorFrequencyConfigurationValue
              ? "${(entry.$2 as SensorFrequencyConfigurationValue).frequencyHz}Hz"
              : "configured";
          return "$name: $frequency";
        },
      ).join("; ");

      print(leftSelectedCfgsString);
      print(rightSelectedCfgsString);

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

  void swallowed() {
    logger.logOtherEvent(
      currentBlock.number,
      currentBlock.instruction,
      currentTask!.name,
      "swallowed",
    );
  }

  void newPieceOfFood() {
    logger.logOtherEvent(
      currentBlock.number,
      currentBlock.instruction,
      currentTask!.name,
      "newPieceOfFood",
    );
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
      await (leftWearable as EdgeRecorderManager).setFilePrefix("left_$prefix");
    } else {
      throw Exception(
        "The left wearable does not support setting a log file prefix",
      );
    }
    if (rightWearable is EdgeRecorderManager) {
      // Set the log file prefix for the wearable
      await (rightWearable as EdgeRecorderManager)
          .setFilePrefix("right_$prefix");
    } else {
      throw Exception(
        "The right wearable does not support setting a log file prefix",
      );
    }
  }

  SensorFrequencyConfigurationValue? findBestMatch(
    List<SensorConfigurationValue> values,
    SensorConfig experimentSensorConfig,
  ) {
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
    return bestMatch;
  }

  void setConfigProvider(
    String? sensorId,
    SensorConfigurationProvider cfgProvider,
    Map<String, SensorConfiguration<SensorConfigurationValue>>
        sensorIdToConfigMap,
    SensorConfig experimentSensorConfig,
  ) {
    if (sensorId != null && sensorIdToConfigMap.containsKey(sensorId)) {
      final cfg = sensorIdToConfigMap[sensorId]!;

      if (cfg is SensorFrequencyConfiguration) {
        List<SensorConfigurationValue> values =
            cfgProvider.getSensorConfigurationValues(cfg, distinct: true);

        // Find the closest sample rate
        final bestMatch = findBestMatch(values, experimentSensorConfig);

        if (bestMatch != null) {
          cfgProvider.addSensorConfiguration(
            cfg,
            bestMatch,
          );
        }
      }

      // for all sensors enable recording
      // for skin temp sensor enable streaming
      if (cfg is ConfigurableSensorConfiguration) {
        if (cfg.availableOptions.contains(RecordSensorConfigOption())) {
          cfgProvider.addSensorConfigurationOption(
            cfg,
            RecordSensorConfigOption(),
          );
        }
        if (sensorId == "temperature" &&
            cfg.availableOptions.contains(StreamSensorConfigOption())) {
          cfgProvider.addSensorConfigurationOption(
            cfg,
            StreamSensorConfigOption(),
          );
        }
      }
    }
  }

  /// Configure sensors based on global configuration
  Future<
      (
        List<
            (
              SensorConfiguration<SensorConfigurationValue>,
              SensorConfigurationValue
            )>,
        List<
            (
              SensorConfiguration<SensorConfigurationValue>,
              SensorConfigurationValue
            )>
      )> _configureSensors() async {
    if (leftWearable is! SensorConfigurationManager) {
      throw Exception(
          "The left wearable does not support sensor configuration");
    }
    if (rightWearable is! SensorConfigurationManager) {
      throw Exception(
          "The right wearable does not support sensor configuration");
    }

    // Configure each sensor according to the global configuration
    for (var sensorConfig in experimentConfig.globalSensorConfigs) {
      final sensorName = sensorConfig.sensor.toLowerCase();

      // Get the sensor ID from the configuration
      final sensorId = experimentConfig.getSensorId(sensorName);

      setConfigProvider(
        sensorId,
        leftConfigProvider,
        _leftSensorIdToConfigMap,
        sensorConfig,
      );
      setConfigProvider(
        sensorId,
        rightConfigProvider,
        _rightSensorIdToConfigMap,
        sensorConfig,
      );
    }

    var leftSelectedCfgs = leftConfigProvider.getSelectedConfigurations();
    for (var entry in leftSelectedCfgs) {
      SensorConfiguration config = entry.$1;
      SensorConfigurationValue value = entry.$2;
      config.setConfiguration(value);
    }

    var rightSelectedCfgs = rightConfigProvider.getSelectedConfigurations();
    for (var entry in rightSelectedCfgs) {
      SensorConfiguration config = entry.$1;
      SensorConfigurationValue value = entry.$2;
      config.setConfiguration(value);
    }

    return (leftSelectedCfgs, rightSelectedCfgs);
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

      if (sensorId != null && _leftSensorIdToConfigMap.containsKey(sensorId)) {
        final cfg = _leftSensorIdToConfigMap[sensorId]!;
        if (cfg is ConfigurableSensorConfiguration) {
          // Remove streaming option to disable the sensor
          leftConfigProvider.removeSensorConfigurationOption(
            cfg,
            RecordSensorConfigOption(),
          );
          var value = leftConfigProvider.getSelectedConfigurationValue(cfg);
          if (value != null) {
            cfg.setConfiguration(
              value as ConfigurableSensorConfigurationValue,
            );
          }
        }
      }

      if (sensorId != null && _rightSensorIdToConfigMap.containsKey(sensorId)) {
        final cfg = _rightSensorIdToConfigMap[sensorId]!;
        if (cfg is ConfigurableSensorConfiguration) {
          // Remove streaming option to disable the sensor
          rightConfigProvider.removeSensorConfigurationOption(
            cfg,
            RecordSensorConfigOption(),
          );
          var value = rightConfigProvider.getSelectedConfigurationValue(cfg);
          if (value != null) {
            cfg.setConfiguration(
              value as ConfigurableSensorConfigurationValue,
            );
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
      // subscription?.cancel();
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
