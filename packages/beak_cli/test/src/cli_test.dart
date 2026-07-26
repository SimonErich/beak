import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late StringBuffer out;
  late Map<(String, int), bool> reachable;
  late CommandRunner<int> runner;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_cli_test');
    addTearDown(() => root.deleteSync(recursive: true));
    out = StringBuffer();
    reachable = {};
    runner = createBeakRunner(
      BeakCliEnvironment(
        out: out,
        rootDirectory: root,
        now: () => DateTime.utc(2026, 7, 3, 12),
        probe: (host, port) async => reachable[(host, port)] ?? false,
      ),
    );
  });

  String read(String relativePath) =>
      File('${root.path}/$relativePath').readAsStringSync();

  group('field specs', () {
    test('parses every kind including aliases', () {
      final specs = BeakFieldSpec.parseList(
        'name:string,notes:text,stock:int,price:decimal,'
        'active:bool,released_at:datetime',
      );
      expect(specs.map((spec) => spec.kind), [
        BeakFieldKind.string,
        BeakFieldKind.text,
        BeakFieldKind.integer,
        BeakFieldKind.decimal,
        BeakFieldKind.boolean,
        BeakFieldKind.dateTime,
      ]);
      expect(specs.last.camelName, 'releasedAt');
    });

    test('rejects malformed tokens with a pointed message', () {
      expect(
        () => BeakFieldSpec.parse('nameonly'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BeakFieldSpec.parse('name:blob'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BeakFieldSpec.parse('BadName:string'),
        throwsA(isA<FormatException>()),
      );
    });

    test('derives snake and plural table names', () {
      expect(snakeCaseOf('OrderItem'), 'order_item');
      expect(tableNameOf('OrderItem'), 'order_items');
      expect(tableNameOf('Category'), 'categories');
      expect(tableNameOf('Box'), 'boxes');
    });
  });

  group('make:resource', () {
    test('scaffolds worm model, Beak columns and migration', () async {
      final int? code = await runner.run([
        'make:resource',
        'Widget',
        '--fields',
        'name:string,price:decimal,active:bool',
      ]);

      expect(code, 0);
      final String wormModel = read('lib/src/models/widget.dart');
      expect(wormModel, contains('final class Widget extends Model'));
      expect(
        wormModel,
        contains("String get tableName => Widget\$.tableName;"),
      );
      expect(wormModel, contains('static QueryBuilder<Widget> query()'));
      expect(wormModel, contains("static const String tableName = 'widgets';"));

      final String columns = read('lib/src/models/widget_columns.dart');
      expect(columns, contains('abstract final class WidgetColumns'));
      expect(columns, contains('final class WidgetModel extends BeakModel'));
      expect(columns, contains("String get table => 'widgets';"));
      expect(columns, contains("String get displayColumnKey => 'name';"));

      final String migration = read(
        'lib/src/migrations/create_widgets_table.dart',
      );
      expect(
        migration,
        contains("String get name => '20260703_120000_create_widgets_table';"),
      );
      expect(migration, contains("table.decimal('price');"));
      expect(out.toString(), contains('register the migration'));
    });

    test('rejects a lowercase resource name', () async {
      await expectLater(
        runner.run(['make:resource', 'widget']),
        throwsA(isA<UsageException>()),
      );
    });

    test('rejects malformed fields through usage errors', () async {
      await expectLater(
        runner.run(['make:resource', 'Widget', '--fields', 'name:blob']),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('narrow generators', () {
    test('make:model writes only the worm model', () async {
      await runner.run(['make:model', 'Gadget', '--fields', 'label:string']);
      expect(
        File('${root.path}/lib/src/models/gadget.dart').existsSync(),
        isTrue,
      );
      expect(
        File('${root.path}/lib/src/models/gadget_columns.dart').existsSync(),
        isFalse,
      );
    });

    test('make:columns writes only the Beak definition', () async {
      await runner.run(['make:columns', 'Gadget', '--fields', 'label:string']);
      expect(
        read('lib/src/models/gadget_columns.dart'),
        contains('GadgetModel'),
      );
    });

    test('make:migration writes only the migration', () async {
      await runner.run([
        'make:migration',
        'Gadget',
        '--fields',
        'label:string',
      ]);
      expect(
        read('lib/src/migrations/create_gadgets_table.dart'),
        contains('CreateGadgetsTable'),
      );
    });
  });

  group('doctor', () {
    test('a directory that is not a Dart project fails with the fix', () async {
      expect(await runner.run(['doctor']), 1);
      expect(out.toString(), contains('not a Dart project'));
      expect(out.toString(), contains('beak create'));
    });
  });

  group('entry point', () {
    test('misuse exits 64 with the usage message, not a stack trace', () async {
      final result = await Process.run(Platform.resolvedExecutable, const [
        'run',
        'bin/beak.dart',
        'make:model',
        'lowercase',
      ]);

      expect(result.exitCode, 64, reason: 'EX_USAGE for bad input');
      final String stderr = result.stderr.toString();
      expect(stderr, contains('UpperCamelCase'));
      expect(
        stderr,
        isNot(contains('Unhandled exception')),
        reason: 'the crafted usage message replaces the raw stack trace',
      );
    });
  });
}
