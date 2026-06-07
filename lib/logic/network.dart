import 'dart:isolate';
import 'dart:convert';

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
      _eventMonitor = await Isolate.run(() => BayesEventMonitor.fromJsonEncoded(snapshot));
    }
    await _rebuildNetwork();
  }

  void notifyEvent(final Log log, final Log? prev) {
    _eventMonitor.notifyEvent(_toEvent(log, prev));
  }

  void _save() {
    HiveDatabase().statistics.put('bayesianEventMonitor', _eventMonitor.toJsonEncoded(pretty: false));
  }

  String? _load() {
    return HiveDatabase().statistics.get('bayesianEventMonitor');
  }

  Future<void> commit() async {
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
    return await Isolate.run(() => BayesEventMonitor.fromJsonEncoded(json));
  }

  Future<void> _rebuildNetwork() async {
    final String json = _eventMonitor.toJsonEncoded(pretty: false);
    _network = await Isolate.run(() => BayesNetwork.buildFromJson(json));
  }

  static BayesianNetwork buildFromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final raw = (data['eventsCount'] as List<dynamic>).cast<Map<String, dynamic>>();

    if (raw.isEmpty) {
      return BayesianNetwork(data['name'] as String? ?? 'empty');
    }

    final events = <_ParsedEvent>[];
    final varValues = <String, Set<String>>{};
    final order = <String>[];

    for (final entry in raw) {
      final values = (entry['event']['values'] as List<dynamic>).cast<String>();
      final eventMap = <String, String>{};
      for (final v in values) {
        final eq = v.indexOf('=');
        final name = v.substring(0, eq);
        final val = v.substring(eq + 1);
        eventMap[name] = val;
        (varValues[name] ??= <String>{}).add(val);
        if (!order.contains(name)) order.add(name);
      }
      events.add(_ParsedEvent(eventMap, entry['count'] as int));
    }

    final indexOf = <String, int>{
      for (var i = 0; i < order.length; i++) order[i]: i,
    };
    const maxParents = 2;
    final net = BayesianNetwork(data['name'] as String? ?? 'custom');

    for (final varName in order) {
      final values = varValues[varName]!.toList()..sort();
      final idx = indexOf[varName]!;
      final parentsStart = (idx - maxParents).clamp(0, idx);
      final parents = order.sublist(parentsStart, idx);
      net.addVariable(varName, values, parents,
          _computeProbabilities(varName, values, parents, events),
          unseenMinimalProbability: 1e-7);
    }

    return net;
  }

  static List<String> _computeProbabilities(
    String varName,
    List<String> values,
    List<String> parents,
    List<_ParsedEvent> events,
  ) {
    final jointCounts = <String, Map<String, int>>{};

    for (final e in events) {
      final v = e.values[varName];
      if (v == null) continue;

      String key;
      if (parents.isEmpty) {
        key = '';
      } else {
        final pv = [for (final p in parents) e.values[p]];
        if (pv.any((x) => x == null)) continue;
        key = [
          for (var i = 0; i < parents.length; i++) '${parents[i]}=${pv[i]}',
        ].join(', ');
      }
      jointCounts
          .putIfAbsent(key, () => {for (final x in values) x: 0})
          .update(v, (c) => c + e.count, ifAbsent: () => e.count);
    }

    if (jointCounts.isEmpty) {
      return [for (final v in values) '$varName = $v: ${1.0 / values.length}'];
    }

    return [
      for (final entry in jointCounts.entries)
        if (entry.value.values.fold<int>(0, (s, c) => s + c) > 0)
          for (final v in values)
            '${entry.key}${entry.key.isEmpty ? '' : ', '}$varName = $v: ${entry.value[v]! / entry.value.values.fold<int>(0, (s, c) => s + c)}',
    ];
  }



  BayesAnalyser get analyser => _network.analyser;
}

class _ParsedEvent {
  final Map<String, String> values;
  final int count;
  const _ParsedEvent(this.values, this.count);
}
