import 'package:buritto/providers/calendar_provider.dart';
import 'package:buritto/widgets/calendar_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CalendarArea extends StatelessWidget {
  const CalendarArea({super.key});

  static const int _limit = 6600;
  static const List<String> _months = ['Jan','Feb','Mar','Apr','May','Jun', 'Jul','Aug','Sep','Oct','Nov','Dec'];

  Widget _itemBuilder(BuildContext context, final int index) {
    final start = context.read<CalendarProvider>().start;
    final date = DateTime(start.year, start.month + index, start.day);
    return CalendarGrid(month: date.month, year: date.year);
  }

  Widget _builder(BuildContext context, Widget? child) {
    final provider = context.read<CalendarProvider>();
    final start = provider.start;
    final controller = provider.controller;
    final offset = controller.hasClients ? controller.offset : 0.0;
    final current = (offset / provider.itemExtent).floor();
    final date = DateTime(start.year, start.month + current, start.day);
    return Text(
      '${_months[date.month - 1]}, ${date.year}',
      style: const TextStyle(
        fontSize: 20,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CalendarProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: AnimatedBuilder(
              animation: provider.controller,
              builder: _builder,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(child: Text('S', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))),
              Expanded(child: Text('M', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))),
              Expanded(child: Text('T', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))),
              Expanded(child: Text('W', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))),
              Expanded(child: Text('T', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))),
              Expanded(child: Text('F', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))),
              Expanded(child: Text('S', textAlign: TextAlign.center, style: TextStyle(color: Colors.black))),
            ]
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: provider.controller,
            itemCount: _limit,
            itemExtent: provider.itemExtent,
            itemBuilder: _itemBuilder,
          ),
        ),
      ],
    );
  }
}
