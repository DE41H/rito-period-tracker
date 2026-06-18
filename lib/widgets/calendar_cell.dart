import 'package:flutter/material.dart';

class CalendarCell extends StatelessWidget {
  const CalendarCell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      color: Colors.white,
      child: Center(
        child: SizedBox(
          width: 5,
          height: 5,
        ),
      ),
    );
  }
}
