import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

import '../../support/fake_database.dart';

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
      expect(status.path, 'product_status.dart');
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

    test('names the class and file by the singular table', () {
      expect(files['categories']!.className, 'Category');
      expect(files['categories']!.path, 'category.dart');
    });

    test('emits the annotated authoring surface, not a parallel dialect', () {
      final source = files['products']!.contents;
      expect(source, contains("import 'package:beak/schema.dart';"));
      expect(source, contains('@Resource('));
      expect(source, contains('final class Product extends BeakSchema'));
      expect(source, contains("part 'product.beak.dart';"));
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

  group('the introspect command', () {
    late Directory root;
    late StringBuffer out;

    setUp(() {
      root = Directory.systemTemp.createTempSync('beak_introspect_');
      addTearDown(() => root.deleteSync(recursive: true));
      out = StringBuffer();
    });

    Future<int> run(List<String> args) async {
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
            open: (url) async => (shopDatabase().query, () async {}),
          ),
        );
      return await runner.run(['introspect', ...args]) ?? 0;
    }

    bool exists(String path) => File('${root.path}/$path').existsSync();

    test('writes a model per resource table', () async {
      expect(await run(['postgres://u:p@localhost:5432/shop']), 0);
      expect(exists('lib/models/product.dart'), isTrue);
      expect(exists('lib/models/category.dart'), isTrue);
      expect(exists('lib/models/product_tag.dart'), isFalse);
      expect(out.toString(), contains('run `beak prepare`'));
    });

    test('reports what it read and what it skipped', () async {
      await run(['postgres://u:p@localhost:5432/shop']);
      expect(out.toString(), contains('read 5 tables'));
      expect(out.toString(), contains('worm_migrations'));
    });

    test('--dry-run writes nothing', () async {
      expect(await run(['postgres://u:p@localhost:5432/shop', '--dry-run']), 0);
      expect(exists('lib/models/product.dart'), isFalse);
      expect(out.toString(), contains('would create'));
    });

    test('--only narrows the selection', () async {
      await run(['postgres://u:p@localhost:5432/shop', '--only', 'products']);
      expect(exists('lib/models/product.dart'), isTrue);
      expect(exists('lib/models/category.dart'), isFalse);
    });

    test('--except removes a table', () async {
      await run(['postgres://u:p@localhost:5432/shop', '--except', 'users']);
      expect(exists('lib/models/user.dart'), isFalse);
      expect(exists('lib/models/product.dart'), isTrue);
    });

    test('--out redirects the output directory', () async {
      await run(['postgres://u:p@localhost:5432/shop', '--out', 'lib/schema']);
      expect(exists('lib/schema/product.dart'), isTrue);
    });

    test('rejects a non-Postgres url with a clear message', () async {
      expect(await run(['mysql://u:p@localhost/shop']), 1);
      expect(out.toString(), contains('not supported yet'));
    });

    test('rejects a missing or malformed url', () {
      expect(run([]), throwsA(isA<Object>()));
      expect(run(['not a url', 'extra']), throwsA(isA<Object>()));
    });
  });
}
