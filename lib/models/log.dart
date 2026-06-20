import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/network.dart';
import 'package:buritto/models/discharge.dart';
import 'package:buritto/models/flow.dart';
import 'package:buritto/models/mood.dart';
import 'package:buritto/models/phase.dart';
import 'package:buritto/models/quantum.dart';
import 'package:buritto/models/sex.dart';
import 'package:buritto/models/sleep.dart';
import 'package:buritto/models/stress.dart';
import 'package:buritto/models/symptom.dart';
import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';

class Log {
  const Log({
    required this.date,
    required this.cycleDay,
    required this.ovulating,
    required this.phase,
    required this.flow,
    this.symptoms = const {},
    this.moods = const {},
    this.discharge,
    this.stress,
    this.sleep,
    this.sex,
    this.notes,
  });

  final DateTime date;
  final int cycleDay;
  final bool ovulating;
  final Phase phase;
  final Flow flow;
  final Set<Symptom> symptoms;
  final Set<Mood> moods;
  final Discharge? discharge;
  final Stress? stress;
  final Sleep? sleep;
  final Sex? sex;
  final String? notes;

  Log copyWith({
    DateTime? date,
    int? cycleDay,
    bool? ovulating,
    Phase? phase,
    Flow? flow,
    Set<Symptom>? symptoms,
    Set<Mood>? moods,
    Discharge? discharge,
    Stress? stress,
    Sleep? sleep,
    Sex? sex,
    String? notes,
  }) => Log(
    date: date ?? this.date,
    cycleDay: cycleDay ?? this.cycleDay,
    ovulating: ovulating ?? this.ovulating,
    phase: phase ?? this.phase,
    flow: flow ?? this.flow,
    symptoms: symptoms ?? this.symptoms,
    moods: moods ?? this.moods,
    discharge: discharge ?? this.discharge,
    stress: stress ?? this.stress,
    sleep: sleep ?? this.sleep,
    sex: sex ?? this.sex,
    notes: notes ?? this.notes,
  );

  List<String> toBayesEvent([Log? prev]) => [
    'PHASE=${phase.name.toUpperCase()}',
    if (prev != null) 'PREV_PHASE=${prev.phase.name.toUpperCase()}',
    if (prev != null) 'PREV_FLOW=${prev.flow.name.toUpperCase()}',
  ];

  Map<String, dynamic> toJson() => {
    'date': LogRepo().dateToString(date),
    'cycleDay': cycleDay,
    'ovulating': ovulating,
    'phase': phase.index,
    'flow': flow.index,
    'symptoms': symptoms.map((s) => s.index).toList(),
    'moods': moods.map((m) => m.index).toList(),
    'discharge': discharge?.index,
    'stress': stress?.index,
    'sleep': sleep?.index,
    'sex': sex?.index,
    'notes': notes,
  };

  @override
  String toString() {
    final StringBuffer builder = StringBuffer();
    builder.writeln("Date: ${LogRepo().dateToString(date)}");
    builder.writeln("Phase: ${phase.title}");
    builder.writeln("Notes: $notes");
    ovulating ? builder.writeln("You were Ovulating today!") : null;
    (flow != Flow.none) ? builder.writeln("You were experiencing ${flow.title.toLowerCase()} flow!"): null;
    (discharge != null) ? builder.writeln("You had ${discharge!.title.toLowerCase()} discharge!") : null;
    (sleep != null) ? builder.writeln("You had ${sleep!.title.toLowerCase()} sleep quality!") : null;
    (stress != null) ? builder.writeln("You were feeling ${stress!.title.toLowerCase()} stress!") : null;
    (sex != null) ? builder.writeln("You had ${sex!.title.toLowerCase()} sex on this day!") : null;
    if (symptoms.isNotEmpty) {
      builder.write("You were facing ");
      for (var element in symptoms) {
        if (element == symptoms.first) {
          builder.write(element.title.toLowerCase());
          continue;
        }
        builder.write(", ${element.title.toLowerCase()}");
      }
      builder.writeln(" today");
    }
    if (moods.isNotEmpty) {
      builder.write("You were feeling ");
      for (var element in moods) {
        if (element == moods.first) {
          builder.write(element.title.toLowerCase());
          continue;
        }
        builder.write(", ${element.title.toLowerCase()}");
      }
      builder.writeln(" today");
    }
    return builder.toString();
  }

  factory Log.fromJson(final Map<String, dynamic> json) => Log(
    date: LogRepo().stringToDate(json['date'] as String),
    cycleDay: json['cycleDay'] as int,
    ovulating: json['ovulating'] as bool,
    phase: Phase.values[json['phase'] as int],
    flow: Flow.values[json['flow'] as int],
    symptoms: {for (final i in (json['symptoms'] as List).cast<int>()) Symptom.values[i]},
    moods: {for (final i in (json['moods'] as List).cast<int>()) Mood.values[i]},
    discharge: json['discharge'] != null ? Discharge.values[json['discharge'] as int] : null,
    stress: json['stress'] != null ? Stress.values[json['stress'] as int] : null,
    sleep: json['sleep'] != null ? Sleep.values[json['sleep'] as int] : null,
    sex: json['sex'] != null ? Sex.values[json['sex'] as int] : null,
    notes: json['notes'] as String?,
  );
}

class LogRepo {
  static final LogRepo _instance = LogRepo._internal();
  factory LogRepo() => _instance;
  LogRepo._internal();

  String dateToString(final DateTime date) => date.toIso8601String();
  DateTime stringToDate(final String string) => DateTime.parse(string);

  final Lock _pipelineLock = Lock();
  Lock get pipelineLock => _pipelineLock;

  Future<bool> save({
    required final DateTime date,
    required final Flow flow,
    final Set<Symptom> symptoms = const {},
    final Set<Mood> moods = const {},
    final Discharge? discharge,
    final Stress? stress,
    final Sleep? sleep,
    final Sex? sex,
    final String? notes,
  }) async => _pipelineLock.synchronized(() async {
    if (date.isAfter(DateTime.now())) return false;

    final List<String> keys = HiveDatabase().logs.keys.cast<String>().toList();
    final String key = dateToString(date);
    final int index = lowerBound(keys, key);
    if(index == keys.length || keys[index] != key) keys.insert(index, key);

    final (int cycleDay, Phase phase) = await _compute(date, flow, keys, index);
    final Log log = Log(
      date: date,
      cycleDay: cycleDay,
      ovulating: KalmanFilter().ovulationDay == cycleDay,
      phase: phase,
      flow: flow,
      symptoms: symptoms,
      moods: moods,
      discharge: discharge,
      stress: stress,
      sleep: sleep,
      sex: sex,
      notes: notes,
    );
    await HiveDatabase().logs.put(key, log);

    final bool isPastInsertion = index < keys.length - 1;
    if (isPastInsertion) {
      final Iterable<String> subsequent = keys.skip(index + 1);
      int i = index + 1;
      for (final k in subsequent) {
        final Log old = (await HiveDatabase().logs.get(k))!;
        final (int cd, Phase ph) = await _compute(old.date, old.flow, keys, i++, true);
        await HiveDatabase().logs.put(k, old.copyWith(cycleDay: cd, phase: ph, ovulating: KalmanFilter().ovulationDay == cd));
      }

      final bool pcos = HiveDatabase().settings.get('hasPcos', defaultValue: false) as bool;
      await (
        KalmanFilter().rebuild(pcos),
        BayesNetwork().reseed(pcos),
      ).wait;
    } else {
      final Log? prev = await HiveDatabase().logs.get(dateToString(date.subtract(const Duration(days: 1))));
      await BayesNetwork().update(log, prev);
    }
    await QuantumRepo().invalidate();
    
    return true;
  });

  Future<(int, Phase)> _compute(final DateTime date, final Flow flow, final List<String> keys, final int index, [final bool recompute = false]) async {
    final String? lastKey = (index > 0) ? keys[index - 1] : null;
    if (lastKey == null) return (1, flow != Flow.none ? Phase.menstrual : Phase.follicular);

    final Log last = (await HiveDatabase().logs.get(lastKey))!;
    final int elapsed = date.difference(last.date).inDays;
    final int rawDay = last.cycleDay + elapsed - 1;
    final int cycleDay = (rawDay % KalmanFilter().cycleLength).floor() + 1;

    if (!recompute && last.phase == Phase.menstrual && last.flow != Flow.none) {
      if (elapsed > KalmanFilter().periodLength * 1.5) {
        KalmanFilter().stagePeriodEnd(last.cycleDay.toDouble());
        KalmanFilter().flushPeriodEnd();
      } else if (flow == Flow.none) {
        KalmanFilter().stagePeriodEnd(last.cycleDay.toDouble());
      }
    }
    if (flow != Flow.none && rawDay > KalmanFilter().cycleLength * 0.5 && rawDay < KalmanFilter().cycleLength * 1.5) {
      if (!recompute) {
        if (elapsed <= KalmanFilter().periodLength * 1.5 && last.flow != Flow.none) {
          KalmanFilter().stagePeriodEnd(last.cycleDay.toDouble(), false);
        }
        KalmanFilter().flushPeriodEnd();
        KalmanFilter().updateCycle(rawDay);
      }
      return (1, Phase.menstrual);
    }
    return (cycleDay, KalmanFilter().predictPhase(cycleDay, flow));
  }

  Future<bool> delete(DateTime date) async {
    final List<String> keys = HiveDatabase().logs.keys.cast<String>().toList();
    final String key = dateToString(date);
    final int index = lowerBound(keys, key);
    if (index == keys.length || keys[index] != key) return false;
    await HiveDatabase().logs.delete(key);
    keys.removeAt(index);
    int i = index;
    for (final k in keys.skip(index)) {
      final Log old = (await HiveDatabase().logs.get(k))!;
      final (int cd, Phase ph) = await _compute(old.date, old.flow, keys, i++);
      await HiveDatabase().logs.put(k, old.copyWith(cycleDay: cd, phase: ph, ovulating: KalmanFilter().ovulationDay == cd));
    }
    final bool pcos = HiveDatabase().settings.get('hasPcos', defaultValue: false) as bool;
    await (
      KalmanFilter().rebuild(pcos),
      BayesNetwork().reseed(pcos),
    ).wait;
    await QuantumRepo().invalidate();

    return true;
  }

  Stream<Log> get all async* {
    for (final key in HiveDatabase().logs.keys.cast<String>()) {
      final Log? log = await HiveDatabase().logs.get(key);
      if (log != null) yield log;
    }
  }

  Stream<Log> range(final DateTime from, final DateTime to) async* {
    final List<String> keys = HiveDatabase().logs.keys.cast<String>().toList();
    final String fromKey = from.toIso8601String();
    final String toKey = to.toIso8601String();
    final int start = lowerBound(keys, fromKey);
    for (int i = start; i < keys.length; i++) {
      if (keys[i].compareTo(toKey) > 0) break;
      final Log? log = await HiveDatabase().logs.get(keys[i]);
      if (log != null) yield log;
    }
  }

  Future<Log?> get(final DateTime date) => HiveDatabase().logs.get(dateToString(date));
}
