import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'future-date rules validate both typed drafts and server wire values',
    () {
      const rule = BeakFutureDate();
      expect(rule.validate(DateTime.utc(2200)), isNull);
      expect(rule.validate('2200-01-01T00:00:00Z'), isNull);
      expect(rule.validate(DateTime.utc(2000)), isNotNull);
      expect(rule.validate('2000-01-01T00:00:00Z'), isNotNull);
      expect(rule.validate(null), isNull);
    },
  );
}
