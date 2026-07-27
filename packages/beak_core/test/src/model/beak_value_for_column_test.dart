import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

/// A driver says what it can: SQLite has no boolean, date or decimal type, so
/// the value that comes back depends on who stored it. The column decides.
void main() {
  test('a boolean column reads the 0/1 SQLite stores', () {
    const column = BeakBoolColumn(key: 'featured', label: 'Featured');

    expect(beakValueForColumn(column, 1), const BeakBoolValue(true));
    expect(beakValueForColumn(column, 0), const BeakBoolValue(false));
    expect(beakValueForColumn(column, true), const BeakBoolValue(true));
  });

  test('a date-time column reads the string SQLite stores', () {
    const column = BeakDateTimeColumn(key: 'placed_at', label: 'Placed');

    expect(
      beakValueForColumn(column, '2026-07-27T12:00:00.000Z'),
      BeakDateTimeValue(DateTime.utc(2026, 7, 27, 12)),
    );
  });

  test('numeric columns keep their declared width', () {
    const price = BeakDecimalColumn(key: 'price', label: 'Price');
    const stock = BeakIntColumn(key: 'stock', label: 'Stock');

    expect(beakValueForColumn(price, 89), const BeakDoubleValue(89));
    expect(beakValueForColumn(stock, '42'), const BeakIntValue(42));
  });

  test('a value the column cannot read keeps its literal form', () {
    const column = BeakBoolColumn(key: 'featured', label: 'Featured');

    expect(beakValueForColumn(column, 'maybe'), const BeakStringValue('maybe'));
    expect(beakValueForColumn(column, null), const BeakNullValue());
  });

  test('a column Beak cannot type leaves the value alone', () {
    const column = BeakStringColumn(key: 'name', label: 'Name');

    expect(
      beakValueForColumn(column, 'Espresso'),
      const BeakStringValue('Espresso'),
    );
    expect(beakValueForColumn(null, 7), const BeakIntValue(7));
  });
}
