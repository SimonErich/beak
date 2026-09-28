import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

import 'beak_schema_test.dart' show readSchemas;

void main() {
  test('semantic declarations cannot silently disagree with typed helpers', () {
    final (_, issues) = readSchemas({
      'bad.dart': """
@Resource()
final class Bad extends BeakSchema {
  late final String label;
  @Column(semantic: BeakSemantic.money(currency: 'EUR'))
  late final int wrongMoney;
  @Column(semantic: BeakSemantic.calendarDate())
  late final DateTime wrongDate;
  late final List<String?> nullableElements;
}
""",
    });
    expect(issues, hasLength(3));
  });

  test('passwords cannot leak into generated record labels or search', () {
    final (_, invalid) = readSchemas({
      'secret.dart': """
@Resource()
final class Secret extends BeakSchema {
  @Display()
  @Column(semantic: BeakSemantic.password())
  late final String password;
  @Column(semantic: BeakSemantic.password(), searchable: true)
  late final String another;
}
""",
    });
    expect(invalid, hasLength(2));
    final (schemas, issues) = readSchemas({
      'secret.dart': """
@Resource()
final class Secret extends BeakSchema {
  @Column(semantic: BeakSemantic.password())
  late final String password;
  late final String label;
}
""",
    });
    expect(issues, isEmpty);
    expect(schemas.single.displayColumnKey, 'label');
    expect(
      BeakSchemaEmitter.emit(schemas.single, schemas),
      contains('visibleOn: {BeakContext.form}'),
    );
  });

  test('semantic model types emit physical columns with typed helpers', () {
    final (schemas, issues) = readSchemas({
      'entry.dart': '''
@Resource()
final class Entry extends BeakSchema {
  @Column(semantic: BeakSemantic.email(), defaultValue: 'hello@example.com')
  late final String email;
  late final BeakDate birthday;
  late final BeakTime openingTime;
  late final Duration elapsed;
  @Column(semantic: BeakSemantic.money(scale: 3), currencyFrom: #currency)
  late final BeakDecimal amount;
  @Column(defaultValue: 'EUR')
  late final String currency;
  late final List<String> tags;
  late final List<int>? scores;
  late final BeakJsonObject? settings;
  late final bool? approved;
  static List<BeakRecordRule> get validationRules => [];
}
''',
    });
    expect(issues, isEmpty);
    final schema = schemas.single;
    final emitted = BeakSchemaEmitter.emit(schema, schemas);
    expect(emitted, contains('BeakScalarField<BeakDate>'));
    expect(emitted, contains('BeakScalarField<BeakTime>'));
    expect(emitted, contains('BeakScalarField<Duration>'));
    expect(emitted, contains('BeakScalarField<BeakDecimal>'));
    expect(emitted, contains('BeakScalarField<List<String>>'));
    expect(emitted, contains('BeakScalarField<BeakJsonObject>'));
    expect(emitted, contains('BeakSemantic.calendarDate()'));
    expect(emitted, contains('currencyColumn: EntryColumns.currency'));
    expect(emitted, contains('tristate: true'));
    expect(emitted, contains('get validationRules => Entry.validationRules'));
  });

  test(
    'unsupported list elements and unknown currency references report schema errors',
    () {
      final (_, issues) = readSchemas({
        'entry.dart': '''
@Resource()
final class Entry extends BeakSchema {
  late final String label;
  late final List<DateTime> values;
  @Column(semantic: BeakSemantic.money(), currencyFrom: #missing)
  late final BeakDecimal amount;
}
''',
      });
      expect(issues, hasLength(2));
      expect(
        issues.map((issue) => issue.message).join(' '),
        contains('missing'),
      );
    },
  );
}
