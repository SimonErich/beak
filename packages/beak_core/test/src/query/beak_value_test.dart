import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  final utcInstant = DateTime.utc(2026, 6, 1, 12, 30, 45, 123);
  const utcIso = '2026-06-01T12:30:45.123Z';

  group('BeakValue.of', () {
    test('wraps each supported Dart type in its typed variant', () {
      expect(BeakValue.of(null), const BeakNullValue());
      expect(BeakValue.of(true), const BeakBoolValue(true));
      expect(BeakValue.of(42), const BeakIntValue(42));
      expect(BeakValue.of(1.5), const BeakDoubleValue(1.5));
      expect(BeakValue.of('beak'), const BeakStringValue('beak'));
      expect(BeakValue.of(utcInstant), BeakDateTimeValue(utcInstant));
    });

    test('wraps lists recursively, including nested lists', () {
      expect(
        BeakValue.of([
          1,
          'two',
          null,
          <Object?>[true],
        ]),
        const BeakListValue([
          BeakIntValue(1),
          BeakStringValue('two'),
          BeakNullValue(),
          BeakListValue([BeakBoolValue(true)]),
        ]),
      );
    });

    test('passes an existing BeakValue through unchanged', () {
      const value = BeakIntValue(7);
      expect(BeakValue.of(value), same(value));
      expect(
        BeakValue.of(const [BeakIntValue(1), BeakIntValue(2)]),
        const BeakListValue([BeakIntValue(1), BeakIntValue(2)]),
      );
    });

    test('rejects unsupported types with a configuration error', () {
      expect(
        () => BeakValue.of(const Duration(seconds: 1)),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('Duration'),
          ),
        ),
      );
    });
  });

  group('raw', () {
    test('each variant unwraps to its plain Dart value', () {
      expect(const BeakNullValue().raw, isNull);
      expect(const BeakBoolValue(true).raw, true);
      expect(const BeakIntValue(7).raw, 7);
      expect(const BeakDoubleValue(1.5).raw, 1.5);
      expect(const BeakStringValue('x').raw, 'x');
      expect(BeakDateTimeValue(utcInstant).raw, utcInstant);
    });

    test('lists unwrap recursively', () {
      expect(
        const BeakListValue([
          BeakIntValue(1),
          BeakListValue([BeakStringValue('a')]),
        ]).raw,
        [
          1,
          ['a'],
        ],
      );
    });
  });

  group('toJson', () {
    test('serializes primitives as raw JSON values', () {
      expect(const BeakNullValue().toJson(), isNull);
      expect(const BeakBoolValue(false).toJson(), isFalse);
      expect(const BeakIntValue(3).toJson(), 3);
      expect(const BeakDoubleValue(2.5).toJson(), 2.5);
      expect(const BeakStringValue('x').toJson(), 'x');
    });

    test('serializes DateTime as a tagged object', () {
      expect(BeakDateTimeValue(utcInstant).toJson(), {
        'type': 'dateTime',
        'value': utcIso,
      });
    });

    test('serializes lists element-wise', () {
      expect(
        const BeakListValue([BeakIntValue(1), BeakStringValue('two')]).toJson(),
        [1, 'two'],
      );
    });
  });

  group('fromJson', () {
    test('decodes primitives into their typed variants', () {
      expect(BeakValue.fromJson(null), const BeakNullValue());
      expect(BeakValue.fromJson(true), const BeakBoolValue(true));
      expect(BeakValue.fromJson(42), const BeakIntValue(42));
      expect(BeakValue.fromJson(1.5), const BeakDoubleValue(1.5));
      expect(BeakValue.fromJson('beak'), const BeakStringValue('beak'));
    });

    test('decodes tagged dateTime objects, preserving UTC', () {
      final decoded = BeakValue.fromJson(const <String, Object?>{
        'type': 'dateTime',
        'value': utcIso,
      });
      expect(decoded, BeakDateTimeValue(utcInstant));
      expect(switch (decoded) {
        final BeakDateTimeValue value => value.value.isUtc,
        _ => fail('expected a BeakDateTimeValue, got $decoded'),
      }, isTrue);
    });

    test('decodes lists recursively', () {
      expect(
        BeakValue.fromJson([
          1,
          <String, Object?>{'type': 'dateTime', 'value': utcIso},
        ]),
        BeakListValue([const BeakIntValue(1), BeakDateTimeValue(utcInstant)]),
      );
    });

    test('rejects tagged objects with an unknown type', () {
      expect(
        () => BeakValue.fromJson(const <String, Object?>{
          'type': 'money',
          'value': 1,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects objects without a type tag', () {
      expect(
        () => BeakValue.fromJson(const <String, Object?>{'value': 1}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects dateTime tags whose value is not a string', () {
      expect(
        () => BeakValue.fromJson(const <String, Object?>{
          'type': 'dateTime',
          'value': 5,
        }),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects dateTime tags whose value is not ISO-8601', () {
      expect(
        () => BeakValue.fromJson(const <String, Object?>{
          'type': 'dateTime',
          'value': 'not a timestamp',
        }),
        throwsA(
          isA<BeakConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('not a timestamp'),
          ),
        ),
      );
    });

    test('rejects values outside the JSON data model', () {
      expect(
        () => BeakValue.fromJson(runtimeValue<Object?>(const Duration())),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('round-trips', () {
    test('every variant survives toJson → fromJson', () {
      final values = <BeakValue>[
        const BeakNullValue(),
        const BeakBoolValue(true),
        const BeakIntValue(-7),
        const BeakDoubleValue(3.25),
        const BeakStringValue('beak'),
        BeakDateTimeValue(utcInstant),
        BeakListValue([
          const BeakStringValue('nested'),
          BeakDateTimeValue(utcInstant),
          const BeakListValue([BeakNullValue()]),
        ]),
      ];
      for (final value in values) {
        expect(BeakValue.fromJson(value.toJson()), value);
      }
    });

    test('local DateTimes survive a full JSON string cycle', () {
      final local = BeakDateTimeValue(DateTime(2026, 3, 14, 9, 26, 53));
      final decoded = BeakValue.fromJson(
        jsonDecode(jsonEncode(local.toJson())),
      );
      expect(decoded, local);
    });
  });

  group('equality', () {
    test('equal values compare equal and hash consistently', () {
      expect(BeakStringValue(runtimeValue('a')), const BeakStringValue('a'));
      expect(
        BeakStringValue(runtimeValue('a')).hashCode,
        const BeakStringValue('a').hashCode,
      );
      expect(BeakIntValue(runtimeValue(1)), const BeakIntValue(1));
      expect(
        BeakIntValue(runtimeValue(1)).hashCode,
        const BeakIntValue(1).hashCode,
      );
      expect(BeakDoubleValue(runtimeValue(1.5)), const BeakDoubleValue(1.5));
      expect(
        BeakDoubleValue(runtimeValue(1.5)).hashCode,
        const BeakDoubleValue(1.5).hashCode,
      );
      expect(BeakBoolValue(runtimeValue(true)), const BeakBoolValue(true));
      expect(
        BeakBoolValue(runtimeValue(true)).hashCode,
        const BeakBoolValue(true).hashCode,
      );
      expect(const BeakNullValue(), runtimeValue(const BeakNullValue()));
      expect(
        const BeakNullValue().hashCode,
        runtimeValue(const BeakNullValue()).hashCode,
      );
      expect(
        BeakDateTimeValue(runtimeValue(utcInstant)),
        BeakDateTimeValue(utcInstant),
      );
      expect(
        BeakDateTimeValue(runtimeValue(utcInstant)).hashCode,
        BeakDateTimeValue(utcInstant).hashCode,
      );
      expect(
        BeakListValue(runtimeValue(const [BeakIntValue(1)])),
        const BeakListValue([BeakIntValue(1)]),
      );
      expect(
        BeakListValue(runtimeValue(const [BeakIntValue(1)])).hashCode,
        const BeakListValue([BeakIntValue(1)]).hashCode,
      );
    });

    test('different payloads or variants are not equal', () {
      expect(const BeakStringValue('a'), isNot(const BeakStringValue('b')));
      expect(const BeakIntValue(1), isNot(const BeakIntValue(2)));
      expect(const BeakIntValue(1), isNot(const BeakDoubleValue(1)));
      expect(const BeakDoubleValue(1), isNot(const BeakDoubleValue(2)));
      expect(const BeakBoolValue(true), isNot(const BeakBoolValue(false)));
      expect(const BeakNullValue(), isNot(const BeakBoolValue(false)));
      expect(
        BeakDateTimeValue(utcInstant),
        isNot(BeakDateTimeValue(DateTime.utc(2000))),
      );
      expect(
        const BeakListValue([BeakIntValue(1)]),
        isNot(const BeakListValue([BeakIntValue(1), BeakIntValue(2)])),
      );
      expect(
        const BeakListValue([BeakIntValue(1)]),
        isNot(const BeakListValue([BeakIntValue(2)])),
      );
    });
  });

  group('toString', () {
    test('names the variant and its payload', () {
      expect(const BeakStringValue('a').toString(), 'BeakStringValue(a)');
      expect(const BeakIntValue(3).toString(), 'BeakIntValue(3)');
      expect(const BeakDoubleValue(2.5).toString(), 'BeakDoubleValue(2.5)');
      expect(const BeakBoolValue(true).toString(), 'BeakBoolValue(true)');
      expect(const BeakNullValue().toString(), 'BeakNullValue()');
      expect(
        BeakDateTimeValue(utcInstant).toString(),
        'BeakDateTimeValue(2026-06-01 12:30:45.123Z)',
      );
      expect(
        const BeakListValue([BeakIntValue(1)]).toString(),
        'BeakListValue([BeakIntValue(1)])',
      );
    });
  });
}
