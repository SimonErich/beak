import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/beak_serverpod.dart';
import 'package:test/test.dart';

enum _Status { open, closed }

void main() {
  test('preserves false, null, enum, DateTime and lists without coercion', () {
    expect(
      ServerpodCodecs.boolean.nullable.decode(const BeakNullValue()),
      isNull,
    );
    expect(
      ServerpodCodecs.boolean.nullable.decode(const BeakBoolValue(false)),
      isFalse,
    );
    final now = DateTime.utc(2026, 9, 26);
    expect(
      ServerpodCodecs.dateTime.decode(ServerpodCodecs.dateTime.encode(now)),
      now,
    );
    final status = ServerpodCodecs.enumeration(_Status.values);
    expect(status.decode(status.encode(_Status.closed)), _Status.closed);
    expect(
      () => status.decode(const BeakStringValue('missing')),
      throwsA(isA<BeakValidationException>()),
    );
    expect(
      ServerpodCodecs.integer.list.decode(
        const BeakListValue([BeakIntValue(3)]),
      ),
      [3],
    );
    expect(
      () => ServerpodCodecs.integer.decode(const BeakDoubleValue(1.5)),
      throwsA(isA<BeakValidationException>()),
    );
    expect(
      () => ServerpodCodecs.string.decode(const BeakIntValue(2)),
      throwsA(isA<BeakValidationException>()),
    );
  });

  test(
    'nested form paths decode without raw JSON and explicit null stays present',
    () {
      const input = BeakRecord(
        values: {
          'user.name': BeakNullValue(),
          'user.enabled': BeakBoolValue(false),
        },
      );
      final nested = serverpodNestedInput(input, 'user');
      expect(nested?.values.containsKey('name'), isTrue);
      expect(nested?['enabled']?.raw, isFalse);
      expect(serverpodNestedInput(input, 'other'), isNull);
      expect(
        serverpodFlatten('user', nested!)['user.name'],
        const BeakNullValue(),
      );
    },
  );

  test('scalar collections preserve null elements and typed sets', () {
    final list = ServerpodCodecs.string.nullable.list;
    expect(list.decode(list.encode(['one', null])), ['one', null]);
    final set = ServerpodCodecs.integer.set;
    expect(set.decode(set.encode({2, 3})), {2, 3});
    expect(ServerpodCodecs.decimal.decode(const BeakIntValue(2)), 2.0);
    expect(
      ServerpodCodecs.decimal.decode(ServerpodCodecs.decimal.encode(2.5)),
      2.5,
    );
    final uri = Uri.parse('https://example.com/profile');
    expect(ServerpodCodecs.uri.decode(ServerpodCodecs.uri.encode(uri)), uri);
    for (final decode in <Object? Function()>[
      () => list.decode(const BeakStringValue('wrong')),
      () => set.decode(const BeakNullValue()),
      () => ServerpodCodecs.decimal.decode(const BeakBoolValue(false)),
      () => ServerpodCodecs.boolean.decode(const BeakStringValue('false')),
      () =>
          ServerpodCodecs.dateTime.decode(const BeakStringValue('2026-01-01')),
      () => ServerpodCodecs.uri.decode(const BeakBoolValue(true)),
    ]) {
      expect(decode, throwsA(isA<BeakValidationException>()));
    }
  });

  test(
    'edited nested paths override loaded relations while explicit null clears',
    () {
      const loaded = BeakRecord(values: {'name': BeakStringValue('Old')});
      const edited = BeakRecord(
        values: {'user.name': BeakStringValue('New')},
        relations: {
          'user': [loaded],
          'user.roles': [],
        },
      );
      final result = requireServerpodNestedInput(edited, 'user');
      expect(result['name']?.raw, 'New');
      expect(requireServerpodRelatedInputs(result, 'roles'), isEmpty);
      expect(
        serverpodNestedInput(
          const BeakRecord(
            values: {'user': BeakNullValue()},
            relations: {
              'user': [loaded],
            },
          ),
          'user',
        ),
        isNull,
      );
      expect(
        () => serverpodNestedInput(
          const BeakRecord(
            values: {},
            relations: {
              'user': [loaded, loaded],
            },
          ),
          'user',
        ),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        () => requireServerpodNestedInput(const BeakRecord(values: {}), 'user'),
        throwsA(isA<BeakValidationException>()),
      );
      expect(
        () => requireServerpodRelatedInputs(
          const BeakRecord(values: {}),
          'roles',
        ),
        throwsA(isA<BeakValidationException>()),
      );
    },
  );
}
