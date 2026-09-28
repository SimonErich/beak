import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  BeakAttributeDefinition definition(
    BeakAttributeType type, {
    bool required = true,
    int version = 1,
  }) => BeakAttributeDefinition(
    id: 'size',
    label: 'Size',
    type: type,
    required: required,
    version: version,
    choices: type == BeakAttributeType.choice ? ['Small', 'Large'] : [],
  );

  test('attribute representation and revision are validated consistently', () {
    for (final (type, valid, invalid) in [
      (BeakAttributeType.number, '1.25', 'NaN'),
      (BeakAttributeType.boolean, 'false', 'yes'),
      (BeakAttributeType.choice, 'Small', 'Unknown'),
    ]) {
      final field = definition(type);
      expect(field.validate(valid), isNull);
      expect(field.validate(invalid), isNotNull);
      expect(field.validate(null), isNotNull);
      expect(field.validate(valid, version: 2), contains('definition changed'));
    }
    expect(
      definition(BeakAttributeType.text, required: false).validate(' '),
      isNull,
    );
    expect(definition(BeakAttributeType.text).validate('Description'), isNull);
    final limited = BeakAttributeDefinition(
      id: 'name',
      label: 'Name',
      type: BeakAttributeType.text,
      rules: const [BeakMaxLength(3)],
    );
    expect(limited.validate('1234'), isNotNull);
    expect(limited.validate('123'), isNull);
  });

  test('malformed definitions are rejected before constructing an editor', () {
    expect(
      () => BeakAttributeDefinition(
        id: '',
        label: 'Size',
        type: BeakAttributeType.text,
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => BeakAttributeDefinition(
        id: 'size',
        label: 'Size',
        type: BeakAttributeType.choice,
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => BeakAttributeDefinition(
        id: 'size',
        label: 'Size',
        type: BeakAttributeType.choice,
        choices: ['Small', 'Small'],
      ),
      throwsA(isA<BeakConfigurationException>()),
    );
    expect(
      () => BeakAttributeSet([
        definition(BeakAttributeType.text),
        definition(BeakAttributeType.text),
      ]),
      throwsA(isA<BeakConfigurationException>()),
    );
  });

  test('category changes preserve obsolete and invalid values for review', () {
    final set = BeakAttributeSet([
      definition(BeakAttributeType.choice, version: 2),
      BeakAttributeDefinition(
        id: 'material',
        label: 'Material',
        type: BeakAttributeType.text,
        required: true,
      ),
    ]);
    final entries = [
      const BeakAttributeEntry(
        definitionId: 'size',
        value: 'Small',
        version: 1,
      ),
      const BeakAttributeEntry(
        definitionId: 'size',
        value: 'Other',
        version: 2,
      ),
      const BeakAttributeEntry(
        definitionId: 'old',
        value: 'Preserve me',
        version: 1,
      ),
    ];
    final report = set.reconcile(entries);
    expect(report.valid, isFalse);
    expect(report.retained, entries.take(2));
    expect(report.obsolete.single.value, 'Preserve me');
    expect(report.missing.single.id, 'material');
    expect(report.errors['size'], hasLength(3));
    expect(
      set.reconcile([
        const BeakAttributeEntry(
          definitionId: 'size',
          value: 'Small',
          version: 2,
        ),
        const BeakAttributeEntry(
          definitionId: 'material',
          value: 'Cotton',
          version: 1,
        ),
      ]).valid,
      isTrue,
    );
  });
}
