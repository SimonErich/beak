import 'dart:math';

import 'package:beak_backend/beak_backend.dart';
import 'package:test/test.dart';

void main() {
  final v4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('produces RFC 4122 v4 ids', () {
    for (var i = 0; i < 32; i += 1) {
      expect(generateUuidV4(), matches(v4Pattern));
    }
  });

  test('is deterministic under an injected random source', () {
    expect(
      generateUuidV4(random: Random(7)),
      generateUuidV4(random: Random(7)),
    );
  });

  test('successive ids differ', () {
    expect(generateUuidV4(), isNot(generateUuidV4()));
  });
}
