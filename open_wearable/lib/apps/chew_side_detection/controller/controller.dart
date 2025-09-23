import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/manager.dart';
import 'package:open_wearable/apps/chew_side_detection/model/block.dart';
import 'package:open_wearable/apps/chew_side_detection/model/config.dart';
import 'logger.dart';

enum ExperimentState {
  experimentNotStarted,
  configuringSensors,
  reapplyingWearables,
  taskWaiting,
  taskRunning,
  taskComplete,
  experimentComplete,
}

class ExperimentController with ChangeNotifier {
  final ExperimentConfig expConfig;
  final ExperimentManager manager;
  final ExperimentLogger logger;
  late String experimentId;

  // State
  final TextEditingController _expIdController = TextEditingController();
  int _currentBlockIndex = 0;
  int _currentBlockTaskIndex = 0;
  int _currentTaskIndex = 0;
  ExperimentState _state = ExperimentState.experimentNotStarted;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  bool _sensorsConfigured = false;

  ExperimentController({
    required this.expConfig,
    required this.manager,
    required this.logger,
  });

  // Indices
  int get currentBlockIndex => _currentBlockIndex;
  int get currentBlockTaskIndex => _currentBlockTaskIndex;

  // Objects
  ExperimentBlock get currentBlock => expConfig.blocks[_currentBlockIndex];
  Task? get currentTask {
    final block = expConfig.blocks[_currentBlockIndex];
    if (block.tasks.isEmpty) return null;
    return block.tasks[_currentBlockTaskIndex];
  }

  // Counts
  int get totalNumBlocks => expConfig.blocks.fold(0, (sum, block) => sum + 1);
  int get totalNumBlockTasks => currentBlock.tasks.length;

  // Last
  bool get isLastBlock => _currentBlockIndex == expConfig.blocks.length - 1;
  bool get isLastBlockStep {
    if (currentBlock.tasks.isEmpty) return true;
    return _currentBlockTaskIndex == currentBlock.tasks.length - 1;
  }

  // State
  ExperimentState get state => _state;

  // Timer
  int get elapsedSeconds => _elapsedSeconds;
  double get progress {
    if (currentTask == null ||
        _state == ExperimentState.experimentNotStarted ||
        _state == ExperimentState.taskWaiting) {
      return 0.0;
    }

    // Prevent division by zero
    final duration = currentTask!.duration;
    if (duration == 0) return 0.0;

    // Calculate progress
    return _elapsedSeconds / duration;
  }

  // Experiment ID
  TextEditingController get expIdController => _expIdController;

  /// Start the experiment session
  Future<void> startExperiment() async {
    if (_state != ExperimentState.experimentNotStarted) return;

    try {
      _state = ExperimentState.configuringSensors;
      notifyListeners();

      // Get experiment ID from text field
      experimentId = _expIdController.text.trim();

      // Set sensor log file prefix
      await manager.setSensorLogFilePrefix(
        "${experimentId}_${DateFormat('yyMMdd_HH_mm').format(DateTime.now())}_",
      );

      await Future.wait([
        logger.initialize(experimentId),
        manager.configureSensors(),
      ]);

      _sensorsConfigured = true;

      logger.startLogging();

      _prepareTask();
    } catch (e) {
      _state = ExperimentState.experimentNotStarted;
      notifyListeners();
      rethrow;
    }
  }

  void swallowed() {
    logger.logOtherEvent(
      currentBlock.number,
      currentBlock.instruction,
      currentTask!.id,
      "swallowed",
    );
  }

  void newPieceOfFood() {
    logger.logOtherEvent(
      currentBlock.number,
      currentBlock.instruction,
      currentTask!.id,
      "newPieceOfFood",
    );
  }

  void bitOffPiece() {
    logger.logOtherEvent(
      currentBlock.number,
      currentBlock.instruction,
      currentTask!.id,
      "bitOffPiece",
    );
  }

  /// Start the timer for the current step (called manually by user)
  Future<void> startTaskTimer() async {
    if (_state != ExperimentState.taskWaiting) return;
    // If there's no task, do nothing
    final task = currentTask;
    if (task == null) return;

    _state = ExperimentState.taskRunning;

    // Log step start
    logger.logTaskStart(
      currentBlock.number,
      currentBlock.instruction,
      task.id,
      task.duration,
    );

    // Start the progress timer
    _progressTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();

      if (_elapsedSeconds >= task.duration) {
        _completeTask();
      }
    });

    notifyListeners();
  }

  /// Complete the current step
  Future<void> _completeTask() async {
    _progressTimer?.cancel();
    _progressTimer = null;

    logger.logTaskEnd();

    _state = ExperimentState.taskComplete;
    notifyListeners();
  }

  void reappliedWearables() {
    _prepareTask();
  }

  void _shouldReapplyWearables() {
    _state = ExperimentState.reapplyingWearables;
    notifyListeners();
  }

  /// Prepare the current step (without starting the timer)
  void _prepareTask() {
    _elapsedSeconds = 0;
    _state = ExperimentState.taskWaiting;
    notifyListeners();
  }

  void _performAction() {
    final random = Random();
    final chance = random.nextDouble(); // value between 0.0 and 1.0

    if (chance < 0.1) {
      _shouldReapplyWearables(); // 10% chance
    } else {
      _prepareTask(); // 90% chance
    }
  }

  /// Move to the next step in the experiment process
  void nextStep() {
    print("currentBlockIndex: $_currentBlockIndex");
    print("currentBlockTaskIndex: $_currentBlockTaskIndex");
    print("currentTaskIndex: $_currentTaskIndex");
    print("isLastBlock: $isLastBlock");
    print("isLastBlockStep: $isLastBlockStep");

    if (isLastBlock && isLastBlockStep) {
      stopExperiment();
      return;
    }

    if (isLastBlockStep) {
      _currentTaskIndex++;
      _currentBlockIndex++;
      _currentBlockTaskIndex = 0;
      notifyListeners();
      _performAction();
      return;
    }

    _currentTaskIndex++;
    _currentBlockTaskIndex++;
    notifyListeners();
    _performAction(); // Prepare the next step but don't start timer
  }

  /// Reset the current step timer back to 0
  Future<void> resetCurrentStepTimer() async {
    if (_state == ExperimentState.taskRunning ||
        _state == ExperimentState.taskComplete) {
      _progressTimer?.cancel();
      _progressTimer = null;
      _elapsedSeconds = 0;

      logger.discardLastTask();

      // Return to waiting state
      _state = ExperimentState.taskWaiting;
      notifyListeners();
    }
  }

  /// Stop the experiment completely
  Future<void> stopExperiment() async {
    _progressTimer?.cancel();
    _progressTimer = null;

    await Future.wait([
      if (_sensorsConfigured)
        () async {
          await manager.deactivateSensors();
          _sensorsConfigured = false;
        }(),
      () async {
        await logger.stopAndWriteLogging();
      }(),
    ]);

    _state = ExperimentState.experimentNotStarted;
    _currentTaskIndex = 0;
    _currentBlockIndex = 0;
    _currentBlockTaskIndex = 0;
    _elapsedSeconds = 0;

    notifyListeners();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}
