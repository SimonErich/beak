import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../../support/beak_cli_internals.dart';
import 'package:test/test.dart';

import '../../support/fake_database.dart';

/// A reader that fails if anything reaches for it.
Future<List<IntrospectedTable>> neverRead(
  Uri url, {
  String schema = 'public',
}) async => throw StateError('a test read the live schema of $url');

void main() {
  group('PostgresIntrospector', () {
    late List<IntrospectedTable> tables;

    setUp(() async => tables = await readShop());

    test('reads every base table, in name order', () {
      expect(tables.map((table) => table.name), [
        'categories',
        'product_tag',
        'products',
        'tags',
        'users',
        'worm_migrations',
      ]);
    });

    test('reads types, nullability, length and defaults', () {
      final products = tableNamed(tables, 'products');
      final byName = {for (final c in products.columns) c.name: c};
      expect(byName['name']!.dataType, 'character varying');
      expect(byName['name']!.isNullable, isFalse);
      expect(byName['name']!.maxLength, 255);
      expect(byName['description']!.isNullable, isTrue);
      expect(byName['stock']!.hasDefault, isTrue);
    });

    test('resolves enum labels in declaration order', () {
      final status = tableNamed(
        tables,
        'products',
      ).columns.firstWhere((c) => c.name == 'status');
      expect(status.enumTypeName, 'product_status');
      expect(status.enumValues, ['draft', 'published']);
    });

    test('reads the indexes a table already has', () {
      // An index the database has is a decision about how it is queried.
      // Reading it back is what keeps a round trip from handing back a schema
      // that looks right and runs slowly.
      final byName = {
        for (final c in tableNamed(tables, 'products').columns) c.name: c,
      };

      expect(byName['name']?.isIndexed, isTrue);
      expect(byName['name']?.isUnique, isFalse);
      expect(byName['sku']?.isIndexed, isTrue);
      expect(byName['sku']?.isUnique, isTrue);
      expect(byName['price']?.isIndexed, isFalse);
    });

    test('reads foreign keys and primary keys', () {
      expect(
        tableNamed(tables, 'products').foreignKeys.single.column,
        'category_id',
      );
      expect(tableNamed(tables, 'products').primaryKey, 'id');
    });

    test('detects the soft-delete and timestamp conventions', () {
      expect(tableNamed(tables, 'products').softDeletes, isTrue);
      expect(tableNamed(tables, 'products').timestamps, isTrue);
      expect(tableNamed(tables, 'categories').softDeletes, isFalse);
    });

    test('recognises a pure join table as a pivot', () {
      expect(tableNamed(tables, 'product_tag').isPivot, isTrue);
      expect(tableNamed(tables, 'products').isPivot, isFalse);
    });
  });

  group('emitting schema classes', () {
    late Map<String, IntrospectedSchemaFile> files;

    setUp(() async {
      final emitted = BeakIntrospectionEmitter.emitAll(await readShop());
      files = {for (final file in emitted) file.table: file};
    });

    test('emits one resource per non-pivot table, plus its enums', () {
      expect(
        files.keys,
        unorderedEquals([
          'categories',
          'products',
          'product_status',
          'tags',
          'users',
        ]),
      );
    });

    test('carries a read index onto the column it belongs to', () {
      final String source = files['products']!.contents;

      expect(source, contains('indexed: true'));
      expect(source, contains('unique: true'));
      // The primary key and the foreign key never reach a `@Column`: the
      // schema class does not declare either.
      expect(source, isNot(contains('late final String id;')));
    });

    test('declares the database enum so the emitted type resolves', () {
      final status = files['product_status']!;
      expect(status.className, 'ProductStatus');
      expect(status.contents, contains('enum ProductStatus {'));
      expect(status.contents, contains('  draft,'));
      expect(status.contents, contains('  published,'));
    });

    test('a resource using an enum imports it', () {
      expect(
        files['products']!.contents,
        contains("import 'product_status.dart';"),
      );
      expect(
        files['products']!.contents,
        contains('late final ProductStatus status'),
      );
    });

    test('an enum type name is not singularized', () {
      // `product_status` is already singular; the table singularizer would
      // turn it into `ProductStatu`.
      expect(files['product_status']!.className, isNot(endsWith('Statu')));
    });

    test('folds a pivot into the relationship rather than a resource', () {
      expect(files.keys, isNot(contains('product_tag')));
      expect(files['products']!.contents, contains('@BelongsToMany('));
      expect(
        files['products']!.contents,
        contains("pivotTable: 'product_tag'"),
      );
      expect(files['products']!.contents, contains('List<Tag> tags'));
    });

    test('skips migration bookkeeping tables', () {
      expect(files.keys, isNot(contains('worm_migrations')));
    });

    test('skips the tables Beak keeps for itself', () {
      // A database Beak migrated once carries its own receipts and outbox.
      // Introspecting it again generated classes for both.
      final generated = BeakIntrospectionEmitter.emitAll([
        for (final name in ['_beak_commit_receipts', '_beak_outbox', 'orders'])
          IntrospectedTable(
            name: name,
            columns: [
              const IntrospectedColumn(
                name: 'id',
                dataType: 'uuid',
                isNullable: false,
              ),
              const IntrospectedColumn(
                name: 'note',
                dataType: 'text',
                isNullable: true,
              ),
            ],
          ),
      ]);

      expect(generated.map((file) => file.table), ['orders']);
    });

    test('names the class by the singular table', () {
      expect(files['categories']!.className, 'Category');
    });

    test('puts each table in the feature folder make:resource would', () {
      // The same place `beak make:resource Category` writes, so an
      // introspected project and a scaffolded one have one layout.
      expect(files['categories']!.path, 'categories/models/category.dart');
      expect(files['products']!.path, 'products/models/product.dart');
      expect(files['users']!.path, 'users/models/user.dart');
    });

    test('an enum sits beside the only table that uses it', () {
      expect(
        files['product_status']!.path,
        'products/models/product_status.dart',
      );
    });

    test('a relationship imports its far side across feature folders', () {
      final String source = files['products']!.contents;

      expect(
        source,
        contains("import '../../categories/models/category.dart';"),
      );
      expect(source, contains("import '../../tags/models/tag.dart';"));
      expect(source, isNot(contains("import 'product.dart';")));
    });

    test('emits the annotated authoring surface, not a parallel dialect', () {
      final source = files['products']!.contents;
      expect(source, contains("import 'package:beak/schema.dart';"));
      expect(source, contains('@Resource('));
      expect(source, contains('final class Product extends BeakSchema'));
      expect(source, contains("part 'product.beak.dart';"));
    });

    test('takes ownership of the schema by default', () {
      // The baseline migration covers the tables that already exist, so the
      // classes can own them: `beak doctor` then reports drift, and
      // `make:migration --from-drift` can write the changes.
      for (final file in files.values) {
        expect(file.contents, isNot(contains('managesSchema')));
      }
    });

    test('a length becomes a rule, and the rule sizes the column', () {
      // One declaration: `BeakMaxLength` validates and sizes the VARCHAR.
      final source = files['categories']!.contents;
      expect(source, contains('BeakMaxLength(60)'));
      expect(source, isNot(contains('maxLength: 60')));
    });

    test('carries soft deletes and timestamps onto the annotation', () {
      expect(files['products']!.contents, contains('softDeletes: true'));
      expect(files['products']!.contents, contains('timestamps: true'));
      expect(files['categories']!.contents, isNot(contains('softDeletes')));
    });

    test('maps database types onto authoring types', () {
      final source = files['products']!.contents;
      expect(source, contains('late final String name'));
      expect(source, contains('late final BeakText? description'));
      expect(source, contains('late final double price'));
    });

    test('makes a defaulted NOT NULL column optional', () {
      // The database will fill it, so requiring it in a form would be wrong.
      expect(files['products']!.contents, contains('late final int? stock'));
    });

    test('reads an upload column from its name, not its varchar type', () {
      // The database sees a varchar either way; the name is the only signal
      // that the value is a storage key rather than text.
      final source = files['products']!.contents;
      expect(source, contains('late final BeakImageRef? image'));
      expect(source, contains('late final BeakFileRef? specFile'));
    });

    test('an upload column carries no length rule', () {
      // The length bounds the storage key Beak writes, not user input.
      final image = files['products']!.contents
          .split('\n')
          .lastWhere((line) => line.contains('@Column'), orElse: () => '');
      expect(image, isNot(contains('maxLength')));
    });

    test('picks a display column by convention', () {
      expect(files['products']!.contents, contains('@Display()'));
      expect(files['users']!.contents, contains('@Display()'));
    });

    test('derives rules from the column name and length', () {
      expect(files['users']!.contents, contains('BeakEmail()'));
      expect(files['categories']!.contents, contains('BeakMaxLength(60)'));
    });

    test('emits a belongs-to for a foreign key', () {
      expect(files['products']!.contents, contains('@BelongsTo()'));
      expect(
        files['products']!.contents,
        contains('late final Category? category'),
      );
    });

    test('omits a secret column and says so', () {
      final users = files['users']!;
      expect(users.contents, isNot(contains('passwordHash')));
      expect(users.notes.single, contains('password_hash'));
      expect(users.notes.single, contains('secret'));
    });

    test('an unspellable enum label falls back to text, with a note', () async {
      // Beak stores an enum by its Dart name, so `in progress` has no
      // representation that round-trips; text is the honest answer.
      final database = FakeDatabase(
        columns: [
          column('jobs', 'id', 'uuid', nullable: false),
          column(
            'jobs',
            'state',
            'USER-DEFINED',
            nullable: false,
            udt: 'job_state',
          ),
        ],
        primaryKeys: [
          {'table_name': 'jobs', 'column_name': 'id'},
        ],
        enums: [
          {'enum_name': 'job_state', 'enum_value': 'queued'},
          {'enum_name': 'job_state', 'enum_value': 'in progress'},
        ],
      );
      final emitted = BeakIntrospectionEmitter.emitAll(
        await PostgresIntrospector(database.query).read(),
      );

      expect(emitted.map((file) => file.table), ['jobs']);
      expect(emitted.single.contents, contains('late final String state'));
      expect(emitted.single.notes.single, contains('in progress'));
      expect(emitted.single.notes.single, contains('read as text'));
    });

    test('a reserved word is never emitted as an enum value', () async {
      final database = FakeDatabase(
        columns: [column('rooms', 'kind', 'USER-DEFINED', udt: 'room_kind')],
        enums: [
          {'enum_name': 'room_kind', 'enum_value': 'class'},
          {'enum_name': 'room_kind', 'enum_value': 'lab'},
        ],
      );
      final emitted = BeakIntrospectionEmitter.emitAll(
        await PostgresIntrospector(database.query).read(),
      );

      expect(emitted.single.contents, contains('late final String? kind'));
    });

    test('output is formatted', () {
      for (final file in files.values) {
        expect(BeakEmitters.format(file.contents), file.contents);
      }
    });
  });

  group('emitting for a schema someone else owns', () {
    late Map<String, IntrospectedSchemaFile> files;

    setUp(() async {
      final emitted = BeakIntrospectionEmitter.emitAll(
        await readShop(),
        ownership: BeakIntrospectionOwnership.external,
      );
      files = {for (final file in emitted) file.table: file};
    });

    test('marks every resource as not migrated by Beak', () {
      for (final file in files.values) {
        if (file.contents.contains('extends BeakSchema')) {
          expect(file.contents, contains('managesSchema: false'));
        }
      }
      expect(files['products']!.contents, contains('managesSchema: false'));
    });

    test('changes nothing else about the classes', () async {
      final adopted = {
        for (final file in BeakIntrospectionEmitter.emitAll(await readShop()))
          file.table: file,
      };

      for (final table in files.keys) {
        expect(
          BeakEmitters.format(
            files[table]!.contents.replaceFirst(
              RegExp(r'managesSchema: false,?\s*'),
              '',
            ),
          ),
          adopted[table]!.contents,
          reason: table,
        );
      }
    });
  });

  group('the baseline migration', () {
    late String source;

    setUp(() async {
      source = BeakIntrospectionEmitter.emitBaseline(
        await readShop(),
        migrationName: '20260928_101500_adopt_existing_schema',
        schemaRoot: '../resources',
      );
    });

    test('is a BeakBaselineMigration named for the moment it was written', () {
      expect(
        source,
        contains(
          'final class AdoptExistingSchema extends BeakBaselineMigration',
        ),
      );
      expect(
        source,
        contains("String get name => '20260928_101500_adopt_existing_schema'"),
      );
      expect(source, contains('const AdoptExistingSchema();'));
      expect(source, contains("import 'package:beak/migrations.dart';"));
    });

    test('lists every resource model, each after the tables it references', () {
      expect(
        source,
        contains(
          'List<BeakModel> get models => const [\n'
          '    CategoryModel(),\n'
          '    ProductModel(),\n'
          '    TagModel(),\n'
          '    UserModel(),\n'
          '  ];',
        ),
      );
    });

    test('lists a pivot once, through the side that declares it', () {
      expect(
        source,
        contains(
          'List<BeakBelongsToMany> get pivots => const [ProductRelations.tags];',
        ),
      );
    });

    test('imports the schema files, and only those', () {
      expect(
        source,
        contains("import '../resources/categories/models/category.dart';"),
      );
      expect(
        source,
        contains("import '../resources/products/models/product.dart';"),
      );
      expect(source, contains("import '../resources/tags/models/tag.dart';"));
      expect(source, contains("import '../resources/users/models/user.dart';"));
      expect(source, isNot(contains('product_status')));
      expect(source, isNot(contains('product_tag')));
    });

    test('leaves out migration bookkeeping', () {
      expect(source, isNot(contains('worm_migrations')));
      expect(source, isNot(contains('WormMigration')));
    });

    test('is formatted', () {
      expect(BeakEmitters.format(source), source);
    });

    test('does not declare pivots when the database has none', () async {
      final only = BeakIntrospectionEmitter.emitBaseline(
        [tableNamed(await readShop(), 'categories')],
        migrationName: '20260928_101500_adopt_existing_schema',
        schemaRoot: '../resources',
      );

      expect(only, contains('CategoryModel()'));
      expect(only, isNot(contains('pivots')));
    });

    test('orders a table after the one it references, not by name', () {
      // `a_items` sorts first but references `z_owners`.
      final tables = [
        const IntrospectedTable(
          name: 'a_items',
          columns: [
            IntrospectedColumn(name: 'id', dataType: 'uuid', isNullable: false),
            IntrospectedColumn(
              name: 'owner_id',
              dataType: 'uuid',
              isNullable: true,
            ),
          ],
          foreignKeys: [
            IntrospectedForeignKey(
              column: 'owner_id',
              referencedTable: 'z_owners',
            ),
          ],
        ),
        const IntrospectedTable(
          name: 'z_owners',
          columns: [
            IntrospectedColumn(name: 'id', dataType: 'uuid', isNullable: false),
          ],
        ),
      ];

      final baseline = BeakIntrospectionEmitter.emitBaseline(
        tables,
        migrationName: '20260928_101500_adopt_existing_schema',
        schemaRoot: '../resources',
      );

      expect(
        baseline.indexOf('ZOwnerModel()'),
        lessThan(baseline.indexOf('AItemModel()')),
      );
    });

    test('lists each of two tables that reference each other once', () {
      const tables = [
        IntrospectedTable(
          name: 'chickens',
          columns: [
            IntrospectedColumn(name: 'id', dataType: 'uuid', isNullable: false),
            IntrospectedColumn(
              name: 'egg_id',
              dataType: 'uuid',
              isNullable: true,
            ),
          ],
          foreignKeys: [
            IntrospectedForeignKey(column: 'egg_id', referencedTable: 'eggs'),
          ],
        ),
        IntrospectedTable(
          name: 'eggs',
          columns: [
            IntrospectedColumn(name: 'id', dataType: 'uuid', isNullable: false),
            IntrospectedColumn(
              name: 'chicken_id',
              dataType: 'uuid',
              isNullable: true,
            ),
          ],
          foreignKeys: [
            IntrospectedForeignKey(
              column: 'chicken_id',
              referencedTable: 'chickens',
            ),
          ],
        ),
      ];

      final baseline = BeakIntrospectionEmitter.emitBaseline(
        tables,
        migrationName: '20260928_101500_adopt_existing_schema',
        schemaRoot: '../resources',
      );

      // The walk reaches `eggs` while placing `chickens`, so `eggs` goes
      // first and its foreign key to `chickens` is the one left out.
      expect(
        baseline.indexOf('EggModel()'),
        lessThan(baseline.indexOf('ChickenModel()')),
      );
      expect('ChickenModel()'.allMatches(baseline), hasLength(1));
      expect('EggModel()'.allMatches(baseline), hasLength(1));
    });

    test('follows the flat layout', () async {
      final flat = BeakIntrospectionEmitter.emitBaseline(
        await readShop(),
        migrationName: '20260928_101500_adopt_existing_schema',
        schemaRoot: '../schema',
        layout: BeakIntrospectionLayout.flat,
      );

      expect(flat, contains("import '../schema/product.dart';"));
      expect(flat, contains("import '../schema/category.dart';"));
    });

    test('every import resolves to a file emitted for it', () async {
      final tables = await readShop();
      final emitted = {
        for (final file in BeakIntrospectionEmitter.emitAll(tables))
          'lib/resources/${file.path}',
      };
      for (final match in RegExp(
        "^import '(?!package:)([^']+)';",
        multiLine: true,
      ).allMatches(source)) {
        final String target = p.posix.normalize(
          p.posix.join('lib/migrations', match.group(1)),
        );
        expect(emitted, contains(target), reason: match.group(1));
      }
    });
  });

  group('every import an emitted file makes', () {
    for (final layout in BeakIntrospectionLayout.values) {
      test('resolves to a file emitted beside it, laid out $layout', () async {
        final emitted = BeakIntrospectionEmitter.emitAll(
          await readShop(),
          layout: layout,
        );
        final paths = {for (final file in emitted) file.path};

        for (final file in emitted) {
          for (final match in RegExp(
            "^import '(?!package:)([^']+)';",
            multiLine: true,
          ).allMatches(file.contents)) {
            final String target = p.posix.normalize(
              p.posix.join(p.posix.dirname(file.path), match.group(1)),
            );
            expect(
              paths,
              contains(target),
              reason: '${file.path} imports ${match.group(1)}',
            );
          }
        }
      });
    }
  });

  group('the flat layout', () {
    late Map<String, IntrospectedSchemaFile> files;

    setUp(() async {
      final emitted = BeakIntrospectionEmitter.emitAll(
        await readShop(),
        layout: BeakIntrospectionLayout.flat,
      );
      files = {for (final file in emitted) file.table: file};
    });

    test('names each file by the singular table, in one directory', () {
      expect(files['categories']!.path, 'category.dart');
      expect(files['products']!.path, 'product.dart');
      expect(files['product_status']!.path, 'product_status.dart');
    });

    test('imports its neighbours by file name', () {
      final String source = files['products']!.contents;

      expect(source, contains("import 'category.dart';"));
      expect(source, contains("import 'product_status.dart';"));
      expect(source, contains("import 'tag.dart';"));
    });
  });

  group('an enum shared by two tables', () {
    late Map<String, IntrospectedSchemaFile> files;

    setUp(() async {
      final database = FakeDatabase(
        columns: [
          column('invoices', 'id', 'uuid', nullable: false),
          column(
            'invoices',
            'state',
            'USER-DEFINED',
            nullable: false,
            udt: 'payment_state',
          ),
          column('orders', 'id', 'uuid', nullable: false),
          column(
            'orders',
            'state',
            'USER-DEFINED',
            nullable: false,
            udt: 'payment_state',
          ),
        ],
        primaryKeys: [
          for (final table in ['invoices', 'orders'])
            {'table_name': table, 'column_name': 'id'},
        ],
        enums: [
          {'enum_name': 'payment_state', 'enum_value': 'open'},
          {'enum_name': 'payment_state', 'enum_value': 'paid'},
        ],
      );
      final emitted = BeakIntrospectionEmitter.emitAll(
        await PostgresIntrospector(database.query).read(),
      );
      files = {for (final file in emitted) file.table: file};
    });

    test('is declared once, beside the first table that uses it', () {
      expect(
        files.values.where((file) => file.className == 'PaymentState'),
        hasLength(1),
      );
      expect(
        files['payment_state']!.path,
        'invoices/models/payment_state.dart',
      );
    });

    test('is imported across feature folders by the others', () {
      expect(
        files['invoices']!.contents,
        contains("import 'payment_state.dart';"),
      );
      expect(
        files['orders']!.contents,
        contains("import '../../invoices/models/payment_state.dart';"),
      );
    });
  });

  group('the introspect command', () {
    late Directory root;
    late StringBuffer out;

    setUp(() {
      root = Directory.systemTemp.createTempSync('beak_introspect_');
      addTearDown(() => root.deleteSync(recursive: true));
      out = StringBuffer();
    });

    Future<int> run(List<String> args, {FakeDatabase? database}) async {
      final environment = BeakCliEnvironment(
        out: out,
        rootDirectory: root,
        now: () => DateTime.utc(2026),
        probe: (host, port) async => false,
      );
      // A standalone runner wired to the fake database: the real one binds a
      // live Postgres opener, which a unit test must not reach for.
      final runner = CommandRunner<int>('beak', 'test')
        ..addCommand(
          IntrospectCommand(
            environment,
            readSchema: (url, {String schema = 'public'}) =>
                PostgresIntrospector((database ?? shopDatabase()).query).read(),
          ),
        );
      return await runner.run(['introspect', ...args]) ?? 0;
    }

    String read(String path) => File('${root.path}/$path').readAsStringSync();

    /// The shop, plus a table that only another migration tool writes.
    FakeDatabase shopWith(String bookkeepingTable) {
      final shop = shopDatabase();
      return FakeDatabase(
        columns: [
          ...shop.columns,
          column(bookkeepingTable, 'id', 'integer', nullable: false),
        ],
        foreignKeys: shop.foreignKeys,
        primaryKeys: shop.primaryKeys,
        enums: shop.enums,
        indexes: shop.indexes,
      );
    }

    const baselinePath =
        'lib/migrations/20260101_000000_adopt_existing_schema.dart';

    bool exists(String path) => File('${root.path}/$path').existsSync();

    test('writes a model per resource table, in its feature folder', () async {
      expect(await run(['postgres://u:p@localhost:5432/shop']), 0);
      expect(exists('lib/resources/products/models/product.dart'), isTrue);
      expect(exists('lib/resources/categories/models/category.dart'), isTrue);
      expect(exists('lib/resources/product_tag'), isFalse);
      expect(exists('lib/models'), isFalse);
      expect(
        exists('lib/resources/products/models/product_status.dart'),
        isTrue,
      );
      expect(out.toString(), contains('run `beak prepare`'));
    });

    test('what it writes is what beak prepare reads', () async {
      await run(['postgres://u:p@localhost:5432/shop']);
      File(
        '${root.path}/pubspec.yaml',
      ).writeAsStringSync('name: shop\ndependencies:\n  beak: any\n');

      final BeakPrepareResult prepared = runPrepare(
        BeakCliEnvironment(
          out: StringBuffer(),
          rootDirectory: root,
          now: () => DateTime.utc(2026),
          probe: (host, port) async => false,
        ),
      );

      expect(
        prepared.isSuccess,
        isTrue,
        reason: '${prepared.discovery.issues}',
      );
      expect(
        prepared.discovery.models.map((model) => model.table),
        containsAll(['products', 'categories', 'tags', 'users']),
      );
    });

    test('reports what it read and what it skipped', () async {
      await run(['postgres://u:p@localhost:5432/shop']);
      expect(out.toString(), contains('read 5 tables'));
      expect(out.toString(), contains('worm_migrations'));
    });

    test('--dry-run writes nothing', () async {
      expect(await run(['postgres://u:p@localhost:5432/shop', '--dry-run']), 0);
      expect(exists('lib/resources'), isFalse);
      expect(
        out.toString(),
        contains('would create lib/resources/products/models/product.dart'),
      );
    });

    test('--only narrows the selection', () async {
      await run(['postgres://u:p@localhost:5432/shop', '--only', 'products']);
      expect(exists('lib/resources/products/models/product.dart'), isTrue);
      expect(exists('lib/resources/categories'), isFalse);
    });

    test('--except removes a table', () async {
      await run(['postgres://u:p@localhost:5432/shop', '--except', 'users']);
      expect(exists('lib/resources/users'), isFalse);
      expect(exists('lib/resources/products/models/product.dart'), isTrue);
    });

    test('--out writes every file flat into that directory', () async {
      await run(['postgres://u:p@localhost:5432/shop', '--out', 'lib/schema']);
      expect(exists('lib/schema/product.dart'), isTrue);
      expect(exists('lib/schema/product_status.dart'), isTrue);
      expect(exists('lib/resources'), isFalse);
      expect(
        File('${root.path}/lib/schema/product.dart').readAsStringSync(),
        contains("import 'category.dart';"),
      );
    });

    test('rejects a scheme Beak cannot read, with a clear message', () async {
      expect(await run(['mysql://u:p@localhost/shop']), 1);
      expect(out.toString(), contains('not supported yet'));
      expect(out.toString(), contains('SQLite'));
    });

    test('accepts a SQLite url, which Beak can read too', () async {
      // The introspector for it exists, so refusing the scheme would be the
      // command declining a thing the library does.
      expect(await run(['sqlite:legacy.db']), 0);
      expect(exists('lib/resources/products/models/product.dart'), isTrue);
    });

    test('rejects a missing or malformed url', () {
      expect(run([]), throwsA(isA<Object>()));
      expect(run(['not a url', 'extra']), throwsA(isA<Object>()));
    });

    test('rejects an ownership that is neither adopt nor external', () {
      expect(
        run(['postgres://u:p@localhost:5432/shop', '--ownership', 'borrow']),
        throwsA(isA<UsageException>()),
      );
    });

    group('adopting, the default', () {
      test('writes the baseline migration beside the schema classes', () async {
        expect(await run(['postgres://u:p@localhost:5432/shop']), 0);

        expect(exists(baselinePath), isTrue);
        final String baseline = read(baselinePath);
        expect(baseline, contains('extends BeakBaselineMigration'));
        expect(baseline, contains('CategoryModel(),'));
        expect(baseline, contains('ProductRelations.tags'));
        expect(baseline, contains("'20260101_000000_adopt_existing_schema'"));
        expect(out.toString(), contains('created $baselinePath'));
      });

      test('leaves the classes to Beak, with no managesSchema', () async {
        await run(['postgres://u:p@localhost:5432/shop']);

        expect(
          read('lib/resources/products/models/product.dart'),
          isNot(contains('managesSchema')),
        );
      });

      test('says what the migration does with the database it read', () async {
        await run(['postgres://u:p@localhost:5432/shop']);

        expect(out.toString(), contains('adopting'));
        expect(out.toString(), contains('beak prepare'));
      });

      test('--dry-run reports the migration and writes none', () async {
        await run(['postgres://u:p@localhost:5432/shop', '--dry-run']);

        expect(exists('lib/migrations'), isFalse);
        expect(out.toString(), contains('would create $baselinePath'));
      });

      test('--out puts the classes elsewhere and imports them from there', () {
        return run([
          'postgres://u:p@localhost:5432/shop',
          '--out',
          'lib/schema',
        ]).then((code) {
          expect(code, 0);
          expect(
            read(baselinePath),
            contains("import '../schema/product.dart';"),
          );
        });
      });

      test('--out outside lib/ cannot be imported by a migration', () async {
        expect(
          run(['postgres://u:p@localhost:5432/shop', '--out', 'tool/schema']),
          throwsA(
            isA<UsageException>().having(
              (e) => e.message,
              'message',
              contains('under lib/'),
            ),
          ),
        );
        expect(exists('lib/migrations'), isFalse);
        expect(exists('tool'), isFalse);
      });

      test('--out outside lib/ is fine when Beak adopts nothing', () async {
        expect(
          await run([
            'postgres://u:p@localhost:5432/shop',
            '--out',
            'tool/schema',
            '--ownership',
            'external',
          ]),
          0,
        );
        expect(exists('tool/schema/product.dart'), isTrue);
      });

      test('a second run keeps the migration it already wrote', () async {
        await run(['postgres://u:p@localhost:5432/shop']);
        final String first = read(baselinePath);
        out.clear();

        expect(await run(['postgres://u:p@localhost:5432/shop']), 0);

        expect(
          Directory('${root.path}/lib/migrations').listSync(),
          hasLength(1),
        );
        expect(read(baselinePath), first);
        expect(out.toString(), contains('already adopts'));
      });

      test('a migration named for an earlier moment counts too', () async {
        File(
            '${root.path}/lib/migrations/20250101_000000_adopt_existing_schema.dart',
          )
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('// earlier\n');

        await run(['postgres://u:p@localhost:5432/shop']);

        expect(exists(baselinePath), isFalse);
        expect(out.toString(), contains('already adopts'));
      });

      test('what it writes is what prepare reads, with no create_ '
          'migration for an adopted table', () async {
        await run(['postgres://u:p@localhost:5432/shop']);
        File(
          '${root.path}/pubspec.yaml',
        ).writeAsStringSync('name: shop\ndependencies:\n  beak: ^0.9.0\n');
        final environment = BeakCliEnvironment(
          out: StringBuffer(),
          rootDirectory: root,
          now: () => DateTime.utc(2026, 2),
          probe: (host, port) async => false,
        );

        final BeakPrepareResult prepared = runPrepare(environment);

        expect(
          prepared.isSuccess,
          isTrue,
          reason: '${prepared.discovery.issues}',
        );
        expect(
          prepared.written.where(
            (path) => path.startsWith('lib/migrations/create_'),
          ),
          isEmpty,
        );
        expect(prepared.discovery.migrations.map((m) => m.name), [
          'AdoptExistingSchema',
        ]);
        expect(
          read('lib/beak/server.g.dart'),
          contains('AdoptExistingSchema()'),
        );
        final checks = await diagnose(environment, readSchema: neverRead);
        expect(
          checks
              .firstWhere(
                (check) => check.label.contains('every model has a migration'),
              )
              .status,
          BeakCheckStatus.ok,
        );
      });

      test('a table added later still gets its own migration', () async {
        await run(['postgres://u:p@localhost:5432/shop']);
        File(
          '${root.path}/pubspec.yaml',
        ).writeAsStringSync('name: shop\ndependencies:\n  beak: any\n');
        File('${root.path}/lib/resources/notes/models/note.dart')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(generateSchemaClass('Note', const []));
        final environment = BeakCliEnvironment(
          out: StringBuffer(),
          rootDirectory: root,
          now: () => DateTime.utc(2026, 2),
          probe: (host, port) async => false,
        );

        final BeakPrepareResult prepared = runPrepare(environment);

        expect(prepared.written.where((path) => path.contains('create_')), [
          'lib/migrations/create_notes_table.dart',
        ]);
      });
    });

    group('--ownership external', () {
      test('marks the classes and writes no migration', () async {
        expect(
          await run([
            'postgres://u:p@localhost:5432/shop',
            '--ownership',
            'external',
          ]),
          0,
        );

        expect(exists('lib/migrations'), isFalse);
        expect(
          read('lib/resources/products/models/product.dart'),
          contains('managesSchema: false'),
        );
        expect(out.toString(), isNot(contains('adopt')));
      });

      test(
        'tells the user to migrate once, for Beak\'s own tables only',
        () async {
          // Saves go through POST /api/commits, which needs the receipts table;
          // `beak migrate` on such a database creates that, the outbox and
          // worm's log, and touches none of the user's tables. The message said
          // never to run it.
          await run([
            'postgres://u:p@localhost:5432/shop',
            '--ownership',
            'external',
          ]);

          final String text = out.toString();
          expect(text, contains('Run `beak migrate` once'));
          expect(text, contains('_beak_commit_receipts'));
          expect(text, contains('_beak_outbox'));
          expect(text, contains('worm_migrations'));
          expect(text, isNot(contains('do not run')));
        },
      );
    });

    group('running it again', () {
      const url = 'postgres://u:p@localhost:5432/shop';
      const product = 'lib/resources/products/models/product.dart';

      test(
        'over files nobody touched writes the same files and succeeds',
        () async {
          await run([url]);
          final String first = read(product);
          out.clear();

          expect(await run([url]), 0);

          expect(read(product), first);
          expect(out.toString(), isNot(contains('already exists')));
        },
      );

      test('refuses to overwrite a schema file that was edited, and writes '
          'nothing', () async {
        // The classes are the project's the moment they are written, and
        // this used to replace them, edits and all, without a word.
        await run([url]);
        File('${root.path}/$product').writeAsStringSync('// mine, edited\n');
        File(
          '${root.path}/lib/resources/categories/models/category.dart',
        ).writeAsStringSync('// also mine\n');
        out.clear();

        expect(await run([url]), 1);

        expect(read(product), '// mine, edited\n');
        expect(
          read('lib/resources/categories/models/category.dart'),
          '// also mine\n',
        );
        expect(out.toString(), contains(product));
        expect(
          out.toString(),
          contains('lib/resources/categories/models/category.dart'),
        );
        expect(out.toString(), contains('--force'));
        expect(out.toString(), contains('already exists'));
      });

      test('--force replaces it', () async {
        await run([url]);
        File('${root.path}/$product').writeAsStringSync('// mine, edited\n');

        expect(await run([url, '--force']), 0);

        expect(
          read(product),
          contains('final class Product extends BeakSchema'),
        );
      });

      test(
        '--only leaves an edited file for a table it did not select',
        () async {
          await run([url]);
          File('${root.path}/$product').writeAsStringSync('// mine, edited\n');

          expect(await run([url, '--only', 'categories']), 0);

          expect(read(product), '// mine, edited\n');
        },
      );

      test('--dry-run says what would be refused and writes nothing', () async {
        await run([url]);
        File('${root.path}/$product').writeAsStringSync('// mine, edited\n');
        out.clear();

        expect(await run([url, '--dry-run']), 1);

        expect(read(product), '// mine, edited\n');
        expect(out.toString(), contains(product));
        expect(out.toString(), contains('already exists'));
      });
    });

    group('a database another tool migrates', () {
      for (final table in foreignMigrationTables) {
        test('$table switches the default to external, with a note', () async {
          expect(
            await run([
              'postgres://u:p@localhost:5432/shop',
            ], database: shopWith(table)),
            0,
          );

          expect(exists('lib/migrations'), isFalse);
          expect(
            read('lib/resources/products/models/product.dart'),
            contains('managesSchema: false'),
          );
          expect(out.toString(), contains(table));
          expect(out.toString(), contains('--ownership adopt'));
        });
      }

      test('asking to adopt is honoured, and not second-guessed', () async {
        await run([
          'postgres://u:p@localhost:5432/shop',
          '--ownership',
          'adopt',
        ], database: shopWith('flyway_schema_history'));

        expect(exists(baselinePath), isTrue);
        expect(out.toString(), isNot(contains('--ownership adopt')));
      });

      test('asking for external needs no note', () async {
        await run([
          'postgres://u:p@localhost:5432/shop',
          '--ownership',
          'external',
        ], database: shopWith('flyway_schema_history'));

        expect(exists('lib/migrations'), isFalse);
        expect(out.toString(), isNot(contains('--ownership adopt')));
      });

      test('its bookkeeping table is never written as a resource', () async {
        await run([
          'postgres://u:p@localhost:5432/shop',
        ], database: shopWith('alembic_version'));

        expect(exists('lib/resources/alembic_version'), isFalse);
        expect(out.toString(), contains('skipped'));
        expect(out.toString(), contains('alembic_version'));
      });

      test('worm\'s own bookkeeping does not switch the default', () async {
        await run(['postgres://u:p@localhost:5432/shop']);

        expect(exists(baselinePath), isTrue);
      });
    });

    group('a Serverpod database', () {
      const refusal =
          'This database belongs to a Serverpod server. Beak does not '
          'connect to it; add the admin app to your Serverpod workspace '
          'instead (see the Serverpod section of the docs).';

      for (final table in const [
        'serverpod_session_log',
        'serverpod_migrations',
        'serverpod_auth_idp_user',
      ]) {
        test('is refused when it has $table', () async {
          expect(
            await run([
              'postgres://u:p@localhost:5432/shop',
            ], database: shopWith(table)),
            1,
          );

          expect(out.toString(), contains(refusal));
          expect(exists('lib'), isFalse);
          expect(exists('.env'), isFalse);
        });
      }

      test('is refused whatever the ownership asked for', () async {
        expect(
          await run([
            'postgres://u:p@localhost:5432/shop',
            '--ownership',
            'external',
            '--dry-run',
          ], database: shopWith('serverpod_migrations')),
          1,
        );
        expect(out.toString(), contains(refusal));
      });

      test('is not confused with a table that merely starts alike', () async {
        expect(
          await run([
            'postgres://u:p@localhost:5432/shop',
          ], database: shopWith('serverpods')),
          0,
        );
        expect(out.toString(), isNot(contains('Serverpod')));
      });
    });

    group('--save-url', () {
      const url = 'postgres://u:p@localhost:5432/shop';

      test('writes DATABASE_URL to a .env that did not exist', () async {
        await run([url, '--save-url']);

        expect(read('.env'), 'DATABASE_URL=$url\n');
        expect(out.toString(), contains('created .env'));
      });

      test(
        'replaces an existing DATABASE_URL and keeps every other line',
        () async {
          File('${root.path}/.env').writeAsStringSync(
            '# secrets\nPORT=9000\nDATABASE_URL=sqlite:old.db\nHOST=0.0.0.0\n',
          );

          await run([url, '--save-url']);

          expect(
            read('.env'),
            '# secrets\nPORT=9000\nDATABASE_URL=$url\nHOST=0.0.0.0\n',
          );
        },
      );

      test('appends to a .env that has none, whatever its last line', () async {
        File('${root.path}/.env').writeAsStringSync('PORT=9000');

        await run([url, '--save-url']);

        expect(read('.env'), 'PORT=9000\nDATABASE_URL=$url\n');
      });

      test('the backend reads back what was saved', () async {
        await run([url, '--save-url']);

        expect(
          beakDatabaseUrlOf(root, processEnvironment: const {}),
          Uri.parse(url),
        );
      });

      test('a second run changes nothing', () async {
        await run([url, '--save-url']);
        final String first = read('.env');

        await run([url, '--save-url']);

        expect(read('.env'), first);
      });

      test('a SQLite url is saved as it was given', () async {
        await run(['sqlite:legacy.db', '--save-url']);

        expect(read('.env'), 'DATABASE_URL=sqlite:legacy.db\n');
      });

      test('--dry-run writes nothing', () async {
        await run([url, '--save-url', '--dry-run']);

        expect(exists('.env'), isFalse);
        expect(out.toString(), contains('would save DATABASE_URL'));
      });

      test(
        'warns when .env is not git-ignored, the url may hold a password',
        () async {
          File('${root.path}/.gitignore').writeAsStringSync('build/\n');

          await run([url, '--save-url']);

          expect(out.toString(), contains('.env is not in .gitignore'));
        },
      );

      test('says nothing about git when .env is ignored', () async {
        File('${root.path}/.gitignore').writeAsStringSync('build/\n.env\n');

        await run([url, '--save-url']);

        expect(out.toString(), isNot(contains('.gitignore')));
      });

      test(
        'says nothing about git when there is no repository to speak of',
        () async {
          await run([url, '--save-url']);

          expect(out.toString(), isNot(contains('.gitignore')));
        },
      );

      test('is not done without the flag', () async {
        await run([url]);

        expect(exists('.env'), isFalse);
      });
    });
  });
}
