import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';
import 'package:buritto/models/message.dart';
import 'package:flutter/material.dart';

class HomeProvider extends ChangeNotifier {
  static final HomeProvider _instance = HomeProvider._internal();
  factory HomeProvider() => _instance;
  HomeProvider._internal();

  double? _progress;
  double get progress {
    _progress ??= ((HiveDatabase().predictions.values.firstOrNull?.cycleDay.toDouble() ?? 0.0) / KalmanFilter().cycleLength).clamp(0.0, 1.0);
    return _progress!;
  }

  TextEditingController get inputController => MessageRepo().controller;

  void updateProgress() {
    _progress = ((HiveDatabase().predictions.values.firstOrNull?.cycleDay.toDouble() ?? 0.0) / KalmanFilter().cycleLength).clamp(0.0, 1.0);
    notifyListeners();
  }

  void sendMessage() async {
    await MessageRepo().send(inputController.text.trim());
  }
}
