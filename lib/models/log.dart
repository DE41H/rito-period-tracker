import 'package:collection/collection.dart';

import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/network.dart';

class Log {
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
}

enum Sex {
  protected(0),
  unprotected(1);

  final int value;
  const Sex(this.value);
}

enum Phase {
  menstrual(0),
  follicular(1),
  ovulatory(2),
  luteal(3);

  final int value;
  const Phase(this.value);
}

enum Sleep {
  poor(0),
  average(1),
  excellent(2);

  final int value;
  const Sleep(this.value);
}

enum Stress {
  low(0),
  medium(1),
  high(2);

  final int value;
  const Stress(this.value);
}

enum Flow {
  none(0),
  light(1),
  medium(2),
  heavy(3);

  final int value;
  const Flow(this.value);
}

enum Symptom {
  periodCramps(0),
  ovulationPain(1),
  tenderBreasts(2),
  headache(3),
  fatigue(4),
  bloating(5),
  acne(6);

  final int value;
  const Symptom(this.value);
}

enum Mood {
  happy(0),
  highLibido(1),
  irritable(2),
  anxious(3),
  depressed(4),
  exhausted(5);

  final int value;
  const Mood(this.value);
}

enum Discharge {
  dry(0),
  sticky(1),
  creamy(2),
  watery(3),
  eggwhite(4);

  final int value;
  const Discharge(this.value);
}

class LogRepo {
  static final LogRepo _instance = LogRepo._internal();
  factory LogRepo() => _instance;
  LogRepo._internal();

  static String dateToString(DateTime date) => date.toIso8601String();
  static DateTime stringToDate(String string) => DateTime.parse(string);

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
  }) async {
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
        await HiveDatabase().logs.put(k, Log(
          date: old.date,
          cycleDay: cd,
          ovulating: KalmanFilter().ovulationDay == cd,
          phase: ph,
          flow: old.flow,
          symptoms: old.symptoms,
          moods: old.moods,
          discharge: old.discharge,
          stress: old.stress,
          sleep: old.sleep,
          sex: old.sex,
          notes: old.notes,
        ));
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

    return true;
  }

  Future<(int, Phase)> _compute(DateTime date, Flow flow, List<String> keys, int index, [bool recompute = false]) async {
    final String? prevKey = (index > 0) ? keys[index - 1] : null;
    if (prevKey == null) return (1, flow != Flow.none ? Phase.menstrual : Phase.follicular);

    final Log last = (await HiveDatabase().logs.get(prevKey))!;
    final int cycleDay = KalmanFilter().predictCycleDay(date, last);

    if (!recompute && flow == Flow.none && last.phase == Phase.menstrual) {
      KalmanFilter().updatePeriod(last.cycleDay.toDouble());
    }
    if (flow != Flow.none && last.phase != Phase.menstrual && cycleDay > KalmanFilter().cycleLength * 0.5) {
      if (!recompute) KalmanFilter().updateCycle(cycleDay.toDouble());
      return (1, Phase.menstrual);
    }
    return (cycleDay, KalmanFilter().predictPhase(cycleDay, flow));
  }


  Future<Log?> get(final DateTime date) => HiveDatabase().logs.get(dateToString(date));
}
