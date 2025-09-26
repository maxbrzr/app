import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/controller.dart';
import 'package:provider/provider.dart';

/// Consistent spacing
const gapS = SizedBox(height: 8);
const gapM = SizedBox(height: 16);
const gapL = SizedBox(height: 24);
const height = 48.0;

class ExperimentView extends StatelessWidget {
  const ExperimentView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ExperimentController>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.state == ExperimentState.experimentNotStarted) ...[
                _SensorConfigCard(controller: controller),
                gapM,
                _StepsList(controller: controller),
              ] else ...[
                _StepProgress(controller: controller),
                gapM,
                _InstructionCard(controller: controller),
                if (controller.currentBlock.tasks.isNotEmpty) gapM,
                if (controller.currentBlock.tasks.isNotEmpty)
                  _TimerCard(controller: controller),
              ],
              gapL,
              _ControlSection(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- Shared building blocks -----------------

class _AppCard extends StatelessWidget {
  final Widget child;
  const _AppCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final ExperimentController controller;
  const _StepProgress({required this.controller});

  @override
  Widget build(BuildContext context) {
    final totalBlocks =
        controller.totalNumBlocks == 0 ? 1 : controller.totalNumBlocks;
    final totalTasks =
        controller.totalNumBlockTasks == 0 ? 1 : controller.totalNumBlockTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Block ${controller.currentBlockIndex + 1} of ${controller.totalNumBlocks}",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        gapS,
        LinearProgressIndicator(
          value: (controller.currentBlockIndex + 1) / totalBlocks,
        ),
        if (controller.totalNumBlockTasks > 0) ...[
          gapM,
          Text(
            "Task ${controller.currentBlockTaskIndex + 1} of ${controller.totalNumBlockTasks}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          gapS,
          LinearProgressIndicator(
            value: (controller.currentBlockTaskIndex + 1) / totalTasks,
          ),
        ],
      ],
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final ExperimentController controller;
  const _InstructionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Block Instruction",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          gapS,
          Text(
            controller.currentBlock.instruction,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (controller.currentBlock.tasks.isNotEmpty) ...[
            gapM,
            Text(
              "Task Instruction",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            gapS,
            Text(
              controller.currentTask?.name ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  final ExperimentController controller;
  const _TimerCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final task = controller.currentTask;
    if (task == null) return const SizedBox.shrink();

    // Remaining time
    final remainingSeconds =
        (task.duration - controller.elapsedSeconds).clamp(0, task.duration);
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return _AppCard(
      child: Center(
        child: Text(
          "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _StepsList extends StatelessWidget {
  final ExperimentController controller;
  const _StepsList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Experiment Blocks",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          gapM,
          for (var block in controller.expConfig.blocks) ...[
            Text(
              "Block ${block.number} - ${block.instruction}",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (var entry in block.tasks.asMap().entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: entry.key == 0
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300],
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              entry.key == 0 ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            gapM,
          ],
        ],
      ),
    );
  }
}

class _SensorConfigCard extends StatelessWidget {
  final ExperimentController controller;
  const _SensorConfigCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sensor Configurations",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          gapS,
          ...controller.expConfig.globalSensorConfigs.map(
            (config) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${config.sensor}: ${config.sampleRate} Hz'),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Control Buttons -----------------

class _ControlSection extends StatelessWidget {
  final ExperimentController controller;
  const _ControlSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    switch (controller.state) {
      case ExperimentState.experimentNotStarted:
        return Container();

      case ExperimentState.configuringSensors:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              gapS,
              Text('Configuring sensors...'),
            ],
          ),
        );

      case ExperimentState.taskWaiting:
        if (controller.currentTask != null) {
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: height,
                child: PlatformElevatedButton(
                  onPressed: controller.startTask,
                  child: const Text("Start Timer"),
                ),
              ),
              gapL,
              SizedBox(
                width: double.infinity,
                height: height,
                child: PlatformElevatedButton(
                  onPressed: controller.nextStep,
                  child: const Text("Skip Task"),
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white, // text color
                    ),
                  ),
                ),
              ),
              gapL,
              SizedBox(
                width: double.infinity,
                height: height,
                child: PlatformElevatedButton(
                  onPressed: controller.lastStep,
                  child: const Text("Last Task"),
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white, // text color
                    ),
                  ),
                ),
              ),
              gapL,
              SizedBox(
                width: double.infinity,
                height: height,
                child: PlatformElevatedButton(
                  onPressed: controller.startSync,
                  child: Text("Start Syncing"),
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white, // text color
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: height,
              child: PlatformElevatedButton(
                onPressed: controller.nextStep,
                child: Text(
                  controller.isLastBlockStep ? "Next Block" : "Next Task",
                ),
              ),
            ),
            gapL,
            SizedBox(
              width: double.infinity,
              height: height,
              child: PlatformElevatedButton(
                onPressed: controller.startSync,
                child: Text("Start Syncing"),
                material: (_, __) => MaterialElevatedButtonData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white, // text color
                  ),
                ),
              ),
            ),
          ],
        );

      case ExperimentState.soundSyncing:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: height,
              child: PlatformElevatedButton(
                onPressed: controller.endSync,
                child: const Text("End Syncing"),
                material: (_, __) => MaterialElevatedButtonData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white, // text color
                  ),
                ),
              ),
            ),
          ],
        );

      case ExperimentState.taskRunning:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: height,
              child: PlatformElevatedButton(
                onPressed: controller.resetTask,
                child: const Text("Reset Task"),
                material: (_, __) => MaterialElevatedButtonData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white, // text color
                  ),
                ),
              ),
            ),
            gapL,
            if ([2, 3, 4].contains(controller.currentBlock.number))
              Row(
                children: [
                  // Left button (Swallowed)
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: PlatformElevatedButton(
                        onPressed: controller.swallowed,
                        child: const Text("Swallowed"),
                        material: (_, __) => MaterialElevatedButtonData(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Right side (stacked buttons)
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: height,
                          width: double.infinity,
                          child: PlatformElevatedButton(
                            onPressed: controller.newPieceOfFood,
                            child: const Text(
                              "New Piece of Food",
                              textAlign: TextAlign.center,
                            ),
                            material: (_, __) => MaterialElevatedButtonData(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: height,
                          width: double.infinity,
                          child: PlatformElevatedButton(
                            onPressed: controller.bitOffPiece,
                            child: const Text(
                              "Bit Off Piece",
                              textAlign: TextAlign.center,
                            ),
                            material: (_, __) => MaterialElevatedButtonData(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );

      case ExperimentState.reapplyingWearables:
        return SizedBox(
          width: double.infinity,
          height: height,
          child: PlatformElevatedButton(
            onPressed: controller.reappliedWearables,
            child: const Text("Reapplied Wearables"),
            material: (_, __) => MaterialElevatedButtonData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white, // text color
              ),
            ),
          ),
        );

      case ExperimentState.taskComplete:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: height,
              child: PlatformElevatedButton(
                onPressed: controller.nextStep,
                child: Text(
                  controller.isLastBlockStep ? "Next Block" : "Next Task",
                ),
              ),
            ),
            gapM,
            SizedBox(
              width: double.infinity,
              height: height,
              child: PlatformElevatedButton(
                onPressed: controller.repeatTask,
                child: const Text("Repeat Task"),
                material: (_, __) => MaterialElevatedButtonData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white, // text color
                  ),
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
              height: height,
              child: PlatformElevatedButton(
                onPressed: controller.stopExperiment,
                child: const Text("Finish Experiment"),
              ),
            ),
          ],
        );
    }
  }
}
