import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_wearable/apps/chew_side_detection/model/block.dart';
import 'package:yaml/yaml.dart';

/// Represents a sensor configuration for the chewing experiment
class SensorConfig {
  final String sensor;
  final double sampleRate;

  SensorConfig({
    required this.sensor,
    required this.sampleRate,
  });

  factory SensorConfig.fromYaml(YamlMap map) {
    final dynamic rawSampleRate = map['sample_rate'];
    double sampleRate;

    if (rawSampleRate is int) {
      sampleRate = rawSampleRate.toDouble();
    } else if (rawSampleRate is double) {
      sampleRate = rawSampleRate;
    } else {
      throw Exception('Invalid sample_rate format: must be a number');
    }

    return SensorConfig(
      sensor: map['sensor'] as String,
      sampleRate: sampleRate,
    );
  }
}

/// Represents a chewing side detection experiment configuration
class ExperimentConfig {
  final List<ExperimentBlock> blocks;
  final Map<String, String> sensorIdMap;
  final List<SensorConfig> globalSensorConfigs;
  String name = "experiment";

  ExperimentConfig({
    required this.blocks,
    required this.sensorIdMap,
    required this.globalSensorConfigs,
  });

  /// Default sensor ID mapping for OpenEarable v2
  static const Map<String, String> defaultSensorIdMap = {
    'imu': "9-Axis IMU",
    'ppg': "Pulse Oximeter",
    'temperature': "Skin Temperature Sensor",
    'pressure': "Ear Canal Pressure Sensor",
    'bone_conduction': "Bone Conduction Accelerometer",
    'microphone': "Microphones",
  };

  /// Get the sensor ID for a given sensor name
  String? getSensorId(String sensorName) {
    final normalizedName = sensorName.toLowerCase();
    return sensorIdMap[normalizedName] ?? defaultSensorIdMap[normalizedName];
  }

  factory ExperimentConfig.fromYaml(YamlMap map) {
    // Parse blocks
    final blockList = map['blocks'] as YamlList;
    final blocks = blockList
        .map((block) => ExperimentBlock.fromYaml(block as YamlMap))
        .toList();

    // Parse sensor ID mapping if it exists
    Map<String, String> sensorIdMap = {};
    if (map.containsKey('sensor_id_map')) {
      final sensorIdMapYaml = map['sensor_id_map'] as YamlMap;
      sensorIdMap = sensorIdMapYaml
          .map((key, value) => MapEntry(key as String, value as String));
    }

    // Parse global sensor configurations if they exist
    List<SensorConfig> globalSensorConfigs = [];
    if (map.containsKey('global_sensor_configs')) {
      final globalConfigsList = map['global_sensor_configs'] as YamlList;
      globalSensorConfigs = globalConfigsList
          .map((config) => SensorConfig.fromYaml(config as YamlMap))
          .toList();
    }

    return ExperimentConfig(
      blocks: blocks,
      sensorIdMap: sensorIdMap,
      globalSensorConfigs: globalSensorConfigs,
    );
  }

  /// Loads a configuration from a file path
  static Future<ExperimentConfig> fromFile(String path) async {
    String yamlString;

    // Check if the path is an asset or a file
    if (path.startsWith('lib/') || path.startsWith('assets/')) {
      yamlString = await rootBundle.loadString(path);
    } else {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Configuration file not found: $path');
      }
      yamlString = await file.readAsString();
    }

    final yamlMap = loadYaml(yamlString) as YamlMap;
    final config = ExperimentConfig.fromYaml(yamlMap);
    config.name = _generateNameFromConfigFile(path);
    return config;
  }

  /// Generate a configuration name based on the configuration file path
  static String _generateNameFromConfigFile(String configPath) {
    String name;

    if (configPath.contains('/')) {
      name = configPath.split('/').last;
    } else {
      name = configPath;
    }

    if (name.contains('.')) {
      name = name.substring(0, name.lastIndexOf('.'));
    }

    return name.replaceAll(RegExp(r'[^\w\-_]'), '_');
  }
}
