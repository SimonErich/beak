import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:test/test.dart';

void main() {
  final field = ServerpodField<String?, String?>(
    key: 'name',
    get: (value) => value,
    codec: ServerpodCodecs.string.nullable,
    buildColumn: (label, options) => BeakStringColumn(
      key: 'name',
      label: label,
      visibleOn: options.visibleOn,
      sortable: options.sortable,
      searchable: options.searchable,
      filterable: options.filterable,
      rules: options.rules,
    ),
  );

  test(
    'required nullable fields distinguish omission from deliberate clearing',
    () {
      const missing = BeakRecord(values: {});
      const clearing = BeakRecord(values: {'name': BeakNullValue()});
      expect(field.isPresent(missing), isFalse);
      expect(field.isPresent(clearing), isTrue);
      expect(field.readRequired(clearing), isNull);
      expect(
        () => field.readRequired(missing),
        throwsA(
          isA<BeakValidationException>().having(
            (error) => error.fieldErrors.keys,
            'field path',
            contains('name'),
          ),
        ),
      );
      expect(
        () => field.read(const BeakRecord(values: {'name': BeakIntValue(7)})),
        throwsA(
          isA<BeakValidationException>().having(
            (error) => error.fieldErrors.keys,
            'field path',
            contains('name'),
          ),
        ),
      );
      expect(field.encode('Ada'), const BeakStringValue('Ada'));
    },
  );

  test('generated form presentation inherits only unambiguous labels', () {
    const exact = BeakStringColumn(key: 'name', label: 'Exact');
    const nested = BeakStringColumn(key: 'profile.name', label: 'Nested');
    const other = BeakStringColumn(key: 'account.name', label: 'Other');
    expect(serverpodFormColumn(field, [exact, nested]).label, 'Exact');
    final projected = serverpodFormColumn(field, [nested]);
    expect(projected.label, 'Nested');
    expect(projected.visibleOn, {BeakContext.form});
    expect(projected.sortable, isFalse);
    expect(serverpodFormColumn(field, [nested, other]).label, 'name');
    expect(serverpodFormColumn(field, [], label: 'Override').label, 'Override');
    final enumField = ServerpodField<_Status, _Status>(
      key: 'status',
      get: (value) => value,
      codec: ServerpodCodecs.enumeration(_Status.values),
      buildColumn: (label, options) => BeakEnumColumn<_Status>(
        key: 'status',
        label: label,
        values: _Status.values,
        labelOf: (value) => options.enumLabels[value] ?? value.name,
      ),
    );
    final column = serverpodFormColumn(enumField, [
      BeakEnumColumn<_Status>(
        key: 'entry.status',
        label: 'Status',
        values: _Status.values,
        labelOf: (_) => 'Aktiv',
      ),
    ]);
    expect(
      column,
      isA<BeakEnumColumn<_Status>>().having(
        (value) => value.labelFor(_Status.active),
        'localized value',
        'Aktiv',
      ),
    );
  });

  test('presentation choices do not redefine the original field shape', () {
    final column = field.column(
      'Localized name',
      options: const ServerpodColumnOptions(
        visibleOn: {BeakContext.table, BeakContext.detail},
        sortable: true,
        searchable: true,
        filterable: true,
        rules: [BeakRequired()],
      ),
    );
    final model = ServerpodModel(
      resource: 'people',
      columns: [column],
      primaryKey: column,
      displayColumn: column,
    );
    expect(model.displayColumnKey, field.key);
    expect(model.relationships, isEmpty);
    expect(column.label, 'Localized name');
    expect(column.sortable && column.searchable && column.filterable, isTrue);
    expect(column.rules.single, isA<BeakRequired>());
    expect(field.column('Default').visibleOn, {BeakContext.detail});
    final relation = ServerpodRelationField<String, int>(
      key: 'nameLength',
      get: (value) => value.length,
      codec: const _TextCodec(),
    );
    expect(
      relation.read(
        const BeakRecord(values: {'value': BeakStringValue('Ada')}),
      ),
      3,
    );
  });
}

final class _TextCodec extends ServerpodCodec<String> {
  const _TextCodec();
  @override
  String decode(BeakRecord record) =>
      ServerpodCodecs.string.decode(record['value']);
  @override
  BeakRecord encode(String value) =>
      BeakRecord(values: {'value': ServerpodCodecs.string.encode(value)});
}

enum _Status { active }
