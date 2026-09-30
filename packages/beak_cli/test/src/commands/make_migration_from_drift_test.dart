import 'dart:io';

import 'package:args/command_runner.dart';
import '../../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// A schema class whose `stock` field is [required] or nullable.
String productSchema({required bool requiredStock}) =>
    '''
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';

/// Something for sale.
@Resource()
final class Product extends BeakSchema {
  /// What it is called.
  @Display()
  late final String name;

  /// Units in stock.
  late final int${requiredStock ? '' : '?'} stock;
}
''';

/// The `products` table holding [columns], as a live-schema reader reports it.
List<IntrospectedTable> productsTable(List<String> columns) => [
  IntrospectedTable(
    name: 'products',
    columns: [
      for (final name in columns)
        IntrospectedColumn(name: name, dataType: 'text', isNullable: true),
    ],
    foreignKeys: const [],
    primaryKey: 'id',
  ),
];

void main() {
  late Directory root;
  late StringBuffer out;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_from_drift_');
    addTearDown(() => root.deleteSync(recursive: true));
    File(
      '${root.path}/pubspec.yaml',
    ).writeAsStringSync('name: shop\ndependencies:\n  beak: any\n');
    out = StringBuffer();
  });

  /// Runs `make:migration AddStock --from-drift` in [root].
  ///
  /// [tables] is what the injected reader reports; leave it null for a case
  /// whose guard must fail before anything is read.
  Future<int> run({
    List<IntrospectedTable>? tables,
    Map<String, String> processEnvironment = const {},
  }) async {
    final environment = BeakCliEnvironment(
      out: out,
      rootDirectory: root,
      now: () => DateTime.utc(2026, 7, 28, 12),
      probe: (host, port) async => false,
      processEnvironment: processEnvironment,
    );
    final runner = CommandRunner<int>('beak', 'test')
      ..addCommand(
        MakeMigrationCommand(
          environment,
          readSchema: (url, {String schema = 'public'}) async =>
              tables ??
              (throw StateError('the guard should have failed before reading')),
        ),
      );
    return await runner.run(['make:migration', 'AddStock', '--from-drift']) ??
        0;
  }

  void writeSchema({required bool requiredStock}) {
    File('${root.path}/lib/models/product.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(productSchema(requiredStock: requiredStock));
  }

  File migration() => File('${root.path}/lib/migrations/add_stock.dart');

  File database() => File('${root.path}/beak.db');

  group('before the first migrate', () {
    test('refuses to look, and creates nothing', () async {
      // Opening a SQLite file creates it, so "looking" used to leave an
      // empty beak.db behind and then report that it lacked nothing.
      writeSchema(requiredStock: false);

      expect(await run(), 1);
      expect(out.toString(), contains('run `beak migrate` first'));
      expect(database().existsSync(), isFalse, reason: 'looking created it');
      expect(migration().existsSync(), isFalse);
    });
  });

  group('a database it cannot read', () {
    test('in-memory SQLite is named, not probed', () async {
      // This used to fall through to the Postgres reader and surface as a
      // socket error on port 0.
      writeSchema(requiredStock: false);
      File(
        '${root.path}/.env',
      ).writeAsStringSync('DATABASE_URL=sqlite::memory:\n');

      expect(await run(), 1);
      expect(out.toString(), contains('in-memory'));
    });

    test('a DATABASE_URL from the shell is the one it names', () async {
      // Read from the .env alone, this compared against the default SQLite
      // file whatever the shell said.
      writeSchema(requiredStock: false);

      expect(
        await run(processEnvironment: {'DATABASE_URL': 'sqlite::memory:'}),
        1,
      );
      expect(out.toString(), contains('in-memory'));
    });

    test('the shell beats the .env', () async {
      writeSchema(requiredStock: false);
      File(
        '${root.path}/.env',
      ).writeAsStringSync('DATABASE_URL=mysql://localhost/beak\n');

      expect(
        await run(processEnvironment: {'DATABASE_URL': 'sqlite::memory:'}),
        1,
      );
      expect(out.toString(), contains('in-memory'));
      expect(out.toString(), isNot(contains('mysql')));
    });

    test('an unsupported scheme is named', () async {
      writeSchema(requiredStock: false);
      File(
        '${root.path}/.env',
      ).writeAsStringSync('DATABASE_URL=mysql://localhost/beak\n');

      expect(await run(), 1);
      expect(out.toString(), contains('"mysql" is not supported'));
    });
  });

  group('against a readable database', () {
    setUp(() {
      // The guard only needs the file to exist; the injected reader answers
      // for its contents.
      File('${root.path}/beak.db').writeAsStringSync('');
    });

    test('writes the migration and exits 0 when a column is addable', () async {
      writeSchema(requiredStock: false);

      expect(await run(tables: productsTable(['id', 'name'])), 0);
      expect(migration().existsSync(), isTrue);
      expect(
        migration().readAsStringSync(),
        contains('BeakBlueprint.defineColumn(table, ProductColumns.stock)'),
      );
      expect(out.toString(), contains('run `beak migrate` to apply it'));
    });

    test('exits 1 when every missing column needs a decision', () async {
      // "No drift" and "drift no migration can express" are different
      // answers, and exit 0 on the second told CI the schema was applied.
      writeSchema(requiredStock: true);

      expect(await run(tables: productsTable(['id', 'name'])), 1);
      expect(migration().existsSync(), isFalse);
      expect(out.toString(), contains('! products.stock'));
      expect(out.toString(), contains('needs a decision first'));
    });

    test('refuses to overwrite a migration of the same name', () async {
      writeSchema(requiredStock: false);
      migration()
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('// mine, and already edited\n');

      expect(await run(tables: productsTable(['id', 'name'])), 1);

      expect(migration().readAsStringSync(), '// mine, and already edited\n');
      expect(out.toString(), contains('already exists'));
    });

    test('exits 0 and writes nothing when there is no drift', () async {
      writeSchema(requiredStock: false);

      expect(await run(tables: productsTable(['id', 'name', 'stock'])), 0);
      expect(migration().existsSync(), isFalse);
      expect(out.toString(), contains('nothing to add'));
    });
  });
}
