import 'dart:io';

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// Represents a sensor configuration for the timed experiment
class TimedSensorConfig {
  final String sensor;
  final double sampleRate;

  TimedSensorConfig({
    required this.sensor,
    required this.sampleRate,
  });

  factory TimedSensorConfig.fromYaml(YamlMap map) {
    // Parse sample_rate to handle both int and double values
    final dynamic rawSampleRate = map['sample_rate'];
    double sampleRate;
    
    if (rawSampleRate is int) {
      sampleRate = rawSampleRate.toDouble();
    } else if (rawSampleRate is double) {
      sampleRate = rawSampleRate;
    } else {
      throw Exception('Invalid sample_rate format: must be a number');
    }

    return TimedSensorConfig(
      sensor: map['sensor'] as String,
      sampleRate: sampleRate,
    );
  }
}

/// Represents a step in the timed experiment process
class TimedExperimentStep {
  final String name;
  final String description;
  final int duration; // in seconds

  TimedExperimentStep({
    required this.name,
    required this.description,
    required this.duration,
  });

  factory TimedExperimentStep.fromYaml(YamlMap map) {
    return TimedExperimentStep(
      name: map['name'] as String,
      description: map['description'] as String,
      duration: map['duration'] as int,
    );
  }
}

/// Represents a complete timed experiment configuration
class TimedExperimentConfig {
  final List<TimedExperimentStep> steps;
  final Map<String, String> sensorIdMap;
  final List<TimedSensorConfig> globalSensorConfigs;
  String name = 'timed_experiment';

  TimedExperimentConfig({
    required this.steps,
    required this.sensorIdMap,
    required this.globalSensorConfigs,
  });

  /// Get the sensor ID for a given sensor name
  String? getSensorId(String sensorName) {
    final normalizedName = sensorName.toLowerCase();
    return sensorIdMap[normalizedName] ?? defaultSensorIdMap[normalizedName];
  }

  /// Default sensor ID mapping for OpenEarable v2
  static const Map<String, String> defaultSensorIdMap = {
    'imu': "9-Axis IMU",
    'ppg': "Pulse Oximeter",
    'temperature': "Skin Temperature Sensor",
    'pressure': "Ear Canal Pressure Sensor",
    'bone_conduction': "Bone Conduction Accelerometer",
    'microphone': "Microphones",
  };

  factory TimedExperimentConfig.fromYaml(YamlMap map) {
    final stepsList = map['steps'] as YamlList;
    final steps = stepsList
        .map((step) => TimedExperimentStep.fromYaml(step as YamlMap))
        .toList();

    // Parse sensor ID mapping if it exists
    Map<String, String> sensorIdMap = {};
    if (map.containsKey('sensor_id_map')) {
      final sensorIdMapYaml = map['sensor_id_map'] as YamlMap;
      sensorIdMap = sensorIdMapYaml.map((key, value) => MapEntry(key as String, value as String));
    }

    // Parse global sensor configurations if they exist
    List<TimedSensorConfig> globalSensorConfigs = [];
    if (map.containsKey('global_sensor_configs')) {
      final globalConfigsList = map['global_sensor_configs'] as YamlList;
      globalSensorConfigs = globalConfigsList
          .map((config) => TimedSensorConfig.fromYaml(config as YamlMap))
          .toList();
    }

    return TimedExperimentConfig(
      steps: steps,
      sensorIdMap: sensorIdMap,
      globalSensorConfigs: globalSensorConfigs,
    );
  }

  /// Loads a configuration from a file path
  static Future<TimedExperimentConfig> fromFile(String path) async {
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
    
    final config = await parseYamlString(yamlString);
    config.name = _generateNameFromConfigFile(path);
    return config;
  }
  
  /// Parses a YAML string into a TimedExperimentConfig
  static Future<TimedExperimentConfig> parseYamlString(String yamlString) async {
    try {
      final yamlMap = loadYaml(yamlString) as YamlMap;
      
      // Validate required structure
      if (!yamlMap.containsKey('steps')) {
        throw Exception('Configuration is missing "steps" section');
      }
      
      if ((yamlMap['steps'] is! YamlList)) {
        throw Exception('Configuration "steps" must be a list');
      }
      
      if (!yamlMap.containsKey('global_sensor_configs')) {
        throw Exception('Configuration is missing "global_sensor_configs" section');
      }
      
      if ((yamlMap['global_sensor_configs'] is! YamlList)) {
        throw Exception('Configuration "global_sensor_configs" must be a list');
      }
      
      return TimedExperimentConfig.fromYaml(yamlMap);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Invalid configuration format: ${e.toString()}');
    }
  }

  /// Generate a configuration name based on the configuration file path
  static String _generateNameFromConfigFile(String configPath) {
    String name;

    if (configPath.contains('/')) {
      name = configPath.split('/').last;
    } else {
      name = configPath;
    }

    // Remove the extension (.yaml, .yml, etc.)
    if (name.contains('.')) {
      name = name.substring(0, name.lastIndexOf('.'));
    }

    // Clean up the name to be filesystem-safe
    name = name.replaceAll(RegExp(r'[^\w\-_]'), '_');

    return name;
  }
}
