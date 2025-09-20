import 'package:shared_preferences/shared_preferences.dart';

/// Manages storage and retrieval of user timed experiment configuration paths
class ConfigStorage {
  static const String _storageKey = 'experiment_config_paths';

  /// Saves the list of user configuration file paths
  static Future<void> saveUserConfigs(List<String> configPaths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, configPaths);
  }

  /// Retrieves the list of saved user configuration file paths
  static Future<List<String>> getUserConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? [];
  }

  /// Adds a new configuration path to stored list
  static Future<void> addUserConfig(String configPath) async {
    final configs = await getUserConfigs();
    if (!configs.contains(configPath)) {
      configs.add(configPath);
      await saveUserConfigs(configs);
    }
  }

  /// Removes a configuration path from stored list
  static Future<void> removeUserConfig(String configPath) async {
    final configs = await getUserConfigs();
    configs.remove(configPath);
    await saveUserConfigs(configs);
  }
}
