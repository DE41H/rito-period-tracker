import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';
import 'package:buritto/models/log.dart';
import 'package:statistics/statistics.dart';

class Network {
  static final Network _instance = Network._internal();
  factory Network() => _instance;
  Network._internal();

  late final BayesEventMonitor _eventMonitor;
  late BayesianNetwork _network;

  void init() {
    final String? snapshot = _load();
    if (snapshot == null) {
      _eventMonitor = BayesEventMonitor('cycleMonitor');
      _seedPopulation();
      _save();
    } else {
      _eventMonitor = BayesEventMonitor.fromJsonEncoded(snapshot);
    }
    _rebuildNetwork();
  }

  void notifyEvent(Log log) {
    if (log.cycleDay / KalmanFilter().estimate)

    _eventMonitor.notifyEvent([event]);
  }

  void _seedPopulation() {

  }

  void _rebuildNetwork() {
    _network = _eventMonitor.buildBayesianNetwork();
  }

  void _save() {
    HiveDatabase().statistics.put('bayesianEventMonitor', _eventMonitor.toJsonEncoded(pretty: false));
  }

  String? _load() {
    return HiveDatabase().statistics.get('bayesianEventMonitor');
  }

  BayesAnalyser get analyser => _network.analyser;
}