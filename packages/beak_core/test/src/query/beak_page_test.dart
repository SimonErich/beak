import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';

import '../../support/runtime_values.dart';

/// A minimal typed record item exercising the (de)serializer seam.
final class _Product {
  const _Product(this.name, this.priceInCents);

  final String name;
  final int priceInCents;

  Map<String, Object?> toJson() => {
    'name': name,
    'price_in_cents': priceInCents,
  };

  static _Product fromJson(Object? json) => switch (json) {
    {'name': final String name, 'price_in_cents': final int priceInCents} =>
      _Product(name, priceInCents),
    _ => throw BeakConfigurationException('Malformed product JSON: $json.'),
  };

  @override
  bool operator ==(Object other) =>
      other is _Product &&
      other.name == name &&
      other.priceInCents == priceInCents;

  @override
  int get hashCode => Object.hash(name, priceInCents);
}

void main() {
  const page = BeakPage<_Product>(
    items: [_Product('Stapler', 999), _Product('Desk', 24900)],
    total: 12,
    page: 1,
    perPage: 2,
  );

  test('pins the exact JSON map given an item serializer', () {
    expect(page.toJson((item) => item.toJson()), {
      'items': [
        {'name': 'Stapler', 'price_in_cents': 999},
        {'name': 'Desk', 'price_in_cents': 24900},
      ],
      'total': 12,
      'page': 1,
      'perPage': 2,
    });
  });

  test('round-trips through JSON given an item deserializer', () {
    expect(
      BeakPage.fromJson(
        page.toJson((item) => item.toJson()),
        _Product.fromJson,
      ),
      page,
    );
  });

  test('an empty page round-trips', () {
    const empty = BeakPage<_Product>(items: [], total: 0, page: 1, perPage: 25);
    expect(
      BeakPage.fromJson(
        empty.toJson((item) => item.toJson()),
        _Product.fromJson,
      ),
      empty,
    );
  });

  group('fromJson', () {
    test('rejects JSON whose items is missing or not a list', () {
      expect(
        () => BeakPage.fromJson(const {
          'total': 0,
          'page': 1,
          'perPage': 25,
        }, _Product.fromJson),
        throwsA(isA<BeakConfigurationException>()),
      );
      expect(
        () => BeakPage.fromJson(const {
          'items': 'nope',
          'total': 0,
          'page': 1,
          'perPage': 25,
        }, _Product.fromJson),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('rejects missing or non-integer envelope numbers', () {
      for (final key in const ['total', 'page', 'perPage']) {
        final missing = page.toJson((item) => item.toJson())..remove(key);
        expect(
          () => BeakPage.fromJson(missing, _Product.fromJson),
          throwsA(isA<BeakConfigurationException>()),
          reason: 'missing "$key" must be rejected',
        );
        final wrong = page.toJson((item) => item.toJson())..[key] = 'x';
        expect(
          () => BeakPage.fromJson(wrong, _Product.fromJson),
          throwsA(isA<BeakConfigurationException>()),
          reason: 'non-integer "$key" must be rejected',
        );
      }
    });

    test('lets item deserializer failures propagate', () {
      expect(
        () => BeakPage.fromJson(const {
          'items': [7],
          'total': 1,
          'page': 1,
          'perPage': 25,
        }, _Product.fromJson),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });

  group('equality', () {
    test('equal pages compare equal and hash consistently', () {
      final rebuilt = BeakPage<_Product>(
        items: runtimeValue(const [
          _Product('Stapler', 999),
          _Product('Desk', 24900),
        ]),
        total: 12,
        page: 1,
        perPage: 2,
      );
      expect(rebuilt, page);
      expect(rebuilt.hashCode, page.hashCode);
    });

    test('pages differ by items or envelope numbers', () {
      expect(
        page,
        isNot(
          const BeakPage<_Product>(
            items: [_Product('Stapler', 999)],
            total: 12,
            page: 1,
            perPage: 2,
          ),
        ),
      );
      expect(
        page,
        isNot(
          const BeakPage<_Product>(
            items: [_Product('Stapler', 999), _Product('Desk', 1)],
            total: 12,
            page: 1,
            perPage: 2,
          ),
        ),
      );
      expect(
        page,
        isNot(
          const BeakPage<_Product>(
            items: [_Product('Stapler', 999), _Product('Desk', 24900)],
            total: 13,
            page: 1,
            perPage: 2,
          ),
        ),
      );
      expect(
        page,
        isNot(
          const BeakPage<_Product>(
            items: [_Product('Stapler', 999), _Product('Desk', 24900)],
            total: 12,
            page: 2,
            perPage: 2,
          ),
        ),
      );
      expect(
        page,
        isNot(
          const BeakPage<_Product>(
            items: [_Product('Stapler', 999), _Product('Desk', 24900)],
            total: 12,
            page: 1,
            perPage: 3,
          ),
        ),
      );
    });
  });

  test('toString names the envelope', () {
    expect(
      const BeakPage<int>(items: [1], total: 9, page: 2, perPage: 1).toString(),
      'BeakPage(1 of 9 items, page 2, perPage 1)',
    );
  });
}
