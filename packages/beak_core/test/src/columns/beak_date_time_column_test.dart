import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

void main() {
  const column = BeakDateTimeColumn(key: 'created_at', label: 'Created');

  test('exposes the documented formats in stable order', () {
    expect(BeakDateFormat.values.map((format) => format.name), const [
      'standard',
      'relative',
      'dateOnly',
      'timeOnly',
      'iso',
    ]);
  });

  test('defaults to the standard format', () {
    expect(column.format, BeakDateFormat.standard);
  });

  test('holds DateTime values', () {
    expect(column.valueType, DateTime);
  });

  test('renders as an absolute date everywhere for non-relative formats', () {
    for (final format in const [
      BeakDateFormat.standard,
      BeakDateFormat.dateOnly,
      BeakDateFormat.timeOnly,
      BeakDateFormat.iso,
    ]) {
      final formatted = column.withFormat(format);
      for (final context in BeakContext.values) {
        expect(
          formatted.intentFor(context),
          BeakRenderIntent.date,
          reason: '$format/$context',
        );
      }
    }
  });

  test('renders relative timestamps in table and detail only', () {
    final relative = column.withFormat(BeakDateFormat.relative);
    expect(
      relative.intentFor(BeakContext.table),
      BeakRenderIntent.relativeDate,
    );
    expect(
      relative.intentFor(BeakContext.detail),
      BeakRenderIntent.relativeDate,
    );
    expect(relative.intentFor(BeakContext.form), BeakRenderIntent.date);
    expect(relative.intentFor(BeakContext.filter), BeakRenderIntent.date);
  });

  test('withFormat copies every field and leaves the original untouched', () {
    const original = BeakDateTimeColumn(
      key: 'shipped_at',
      label: 'Shipped',
      visibleOn: {BeakContext.table, BeakContext.detail},
      sortable: true,
      searchable: true,
      filterable: true,
      rules: [BeakRequired()],
    );
    final copy = original.withFormat(BeakDateFormat.relative);
    expect(copy, isNot(same(original)));
    expect(copy.format, BeakDateFormat.relative);
    expect(copy.key, original.key);
    expect(copy.label, original.label);
    expect(copy.visibleOn, original.visibleOn);
    expect(copy.sortable, original.sortable);
    expect(copy.searchable, original.searchable);
    expect(copy.filterable, original.filterable);
    expect(copy.rules, original.rules);
    expect(original.format, BeakDateFormat.standard);
  });
}
