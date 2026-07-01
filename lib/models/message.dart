import 'dart:async';
import 'dart:collection';

import 'package:buritto/app.dart';
import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/intent.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/sheets/create_log.dart';
import 'package:chrono_dart/chrono_dart.dart';
import 'package:flutter/material.dart';

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

  final TextEditingController controller = TextEditingController();

  final Map<int, Future<Message?>> _futures = {};
  Map<int, Future<Message?>> get futures => UnmodifiableMapView(_futures);

  Future<Message?> get(final int i) {
    _futures[i] ??= HiveDatabase().messages.getAt(i);
    return _futures[i]!;
  }

  Future<void> send(final String content) async {
    if (content.isEmpty) return;
    controller.clear();
    await (
      IntentJudge().process(content),
      HiveDatabase().messages.add(Message(content: content, isInput: true)),
    ).wait;
  }

  void reply(final String content) {
    if (content.isEmpty) return;
    HiveDatabase().messages.add(Message(content: content, isInput: false));
    controller.clear();
  }

  Future<void> viewLog(final String message) async {
    final DateTime? date = Chrono.parseDate(message);
    if (date == null) {
      reply("You have to provide a date to search for!");
      return;
    }
    final key = LogRepo().dateToString(date);
    if (!HiveDatabase().logs.containsKey(key)) {
      reply("There exists no Log on ${date.day}/${date.month}/${date.year}!");
      return;
    }
    final Log log = (await HiveDatabase().logs.get(key))!;
    reply(log.toString());
  }

  Future<void> viewList(final String message) async {
    final keys = HiveDatabase().logs.keys.cast<String>();
    final dates = keys.map((k) => LogRepo().stringToDate(k));
    final StringBuffer buffer = StringBuffer();
    buffer.writeln("Logs exist on these dates:");
    for (var date in dates) {
      buffer.writeln("- ${date.day}/${date.month}/${date.year}");
    }
    reply(buffer.toString());
  }

  Future<void> deleteLog(final String message) async {
    final DateTime? date = Chrono.parseDate(message);
    if (date == null) {
      reply("You have to provide a date of the Log to delete!");
      return;
    }
    final key = LogRepo().dateToString(date);
    if (!HiveDatabase().logs.containsKey(key)) {
      reply("There exists no Log on ${date.day}/${date.month}/${date.year}!");
      return;
    }
    unawaited(HiveDatabase().logs.delete(key));
    reply("The Log on ${date.day}/${date.month}/${date.year} was successfully deleted!");
  }

  Future<void> createLog(final String message) async {
    reply("Here is the Log creation menu...");
    final context = navigatorKey.currentContext;
    if (context == null) {
      reply("Error! Please try again...");
      return;
    }
    CreateLogModal().show(context);
  }
}
