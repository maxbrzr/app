import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/controller.dart';
import 'package:open_wearable/apps/chew_side_detection/view/page.dart';
import 'package:provider/provider.dart';

class ExperimentView extends StatelessWidget {
  const ExperimentView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ExperimentController>(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.state == ExperimentState.experimentNotStarted) ...[
              _buildSensorConfigs(context, controller),
              _buildStepsList(context, controller),
            ] else ...[
              _buildStepProgressIndicator(controller),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Block Instruction",
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.currentBlock.instruction,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        if (controller.currentBlock.tasks.isNotEmpty) ...[
                          Text(
                            "Task Instruction",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            controller.currentTask!.name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (controller.currentBlock.tasks.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildTimerDisplay(context, controller) ?? Container(),
              ],
            ],
            _buildControlButtons(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProgressIndicator(ExperimentController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Block ${controller.currentBlockIndex + 1} of ${controller.totalNumBlocks}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        LinearProgressIndicator(
          value:
              (controller.currentBlockIndex + 1) / (controller.totalNumBlocks),
          backgroundColor: Colors.grey[300],
        ),
        controller.totalNumBlockTasks == 0
            ? Container()
            : Text(
                "Task ${controller.currentBlockTaskIndex + 1} of ${controller.totalNumBlockTasks}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
        SizedBox(height: 8),
        controller.totalNumBlockTasks == 0
            ? Container()
            : LinearProgressIndicator(
                value: (controller.currentBlockTaskIndex + 1) /
                    (controller.totalNumBlockTasks),
                backgroundColor: Colors.grey[300],
              ),
      ],
    );
  }

  Widget _buildStepsList(
    BuildContext context,
    ExperimentController controller,
  ) {
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
            for (var block in controller.expConfig.blocks) ...[
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

  Widget? _buildTimerDisplay(
    BuildContext context,
    ExperimentController controller,
  ) {
    final task = controller.currentTask;
    if (task == null) return null; // Nothing to show if no task

    final minutes = controller.elapsedSeconds ~/ 60;
    final seconds = controller.elapsedSeconds % 60;
    final totalMinutes = task.duration ~/ 60;
    final totalSeconds = task.duration % 60;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0), // same as instructions card
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// Current time
              Text(
                "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              /// Total time
              Text(
                "of ${totalMinutes.toString().padLeft(2, '0')}:${totalSeconds.toString().padLeft(2, '0')}",
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              /// Progress bar
              LinearProgressIndicator(
                value: controller.progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[300],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorConfigs(
    BuildContext context,
    ExperimentController controller,
  ) {
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
            ...controller.expConfig.globalSensorConfigs.map(
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
    BuildContext context,
    ExperimentController controller,
  ) {
    switch (controller.state) {
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
      case ExperimentState.experimentNotStarted:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlatformTextField(
              controller: controller.expIdController,
              hintText: "Enter experiment ID",
            ),
            const SizedBox(height: 16),
            PlatformElevatedButton(
              onPressed: () {
                final experimentId = controller.expIdController.text.trim();
                if (experimentId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter the experiment ID."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                controller.startExperiment();
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
              Text("Configuring sensors"),
            ],
          ),
        );

      case ExperimentState.taskWaiting:
        if (controller.currentTask != null) {
          return SizedBox(
            width: double.infinity,
            child: PlatformElevatedButton(
              onPressed: () => controller.nextStep(),
              padding: buttonPadding,
              child: Text(
                controller.isLastBlock && controller.isLastBlockStep
                    ? "Finish Experiment"
                    : controller.isLastBlockStep
                        ? "Next Block"
                        : "Next Task",
                style: buttonTextStyle,
              ),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: () => controller.startTaskTimer(),
            padding: buttonPadding,
            child: Text(
              "Start Timer",
              style: buttonTextStyle,
            ),
          ),
        );

      case ExperimentState.reapplyingWearables:
        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: () => controller.reappliedWearables(),
            padding: buttonPadding,
            child: Text(
              "Reapplied Wearables",
              style: buttonTextStyle,
            ),
          ),
        );

      case ExperimentState.taskRunning:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: PlatformElevatedButton(
                    onPressed: () => controller.resetCurrentStepTimer(),
                    padding: buttonPadding,
                    child: Text(
                      "Reset Task",
                      style: buttonTextStyle,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 40),
            if ([2, 3, 4].contains(controller.currentBlock.number))
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 72,
                      child: PlatformElevatedButton(
                        /// Insert logging of "swallowing"
                        padding: buttonPadding,
                        onPressed: () => controller.swallowed(),
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
                        onPressed: () => controller.newPieceOfFood(),
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

      case ExperimentState.taskComplete:
        if (controller.currentTask != null) {
          return SizedBox(
            width: double.infinity,
            child: PlatformElevatedButton(
              onPressed: () => controller.nextStep(),
              padding: buttonPadding,
              child: Text(
                controller.isLastBlock && controller.isLastBlockStep
                    ? "Finish Experiment"
                    : controller.isLastBlockStep
                        ? "Next Block"
                        : "Next Task",
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
                onPressed: () => controller.nextStep(),
                padding: buttonPadding,
                child: Text(
                  controller.isLastBlock && controller.isLastBlockStep
                      ? "Finish Experiment"
                      : controller.isLastBlockStep
                          ? "Next Block"
                          : "Next Task",
                  style: buttonTextStyle,
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PlatformElevatedButton(
                onPressed: () => controller.resetCurrentStepTimer(),
                padding: buttonPadding,
                child: Text(
                  "Repeat Task",
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
                onPressed: () => controller.nextStep(),
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
}
