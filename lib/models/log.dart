import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';

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

  late final List<DateTime>? keys;

  Future<void> save({
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
    final (int cycleDay, Phase phase) = await _compute(date, flow);
    HiveDatabase().logs.put(date, Log(
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
    ));
  }

  Future<(int, Phase)> _compute(DateTime date, Flow flow) async {
    keys ??= HiveDatabase().logs.keys.cast<DateTime>().toList()..sort();

    if (keys!.isEmpty) return (1, flow != Flow.none ? Phase.menstrual : Phase.follicular);

    final Log? last = await HiveDatabase().logs.get(keys!.last);
    if (last == null) return (1, Phase.menstrual);

    final int elapsed = date.difference(last.date).inDays.clamp(1, 999);
    final double estimate = KalmanFilter().cycleLength;
    final int cycleDay = last.cycleDay + elapsed;

    if (flow != Flow.none && last.phase != Phase.menstrual && cycleDay > estimate * 0.75) {
      KalmanFilter().update(cycleDay.toDouble());
      return (elapsed.clamp(1, 7), Phase.menstrual);
    }

    return (cycleDay, _phase(cycleDay, flow, estimate));
  }

  Phase _phase(int cycleDay, Flow flow, double estimate) {
    if (flow != Flow.none) return Phase.menstrual;
    final int ovulationDay = (estimate - 14).round();
    if (cycleDay < ovulationDay - 1) return Phase.follicular;
    if (cycleDay <= ovulationDay + 1) return Phase.ovulatory;
    return Phase.luteal;
  }

  Future<Log?> get(final DateTime date) => HiveDatabase().logs.get(date);
}
