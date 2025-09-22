import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/storage.dart';
import 'package:open_wearable/apps/chew_side_detection/view/page.dart';
import 'package:open_wearable/apps/chew_side_detection/view/log_files_page.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:file_picker/file_picker.dart';

class ConfigSelectionPage extends StatefulWidget {
  final Wearable leftWearable;
  final Wearable rightWearable;
  final SensorConfigurationProvider leftConfigProvider;
  final SensorConfigurationProvider rightConfigProvider;

  const ConfigSelectionPage({
    super.key,
    required this.leftWearable,
    required this.leftConfigProvider,
    required this.rightWearable,
    required this.rightConfigProvider,
  });

  @override
  State<ConfigSelectionPage> createState() => _ConfigSelectionPageState();
}

class _ConfigSelectionPageState extends State<ConfigSelectionPage> {
  // List of available configuration files
  final List<String> _builtinConfigFiles = [
    'lib/apps/chew_side_detection/assets/experiment.yaml',
    'lib/apps/chew_side_detection/assets/test.yaml',
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
      final savedConfigs = await ConfigStorage.getUserConfigs();

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
        await ConfigStorage.saveUserConfigs(existingConfigs);
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
        await ConfigStorage.addUserConfig(path);

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

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Select Experiment"),
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
                  "Experiment",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                SizedBox(height: 8),
                Text(
                  "Select a configuration to run an experiment. Sensors are activated once at the start and deactivated at the end. Step transitions are logged to CSV with timestamps.",
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
                print(_allConfigFiles);
                final configPath = _allConfigFiles[index];
                final configName = _getConfigName(configPath);
                final isBuiltin = _builtinConfigFiles.contains(configPath);

                if (isBuiltin) {
                  // Built-in configuration
                  return Card(
                    margin:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: PlatformListTile(
                      title: Text("Experiment: $configName"),
                      subtitle: Text("Built-in configuration"),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          platformPageRoute(
                            context: context,
                            builder: (context) => ExperimentPage(
                              leftWearable: widget.leftWearable,
                              leftConfigProvider: widget.leftConfigProvider,
                              rightWearable: widget.rightWearable,
                              rightConfigProvider: widget.rightConfigProvider,
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
                        await ConfigStorage.removeUserConfig(configPath);

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
                                await ConfigStorage.addUserConfig(configPath);
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
                        title: Text("Experiment: $configName"),
                        subtitle: Text("Custom configuration"),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            platformPageRoute(
                              context: context,
                              builder: (context) => ExperimentPage(
                                leftWearable: widget.leftWearable,
                                leftConfigProvider: widget.leftConfigProvider,
                                rightWearable: widget.rightWearable,
                                rightConfigProvider: widget.rightConfigProvider,
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
