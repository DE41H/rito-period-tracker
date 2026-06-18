import 'dart:async';

import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/providers/settings_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:provider/provider.dart';

class BirthdayPicker extends StatelessWidget {
  const BirthdayPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      title: Text(
        'Birthday',
        style: TextStyle(
          fontSize: 20,
          color: Colors.black,
        ),
      ),
      trailing: BirthdayPickerTrailingArea(),
    );
  }
}

class BirthdayPickerTrailingArea extends StatelessWidget {
  const BirthdayPickerTrailingArea({super.key});

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun', 'Jul','Aug','Sep','Oct','Nov','Dec'];
  static List<String> _cachedYears = List.generate(DateTime.now().year - 1950, (i) => (i + 1950).toString());
  static int _cachedYear = DateTime.now().year;
  static List<String> get _years {
    if (DateTime.now().year != _cachedYear) {
      _cachedYear = DateTime.now().year;
      _cachedYears = List.generate(DateTime.now().year - 1950, (i) => (i + 1950).toString());
    }
    return _cachedYears;
  }

  @override
  Widget build(BuildContext context) {
    final isReseeding = context.select<SettingsProvider, bool>((s) => s.isReseeding);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isReseeding) const CircularProgressIndicator(),
        MinimalCupertinoSettingsPicker(
          variable: 'birthMonth',
          children: _months,
          offset: 1,
          isReseeding: isReseeding,
        ),
        MinimalCupertinoSettingsPicker(
          variable: 'birthYear',
          children: _years,
          offset: 1950,
          isReseeding: isReseeding,
        ),
      ],
    );
  }
}

class MinimalCupertinoSettingsPicker extends StatefulWidget {
  const MinimalCupertinoSettingsPicker({
    super.key,
    required this.variable,
    required this.children,
    required this.offset,
    required this.isReseeding,
  });

  final String variable;
  final List<String> children;
  final int offset;
  final bool isReseeding;

  static final Map<String, List<Widget>?> _cachedChildrenWidgets = {
    'birthMonth': null,
    'birthYear': null,
  };
  static final Map<String, Timer?> _debounce = {
    'birthMonth': null,
    'birthYear': null,
  };
  static final Map<String, FixedExtentScrollController> _scrollController = {
    'birthMonth': FixedExtentScrollController(initialItem: (HiveDatabase().settings.get('birthMonth', defaultValue: 1) as int) - 1),
    'birthYear': FixedExtentScrollController(initialItem: (HiveDatabase().settings.get('birthYear', defaultValue: 2000) as int) - 1950),
  };

  @override
  State<MinimalCupertinoSettingsPicker> createState() => _MinimalCupertinoSettingsPickerState();
}

class _MinimalCupertinoSettingsPickerState extends State<MinimalCupertinoSettingsPicker> {
  late final ValueListenable<Box<dynamic>> _listenable;

  List<Widget> get _childrenWidgets {
    MinimalCupertinoSettingsPicker._cachedChildrenWidgets[widget.variable] ??= [
      for (final m in widget.children)
        Center(
          child: Text(
            m,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.black,
              fontFamily: 'Shifa-Rame',
            ),
          ),
        ),
    ];
    return MinimalCupertinoSettingsPicker._cachedChildrenWidgets[widget.variable]!;
  }

  @override
  void initState() {
    super.initState();
    _listenable = HiveDatabase().settings.listenable(keys: [widget.variable]);
    _listenable.addListener(_onVarChanged);
  }

  void _onVarChanged() {
    final target = HiveDatabase().settings.get(widget.variable, defaultValue: widget.variable == 'birthYear' ? 2000 : 1) as int;
    final targetIndex = target - widget.offset;
    final controller = MinimalCupertinoSettingsPicker._scrollController[widget.variable]!;
    if (controller.hasClients && controller.selectedItem != targetIndex) {
      controller.animateToItem(
        targetIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.decelerate,
      );
    }
  }

  void _onSelectedItemChanged(final int i) {
    final provider = context.read<SettingsProvider>();
    HiveDatabase().settings.put(widget.variable, i + widget.offset);
    MinimalCupertinoSettingsPicker._debounce[widget.variable]?.cancel();
    MinimalCupertinoSettingsPicker._debounce[widget.variable] = Timer(
      const Duration(seconds: 1),
      () => provider.reseed(
        null,
        widget.variable == 'birthYear' ? i + widget.offset : null,
        widget.variable == 'birthMonth' ? i + widget.offset : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 100,
      child: IgnorePointer(
        ignoring: widget.isReseeding,
        child: CupertinoPicker(
          itemExtent: 50,
          diameterRatio: 100,
          scrollController: MinimalCupertinoSettingsPicker._scrollController[widget.variable]!,
          onSelectedItemChanged: _onSelectedItemChanged,
          children: _childrenWidgets,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _listenable.removeListener(_onVarChanged);
    super.dispose();
  }
}
