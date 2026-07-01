import 'package:flutter_test/flutter_test.dart';

import '../tools/generate_embeddings.dart';
import '../tools/generate_seeds.dart';

void main() {
  test('generate_embeddings', generateEmbeddings, timeout: Timeout.none);
  test('generate_seeds', generateSeeds);
}