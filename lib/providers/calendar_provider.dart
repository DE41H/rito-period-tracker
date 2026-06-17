import 'package:flutter/material.dart';

class CalendarProvider extends ChangeNotifier {
  static DateTime get _now => DateTime.now();
  static int get _monthsSinceStart => (_now.year - _start.year) * 12 + (_now.month - _start.month);

  (int, int) selected = (_now.month, _now.year);
  double itemExtent = 320;

  static final _start = DateTime(1950, 1, 1);
  DateTime get start => _start;

  ScrollController? _controller;
  ScrollController get controller {
    final double offset = _monthsSinceStart * itemExtent + (itemExtent / 7);
    _controller ??= ScrollController(initialScrollOffset: offset);
    if (_controller!.initialScrollOffset != offset) {
      _controller!.dispose();
      _controller = ScrollController(initialScrollOffset: offset);
    }
    return _controller!;
  }

  void updateItemExtent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = (screenWidth - 6 * 4.0) / 7;
    itemExtent = cellSize * 6 + 4.0 * 5;
  }

  @override
  void dispose() {
    _controller!.dispose();
    super.dispose();
  }
}
