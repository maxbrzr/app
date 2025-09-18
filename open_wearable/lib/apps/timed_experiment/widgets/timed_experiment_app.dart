import 'package:flutter/material.dart';
import 'package:open_wearable/apps/timed_experiment/widgets/timed_config_selection_page.dart';
import 'package:open_wearable/apps/widgets/select_earable_view.dart';
import 'package:open_wearable/apps/widgets/select_two_earable_view.dart';

class TimedExperimentApp extends StatelessWidget {
  const TimedExperimentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectTwoEarableView(
      startApp: (leftWearable, leftConfigProv, rightWearable, rightConfigProv) {
        return TimedConfigSelectionPage(
          wearable: leftWearable,
          sensorConfigProvider: leftConfigProv,
        );
      },
    );
  }
}
