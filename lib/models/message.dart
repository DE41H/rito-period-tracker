import 'dart:collection';

import 'package:buritto/hive/hive_database.dart';

class Message {
  const Message({
    required this.content,
    this.isInput = true,
  });

  final String content;
  final bool isInput;
}

class MessageRepo {
  static final MessageRepo _instance = MessageRepo._internal();
  factory MessageRepo() => _instance;
  MessageRepo._internal();

  final Map<int, Future<Message?>> _futures = {};
  Map<int, Future<Message?>> get futures => UnmodifiableMapView(_futures);

  Future<Message?> get(final int i) {
    _futures[i] ??= HiveDatabase().messages.getAt(i);
    return _futures[i]!;
  }

  void send(final String content, final bool isInput) {
    if (content.isEmpty) return;
    HiveDatabase().messages.add(Message(content: content, isInput: isInput));
  }
}
