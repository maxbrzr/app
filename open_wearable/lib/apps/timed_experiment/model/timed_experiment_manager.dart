import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'timed_experiment_config.dart';
import 'timed_experiment_logger.dart';

enum TimedExperimentState {
  notStarted,
  configuringSensors,
  waitingToStart,
  running,
  complete,
}

class TimedExperimentManager with ChangeNotifier {
  final TimedExperimentConfig experimentConfig;
  final Wearable wearable;
  final SensorConfigurationProvider sensorConfigProvider;
  final TimedExperimentLogger logger;

  late List<SensorConfiguration> _sensorConfigurations;
  late Map<String, SensorConfiguration> _sensorIdToConfigMap;

  int _currentStepIndex = 0;
  TimedExperimentState _state = TimedExperimentState.notStarted;
  DateTime? _sessionStartTime;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  bool _sensorsConfigured = false;
  String sessionId = _generateSessionId();

  TimedExperimentManager({
    required this.experimentConfig,
    required this.wearable,
    required this.sensorConfigProvider,
    required this.logger,
  }) {
    if (wearable is SensorConfigurationManager) {
      // Get all available sensor configurations
      _sensorConfigurations =
          (wearable as SensorConfigurationManager).sensorConfigurations;
      _sensorIdToConfigMap = {};

      // Create a mapping from sensor IDs to their configurations
      for (var configuration in _sensorConfigurations) {
        // Map the sensor ID to the configuration
        _sensorIdToConfigMap[configuration.name] = configuration;
      }
    } else {
      throw Exception("The wearable does not support sensor configuration");
    }
  }

  dynamic get currentStep =>
      experimentConfig.steps[_currentStepIndex];

  int get currentStepIndex => _currentStepIndex;

  int get totalSteps => experimentConfig.steps.length;

  TimedExperimentState get state => _state;

  int get elapsedSeconds => _elapsedSeconds;

  DateTime? get sessionStartTime => _sessionStartTime;

  double get progress {
    if (_state == TimedExperimentState.notStarted ||
        _state == TimedExperimentState.waitingToStart) {
      return 0.0;
    }
    return _elapsedSeconds / currentStep.duration;
  }

  bool get canProceedToNextStep {
    return _currentStepIndex < experimentConfig.steps.length - 1;
  }

  bool get isLastStep {
    return _currentStepIndex == experimentConfig.steps.length - 1;
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
    if (_state != TimedExperimentState.notStarted) return;

    try {
      _state = TimedExperimentState.configuringSensors;
      notifyListeners();

      var timestamp = DateFormat('yyMMdd_HH_mm').format(DateTime.now());
      await _setSensorLogFilePrefix(
        "${timestamp}_${experimentConfig.name}_${sessionId}_",
      );

      var selectedConfigurations = await _configureSensors();
      _sensorsConfigured = true;

      String configurations = selectedConfigurations
          .map(
            (entry) {
              String name = entry.$1.name;
              String frequency = entry.$2 is SensorFrequencyConfigurationValue 
                  ? "${(entry.$2 as SensorFrequencyConfigurationValue).frequencyHz}Hz"
                  : "configured";
              return "$name: $frequency";
            },
          )
          .join("; ");

      logger.startSession(configurations, sessionId);
      _sessionStartTime = DateTime.now();

      // Prepare the first step but don't start the timer yet
      _prepareCurrentStep();
    } catch (e) {
      _state = TimedExperimentState.notStarted;
      notifyListeners();
      rethrow;
    }
  }

  /// Prepare the current step (without starting the timer)
  void _prepareCurrentStep() {
    _elapsedSeconds = 0;
    _state = TimedExperimentState.waitingToStart;
    notifyListeners();
  }

  /// Start the timer for the current step (called manually by user)
  void startCurrentStepTimer() {
    if (_state != TimedExperimentState.waitingToStart) return;

    _state = TimedExperimentState.running;

    // Log step start
    logger.logStepStart(
      currentStep.name,
      currentStep.description,
      currentStep.duration,
    );

    // Start the progress timer
    _progressTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();

      if (_elapsedSeconds >= currentStep.duration) {
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

    if (canProceedToNextStep) {
      // Move to next step automatically
      _currentStepIndex++;
      _prepareCurrentStep();
    } else {
      _state = TimedExperimentState.complete;
    }

    notifyListeners();
  }

  /// Move to the next step in the experiment process
  void nextStep() {
    if (!canProceedToNextStep) return;

    _currentStepIndex++;
    _prepareCurrentStep(); // Prepare the next step but don't start timer
  }

  Future<void> _setSensorLogFilePrefix(String prefix) async {
    if (wearable is EdgeRecorderManager) {
      // Set the log file prefix for the wearable
      await (wearable as EdgeRecorderManager).setFilePrefix(prefix);
    } else {
      throw Exception(
          "The wearable does not support setting a log file prefix");
    }
  }

  /// Configure sensors based on global configuration
  Future<List<(SensorConfiguration<SensorConfigurationValue>, SensorConfigurationValue)>> _configureSensors() async {
    if ((wearable is! SensorConfigurationManager)) {
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
          List<SensorConfigurationValue> values = sensorConfigProvider
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
            sensorConfigProvider.addSensorConfiguration(
                configuration, bestMatch,);
          }
        }

        if (configuration is ConfigurableSensorConfiguration) {
          if (configuration.availableOptions
              .contains(RecordSensorConfigOption())) {
            sensorConfigProvider.addSensorConfigurationOption(
              configuration,
              RecordSensorConfigOption(),
            );
          }
        }
      }
    }

    var selectedConfigurations = sensorConfigProvider.getSelectedConfigurations();
    for (var entry in selectedConfigurations) {
      SensorConfiguration config = entry.$1;
      SensorConfigurationValue value = entry.$2;
      config.setConfiguration(value);
    }

    return selectedConfigurations;
  }

  /// Deactivate all configured sensors
  Future<void> _deactivateSensors() async {
    if ((wearable is! SensorConfigurationManager)) return;

    // Deactivate each configured sensor by removing their options
    for (var sensorConfig in experimentConfig.globalSensorConfigs) {
      final sensorName = sensorConfig.sensor.toLowerCase();
      final sensorId = experimentConfig.getSensorId(sensorName);

      if (sensorId != null && _sensorIdToConfigMap.containsKey(sensorId)) {
        final configuration = _sensorIdToConfigMap[sensorId]!;
        if (configuration is ConfigurableSensorConfiguration) {
          // Remove streaming option to disable the sensor
          sensorConfigProvider.removeSensorConfigurationOption(
            configuration,
            RecordSensorConfigOption(),
          );
          var value =
              sensorConfigProvider.getSelectedConfigurationValue(configuration);
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
    if (_state == TimedExperimentState.running) {
      _progressTimer?.cancel();
      _progressTimer = null;
      _elapsedSeconds = 0;

      logger.discardLastStep();

      // Return to waiting state
      _state = TimedExperimentState.waitingToStart;
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
    if (_sessionStartTime != null) {
      await logger.finalizeSession();
    }

    _state = TimedExperimentState.notStarted;
    _currentStepIndex = 0;
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

class SideDetectionExperimentManager extends TimedExperimentManager {
  int _currentBlockIndex = 0;
  final TextEditingController _experimentIdController = TextEditingController();
  late String experimentID;

  SideDetectionExperimentManager({
    required ChewingSideDetectionConfig super.experimentConfig,
    required super.wearable,
    required super.sensorConfigProvider,
    required super.logger,
  });

  TextEditingController get experimentIdController => _experimentIdController;

  @override
  int get totalSteps {
    final blocks = (experimentConfig as ChewingSideDetectionConfig).blocks;
    return blocks.map((block) => block.steps.length).fold(0, (a, b) => a + b);
  }

  @override
  dynamic get currentStep {
    final block = (experimentConfig as ChewingSideDetectionConfig).blocks[_currentBlockIndex];
    return block.steps[_currentStepIndex];
  }

  @override
  bool get isLastStep {
    final blocks = (experimentConfig as ChewingSideDetectionConfig).blocks;
    return (currentBlock.number == blocks.length - 1) && isLastBlockStep;
  }

  bool get isLastBlockStep {
    if (currentBlock.steps.isEmpty) return true;
    return currentStepIndex == currentBlock.steps.length - 1;
  }

  ChewingSideDetectionExperimentBlock get currentBlock {
    return (experimentConfig as ChewingSideDetectionConfig).blocks[_currentBlockIndex];
  }

  bool get hasCurrentStepTimer {
    if (currentBlock.steps.isEmpty) return false;
    return currentStep.containsKey("duration");
  }

  int get overallStepIndex {
    final blocks = (experimentConfig as ChewingSideDetectionConfig).blocks;
    int index = _currentStepIndex;
    for (var i = 0; i < _currentBlockIndex; i++) {
      index += blocks[i].steps.length;
    }
    return index;
  }

  void nextStep() {
    _elapsedSeconds = 0;
    _state = TimedExperimentState.waitingToStart;
    if (currentBlock.number == 0) {
      experimentID = _experimentIdController.text;
    }
    if (isLastStep) {
      finish();
      return;
    }
    if (isLastBlockStep) {
      nextBlock();
      return;
    } 

    _currentStepIndex++;
    notifyListeners();
  }

  void finish() {
    // Add functionality to finalize the experiment
    _state = TimedExperimentState.notStarted;
    // reset everything
    _currentStepIndex = 0;
    _currentBlockIndex = 0;
    _elapsedSeconds = 0;
    notifyListeners();
    return;
  }

  void nextBlock() {
    _currentBlockIndex++;
    _currentStepIndex = 0;
    notifyListeners();
  }

  @override
  /// Start the timer for the current step (called manually by user)
  void startCurrentStepTimer() {
    if (_state != TimedExperimentState.waitingToStart) return;

    _state = TimedExperimentState.running;

    /// Log step start

    // Start the progress timer
    _progressTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();

      if (_elapsedSeconds >= currentStep["duration"]) {
        _completeCurrentStep();
      }
    });

    notifyListeners();
  }

  @override
  void _completeCurrentStep() {
    _progressTimer?.cancel();
    _progressTimer = null;
    nextStep();
  }

  @override
  double get progress {
    if (_state == TimedExperimentState.notStarted ||
        _state == TimedExperimentState.waitingToStart) {
      return 0.0;
    }
    return _elapsedSeconds / currentStep["duration"];
  }

  /// Stop the experiment completely
  @override
  Future<void> stop() async {
    _progressTimer?.cancel();
    _progressTimer = null;

    if (_sensorsConfigured) {
      await _deactivateSensors();
      _sensorsConfigured = false;
    }

    // // Finalize the session logging if we have data
    // if (_sessionStartTime != null) {
    //   await logger.finalizeSession();
    // }

    _state = TimedExperimentState.notStarted;
    _currentStepIndex = 0;
    _currentBlockIndex = 0;
    _elapsedSeconds = 0;
    _sessionStartTime = null;
    notifyListeners();
  }
}
