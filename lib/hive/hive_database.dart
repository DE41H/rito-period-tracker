import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'hive_registrar.g.dart';

import 'package:buritto/models/log.dart';
import 'package:buritto/hive/hive_encryption.dart';
import 'package:buritto/models/message.dart';

class HiveDatabase {
  static final HiveDatabase _instance = HiveDatabase._internal();
  factory HiveDatabase() => _instance;
  HiveDatabase._internal();

  late final Box<dynamic> _settingsBox;
  late final Box<dynamic> _statisticsBox;
  late final LazyBox<Message> _messageBox;
  late final LazyBox<Log> _logBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapters();
    final HiveAesCipher cipher = await HiveEncryption().cipher;
    final (settingsBox, statisticsBox, messageBox, logBox) = await (
      Hive.openBox('settings', encryptionCipher: cipher),
      Hive.openBox('statistics', encryptionCipher: cipher),
      Hive.openLazyBox<Message>('messages', encryptionCipher: cipher),
      Hive.openLazyBox<Log>('logs', encryptionCipher: cipher),
    ).wait;
    _settingsBox = settingsBox;
    _statisticsBox = statisticsBox;
    _messageBox = messageBox;
    _logBox = logBox;
  }

  Box<dynamic> get settings => _settingsBox;
  Box<dynamic> get statistics => _statisticsBox;
  LazyBox<Message> get messages => _messageBox;
  LazyBox<Log> get logs => _logBox;
}
