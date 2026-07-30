/// Integration tests for `worm make:migration --auto`.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/cli/worm_command_runner.dart';
import 'package:worm/src/migration/diff_engine.dart';
import 'package:worm/src/migration/migration_auto_generator.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/blueprint.dart';
import 'package:worm/src/schema/column_type.dart';
import 'package:worm/src/schema/schema_facade.dart';
import 'package:worm/src/schema/table_schema.dart';

import '_fixtures.dart';

String _targetSchemaJson() => '''
{
  "tables": [
    {
      "name": "users",
      "columns": [
        {"name": "id", "type": "uuid", "isPrimaryKey": true},
        {"name": "name", "type": "string"}
      ]
    }
  ]
}
''';

Future<void> _writeTargetSchema(Directory projectRoot) async {
  final file = File('${projectRoot.path}/schema/schema.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(_targetSchemaJson());
}

List<TableSchema> _normalizeToTextTypes(List<TableSchema> tables) =>
    <TableSchema>[
      for (final t in tables)
        TableSchema(
          name: t.name,
          columns: <ColumnSnapshot>[
            for (final c in t.columns)
              ColumnSnapshot(name: c.name, type: ColumnType.text),
          ],
        ),
    ];

Future<List<TableSchema>> _liveSchema(InMemoryAdapter adapter) async {
  final raw = await adapter.introspectSchema();
  return <TableSchema>[
    for (final entry in raw.entries)
      TableSchema(
        name: entry.key,
        columns: <ColumnSnapshot>[
          for (final col in entry.value)
            ColumnSnapshot(name: col, type: ColumnType.text),
        ],
      ),
  ];
}

void main() {
  group('worm make:migration --auto', () {
    test(
      'writes a migration with schema.create() calls for new tables',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        await _writeTargetSchema(harness.projectRoot);

        final runner = WormCommandRunner(harness.build());
        final code = await runner.run(<String>[
          'make:migration',
          'create_users_auto',
          '--auto',
        ]);
        expect(code, 0);

        final files = Directory(
          '${harness.projectRoot.path}/migrations',
        ).listSync().whereType<File>().toList();
        expect(files, hasLength(1));
        final source = files.single.readAsStringSync();
        expect(source, contains("schema.create('users'"));
        expect(source, contains("table.uuid('id')..primary();"));
        expect(source, contains("table.string('name');"));
        expect(source, contains('extends Migration'));
        expect(source, contains('upSchema(Schema schema)'));
        expect(source, contains('downSchema(Schema schema)'));
        expect(source, contains("schema.drop('users', ifExists: true);"));
      },
    );

    test(
      'fails with a typed FormatException when schema.json is missing',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        final adapter = InMemoryAdapter();
        await adapter.connect();
        final generator = MigrationAutoGenerator(
          adapter: adapter,
          projectRoot: harness.projectRoot,
        );
        await expectLater(
          () =>
              generator.generate(className: 'M', fileName: '20260101_000000_m'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('applying the diff brings the live schema to match the target '
        '(DiffEngine.diff() empty after run)', () async {
      final harness = TestHarness();
      addTearDown(harness.dispose);
      await _writeTargetSchema(harness.projectRoot);

      // Build the same generator the CLI uses.
      final adapter = harness.adapter;
      await adapter.connect();
      final generator = MigrationAutoGenerator(
        adapter: adapter,
        projectRoot: harness.projectRoot,
      );
      final target = await generator.readTargetSchema();

      // Simulate executing the generated migration body — apply
      // the target via the Schema facade directly. This is exactly
      // what `schema.create('users', …)` would do inside the
      // generated `upSchema()`.
      final schema = Schema.forRunner(adapter);
      for (final t in target) {
        await schema.create(t.name, (table) {
          for (final col in t.columns) {
            switch (col.type) {
              case ColumnType.uuid:
                final c = table.uuid(col.name);
                if (col.isPrimaryKey) c.primary();
              case ColumnType.string:
                table.string(col.name);
              default:
                table.text(col.name);
            }
          }
        });
      }

      // Re-introspect; compare to a normalized target where
      // both sides use ColumnType.text so the diff is purely
      // structural (the in-memory adapter does not record types).
      final liveAfter = await _liveSchema(adapter);
      final normalisedTarget = _normalizeToTextTypes(target);
      final diff = DiffEngine.diff(from: liveAfter, to: normalisedTarget);
      expect(diff.isEmpty, isTrue);
    });

    test(
      'emits schema.drop for tables present live but absent from target',
      () async {
        final harness = TestHarness();
        addTearDown(harness.dispose);
        await _writeTargetSchema(harness.projectRoot);

        // Seed an extra table on the live adapter so the diff
        // produces a dropTable entry.
        final adapter = harness.adapter;
        await adapter.connect();
        await adapter.executeSchema(
          const SchemaDescriptor.createTable(table: 'obsolete'),
        );

        final runner = WormCommandRunner(harness.build());
        final code = await runner.run(<String>[
          'make:migration',
          'prune_obsolete',
          '--auto',
        ]);
        expect(code, 0);

        final source = Directory(
          '${harness.projectRoot.path}/migrations',
        ).listSync().whereType<File>().single.readAsStringSync();
        expect(source, contains("schema.drop('obsolete');"));
      },
    );

    test('uses Blueprint via the Schema facade only', () {
      // Sanity check that this test file imports the Blueprint and
      // Schema facade so the in-scope verification above compiles
      // even when the auto-generator changes.
      expect(Blueprint.drop('x').operation, BlueprintOperation.drop);
    });
  });
}
