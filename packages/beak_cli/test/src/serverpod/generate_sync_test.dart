import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/src/cli_runner.dart';
import 'package:beak_cli/src/serverpod/generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('beak-sync-'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, String source) {
    File(p.join(root.path, path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source);
  }

  BeakCliEnvironment env() => BeakCliEnvironment(
    out: StringBuffer(),
    rootDirectory: root,
    now: () => DateTime.utc(2026),
    probe: (host, port) async => false,
  );

  void project() {
    write('pubspec.yaml', 'name: shop_admin\n');
    write('beak.yaml', '''
serverpod:
  server: server
  models: [lib/src]
  migrations: migrations
generate:
  output: generated
  inventory: definitions
  prefix: Shop
  areas:
    catalog: {read: readCatalog, write: writeCatalog}
  writes: [configuration]
''');
    write('generated/pubspec.yaml', 'name: shop_generated\n');
    write('server/lib/src/product.spy.yaml', '''
class: Product
table: product
fields:
  id: UuidValue
  name: String
''');
    write(
      'server/migrations/0001/definition_project.json',
      jsonEncode({
        'tables': [
          {
            'name': 'product',
            'columns': [
              {'name': 'id', 'dartType': 'UuidValue?'},
              {'name': 'name', 'dartType': 'String?'},
            ],
          },
        ],
      }),
    );
    write('definitions/catalog.yaml', '''
area: catalog
resources:
  Product: {operations: [read], reason: Closed.}
''');
  }

  test('writes the package, passes --check, and removes an orphan', () {
    project();
    final first = runServerpodGenerate(env());
    expect(first.written, isNotEmpty);
    expect(
      File(p.join(root.path, 'generated/lib/shop_generated.dart')).existsSync(),
      isTrue,
    );
    expect(runServerpodGenerate(env(), check: true).isSuccess, isTrue);

    final orphan = File(p.join(root.path, 'generated/lib/src/old.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('$beakGeneratedHeader\n// stale\n');
    final check = runServerpodGenerate(env(), check: true);
    expect(check.isSuccess, isFalse);
    expect(check.problems.single, contains('orphan'));

    runServerpodGenerate(env());
    expect(orphan.existsSync(), isFalse);
  });

  test('refuses to delete a file it did not generate', () {
    project();
    runServerpodGenerate(env());
    File(
      p.join(root.path, 'generated/lib/src/authored.dart'),
    ).writeAsStringSync('// mine\n');
    expect(() => runServerpodGenerate(env()), returnsNormally);
    expect(
      File(p.join(root.path, 'generated/lib/src/authored.dart')).existsSync(),
      isTrue,
    );
  });
}
