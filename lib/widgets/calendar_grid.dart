import 'package:buritto/logic/collapse.dart';
import 'package:buritto/models/quantum.dart';
import 'package:buritto/widgets/calendar_cell.dart';
import 'package:flutter/material.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(date.year, date.month + 1, 0).day;

    return FutureBuilder(
      future: Hsmm().month(date.year, date.month),
      builder: (context, asyncSnapshot) {
        final List<QuantumLog>? monthData = asyncSnapshot.data;
        return GridView.count(
          padding: const EdgeInsetsGeometry.all(8),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          mainAxisSpacing: 4.0,
          crossAxisSpacing: 4.0,
          children: [
            for (int i = 0; i < 7; i++) const SizedBox.shrink(),
            if (date.weekday != 7) for (int i = 0; i < date.weekday; i++) const CalendarCell(),
            for (int i = 0; i < days; i++) (monthData == null || monthData.isEmpty) ? const CalendarCell() : CalendarCell(q: monthData[i]),
            for (int i = 0;i < 42 - days + date.weekday;i++) const CalendarCell(),
          ],
        );
      },
    );
  }
}
