@Tags(['e2e'])
@TestOn('vm')
library;

import 'dart:io';

import '../support/beak_cli_internals.dart';
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
/// The other half of the promise is that the same migrations also build a
/// database from nothing. A create migration reads the model as it is today, so
/// a fresh database already has every column a later `alter` adds, and the
/// alter has to notice rather than fail with a duplicate column.
///
/// Runs on the default SQLite file, so it needs nothing installed. It is
/// tagged `e2e` for its cost rather than its dependencies: a `flutter pub
/// get` and several `dart run`s are too slow for the main gate.
void main() {
  test('a column added after launch reaches the table, the rows stay, and the '
      'same migrations build an empty database', () async {
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

    // Migrations run in the order of their names, which start with this
    // stamp, so a migration written later has to be stamped later.
    var clock = DateTime.utc(2026, 7, 28, 12);
    final environment = BeakCliEnvironment(
      out: StringBuffer(),
      rootDirectory: project,
      now: () => clock,
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
    await _insertProduct(project, name: 'Espresso Beans', priceInUnits: 1250);

    // Week two: the catalog needs a stock count.
    clock = clock.add(const Duration(days: 7));
    final schema = File(
      '${project.path}/lib/resources/products/models/product.dart',
    );
    schema.writeAsStringSync(
      schema.readAsStringSync().replaceFirst('}', '''
  /// Units in stock.
  @Column(sortable: true)
  late final int? stock;
}'''),
    );
    expect(runPrepare(environment).isSuccess, isTrue);

    // The first migration is written once and never rewritten, and a Beak
    // migration derives its columns from the model at runtime rather than
    // naming them, so nothing static could work out what this database is
    // missing. `--from-drift` looks instead.
    expect(
      await createBeakRunner(
        environment,
      ).run(['make:migration', 'AddStockToProducts', '--from-drift']),
      0,
    );
    final alter = File(
      '${project.path}/lib/migrations/add_stock_to_products.dart',
    );
    expect(alter.existsSync(), isTrue, reason: 'the scaffold names the file');
    expect(
      alter.readAsStringSync(),
      contains('BeakBlueprint.defineColumn(table, ProductColumns.stock)'),
      reason: 'the body was left empty rather than filled in from drift',
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

    // Back down and up again: the alter is undone only where it left
    // something, and applied only where it is missing. The rows go with the
    // tables, so the next step starts from one again.
    await _run(project, ['dart', 'run', 'bin/migrate.dart', 'migrate:refresh']);
    expect(await _products(project), isEmpty);
    await _insertProduct(project, name: 'Espresso Beans', priceInUnits: 1250);

    // Week three: products belong to a category, a table of its own and a
    // key on the one that has data.
    clock = clock.add(const Duration(days: 7));
    expect(
      await createBeakRunner(
        environment,
      ).run(['make:resource', 'Category', '--fields', 'name:string!']),
      0,
    );
    schema.writeAsStringSync(
      schema
          .readAsStringSync()
          .replaceFirst(
            "part 'product.beak.dart';",
            "import '../../categories/models/category.dart';\n\n"
                "part 'product.beak.dart';",
          )
          .replaceFirstMapped(
            RegExp(r'\}\s*$'),
            (_) => '''
  /// What kind of product it is.
  @BelongsTo()
  late final Category? category;
}
''',
          ),
    );
    clock = clock.add(const Duration(days: 1));
    expect(runPrepare(environment).isSuccess, isTrue);
    clock = clock.add(const Duration(days: 1));
    expect(
      await createBeakRunner(
        environment,
      ).run(['make:migration', 'AddCategoryToProducts', '--from-drift']),
      0,
    );
    final keyed = File(
      '${project.path}/lib/migrations/add_category_to_products.dart',
    ).readAsStringSync();
    expect(keyed, contains('isForeignKey: true'));
    expect(keyed, contains('table.foreign('));
    expect(runPrepare(environment).isSuccess, isTrue);
    await _run(project, ['dart', 'run', 'bin/migrate.dart', 'migrate']);

    final List<Map<String, Object?>> keyedRows = await _products(project);
    expect(keyedRows.single['name'], 'Espresso Beans');
    expect(keyedRows.single.containsKey('category_id'), isTrue);

    // From nothing. Every migration replays over a database whose create
    // already made the columns the alters add, which used to stop at the
    // first of them with `duplicate column name`.
    for (final suffix in const ['', '-shm', '-wal', '-journal']) {
      final file = File('${project.path}/beak.db$suffix');
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    await _run(project, ['dart', 'run', 'bin/migrate.dart', 'migrate']);

    // The products migration is the older one and its model has pointed at
    // categories ever since, so name order would create products first. SQLite
    // lets a constraint name a table that is not there yet; Postgres does
    // not. The order the host registers them in is the one that holds on
    // both, and the status list shows the order they ran in.
    final ProcessResult status = await Process.run('dart', const [
      'run',
      'bin/migrate.dart',
      'migrate:status',
    ], workingDirectory: project.path);
    final String ran = '${status.stdout}';
    expect(ran.indexOf('create_categories_table'), isNonNegative, reason: ran);
    expect(
      ran.indexOf('create_categories_table'),
      lessThan(ran.indexOf('create_products_table')),
      reason: 'a table was created before the table its key points at:\n$ran',
    );

    // A setting the host refuses ends a generated entrypoint with one line and
    // a sysexits code, not "Unhandled exception" and a trace.
    for (final (entrypoint, arguments, environment) in const [
      ('bin/serve.dart', <String>[], {'PORT': 'abc'}),
      ('bin/migrate.dart', <String>['migrate'], {'DATABASE_URL': 'ftp://nope'}),
    ]) {
      final ProcessResult refused = await Process.run(
        'dart',
        ['run', entrypoint, ...arguments],
        workingDirectory: project.path,
        environment: environment,
      );
      expect(refused.exitCode, 78, reason: '$entrypoint:\n${refused.stderr}');
      // `dart run` may print its build-hook progress ahead of the child's own
      // output, without a newline.
      final List<String> lines = '${refused.stderr}'
          .replaceAll('Running build hooks...', '')
          .trim()
          .split('\n');
      expect(lines, hasLength(1), reason: '$entrypoint:\n${refused.stderr}');
      expect(lines.single, contains(environment.keys.single));
    }
    await _insertProduct(project, name: 'Decaf', priceInUnits: 900, stock: 4);
    final List<Map<String, Object?>> rebuilt = await _products(project);
    expect(rebuilt.single['name'], 'Decaf');
    expect(rebuilt.single['stock'], 4);
    expect(rebuilt.single.containsKey('category_id'), isTrue);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

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
  required int priceInUnits,
  int? stock,
}) => _throughTheApi(
  project,
  (port) => postJson(port, '/api/products', {
    'name': name,
    // A `decimal` field is a `BeakDecimal`, and the wire carries its stored
    // form: integer units at the scale, so 12.50 is 1250.
    'price': priceInUnits,
    'stock': ?stock,
  }),
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
