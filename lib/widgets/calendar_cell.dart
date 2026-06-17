import 'package:flutter/material.dart';

class CalendarCell extends StatelessWidget {
  const CalendarCell({super.key, required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final String day = '${(date != null) ? date!.day : ''}';

    return Card(
      elevation: 0,
      color: Colors.white,
      child: Stack(
        children: [
          const Center(
            child: SizedBox(
              width: 5,
              height: 5,
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Text(
              day,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18
              ),
            ),
          ),
        ],
      ),
    );
  }
}
