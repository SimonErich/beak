import 'package:test/test.dart';
import 'package:worm/worm.dart';

void main() {
  group('Sequence', () {
    test('next returns monotonically increasing values', () {
      final seq = Sequence();
      expect(seq.next(), 1);
      expect(seq.next(), 2);
      expect(seq.next(), 3);
    });

    test('custom start applies from the first call', () {
      final seq = Sequence(start: 100);
      expect(seq.next(), 100);
      expect(seq.next(), 101);
    });

    test('reset returns to the configured start', () {
      final seq = Sequence(start: 5)
        ..next()
        ..next()
        ..reset();
      expect(seq.next(), 5);
    });

    test('peek does not advance the sequence', () {
      final seq = Sequence()..next();
      expect(seq.peek, 2);
      expect(seq.next(), 2);
    });

    test('next() returns sequential values — call N returns f(N) where '
        'f(N) = start + N', () {
      final seq = Sequence(start: 0);
      expect(seq.next(), 0); // f(0)
      expect(seq.next(), 1); // f(1)
      expect(seq.next(), 2); // f(2)
    });

    test('FactorySequence alias resolves to the same Sequence class', () {
      // The typedef is used in a function signature so the
      // omit_local_variable_types lint stays happy.
      FactorySequence makeSeq() => Sequence(start: 0);
      final seq = makeSeq();
      expect(seq, isA<Sequence>());
      expect(seq, isA<FactorySequence>());
      expect(seq.next(), 0);
      expect(seq.next(), 1);
      expect(seq.next(), 2);
    });
  });
}
