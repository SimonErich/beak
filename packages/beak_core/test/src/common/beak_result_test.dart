import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const BeakException notFound = BeakNotFoundException(
    'Product 42 does not exist.',
  );

  group('BeakOk', () {
    const BeakResult<int> result = BeakOk(2);

    test('isOk is true', () {
      expect(result.isOk, isTrue);
    });

    test('valueOrThrow returns the wrapped value', () {
      expect(result.valueOrThrow, 2);
    });

    test('fold reduces via onOk', () {
      final folded = result.fold(
        onOk: (value) => 'ok:$value',
        onErr: (error) => 'err:${error.code}',
      );
      expect(folded, 'ok:2');
    });

    test('map transforms the value and stays ok', () {
      final mapped = result.map((value) => 'v$value');
      expect(mapped, isA<BeakOk<String>>());
      expect(mapped.valueOrThrow, 'v2');
    });

    test('pattern-matches as BeakOk exposing its value', () {
      switch (result) {
        case BeakOk(:final value):
          expect(value, 2);
        case BeakErr():
          fail('expected a BeakOk');
      }
    });
  });

  group('BeakErr', () {
    const BeakResult<int> result = BeakErr(notFound);

    test('isOk is false', () {
      expect(result.isOk, isFalse);
    });

    test('valueOrThrow throws the exact wrapped exception', () {
      expect(() => result.valueOrThrow, throwsA(same(notFound)));
    });

    test('fold reduces via onErr', () {
      final folded = result.fold(
        onOk: (value) => 'ok:$value',
        onErr: (error) => 'err:${error.code}',
      );
      expect(folded, 'err:not_found');
    });

    test('map keeps the error and never invokes the transform', () {
      final mapped = result.map<String>((value) {
        fail('transform must not be invoked on a BeakErr');
      });
      expect(mapped, isA<BeakErr<String>>());
      expect(() => mapped.valueOrThrow, throwsA(same(notFound)));
    });

    test('pattern-matches as BeakErr exposing its error', () {
      switch (result) {
        case BeakOk():
          fail('expected a BeakErr');
        case BeakErr(:final error):
          expect(error, same(notFound));
      }
    });
  });
}
