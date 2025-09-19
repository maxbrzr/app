import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/chew_side_detection/model/manager.dart';
import 'package:open_wearable/apps/chew_side_detection/widgets/page.dart';
import 'package:provider/provider.dart';

class ExperimentView extends StatelessWidget {
  const ExperimentView({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<ExperimentManager>(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (manager.state == ExperimentState.notStarted) ...[
              _buildSensorConfigs(context, manager),
              _buildStepsList(context, manager),
            ] else ...[
              _buildStepProgressIndicator(manager),
              // if (manager.currentBlock.number == 0) ...[
              //   SizedBox(height: 12),
              //   PlatformTextField(
              //     controller: manager.experimentIdController,
              //     hintText: "Enter experiment ID",
              //   ),
              // ],
              SizedBox(height: 24),
              if (manager.currentBlock.tasks.isEmpty)
                Text(
                  manager.currentBlock.instruction,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              if (manager.currentBlock.tasks.isNotEmpty) ...[
                Text(
                  "${manager.currentBlock.instruction}${manager.currentTask?.name != null ? ' for ${manager.currentTask!.name}' : ''}",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                _buildTimerDisplay(context, manager) ?? Container(),
              ],
            ],
            _buildControlButtons(context, manager),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProgressIndicator(ExperimentManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Step ${manager.currentTaskIndex + 1} of ${manager.totalNumTasks}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        LinearProgressIndicator(
          value: (manager.currentTaskIndex + 1) / manager.totalNumTasks,
          backgroundColor: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildStepsList(BuildContext context, ExperimentManager manager) {
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
            for (var block in manager.experimentConfig.blocks) ...[
              Text(
                "Block ${block.number} - ${block.instruction}",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              for (var entry in block.tasks.asMap().entries) ...[
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
                            entry.value.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: entry.key == 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                          Text(
                            '${entry.value.duration ~/ 60}:${(entry.value.duration % 60).toString().padLeft(2, '0')}',
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
              ],
              SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildTimerDisplay(BuildContext context, ExperimentManager manager) {
    final task = manager.currentTask;
    if (task == null) return null; // Nothing to show if no task

    final minutes = manager.elapsedSeconds ~/ 60;
    final seconds = manager.elapsedSeconds % 60;
    final totalMinutes = task.duration ~/ 60;
    final totalSeconds = task.duration % 60;

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

  Widget _buildSensorConfigs(BuildContext context, ExperimentManager manager) {
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

  Widget _buildControlButtons(BuildContext context, ExperimentManager manager) {
    switch (manager.state) {
      // case ExperimentState.notStarted:
      //   return SizedBox(
      //     width: double.infinity,
      //     child: PlatformElevatedButton(
      //       onPressed: () => manager.startExperiment(),
      //       padding: buttonPadding,
      //       child: Text(
      //         "Start Experiment",
      //         style: buttonTextStyle,
      //       ),
      //     ),
      //   );
      case ExperimentState.notStarted:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlatformTextField(
              controller: manager.experimentIdController,
              hintText: "Enter experiment ID",
            ),
            const SizedBox(height: 16),
            PlatformElevatedButton(
              onPressed: () {
                final experimentId = manager.experimentIdController.text.trim();
                if (experimentId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter an experiment ID"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                manager.startExperiment();
              },
              padding: buttonPadding,
              child: Text(
                "Start Experiment",
                style: buttonTextStyle,
              ),
            ),
          ],
        );

      case ExperimentState.configuringSensors:
        return Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Configuring sensors..."),
            ],
          ),
        );

      case ExperimentState.waitingToStart:
        print(!manager.hasCurrentStepTimer);
        if (!manager.hasCurrentStepTimer) {
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

      case ExperimentState.running:
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
                        onPressed: () => manager.swallowed(),
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
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 72,
                      child: PlatformElevatedButton(
                        /// Insert logging of "new piece"
                        onPressed: () => manager.newPieceOfFood(),
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

      case ExperimentState.stepComplete:
        if (!manager.hasCurrentStepTimer) {
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

      case ExperimentState.experimentComplete:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: PlatformElevatedButton(
                padding: buttonPadding,
                onPressed: () => manager.nextStep(),
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

  Widget _buildSessionInfo(BuildContext context, ExperimentManager manager) {
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
                "Current Step: ${manager.currentTaskIndex + 1}/${manager.totalNumTasks}"),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionIdInfo(BuildContext context, ExperimentManager manager) {
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

  Widget _buildCsvFileInfo(BuildContext context, ExperimentManager manager) {
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
      BuildContext context, ExperimentManager manager) async {
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
