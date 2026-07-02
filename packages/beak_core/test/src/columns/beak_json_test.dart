import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  const tree = BeakJsonObject({
    'name': BeakJsonString('Beak'),
    'version': BeakJsonNumber(2),
    'stable': BeakJsonBool(false),
    'license': BeakJsonNull(),
    'tags': BeakJsonArray([BeakJsonString('admin'), BeakJsonString('dart')]),
    'meta': BeakJsonObject({'rating': BeakJsonNumber(4.5)}),
  });

  const source =
      '{"name":"Beak","version":2,"stable":false,"license":null,'
      '"tags":["admin","dart"],"meta":{"rating":4.5}}';

  test('encodes a typed tree to a compact JSON document', () {
    expect(tree.encode(), source);
  });

  test('decodes a JSON document into an equal typed tree', () {
    expect(BeakJson.decode(source), tree);
  });

  test('round-trips through encode and decode', () {
    final decoded = BeakJson.decode(tree.encode());
    expect(decoded, tree);
    expect(decoded.encode(), source);
  });

  test('toEncodable produces plain Dart JSON structures', () {
    expect(const BeakJsonNull().toEncodable(), isNull);
    expect(const BeakJsonBool(true).toEncodable(), isTrue);
    expect(const BeakJsonNumber(3).toEncodable(), 3);
    expect(const BeakJsonString('x').toEncodable(), 'x');
    expect(const BeakJsonArray([BeakJsonNumber(1)]).toEncodable(), const [1]);
    expect(const BeakJsonObject({'a': BeakJsonNumber(1)}).toEncodable(), const {
      'a': 1,
    });
  });

  test('rejects values outside the JSON data model', () {
    expect(
      () => BeakJson.fromEncodable(DateTime.utc(2026)),
      throwsArgumentError,
    );
  });

  test('rejects object keys that are not strings', () {
    expect(
      () => BeakJson.fromEncodable({runtimeValue<Object?>(1): 'x'}),
      throwsArgumentError,
    );
  });

  group('equality', () {
    test('objects compare unordered and hash consistently', () {
      final first = BeakJsonObject({
        runtimeValue('x'): const BeakJsonNumber(1),
        'y': const BeakJsonNumber(2),
      });
      final second = BeakJsonObject({
        runtimeValue('y'): const BeakJsonNumber(2),
        'x': const BeakJsonNumber(1),
      });
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('objects with different sizes, keys or values differ', () {
      final small = BeakJsonObject({
        runtimeValue('x'): const BeakJsonNumber(1),
      });
      expect(
        small,
        isNot(
          const BeakJsonObject({
            'x': BeakJsonNumber(1),
            'y': BeakJsonNumber(2),
          }),
        ),
      );
      expect(small, isNot(const BeakJsonObject({'x': BeakJsonNumber(9)})));
      expect(small, isNot(const BeakJsonObject({'z': BeakJsonNumber(1)})));
      expect(small == runtimeValue<Object>(const BeakJsonArray([])), isFalse);
    });

    test('arrays compare element-wise in order', () {
      final array = BeakJsonArray([
        BeakJsonNumber(runtimeValue(1)),
        const BeakJsonNumber(2),
      ]);
      const expected = BeakJsonArray([BeakJsonNumber(1), BeakJsonNumber(2)]);
      expect(array, expected);
      expect(array.hashCode, expected.hashCode);
      expect(
        array,
        isNot(const BeakJsonArray([BeakJsonNumber(2), BeakJsonNumber(1)])),
      );
      expect(array, isNot(const BeakJsonArray([BeakJsonNumber(1)])));
      expect(array == runtimeValue<Object>(const BeakJsonNull()), isFalse);
    });

    test('scalars compare by value and never across types', () {
      expect(BeakJsonString(runtimeValue('1')), const BeakJsonString('1'));
      expect(
        BeakJsonString(runtimeValue('1')).hashCode,
        const BeakJsonString('1').hashCode,
      );
      expect(BeakJsonNumber(runtimeValue(1)), const BeakJsonNumber(1));
      expect(
        BeakJsonNumber(runtimeValue(1)).hashCode,
        const BeakJsonNumber(1).hashCode,
      );
      expect(BeakJsonBool(runtimeValue(true)), const BeakJsonBool(true));
      expect(
        BeakJsonBool(runtimeValue(true)).hashCode,
        const BeakJsonBool(true).hashCode,
      );
      expect(
        BeakJsonString(runtimeValue('1')),
        isNot(const BeakJsonString('2')),
      );
      expect(BeakJsonNumber(runtimeValue(1)), isNot(const BeakJsonNumber(2)));
      expect(
        BeakJsonBool(runtimeValue(true)),
        isNot(const BeakJsonBool(false)),
      );
      expect(
        const BeakJsonString('1') ==
            runtimeValue<Object>(const BeakJsonNumber(1)),
        isFalse,
      );
      expect(
        const BeakJsonNull() == runtimeValue<Object>(const BeakJsonNull()),
        isTrue,
      );
      expect(const BeakJsonNull() == runtimeValue<Object>(0), isFalse);
      expect(const BeakJsonNull().hashCode, null.hashCode);
    });
  });

  test('prints readable debug output', () {
    expect(tree.toString(), contains('Beak'));
    expect(const BeakJsonArray([]).toString(), contains('BeakJsonArray'));
    expect(const BeakJsonNumber(1).toString(), contains('1'));
    expect(const BeakJsonBool(true).toString(), contains('true'));
    expect(const BeakJsonNull().toString(), 'BeakJsonNull()');
    expect(const BeakJsonString('x').toString(), contains('x'));
  });
}
