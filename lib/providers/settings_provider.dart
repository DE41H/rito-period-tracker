  import 'package:flutter/material.dart';

  import '../pages/settings.dart';

  class SettingsProvider extends ChangeNotifier {
    double iconAngle = 0.0;
    bool isSettingsPage = false;

    void toggleSettings(NavigatorState navigator) {
      iconAngle += 0.125;
      if (isSettingsPage) {
        navigator.pop();
      } else {
        navigator.push(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => SettingsPage(),
            transitionsBuilder: (_, _, _, child) => child,
          )
        );
      }
      isSettingsPage = !isSettingsPage;
      notifyListeners();
    }
  }
