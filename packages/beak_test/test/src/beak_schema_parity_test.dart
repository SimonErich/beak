import 'package:beak_test/beak_test.dart';
import 'package:test/test.dart';

import '../support/contract_models.dart';

/// The schema the fixture registry expects, in full.
BeakSchemaColumns completeSchema() => {
  'products': {
    'id',
    'name',
    'price',
    'stock',
    'status',
    'category_id',
    'deleted_at',
  },
  'categories': {'id', 'name'},
  'tags': {'id', 'name'},
  'product_tag': {'product_id', 'tag_id'},
};

void main() {
  final registry = buildContractRegistry();

  group('expectSchemaParity', () {
    test('passes when the schema has everything the models declare', () {
      expectSchemaParity(registry: registry, actual: completeSchema());
    });

    test('fails, naming the table, when one is missing', () {
      final schema = completeSchema()..remove('categories');
      expect(
        () => expectSchemaParity(registry: registry, actual: schema),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            allOf(contains('categories'), contains('missing')),
          ),
        ),
      );
    });

    test('fails, naming the column, when one is missing', () {
      final schema = completeSchema()..['products']!.remove('price');
      expect(
        () => expectSchemaParity(registry: registry, actual: schema),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            contains('products.price'),
          ),
        ),
      );
    });

    test('fails when a belongs-to foreign key is missing', () {
      // The FK is implied by the relationship, not declared as a column, so
      // it needs its own check.
      final schema = completeSchema()..['products']!.remove('category_id');
      expect(
        () => expectSchemaParity(registry: registry, actual: schema),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            allOf(contains('category_id'), contains('"category"')),
          ),
        ),
      );
    });

    test('fails when a soft-deleting model has no deleted_at', () {
      final schema = completeSchema()..['products']!.remove('deleted_at');
      expect(
        () => expectSchemaParity(registry: registry, actual: schema),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            contains('soft-deletes'),
          ),
        ),
      );
    });

    test('reports every problem at once, not just the first', () {
      final schema = completeSchema()
        ..remove('categories')
        ..['products']!.remove('price');
      expect(
        () => expectSchemaParity(registry: registry, actual: schema),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            allOf(contains('categories'), contains('products.price')),
          ),
        ),
      );
    });

    test('honours the ignore lists', () {
      final schema = completeSchema()
        ..remove('categories')
        ..['products']!.remove('price');
      expectSchemaParity(
        registry: registry,
        actual: schema,
        ignoreTables: {'categories'},
        ignoreColumns: {'price'},
      );
    });
  });

  group('expectNoOrphanTables', () {
    test('passes when every table is modelled or is a pivot', () {
      expectNoOrphanTables(registry: registry, actual: completeSchema());
    });

    test('ignores framework bookkeeping tables', () {
      final schema = completeSchema()..['worm_migrations'] = {'id', 'name'};
      expectNoOrphanTables(registry: registry, actual: schema);
    });

    test('fails, naming the table, on an unmodelled one', () {
      final schema = completeSchema()..['legacy_audit'] = {'id'};
      expect(
        () => expectNoOrphanTables(registry: registry, actual: schema),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            contains('legacy_audit'),
          ),
        ),
      );
    });

    test('honours the ignore list', () {
      final schema = completeSchema()..['legacy_audit'] = {'id'};
      expectNoOrphanTables(
        registry: registry,
        actual: schema,
        ignoreTables: {'legacy_audit'},
      );
    });
  });
}
