import 'dart:async';

import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/chew_side_detection/model/config.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';

class ExperimentManager {
  final ExperimentConfig expConfig;
  final Wearable leftWearable;
  final Wearable rightWearable;
  final SensorConfigurationProvider leftSensorCfgProvider;
  final SensorConfigurationProvider rightSensorCfgProvider;

  late List<SensorConfiguration> _leftSensorCfgs;
  late List<SensorConfiguration> _rightSensorCfgs;
  late Map<String, SensorConfiguration> _leftSensorIdToCfgMap;
  late Map<String, SensorConfiguration> _rightSensorIdToCfgMap;

  ExperimentManager({
    required this.expConfig,
    required this.leftWearable,
    required this.leftSensorCfgProvider,
    required this.rightWearable,
    required this.rightSensorCfgProvider,
  }) {
    if (leftWearable is SensorConfigurationManager) {
      _leftSensorCfgs =
          (leftWearable as SensorConfigurationManager).sensorConfigurations;
      _leftSensorIdToCfgMap = {};
      for (var cfg in _leftSensorCfgs) {
        _leftSensorIdToCfgMap[cfg.name] = cfg;
      }
    } else {
      throw Exception(
        "The left wearable does not support sensor configuration",
      );
    }
    if (rightWearable is SensorConfigurationManager) {
      _rightSensorCfgs =
          (rightWearable as SensorConfigurationManager).sensorConfigurations;
      _rightSensorIdToCfgMap = {};
      for (var configuration in _rightSensorCfgs) {
        _rightSensorIdToCfgMap[configuration.name] = configuration;
      }
    } else {
      throw Exception(
        "The right wearable does not support sensor configuration",
      );
    }
  }

  Future<void> setSensorLogFilePrefix(String prefix) async {
    if (leftWearable is! EdgeRecorderManager) {
      throw Exception(
        "The left wearable does not support setting a log file prefix",
      );
    }
    if (rightWearable is! EdgeRecorderManager) {
      throw Exception(
        "The right wearable does not support setting a log file prefix",
      );
    }
    await Future.wait([
      (leftWearable as EdgeRecorderManager).setFilePrefix("left_$prefix"),
      (rightWearable as EdgeRecorderManager).setFilePrefix("right_$prefix"),
    ]);
  }

  SensorFrequencyConfigurationValue? _findBestMatch(
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

  void _setConfigProvider(
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
        final bestMatch = _findBestMatch(values, experimentSensorConfig);

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
        // if (sensorId == "temperature" &&
        //     cfg.availableOptions.contains(StreamSensorConfigOption())) {
        //   cfgProvider.addSensorConfigurationOption(
        //     cfg,
        //     StreamSensorConfigOption(),
        //   );
        // }
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
      )> configureSensors() async {
    if (leftWearable is! SensorConfigurationManager) {
      throw Exception(
          "The left wearable does not support sensor configuration");
    }
    if (rightWearable is! SensorConfigurationManager) {
      throw Exception(
          "The right wearable does not support sensor configuration");
    }

    // Configure each sensor according to the global configuration
    for (var sensorConfig in expConfig.globalSensorConfigs) {
      final sensorName = sensorConfig.sensor.toLowerCase();

      // Get the sensor ID from the configuration
      final sensorId = expConfig.getSensorId(sensorName);

      _setConfigProvider(
        sensorId,
        leftSensorCfgProvider,
        _leftSensorIdToCfgMap,
        sensorConfig,
      );
      _setConfigProvider(
        sensorId,
        rightSensorCfgProvider,
        _rightSensorIdToCfgMap,
        sensorConfig,
      );
    }

    var leftSelectedCfgs = leftSensorCfgProvider.getSelectedConfigurations();
    for (var entry in leftSelectedCfgs) {
      SensorConfiguration config = entry.$1;
      SensorConfigurationValue value = entry.$2;
      config.setConfiguration(value);
    }

    var rightSelectedCfgs = rightSensorCfgProvider.getSelectedConfigurations();
    for (var entry in rightSelectedCfgs) {
      SensorConfiguration config = entry.$1;
      SensorConfigurationValue value = entry.$2;
      config.setConfiguration(value);
    }

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

    return (leftSelectedCfgs, rightSelectedCfgs);
  }

  /// Deactivate all configured sensors
  Future<void> deactivateSensors() async {
    if ((leftWearable is! SensorConfigurationManager ||
        rightWearable is! SensorConfigurationManager)) {
      return;
    }

    // Deactivate each configured sensor by removing their options
    for (var sensorConfig in expConfig.globalSensorConfigs) {
      final sensorName = sensorConfig.sensor.toLowerCase();
      final sensorId = expConfig.getSensorId(sensorName);

      if (sensorId != null && _leftSensorIdToCfgMap.containsKey(sensorId)) {
        final cfg = _leftSensorIdToCfgMap[sensorId]!;
        if (cfg is ConfigurableSensorConfiguration) {
          // Remove streaming option to disable the sensor
          leftSensorCfgProvider.removeSensorConfigurationOption(
            cfg,
            RecordSensorConfigOption(),
          );
          var value = leftSensorCfgProvider.getSelectedConfigurationValue(cfg);
          if (value != null) {
            cfg.setConfiguration(
              value as ConfigurableSensorConfigurationValue,
            );
          }
        }
      }

      if (sensorId != null && _rightSensorIdToCfgMap.containsKey(sensorId)) {
        final cfg = _rightSensorIdToCfgMap[sensorId]!;
        if (cfg is ConfigurableSensorConfiguration) {
          // Remove streaming option to disable the sensor
          rightSensorCfgProvider.removeSensorConfigurationOption(
            cfg,
            RecordSensorConfigOption(),
          );
          var value = rightSensorCfgProvider.getSelectedConfigurationValue(cfg);
          if (value != null) {
            cfg.setConfiguration(
              value as ConfigurableSensorConfigurationValue,
            );
          }
        }
      }
    }
  }
}
