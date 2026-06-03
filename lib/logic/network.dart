import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:statistics/statistics.dart';

import 'package:buritto/models/log.dart';
import 'package:buritto/hive/hive_database.dart';

class BayesNetwork {
  static final BayesNetwork _instance = BayesNetwork._internal();
  factory BayesNetwork() => _instance;
  BayesNetwork._internal();

  late final BayesEventMonitor _eventMonitor;
  late BayesianNetwork _network;

  Future<void> init() async {
    final String? snapshot = _load();
    if (snapshot == null) {
      _eventMonitor = await _loadSeed();
      _save();
    } else {
      _eventMonitor = BayesEventMonitor.fromJsonEncoded(snapshot);
    }
    await _rebuildNetwork();
  }

  void notifyEvent(final Log log, final Log? prev) {
    _eventMonitor.notifyEvent(_toEvent(log, prev));
  }

  void commit() async {
    _save();
    await _rebuildNetwork();
  }

  List<String> _toEvent(final Log log, final Log? prev) => [
    'PHASE=${log.phase.name}',
    'FLOW=${log.flow.name}',
    for (final s in Symptom.values) 'SYMPTOM_${s.name}=${log.symptoms.contains(s)}',
    for (final m in Mood.values) 'MOOD_${m.name}=${log.moods.contains(m)}',
    if (log.discharge != null) 'DISCHARGE=${log.discharge!.name}',
    if (log.stress != null) 'STRESS=${log.stress!.name}',
    if (log.sleep != null) 'SLEEP=${log.sleep!.name}',
    if (log.sex != null) 'SEX=${log.sex!.name}',
    if (prev != null) 'PREV_PHASE=${prev.phase.name}',
    if (prev != null) 'PREV_FLOW=${prev.flow.name}',
  ];

  Future<BayesEventMonitor> _loadSeed() async {
    final bool hasPcos = HiveDatabase().settings.get('hasPcos', defaultValue: false) as bool;
    final String profile = hasPcos ? 'pcos' : 'normal';
    final String json = await rootBundle.loadString('assets/population/network_$profile.json');
    return BayesEventMonitor.fromJsonEncoded(json);
  }

  Future<void> _rebuildNetwork() async {
    _network = await Isolate.run(() => _eventMonitor.buildBayesianNetwork());
  }

  void _save() {
    HiveDatabase().statistics.put('bayesianEventMonitor', _eventMonitor.toJsonEncoded(pretty: false));
  }

  String? _load() {
    return HiveDatabase().statistics.get('bayesianEventMonitor');
  }

  BayesAnalyser get analyser => _network.analyser;
}
