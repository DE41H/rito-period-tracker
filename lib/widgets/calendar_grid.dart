import 'package:flutter/material.dart';

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({super.key, required this.month, required this.year});

  final int month;
  final int year;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 4.0,
      crossAxisSpacing: 4.0,
      children: const [],
    );
  }
}
