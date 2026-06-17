import 'package:buritto/widgets/calendar_cell.dart';
import 'package:flutter/material.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(date.year, date.month + 1, date.day).difference(date).inDays;
    return GridView.count(
      padding: const EdgeInsetsGeometry.all(8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 4.0,
      crossAxisSpacing: 4.0,
      children: [
        for (int i = 0; i < 7; i++) const SizedBox.shrink(),
        if (date.weekday != 7) for (int i = 0; i < date.weekday; i++) const CalendarCell(date: null),
        for (int i = 0; i < days; i++) CalendarCell(date: date.add(Duration(days: i))),
        for (int i = 0;i < 42 - days + date.weekday;i++) const CalendarCell(date: null),
      ],
    );
  }
}
