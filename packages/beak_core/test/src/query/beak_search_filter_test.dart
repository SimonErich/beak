import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const model = _SearchModel();
  final registry = BeakModelRegistry()..register(model);
  BeakFilter? search(String term, List<String> keys) =>
      beakSearchFilter(BeakSearch(term, keys), model, registry);
  test(
    'text, identifiers, decimals, booleans and dates retain their types',
    () {
      final cases = <(String, String, BeakValue, BeakOperator)>[
        ('name', 'Tea', const BeakStringValue('%Tea%'), BeakOperator.ilike),
        ('id', '42', const BeakIntValue(42), BeakOperator.eq),
        ('price', '2.5', const BeakDoubleValue(2.5), BeakOperator.eq),
        ('active', 'true', const BeakBoolValue(true), BeakOperator.eq),
        ('active', 'FALSE', const BeakBoolValue(false), BeakOperator.eq),
        (
          'date',
          '2026-09-27',
          BeakDateTimeValue(DateTime(2026, 9, 27)),
          BeakOperator.eq,
        ),
      ];
      for (final (key, term, value, operator) in cases) {
        expect(
          search(term, [key]),
          BeakOrFilter([BeakFieldFilter.forKey(key, operator, value)]),
        );
      }
      expect(
        search('Tea', ['id', 'active', 'price', 'date', 'name']),
        search('Tea', ['name']),
      );
      expect(
        search('no match', ['id']),
        const BeakFieldFilter.forKey(
          'id',
          BeakOperator.inList,
          BeakListValue([]),
        ),
      );
    },
  );
  test('wildcard characters in a term are searched for, not obeyed', () {
    expect(
      search(r'50%_off\', ['name']),
      const BeakOrFilter([
        BeakFieldFilter.forKey(
          'name',
          BeakOperator.ilike,
          BeakStringValue(r'%50\%\_off\\%'),
        ),
      ]),
    );
  });
  test('semantic searches normalize exact amounts and calendar values', () {
    for (final (key, term, value) in <(String, String, BeakValue)>[
      ('amount', '12.345', const BeakIntValue(12345)),
      ('day', '2024-02-29', const BeakStringValue('2024-02-29')),
      ('time', '09:30', const BeakStringValue('09:30:00')),
      ('elapsed', '1500000', const BeakIntValue(1500000)),
    ]) {
      expect(
        search(term, [key]),
        BeakOrFilter([BeakFieldFilter.forKey(key, BeakOperator.eq, value)]),
      );
    }
    for (final (key, term) in [
      ('day', '2023-02-29'),
      ('elapsed', '1.5'),
      ('elapsed', 'invalid'),
    ]) {
      expect(
        search(term, [key]),
        const BeakFieldFilter.forKey(
          'id',
          BeakOperator.inList,
          BeakListValue([]),
        ),
      );
    }
  });
  test('secret metadata is never searchable', () {
    expect(model.columnByKey('secret')!.searchable, isFalse);
    expect(
      () => search('secret', ['secret']),
      throwsA(isA<BeakValidationException>()),
    );
  });
  test('a related numeric identifier remains an equality predicate', () {
    expect(
      search('42', ['parent.id']),
      const BeakOrFilter([
        BeakFieldFilter.forKey('parent.id', BeakOperator.eq, BeakIntValue(42)),
      ]),
    );
  });
  test('absent and blank searches do not add predicates', () {
    expect(beakSearchFilter(null, model, registry), isNull);
    expect(search('  ', ['name']), isNull);
    expect(search('Tea', []), isNull);
  });
  test('invalid or unsupported search paths fail explicitly', () {
    for (final key in [
      'missing',
      'missing.name',
      'json',
      'custom',
      '${List.filled(17, 'parent').join('.')}.name',
    ]) {
      expect(
        () => search('Tea', [key]),
        throwsA(isA<BeakValidationException>()),
      );
    }
  });
}

final class _SearchModel extends BeakModel {
  const _SearchModel();
  @override
  String get table => 'searches';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'ID'),
    BeakIntColumn(
      key: 'amount',
      label: 'Amount',
      semantic: BeakSemantic.money(scale: 3, currency: 'EUR'),
    ),
    BeakStringColumn(
      key: 'day',
      label: 'Day',
      semantic: BeakSemantic.calendarDate(),
    ),
    BeakStringColumn(key: 'time', label: 'Time', semantic: BeakSemantic.time()),
    BeakIntColumn(
      key: 'elapsed',
      label: 'Elapsed',
      semantic: BeakSemantic.duration(),
    ),
    BeakStringColumn(
      key: 'secret',
      label: 'Secret',
      searchable: true,
      semantic: BeakSemantic.password(),
    ),
    BeakStringColumn(key: 'name', label: 'Name'),
    BeakDecimalColumn(key: 'price', label: 'Price'),
    BeakBoolColumn(key: 'active', label: 'Active'),
    BeakDateTimeColumn(key: 'date', label: 'Date'),
    BeakJsonColumn(key: 'json', label: 'JSON'),
    BeakCustomColumn(
      key: 'custom',
      label: 'Custom',
      tag: BeakColumnTag('custom'),
    ),
  ];
  @override
  List<BeakRelationship> get relationships => const [
    BeakBelongsTo(
      key: 'parent',
      label: 'Parent',
      relatedTable: 'searches',
      foreignKey: 'parent_id',
      displayColumnKey: 'name',
    ),
  ];
}
