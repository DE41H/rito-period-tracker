import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/models/log.dart';
import 'package:flutter/services.dart';
import 'package:statistics/statistics.dart';
import 'package:worker_manager/worker_manager.dart';

class BayesNetwork {
  static final BayesNetwork _instance = BayesNetwork._internal();
  factory BayesNetwork() => _instance;
  BayesNetwork._internal();

  late BayesEventMonitor _eventMonitor;
  Cancelable<BayesEventMonitor>? seeding;

  late BayesianNetwork _network;
  Cancelable<BayesianNetwork>? rebuilding;

  BayesAnalyser get analyser => _network.analyser;

  Future<void> init() async {
    final String? snapshot = _load();
    if (snapshot == null) {
      _eventMonitor = await _loadSeed();
      _save();
    } else {
      _eventMonitor = await workerManager.execute(() => BayesEventMonitor.fromJsonEncoded(snapshot));
    }
    await _rebuildNetwork();
  }

  Future<void> update(final Log log, [Log? prev]) async {
    _notifyEvent(log, prev);
    await _commit();
  }

  void _notifyEvent(final Log log, [Log? prev]) {
    if (prev != null && log.date.difference(prev.date).inDays != 1) prev = null;
    final event = _toEvent(log, prev);
    _eventMonitor.notifyEvent(event);

    final phase = 'PHASE=${log.phase.name.toUpperCase()}';
    final flow = 'FLOW=${log.flow.name.toUpperCase()}';

    _eventMonitor.notifyDependency(['FLOW', 'PHASE'], [flow, phase]);
    for (final s in Symptom.values) {
      final sym = 'SYMPTOM_${s.name.toUpperCase()}=${log.symptoms.contains(s).toString().toUpperCase()}';
      _eventMonitor.notifyDependency(['SYMPTOM_${s.name.toUpperCase()}', 'PHASE'], [sym, phase]);
    }
    for (final m in Mood.values) {
      final mood = 'MOOD_${m.name.toUpperCase()}=${log.moods.contains(m).toString().toUpperCase()}';
      _eventMonitor.notifyDependency(['MOOD_${m.name.toUpperCase()}', 'PHASE'], [mood, phase]);
    }
    if (log.discharge != null) {
      final dis = 'DISCHARGE=${log.discharge!.name.toUpperCase()}';
      _eventMonitor.notifyDependency(['DISCHARGE', 'PHASE'], [dis, phase]);
      _eventMonitor.notifyDependency(['DISCHARGE', 'FLOW'],  [dis, flow]);
    }
    if (log.stress != null) {
      _eventMonitor.notifyDependency(['STRESS', 'PHASE'], ['STRESS=${log.stress!.name.toUpperCase()}', phase]);
    }
    if (log.sleep != null) {
      _eventMonitor.notifyDependency(['SLEEP', 'PHASE'], ['SLEEP=${log.sleep!.name.toUpperCase()}', phase]);
    }
    if (log.sex != null) {
      _eventMonitor.notifyDependency(['SEX', 'PHASE'], ['SEX=${log.sex!.name.toUpperCase()}', phase]);
    }

    _eventMonitor.notifyDependency(['SYMPTOM_PERIODCRAMPS', 'PHASE', 'FLOW'],
        ['SYMPTOM_PERIODCRAMPS=${log.symptoms.contains(Symptom.periodCramps).toString().toUpperCase()}', phase, flow]);
    _eventMonitor.notifyDependency(['SYMPTOM_BLOATING', 'PHASE', 'FLOW'],
        ['SYMPTOM_BLOATING=${log.symptoms.contains(Symptom.bloating).toString().toUpperCase()}', phase, flow]);
    _eventMonitor.notifyDependency(['SYMPTOM_FATIGUE', 'PHASE', 'FLOW'],
        ['SYMPTOM_FATIGUE=${log.symptoms.contains(Symptom.fatigue).toString().toUpperCase()}', phase, flow]);

    if (prev != null) {
      final prevPhase = 'PREV_PHASE=${prev.phase.name.toUpperCase()}';
      final prevFlow  = 'PREV_FLOW=${prev.flow.name.toUpperCase()}';
      _eventMonitor.notifyDependency(['PHASE', 'PREV_PHASE'], [phase, prevPhase]);
      _eventMonitor.notifyDependency(['FLOW', 'PREV_FLOW'],   [flow,  prevFlow]);
      _eventMonitor.notifyDependency(['FLOW', 'PHASE', 'PREV_FLOW'], [flow, phase, prevFlow]);

      for (final s in Symptom.values) {
        final sym = 'SYMPTOM_${s.name.toUpperCase()}=${log.symptoms.contains(s).toString().toUpperCase()}';
        _eventMonitor.notifyDependency(['SYMPTOM_${s.name.toUpperCase()}', 'PHASE', 'PREV_PHASE'], [sym, phase, prevPhase]);
      }
      for (final m in Mood.values) {
        final mood = 'MOOD_${m.name.toUpperCase()}=${log.moods.contains(m).toString().toUpperCase()}';
        _eventMonitor.notifyDependency(['MOOD_${m.name.toUpperCase()}', 'PHASE', 'PREV_PHASE'], [mood, phase, prevPhase]);
      }
      if (log.discharge != null) {
        _eventMonitor.notifyDependency(['DISCHARGE', 'PHASE', 'PREV_PHASE'],
            ['DISCHARGE=${log.discharge!.name.toUpperCase()}', phase, prevPhase]);
      }
      if (log.stress != null) {
        _eventMonitor.notifyDependency(['STRESS', 'PHASE', 'PREV_PHASE'],
            ['STRESS=${log.stress!.name.toUpperCase()}', phase, prevPhase]);
      }
      if (log.sleep != null) {
        _eventMonitor.notifyDependency(['SLEEP', 'PHASE', 'PREV_PHASE'],
            ['SLEEP=${log.sleep!.name.toUpperCase()}', phase, prevPhase]);
      }
      if (log.sex != null) {
        _eventMonitor.notifyDependency(['SEX', 'PHASE', 'PREV_PHASE'],
            ['SEX=${log.sex!.name.toUpperCase()}', phase, prevPhase]);
      }
    }
  }

  void _save() {
    HiveDatabase().statistics.put('bayesianEventMonitor', _eventMonitor.toJsonEncoded(pretty: false));
  }

  String? _load() {
    return HiveDatabase().statistics.get('bayesianEventMonitor') as String?;
  }

  Future<void> _commit() async {
    _save();
    await _rebuildNetwork();
  }

  List<String> _toEvent(final Log log, final Log? prev) => [
    'PHASE=${log.phase.name.toUpperCase()}',
    'FLOW=${log.flow.name.toUpperCase()}',
    for (final s in Symptom.values) 'SYMPTOM_${s.name.toUpperCase()}=${log.symptoms.contains(s).toString().toUpperCase()}',
    for (final m in Mood.values) 'MOOD_${m.name.toUpperCase()}=${log.moods.contains(m).toString().toUpperCase()}',
    if (log.discharge != null) 'DISCHARGE=${log.discharge!.name.toUpperCase()}',
    if (log.stress != null) 'STRESS=${log.stress!.name.toUpperCase()}',
    if (log.sleep != null) 'SLEEP=${log.sleep!.name.toUpperCase()}',
    if (log.sex != null) 'SEX=${log.sex!.name.toUpperCase()}',
    if (prev != null) 'PREV_PHASE=${prev.phase.name.toUpperCase()}',
    if (prev != null) 'PREV_FLOW=${prev.flow.name.toUpperCase()}',
  ];

  Future<void> reseed(final bool pcos) async {
    _eventMonitor = await _loadSeed(pcos);

    Log? prev;
    for (final key in HiveDatabase().logs.keys.cast<String>()) {
      final Log log = (await HiveDatabase().logs.get(key))!;
      _notifyEvent(log, prev);
      prev = log;
    }

    await _commit();
  }

  Future<BayesEventMonitor> _loadSeed([final bool? pcos]) async {
    final bool hasPcos = (pcos != null) ? pcos : HiveDatabase().settings.get('hasPcos', defaultValue: false) as bool;
    final String profile = hasPcos ? 'pcos' : 'normal';
    final String json = await rootBundle.loadString('assets/population/network_$profile.json');
    seeding?.cancel();
    seeding = workerManager.execute(() => BayesEventMonitor.fromJsonEncoded(json));
    return await seeding!;
  }

  Future<void> _rebuildNetwork() async {
    final String json = _eventMonitor.toJsonEncoded(pretty: false);
    rebuilding?.cancel();
    rebuilding = workerManager.execute(() => BayesEventMonitor.fromJsonEncoded(json).buildBayesianNetwork());
    _network = await rebuilding!;
  }
}
