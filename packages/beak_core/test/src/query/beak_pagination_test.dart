import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

void main() {
  test('defaults to the first page of 25 records', () {
    const pagination = BeakPagination();
    expect(pagination.page, 1);
    expect(pagination.perPage, 25);
  });

  test('asserts that page and perPage are positive', () {
    expect(
      () => BeakPagination(page: runtimeValue(0)),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => BeakPagination(perPage: runtimeValue(0)),
      throwsA(isA<AssertionError>()),
    );
  });

  test('pins the exact JSON map', () {
    expect(const BeakPagination().toJson(), {'page': 1, 'perPage': 25});
    expect(const BeakPagination(page: 3, perPage: 50).toJson(), {
      'page': 3,
      'perPage': 50,
    });
  });

  test('round-trips through JSON losslessly', () {
    const pagination = BeakPagination(page: 3, perPage: 50);
    expect(BeakPagination.fromJson(pagination.toJson()), pagination);
  });

  group('fromJson', () {
    test('fills a missing key with the constructor default', () {
      expect(BeakPagination.fromJson(const {}), const BeakPagination());
      expect(
        BeakPagination.fromJson(const {'page': 3}),
        const BeakPagination(page: 3),
      );
      expect(
        BeakPagination.fromJson(const {'perPage': 50}),
        const BeakPagination(perPage: 50),
      );
      expect(
        BeakPagination.fromJson(const {'page': null, 'perPage': null}),
        const BeakPagination(),
      );
    });

    test('names the key of a wrongly typed value', () {
      expect(
        () => BeakPagination.fromJson(const {'perPage': 'many'}),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('"perPage"'),
          ),
        ),
      );
    });

    test('rejects wrongly typed keys', () {
      expect(
        () => BeakPagination.fromJson(const {'page': 'one', 'perPage': 25}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakPagination.fromJson(const {'page': 1, 'perPage': 2.5}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects non-positive pages and page sizes', () {
      expect(
        () => BeakPagination.fromJson(const {'page': 0, 'perPage': 25}),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakPagination.fromJson(const {'page': 1, 'perPage': -1}),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    test('equal paginations compare equal and hash consistently', () {
      expect(
        BeakPagination(page: runtimeValue(2)),
        const BeakPagination(page: 2),
      );
      expect(
        BeakPagination(page: runtimeValue(2)).hashCode,
        const BeakPagination(page: 2).hashCode,
      );
    });

    test('paginations differ by page or page size', () {
      expect(const BeakPagination(), isNot(const BeakPagination(page: 2)));
      expect(const BeakPagination(), isNot(const BeakPagination(perPage: 50)));
    });
  });

  test('toString names page and page size', () {
    expect(
      const BeakPagination(page: 2, perPage: 50).toString(),
      'BeakPagination(page 2, perPage 50)',
    );
  });
}
