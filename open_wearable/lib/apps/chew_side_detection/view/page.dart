import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/controller.dart';
import 'package:open_wearable/apps/chew_side_detection/model/config.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/logger.dart';
import 'package:open_wearable/apps/chew_side_detection/controller/manager.dart';
import 'package:open_wearable/apps/chew_side_detection/view/log_files_page.dart';
import 'package:open_wearable/apps/chew_side_detection/view/view.dart';
import 'package:open_wearable/view_models/sensor_configuration_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

final EdgeInsets buttonPadding = EdgeInsets.all(16.0);
final TextStyle buttonTextStyle = TextStyle(fontSize: 18);

class ExperimentPage extends StatefulWidget {
  final Wearable leftWearable;
  final Wearable rightWearable;
  final SensorConfigurationProvider leftConfigProvider;
  final SensorConfigurationProvider rightConfigProvider;
  final String configPath;

  const ExperimentPage({
    super.key,
    required this.leftWearable,
    required this.leftConfigProvider,
    required this.rightWearable,
    required this.rightConfigProvider,
    required this.configPath,
  });

  @override
  State<ExperimentPage> createState() => _ExperimentPageState();
}

class _ExperimentPageState extends State<ExperimentPage> {
  ExperimentController? _controller;
  ExperimentManager? _manager;
  ExperimentLogger? _logger;
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

      final expConfig = await ExperimentConfig.fromFile(widget.configPath);

      setState(() {
        _logger = ExperimentLogger();

        _manager = ExperimentManager(
          logger: _logger!,
          expConfig: expConfig,
          leftWearable: widget.leftWearable,
          leftSensorCfgProvider: widget.leftConfigProvider,
          rightWearable: widget.rightWearable,
          rightSensorCfgProvider: widget.rightConfigProvider,
        );

        _controller = ExperimentController(
          expConfig: expConfig,
          manager: _manager!,
          logger: _logger!,
        );

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

  // Share CSV data
  Future<void> _shareData() async {
    if (_logger == null) return;

    try {
      final csvFile = _logger!.csvFile;
      if (await csvFile.exists()) {
        SharePlus.instance.share(
          ShareParams(
            text: 'Experiment Data',
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
        if (_controller != null) {
          _controller!.stopExperiment();
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: PlatformScaffold(
        appBar: PlatformAppBar(
          title: Text("Experiment"),
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
          value: _controller,
          child: const ExperimentView(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopExperiment();
    _controller?.dispose();
    super.dispose();
  }
}
