import 'package:test/test.dart';
import 'package:worm/src/config/strictness_config.dart';

void main() {
  group('StrictnessConfig (EPIC-007 extensions)', () {
    test('defaults warnOnMissingIndex to false', () {
      const config = StrictnessConfig();
      expect(config.warnOnMissingIndex, isFalse);
    });

    test('defaults slowQueryThreshold to 500ms', () {
      const config = StrictnessConfig();
      expect(config.slowQueryThreshold, const Duration(milliseconds: 500));
    });

    test('copyWith preserves and overrides the new fields', () {
      const original = StrictnessConfig();
      final updated = original.copyWith(
        warnOnMissingIndex: true,
        slowQueryThreshold: const Duration(milliseconds: 10),
      );
      expect(updated.warnOnMissingIndex, isTrue);
      expect(updated.slowQueryThreshold, const Duration(milliseconds: 10));
      // Existing fields are preserved.
      expect(updated.preventLazyLoading, original.preventLazyLoading);
      expect(updated.warnOnN1Queries, original.warnOnN1Queries);
    });
  });
}
