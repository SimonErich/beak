import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import 'doctor_command_test.dart'
    show
        checkMatching,
        driftSchema,
        environmentFor,
        noteModel,
        productSchema,
        projectWith;

const String _pubspec = 'name: acme_admin\ndependencies:\n  beak: ^0.9.0\n';

const String _authoredMain = '''
import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(BeakPanel(title: 'Acme', resources: []));
''';

Directory _prepared(Map<String, String> files) {
  final root = projectWith({'pubspec.yaml': _pubspec, ...files});
  runPrepare(environmentFor(root));
  return root;
}

Future<List<BeakCheck>> _diagnose(
  Directory root, {
  bool databaseUp = false,
  List<IntrospectedTable> tables = const [],
}) => diagnose(
  environmentFor(root, databaseUp: databaseUp),
  readSchema: (url, {String schema = 'public'}) async => tables,
);

void main() {
  group('a schema class that cannot be read', () {
    const uriField = '''
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'link.beak.dart';

@Resource()
final class Link extends BeakSchema {
  @Display()
  late final String title;
  late final Uri target;
}
''';

    test('is a failure, as it is for prepare', () async {
      // With a `Uri` field `beak prepare` exits 1 with "Cannot generate", and
      // doctor said OK and "All checks passed".
      final root = projectWith({
        'pubspec.yaml': _pubspec,
        'lib/models/link.dart': uriField,
      });

      final checks = await _diagnose(root);

      final check = checkMatching(checks, 'Link.target');
      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('lib/models/link.dart'));
    });

    test('makes the command exit 1', () async {
      final root = projectWith({
        'pubspec.yaml': _pubspec,
        'lib/models/link.dart': uriField,
      });
      final out = StringBuffer();

      final code = await createBeakRunner(
        environmentFor(root, out: out),
      ).run(['doctor']);

      expect(code, 1);
      expect(out.toString(), contains('Some checks failed.'));
    });

    test('is reported once, not once by the schema check and once by '
        'discovery', () async {
      final root = projectWith({
        'pubspec.yaml': _pubspec,
        'lib/models/link.dart': uriField,
      });

      final checks = await _diagnose(root);

      expect(
        checks.where((c) => c.label.contains('Link.target')),
        hasLength(1),
      );
    });
  });

  group('the imports of a migration', () {
    test('that no longer resolve are a failure, naming the file', () async {
      // Moving a schema file breaks the relative import in the migration that
      // creates its table. Doctor said OK, and the project stopped compiling.
      final root = _prepared({
        'lib/models/note.dart': noteModel,
        'lib/migrations/create_notes_table.dart': '''
import 'package:beak/migrations.dart';

import '../models/gone.dart';

final class CreateNotesTable extends Migration {
  const CreateNotesTable();
  @override
  String get name => '20260101_000000_create_notes_table';
  @override
  Future<void> upSchema(Schema schema) async {}
  @override
  Future<void> downSchema(Schema schema) async {}
}
''',
      });

      final check = checkMatching(await _diagnose(root), 'gone.dart');

      expect(check.status, BeakCheckStatus.fail);
      expect(check.label, contains('lib/migrations/create_notes_table.dart'));
      expect(check.label, contains('../models/gone.dart'));
      expect(check.remedy, contains('import'));
    });

    test(
      'that resolve pass, package imports of the project included',
      () async {
        final root = _prepared({
          'lib/models/note.dart': noteModel,
          'lib/models/tag.dart': "// a tag\n",
          'lib/migrations/create_notes_table.dart': '''
import 'package:beak/migrations.dart';
import 'package:acme_admin/models/tag.dart';

import '../models/note.dart';

final class CreateNotesTable extends Migration {
  const CreateNotesTable();
  @override
  String get name => '20260101_000000_create_notes_table';
  @override
  Future<void> upSchema(Schema schema) async {}
  @override
  Future<void> downSchema(Schema schema) async {}
}
''',
        });

        final checks = await _diagnose(root);

        expect(
          checkMatching(checks, 'migrations import').status,
          BeakCheckStatus.ok,
        );
      },
    );
  });

  group('a table whose create migration is written and pending', () {
    test('is told to run beak migrate, not to write a migration', () async {
      final root = _prepared({
        'lib/models/product.dart': productSchema(''),
        '.env': 'DATABASE_URL=postgres://beak:beak@localhost:25432/beak\n',
      });

      final checks = await _diagnose(root, databaseUp: true);

      final check = checkMatching(checks, 'declares table "products"');
      expect(check.status, BeakCheckStatus.warn);
      expect(check.remedy, 'beak migrate');
    });
  });

  group('real drift', () {
    Directory drifted(String extraFields) => _prepared({
      'lib/models/product.dart': productSchema(extraFields),
      '.env': 'DATABASE_URL=postgres://beak:beak@localhost:25432/beak\n',
    });

    test(
      'a missing column is told the migration to write, with the flag',
      () async {
        final checks = await _diagnose(
          drifted('\n  late final int? reserved;\n'),
          databaseUp: true,
          tables: driftSchema(),
        );

        final check = checkMatching(checks, 'products.reserved');
        expect(
          check.remedy,
          'beak make:migration AddReservedToProducts --from-drift, then '
          'beak migrate',
        );
      },
    );

    test('a missing bookkeeping column is reported once, with the same hint '
        'as any declared column', () async {
      // `softDeletes: true` and `timestamps: true` put `deleted_at` and
      // the stamps among the schema's declared columns, so reporting them
      // again as implied ones printed two warnings for one missing column.
      final List<IntrospectedTable> tables = [
        for (final table in driftSchema())
          IntrospectedTable(
            name: table.name,
            columns: [
              for (final column in table.columns)
                if (column.name != 'deleted_at' && column.name != 'updated_at')
                  column,
            ],
            foreignKeys: table.foreignKeys,
            primaryKey: table.primaryKey,
          ),
      ];

      final checks = await _diagnose(
        drifted(''),
        databaseUp: true,
        tables: tables,
      );

      final missing = [
        for (final check in checks)
          if (check.label.contains('deleted_at') ||
              check.label.contains('updated_at'))
            check,
      ];
      expect(missing, hasLength(2));
      expect(missing.map((check) => check.remedy), [
        'beak make:migration AddUpdatedAtToProducts --from-drift, then '
            'beak migrate',
        'beak make:migration AddDeletedAtToProducts --from-drift, then '
            'beak migrate',
      ]);
    });

    test(
      'a column nothing declares is told to declare it or drop it',
      () async {
        final checks = await _diagnose(
          drifted(''),
          databaseUp: true,
          tables: driftSchema(extraColumns: ['legacy_sku']),
        );

        final check = checkMatching(checks, 'products.legacy_sku');
        expect(
          check.remedy,
          'declare the field on Product, or drop the column with '
          'beak make:migration <Name>, then beak migrate',
        );
      },
    );
  });

  group('the summary of an authored panel', () {
    test('does not count screens and overrides it never uses', () async {
      // The generated panel finds `lib/screens/` and the override files. An
      // authored one lists its pages itself, so "0 screens" and "1 override"
      // (for lib/server.dart) described nothing.
      final root = _prepared({
        'lib/models/note.dart': noteModel,
        'lib/main.dart': _authoredMain,
        'lib/server.dart':
            "import 'package:beak/server.dart';\nBeakServer beakServer(BeakServerDefaults defaults) => defaults.build();\n",
      });

      final checks = await _diagnose(root);

      final check = checkMatching(checks, 'discovered');
      expect(
        check.label,
        'discovered 1 model · 0 resource classes · screens and overrides '
        'not applicable (lib/main.dart is authored)',
      );
    });

    test('names the entrypoint an embedded panel boots from', () async {
      final root = _prepared({
        'lib/models/note.dart': noteModel,
        'beak.yaml': 'panel:\n  entrypoint: lib/admin_main.dart\n',
        'lib/admin_main.dart': _authoredMain,
      });

      final check = checkMatching(await _diagnose(root), 'discovered');

      expect(check.label, contains('lib/admin_main.dart is authored'));
    });

    test('counts them for a generated panel', () async {
      final root = _prepared({'lib/models/note.dart': noteModel});

      final check = checkMatching(await _diagnose(root), 'discovered');

      expect(
        check.label,
        'discovered 1 model · 0 resource classes · 0 screens · 0 overrides',
      );
    });

    test('is what prepare prints too', () {
      final root = projectWith({
        'pubspec.yaml': _pubspec,
        'lib/models/note.dart': noteModel,
        'lib/main.dart': _authoredMain,
      });
      final out = StringBuffer();

      runPrepare(environmentFor(root, out: out));

      expect(
        out.toString(),
        contains(
          '1 model · 0 resource classes · screens and overrides not '
          'applicable (lib/main.dart is authored)',
        ),
      );
    });
  });
}
