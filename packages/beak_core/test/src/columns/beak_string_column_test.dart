import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakStringColumn(key: 'name', label: 'Name');

  test('renders as plain text in every context', () {
    for (final context in BeakContext.values) {
      expect(column.intentFor(context), BeakRenderIntent.text);
    }
  });

  test('holds String values', () {
    expect(column.valueType, String);
  });

  test('defaults to table/form/detail visibility with all flags off', () {
    expect(column.visibleOn, const {
      BeakContext.table,
      BeakContext.form,
      BeakContext.detail,
    });
    expect(column.sortable, isFalse);
    expect(column.searchable, isFalse);
    expect(column.filterable, isFalse);
    expect(column.rules, isEmpty);
    expect(column.placeholder, isEmpty);
    expect(column.maxLength, isNull);
  });

  test('stores every override as given', () {
    const overridden = BeakStringColumn(
      key: 'sku',
      label: 'SKU',
      visibleOn: {BeakContext.table},
      sortable: true,
      searchable: true,
      filterable: true,
      rules: [BeakRequired(), BeakMaxLength(32)],
      placeholder: 'ABC-123',
      maxLength: 32,
    );
    expect(overridden.key, 'sku');
    expect(overridden.label, 'SKU');
    expect(overridden.visibleOn, const {BeakContext.table});
    expect(overridden.sortable, isTrue);
    expect(overridden.searchable, isTrue);
    expect(overridden.filterable, isTrue);
    expect(overridden.rules, hasLength(2));
    expect(overridden.placeholder, 'ABC-123');
    expect(overridden.maxLength, 32);
  });
}
