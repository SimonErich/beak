/// Unit tests for [DurationCast] — verifies the cast in isolation
/// against the Duration ↔ millisecond-integer contract.
library;

import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('DurationCast', () {
    const cast = DurationCast();

    test('decode(5000) returns Duration(milliseconds: 5000)', () {
      expect(cast.decode(5000), const Duration(milliseconds: 5000));
    });

    test('encode(Duration(milliseconds: 5000)) returns 5000 as int', () {
      final encoded = cast.encode(const Duration(milliseconds: 5000));
      expect(encoded, 5000);
      expect(encoded, isA<int>());
    });

    test('decode(null) returns null', () {
      expect(cast.decode(null), isNull);
    });

    test('encode(null) returns null', () {
      expect(cast.encode(null), isNull);
    });

    test('decode(0) returns Duration.zero', () {
      expect(cast.decode(0), Duration.zero);
    });

    test('decode(non-numeric String) throws CastException', () {
      expect(() => cast.decode('not-an-int'), throwsA(isA<CastException>()));
    });
  });
}
