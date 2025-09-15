import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class TimedCreateConfigDialog extends StatefulWidget {
  final Function(String) onConfigCreated;

  const TimedCreateConfigDialog({
    super.key,
    required this.onConfigCreated,
  });

  @override
  State<TimedCreateConfigDialog> createState() => _TimedCreateConfigDialogState();
}

class _TimedCreateConfigDialogState extends State<TimedCreateConfigDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _saveLocationPath;
  bool _isCreating = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return PlatformAlertDialog(
      title: Text("Create New Timed Experiment Config"),
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
          onPressed: _isCreating ? null : _createConfig,
          child: _isCreating 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text("Create"),
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

  Future<void> _createConfig() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = "Please enter a configuration name";
      });
      return;
    }

    setState(() {
      _isCreating = true;
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
      
      // Create template config file
      final file = File(filePath);
      await file.writeAsString(_templateConfig);
      
      // Notify parent widget
      widget.onConfigCreated(filePath);
      
      // Close dialog
      if (mounted) Navigator.of(context).pop();
      
    } catch (e) {
      print("Error creating config file: $e");
      setState(() {
        _isCreating = false;
        _error = "Error creating configuration file: ${e.toString()}";
      });
    }
  }

  final String _templateConfig = '''
# Timed Experiment Configuration
# OpenEarable v2 sensor ID mapping
sensor_id_map:
  imu: 0
  pressure: 1
  microphone: 2
  ppg: 4
  temperature: 6
  bone_conduction: 7

# Global sensor configurations - these apply to the entire session
global_sensor_configs:
  - sensor: pressure
    sample_rate: 200
  - sensor: temperature
    sample_rate: 64
  - sensor: ppg
    sample_rate: 4096
  - sensor: bone_conduction
    sample_rate: 6400
  - sensor: imu
    sample_rate: 800

steps:
  - name: "Preparation"
    description: "Get ready for the experiment"
    duration: 10

  - name: "Baseline"
    description: "Sit still for baseline measurement"
    duration: 30

  - name: "Activity 1"
    description: "Perform first activity"
    duration: 60

  - name: "Rest"
    description: "Rest between activities"
    duration: 30

  - name: "Activity 2"
    description: "Perform second activity"
    duration: 60

  - name: "Recovery"
    description: "Recovery period"
    duration: 30
''';
}
