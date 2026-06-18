import 'package:flutter/material.dart';

class CalendarProvider extends ChangeNotifier {
  static DateTime get _now => DateTime.now();
  static int get _monthsSinceStart => (_now.year - _start.year) * 12 + (_now.month - _start.month);

  double itemExtent = 320;
  DateTime selected = _now;

  static final _start = DateTime(1950, 1, 1);
  DateTime get start => _start;

  ScrollController? _controller;
  ScrollController get controller {
    final double offset = _monthsSinceStart * itemExtent + (itemExtent / 7);
    _controller ??= ScrollController(initialScrollOffset: offset)..addListener(_onScroll);
    if (_controller!.initialScrollOffset != offset) {
      _controller!.dispose();
      _controller = ScrollController(initialScrollOffset: offset)..addListener(_onScroll);
    }
    return _controller!;
  }

  void updateItemExtent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = (screenWidth - 6 * 4.0) / 7;
    itemExtent = cellSize * 6 + 4.0 * 5;
  }

  void _onScroll() {
    final start = _start;
    final controller = _controller!;
    final offset = controller.hasClients ? controller.offset : controller.initialScrollOffset;
    final current = (offset / itemExtent).floor();
    final DateTime date = DateTime(start.year, start.month + current, start.day);
    if (selected != date) {
      selected = date;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
