import 'package:flutter/material.dart';

class CalendarProvider extends ChangeNotifier {
  static DateTime get _now => DateTime.now();
  static int get _monthsSinceStart => (_now.year - _start.year) * 12 + (_now.month - _start.month);

  (int, int) selected = (_now.month, _now.year);

  static const double _itemExtent = 320;
  double get itemExtent => _itemExtent;

  static final _start = DateTime(1950, 1, 1);
  DateTime get start => _start;

  final ScrollController controller = ScrollController(
    initialScrollOffset: _monthsSinceStart * _itemExtent,
  );
}
