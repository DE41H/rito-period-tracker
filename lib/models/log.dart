import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';

class Log {
  final DateTime date;
  final int cycleDay;
  final Flow flow;
  final Set<Symptom> symptoms;
  final Set<Mood> moods;
  final Discharge? discharge;
  final Stress? stress;
  final Sleep? sleep;
  final bool? smoked;
  final bool? drank;
  final String? notes;

  const Log({
    required this.date,
    required this.cycleDay,
    required this.flow,
    this.symptoms = const {},
    this.moods = const {},
    this.discharge,
    this.stress,
    this.sleep,
    this.smoked,
    this.drank,
    this.notes,
  });
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
  const LogRepo();

  Future<void> create({
    required final DateTime date,
    required final Flow flow,
    final Set<Symptom> symptoms = const {},
    final Set<Mood> moods = const {},
    final Discharge? discharge,
    final Stress? stress,
    final Sleep? sleep,
    final bool? smoked,
    final bool? drank,
    final String? notes,
  }) async {
    final DateTime lastDate = (HiveDatabase().logs.keys.cast<DateTime>().toList()..sort()).last;
    final Log lastLog = (await get(lastDate))!;
    final int days = date.difference(lastDate).inDays;
    final int cycleDay = (days % KalmanFilter().estimate + lastLog.cycleDay).floor();
    final Log log = Log(
      date: date,
      cycleDay: cycleDay,
      flow: flow,
      symptoms: symptoms,
      moods: moods,
      discharge: discharge,
      stress: stress,
      sleep: sleep,
      smoked: smoked,
      drank: drank,
      notes: notes,
    );
    _save(log);
  }

  Future<Log?> get(final DateTime date) {
    return HiveDatabase().logs.get(date);
  }
  
  void _save(Log log) {
    HiveDatabase().logs.put(log.date, log);
  }
}
