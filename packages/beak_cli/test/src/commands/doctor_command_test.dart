import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:beak_cli/beak_cli.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

const String noteModel = '''
import 'package:beak_core/beak_core.dart';

final class NoteModel extends BeakModel {
  const NoteModel();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [];
}
''';

/// A schema class over `products`, plus whatever [extraFields] adds.
///
/// Matches [driftDatabase] exactly as written, so a test that wants drift
/// has to introduce it — which keeps each one about the difference it names.
String productSchema(String extraFields) =>
    '''
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';

/// Something for sale.
@Resource(softDeletes: true, timestamps: true)
final class Product extends BeakSchema {
  /// What it is called.
  @Display()
  late final String name;

  /// What it costs.
  late final double price;
$extraFields}
''';

/// The `products` table as the schema class above describes it, plus any
/// [extraColumns] the database has grown on its own.
List<IntrospectedTable> driftSchema({List<String> extraColumns = const []}) => [
  IntrospectedTable(
    name: 'products',
    columns: [
      for (final name in [
        'id',
        'name',
        'price',
        'created_at',
        'updated_at',
        'deleted_at',
        ...extraColumns,
      ])
        IntrospectedColumn(name: name, dataType: 'text', isNullable: true),
    ],
    foreignKeys: const [],
    primaryKey: 'id',
  ),
];

/// A reader that fails if anything reaches for it.
///
/// The default reader opens a real database, so a test that does not mean to
/// introspect must say so rather than find out over the network.
Future<List<IntrospectedTable>> neverRead(
  Uri url, {
  String schema = 'public',
}) async => throw StateError('a test read the live schema of $url');

/// A project directory seeded with [files].
Directory projectWith(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('beak_doctor_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final MapEntry(key: path, value: contents) in files.entries) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }
  return root;
}

BeakCliEnvironment environmentFor(
  Directory root, {
  bool databaseUp = false,
  StringSink? out,
}) => BeakCliEnvironment(
  out: out ?? StringBuffer(),
  rootDirectory: root,
  now: () => DateTime.utc(2026, 7, 26, 12),
  probe: (host, port) async => databaseUp,
);

/// Every check for a project seeded with [files].
Future<List<BeakCheck>> checksFor(Map<String, String> files) =>
    diagnose(environmentFor(projectWith(files)));

/// The check whose label contains [needle].
BeakCheck checkMatching(List<BeakCheck> checks, String needle) =>
    checks.firstWhere(
      (check) => check.label.contains(needle),
      orElse: () => throw StateError(
        'no check matching "$needle" in:\n'
        '${checks.map((check) => '  ${check.label}').join('\n')}',
      ),
    );

/// A minimal but complete project: pubspec, model, generated wiring.
Directory preparedProject() {
  final root = projectWith({
    'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
    'lib/models/note.dart': noteModel,
  });
  runPrepare(environmentFor(root));
  return root;
}

void main() {
  group('not a project', () {
    test('is the only check reported, with the fix', () async {
      final checks = await diagnose(environmentFor(projectWith({})));
      expect(checks, hasLength(1));
      expect(checks.single.status, BeakCheckStatus.fail);
      expect(checks.single.remedy, contains('beak create'));
    });
  });

  group('dependencies', () {
    test('a project not depending on Beak fails', () async {
      final checks = await diagnose(
        environmentFor(projectWith({'pubspec.yaml': 'name: acme_admin\n'})),
      );
      expect(
        checkMatching(checks, 'does not depend on beak').status,
        BeakCheckStatus.fail,
      );
    });

    test('a project depending on Beak passes', () async {
      final checks = await diagnose(environmentFor(preparedProject()));
      expect(
        checkMatching(checks, 'depends on Beak').status,
        BeakCheckStatus.ok,
      );
    });
  });

  group('beak.yaml', () {
    test('a malformed file fails, and stops further checks', () async {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
        'beak.yaml': 'colour: blue\n',
      });
      final checks = await diagnose(environmentFor(root));
      expect(checkMatching(checks, 'colour').status, BeakCheckStatus.fail);
      // Nothing downstream can be trusted once config parsing failed.
      expect(
        checks.where((check) => check.label.contains('discovered')),
        isEmpty,
      );
    });
  });

  group('beak.yaml resources', () {
    test('a key naming no table fails, with a did-you-mean', () async {
      // `prepare` refuses to generate on this, so a doctor that stayed quiet
      // reported a healthy project that could not be generated.
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/note.dart': noteModel,
        'beak.yaml': 'resources:\n  note:\n    icon: fileText\n',
      });
      runPrepare(environmentFor(root));

      final check = checkMatching(
        await diagnose(environmentFor(root), readSchema: neverRead),
        'note',
      );
      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('notes'), reason: 'no did-you-mean');
    });

    test('a key naming a real table is not reported', () async {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/note.dart': noteModel,
        'beak.yaml': 'resources:\n  notes:\n    icon: fileText\n',
      });
      runPrepare(environmentFor(root));

      final checks = await diagnose(
        environmentFor(root),
        readSchema: neverRead,
      );
      expect(checks.where((c) => c.status == BeakCheckStatus.fail), isEmpty);
    });
  });

  group('models', () {
    test('an empty project warns rather than failing', () async {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
      });
      final checks = await diagnose(environmentFor(root));
      final check = checkMatching(checks, 'no models found');
      expect(check.status, BeakCheckStatus.warn);
      expect(check.remedy, contains('lib/models/'));
    });

    test('a discovery issue is surfaced as a failure', () async {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
        'lib/models/note.dart': '''
import 'package:beak_core/beak_core.dart';

final class NoteModel extends BeakModel {
  NoteModel(this.table);
  @override
  final String table;
}
''',
      });
      final checks = await diagnose(environmentFor(root));
      expect(
        checkMatching(checks, 'const NoteModel()').status,
        BeakCheckStatus.fail,
      );
    });
  });

  group('generated files', () {
    test('a prepared project reports them up to date', () async {
      final checks = await diagnose(environmentFor(preparedProject()));
      expect(
        checkMatching(checks, 'generated files up to date').status,
        BeakCheckStatus.ok,
      );
    });

    test('a stale file fails, naming `beak prepare` as the fix', () async {
      final root = preparedProject();
      File(
        '${root.path}/lib/beak/registry.g.dart',
      ).writeAsStringSync('// hand-edited\n');

      final checks = await diagnose(environmentFor(root));
      final check = checkMatching(checks, 'out of date');
      expect(check.status, BeakCheckStatus.fail);
      expect(check.remedy, 'beak prepare');
      expect(check.label, contains('1 stale'));
    });

    test('a stale <model>.beak.dart fails too', () async {
      // The part files are written a step before `BeakEmitters.all` runs, so
      // they used not to be compared at all — and `examples/quickstart` sat
      // 18 lines behind the emitter while doctor reported "up to date".
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/product.dart': productSchema(''),
      });
      runPrepare(environmentFor(root));
      // Stands in for the real drift: a part file written by an older
      // emitter, missing whatever the current one adds.
      final part = File('${root.path}/lib/models/product.beak.dart');
      final List<String> lines = part.readAsLinesSync();
      part.writeAsStringSync('${lines.take(lines.length - 2).join('\n')}\n');

      final check = checkMatching(
        await diagnose(environmentFor(root), readSchema: neverRead),
        'out of date',
      );
      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('1 stale'));
      expect(check.remedy, 'beak prepare');
    });

    test('a missing entrypoint fails — the fresh-clone case', () async {
      final root = preparedProject();
      File('${root.path}/lib/main.dart').deleteSync();

      final check = checkMatching(
        await diagnose(environmentFor(root)),
        'out of date',
      );
      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('1 missing'));
    });
  });

  group('migration coverage', () {
    test('a model with no table fails, naming it', () async {
      // `beak create x && beak dev` used to start a server whose every
      // endpoint failed on a missing table, and doctor said all clear.
      final checks = await checksFor({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
        'lib/models/note.dart': """
import 'package:beak/beak.dart';

final class NoteModel extends BeakModel {
  const NoteModel();
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [];
}
""",
      });

      final check = checkMatching(checks, 'no migration creates');
      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('notes'));
      expect(check.remedy, 'beak prepare');
    });

    test('a prepared project passes', () async {
      final checks = await diagnose(environmentFor(preparedProject()));

      expect(
        checkMatching(checks, 'every model has a migration').status,
        BeakCheckStatus.ok,
      );
    });
  });

  group('web safety', () {
    /// A prepared project whose screen file is [screen].
    ///
    /// Prepared, because the check follows the panel's import graph: a file
    /// nothing imports is not a panel file, and the screen only becomes one
    /// once `beak prepare` has wired it into panel.g.dart.
    Directory projectWithScreen(String screen) {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/note.dart': noteModel,
        'lib/screens/reports.dart': screen,
      });
      runPrepare(environmentFor(root));
      return root;
    }

    test('a panel file importing the server fails, naming the file', () async {
      // The exact failure the library split exists to prevent: it compiles,
      // then dies in a browser — or takes the server's AOT build with it.
      final checks = await diagnose(
        environmentFor(
          projectWithScreen('''
import 'package:beak/panel.dart';
import 'package:beak/server.dart';

BeakScreen buildReportsScreen() => BeakScreen();
'''),
        ),
        readSchema: neverRead,
      );

      final check = checkMatching(checks, 'lib/screens/reports.dart');
      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('package:beak/server.dart'));
      expect(check.remedy, contains('lib/server.dart'));
    });

    test('a screen the panel does import is reached through it', () async {
      // Proves the walk is transitive rather than a scan of lib/screens/:
      // the offending import sits one file further out, in a helper the
      // screen imports.
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/note.dart': noteModel,
        'lib/screens/reports.dart': '''
import 'package:beak/panel.dart';

import '../reporting/totals.dart';

BeakScreen buildReportsScreen() => BeakScreen(total: monthlyTotal);
''',
        'lib/reporting/totals.dart': '''
import 'package:beak/server.dart';

int get monthlyTotal => 0;
''',
      });
      runPrepare(environmentFor(root));

      final check = checkMatching(
        await diagnose(environmentFor(root), readSchema: neverRead),
        'lib/reporting/totals.dart',
      );
      expect(check.status, BeakCheckStatus.fail);
    });

    test('lib/server.dart and the migrations may import it', () async {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/note.dart': noteModel,
        'lib/server.dart': "import 'package:beak/server.dart';\n",
        'lib/migrations/create_notes.dart':
            "import 'package:beak/migrations.dart';\n",
      });
      runPrepare(environmentFor(root));

      expect(
        checkMatching(
          await diagnose(environmentFor(root), readSchema: neverRead),
          'no panel file imports the server',
        ).status,
        BeakCheckStatus.ok,
      );
    });

    test('a server-side file the panel never imports is not a panel file', () {
      // `examples/embedded` keeps `lib/legacy_system.dart`, which migrates
      // the host system's own table and is imported by `bin/host.dart`
      // alone. A path allowlist called that a failure; the import graph
      // knows better.
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/note.dart': noteModel,
        'lib/legacy_system.dart': "import 'package:beak/migrations.dart';\n",
      });
      runPrepare(environmentFor(root));

      expect(
        serverImportChecks(root, packageName: 'acme_admin').single.status,
        BeakCheckStatus.ok,
      );
    });

    test('a project with no panel entrypoint reports nothing', () {
      // Before `beak prepare` there is no panel to protect, and inventing a
      // verdict about one would be a guess.
      expect(
        serverImportChecks(
          projectWith({'lib/screens/reports.dart': "import 'dart:io';\n"}),
          packageName: 'acme_admin',
        ),
        isEmpty,
      );
    });

    test('a missing web/ warns rather than fails', () async {
      final checks = await checksFor({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
      });

      final check = checkMatching(checks, 'web/');
      expect(check.status, BeakCheckStatus.warn);
      expect(check.remedy, contains('flutter create'));
    });
  });

  group('database', () {
    test('a SQLite URL passes without probing anything', () async {
      final checks = await checksFor({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak:\n',
        '.env': 'DATABASE_URL=sqlite:beak.db\n',
      });

      final check = checkMatching(checks, 'SQLite');
      expect(check.status, BeakCheckStatus.ok);
    });

    test('an absent DATABASE_URL is the supported default, not a problem', () {
      // Warning about a working zero-setup project trains people to ignore
      // this output.
      expect(
        diagnose(
          environmentFor(preparedProject()),
        ).then((checks) => checkMatching(checks, 'no DATABASE_URL').status),
        completion(BeakCheckStatus.ok),
      );
    });

    test('an unreachable database warns with the two possible fixes', () async {
      final root = preparedProject();
      File('${root.path}/.env').writeAsStringSync(
        'DATABASE_URL=postgres://beak:beak@localhost:25432/beak\n',
      );
      final check = checkMatching(
        await diagnose(environmentFor(root)),
        'database unreachable',
      );
      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('localhost:25432'));
      expect(check.remedy, contains('DATABASE_URL'));
    });

    test('a reachable database passes', () async {
      final root = preparedProject();
      File('${root.path}/.env').writeAsStringSync(
        'DATABASE_URL=postgres://beak:beak@localhost:25432/beak\n',
      );
      final check = checkMatching(
        await diagnose(
          environmentFor(root, databaseUp: true),
          readSchema: neverRead,
        ),
        'database reachable',
      );
      expect(check.status, BeakCheckStatus.ok);
    });
  });

  group('an in-memory database', () {
    test('is named, and neither probed nor read', () async {
      // `sqlite::memory:` used to fall through to the Postgres branch and
      // warn "database unreachable at :0" on every run, forever.
      final root = preparedProject();
      File(
        '${root.path}/.env',
      ).writeAsStringSync('DATABASE_URL=sqlite::memory:\n');

      final checks = await diagnose(
        environmentFor(root),
        readSchema: neverRead,
      );
      final check = checkMatching(checks, 'in-memory');
      expect(check.status, BeakCheckStatus.ok);
      expect(
        checks.where((check) => check.label.contains('unreachable')),
        isEmpty,
      );
    });
  });

  group('drift', () {
    /// A project whose one schema class declares a `products` table shaped
    /// like the one [shopDatabase] introspects.
    Directory shopProject({String extraFields = ''}) {
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/product.dart': productSchema(extraFields),
        '.env': 'DATABASE_URL=postgres://beak:beak@localhost:25432/beak\n',
      });
      runPrepare(environmentFor(root));
      return root;
    }

    Future<List<BeakCheck>> checksAgainst(
      Directory root, {
      List<String> extraColumns = const [],
    }) => diagnose(
      environmentFor(root, databaseUp: true),
      readSchema: (url, {String schema = 'public'}) async =>
          driftSchema(extraColumns: extraColumns),
    );

    test(
      'a column the database lacks is a warning naming both sides',
      () async {
        final checks = await checksAgainst(
          shopProject(
            extraFields: '''

  /// How many are reserved.
  late final int? reserved;
''',
          ),
        );

        final check = checkMatching(checks, 'products.reserved');
        expect(check.status, BeakCheckStatus.warn);
        expect(check.label, contains('Product.reserved'));
        expect(check.remedy, contains('beak make:migration'));
      },
    );

    test('a matching database reports one check, not one per column', () async {
      final checks = await checksAgainst(shopProject());

      final check = checkMatching(checks, 'matches the schema classes');
      expect(check.status, BeakCheckStatus.ok);
    });

    test('a column the schema does not declare is drift too', () async {
      // The direction people forget: someone added it by hand, and every
      // generated migration from here on is derived from a schema that has
      // never heard of it.
      final checks = await checksAgainst(
        shopProject(),
        extraColumns: ['legacy_sku'],
      );

      final check = checkMatching(checks, 'products.legacy_sku');
      expect(check.status, BeakCheckStatus.warn);
      expect(check.label, contains('Product does not declare it'));
    });

    test('drift alone does not fail the run', () async {
      final runner = CommandRunner<int>('beak', 'test')
        ..addCommand(
          DoctorCommand(
            environmentFor(
              shopProject(extraFields: '\n  late final int? reserved;\n'),
              databaseUp: true,
            ),
            readSchema: (url, {String schema = 'public'}) async =>
                driftSchema(),
          ),
        );
      final code = await runner.run(['doctor']);

      // A database is not the project, and the fix is a migration someone
      // has to write. Blocking CI on it would make `doctor` unrunnable
      // against any environment mid-deploy.
      expect(code, 0);
    });

    test(
      'an unreadable database says so rather than reporting drift',
      () async {
        final checks = await diagnose(
          environmentFor(shopProject(), databaseUp: true),
          readSchema: (url, {String schema = 'public'}) async =>
              throw const SocketException('password rejected'),
        );

        final check = checkMatching(
          checks,
          'could not read the database schema',
        );
        expect(check.status, BeakCheckStatus.warn);
        expect(check.remedy, contains('credentials'));
      },
    );

    test('a project with no schema classes is not checked at all', () async {
      final root = preparedProject();
      File('${root.path}/.env').writeAsStringSync(
        'DATABASE_URL=postgres://beak:beak@localhost:25432/beak\n',
      );

      // The hand-written-model hatch: there is no schema class to compare
      // against, so there is nothing to say.
      final checks = await diagnose(
        environmentFor(root, databaseUp: true),
        readSchema: neverRead,
      );
      expect(
        checks.where((check) => check.label.contains('schema classes')),
        isEmpty,
      );
    });
  });

  group('drift on a real SQLite file', () {
    test(
      'a column the model gained is named, against the default db',
      () async {
        // The configuration most projects run: no DATABASE_URL, so the default
        // file. Drift used to be Postgres-only, which left the zero-setup
        // default with the least checking of any database Beak supports.
        final root = projectWith({
          'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
          'lib/models/product.dart': productSchema(''),
        });
        runPrepare(environmentFor(root));

        // A table shaped like the schema class, minus the column it is about
        // to gain.
        final database = sqlite3.open('${root.path}/beak.db');
        database.execute(
          'CREATE TABLE products ('
          'id TEXT PRIMARY KEY, name TEXT, price NUMERIC(12, 4), '
          'created_at TEXT, updated_at TEXT, deleted_at TEXT)',
        );
        database.dispose();

        final checks = await diagnose(environmentFor(root));
        expect(
          checkMatching(checks, 'default SQLite file').status,
          BeakCheckStatus.ok,
        );
        expect(
          checkMatching(checks, 'matches the schema classes').status,
          BeakCheckStatus.ok,
        );

        // Now the model gains a column the table has not got.
        final schema = File('${root.path}/lib/models/product.dart');
        schema.writeAsStringSync(
          schema.readAsStringSync().replaceFirst(
            'late final double price;',
            'late final double price;\n\n  /// Units in stock.\n'
                '  late final int? stock;',
          ),
        );
        runPrepare(environmentFor(root));

        final check = checkMatching(
          await diagnose(environmentFor(root)),
          'products.stock',
        );
        expect(check.status, BeakCheckStatus.warn);
        expect(check.label, contains('Product.stock'));
      },
    );

    test('a database that does not exist yet is not drift', () async {
      // Before the first migrate there is no file, and nothing that could be
      // out of step with the models.
      final root = projectWith({
        'pubspec.yaml': 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n',
        'lib/models/product.dart': productSchema(''),
      });
      runPrepare(environmentFor(root));

      final checks = await diagnose(environmentFor(root));
      final check = checkMatching(checks, 'not created yet');
      expect(check.status, BeakCheckStatus.ok);
      expect(check.remedy, 'beak migrate');
      expect(checks.every((c) => c.status != BeakCheckStatus.fail), isTrue);
    });
  });

  group('exit code', () {
    test('is 0 when only warnings are present', () async {
      final out = StringBuffer();
      final code = await createBeakRunner(
        environmentFor(preparedProject(), out: out),
      ).run(['doctor']);
      expect(code, 0, reason: 'warnings must not fail the command');
      expect(out.toString(), contains('All checks passed.'));
    });

    test('is 1 when any check failed', () async {
      final root = preparedProject();
      File('${root.path}/lib/main.dart').deleteSync();
      final out = StringBuffer();
      final code = await createBeakRunner(
        environmentFor(root, out: out),
      ).run(['doctor']);
      expect(code, 1);
      expect(out.toString(), contains('Some checks failed.'));
      expect(out.toString(), contains('→ beak prepare'));
    });
  });

  group('--json', () {
    test('reports the same verdict as a machine-readable document', () async {
      final out = StringBuffer();
      final code = await createBeakRunner(
        environmentFor(preparedProject(), out: out),
      ).run(['doctor', '--json']);

      final Object? decoded = jsonDecode(out.toString());
      expect(decoded, isA<Map<String, Object?>>());
      if (decoded case {
        'healthy': final bool healthy,
        'checks': final List<Object?> checks,
      }) {
        expect(healthy, isTrue);
        expect(code, 0);
        expect(checks, isNotEmpty);
        expect(
          checks.whereType<Map<String, Object?>>().map((c) => c['status']),
          everyElement(isIn(['ok', 'warn', 'fail'])),
        );
      } else {
        fail('expected {healthy, checks}, got $decoded');
      }
    });

    test('prints nothing but the document', () async {
      final out = StringBuffer();
      await createBeakRunner(
        environmentFor(preparedProject(), out: out),
      ).run(['doctor', '--json']);

      expect(out.toString(), isNot(contains('All checks passed.')));
      expect(out.toString().trimLeft(), startsWith('{'));
    });
  });
}
