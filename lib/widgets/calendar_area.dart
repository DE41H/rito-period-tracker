import 'package:buritto/logic/collapse.dart';
import 'package:buritto/providers/calendar_provider.dart';
import 'package:buritto/widgets/calendar_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CalendarArea extends StatelessWidget {
  const CalendarArea({super.key});

  static const int _limit = 6600;

  Widget _itemBuilder(BuildContext context, final int index) {
    final start = context.read<CalendarProvider>().start;
    final date = DateTime(start.year, start.month + index, start.day);
    Hsmm().month(date.year, date.month);
    return CalendarGrid(date: date);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CalendarProvider>();
    provider.updateItemExtent(context);

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Center(
            child: CalendarHeader(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({super.key});

  static const List<String> _months = ['Jan','Feb','Mar','Apr','May','Jun', 'Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final date = context.select<CalendarProvider, DateTime>((c) => c.selected);

    return Text(
      '${_months[date.month - 1]}, ${date.year}',
      style: const TextStyle(
        fontSize: 20,
      )
    );
  }
}