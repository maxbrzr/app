import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/timed_experiment/widgets/log_files_page.dart';
import 'package:open_wearable/apps/timed_experiment/widgets/timed_experiment_page.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'timed_create_config_dialog.dart';
import '../model/timed_config_storage.dart';

class TimedConfigSelectionPage extends StatefulWidget {
  final Wearable wearable;
  final SensorConfigurationProvider sensorConfigProvider;

  const TimedConfigSelectionPage({
    super.key,
    required this.wearable,
    required this.sensorConfigProvider,
  });

  @override
  State<TimedConfigSelectionPage> createState() =>
      _TimedConfigSelectionPageState();
}

class _TimedConfigSelectionPageState extends State<TimedConfigSelectionPage> {
  // List of available configuration files
  final List<String> _builtinConfigFiles = [
    'lib/apps/timed_experiment/assets/sample_timed_experiment.yaml',
    'lib/apps/timed_experiment/assets/auth_final.yaml',
  ];

  // List of user-loaded configuration files
  List<String> _userConfigFiles = [];

  @override
  void initState() {
    super.initState();
    _loadUserConfigurations();
  }

  // Load user configurations from persistent storage
  Future<void> _loadUserConfigurations() async {
    try {
      final savedConfigs = await TimedConfigStorage.getUserConfigs();

      // Filter out configs that no longer exist
      final existingConfigs = <String>[];
      for (final path in savedConfigs) {
        if (path.startsWith('lib/') ||
            path.startsWith('assets/') ||
            await File(path).exists()) {
          existingConfigs.add(path);
        }
      }

      // Save the filtered list back to storage (remove invalid entries)
      if (existingConfigs.length != savedConfigs.length) {
        await TimedConfigStorage.saveUserConfigs(existingConfigs);
      }

      setState(() {
        _userConfigFiles = existingConfigs;
      });
    } catch (e) {
      print('Error loading configurations: $e');
    }
  }

  // Method to pick a YAML file from device storage
  Future<void> _pickConfigFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        // allowedExtensions: ['yaml', 'yml'],
      );

      if (result != null) {
        final path = result.files.single.path!;

        setState(() {
          _userConfigFiles.add(path);
        });

        // Save to persistent storage
        await TimedConfigStorage.addUserConfig(path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configuration file added successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error picking file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding configuration file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Get a list of all config files (built-in and user loaded)
  List<String> get _allConfigFiles =>
      [..._builtinConfigFiles, ..._userConfigFiles];

  // Get just the filename from a path for display
  String _getConfigName(String path) {
    return path.split('/').last.replaceAll('.yaml', '').replaceAll('.yml', '');
  }

  // Show dialog to create a new config file
  void _showCreateConfigDialog() {
    showPlatformDialog(
      context: context,
      builder: (BuildContext context) {
        return TimedCreateConfigDialog(
          onConfigCreated: (String path) async {
            setState(() {
              _userConfigFiles.add(path);
            });

            try {
              await TimedConfigStorage.addUserConfig(path);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Configuration created successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            } catch (e) {
              print("Error saving configuration reference: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Error saving configuration reference: ${e.toString()}'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Select Timed Experiment"),
        trailingActions: [
          PlatformPopupMenu(
            options: [
              PopupMenuOption(
                label: 'Load Config File',
                onTap: (_) => _pickConfigFile(),
              ),
            ],
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.0),
            margin: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Timed Experiment",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                SizedBox(height: 8),
                Text(
                  "Select a configuration to run a timed experiment. Sensors are activated once at the start and deactivated at the end. Step transitions are logged to CSV with timestamps.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),

          PlatformElevatedButton(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Experiment Logs",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 8),
                Icon(Icons.folder),
              ],
            ),
            onPressed: () {
              Navigator.of(context).push(
                platformPageRoute(
                  context: context,
                  builder: (context) => LogFilesPage(),
                ),
              );
            },
          ),

          // Configuration list
          Expanded(
            child: ListView.builder(
              itemCount: _allConfigFiles.length,
              itemBuilder: (context, index) {
                final configPath = _allConfigFiles[index];
                final configName = _getConfigName(configPath);
                final isBuiltin = _builtinConfigFiles.contains(configPath);

                if (isBuiltin) {
                  // Built-in configuration
                  return Card(
                    margin:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: PlatformListTile(
                      title: Text("Timed Experiment: $configName"),
                      subtitle: Text("Built-in configuration"),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          platformPageRoute(
                            context: context,
                            builder: (context) => TimedExperimentPage(
                              wearable: widget.wearable,
                              sensorConfigProvider: widget.sensorConfigProvider,
                              configPath: configPath,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  // User-loaded configuration with delete option
                  return Dismissible(
                    key: Key(configPath),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20.0),
                      color: Colors.red,
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) async {
                      try {
                        // Remove from local state
                        setState(() {
                          _userConfigFiles.remove(configPath);
                        });

                        // Remove from persistent storage
                        await TimedConfigStorage.removeUserConfig(configPath);

                        // Show undo snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Configuration removed'),
                            action: SnackBarAction(
                              label: 'UNDO',
                              onPressed: () async {
                                // Add it back
                                setState(() {
                                  _userConfigFiles.add(configPath);
                                });
                                await TimedConfigStorage.addUserConfig(
                                    configPath);
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        print("Error removing configuration: $e");
                      }
                    },
                    child: Card(
                      margin:
                          EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: PlatformListTile(
                        title: Text("Timed Experiment: $configName"),
                        subtitle: Text("Custom configuration"),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            platformPageRoute(
                              context: context,
                              builder: (context) => TimedExperimentPage(
                                wearable: widget.wearable,
                                sensorConfigProvider:
                                    widget.sensorConfigProvider,
                                configPath: configPath,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
