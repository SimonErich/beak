import 'dart:io';

import 'package:beak_cli/src/cli_runner.dart';
import 'package:beak_cli/src/serverpod/generate_issue.dart';
import 'package:beak_cli/src/serverpod/generator.dart';
import 'package:test/test.dart';

import '../serverpod/serverpod_fixture.dart';

void main() {
  late ServerpodFixture fixture;

  setUp(() => fixture = ServerpodFixture());
  tearDown(() => fixture.delete());

  BeakCliEnvironment env() => fixture.env();

  void write(String path, String source) => fixture.write(path, source);

  String generated() => fixture.read(
    'definitions/lib/src/generated/models/catalog/product.beak.dart',
  );

  void project({String labels = 'labels: {path: labels, template: de}'}) {
    fixture
      ..project(labels: labels)
      ..model('product', '''
class: Product
table: product_main
fields:
  id: UuidValue
  name: String
  status: ProductStatus
''')
      ..model('product_status', '''
enum: ProductStatus
serialized: byName
values:
  - draft
  - active
''')
      ..database([
        ServerpodFixture.table(
          'product_main',
          ['id', 'name', 'status'],
          types: {'status': 'protocol:ProductStatus?'},
        ),
      ])
      ..define(
        'catalog/product',
        '''
@Resource()
@ServerpodAdminModel(area: 'catalog', reason: 'Closed.')
final class Product extends BeakSchema {
  late final String name;

  late final ProductStatus status;
}''',
        imports: ['package:shop_definitions/src/generated/enums.dart'],
      );
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
    File('${fixture.root.path}/labels/models_en.arb').deleteSync();

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
