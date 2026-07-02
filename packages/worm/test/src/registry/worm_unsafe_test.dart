/// `Worm.unsafe` zone-based escape hatch and `Worm.strictness` accessor.
library;

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/config/strictness_config.dart';
import 'package:worm/src/config/worm_config.dart';
import 'package:worm/src/registry/worm.dart';

void main() {
  tearDown(Worm.reset);

  group('Worm.strictness', () {
    test('falls back to all-off defaults before initialize', () {
      expect(Worm.strictness.preventFullTableScans, isFalse);
      expect(Worm.strictness.preventLazyLoading, isFalse);
      expect(Worm.strictness.preventDestructiveWithoutWhere, isFalse);
    });

    test('returns config strictness after initialize', () async {
      await Worm.initialize(
        config: const WormConfig(
          strictness: StrictnessConfig(
            preventFullTableScans: true,
            preventLazyLoading: true,
          ),
        ),
        adapters: <String, InMemoryAdapter>{'default': InMemoryAdapter()},
      );
      expect(Worm.strictness.preventFullTableScans, isTrue);
      expect(Worm.strictness.preventLazyLoading, isTrue);
    });
  });

  group('Worm.unsafe', () {
    test('is false outside an unsafe block', () {
      expect(Worm.isUnsafe, isFalse);
    });

    test('is true inside the callback and false after it returns', () async {
      expect(Worm.isUnsafe, isFalse);
      final wasUnsafe = await Worm.unsafe<bool>(() async => Worm.isUnsafe);
      expect(wasUnsafe, isTrue);
      expect(Worm.isUnsafe, isFalse);
    });

    test('isUnsafe survives awaits inside the block', () async {
      final observed = await Worm.unsafe<bool>(() async {
        await Future<void>.delayed(Duration.zero);
        return Worm.isUnsafe;
      });
      expect(observed, isTrue);
    });

    test('restores isUnsafe when the callback throws', () async {
      await expectLater(
        Worm.unsafe<void>(() async {
          expect(Worm.isUnsafe, isTrue);
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );
      expect(Worm.isUnsafe, isFalse);
    });

    test('nested unsafe is idempotent', () async {
      final flags = await Worm.unsafe<List<bool>>(() async {
        final outer = Worm.isUnsafe;
        final inner = await Worm.unsafe<bool>(() async => Worm.isUnsafe);
        return <bool>[outer, inner];
      });
      expect(flags, <bool>[true, true]);
      expect(Worm.isUnsafe, isFalse);
    });
  });
}
