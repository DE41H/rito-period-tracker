import 'dart:async';

import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/collapse.dart';
import 'package:buritto/models/discharge.dart';
import 'package:buritto/models/flow.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/mood.dart';
import 'package:buritto/models/phase.dart';
import 'package:buritto/models/sex.dart';
import 'package:buritto/models/sleep.dart';
import 'package:buritto/models/stress.dart';
import 'package:buritto/models/symptom.dart';

class QuantumLog {
  const QuantumLog({
    required this.date,
    required this.cycleDay,
    required this.phase,
    required this.flow,
    required this.symptoms,
    required this.moods,
    required this.discharge,
    required this.stress,
    required this.sleep,
    required this.sex,
  });

  final DateTime date;
  final int cycleDay;
  final Phase phase;
  final Map<Flow, double> flow;
  final Map<Symptom, double> symptoms;
  final Map<Mood, double> moods;
  final Map<Discharge, double> discharge;
  final Map<Stress, double> stress;
  final Map<Sleep, double> sleep;
  final Map<Sex, double> sex;

  factory QuantumLog.fromLog(Log log) => QuantumLog(
    date: log.date,
    cycleDay: log.cycleDay,
    phase: log.phase,
    flow: {for (final v in Flow.values) v: v == log.flow ? 1.0 : 0.0},
    symptoms: {for (final v in Symptom.values) v: log.symptoms.contains(v) ? 1.0 : 0.0},
    moods: {for (final v in Mood.values) v: log.moods.contains(v) ? 1.0 : 0.0},
    discharge: log.discharge != null
        ? {for (final v in Discharge.values) v: v == log.discharge ? 1.0 : 0.0}
        : {for (final v in Discharge.values) v: 1.0 / Discharge.values.length},
    stress: log.stress != null
        ? {for (final v in Stress.values) v: v == log.stress ? 1.0 : 0.0}
        : {for (final v in Stress.values) v: 1.0 / Stress.values.length},
    sleep: log.sleep != null
        ? {for (final v in Sleep.values) v: v == log.sleep ? 1.0 : 0.0}
        : {for (final v in Sleep.values) v: 1.0 / Sleep.values.length},
    sex: log.sex != null
        ? {for (final v in Sex.values) v: v == log.sex ? 1.0 : 0.0}
        : {for (final v in Sex.values) v: 1.0 / Sex.values.length},
  );
}

class QuantumRepo {
  static final QuantumRepo _instance = QuantumRepo._internal();
  factory QuantumRepo() => _instance;
  QuantumRepo._internal();

  int _version = 0;
  int get version => _version;

  Future<void> saveMonth(final List<QuantumLog> quantumMonth) async {
    final Map<String, QuantumLog> entries = {
      for (final q in quantumMonth) LogRepo().dateToString(q.date): q,
    };
    await HiveDatabase().predictions.putAll(entries);
  }

  Future<List<QuantumLog>?> getMonth(int year, int month) async {
    final DateTime current = DateTime(year, month, 1);
    final int days = DateTime(current.year, current.month + 1, 0).day;
    final List<String> keys = List.generate(days, (i) => LogRepo().dateToString(current.add(Duration(days: i))));
    final List<QuantumLog?> results = await Future.wait(keys.map((k) => HiveDatabase().predictions.get(k)));
    if (results.any((q) => q == null)) return null;
    return results.cast<QuantumLog>();
  }

  Future<void> _deleteMonth(int year, int month) async {
    final DateTime current = DateTime(year, month, 1);
    final int days = DateTime(current.year, current.month + 1, 0).day;
    final List<String> keys = List.generate(days, (i) => LogRepo().dateToString(current.add(Duration(days: i))));
    await HiveDatabase().predictions.deleteAll(keys);
  }

  Future<void> invalidate(DateTime around) async {
    _version++;
    for (int d = -1; d <= 1; d++) {
      final DateTime dt = DateTime(around.year, around.month + d);
      await _deleteMonth(dt.year, dt.month);
      unawaited(Hsmm().month(dt.year, dt.month));
    }
  }

  Future<void> invalidateAll() async {
    _version++;
    await HiveDatabase().predictions.clear();
  }
}
