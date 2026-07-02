import 'package:test/test.dart';
import 'package:worm/src/logging/n_plus_one_detector.dart';

void main() {
  group('NPlusOneDetector.shouldWarn', () {
    test('returns false when count is below threshold', () {
      final detector = NPlusOneDetector(threshold: 3)
        ..recordQuery('posts')
        ..recordQuery('posts');

      expect(detector.shouldWarn('posts', threshold: 3), isFalse);
    });

    test('returns true when count reaches threshold', () {
      final detector = NPlusOneDetector(threshold: 3)
        ..recordQuery('posts')
        ..recordQuery('posts')
        ..recordQuery('posts');

      expect(detector.shouldWarn('posts', threshold: 3), isTrue);
    });

    test('returns false for an untouched table', () {
      final detector = NPlusOneDetector(threshold: 3)..recordQuery('posts');

      expect(detector.shouldWarn('users', threshold: 3), isFalse);
    });

    test('tracks each table independently', () {
      final detector = NPlusOneDetector(threshold: 2)
        ..recordQuery('posts')
        ..recordQuery('users')
        ..recordQuery('users');

      expect(detector.shouldWarn('posts', threshold: 2), isFalse);
      expect(detector.shouldWarn('users', threshold: 2), isTrue);
    });

    test('evicts entries older than the configured window', () {
      var now = DateTime(2026);
      final detector =
          NPlusOneDetector(
              threshold: 3,
              window: const Duration(milliseconds: 100),
              clock: () => now,
            )
            ..recordQuery('posts')
            ..recordQuery('posts')
            ..recordQuery('posts');

      expect(detector.shouldWarn('posts'), isTrue);

      now = now.add(const Duration(milliseconds: 250));

      expect(detector.shouldWarn('posts'), isFalse);
    });

    test('counts only entries inside the window', () {
      var now = DateTime(2026);
      final detector =
          NPlusOneDetector(
              threshold: 3,
              window: const Duration(milliseconds: 100),
              clock: () => now,
            )
            ..recordQuery('posts')
            ..recordQuery('posts');

      now = now.add(const Duration(milliseconds: 250));
      detector.recordQuery('posts');

      expect(detector.shouldWarn('posts'), isFalse);
    });

    test('honours per-call threshold and window overrides', () {
      final detector = NPlusOneDetector(threshold: 100)
        ..recordQuery('posts')
        ..recordQuery('posts');

      expect(detector.shouldWarn('posts', threshold: 2), isTrue);
    });

    test('reset and resetTable forget prior observations', () {
      final detector = NPlusOneDetector(threshold: 2)
        ..recordQuery('posts')
        ..recordQuery('posts')
        ..resetTable('posts');

      expect(detector.shouldWarn('posts', threshold: 2), isFalse);

      detector
        ..recordQuery('users')
        ..recordQuery('users')
        ..reset();

      expect(detector.shouldWarn('users', threshold: 2), isFalse);
    });
  });
}
