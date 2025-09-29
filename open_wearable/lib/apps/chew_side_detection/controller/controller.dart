import 'dart:async';
import 'dart:math';

// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/manager.dart';
import 'package:open_wearable/apps/chew_side_detection/model/block.dart';
import 'package:open_wearable/apps/chew_side_detection/model/config.dart';
import 'logger.dart';

enum ExperimentState {
  experimentNotStarted,
  configuringSensors,
  taskWaiting,
  taskRunning,
  taskComplete,
  reapplyingWearables,
  soundSyncing,
  experimentComplete,
}

class ExperimentController with ChangeNotifier {
  final ExperimentConfig expConfig;
  final ExperimentManager manager;
  final ExperimentLogger logger;
  final String experimentId;
  final Random reapplyRandom;

  // State
  int _currentBlockIndex = 0;
  int _currentBlockTaskIndex = 0;
  ExperimentState _state = ExperimentState.experimentNotStarted;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  int _syncCounter = 0;

  ExperimentController({
    required this.expConfig,
    required this.manager,
    required this.logger,
    required this.experimentId,
  }) : reapplyRandom = Random(experimentId.hashCode);

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

  bool get isFirstBlockStep => _currentBlockTaskIndex == 0;

  // State
  ExperimentState get state => _state;

  // Timer
  int get elapsedSeconds => _elapsedSeconds;
  double get progress {
    if (_state == ExperimentState.taskRunning) {
      final duration = currentTask!.duration;
      if (duration == 0) return 0.0;
      return _elapsedSeconds / duration;
    }
    return 0.0;
  }

  // called from view
  Future<void> startExperiment() async {
    if (_state != ExperimentState.experimentNotStarted) {
      throw Exception(
        "When calling startExperiment, state must be experimentNotStarted",
      );
    }
    _state = ExperimentState.taskWaiting;
    notifyListeners();
  }

  void stopExperiment() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _currentBlockIndex = 0;
    _currentBlockTaskIndex = 0;
    _elapsedSeconds = 0;
    _state = ExperimentState.experimentNotStarted;
    notifyListeners();
  }

  Future<void> startSync() async {
    if (_state != ExperimentState.taskWaiting) {
      throw Exception("When calling startSync, state must be taskWaiting");
    }

    String date = DateFormat('yyMMdd_HH_mm_ss').format(DateTime.now());
    String id = "${experimentId}_sync_${_syncCounter}_$date";
    await logger.startLogging(id);
    await _startSensors(id);
    _state = ExperimentState.soundSyncing;
    notifyListeners();
  }

  Future<void> endSync() async {
    if (_state != ExperimentState.soundSyncing) {
      throw Exception("When calling endSync, state must be soundSyncing");
    }

    await _stopSensors();
    logger.logTaskEnd();
    await logger.stopAndWriteLogging();

    _syncCounter++;
    _state = ExperimentState.taskWaiting;
    notifyListeners();
  }

  Future<void> startTask() async {
    if (_state != ExperimentState.taskWaiting) {
      throw Exception("When calling startTask, state must be taskWaiting");
    }

    String date = DateFormat('yyMMdd_HH_mm_ss').format(DateTime.now());
    String id =
        "${experimentId}_${currentBlock.number}_${currentTask!.id}_$date";

    await logger.startLogging(id);
    logger.logTaskStart(
      currentBlock.number,
      currentTask!.id,
      currentTask!.duration,
    );
    await _startSensors(id);

    _state = ExperimentState.taskRunning;
    _progressTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      notifyListeners();
      if (_elapsedSeconds >= currentTask!.duration) {
        _completeTask();
      }
    });
    notifyListeners();
  }

  Future<void> resetTask() async {
    if (_state != ExperimentState.taskRunning) {
      throw Exception("When calling resetTask, state must be taskRunning");
    }
    await _stopSensors();
    logger.logTaskEnd();
    await logger.stopAndWriteLogging();

    _progressTimer?.cancel();
    _progressTimer = null;
    _prepareTask();
  }

  void repeatTask() {
    if (_state != ExperimentState.taskComplete) {
      throw Exception("When calling repeatTask, state must be taskComplete");
    }
    _prepareTask();
  }

  void nextStep() {
    if (_state != ExperimentState.taskWaiting &&
        _state != ExperimentState.taskComplete) {
      throw Exception(
        "When calling nextStep, state must be taskComplete, was in $_state",
      );
    }
    if (isLastBlock && isLastBlockStep) {
      _state = ExperimentState.experimentComplete;
      notifyListeners();
    } else if (isLastBlockStep) {
      _currentBlockIndex++;
      _currentBlockTaskIndex = 0;
      notifyListeners();
      _prepareTaskOrReapply();
    } else {
      _currentBlockTaskIndex++;
      notifyListeners();
      _prepareTaskOrReapply();
    }
  }

  void lastStep() {
    if (_state != ExperimentState.taskWaiting &&
        _state != ExperimentState.taskComplete) {
      throw Exception(
        "When calling lastStep, state must be taskComplete, was in $_state",
      );
    }
    if (isFirstBlockStep) {
      _currentBlockIndex--;
      _currentBlockTaskIndex = currentBlock.tasks.length - 1;
      notifyListeners();
      _prepareTaskOrReapply();
    } else {
      _currentBlockTaskIndex--;
      notifyListeners();
      _prepareTaskOrReapply();
    }
  }

  void reappliedWearables() {
    _prepareTask();
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

  // private

  Future<void> _startSensors(String id) async {
    if (_state != ExperimentState.taskWaiting) {
      throw Exception("When calling startSensors, state must be taskWaiting");
    }

    _state = ExperimentState.configuringSensors;
    notifyListeners();

    await manager.setSensorLogFilePrefix(id);
    await manager.configureSensors();
    await logger.sensorsReady;
    print("NOW");

    _state = ExperimentState.taskWaiting;
    notifyListeners();
  }

  Future<void> _stopSensors() async {
    if (_state != ExperimentState.taskRunning &&
        _state != ExperimentState.soundSyncing) {
      throw Exception(
        "When calling stopSensors, state must be taskRunning or soundSyncing",
      );
    }
    _state = ExperimentState.configuringSensors;
    notifyListeners();

    await manager.deactivateSensors();

    _state = ExperimentState.taskWaiting;
    notifyListeners();
  }

  Future<void> _completeTask() async {
    if (_state != ExperimentState.taskRunning) {
      throw Exception("When calling completeTask, state must be taskRunning");
    }

    _progressTimer?.cancel();
    _progressTimer = null;

    await _stopSensors();
    logger.logTaskEnd();
    await logger.stopAndWriteLogging();

    _state = ExperimentState.taskComplete;
    notifyListeners();
  }

  void _shouldReapply() {
    _state = ExperimentState.reapplyingWearables;
    notifyListeners();
  }

  void _prepareTask() {
    _elapsedSeconds = 0;
    _state = ExperimentState.taskWaiting;
    notifyListeners();
  }

  void _prepareTaskOrReapply() {
    final chance = reapplyRandom.nextDouble(); // value between 0.0 and 1.0
    if (chance < 0.1) {
      _shouldReapply(); // 10% chance
    } else {
      _prepareTask(); // 90% chance
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}
