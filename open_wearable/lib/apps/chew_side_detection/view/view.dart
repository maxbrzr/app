import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/controller.dart';
import 'package:provider/provider.dart';

/// Consistent spacing
const gapS = SizedBox(height: 8);
const gapM = SizedBox(height: 16);
const gapL = SizedBox(height: 24);

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

    final minutes = controller.elapsedSeconds ~/ 60;
    final seconds = controller.elapsedSeconds % 60;
    final totalMinutes = task.duration ~/ 60;
    final totalSeconds = task.duration % 60;

    return _AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
            textAlign: TextAlign.center,
          ),
          gapS,
          Text(
            "of ${totalMinutes.toString().padLeft(2, '0')}:${totalSeconds.toString().padLeft(2, '0')}",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          gapM,
          LinearProgressIndicator(value: controller.progress.clamp(0.0, 1.0)),
        ],
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

  bool _isConsentBlock() {
    final instr = controller.currentBlock.instruction.toLowerCase();
    return instr.contains('consent') ||
        instr.contains('consent form') ||
        instr.contains('fill out consent');
  }

  @override
  Widget build(BuildContext context) {
    switch (controller.state) {
      case ExperimentState.experimentNotStarted:
        return _startControls(context);

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
        if (_isConsentBlock()) return _consentControls(context);
        // Task exists but not started → Start Timer
        if (controller.currentTask != null) {
          return SizedBox(
            width: double.infinity,
            child: PlatformElevatedButton(
              onPressed: controller.startTaskTimer,
              child: const Text("Start Timer"),
            ),
          );
        }
        // Otherwise allow next step
        return _nextStepButton(context);

      case ExperimentState.taskRunning:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: PlatformElevatedButton(
                onPressed: controller.resetCurrentStepTimer,
                child: const Text("Reset Task"),
              ),
            ),
            gapL,
            if (!_isConsentBlock() &&
                [2, 3, 4].contains(controller.currentBlock.number))
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: PlatformElevatedButton(
                        onPressed: controller.swallowed,
                        child: const Text("Swallowed"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: PlatformElevatedButton(
                        onPressed: controller.newPieceOfFood,
                        child: const Text(
                          "New Piece of Food",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );

      case ExperimentState.reapplyingWearables:
        return SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: controller.reappliedWearables,
            child: const Text("Reapplied Wearables"),
          ),
        );

      case ExperimentState.taskComplete:
        if (_isConsentBlock()) return _consentControls(context);
        return Column(
          children: [
            _nextStepButton(context),
            gapM,
            SizedBox(
              width: double.infinity,
              child: PlatformElevatedButton(
                onPressed: controller.resetCurrentStepTimer,
                child: const Text("Repeat Task"),
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
                onPressed: controller.nextStep,
                child: const Text("Finish Experiment"),
              ),
            ),
            gapM,
            Text(
              'Experiment completed! You can finish to save data or restart.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
    }
  }

  Widget _nextStepButton(BuildContext context) {
    final label = controller.isLastBlock && controller.isLastBlockStep
        ? "Finish Experiment"
        : controller.isLastBlockStep
            ? "Next Block"
            : "Next Task";
    return SizedBox(
      width: double.infinity,
      child: PlatformElevatedButton(
        onPressed: controller.nextStep,
        child: Text(label),
      ),
    );
  }

  Widget _startControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlatformTextField(
          controller: controller.expIdController,
          hintText: "Enter experiment ID",
        ),
        gapM,
        PlatformElevatedButton(
          onPressed: () {
            final id = controller.expIdController.text.trim();
            if (id.isEmpty) {
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
          child: const Text("Start Experiment"),
        ),
      ],
    );
  }

  Widget _consentControls(BuildContext context) {
    final label = controller.isLastBlock && controller.isLastBlockStep
        ? "Finish Experiment"
        : controller.isLastBlockStep
            ? "Next Block"
            : "Continue";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        gapM,
        SizedBox(
          width: double.infinity,
          child: PlatformElevatedButton(
            onPressed: controller.nextStep,
            child: Text(label),
          ),
        ),
      ],
    );
  }
}
