import 'dart:async';

import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/network.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/pages/settings.dart';
import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  double _iconAngle = 0.0;
  double get iconAngle => _iconAngle;

  bool _isReseeding = false;
  bool get isReseeding => _isReseeding;

  bool _isSettingsPage = false;

  Future<void> reseed([final bool? pcos, final int? year, final int? month]) async {
    _isReseeding = true;
    notifyListeners();
    await LogRepo().pipelineLock.synchronized(() async {
      if (pcos != null)
      {
        await (
          KalmanFilter().rebuild(pcos, year, month),
          BayesNetwork().reseed(pcos),
        ).wait;
      } else {
        await KalmanFilter().rebuild(pcos, year, month);
      }
    });
    _isReseeding = false;
    notifyListeners();
  }

  void toggleSettings(final NavigatorState navigator) {
    _iconAngle += 0.375;
    if (_isSettingsPage) {
      navigator.pop();
    } else {
      navigator.push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => const SettingsPage(),
          transitionsBuilder: (_, _, _, child) => child,
        )
      );
    }
    _isSettingsPage = !_isSettingsPage;
    notifyListeners();
  }
}
