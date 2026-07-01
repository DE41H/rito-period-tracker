import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_wordpiece/dart_wordpiece.dart';
import 'package:messagepack/messagepack.dart';
import 'package:statistics/statistics.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

const int _dim = 384;

void generateEmbeddings() async {
  final vocabRaw = await File('assets/models/vocab.txt').readAsString();
  final vocab = VocabLoader.fromString(vocabRaw);
  final tokenizer = WordPieceTokenizer(
    vocab: vocab,
    config: const TokenizerConfig(normalizeText: true, maxLength: 128),
  );

  final interpreter = Interpreter.fromFile(
    File('assets/models/minilm.tflite'),
    options: InterpreterOptions()..threads = 4,
  );

  stdout.write('Generating embeddings... ');

  final entriesRaw = await File('tools/convo.jsonl').readAsString();
  final entries = const LineSplitter().convert(entriesRaw).map((ele) {
    final json = (jsonDecode(ele) as Map).cast<String, String>();
    final entry = json.entries.first;
    final embedding = _embed(interpreter, tokenizer, entry.key);
    final bytes = embedding.buffer.asUint8List(embedding.offsetInBytes, embedding.lengthInBytes);
    return (bytes, entry.key, entry.value);
  });

  final packer = Packer();
  packer.packListLength(entries.length);
  for (final entry in entries) {
    packer.packBinary(entry.$1);
    packer.packString(entry.$2);
    packer.packString(entry.$3);
  }

  final bytes = packer.takeBytes();
  await File("assets/models/convo.bin").writeAsBytes(bytes);

  interpreter.close();
  stdout.write('saved (assets/models/convo.bin)\n');
}

Float32List _embed(Interpreter interpreter, WordPieceTokenizer tokenizer, String text) {
  final input = tokenizer.encode(text);
  final result = [List.filled(_dim, 0.0)];
  interpreter.runForMultipleInputs([[input.inputIds], [input.attentionMask]], {0: result});
  return _normalize(Float32List.fromList(result[0]));
}

Float32List _normalize(final Float32List vec) {
  final double mag = sqrt(vec.sumSquares);
  if (mag == 0.0) return vec;
  return Float32List.fromList(vec.map((x) => x / mag).toList(growable: false));
}
