import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'declared scalar metadata validates consistently without duplicate rules',
    () {
      const validator = BeakValidation();
      const quantity = BeakIntColumn(
        key: 'quantity',
        label: 'Quantity',
        min: 1,
        max: 20,
      );
      const name = BeakStringColumn(key: 'name', label: 'Name', maxLength: 4);
      const amount = BeakDecimalColumn(
        key: 'amount',
        label: 'Amount',
        precision: 2,
        totalDigits: 5,
      );
      expect(validator.columnErrors(quantity, 0), ['Must be at least 1.']);
      expect(validator.columnErrors(quantity, 21), ['Must be at most 20.']);
      expect(validator.columnErrors(name, 'hello'), [
        'Must be at most 4 characters.',
      ]);
      expect(validator.columnErrors(amount, 1.005), [
        'Use at most 2 decimal places.',
      ]);
      expect(validator.columnErrors(amount, double.infinity), [
        'Must be a finite number.',
      ]);
      expect(validator.columnErrors(amount, 1000), [
        'Must have at most 3 integer digits.',
      ]);
      expect(validator.columnErrors(amount, 0.1 + 0.2), isEmpty);
      expect(validator.columnErrors(quantity, '1'), ['Must be an integer.']);
      expect(validator.columnErrors(name, null), isEmpty);
    },
  );
  test(
    'structured text and metadata constraints reject invalid API values',
    () {
      const validator = BeakValidation();
      const json = BeakJsonColumn(key: 'config', label: 'Configuration');
      const color = BeakColorColumn(key: 'color', label: 'Color');
      const bounded = BeakIntColumn(
        key: 'count',
        label: 'Count',
        min: 1,
        rules: [BeakMin(1)],
      );
      expect(validator.columnErrors(json, '{oops'), ['Must be valid JSON.']);
      expect(validator.columnErrors(json, '{"nested":[1,true,null]}'), isEmpty);
      expect(validator.columnErrors(json, 1), ['Must be a string.']);
      expect(validator.columnErrors(color, 'red'), isNotEmpty);
      expect(validator.columnErrors(color, '#0F8'), isEmpty);
      expect(validator.columnErrors(bounded, 0), ['Must be at least 1.']);
    },
  );

  test('semantic codecs, list items and nested objects share validation', () {
    const validator = BeakValidation();
    const date = BeakStringColumn(
      key: 'date',
      label: 'Date',
      semantic: BeakSemantic.calendarDate(),
    );
    const email = BeakStringColumn(
      key: 'email',
      label: 'Email',
      semantic: BeakSemantic.email(),
    );
    const tags = BeakJsonColumn(
      key: 'tags',
      label: 'Tags',
      semantic: BeakSemantic.list(
        BeakPrimitiveType.string,
        minItems: 1,
        maxItems: 2,
        distinctItems: true,
        itemRules: [BeakMinLength(2)],
      ),
    );
    const address = BeakJsonColumn(
      key: 'address',
      label: 'Address',
      semantic: BeakSemantic.object(
        BeakObjectSchema(
          columns: [
            BeakStringColumn(
              key: 'street',
              label: 'Street',
              rules: [BeakRequired()],
            ),
            BeakIntColumn(key: 'number', label: 'Number', min: 1),
          ],
        ),
      ),
    );
    expect(validator.columnErrors(date, const BeakDate(2026, 2, 28)), isEmpty);
    expect(validator.columnErrors(date, '2026-02-30'), isNotEmpty);
    expect(validator.columnErrors(email, 'bad'), [
      'Must be a valid email address.',
    ]);
    expect(
      validator.columnErrors(tags, ['aa', 'aa']),
      contains('Items must be distinct.'),
    );
    expect(
      validator.columnErrors(tags, '["a"]'),
      contains('Item 1: Must be at least 2 characters.'),
    );
    expect(
      validator.columnErrors(tags, []),
      contains('Must contain at least 1 items.'),
    );
    expect(validator.columnErrors(tags, [1]), isNotEmpty);
    expect(
      validator.columnErrors(address, '{"number":0,"extra":true}'),
      unorderedEquals([
        'Unknown property "extra".',
        'Street: This field is required.',
        'Number: Must be at least 1.',
      ]),
    );
    expect(
      validator.columnErrors(address, '{"street":"Main","number":2}'),
      isEmpty,
    );
  });

  test(
    'shared record rules validate merged edits and final collection contents',
    () {
      const validator = BeakValidation();
      final initial = BeakRecord.fromRow({
        'notify': false,
        'email': null,
        'start': DateTime.utc(2026, 1, 1),
        'end': DateTime.utc(2026, 1, 2),
      });
      final errors = validator.validate(
        const _Booking(),
        BeakRecord.fromRow({'notify': true, 'end': DateTime.utc(2025)}),
        isCreate: false,
        initial: initial,
      );
      expect(errors.keys, unorderedEquals(['email', 'end', 'lines']));
      final complete = BeakRecord(
        values: BeakRecord.fromRow({
          'notify': true,
          'email': 'a@example.com',
          'start': DateTime.utc(2026),
          'end': DateTime.utc(2026, 1, 2),
        }).values,
        relations: {
          'lines': [
            BeakRecord.fromRow({'code': 'one', 'amount': 5}),
            BeakRecord.fromRow({'code': 'one', 'amount': 9}),
          ],
        },
      );
      final invalidLines = validator.validate(const _Booking(), complete);
      expect(invalidLines.keys, ['lines']);
      expect(invalidLines['lines'], hasLength(2));
    },
  );
}

final class _Booking extends BeakModel {
  const _Booking();
  static const notify = BeakScalarField<bool>(
    model: _Booking(),
    column: BeakBoolColumn(key: 'notify', label: 'Notify'),
  );
  static const email = BeakScalarField<String>(
    model: _Booking(),
    column: BeakStringColumn(key: 'email', label: 'Email'),
  );
  static const start = BeakScalarField<DateTime>(
    model: _Booking(),
    column: BeakDateTimeColumn(key: 'start', label: 'Start'),
  );
  static const end = BeakScalarField<DateTime>(
    model: _Booking(),
    column: BeakDateTimeColumn(key: 'end', label: 'End'),
  );
  static const lines = BeakToManyField(
    model: _Booking(),
    target: _Line(),
    relation: BeakHasMany(
      key: 'lines',
      label: 'Lines',
      relatedTable: 'lines',
      foreignKey: 'booking_id',
      displayColumnKey: 'code',
    ),
  );
  @override
  String get table => 'bookings';
  @override
  String get displayColumnKey => 'email';
  @override
  List<BeakColumn> get columns => [
    notify.column,
    email.column,
    start.column,
    end.column,
  ];
  @override
  List<BeakRecordRule> get validationRules => [
    BeakRequiredIf(email, when: BeakWhen.equals(notify, true)),
    const BeakAfterField(end, start),
    const BeakCount(lines, min: 1, max: 3),
    const BeakDistinct(lines, _Line.code),
    const BeakSum(lines, _Line.amount, max: 10),
  ];
}

final class _Line extends BeakModel {
  const _Line();
  static const code = BeakScalarField<String>(
    model: _Line(),
    column: BeakStringColumn(key: 'code', label: 'Code'),
  );
  static const amount = BeakScalarField<int>(
    model: _Line(),
    column: BeakIntColumn(key: 'amount', label: 'Amount'),
  );
  @override
  String get table => 'lines';
  @override
  String get displayColumnKey => 'code';
  @override
  List<BeakColumn> get columns => [code.column, amount.column];
}
