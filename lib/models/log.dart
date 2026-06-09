import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/network.dart';
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

  static Log fromJson(final Map<String, dynamic> json) => Log(
    date: LogRepo().stringToDate(json['date'] as String),
    cycleDay: json['cycleDay'] as int,
    ovulating: json['ovulating'] as bool,
    phase: Phase.values[json['phase'] as int],
    flow: Flow.values[json['flow'] as int],
    symptoms: (json['symptoms'] as List).cast<int>().map((i) => Symptom.values[i]).toSet(),
    moods: (json['moods'] as List).cast<int>().map((i) => Mood.values[i]).toSet(),
    discharge: json['discharge'] != null ? Discharge.values[json['discharge'] as int] : null,
    stress: json['stress'] != null ? Stress.values[json['stress'] as int] : null,
    sleep: json['sleep'] != null ? Sleep.values[json['sleep'] as int] : null,
    sex: json['sex'] != null ? Sex.values[json['sex'] as int] : null,
    notes: json['notes'] as String?,
  );
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

    return true;
  });

  Future<(int, Phase)> _compute(final DateTime date, final Flow flow, final List<String> keys, final int index, [final bool recompute = false]) async {
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
