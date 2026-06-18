import 'package:buritto/hive/hive_encryption.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/message.dart';
import 'package:buritto/models/quantum.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'hive_registrar.g.dart';

class HiveDatabase {
  static final HiveDatabase _instance = HiveDatabase._internal();
  factory HiveDatabase() => _instance;
  HiveDatabase._internal();

  late final Box<dynamic> _settingsBox;
  Box<dynamic> get settings => _settingsBox;

  late final Box<dynamic> _statisticsBox;
  Box<dynamic> get statistics => _statisticsBox;

  late final LazyBox<Message> _messageBox;
  LazyBox<Message> get messages => _messageBox;

  late final LazyBox<Log> _logBox;
  LazyBox<Log> get logs => _logBox;

  late final LazyBox<QuantumLog> _predictionBox;
  LazyBox<QuantumLog> get predictions => _predictionBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapters();
    final HiveAesCipher cipher = await HiveEncryption().cipher;
    final boxes = await (
      Hive.openBox<dynamic>('settings', encryptionCipher: cipher),
      Hive.openBox<dynamic>('statistics', encryptionCipher: cipher),
      Hive.openLazyBox<Message>('messages', encryptionCipher: cipher),
      Hive.openLazyBox<Log>('logs', encryptionCipher: cipher),
      Hive.openLazyBox<QuantumLog>('predictions', encryptionCipher: cipher),
    ).wait;
    _settingsBox = boxes.$1;
    _statisticsBox = boxes.$2;
    _messageBox = boxes.$3;
    _logBox = boxes.$4;
    _predictionBox = boxes.$5;
  }
}
