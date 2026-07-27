import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/models/discharge.dart';
import 'package:buritto/models/flow.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/mood.dart';
import 'package:buritto/models/sex.dart';
import 'package:buritto/models/sleep.dart';
import 'package:buritto/models/stress.dart';
import 'package:buritto/models/symptom.dart';
import 'package:flutter/material.dart' hide Flow;

class CreateLogModal {
  static final CreateLogModal _instance = CreateLogModal._internal();
  factory CreateLogModal() => _instance;
  CreateLogModal._internal();

  void show(BuildContext context, {DateTime? date, Log? log}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateLogSheet(
        date: log?.date ?? date ?? DateTime.now(),
        existingLog: log,
      ),
    );
  }
}

class _CreateLogSheet extends StatefulWidget {
  const _CreateLogSheet({required this.date, this.existingLog});

  final DateTime date;
  final Log? existingLog;

  @override
  State<_CreateLogSheet> createState() => _CreateLogSheetState();
}

class _CreateLogSheetState extends State<_CreateLogSheet> {
  late DateTime _date;
  Flow _flow = Flow.none;
  final Set<Symptom> _symptoms = {};
  final Set<Mood> _moods = {};
  Discharge? _discharge;
  Stress? _stress;
  Sleep? _sleep;
  Sex? _sex;
  final TextEditingController _notesController = TextEditingController();
  bool _saving = false;

  late final Set<String> _loggedDates;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.date.year, widget.date.month, widget.date.day);
    _loggedDates = HiveDatabase().logs.keys
        .cast<String>()
        .map((k) => k.substring(0, 10))
        .toSet();

    final Log? log = widget.existingLog;
    if (log != null) _applyLog(log);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _applyLog(Log log) {
    _flow = log.flow;
    _symptoms..clear()..addAll(log.symptoms);
    _moods..clear()..addAll(log.moods);
    _discharge = log.discharge;
    _stress = log.stress;
    _sleep = log.sleep;
    _sex = log.sex;
    _notesController.text = log.notes ?? '';
  }

  void _resetFields() {
    _flow = Flow.none;
    _symptoms.clear();
    _moods.clear();
    _discharge = null;
    _stress = null;
    _sleep = null;
    _sex = null;
    _notesController.text = '';
  }

  Future<void> _onDateSelected(DateTime date) async {
    final Log? log = await HiveDatabase().logs.get(LogRepo().dateToString(date));
    setState(() {
      _date = date;
      if (log != null) {
        _applyLog(log);
      } else {
        _resetFields();
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final bool ok = await LogRepo().save(
      date: _date,
      flow: _flow,
      symptoms: Set.unmodifiable(_symptoms),
      moods: Set.unmodifiable(_moods),
      discharge: _discharge,
      stress: _stress,
      sleep: _sleep,
      sex: _sex,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existingLog != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            else
              _InlineDatePicker(
                selectedDate: _date,
                loggedDates: _loggedDates,
                onSelected: _onDateSelected,
              ),
            const SizedBox(height: 16),
            _SingleSelect<Flow>(
              label: 'Flow',
              values: Flow.values,
              selected: _flow,
              onChanged: (v) => setState(() => _flow = v),
            ),
            const SizedBox(height: 12),
            _MultiSelect<Symptom>(
              label: 'Symptoms',
              values: Symptom.values,
              selected: _symptoms,
              onToggle: (v) => setState(() => _symptoms.contains(v) ? _symptoms.remove(v) : _symptoms.add(v)),
            ),
            const SizedBox(height: 12),
            _MultiSelect<Mood>(
              label: 'Mood',
              values: Mood.values,
              selected: _moods,
              onToggle: (v) => setState(() => _moods.contains(v) ? _moods.remove(v) : _moods.add(v)),
            ),
            const SizedBox(height: 12),
            _NullableSingleSelect<Discharge>(
              label: 'Discharge',
              values: Discharge.values,
              selected: _discharge,
              onChanged: (v) => setState(() => _discharge = v),
            ),
            const SizedBox(height: 12),
            _NullableSingleSelect<Stress>(
              label: 'Stress',
              values: Stress.values,
              selected: _stress,
              onChanged: (v) => setState(() => _stress = v),
            ),
            const SizedBox(height: 12),
            _NullableSingleSelect<Sleep>(
              label: 'Sleep',
              values: Sleep.values,
              selected: _sleep,
              onChanged: (v) => setState(() => _sleep = v),
            ),
            const SizedBox(height: 12),
            _NullableSingleSelect<Sex>(
              label: 'Sex',
              values: Sex.values,
              selected: _sex,
              onChanged: (v) => setState(() => _sex = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineDatePicker extends StatefulWidget {
  const _InlineDatePicker({
    required this.selectedDate,
    required this.loggedDates,
    required this.onSelected,
  });

  final DateTime selectedDate;
  final Set<String> loggedDates;
  final ValueChanged<DateTime> onSelected;

  @override
  State<_InlineDatePicker> createState() => _InlineDatePickerState();
}

class _InlineDatePickerState extends State<_InlineDatePicker> {
  late DateTime _viewMonth;

  static const List<String> _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
  }

  // Sunday-start: Sun(7)→0, Mon(1)→1, ..., Sat(6)→6
  static int _leadingBlanks(DateTime firstOfMonth) {
    final int wd = firstOfMonth.weekday;
    return wd == 7 ? 0 : wd;
  }

  static String _dateKey(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String().substring(0, 10);

  bool _isLogged(DateTime d) => widget.loggedDates.contains(_dateKey(d));

  bool _isSelected(DateTime d) =>
      d.year == widget.selectedDate.year &&
      d.month == widget.selectedDate.month &&
      d.day == widget.selectedDate.day;

  bool _isFuture(DateTime d) {
    final DateTime today = DateTime.now();
    return d.isAfter(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final int blanks = _leadingBlanks(DateTime(_viewMonth.year, _viewMonth.month, 1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                () => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1),
              ),
            ),
            Text(
              '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                () => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1),
              ),
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final label in _dayLabels)
              Center(
                child: Text(label, style: Theme.of(context).textTheme.labelSmall),
              ),
            for (int i = 0; i < blanks; i++) const SizedBox.shrink(),
            for (int day = 1; day <= daysInMonth; day++)
              Builder(builder: (context) {
                final DateTime date = DateTime(_viewMonth.year, _viewMonth.month, day);
                return _DayCell(
                  date: date,
                  isLogged: _isLogged(date),
                  isSelected: _isSelected(date),
                  isFuture: _isFuture(date),
                  onTap: widget.onSelected,
                );
              }),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isLogged,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime date;
  final bool isLogged;
  final bool isSelected;
  final bool isFuture;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isFuture ? null : () => onTap(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: isSelected
            ? BoxDecoration(color: colors.primary, shape: BoxShape.circle)
            : null,
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontWeight: isLogged ? FontWeight.bold : FontWeight.normal,
              color: isFuture
                  ? colors.onSurface.withValues(alpha: 0.3)
                  : isSelected
                      ? colors.onPrimary
                      : isLogged
                          ? colors.primary
                          : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleSelect<T extends Enum> extends StatelessWidget {
  const _SingleSelect({required this.label, required this.values, required this.selected, required this.onChanged});

  final String label;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(v.name),
                selected: selected == v,
                onSelected: (_) => onChanged(v),
              ),
          ],
        ),
      ],
    );
  }
}

class _NullableSingleSelect<T extends Enum> extends StatelessWidget {
  const _NullableSingleSelect({required this.label, required this.values, required this.selected, required this.onChanged});

  final String label;
  final List<T> values;
  final T? selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(v.name),
                selected: selected == v,
                onSelected: (picked) => onChanged(picked ? v : null),
              ),
          ],
        ),
      ],
    );
  }
}

class _MultiSelect<T extends Enum> extends StatelessWidget {
  const _MultiSelect({required this.label, required this.values, required this.selected, required this.onToggle});

  final String label;
  final List<T> values;
  final Set<T> selected;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final v in values)
              FilterChip(
                label: Text(v.name),
                selected: selected.contains(v),
                onSelected: (_) => onToggle(v),
              ),
          ],
        ),
      ],
    );
  }
}
