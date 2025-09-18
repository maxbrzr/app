import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../model/timed_experiment_config.dart';
import '../model/timed_experiment_manager.dart';
import '../model/timed_experiment_logger.dart';
import 'log_files_page.dart';

final EdgeInsets buttonPadding = EdgeInsets.all(16.0);
final TextStyle buttonTextStyle = TextStyle(fontSize: 18);

class TimedExperimentPage extends StatefulWidget {
  final Wearable wearable;
  final SensorConfigurationProvider sensorConfigProvider;
  final String configPath;

  const TimedExperimentPage({
    super.key,
    required this.wearable,
    required this.sensorConfigProvider,
    required this.configPath,
  });

  @override
  State<TimedExperimentPage> createState() => _TimedExperimentPageState();
}

class _TimedExperimentPageState extends State<TimedExperimentPage> {
  TimedExperimentManager? _manager;
  TimedExperimentLogger? _logger;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      // Check if the path exists for external files
      if (!widget.configPath.startsWith('lib/') &&
          !widget.configPath.startsWith('assets/')) {
        final file = File(widget.configPath);
        if (!await file.exists()) {
          throw Exception('Configuration file not found');
        }
      }

      final config = await TimedExperimentConfig.fromFile(widget.configPath);
      final TimedExperimentLogger logger = TimedExperimentLogger();
      await logger.initialize(config.name);
      // if (config is! ChewingSideDetectionConfig) {
      //   await logger.initialize(config.name);
      // }
      print(logger.runtimeType);

      setState(() {
        _logger = logger;
        if (config is ChewingSideDetectionConfig) {
          _manager = SideDetectionExperimentManager(
            experimentConfig: config,
            wearable: widget.wearable,
            sensorConfigProvider: widget.sensorConfigProvider,
            logger: logger,
          );
        } else {
          _manager = TimedExperimentManager(
            experimentConfig: config,
            wearable: widget.wearable,
            sensorConfigProvider: widget.sensorConfigProvider,
            logger: logger,
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading config: ${e.toString()}");
      setState(() {
        _errorMessage =
            "Failed to load experiment configuration: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _manager?.stop();
    _manager?.dispose();
    super.dispose();
  }

  // Share CSV data
  Future<void> _shareData() async {
    if (_logger == null) return;

    try {
      final csvFile = _logger!.csvFile;
      if (await csvFile.exists()) {
        SharePlus.instance.share(
          ShareParams(
            text: 'Timed Experiment Data',
            subject: 'Experiment Results CSV',
            files: [XFile(csvFile.path)],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No data file found to share'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return PlatformScaffold(
        appBar: PlatformAppBar(
          title: Text("Loading..."),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading experiment configuration..."),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return PlatformScaffold(
        appBar: PlatformAppBar(
          title: Text("Error"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                "Error Loading Configuration",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              SizedBox(height: 24),
              PlatformElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Stop the experiment and sensors before navigating back
        if (_manager != null) {
          await _manager!.stop();
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: PlatformScaffold(
        appBar: PlatformAppBar(
          title: Text("Timed Experiment"),
          trailingActions: [
            PlatformIconButton(
              icon: Icon(Icons.folder),
              onPressed: () {
                Navigator.of(context).push(
                  platformPageRoute(
                    context: context,
                    builder: (context) => LogFilesPage(),
                  ),
                );
              },
            ),
            PlatformIconButton(
              icon: Icon(Icons.share),
              onPressed: _shareData,
            ),
          ],
        ),
        body: ChangeNotifierProvider.value(
          value: _manager,
          child: const TimedExperimentView(),
        ),
      ),
    );
  }
}

class TimedExperimentView extends StatelessWidget {
  const TimedExperimentView({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TimedExperimentManager>(context);

    if (manager is SideDetectionExperimentManager) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (manager.state == TimedExperimentState.notStarted) ...[
                _buildSensorConfigs(context, manager),
                _buildStepsList(context, manager),
              ] else ...[
                _buildStepProgressIndicator(manager),
                if (manager.currentBlock.number == 0) ...[
                  SizedBox(height: 12),
                  PlatformTextField(
                    controller: manager.experimentIdController,
                    hintText: "Enter experiment ID",
                  ),
                ],
                SizedBox(height: 24),
                if (manager.currentBlock.steps.isEmpty)
                  Text(
                    manager.currentBlock.instruction,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                if (manager.currentBlock.steps.isNotEmpty) ...[
                  Text(
                    manager.currentStep["task"],
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (manager.currentStep.containsKey("duration"))
                    _buildTimerDisplay(context, manager),
                ],
              ],
              _buildControlButtons(context, manager),
            ],
          ),
        ),
      );
    }

    final currentStep = manager.currentStep;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (manager.state == TimedExperimentState.notStarted) ...[
              _buildCsvFileInfo(context, manager),
              _buildSensorConfigs(context, manager),
              _buildStepsList(context, manager),
              _buildSessionIdInfo(context, manager),
            ] else ...[
              _buildStepProgressIndicator(manager),
              SizedBox(height: 24),
              Text(
                currentStep.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 8),
              Text(
                currentStep.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              SizedBox(height: 24),
              _buildTimerDisplay(context, manager),
            ],
            _buildControlButtons(context, manager),
            SizedBox(height: 24),
            if (manager.sessionStartTime != null)
              _buildSessionInfo(context, manager),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProgressIndicator(TimedExperimentManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Step ${manager is SideDetectionExperimentManager ? manager.overallStepIndex : manager.currentStepIndex + 1} of ${manager.totalSteps}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        LinearProgressIndicator(
          value: (manager is SideDetectionExperimentManager
                  ? manager.overallStepIndex
                  : manager.currentStepIndex + 1) /
              manager.totalSteps,
          backgroundColor: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildStepsList(BuildContext context, TimedExperimentManager manager) {
    if (manager is SideDetectionExperimentManager) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Experiment Blocks",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 12),
              for (var block
                  in (manager.experimentConfig as ChewingSideDetectionConfig)
                      .blocks) ...[
                Text(
                  "Block ${block.number} - ${block.instruction}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                for (var entry in block.steps.asMap().entries) ...[
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.key == 0
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300],
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(
                              color: entry.key == 0
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.value["task"],
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: entry.key == 0
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                            ),
                            if (entry.value.containsKey("duration"))
                              Text(
                                '${entry.value["duration"] ~/ 60}:${(entry.value["duration"] % 60).toString().padLeft(2, '0')}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 12),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Steps",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 12),
            ...manager.experimentConfig.steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isCurrentStep = index == manager.currentStepIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrentStep
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color:
                                isCurrentStep ? Colors.white : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: isCurrentStep
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                          Text(
                            '${step.duration ~/ 60}:${(step.duration % 60).toString().padLeft(2, '0')}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(
      BuildContext context, TimedExperimentManager manager) {
    final minutes = manager.elapsedSeconds ~/ 60;
    final seconds = manager.elapsedSeconds % 60;
    int totalMinutes;
    int totalSeconds;
    if (manager is SideDetectionExperimentManager) {
      totalMinutes = manager.currentStep["duration"] ~/ 60;
      totalSeconds = manager.currentStep["duration"] % 60;
    } else {
      totalMinutes = manager.currentStep.duration ~/ 60;
      totalSeconds = manager.currentStep.duration % 60;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
            ),
            SizedBox(height: 8),
            Text(
              "of ${totalMinutes.toString().padLeft(2, '0')}:${totalSeconds.toString().padLeft(2, '0')}",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: manager.progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorConfigs(
      BuildContext context, TimedExperimentManager manager) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sensor Configurations",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            // Show effective sensor configurations (global + step overrides)
            ...manager.experimentConfig.globalSensorConfigs.map(
              (config) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Text(
                      "${config.sensor}: ${config.sampleRate} Hz",
                    ),
                    SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(
      BuildContext context, TimedExperimentManager manager) {
    switch (manager.state) {
      case TimedExperimentState.notStarted:
        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: () => manager.startExperiment(),
            padding: buttonPadding,
            child: Text(
              "Start Experiment",
              style: buttonTextStyle,
            ),
          ),
        );

      case TimedExperimentState.configuringSensors:
        return Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Configuring sensors..."),
            ],
          ),
        );

      case TimedExperimentState.waitingToStart:
        if (manager is SideDetectionExperimentManager &&
            !manager.hasCurrentStepTimer) {
          return SizedBox(
            width: double.infinity,
            child: PlatformElevatedButton(
              onPressed: () => manager.nextStep(),
              padding: buttonPadding,
              child: Text(
                manager.isLastStep
                    ? "Finish Experiment"
                    : manager.isLastBlockStep
                        ? "Next Block"
                        : "Next Step",
                style: buttonTextStyle,
              ),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: () => manager.startCurrentStepTimer(),
            padding: buttonPadding,
            child: Text(
              "Start Timer",
              style: buttonTextStyle,
            ),
          ),
        );

      case TimedExperimentState.running:
        if (manager is SideDetectionExperimentManager) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PlatformElevatedButton(
                      onPressed: () => manager.resetCurrentStepTimer(),
                      padding: buttonPadding,
                      child: Text(
                        "Reset",
                        style: buttonTextStyle,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 160),
              if ([2, 3, 4].contains(manager.currentBlock.number))
                Row(
                  children: [
                    Expanded(
                        child: SizedBox(
                      height: 72,
                      child: PlatformElevatedButton(
                        /// Insert logging of "swallowing"
                        padding: buttonPadding,
                        onPressed: () => {},
                        material: (context, platform) =>
                            MaterialElevatedButtonData(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.blue),
                            foregroundColor:
                                WidgetStateProperty.all(Colors.white),
                          ),
                        ),
                        cupertino: (context, platform) =>
                            CupertinoElevatedButtonData(
                          color: CupertinoColors.activeBlue,
                        ),
                        child: Center(
                          child: Text(
                            "Swallowed",
                            style: buttonTextStyle,
                          ),
                        ),
                      ),
                    )),
                    SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 72,
                        child: PlatformElevatedButton(
                          /// Insert logging of "new piece"
                          onPressed: () => {},
                          padding: buttonPadding,
                          material: (context, platform) =>
                              MaterialElevatedButtonData(
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.all(Colors.green),
                              foregroundColor:
                                  WidgetStateProperty.all(Colors.white),
                            ),
                          ),
                          cupertino: (context, platform) =>
                              CupertinoElevatedButtonData(
                            color: CupertinoColors.activeGreen,
                          ),
                          child: Center(
                            child: Text(
                              "New Piece of Food",
                              textAlign: TextAlign.center,
                              style: buttonTextStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: PlatformElevatedButton(
                onPressed: () => manager.resetCurrentStepTimer(),
                padding: buttonPadding,
                child: Text(
                  "Reset",
                  style: buttonTextStyle,
                ),
              ),
            ),
          ],
        );

      case TimedExperimentState.stepComplete:
        if (manager is SideDetectionExperimentManager &&
            !manager.hasCurrentStepTimer) {
          return SizedBox(
            width: double.infinity,
            child: PlatformElevatedButton(
              onPressed: () => manager.nextStep(),
              padding: buttonPadding,
              child: Text(
                manager.isLastStep
                    ? "Finish Experiment"
                    : manager.isLastBlockStep
                        ? "Next Block"
                        : "Next Step",
                style: buttonTextStyle,
              ),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: PlatformElevatedButton(
                onPressed: () => manager.nextStep(),
                padding: buttonPadding,
                child: Text(
                  manager.isLastStep ? "Finish Experiment" : "Next Step",
                  style: buttonTextStyle,
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PlatformElevatedButton(
                onPressed: () => manager.resetCurrentStepTimer(),
                padding: buttonPadding,
                child: Text(
                  "Repeat Step",
                  style: buttonTextStyle,
                ),
              ),
            ),
          ],
        );

      case TimedExperimentState.experimentComplete:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: PlatformElevatedButton(
                padding: buttonPadding,
                onPressed: () => manager.stop(),
                child: Text(
                  "Finish Experiment",
                  style: buttonTextStyle,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Experiment completed! You can finish to save data or restart.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
    }
  }

  Widget _buildSessionInfo(
      BuildContext context, TimedExperimentManager manager) {
    final sessionDuration =
        DateTime.now().difference(manager.sessionStartTime!);
    final sessionMinutes = sessionDuration.inMinutes;
    final sessionSeconds = sessionDuration.inSeconds % 60;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Session Information",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 8),
            Text("Session ID: ${manager.sessionId}"),
            Text(
                "Started: ${manager.sessionStartTime!.toString().substring(0, 19)}"),
            Text(
                "Duration: $sessionMinutes:${sessionSeconds.toString().padLeft(2, '0')}"),
            Text(
                "Current Step: ${manager.currentStepIndex + 1}/${manager.totalSteps}"),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionIdInfo(
      BuildContext context, TimedExperimentManager manager) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fingerprint,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  "Session ID",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              manager.sessionId,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 2.0,
                  ),
            ),
            SizedBox(height: 8),
            Text(
              "This random identifier will be used to track this experiment session in the logs.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCsvFileInfo(
      BuildContext context, TimedExperimentManager manager) {
    final logger = manager.logger;
    final csvFileName = logger.csvFile.path.split(Platform.pathSeparator).last;

    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  "Time Logging",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              csvFileName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            SizedBox(height: 8),
            Text(
              "All experiment step timings will be logged to this file. New sessions will be appended.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _createNewLogFile(context, manager),
                    icon: Icon(Icons.add),
                    label: Text("Create New File"),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCurrentFileInfo(context, logger),
                    icon: Icon(Icons.info_outline),
                    label: Text("File Info"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewLogFile(
      BuildContext context, TimedExperimentManager manager) async {
    try {
      final archivedFile = await manager.logger.archiveLogFile();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Moved old file to: ${archivedFile.path.split(Platform.pathSeparator).last}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating new file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showCurrentFileInfo(BuildContext context, dynamic logger) {
    final file = logger.csvFile as File;
    final fileName = file.path.split('/').last;
    final fileSize = _getFileSize(file);
    final fileDate = _getFileDate(file);

    showPlatformDialog(
      context: context,
      builder: (context) => PlatformAlertDialog(
        title: Text('Log File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $fileName', style: TextStyle(fontFamily: 'monospace')),
            SizedBox(height: 8),
            Text('Size: $fileSize'),
            Text('Modified: $fileDate'),
            SizedBox(height: 12),
            Text(
              'This file contains all session data for this experiment configuration.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          PlatformDialogAction(
            child: Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  String _getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getFileDate(File file) {
    try {
      final date = file.lastModifiedSync();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
