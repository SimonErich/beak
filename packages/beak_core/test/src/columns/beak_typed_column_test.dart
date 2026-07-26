import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

enum _Status { draft, published }

/// A record carrying [value] under `field`.
BeakRecord _record(Object? value) =>
    BeakRecord(values: {'field': BeakValue.of(value)});

/// A record carrying no `field` column at all.
const BeakRecord _empty = BeakRecord(values: {});

void main() {
  group('valueType comes from the mixin', () {
    test('every leaf reports the Dart type it reads', () {
      expect(
        const BeakStringColumn(key: 'field', label: 'F').valueType,
        String,
      );
      expect(const BeakTextColumn(key: 'field', label: 'F').valueType, String);
      expect(
        const BeakRichTextColumn(key: 'field', label: 'F').valueType,
        String,
      );
      expect(const BeakColorColumn(key: 'field', label: 'F').valueType, String);
      expect(const BeakJsonColumn(key: 'field', label: 'F').valueType, String);
      expect(const BeakIntColumn(key: 'field', label: 'F').valueType, int);
      expect(
        const BeakDecimalColumn(key: 'field', label: 'F').valueType,
        double,
      );
      expect(const BeakBoolColumn(key: 'field', label: 'F').valueType, bool);
      expect(
        const BeakDateTimeColumn(key: 'field', label: 'F').valueType,
        DateTime,
      );
      expect(
        const BeakEnumColumn<_Status>(
          key: 'field',
          label: 'F',
          values: _Status.values,
        ).valueType,
        _Status,
      );
      expect(
        const BeakCustomColumn(
          key: 'field',
          label: 'F',
          tag: BeakColumnTag('spark'),
        ).valueType,
        Object,
      );
      expect(
        const BeakFileColumn(
          key: 'field',
          label: 'F',
          storagePath: 'files',
        ).valueType,
        String,
      );
      expect(
        const BeakImageColumn(
          key: 'field',
          label: 'F',
          storagePath: 'images',
        ).valueType,
        String,
      );
    });
  });

  group('text columns', () {
    const column = BeakStringColumn(key: 'field', label: 'F');

    test('read a stored string', () {
      expect(column.readFrom(_record('hello')), 'hello');
    });

    test('stringify any other scalar rather than losing it', () {
      expect(column.readFrom(_record(42)), '42');
      expect(column.readFrom(_record(true)), 'true');
    });

    test('read null for an absent or null value', () {
      expect(column.readFrom(_empty), isNull);
      expect(column.readFrom(_record(null)), isNull);
    });

    test('the other string-backed leaves share the behaviour', () {
      expect(
        const BeakTextColumn(key: 'field', label: 'F').readFrom(_record('a')),
        'a',
      );
      expect(
        const BeakRichTextColumn(
          key: 'field',
          label: 'F',
        ).readFrom(_record('<p>')),
        '<p>',
      );
      expect(
        const BeakColorColumn(
          key: 'field',
          label: 'F',
        ).readFrom(_record('#fff')),
        '#fff',
      );
      expect(
        const BeakJsonColumn(key: 'field', label: 'F').readFrom(_record('{}')),
        '{}',
      );
      expect(
        const BeakFileColumn(
          key: 'field',
          label: 'F',
          storagePath: 'f',
        ).readFrom(_record('k')),
        'k',
      );
      expect(
        const BeakImageColumn(
          key: 'field',
          label: 'F',
          storagePath: 'i',
        ).readFrom(_record('k')),
        'k',
      );
    });
  });

  group('numeric columns tolerate the shapes a driver may return', () {
    const intColumn = BeakIntColumn(key: 'field', label: 'F');
    const decimalColumn = BeakDecimalColumn(key: 'field', label: 'F');

    test('int reads ints, wider numerics, and wire strings', () {
      expect(intColumn.readFrom(_record(7)), 7);
      expect(intColumn.readFrom(_record(7.9)), 7);
      expect(intColumn.readFrom(_record('7')), 7);
    });

    test('int reads null for unparseable or foreign shapes', () {
      expect(intColumn.readFrom(_record('seven')), isNull);
      expect(intColumn.readFrom(_record(true)), isNull);
      expect(intColumn.readFrom(_empty), isNull);
    });

    test('decimal reads doubles, ints, and wire strings', () {
      expect(decimalColumn.readFrom(_record(1.5)), 1.5);
      expect(decimalColumn.readFrom(_record(2)), 2.0);
      // Postgres returns numerics as strings over the wire.
      expect(decimalColumn.readFrom(_record('12.50')), 12.5);
    });

    test('decimal reads null for unparseable or foreign shapes', () {
      expect(decimalColumn.readFrom(_record('cheap')), isNull);
      expect(decimalColumn.readFrom(_record(true)), isNull);
      expect(decimalColumn.readFrom(_empty), isNull);
    });
  });

  group('bool columns', () {
    const column = BeakBoolColumn(key: 'field', label: 'F');

    test('read booleans and the canonical wire strings', () {
      expect(column.readFrom(_record(true)), isTrue);
      expect(column.readFrom(_record(false)), isFalse);
      expect(column.readFrom(_record('true')), isTrue);
      expect(column.readFrom(_record('false')), isFalse);
    });

    test('read null for anything else', () {
      expect(column.readFrom(_record('yes')), isNull);
      expect(column.readFrom(_record(1)), isNull);
      expect(column.readFrom(_empty), isNull);
    });
  });

  group('date-time columns', () {
    const column = BeakDateTimeColumn(key: 'field', label: 'F');
    final instant = DateTime.utc(2026, 7, 26, 12, 30);

    test('read instants and ISO-8601 wire strings', () {
      expect(column.readFrom(_record(instant)), instant);
      expect(column.readFrom(_record(instant.toIso8601String())), instant);
    });

    test('read null for unparseable or foreign shapes', () {
      expect(column.readFrom(_record('not a date')), isNull);
      expect(column.readFrom(_record(42)), isNull);
      expect(column.readFrom(_empty), isNull);
    });
  });

  group('enum columns', () {
    const column = BeakEnumColumn<_Status>(
      key: 'field',
      label: 'F',
      values: _Status.values,
    );

    test('read the declared value matching the stored name', () {
      expect(column.readFrom(_record('published')), _Status.published);
    });

    test('read null for a name no longer declared', () {
      // A row written before a value was removed degrades, never crashes.
      expect(column.readFrom(_record('retired')), isNull);
    });

    test('read null for a non-string shape', () {
      expect(column.readFrom(_record(1)), isNull);
      expect(column.readFrom(_empty), isNull);
    });
  });

  group('custom columns', () {
    const column = BeakCustomColumn(
      key: 'field',
      label: 'F',
      tag: BeakColumnTag('spark'),
    );

    test('hand back the raw payload untouched', () {
      expect(column.readFrom(_record(42)), 42);
      expect(column.readFrom(_record('a')), 'a');
    });

    test('read null when absent', () {
      expect(column.readFrom(_empty), isNull);
    });
  });

  group('require', () {
    const column = BeakDecimalColumn(key: 'price', label: 'Price');
    BeakRecord priced(Object? value) =>
        BeakRecord(values: {'price': BeakValue.of(value)});

    test('returns the value when the record carries one', () {
      expect(column.require(priced(9.99)), 9.99);
    });

    test('throws a shape exception naming the column and type', () {
      expect(
        () => column.require(_empty),
        throwsA(
          isA<BeakRecordShapeException>()
              .having((e) => e.columnKey, 'columnKey', 'price')
              .having((e) => e.expectedType, 'expectedType', double)
              .having((e) => e.message, 'message', contains('"price"'))
              .having((e) => e.message, 'message', contains('double')),
        ),
      );
    });

    test('is a configuration exception, so handlers map it like the rest', () {
      expect(
        () => column.require(priced('free')),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('readValue works directly on a BeakValue', () {
    test('so callers holding a value need not build a record', () {
      const column = BeakIntColumn(key: 'field', label: 'F');
      expect(column.readValue(const BeakIntValue(5)), 5);
      expect(column.readValue(null), isNull);
      expect(column.readValue(const BeakNullValue()), isNull);
    });
  });

  group('the mixin keeps columns usable generically', () {
    test('a value-typed helper compiles against any typed column', () {
      V? read<V extends Object>(BeakTypedColumn<V> column, BeakRecord record) =>
          column.readFrom(record);

      expect(
        read(const BeakIntColumn(key: 'field', label: 'F'), _record(3)),
        3,
      );
      expect(
        read(const BeakStringColumn(key: 'field', label: 'F'), _record('x')),
        'x',
      );
    });
  });
}
