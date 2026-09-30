import 'dart:io';

import 'package:args/command_runner.dart';
import '../support/beak_cli_internals.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late StringBuffer out;
  late Map<(String, int), bool> reachable;
  late CommandRunner<int> runner;

  setUp(() {
    root = Directory.systemTemp.createTempSync('beak_cli_test');
    addTearDown(() => root.deleteSync(recursive: true));
    File(
      '${root.path}/pubspec.yaml',
    ).writeAsStringSync('name: shop\ndependencies:\n  beak: any\n');
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

    test('accepts double for the floating-point number and float as its '
        'alias', () {
      expect(BeakFieldKind.parse('double'), BeakFieldKind.floating);
      expect(BeakFieldKind.parse('float'), BeakFieldKind.floating);
      expect(BeakFieldKind.parse('decimal'), BeakFieldKind.decimal);
    });

    test('names every kind in the message for an unknown one', () {
      expect(
        () => BeakFieldSpec.parse('name:blob'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('string, text, int, decimal, double, bool, datetime'),
              isNot(contains('\u2014')),
            ),
          ),
        ),
      );
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
    test('scaffolds one annotated schema class, and prepares it', () async {
      // It used to write a worm Model and an old-style columns class that
      // the schema reader could not see, then print "run beak prepare".
      final int? code = await runner.run([
        'make:resource',
        'Widget',
        '--fields',
        'name:string!,price:decimal!,active:bool',
      ]);

      expect(code, 0);
      final String source = read('lib/resources/widgets/models/widget.dart');
      expect(source, contains('@Resource(timestamps: true)'));
      expect(source, contains('final class Widget extends BeakSchema'));
      expect(source, contains("part 'widget.beak.dart';"));
      expect(source, contains('late final String name;'));
      expect(source, contains('late final BeakDecimal price;'));
      expect(source, contains('late final bool? active;'));
    });

    test('refuses a name the generated code needs for something else, and '
        'writes nothing', () async {
      // `beak make:resource List` wrote a class that made every file around it
      // fail to compile, and then said prepare had run.
      for (final name in [
        'List',
        'Resource',
        'Schema',
        'Migration',
        'String',
      ]) {
        await expectLater(
          runner.run(['make:resource', name]),
          throwsA(
            isA<UsageException>().having(
              (error) => error.message,
              'message',
              allOf(contains('"$name"'), contains('generated')),
            ),
          ),
          reason: name,
        );
      }
      expect(Directory('${root.path}/lib').existsSync(), isFalse);
    });

    test('decimal is exact, and double is the floating-point number', () async {
      // `price:decimal` used to write a `double`, which cannot add up a
      // ledger; the docs told everyone to change it afterwards.
      await runner.run([
        'make:resource',
        'Gauge',
        '--fields',
        'name:string!,reading:double,cost:decimal!',
      ]);

      final String source = read('lib/resources/gauges/models/gauge.dart');
      expect(source, contains('late final double? reading;'));
      expect(source, contains('late final BeakDecimal cost;'));
      final (schemas, issues) = BeakSchemaReader(root).read();
      expect(issues, isEmpty);
      final BeakColumnIr cost = schemas.single.columns.firstWhere(
        (column) => column.fieldName == 'cost',
      );
      expect(cost.declaredValueType, 'BeakDecimal');
    });

    test('the scaffold is what the schema reader reads', () async {
      // The whole point: one authoring surface, not two that disagree.
      await runner.run(['make:resource', 'Widget', '--fields', 'name:string!']);

      final (schemas, issues) = BeakSchemaReader(root).read();

      expect(issues, isEmpty);
      expect(schemas.single.className, 'Widget');
      expect(schemas.single.table, 'widgets');
      // Plus the primary key and the timestamps the annotation asked for.
      expect(
        schemas.single.columns.map((c) => c.fieldName),
        containsAll(<String>['name', 'id']),
      );
    });

    test('prepare runs, so the part file and migration exist', () async {
      await runner.run(['make:resource', 'Widget', '--fields', 'name:string!']);

      expect(
        File(
          '${root.path}/lib/resources/widgets/models/widget.beak.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '${root.path}/lib/migrations/create_widgets_table.dart',
        ).existsSync(),
        isTrue,
      );
    });

    test('nullability decides required-ness, marked with a trailing !', () {
      final required = BeakFieldSpec.parse('name:string!');
      final optional = BeakFieldSpec.parse('note:text');

      expect(required.isRequired, isTrue);
      expect(optional.isRequired, isFalse);
    });

    test('with no fields it scaffolds a display column to edit', () async {
      await runner.run(['make:resource', 'Widget']);

      final String source = read('lib/resources/widgets/models/widget.dart');
      expect(source, contains('@Display()'));
      expect(source, contains('late final String name;'));
    });

    test('writes a resource class beside the schema folder', () async {
      await runner.run([
        'make:resource',
        'OrderItem',
        '--fields',
        'sku:string!',
      ]);

      final String source = read(
        'lib/resources/order_items/order_item_resource.dart',
      );
      expect(
        source,
        contains('final class OrderItemResource extends BeakResource'),
      );
      expect(source, contains("import 'models/order_item.dart';"));
      expect(source, contains('model: const OrderItemModel()'));
      expect(source, contains('`beak prepare` finds this class'));
    });

    test('prepare picks the class up for the generated panel', () async {
      await runner.run(['make:resource', 'Widget', '--fields', 'name:string!']);

      expect(read('lib/beak/panel.g.dart'), contains('WidgetResource()'));
      expect(out.toString(), contains('1 resource class'));
    });

    test('in an authored project, prints the line to register it', () async {
      File('${root.path}/lib/main.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');

      await runner.run(['make:resource', 'Widget', '--fields', 'name:string!']);

      final String printed = out.toString();
      expect(printed, contains('lib/main.dart'));
      expect(
        printed,
        contains("import 'resources/widgets/widget_resource.dart';"),
      );
      expect(printed, contains('WidgetResource(),'));
      final String source = read('lib/resources/widgets/widget_resource.dart');
      expect(source, contains('`resources: [...]` list in `lib/main.dart`'));
      expect(source, isNot(contains('`beak prepare` finds this class')));
    });

    test('a generated entrypoint needs no registration hint', () async {
      await runner.run(['make:resource', 'Widget', '--fields', 'name:string!']);

      expect(out.toString(), isNot(contains('BeakPanel(resources:')));
    });

    test('refuses to overwrite a schema that already exists', () async {
      File('${root.path}/lib/resources/widgets/models/widget.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// mine\n');

      expect(await runner.run(['make:resource', 'Widget']), 1);
      expect(read('lib/resources/widgets/models/widget.dart'), '// mine\n');
      expect(out.toString(), contains('already exists'));
    });
  });

  group('make:migration', () {
    test('scaffolds an empty, correctly-named migration', () async {
      // `prepare` writes the create-table migration; this is for the changes
      // it cannot derive — an alter, a backfill.
      expect(await runner.run(['make:migration', 'AddStatusToProducts']), 0);

      final String source = read('lib/migrations/add_status_to_products.dart');
      expect(source, contains('class AddStatusToProducts extends Migration'));
      expect(
        source,
        contains("String get name => '20260703_120000_add_status_to_products'"),
      );
      expect(source, contains('Future<void> upSchema(Schema schema)'));
      expect(source, contains('Future<void> downSchema(Schema schema)'));
    });

    test('refuses to overwrite a migration of the same name', () async {
      // A migration is edited by hand as soon as it is written, so a second
      // run of the same command used to throw that work away.
      File('${root.path}/lib/migrations/add_status.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('// mine, and already edited\n');

      expect(await runner.run(['make:migration', 'AddStatus']), 1);

      expect(
        read('lib/migrations/add_status.dart'),
        '// mine, and already edited\n',
      );
      expect(
        out.toString(),
        contains('lib/migrations/add_status.dart already exists'),
      );
      expect(out.toString(), contains('--force'));
    });

    test('replaces it with --force', () async {
      File('${root.path}/lib/migrations/add_status.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('// mine\n');

      expect(await runner.run(['make:migration', 'AddStatus', '--force']), 0);

      expect(
        read('lib/migrations/add_status.dart'),
        contains('class AddStatus extends Migration'),
      );
    });

    test('rejects a name that is not UpperCamelCase', () {
      expect(
        runner.run(['make:migration', 'add_status']),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('writeFile', () {
    late BeakCliEnvironment environment;

    setUp(
      () => environment = BeakCliEnvironment(
        out: out,
        rootDirectory: root,
        now: () => DateTime.utc(2026),
        probe: (host, port) async => false,
      ),
    );

    test('resolves a relative path under the project root', () {
      environment.writeFile('lib/models/note.dart', 'const int x = 1;');

      expect(File('${root.path}/lib/models/note.dart').existsSync(), isTrue);
    });

    test('writes an absolute path where it says, not under the root', () {
      // `beak introspect --out /somewhere/else` used to land in
      // `<project>/somewhere/else`, which is a silently wrong answer.
      final elsewhere = Directory.systemTemp.createTempSync('beak_absolute');
      addTearDown(() => elsewhere.deleteSync(recursive: true));
      final target = '${elsewhere.path}/models/note.dart';

      environment.writeFile(target, 'const int x = 1;');

      expect(File(target).existsSync(), isTrue);
      expect(Directory('${root.path}${elsewhere.path}').existsSync(), isFalse);
    });

    test('creates missing parent directories', () {
      environment.writeFile('a/b/c/deep.txt', 'hello');

      expect(File('${root.path}/a/b/c/deep.txt').readAsStringSync(), 'hello');
    });

    test('formats Dart output but leaves other files byte-for-byte', () {
      environment
        ..writeFile('ugly.dart', 'const int   x=1;')
        ..writeFile('ugly.txt', 'const int   x=1;');

      expect(read('ugly.dart'), 'const int x = 1;\n');
      expect(read('ugly.txt'), 'const int   x=1;');
    });
  });

  group('pluralisation', () {
    test('the migration class agrees with the table it creates', () async {
      // `CreateCategorysTable` beside a `categories` table was the tell that
      // two pluralisers were in play.
      await runner.run([
        'make:resource',
        'Category',
        '--fields',
        'name:string!',
      ]);

      final source = read('lib/migrations/create_categories_table.dart');
      expect(source, contains('class CreateCategoriesTable'));
      expect(source, contains("schema.create('categories'"));
      expect(source, isNot(contains('Categorys')));
    });

    test('handles the s/x/ch and y endings the table name does', () {
      expect(pluralOf('Box'), 'Boxes');
      expect(pluralOf('Class'), 'Classes');
      expect(pluralOf('Batch'), 'Batches');
      expect(pluralOf('Category'), 'Categories');
      expect(pluralOf('Product'), 'Products');
    });
  });

  group('formatting', () {
    test('every scaffolded Dart file is already formatted', () async {
      // A scaffold that needs `dart format` afterwards hands the user a diff
      // they did not write, and breaks a --set-exit-if-changed gate.
      await runner.run([
        'make:resource',
        'Invoice',
        '--fields',
        'number:string,total:decimal,paid:bool',
      ]);

      final generated = Directory(root.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      expect(generated, isNotEmpty);
      for (final file in generated) {
        final String source = file.readAsStringSync();
        expect(
          BeakEmitters.format(source),
          source,
          reason: '${file.path} is not formatted',
        );
      }
    });
  });

  group('doctor', () {
    test('a directory that is not a Dart project fails with the fix', () async {
      File('${root.path}/pubspec.yaml').deleteSync();

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
        'make:resource',
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
