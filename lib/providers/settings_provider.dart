import 'dart:async';

import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/network.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/quantum.dart';
import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isReseeding = false;
  bool get isReseeding => _isReseeding;

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
    await QuantumRepo().invalidateAll();
    _isReseeding = false;
    notifyListeners();
  }
}
