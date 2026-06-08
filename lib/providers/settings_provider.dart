  import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/network.dart';
import 'package:flutter/material.dart';

  import 'package:buritto/pages/settings.dart';

  class SettingsProvider extends ChangeNotifier {
    double iconAngle = 0.0;
    bool isSettingsPage = false;
    bool isReseeding = false;

    Future<void> reseed(bool pcos) async {
      isReseeding = true;
      notifyListeners();
      await (
        KalmanFilter().rebuild(pcos),
        BayesNetwork().reseed(pcos),
      ).wait;
      isReseeding = false;
      notifyListeners();
    }

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
