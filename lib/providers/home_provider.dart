import 'package:buritto/models/message.dart';
import 'package:flutter/material.dart';

class HomeProvider extends ChangeNotifier {
  double _progress = 0.4;
  double get progress => _progress;
  set progress(final double value) {
    _progress = value.clamp(0.0, 1.0);
  }

  TextEditingController get inputController => MessageRepo().controller;

  void sendMessage() {
    MessageRepo().send(inputController.text.trim());
  }
}
