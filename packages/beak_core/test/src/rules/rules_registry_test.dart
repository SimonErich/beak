import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// Exhaustive mapping over the sealed rule family: adding a `BeakRule`
/// variant breaks compilation (and this suite) until it is registered here
/// with a test file of its own.
String idOf(BeakRule rule) => switch (rule) {
  BeakFutureDate() => 'future_date',
  BeakRequired() => 'required',
  BeakMinLength() => 'min_length',
  BeakMaxLength() => 'max_length',
  BeakMin() => 'min',
  BeakMax() => 'max',
  BeakEmail() => 'email',
  BeakUrl() => 'url',
  BeakPattern() => 'pattern',
  BeakInList<Object?>() => 'in_list',
  BeakMaxFileSize() => 'max_file_size',
  BeakAllowedFileTypes() => 'allowed_file_types',
};

/// One instance of every concrete rule.
const List<BeakRule> allRules = [
  BeakFutureDate(),
  BeakRequired(),
  BeakMinLength(1),
  BeakMaxLength(1),
  BeakMin(0),
  BeakMax(1),
  BeakEmail(),
  BeakUrl(),
  BeakPattern('.'),
  BeakInList<String>(['x']),
  BeakMaxFileSize(1),
  BeakAllowedFileTypes([BeakFileType.png]),
];

void main() {
  test('every rule carries its stable wire id', () {
    for (final rule in allRules) {
      expect(rule.id, idOf(rule), reason: '$rule');
    }
  });

  test('rule ids are unique', () {
    final ids = allRules.map((rule) => rule.id);
    expect(ids.toSet(), hasLength(ids.length));
  });
}
