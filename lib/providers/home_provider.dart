import 'package:buritto/models/message.dart';
import 'package:flutter/material.dart';

class HomeProvider extends ChangeNotifier {
  List<String> choices = ['1', '2', '3', '4', '5', '6'];
  final TextEditingController inputController = TextEditingController();

  double _progress = 0.4;
  double get progress => _progress;
  set progress(final double value) {
    _progress = value.clamp(0.0, 1.0);
  }

  void sendMessage() {
    MessageRepo().send(inputController.text.trim());
    inputController.clear();
  }

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }
}
