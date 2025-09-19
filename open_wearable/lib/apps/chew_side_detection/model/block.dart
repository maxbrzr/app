import 'package:yaml/yaml.dart';

/// Represents a task for chewing side detection
class Task {
  final String name;
  final int duration;

  Task({required this.name, required this.duration});
}

/// Represents an experiment block for chewing side detection
class ExperimentBlock {
  final int number;
  final String instruction;
  final List<Task> tasks;

  ExperimentBlock({
    required this.instruction,
    required this.number,
    required this.tasks,
  });

  factory ExperimentBlock.fromYaml(YamlMap map) {
    final number = map["block_number"] as int;
    final instruction = map["instruction"] as String;
    final yamlTasks = (map["tasks"] as YamlList?) ?? YamlList.wrap([]);
    // print("block number: $number");
    // print("instruction: $instruction");

    final List<Task> tasks = [];
    for (var task in yamlTasks) {
      final name = task["name"] as String;
      // print("task name: $name");
      tasks.add(
        Task(
          name: "$name-left",
          duration: task["duration"] as int,
        ),
      );
      tasks.add(
        Task(
          name: "$name-right",
          duration: task["duration"] as int,
        ),
      );
    }

    tasks.shuffle();
    return ExperimentBlock(
      number: number,
      instruction: instruction,
      tasks: tasks,
    );
  }
}
