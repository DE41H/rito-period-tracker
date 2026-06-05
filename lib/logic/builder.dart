import 'dart:convert';

import 'package:statistics/statistics.dart';

class BayesNetworkBuilder {
  static BayesianNetwork buildFromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final eventsCount = (data['eventsCount'] as List<dynamic>).cast<Map<String, dynamic>>();

    if (eventsCount.isEmpty) {
      return BayesianNetwork(data['name'] as String? ?? 'empty');
    }

    final varValues = <String, Set<String>>{};
    for (final entry in eventsCount) {
      final event = entry['event'] as Map<String, dynamic>;
      final values = (event['values'] as List<dynamic>).cast<String>();
      for (final v in values) {
        final eq = v.indexOf('=');
        final name = v.substring(0, eq);
        final value = v.substring(eq + 1);
        varValues.putIfAbsent(name, () => <String>{}).add(value);
      }
    }

    final order = _deriveTopologicalOrder(eventsCount, varValues.keys.toSet());

    final net = BayesianNetwork(data['name'] as String? ?? 'custom');

    const maxParents = 2;
    for (final varName in order) {
      final values = varValues[varName]!.toList()..sort();
      final idx = order.indexOf(varName);
      final parentsStart = (idx - maxParents).clamp(0, idx);
      final parents = order.sublist(parentsStart, idx);
      final probabilities = _computeProbabilities(
        varName, values, parents, eventsCount,
      );
      net.addVariable(varName, values, parents, probabilities,
          unseenMinimalProbability: 1e-7);
    }

    return net;
  }

  static List<String> _deriveTopologicalOrder(
    List<Map<String, dynamic>> eventsCount,
    Set<String> allVariables,
  ) {
    final order = <String>[];
    final seen = <String>{};

    for (final entry in eventsCount) {
      final event = entry['event'] as Map<String, dynamic>;
      final values = (event['values'] as List<dynamic>).cast<String>();
      for (final v in values) {
        final eq = v.indexOf('=');
        final name = v.substring(0, eq);
        if (seen.add(name)) order.add(name);
      }
      if (seen.length == allVariables.length) break;
    }

    for (final name in allVariables) {
      if (seen.add(name)) order.add(name);
    }

    return order;
  }

  static List<String> _computeProbabilities(
    String varName,
    List<String> values,
    List<String> parents,
    List<Map<String, dynamic>> eventsCount,
  ) {
    if (parents.isEmpty) {
      final counts = <String, int>{for (final v in values) v: 0};
      int total = 0;
      for (final entry in eventsCount) {
        final event = entry['event'] as Map<String, dynamic>;
        final eventValues = (event['values'] as List<dynamic>).cast<String>();
        final count = entry['count'] as int;
        for (final v in eventValues) {
          final eq = v.indexOf('=');
          if (v.substring(0, eq) == varName) {
            final value = v.substring(eq + 1);
            if (counts.containsKey(value)) {
              counts[value] = counts[value]! + count;
              total += count;
            }
            break;
          }
        }
      }
      if (total == 0) {
        return [for (final v in values) '$varName = $v: ${1.0 / values.length}'];
      }
      return [
        for (final v in values) '$varName = $v: ${counts[v]! / total}',
      ];
    }

    final jointCounts = <String, Map<String, int>>{};

    for (final entry in eventsCount) {
      final event = entry['event'] as Map<String, dynamic>;
      final eventValues = (event['values'] as List<dynamic>).cast<String>();
      final count = entry['count'] as int;

      String? varValue;
      final parentValues = <String, String>{};
      for (final v in eventValues) {
        final eq = v.indexOf('=');
        final name = v.substring(0, eq);
        final value = v.substring(eq + 1);
        if (name == varName) varValue = value;
        if (parents.contains(name)) parentValues[name] = value;
      }
      if (varValue == null) continue;
      if (parentValues.length != parents.length) continue;

      final parentKey = parents.map((p) => '$p=${parentValues[p]}').join(', ');

      jointCounts
          .putIfAbsent(parentKey, () => {for (final v in values) v: 0})
          .update(varValue, (c) => c + count, ifAbsent: () => count);
    }

    final probs = <String>[];
    for (final entry in jointCounts.entries) {
      final total = entry.value.values.fold<int>(0, (s, c) => s + c);
      if (total == 0) continue;
      for (final v in values) {
        final c = entry.value[v] ?? 0;
        probs.add('${entry.key}, $varName = $v: ${c / total}');
      }
    }

    if (probs.isEmpty) {
      return [for (final v in values) '$varName = $v: ${1.0 / values.length}'];
    }

    return probs;
  }
}
