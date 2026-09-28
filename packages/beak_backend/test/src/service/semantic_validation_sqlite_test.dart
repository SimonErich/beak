import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/service/beak_resource_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

final class _Semantics extends BeakModel {
  const _Semantics();
  static const date = BeakScalarField<BeakDate>(
    model: _Semantics(),
    column: BeakStringColumn(
      key: 'date',
      label: 'Date',
      semantic: BeakSemantic.calendarDate(),
    ),
  );
  static const time = BeakScalarField<BeakTime>(
    model: _Semantics(),
    column: BeakStringColumn(
      key: 'time',
      label: 'Time',
      semantic: BeakSemantic.time(),
    ),
  );
  static const money = BeakScalarField<BeakDecimal>(
    model: _Semantics(),
    column: BeakIntColumn(
      key: 'money',
      label: 'Money',
      semantic: BeakSemantic.money(scale: 3),
      defaultValue: BeakDecimal(1234567890123, scale: 3),
    ),
  );
  static const duration = BeakScalarField<Duration>(
    model: _Semantics(),
    column: BeakIntColumn(
      key: 'duration',
      label: 'Duration',
      semantic: BeakSemantic.duration(),
      defaultValue: Duration(days: 4),
    ),
  );
  static const tags = BeakScalarField<List<String>>(
    model: _Semantics(),
    column: BeakJsonColumn(
      key: 'tags',
      label: 'Tags',
      semantic: BeakSemantic.list(
        BeakPrimitiveType.string,
        distinctItems: true,
      ),
    ),
  );
  static const object = BeakScalarField<BeakJsonObject>(
    model: _Semantics(),
    column: BeakJsonColumn(
      key: 'object',
      label: 'Object',
      semantic: BeakSemantic.object(
        BeakObjectSchema(
          columns: [
            BeakIntColumn(
              key: 'count',
              label: 'Count',
              defaultValue: 3,
              min: 1,
            ),
            BeakJsonColumn(
              key: 'child',
              label: 'Child',
              semantic: BeakSemantic.object(
                BeakObjectSchema(
                  columns: [
                    BeakStringColumn(
                      key: 'value',
                      label: 'Value',
                      defaultValue: 'nested',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  static const code = BeakScalarField<String>(
    model: _Semantics(),
    column: BeakStringColumn(
      key: 'code',
      label: 'Code',
      defaultValue: 'same',
      rules: [BeakRequired()],
    ),
  );
  static const tenant = BeakScalarField<String>(
    model: _Semantics(),
    column: BeakStringColumn(
      key: 'tenant',
      label: 'Tenant',
      defaultValue: 'team',
      rules: [BeakRequired()],
    ),
  );
  @override
  List<BeakRecordRule> get validationRules => [
    const BeakUnique(code, scope: [tenant]),
  ];
  @override
  String get table => 'semantics';
  @override
  String get displayColumnKey => 'id';
  @override
  List<BeakColumn> get columns => [
    const BeakStringColumn(key: 'id', label: 'Id'),
    code.column,
    tenant.column,
    date.column,
    time.column,
    money.column,
    duration.column,
    tags.column,
    object.column,
    const BeakBoolColumn(key: 'optional', label: 'Optional', tristate: true),
  ];
}

final class _CreateSemantics extends Migration {
  const _CreateSemantics();
  @override
  String get name => 'create_semantics';
  @override
  Future<void> upSchema(Schema schema) => schema.create(
    'semantics',
    (table) => BeakBlueprint.defineColumns(table, const _Semantics()),
  );
}

void main() {
  test(
    'real SQLite persists semantic values, typed filters and recursive defaults losslessly',
    () async {
      final adapter = SqliteAdapter.memory();
      await adapter.connect();
      addTearDown(adapter.disconnect);
      await MigrationRunner(
        adapter: adapter,
        migrations: [const _CreateSemantics()],
      ).migrate();
      final registry = BeakModelRegistry()..register(const _Semantics());
      final source = WormDataSource(registry, adapter: adapter);
      final service = BeakResourceService(const _Semantics(), source);
      final record = await service.create(
        BeakRecord(
          values: {
            'id': const BeakStringValue('one'),
            'date': _Semantics.date.column.semantic.encode(
              const BeakDate(2026, 9, 27),
            ),
            'time': _Semantics.time.column.semantic.encode(
              const BeakTime(9, 30),
            ),
            'tags': _Semantics.tags.column.semantic.encode(['coffee', 'beans']),
            'object': _Semantics.object.column.semantic.encode({
              'child': <String, Object?>{},
            }),
            'optional': const BeakNullValue(),
          },
        ),
      );
      expect(
        _Semantics.money.readFrom(record),
        const BeakDecimal(1234567890123, scale: 3),
      );
      expect(_Semantics.duration.readFrom(record), const Duration(days: 4));
      expect(_Semantics.date.readFrom(record), const BeakDate(2026, 9, 27));
      expect(_Semantics.time.readFrom(record), const BeakTime(9, 30));
      expect(_Semantics.tags.readFrom(record), ['coffee', 'beans']);
      expect(_Semantics.object.readFrom(record)?.toEncodable(), {
        'count': 3,
        'child': {'value': 'nested'},
      });
      expect(record['optional']?.raw, isNull);
      final found = await source.query(
        const _Semantics().query(
          filter: BeakAndFilter([
            _Semantics.money.gt(const BeakDecimal(1234567890122, scale: 3)),
            _Semantics.date.eq(const BeakDate(2026, 9, 27)),
          ]),
        ),
      );
      expect(found.total, 1);
      // Direct source writes deliberately bypass preflight, proving the inferred
      // composite database constraint closes the concurrent-request race.
      await expectLater(
        source.create(
          'semantics',
          BeakRecord.fromRow({'id': 'racer', 'code': 'same', 'tenant': 'team'}),
        ),
        throwsA(isA<BeakConflictException>()),
      );
      await source.create(
        'semantics',
        BeakRecord.fromRow({
          'id': 'other-team',
          'code': 'same',
          'tenant': 'other',
        }),
      );
      await expectLater(
        source.update(
          'semantics',
          'other-team',
          BeakRecord.fromRow({'tenant': 'team'}),
        ),
        throwsA(isA<BeakConflictException>()),
      );

      await expectLater(
        service.update('one', BeakRecord.fromRow({'date': '2026-02-30'})),
        throwsA(
          isA<BeakValidationException>().having(
            (error) => error.fieldErrors.keys,
            'field',
            ['date'],
          ),
        ),
      );
      await expectLater(
        service.update('one', BeakRecord.fromRow({'object': '{"count":null}'})),
        completes,
      );
      expect(
        _Semantics.object.readFrom(await service.getOne('one'))?.toEncodable(),
        {'count': null},
      );
      await expectLater(
        service.update(
          'one',
          BeakRecord.fromRow({'tags': '["duplicate","duplicate"]'}),
        ),
        throwsA(isA<BeakValidationException>()),
      );
    },
  );
}
