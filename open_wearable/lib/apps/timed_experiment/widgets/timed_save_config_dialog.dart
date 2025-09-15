import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yaml/yaml.dart';

import '../model/timed_experiment_config.dart';

class TimedSaveConfigDialog extends StatefulWidget {
  final TimedExperimentConfig config;
  final Function(String) onConfigSaved;

  const TimedSaveConfigDialog({
    super.key,
    required this.config,
    required this.onConfigSaved,
  });

  @override
  State<TimedSaveConfigDialog> createState() => _TimedSaveConfigDialogState();
}

class _TimedSaveConfigDialogState extends State<TimedSaveConfigDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _saveLocationPath;
  bool _isSaving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return PlatformAlertDialog(
      title: Text("Save Timed Experiment Configuration"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Configuration name input
            PlatformTextField(
              controller: _nameController,
              hintText: "Configuration name",
              material: (_, __) => MaterialTextFieldData(
                decoration: InputDecoration(
                  labelText: "Configuration Name",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Save location picker
            Row(
              children: [
                Expanded(
                  child: Text(
                    _saveLocationPath == null 
                        ? "Default location (Documents)" 
                        : "Location: ${_saveLocationPath!.split('/').last}",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                PlatformTextButton(
                  onPressed: _pickSaveLocation,
                  child: Text("Choose"),
                ),
              ],
            ),
            
            if (_error != null) ...[
              SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        PlatformDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel"),
        ),
        PlatformDialogAction(
          onPressed: _isSaving ? null : _saveConfig,
          child: _isSaving 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text("Save"),
        ),
      ],
    );
  }

  Future<void> _pickSaveLocation() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        setState(() {
          _saveLocationPath = selectedDirectory;
        });
      }
    } catch (e) {
      print("Error picking directory: $e");
    }
  }

  Future<void> _saveConfig() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = "Please enter a configuration name";
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Determine save location
      String directoryPath;
      if (_saveLocationPath != null) {
        directoryPath = _saveLocationPath!;
      } else {
        // Default to documents directory
        final docDir = await getApplicationDocumentsDirectory();
        directoryPath = docDir.path;
      }
      
      final filename = name.endsWith('.yaml') ? name : '$name.yaml';
      final filePath = '$directoryPath/$filename';
      
      // Convert config to YAML string
      final yamlString = _configToYamlString(widget.config);
      
      // Save config file
      final file = File(filePath);
      await file.writeAsString(yamlString);
      
      // Notify parent widget
      widget.onConfigSaved(filePath);
      
      // Close dialog
      if (mounted) Navigator.of(context).pop();
      
    } catch (e) {
      print("Error saving config file: $e");
      setState(() {
        _isSaving = false;
        _error = "Error saving configuration file: ${e.toString()}";
      });
    }
  }

  String _configToYamlString(TimedExperimentConfig config) {
    final buffer = StringBuffer();
    
    buffer.writeln('# Timed Experiment Configuration');
    buffer.writeln('# OpenEarable v2 sensor ID mapping');
    buffer.writeln('sensor_id_map:');
    
    // Use the config's sensor ID map, or fall back to defaults
    final sensorMap = config.sensorIdMap.isNotEmpty 
        ? config.sensorIdMap 
        : TimedExperimentConfig.defaultSensorIdMap;
    
    for (final entry in sensorMap.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
    
    buffer.writeln();
    buffer.writeln('# Global sensor configurations - these apply to the entire session');
    buffer.writeln('global_sensor_configs:');
    
    for (final sensorConfig in config.globalSensorConfigs) {
      buffer.writeln('  - sensor: ${sensorConfig.sensor}');
      buffer.writeln('    sample_rate: ${sensorConfig.sampleRate}');
    }
    
    buffer.writeln();
    buffer.writeln('steps:');
    
    for (final step in config.steps) {
      buffer.writeln('  - name: "${step.name}"');
      buffer.writeln('    description: "${step.description}"');
      buffer.writeln('    duration: ${step.duration}');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
}
