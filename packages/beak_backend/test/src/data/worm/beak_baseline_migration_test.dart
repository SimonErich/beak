import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

abstract final class _CategoryColumns {
  static const id = BeakStringColumn(key: 'id', label: 'Id');
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    rules: [BeakRequired()],
  );

  static const List<BeakColumn> values = [id, name];
}

final class _CategoryModel extends BeakModel {
  const _CategoryModel();

  @override
  String get table => 'categories';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => _CategoryColumns.values;
}

abstract final class _TagColumns {
  static const id = BeakStringColumn(key: 'id', label: 'Id');
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    rules: [BeakRequired()],
  );

  static const List<BeakColumn> values = [id, name];
}

final class _TagModel extends BeakModel {
  const _TagModel();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => _TagColumns.values;
}

abstract final class _ProductRelations {
  static const category = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'categories',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
  );
  static const tags = BeakBelongsToMany(
    key: 'tags',
    label: 'Tags',
    relatedTable: 'tags',
    displayColumnKey: 'name',
    pivotTable: 'product_tag',
    foreignPivotKey: 'product_id',
    relatedPivotKey: 'tag_id',
  );
}

final class _ProductModel extends BeakModel {
  const _ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name', rules: [BeakRequired()]),
    BeakStringColumn(key: 'category_id', label: 'Category'),
  ];

  @override
  List<BeakRelationship> get relationships => const [
    _ProductRelations.category,
    _ProductRelations.tags,
  ];
}

/// A pivot no model in the baseline declares, so nothing knows its owner.
const BeakBelongsToMany _orphanPivot = BeakBelongsToMany(
  key: 'orphans',
  label: 'Orphans',
  relatedTable: 'tags',
  displayColumnKey: 'name',
  pivotTable: 'orphan_tag',
  foreignPivotKey: 'orphan_id',
  relatedPivotKey: 'tag_id',
);

/// The shape `beak introspect` writes: every model in foreign-key order and
/// the many-to-many pivots.
final class _AdoptShop extends BeakBaselineMigration {
  const _AdoptShop();

  @override
  String get name => '20260928_101500_adopt_existing_schema';

  @override
  List<BeakModel> get models => const [
    _CategoryModel(),
    _TagModel(),
    _ProductModel(),
  ];

  @override
  List<BeakBelongsToMany> get pivots => const [_ProductRelations.tags];
}

final class _OrphanPivotBaseline extends BeakBaselineMigration {
  const _OrphanPivotBaseline();

  @override
  String get name => '20260928_101501_orphan';

  @override
  List<BeakModel> get models => const [_TagModel()];

  @override
  List<BeakBelongsToMany> get pivots => const [_orphanPivot];
}

final class _ModelsOnly extends BeakBaselineMigration {
  const _ModelsOnly();

  @override
  String get name => '20260928_101502_models_only';

  @override
  List<BeakModel> get models => const [_CategoryModel()];
}

/// A table with a foreign key to one that appears later in the list, as a
/// cycle in the source database forces.
final class _ForwardReference extends BeakBaselineMigration {
  const _ForwardReference();

  @override
  String get name => '20260928_101503_forward_reference';

  @override
  List<BeakModel> get models => const [_ProductModel(), _CategoryModel()];
}

Future<Set<String>> _tablesOf(DatabaseAdapter adapter) async =>
    (await adapter.introspectSchema()).keys.toSet();

Future<Map<String, List<String>>> _schemaOf(DatabaseAdapter adapter) =>
    adapter.introspectSchema();

void main() {
  late SqliteAdapter adapter;

  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
  });

  tearDown(() => adapter.disconnect());

  MigrationRunner runnerOf(Migration migration) =>
      MigrationRunner(adapter: adapter, migrations: [migration]);

  group('on a database that has nothing', () {
    test('builds every table and pivot, in list order', () async {
      final applied = await runnerOf(const _AdoptShop()).migrate();

      expect(applied, ['20260928_101500_adopt_existing_schema']);
      expect(
        await _tablesOf(adapter),
        containsAll(['categories', 'tags', 'products', 'product_tag']),
      );
      final schema = await _schemaOf(adapter);
      expect(schema['products'], containsAll(['id', 'name', 'category_id']));
      expect(schema['product_tag'], containsAll(['product_id', 'tag_id']));
    });

    test('declares the foreign keys of the tables it creates', () async {
      await runnerOf(const _AdoptShop()).migrate();

      final foreignKeys = await adapter.rawQuery(
        'PRAGMA foreign_key_list(products)',
        const <Object?>[],
      );
      expect(foreignKeys.single['table'], 'categories');
      expect(foreignKeys.single['from'], 'category_id');
    });

    test('is recorded as applied', () async {
      final runner = runnerOf(const _AdoptShop());
      await runner.migrate();

      final statuses = await runner.status();
      expect(statuses.single.state, MigrationState.applied);
    });

    test('leaves out a foreign key whose target comes later', () async {
      await runnerOf(const _ForwardReference()).migrate();

      final foreignKeys = await adapter.rawQuery(
        'PRAGMA foreign_key_list(products)',
        const <Object?>[],
      );
      expect(foreignKeys, isEmpty);
      expect(await _tablesOf(adapter), containsAll(['products', 'categories']));
    });

    test('a baseline without pivots creates only its tables', () async {
      await runnerOf(const _ModelsOnly()).migrate();

      final tables = await _tablesOf(adapter);
      expect(tables, contains('categories'));
      expect(tables, isNot(contains('product_tag')));
    });
  });

  group('on a database that already has the tables', () {
    setUp(() async {
      await adapter.rawQuery(
        'CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT, legacy TEXT)',
        const <Object?>[],
      );
      await adapter.rawQuery(
        'CREATE TABLE products (id TEXT PRIMARY KEY, name TEXT)',
        const <Object?>[],
      );
      await adapter.rawQuery(
        "INSERT INTO categories (id, name, legacy) VALUES ('c1', 'Tools', 'x')",
        const <Object?>[],
      );
    });

    test('leaves an existing table exactly as it was', () async {
      await runnerOf(const _AdoptShop()).migrate();

      final schema = await _schemaOf(adapter);
      // `products` has no category_id in this database, and the baseline must
      // not add it: it only ever creates what is absent.
      expect(schema['products'], ['id', 'name']);
      expect(schema['categories'], ['id', 'name', 'legacy']);
      final rows = await adapter.rawQuery(
        'SELECT * FROM categories',
        const <Object?>[],
      );
      expect(rows.single['legacy'], 'x');
    });

    test('creates only the tables and pivots that are absent', () async {
      await runnerOf(const _AdoptShop()).migrate();

      expect(
        await _tablesOf(adapter),
        containsAll(['categories', 'products', 'tags', 'product_tag']),
      );
    });

    test('is recorded as applied even when it changed nothing', () async {
      await adapter.rawQuery(
        'CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT)',
        const <Object?>[],
      );
      await adapter.rawQuery(
        'CREATE TABLE product_tag (product_id TEXT, tag_id TEXT)',
        const <Object?>[],
      );
      final runner = runnerOf(const _AdoptShop());

      final applied = await runner.migrate();

      expect(applied, ['20260928_101500_adopt_existing_schema']);
      expect((await runner.status()).single.state, MigrationState.applied);
      expect((await _schemaOf(adapter))['product_tag'], [
        'product_id',
        'tag_id',
      ], reason: 'an existing pivot is never rebuilt');
    });

    test('applying it twice is a no-op the second time', () async {
      final runner = runnerOf(const _AdoptShop());
      await runner.migrate();

      expect(await runner.migrate(), isEmpty);
    });
  });

  group('a pivot nobody owns', () {
    test('cannot be created, and the failure names it', () async {
      await expectLater(
        runnerOf(const _OrphanPivotBaseline()).migrate(),
        throwsA(
          isA<MigrationException>().having(
            (error) => error.message,
            'message',
            contains('orphan_tag'),
          ),
        ),
      );
    });

    test('is not needed when the database already has it', () async {
      await adapter.rawQuery(
        'CREATE TABLE orphan_tag (orphan_id TEXT, tag_id TEXT)',
        const <Object?>[],
      );

      await runnerOf(const _OrphanPivotBaseline()).migrate();

      expect(await _tablesOf(adapter), contains('tags'));
    });
  });

  group('going back', () {
    test('the exception says why and what to do', () {
      const exception = BeakIrreversibleMigrationException('adopt_it');

      expect(exception.toString(), contains('adopt_it'));
      expect(exception.toString(), contains('cannot be rolled back'));
    });

    test(
      'a rollback refuses, names the migration, and drops nothing',
      () async {
        final runner = runnerOf(const _AdoptShop());
        await runner.migrate();

        await expectLater(
          runner.rollback(),
          throwsA(
            isA<MigrationException>()
                .having(
                  (error) => error.migration,
                  'migration',
                  '20260928_101500_adopt_existing_schema',
                )
                .having(
                  (error) => error.message,
                  'message',
                  contains('BeakIrreversibleMigrationException'),
                ),
          ),
        );

        expect(await _tablesOf(adapter), contains('products'));
        expect((await runner.status()).single.state, MigrationState.applied);
      },
    );
  });
}
