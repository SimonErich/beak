@Tags(['e2e'])
@TestOn('vm')
library;

import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

import '../support/served_project.dart';

/// Adding a field to a resource that already has data.
///
/// This is the shape of every second week of a project's life, and it is the
/// one Beak used to have no answer for: `beak prepare` writes a resource's
/// first migration and never rewrites it, so a column added afterwards
/// reaches the database through an `alter` migration the project owns.
///
/// What has to hold is that the rows already there survive it. A framework
/// that makes you choose between a new column and your data has not shipped
/// a migration story, it has shipped `migrate:fresh`.
///
/// Runs on the default SQLite file, so it needs nothing installed. It is
/// tagged `e2e` for its cost rather than its dependencies: a `flutter pub
/// get` and two `dart run`s are too slow for the main gate.
void main() {
  test(
    'a column added after launch reaches the table, and the rows stay',
    () async {
      final Directory repoRoot = Directory.current.parent.parent;
      final project = Directory.systemTemp.createTempSync('beak_evolve_');
      addTearDown(() => project.deleteSync(recursive: true));

      File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: shop
publish_to: none
environment:
  sdk: ^3.11.0
  flutter: '>=3.41.0'
dependencies:
  beak:
    path: ${repoRoot.path}/packages/beak
  flutter:
    sdk: flutter
''');

      final environment = BeakCliEnvironment(
        out: StringBuffer(),
        rootDirectory: project,
        now: () => DateTime.utc(2026, 7, 28, 12),
        probe: (host, port) async => false,
      );

      // Launch: one resource, its generated migration, one row of real data.
      expect(
        await createBeakRunner(environment).run([
          'make:resource',
          'Product',
          '--fields',
          'name:string!,price:decimal!',
        ]),
        0,
      );
      await _run(project, ['flutter', 'pub', 'get']);
      await _run(project, ['dart', 'run', 'bin/migrate.dart', 'migrate']);
      await _insertProduct(project, name: 'Espresso Beans', price: 12.5);

      // Week two: the catalog needs a stock count.
      final schema = File('${project.path}/lib/models/product.dart');
      schema.writeAsStringSync(
        schema.readAsStringSync().replaceFirst('}', '''
  /// Units in stock.
  @Column(sortable: true)
  late final int? stock;
}'''),
      );
      expect(runPrepare(environment).isSuccess, isTrue);

      // The first migration is written once and never rewritten, so the column
      // arrives through one the project owns.
      expect(
        await createBeakRunner(
          environment,
        ).run(['make:migration', 'AddStockToProducts']),
        0,
      );
      final alter = File(
        '${project.path}/lib/migrations/add_stock_to_products.dart',
      );
      expect(alter.existsSync(), isTrue, reason: 'the scaffold names the file');
      // Fill in the two bodies the scaffold left empty. `schema.alter`
      // reaches the same blueprint `schema.create` does, so each driver
      // compiles it its own way and no dialect appears here.
      alter.writeAsStringSync(
        alter
            .readAsStringSync()
            .replaceFirst(_scaffoldedUp, _realUp)
            .replaceFirst(_scaffoldedDown, _realDown),
      );
      expect(runPrepare(environment).isSuccess, isTrue);
      await _run(project, ['dart', 'run', 'bin/migrate.dart', 'migrate']);

      // The row is still there, and it can now carry the new column.
      final List<Map<String, Object?>> rows = await _products(project);
      expect(rows, hasLength(1));
      expect(rows.single['name'], 'Espresso Beans');
      expect(
        rows.single.containsKey('stock'),
        isTrue,
        reason: 'the alter reached the table',
      );
      expect(rows.single['stock'], isNull, reason: 'nullable, so no backfill');
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// The empty `upSchema` body `beak make:migration` writes.
const String _scaffoldedUp = '''
  Future<void> upSchema(Schema schema) async {
    // e.g. await schema.alter('products', (table) {
    //   table.string('status', length: 20).makeNullable();
    // });
  }''';

/// The empty `downSchema` body `beak make:migration` writes.
const String _scaffoldedDown = '''
  Future<void> downSchema(Schema schema) async {
    // The inverse of upSchema, so a rollback is not a restore from backup.
  }''';

/// What a person fills the first one in with.
const String _realUp = '''
  Future<void> upSchema(Schema schema) => schema.alter(
    'products',
    (table) => table.integer('stock').makeNullable(),
  );''';

/// And the second, so a rollback is not a restore from backup.
const String _realDown = '''
  Future<void> downSchema(Schema schema) =>
      schema.alter('products', (table) => table.dropColumn('stock'));''';

/// Runs [command] in [project], failing the test with its output.
Future<void> _run(Directory project, List<String> command) async {
  final ProcessResult result = await Process.run(
    command.first,
    command.skip(1).toList(),
    workingDirectory: project.path,
  );
  expect(
    result.exitCode,
    0,
    reason: '${command.join(' ')} failed:\n${result.stdout}\n${result.stderr}',
  );
}

/// Creates one product through the project's own API.
Future<void> _insertProduct(
  Directory project, {
  required String name,
  required double price,
}) => _throughTheApi(
  project,
  (port) => postJson(port, '/api/products', {'name': name, 'price': price}),
);

/// Every product, as the API reports it.
Future<List<Map<String, Object?>>> _products(Directory project) async {
  late List<Map<String, Object?>> rows;
  await _throughTheApi(project, (port) async {
    rows = recordsOf(
      await postJson(port, '/api/products/query', {'table': 'products'}),
    );
  });
  return rows;
}

/// Boots the project's server, hands [use] its port, and shuts it down.
///
/// Reading through the API rather than opening the database file is the
/// point: what matters is that the running application still sees its data.
Future<void> _throughTheApi(
  Directory project,
  Future<void> Function(int port) use,
) async {
  final int port = await freePort();
  final Process server = await serveProject(project, port: port);
  try {
    await use(port);
  } finally {
    await stopServer(server);
  }
}
