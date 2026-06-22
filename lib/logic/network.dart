import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/mood.dart';
import 'package:buritto/models/symptom.dart';
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

  Future<void> update(final Log log) async {
    _notifyEvent(log);
    await _commit();
  }

  void _notifyEvent(final Log log) {
    final String phase = log.phase.name.toUpperCase();

    _eventMonitor.notifyEvent(['PHASE=$phase']);

    _eventMonitor.notifyEvent(['FLOW=${log.flow.name.toUpperCase()}', 'PHASE=$phase']);

    for (final s in Symptom.values) {
      final String val = log.symptoms.contains(s).toString().toUpperCase();
      _eventMonitor.notifyEvent(['SYMPTOM_${s.name.toUpperCase()}=$val', 'PHASE=$phase']);
    }
    for (final m in Mood.values) {
      final String val = log.moods.contains(m).toString().toUpperCase();
      _eventMonitor.notifyEvent(['MOOD_${m.name.toUpperCase()}=$val', 'PHASE=$phase']);
    }
    if (log.discharge != null) {
      _eventMonitor.notifyEvent(['DISCHARGE=${log.discharge!.name.toUpperCase()}', 'PHASE=$phase']);
    }
    if (log.stress != null) {
      _eventMonitor.notifyEvent(['STRESS=${log.stress!.name.toUpperCase()}', 'PHASE=$phase']);
    }
    if (log.sleep != null) {
      _eventMonitor.notifyEvent(['SLEEP=${log.sleep!.name.toUpperCase()}', 'PHASE=$phase']);
    }
    if (log.sex != null) {
      _eventMonitor.notifyEvent(['SEX=${log.sex!.name.toUpperCase()}', 'PHASE=$phase']);
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

  Future<void> reseed(final bool pcos) async {
    _eventMonitor = await _loadSeed(pcos);

    await for (final log in LogRepo().all) {
      _notifyEvent(log);
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
