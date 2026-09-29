import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  test('defaults to ascending', () {
    expect(const BeakSort('name').descending, isFalse);
  });

  test('pins the exact JSON map', () {
    expect(const BeakSort('name').toJson(), {
      'column': 'name',
      'descending': false,
    });
    expect(const BeakSort('created_at', descending: true).toJson(), {
      'column': 'created_at',
      'descending': true,
    });
  });

  test('round-trips through JSON losslessly', () {
    const sort = BeakSort('created_at', descending: true);
    expect(BeakSort.fromJson(sort.toJson()), sort);
  });

  group('fromJson', () {
    test('rejects JSON without the column', () {
      expect(
        () => BeakSort.fromJson(const {}),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('"column"'),
          ),
        ),
      );
      expect(
        () => BeakSort.fromJson(const {'descending': true}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('sorts ascending when the direction is omitted', () {
      expect(BeakSort.fromJson(const {'column': 'a'}), const BeakSort('a'));
      expect(
        BeakSort.fromJson(const {'column': 'a', 'descending': null}),
        const BeakSort('a'),
      );
    });

    test('rejects wrongly typed keys', () {
      expect(
        () => BeakSort.fromJson(const {'column': 1, 'descending': false}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakSort.fromJson(const {'column': 'a', 'descending': 'yes'}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    test('equal sorts compare equal and hash consistently', () {
      expect(
        BeakSort(runtimeValue('a'), descending: true),
        const BeakSort('a', descending: true),
      );
      expect(
        BeakSort(runtimeValue('a'), descending: true).hashCode,
        const BeakSort('a', descending: true).hashCode,
      );
    });

    test('sorts differ by column or direction', () {
      expect(const BeakSort('a'), isNot(const BeakSort('b')));
      expect(const BeakSort('a'), isNot(const BeakSort('a', descending: true)));
    });
  });

  test('toString names the column and direction', () {
    expect(const BeakSort('a').toString(), 'BeakSort(a asc)');
    expect(
      const BeakSort('a', descending: true).toString(),
      'BeakSort(a desc)',
    );
  });
}
