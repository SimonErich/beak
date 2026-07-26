import 'package:beak_core/beak_core.dart';
import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';

import '../support/contract_models.dart';

const _product = ProductModel();

/// A model exercising the rule-derived value paths.
final class _AccountModel extends BeakModel {
  const _AccountModel();

  @override
  String get table => 'accounts';

  @override
  String get displayColumnKey => 'email';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'email', label: 'Email', rules: [BeakEmail()]),
    BeakStringColumn(key: 'website', label: 'Website', rules: [BeakUrl()]),
    BeakStringColumn(
      key: 'plan',
      label: 'Plan',
      rules: [
        BeakInList<String>(['free', 'pro']),
      ],
    ),
    BeakStringColumn(
      key: 'code',
      label: 'Code',
      rules: [BeakMinLength(12), BeakMaxLength(14)],
    ),
    BeakTextColumn(key: 'bio', label: 'Bio'),
    BeakJsonColumn(key: 'meta', label: 'Meta'),
    BeakColorColumn(key: 'tint', label: 'Tint'),
    BeakBoolColumn(key: 'active', label: 'Active'),
    BeakDateTimeColumn(key: 'joined_at', label: 'Joined'),
    BeakImageColumn(key: 'avatar', label: 'Avatar', storagePath: 'avatars'),
    BeakCustomColumn(key: 'spark', label: 'Spark', tag: BeakColumnTag('spark')),
  ];
}

void main() {
  group('build', () {
    test('populates every declared column', () {
      final record = beakFakeRecord(const _AccountModel());
      for (final column in const _AccountModel().columns) {
        expect(
          record[column.key],
          isNotNull,
          reason: '${column.key} was not populated',
        );
      }
    });

    test('is deterministic under a fixed seed', () {
      expect(
        beakFakeRecord(_product, seed: 42).toRow(),
        beakFakeRecord(_product, seed: 42).toRow(),
      );
    });

    test('overrides win, and may add columns the model does not declare', () {
      final record = beakFakeRecord(
        _product,
        overrides: {
          ProductColumns.name.key: const BeakStringValue('Espresso'),
          'extra': const BeakIntValue(7),
        },
      );
      expect(record[ProductColumns.name.key]?.raw, 'Espresso');
      expect(record['extra']?.raw, 7);
    });

    test('leaves the soft-delete marker unset', () {
      // A fixture that arrives deleted is invisible to every query.
      final record = beakFakeRecord(_product);
      expect(record[ProductColumns.deletedAt.key], isNull);
    });

    test('sets the soft-delete marker when asked explicitly', () {
      final deleted = beakFakeRecord(
        _product,
        overrides: {
          ProductColumns.deletedAt.key: BeakValue.of(DateTime.utc(2026)),
        },
      );
      expect(deleted[ProductColumns.deletedAt.key]?.raw, DateTime.utc(2026));
    });

    test('derives the primary key from the table', () {
      expect('${beakFakeRecord(_product)['id']?.raw}', startsWith('products-'));
    });
  });

  group('values satisfy their column rules', () {
    late BeakRecord record;

    setUp(() => record = beakFakeRecord(const _AccountModel()));

    test('an email column gets an address', () {
      expect('${record['email']?.raw}', contains('@'));
    });

    test('a url column gets a URL', () {
      expect('${record['website']?.raw}', startsWith('https://'));
    });

    test('an in-list column picks a declared option', () {
      expect(['free', 'pro'], contains('${record['plan']?.raw}'));
    });

    test('length rules bound the generated text', () {
      final String code = '${record['code']?.raw}';
      expect(code.length, greaterThanOrEqualTo(12));
      expect(code.length, lessThanOrEqualTo(14));
    });

    test('numeric bounds are respected', () {
      final product = beakFakeRecord(_product);
      final double price = ProductColumns.price.require(product);
      final int stock = ProductColumns.stock.require(product);
      expect(price, inInclusiveRange(1, 500));
      expect(stock, inInclusiveRange(0, 99));
    });

    test('an enum column picks a declared value', () {
      expect(
        ProductColumns.status.readFrom(beakFakeRecord(_product)),
        isA<ProductStatus>(),
      );
    });

    test('an upload column points inside its storage path', () {
      expect('${record['avatar']?.raw}', startsWith('avatars/'));
    });

    test('a colour column gets a hex value', () {
      expect('${record['tint']?.raw}', matches(RegExp(r'^#[0-9a-f]{6}$')));
    });

    test('the values round-trip through their own typed readers', () {
      // The strongest statement of correctness available: what the factory
      // wrote, the column can read back as its declared type.
      for (final column in const _AccountModel().columns) {
        if (column case final BeakTypedColumn<Object> typed) {
          expect(
            typed.readFrom(record),
            isNotNull,
            reason: '${column.key} produced a value its own column cannot read',
          );
        }
      }
    });
  });

  group('buildMany', () {
    test('produces distinct records', () {
      final records = BeakRecordFactory().buildMany(_product, 3);
      final ids = {for (final record in records) '${record['id']?.raw}'};
      expect(records, hasLength(3));
      expect(ids, hasLength(3), reason: 'each record needs its own key');
    });

    test('applies the same overrides to each', () {
      final records = BeakRecordFactory().buildMany(
        _product,
        3,
        overrides: {ProductColumns.name.key: const BeakStringValue('Same')},
      );
      expect(
        records.every(
          (record) => record[ProductColumns.name.key]?.raw == 'Same',
        ),
        isTrue,
      );
    });

    test('zero records is an empty list, not an error', () {
      expect(BeakRecordFactory().buildMany(_product, 0), isEmpty);
    });
  });
}
