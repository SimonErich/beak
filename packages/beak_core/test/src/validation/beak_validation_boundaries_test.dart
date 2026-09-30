import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

enum _Status { active, archived }

final class _Model extends BeakModel {
  const _Model(this.columns);
  @override
  final List<BeakColumn> columns;
  @override
  String get table => 'records';
  @override
  String get displayColumnKey => columns.first.key;
}

void main() {
  const validator = BeakValidation();
  test(
    'defaults preserve null, recurse into objects and leave invalid input inspectable',
    () {
      const inner = BeakJsonColumn(
        key: 'child',
        label: 'Child',
        semantic: BeakSemantic.object(
          BeakObjectSchema(
            columns: [
              BeakIntColumn(
                key: 'count',
                label: 'Count',
                defaultValue: 2,
                rules: [BeakRequired()],
              ),
            ],
          ),
        ),
      );
      const object = BeakJsonColumn(
        key: 'object',
        label: 'Object',
        semantic: BeakSemantic.object(
          BeakObjectSchema(
            columns: [
              inner,
              BeakStringColumn(
                key: 'name',
                label: 'Name',
                defaultValue: 'Default',
              ),
            ],
          ),
        ),
      );
      const model = _Model([
        object,
        BeakStringColumn(key: 'name', label: 'Name', defaultValue: 'Root'),
        BeakStringColumn(
          key: 'required',
          label: 'Required',
          rules: [BeakRequired()],
        ),
      ]);
      final input = BeakRecord.fromRow({
        'object': '{"child":{}}',
        'required': 'yes',
      });
      final prepared = validator.applyDefaults(model, input);
      expect(prepared['object']?.raw, '{"child":{"count":2},"name":"Default"}');
      expect(prepared['name']?.raw, 'Root');
      expect(validator.validate(model, prepared), isEmpty);
      final malformed = BeakRecord.fromRow({'object': '{bad'});
      expect(validator.applyDefaults(model, malformed)['object']?.raw, '{bad');
      expect(
        validator
            .applyDefaults(
              model,
              BeakRecord.fromRow({'object': null}),
            )['object']
            ?.raw,
        isNull,
      );
      expect(
        validator.applyDefaults(model, input, includeMissing: false)['name'],
        isNull,
      );
      expect(
        validator.validate(model, BeakRecord.fromRow({'unknown': 1})).keys,
        unorderedEquals(['unknown', 'required']),
      );
      expect(
        validator.validate(model, BeakRecord.fromRow({}), isCreate: false),
        isEmpty,
      );
      const badDefault = _Model([
        BeakJsonColumn(
          key: 'object',
          label: 'Object',
          semantic: BeakSemantic.object(
            BeakObjectSchema(
              columns: [
                BeakJsonColumn(
                  key: 'nested',
                  label: 'Nested',
                  defaultValue: {'bad': Object()},
                  semantic: BeakSemantic.object(BeakObjectSchema(columns: [])),
                ),
              ],
            ),
          ),
        ),
      ]);
      expect(
        validator
            .applyDefaults(
              badDefault,
              BeakRecord.fromRow({'object': '{}'}),
            )['object']
            ?.raw,
        '{}',
      );
      expect(validator.columnErrors(object, {'child': Object()}), [
        'Invalid object value.',
      ]);
    },
  );
  test(
    'semantic validation rejects malformed contact, identifier and collection values',
    () {
      for (final (semantic, valid, invalid) in <(BeakSemantic, Object, Object)>[
        (const BeakSemantic.email(), 'a@example.com', 'bad'),
        (const BeakSemantic.url(), 'https://example.com', 'relative/path'),
        (const BeakSemantic.phone(), '+43 (1) 234-567', '---'),
        (const BeakSemantic.slug(), 'coffee-beans-2', 'Coffee Beans'),
        (
          const BeakSemantic.uuid(),
          '550e8400-e29b-41d4-a716-446655440000',
          'no-uuid',
        ),
      ]) {
        final column = BeakStringColumn(
          key: 'value',
          label: 'Value',
          semantic: semantic,
        );
        expect(validator.columnErrors(column, valid), isEmpty);
        expect(validator.columnErrors(column, invalid), isNotEmpty);
      }
      const bytes = BeakIntColumn(
        key: 'bytes',
        label: 'Bytes',
        semantic: BeakSemantic.fileSize(),
      );
      expect(validator.columnErrors(bytes, 0), isEmpty);
      expect(validator.columnErrors(bytes, -1), isNotEmpty);
      const list = BeakJsonColumn(
        key: 'list',
        label: 'List',
        semantic: BeakSemantic.list(BeakPrimitiveType.integer, maxItems: 1),
      );
      expect(validator.columnErrors(list, [1, 2]), [
        'Must contain at most 1 items.',
      ]);
      // An object column holds JSON text, and a client can send it as deep as
      // a request body allows: that is a validation error, not a crash.
      const document = BeakJsonColumn(
        key: 'document',
        label: 'Document',
        semantic: BeakSemantic.object(
          BeakObjectSchema(columns: [], allowUnknown: true),
        ),
      );
      expect(
        validator.columnErrors(document, '${'{"k":' * 100000}1${'}' * 100000}'),
        isNotEmpty,
      );
      const enumeration = BeakEnumColumn<_Status>(
        key: 'status',
        label: 'Status',
        values: _Status.values,
      );
      expect(validator.columnErrors(enumeration, _Status.active), isEmpty);
      expect(validator.columnErrors(enumeration, 'archived'), isEmpty);
      expect(validator.columnErrors(enumeration, 'missing'), [
        'Must be one of: active, archived.',
      ]);
      expect(
        validator.columnErrors(
          const BeakBoolColumn(key: 'b', label: 'B'),
          'true',
        ),
        isNotEmpty,
      );
      expect(
        validator.columnErrors(
          const BeakDateTimeColumn(key: 'd', label: 'D'),
          'today',
        ),
        isNotEmpty,
      );
      expect(
        validator.columnErrors(
          const BeakDecimalColumn(key: 'n', label: 'N'),
          '1',
        ),
        isNotEmpty,
      );
      expect(
        validator.columnErrors(
          const BeakCustomColumn(
            key: 'custom',
            label: 'Custom',
            tag: BeakColumnTag('custom'),
          ),
          Object(),
        ),
        isEmpty,
      );
    },
  );
}
