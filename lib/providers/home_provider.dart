import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';

class HomeProvider extends ChangeNotifier {
  final TextEditingController inputController = TextEditingController();
  double progress = 0.4;
  final Map<int, Future> futures = {};
  List<String> choices = ['1', '2', '3', '4', '5', '6'];

  Future getFutureMessage(int index) {
    futures[index] ??= Hive.lazyBox('messages').getAt(index);
    return futures[index]!;
  }

  void sendMessage() {
    if (inputController.text.trim().isEmpty) {
      return;
    }
    Hive.lazyBox('messages').add({
      'message': inputController.text.trim(),
      'isInput': true,
    });
    inputController.clear();
    notifyListeners();
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