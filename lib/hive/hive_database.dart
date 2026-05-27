import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'hive_registrar.g.dart';

import 'package:buritto/models/log.dart';
import 'package:buritto/models/cycle.dart';
import 'package:buritto/hive/hive_encryption.dart';
import 'package:buritto/models/message.dart';

class HiveDatabase {
  static final HiveDatabase _instance = HiveDatabase._internal();
  factory HiveDatabase() => _instance;
  HiveDatabase._internal();

  late final Box<dynamic> _settingsBox;
  late final LazyBox<Message> _messageBox;
  late final LazyBox<Log> _logBox;
  late final LazyBox<Cycle> _cycleBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapters();
    final HiveAesCipher cipher = await HiveEncryption().cipher;
    _settingsBox = await Hive.openBox('settings', encryptionCipher: cipher);
    _messageBox = await Hive.openLazyBox<Message>('messages', encryptionCipher: cipher);
    _logBox = await Hive.openLazyBox<Log>('logs', encryptionCipher: cipher);
    _cycleBox = await Hive.openLazyBox<Cycle>('cycles', encryptionCipher: cipher);
  }

  Box<dynamic> get settings => _settingsBox;
  LazyBox<Message> get messages => _messageBox;
  LazyBox<Log> get logs => _logBox;
  LazyBox<Cycle> get cycles => _cycleBox;
}