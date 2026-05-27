import 'package:flutter/material.dart';

import 'package:buritto/models/message.dart';

class HomeProvider extends ChangeNotifier {
  final TextEditingController inputController = TextEditingController();
  double progress = 0.4;
  List<String> choices = ['1', '2', '3', '4', '5', '6'];

  void sendMessage() {
    MessageRepo.sendMessage(inputController.text.trim());
    inputController.clear();
  }

  void setProgress(final double value) {
    if (value < 0.0) {
      progress = 0.0;
    } else if (value > 1.0) {
      progress = 1.0;
    } else {
      progress = value;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }
}