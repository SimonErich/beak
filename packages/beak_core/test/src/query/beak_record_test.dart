import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 3, 8, 30);

  BeakRecord productRecord() => BeakRecord(
    values: {
      'id': const BeakIntValue(1),
      'name': const BeakStringValue('Laser Pointer'),
      'price': const BeakDoubleValue(19.99),
      'active': const BeakBoolValue(true),
      'discontinued_at': const BeakNullValue(),
      'created_at': BeakDateTimeValue(createdAt),
    },
    relations: {
      'category': [
        const BeakRecord(
          values: {'id': BeakIntValue(7), 'name': BeakStringValue('Toys')},
        ),
      ],
      'tags': const [
        BeakRecord(values: {'id': BeakIntValue(1)}),
        BeakRecord(values: {'id': BeakIntValue(2)}),
      ],
    },
  );

  group('construction and access', () {
    test('exposes values and relations as unmodifiable maps', () {
      final record = productRecord();
      expect(
        () => record.values['id'] = const BeakIntValue(2),
        throwsUnsupportedError,
      );
      expect(
        () => record.relations['category'] = const [],
        throwsUnsupportedError,
      );
      expect(
        () => record.relations['tags']!.add(const BeakRecord(values: {})),
        throwsUnsupportedError,
      );
    });

    test('relations default to empty', () {
      const record = BeakRecord(values: {'id': BeakIntValue(1)});
      expect(record.relations, isEmpty);
    });

    test('operator [] returns the typed value or null for unknown keys', () {
      final record = productRecord();
      expect(record['name'], const BeakStringValue('Laser Pointer'));
      expect(record['missing'], isNull);
    });
  });

  group('fromRow / toRow', () {
    test('wraps every raw row value in its typed variant', () {
      final record = BeakRecord.fromRow({
        'id': 1,
        'name': 'Laser Pointer',
        'price': 19.99,
        'active': true,
        'discontinued_at': null,
        'created_at': createdAt,
      });
      expect(record['id'], const BeakIntValue(1));
      expect(record['name'], const BeakStringValue('Laser Pointer'));
      expect(record['price'], const BeakDoubleValue(19.99));
      expect(record['active'], const BeakBoolValue(true));
      expect(record['discontinued_at'], const BeakNullValue());
      expect(record['created_at'], BeakDateTimeValue(createdAt));
      expect(record.relations, isEmpty);
    });

    test('rejects rows holding unsupported value types', () {
      expect(
        () => BeakRecord.fromRow({'meta': const Duration(seconds: 1)}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('toRow unwraps every value back to plain Dart', () {
      final record = productRecord();
      expect(record.toRow(), {
        'id': 1,
        'name': 'Laser Pointer',
        'price': 19.99,
        'active': true,
        'discontinued_at': null,
        'created_at': createdAt,
      });
    });

    test('round-trips a row through fromRow and toRow', () {
      final row = <String, Object?>{
        'id': 1,
        'name': 'Laser Pointer',
        'created_at': createdAt,
      };
      expect(BeakRecord.fromRow(row).toRow(), row);
    });

    test('round-trips list values through fromRow and toRow', () {
      final row = <String, Object?>{
        'tags': ['a', 'b'],
        'scores': [1, 2.5],
      };
      expect(BeakRecord.fromRow(row).toRow(), row);
    });
  });

  group('JSON round-trip', () {
    test('serializes values and nested relations', () {
      final json = productRecord().toJson();
      expect(json['values'], {
        'id': 1,
        'name': 'Laser Pointer',
        'price': 19.99,
        'active': true,
        'discontinued_at': null,
        'created_at': {'type': 'dateTime', 'value': '2026-07-03T08:30:00.000Z'},
      });
      final relations = json['relations'];
      expect(relations, isA<Map<String, Object?>>());
      if (relations is Map<String, Object?>) {
        expect(relations.keys, ['category', 'tags']);
        expect(relations['category'], [
          {
            'values': {'id': 7, 'name': 'Toys'},
            'relations': const <String, Object?>{},
          },
        ]);
      }
    });

    test('decode(encode(record)) is deep-equal after a JSON wire trip', () {
      final record = productRecord();
      final encoded = jsonEncode(record.toJson());
      final decoded = switch (jsonDecode(encoded)) {
        final Map<String, Object?> map => BeakRecord.fromJson(map),
        final Object? other => fail('expected a JSON object, got $other'),
      };
      expect(decoded, record);
      expect(decoded.hashCode, record.hashCode);
    });

    test('fromJson requires the "values" key', () {
      expect(
        () => BeakRecord.fromJson({'relations': <String, Object?>{}}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson requires the "relations" key', () {
      expect(
        () => BeakRecord.fromJson({'values': <String, Object?>{}}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects a non-map relations value', () {
      expect(
        () => BeakRecord.fromJson({
          'values': <String, Object?>{},
          'relations': <Object?>[],
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects a relation entry that is not a list', () {
      expect(
        () => BeakRecord.fromJson({
          'values': <String, Object?>{},
          'relations': {'category': 42},
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('fromJson rejects a non-map values value', () {
      expect(
        () => BeakRecord.fromJson({
          'values': 42,
          'relations': <String, Object?>{},
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    test('records with equal values and relations are equal', () {
      expect(productRecord(), productRecord());
      expect(productRecord().hashCode, productRecord().hashCode);
    });

    test('differing values, relations, or key sets break equality', () {
      final base = runtimeValue(
        const BeakRecord(values: {'id': BeakIntValue(1)}),
      );
      expect(base, isNot(const BeakRecord(values: {'id': BeakIntValue(2)})));
      expect(base, isNot(const BeakRecord(values: {'pk': BeakIntValue(1)})));
      expect(
        base,
        isNot(
          const BeakRecord(
            values: {'id': BeakIntValue(1)},
            relations: {'tags': <BeakRecord>[]},
          ),
        ),
      );
      expect(base, isNot(const BeakRecord(values: {})));
    });

    test('relation lists compare element-wise', () {
      const a = BeakRecord(
        values: {},
        relations: {
          'tags': [
            BeakRecord(values: {'id': BeakIntValue(1)}),
          ],
        },
      );
      const b = BeakRecord(
        values: {},
        relations: {
          'tags': [
            BeakRecord(values: {'id': BeakIntValue(2)}),
          ],
        },
      );
      expect(runtimeValue(a), isNot(b));
    });
  });

  test('toString names the value keys and relation keys', () {
    final rendered = productRecord().toString();
    expect(rendered, contains('BeakRecord'));
    expect(rendered, contains('name'));
    expect(rendered, contains('category'));
  });
}
