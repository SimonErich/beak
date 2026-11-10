import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/src/cli_runner.dart';
import 'package:beak_cli/src/serverpod/generate_issue.dart';
import 'package:beak_cli/src/serverpod/generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('beak-gen-labels-'));
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

  String generated() => File(
    p.join(root.path, 'generated/lib/src/models/product.dart'),
  ).readAsStringSync();

  void project({String labels = 'labels: {path: labels, template: de}'}) {
    write('pubspec.yaml', 'name: shop_admin\n');
    write('beak.yaml', '''
$labels
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
table: product_main
fields:
  id: UuidValue
  name: String
  status: ProductStatus
''');
    write('server/lib/src/product_status.spy.yaml', '''
enum: ProductStatus
serialized: byName
values:
  - draft
  - active
''');
    write(
      'server/migrations/0001/definition_project.json',
      jsonEncode({
        'tables': [
          {
            'name': 'product_main',
            'columns': [
              {'name': 'id', 'dartType': 'UuidValue?'},
              {'name': 'name', 'dartType': 'String?'},
              {'name': 'status', 'dartType': 'protocol:ProductStatus?'},
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
    write('labels/models_de.arb', '''
{
  "@@locale": "de",
  "*.id": "ID",
  "product": "{count, plural, one{Produkt} other{Produkte}}",
  "product.name": "Bezeichnung",
  "product.status": "Status",
  "productStatus.draft": "Entwurf",
  "productStatus.active": "Aktiv",
  "product.actions.archive": "Archivieren"
}''');
    write('labels/models_en.arb', '''
{
  "@@locale": "en",
  "*.id": "ID",
  "product": "{count, plural, one{Product} other{Products}}",
  "product.name": "Title",
  "product.status": "Status",
  "productStatus.draft": "Draft",
  "productStatus.active": "Active",
  "product.actions.archive": "Archive"
}''');
  }

  test('writes every language onto the generated model', () {
    project();
    final result = runServerpodGenerate(env());

    expect(result.warnings, isEmpty);
    final source = generated();
    expect(source, contains("label: 'Bezeichnung',"));
    expect(
      source,
      contains("translations: {'de': 'Bezeichnung', 'en': 'Title'},"),
    );
    expect(source, contains('valueTranslations: {'));
    expect(
      source,
      contains(
        "'de': {ProductStatus.draft: 'Entwurf', ProductStatus.active: 'Aktiv'}",
      ),
    );
    expect(
      source,
      contains(
        "'en': {ProductStatus.draft: 'Draft', ProductStatus.active: 'Active'}",
      ),
    );
    expect(source, contains('BeakModelLabels get labels'));
    expect(source, contains("one: {'de': 'Produkt', 'en': 'Product'},"));
    expect(
      source,
      contains("'archive': {'de': 'Archivieren', 'en': 'Archive'}"),
    );
    expect(runServerpodGenerate(env(), check: true).isSuccess, isTrue);
  });

  test('a changed label file makes --check fail', () {
    project();
    runServerpodGenerate(env());
    write('labels/models_en.arb', '''
{
  "@@locale": "en",
  "*.id": "ID",
  "product": "{count, plural, one{Product} other{Products}}",
  "product.name": "Name",
  "product.status": "Status",
  "productStatus.draft": "Draft",
  "productStatus.active": "Active",
  "product.actions.archive": "Archive"
}''');

    expect(runServerpodGenerate(env(), check: true).isSuccess, isFalse);
  });

  test('a typo in a key fails generation', () {
    project();
    write('labels/models_de.arb', '''
{"@@locale": "de", "product.nmae": "Bezeichnung"}''');
    File(p.join(root.path, 'labels/models_en.arb')).deleteSync();

    expect(
      () => runServerpodGenerate(env()),
      throwsA(
        isA<BeakGenerateException>().having(
          (error) => error.issues.map((issue) => issue.message).join(),
          'messages',
          contains('Did you mean "product.name"?'),
        ),
      ),
    );
  });

  test('without labels the generated labels stay as they were', () {
    project(labels: '');
    runServerpodGenerate(env());

    expect(generated(), contains("label: 'Name',"));
    expect(generated(), isNot(contains('translations:')));
  });
}
