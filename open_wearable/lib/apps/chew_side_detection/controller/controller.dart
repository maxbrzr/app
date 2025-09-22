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
  final TextEditingController _expIdController = TextEditingController();
  late String experimentId;

  // State
  int _currentBlockIndex = 0;
  int _currentBlockTaskIndex = 0;
  int _currentTaskIndex = 0;
  ExperimentState _state = ExperimentState.experimentNotStarted;
  DateTime? _sessionStartTime;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  bool _sensorsConfigured = false;

  ExperimentController({
    required this.expConfig,
    required this.manager,
    required this.logger,
  });

  // Getters
  int get currentBlockIndex => _currentBlockIndex;
  int get currentBlockTaskIndex => _currentBlockTaskIndex;
  int get currentTaskIndex => _currentTaskIndex;

  ExperimentBlock get currentBlock => expConfig.blocks[_currentBlockIndex];

  Task? get currentTask {
    final block = expConfig.blocks[_currentBlockIndex];
    if (block.tasks.isEmpty) return null;
    return block.tasks[_currentBlockTaskIndex];
  }

  int get totalNumTasks =>
      expConfig.blocks.fold(0, (sum, block) => sum + block.tasks.length);

  int get totalNumBlocks => expConfig.blocks.fold(0, (sum, block) => sum + 1);

  int get totalNumBlockTasks =>
      expConfig.blocks[_currentBlockIndex].tasks.length;

  bool get isLastBlock => _currentBlockIndex == expConfig.blocks.length - 1;

  bool get isLastBlockStep {
    if (currentBlock.tasks.isEmpty) return true;
    return currentBlockTaskIndex == currentBlock.tasks.length - 1;
  }

  ExperimentState get state => _state;

  int get elapsedSeconds => _elapsedSeconds;
  DateTime? get sessionStartTime => _sessionStartTime;

  double get progress {
    // No current task or experiment hasn't started yet
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

  TextEditingController get expIdController => _expIdController;

  /// Start the experiment session
  Future<void> startExperiment() async {
    if (_state != ExperimentState.experimentNotStarted) return;

    try {
      _state = ExperimentState.configuringSensors;
      notifyListeners();

      // Get experiment ID from text field
      experimentId = _expIdController.text.trim();

      // Initialize the logger with experiment ID
      await logger.initialize(experimentId);

      // Set sensor log file prefix
      // await manager.setSensorLogFilePrefix(
      //   "${experimentId}_${DateFormat('yyMMdd_HH_mm').format(DateTime.now())}_",
      // );

      // await manager.configureSensors();
      // _sensorsConfigured = true;

      logger.startExperiment();
      _sessionStartTime = DateTime.now();

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

  /// Start the timer for the current step (called manually by user)
  Future<void> startTaskTimer() async {
    if (_state != ExperimentState.taskWaiting) return;
    // If there's no task, do nothing
    final task = currentTask;
    if (task == null) return;

    _state = ExperimentState.taskRunning;

    //Set sensor log file prefix
    final dateStamp = DateFormat('yyMMdd_HH_mm').format(DateTime.now());

    await manager.setSensorLogFilePrefix(
      "${experimentId}_${currentBlock.number}_${currentTask!.id}_${dateStamp}_",
    );

    await manager.configureSensors();
    _sensorsConfigured = true;

    // Log step start
    logger.logStepStart(
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

    if (_sensorsConfigured) {
      // subscription?.cancel();
      await manager.deactivateSensors();
      _sensorsConfigured = false;
    }

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
  void resetCurrentStepTimer() {
    if (_state == ExperimentState.taskRunning ||
        _state == ExperimentState.taskComplete) {
      _progressTimer?.cancel();
      _progressTimer = null;
      _elapsedSeconds = 0;

      logger.discardLastStep();

      // Return to waiting state
      _state = ExperimentState.taskWaiting;
      notifyListeners();
    }
  }

  /// Stop the experiment completely
  Future<void> stopExperiment() async {
    _progressTimer?.cancel();
    _progressTimer = null;

    // if (_sensorsConfigured) {
    //   // subscription?.cancel();
    //   await manager.deactivateSensors();
    //   _sensorsConfigured = false;
    // }

    // Finalize the session logging if we have data
    if (_sessionStartTime != null) {
      await logger.finalizeExperiment();
    }

    _state = ExperimentState.experimentNotStarted;
    _currentTaskIndex = 0;
    _currentBlockIndex = 0;
    _currentBlockTaskIndex = 0;
    _elapsedSeconds = 0;
    _sessionStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}
