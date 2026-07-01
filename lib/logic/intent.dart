import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

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
  static const _threshold = 0.8;

  IsolateInterpreter? _interpreter;
  Interpreter? _address;
  WordPieceTokenizer? _tokenizer;

  late final List<(Float32List, String)> _embeddings;

  final Map<String, Future<void> Function(String)> _registry = {
    "create_log": MessageRepo().createLog,
    "delete_log": MessageRepo().deleteLog,
    "view_list": MessageRepo().viewList,
    "view_log": MessageRepo().viewLog,
  };

  Future<void> init() async {
    await (
      initInterpreter(),
      initTokenizer(),
    ).wait;
  }

  Future<void> initInterpreter() async {
    _address = await Interpreter.fromAsset("assets/models/$_model.tflite", options: InterpreterOptions()..threads = 2);
    _interpreter = await IsolateInterpreter.create(address: _address!.address);
  }

  Future<void> initTokenizer() async {
    final raw = await rootBundle.loadString("assets/models/vocab.txt");
    final vocab = VocabLoader.fromString(raw);
    _tokenizer = WordPieceTokenizer(vocab: vocab, config: const TokenizerConfig(normalizeText: true, maxLength: 128));
  }

  Future<void> process(final String message) async {
    final Float32List output = await _embed(message);

    String? answer;
    double score = 0;

    for (final embedding in _embeddings) {
      final currScore = _cosine(output, embedding.$1);
      if (score < currScore) {
        answer = embedding.$2;
        score = currScore;
      }
    }

    if (score < _threshold || answer == null) {
      MessageRepo().reply("I didn't quite understand that.");
      return;
    }
    if (_registry.keys.contains(answer)) {
      await _registry[answer]!(message);
      return;
    }
    MessageRepo().reply(answer);
  }

  Future<void> load() async {

  }

  Future<Float32List> _embed(final String message) async {
    final input = _tokenizer!.encode(message);
    final result = [List.filled(_dim, 0.0)];
    await _interpreter!.runForMultipleInputs([[input.inputIds], [input.attentionMask]], {0: result});
    return _normalize(Float32List.fromList(result[0]));
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
