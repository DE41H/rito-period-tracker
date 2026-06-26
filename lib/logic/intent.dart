import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/models/message.dart';
import 'package:dart_wordpiece/dart_wordpiece.dart';
import 'package:flutter/services.dart';
import 'package:statistics/statistics.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class IntentJudge {
  static final IntentJudge _instance = IntentJudge._internal();
  factory IntentJudge() => _instance;
  IntentJudge._internal();

  static const int _dim = 384;
  static const String _model = "minilm";
  static const _threshold = 0.5;

  IsolateInterpreter? _interpreter;
  Interpreter? _address;
  WordPieceTokenizer? _tokenizer;

  final List<(String, List<String>, Future<void> Function(String))> _registry = [
    ("create_log", ["log today", "add a new log", "record today's symptoms", "track what I'm feeling now", "create a new entry"], MessageRepo().createLog),
    ("delete_log", ["delete a log", "remove a log", "erase a log entry", "get rid of a log", "permanently delete an entry"], MessageRepo().deleteLog),
    ("view_list", ["show all my logs", "list all logs", "view all logs", "what logs do I have", "browse all my entries"], MessageRepo().viewList),
    ("view_log", ["show my log for a date", "what did I log on a specific day", "view my entry from last week", "open the log from yesterday", "check what I recorded on a date"], MessageRepo().viewLog),
  ];
  final Future<void> Function(String) _fallback = MessageRepo().confused;
  final List<Intent> _intents = [];

  Future<void> init() async {
    final future = await (
      () async {
        _address = await Interpreter.fromAsset("assets/models/$_model.tflite", options: InterpreterOptions()..threads = 2);
        _interpreter = await IsolateInterpreter.create(address: _address!.address);
      }(),
      rootBundle.loadString("assets/models/vocab.txt"),
    ).wait;

    final raw = future.$2;
    final vocab = VocabLoader.fromString(raw);
    _tokenizer = WordPieceTokenizer(vocab: vocab, config: const TokenizerConfig(normalizeText: true, maxLength: 128));

    for (final item in _registry) {
      final List<(String, Float32List)> examples = [];
      for (final example in item.$2) {
        final Float32List embedding;
        final Uint8List bytes;
        if (HiveDatabase().embeddings.containsKey(example)) {
          bytes = (await HiveDatabase().embeddings.get(example))!;
          embedding = bytes.buffer.asFloat32List();
        } else {
          embedding = await _embed(example);
          bytes = embedding.buffer.asUint8List();
          unawaited(HiveDatabase().embeddings.put(example, bytes));
        }
        examples.add((example, embedding));
      }
      final intent = Intent(label: item.$1, examples: examples, handler: item.$3);
      _intents.add(intent);
    }
  }

  Future<void> process(final String message) async {
    final Float32List output = await _embed(message);

    Intent? guess;
    double score = 0;

    for (final intent in _intents) {
      for (final example in intent.examples) {
        final currScore = _cosine(output, example.$2);
        if (score < currScore) {
          guess = intent;
          score = currScore;
        }
      }
    }

    if (score < _threshold || guess == null) {
      await _fallback(message);
      return;
    }

    await guess.handler(message);
  }

  Future<Float32List> _embed(final String message) async {
    final input = _tokenizer!.encode(message);
    final inputIds = [input.inputIds];
    final attentionMask = [input.attentionMask];
    // final tokenTypeIds = [input.tokenTypeIds];

    final List<Float32List> result = [Float32List.fromList(List.filled(_dim, 0.0))];

    await _interpreter!.runForMultipleInputs([inputIds, attentionMask], {0: result});
    final normalized = _normalize(result[0]);
    return normalized;
  }

  double _cosine(final Float32List a, final Float32List b) {
    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  Float32List _normalize(final Float32List vec) {
    final double mag = sqrt(vec.sumSquares);
    if (mag == 0.0) return vec;
    return Float32List.fromList(vec.map((x) => x / mag).toList(growable: false));
  }
}

class Intent {
  const Intent({
    required this.label,
    required this.examples,
    required this.handler,
  });

  final String label;
  final List<(String, Float32List)> examples;
  final Future<void> Function(String) handler;
}
