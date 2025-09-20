import 'package:flutter/material.dart';
import 'package:open_wearable/apps/chew_side_detection/view/config_page.dart';
import 'package:open_wearable/apps/widgets/select_two_earable_view.dart';

class ExperimentApp extends StatelessWidget {
  const ExperimentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SelectTwoEarableView(
      startApp: (leftWearable, leftConfigProv, rightWearable, rightConfigProv) {
        return ConfigSelectionPage(
          leftWearable: leftWearable,
          leftConfigProvider: leftConfigProv,
          rightWearable: rightWearable,
          rightConfigProvider: rightConfigProv,
        );
      },
    );
  }
}
