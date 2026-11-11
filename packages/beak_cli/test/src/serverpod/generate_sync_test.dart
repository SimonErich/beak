import 'dart:io';

import 'package:beak_cli/src/serverpod/generate_issue.dart';
import 'package:beak_cli/src/serverpod/generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'serverpod_fixture.dart';

void main() {
  late ServerpodFixture fixture;

  setUp(() => fixture = ServerpodFixture());
  tearDown(() => fixture.delete());

  void product({String? handlers, String annotation = ''}) {
    fixture
      ..project(handlers: handlers)
      ..model('product', '''
class: Product
table: product
fields:
  id: UuidValue
  name: String
''')
      ..database([
        ServerpodFixture.table('product', ['id', 'name']),
      ])
      ..define('catalog/product', '''
@Resource()
${annotation.isEmpty ? "@ServerpodAdminModel(area: 'catalog', reason: 'Closed.')" : annotation}
final class Product extends BeakSchema {
  @Display()
  late final String name;
}''', writes: annotation.isNotEmpty);
  }

  test('writes the part and models.dart, passes --check, drops an orphan', () {
    product();
    final first = fixture.env();
    expect(runServerpodGenerate(first).written, isNotEmpty);
    expect(
      fixture.read(
        'definitions/lib/src/generated/models/catalog/product.beak.dart',
      ),
      startsWith(
        "${beakGeneratedHeader}\n\npart of 'package:shop_definitions/src/catalog/product.dart';",
      ),
    );
    final models = fixture.read('definitions/lib/src/generated/models.dart');
    expect(models, contains("export 'package:shop_definitions/src/catalog/"));
    expect(models, contains('BeakModelRegistry createShopRegistry() =>'));
    expect(runServerpodGenerate(fixture.env(), check: true).isSuccess, isTrue);

    fixture.write(
      'definitions/lib/src/generated/models/catalog/old.beak.dart',
      '$beakGeneratedHeader\n// stale\n',
    );
    final check = runServerpodGenerate(fixture.env(), check: true);
    expect(check.isSuccess, isFalse);
    expect(check.problems.single, contains('orphan'));

    runServerpodGenerate(fixture.env());
    expect(
      fixture.exists(
        'definitions/lib/src/generated/models/catalog/old.beak.dart',
      ),
      isFalse,
    );
  });

  test('a changed definition class makes --check fail', () {
    product();
    runServerpodGenerate(fixture.env());
    final path = p.join(
      fixture.root.path,
      'definitions/lib/src/catalog/product.dart',
    );
    File(path).writeAsStringSync(
      File(path).readAsStringSync().replaceFirst("'Closed.'", "'Shut.'"),
    );

    expect(runServerpodGenerate(fixture.env(), check: true).isSuccess, isFalse);
  });

  test('refuses to delete a file it did not write', () {
    product();
    runServerpodGenerate(fixture.env());
    fixture.write('definitions/lib/src/generated/authored.dart', '// mine\n');

    final result = runServerpodGenerate(fixture.env());
    expect(result.problems.single, contains('is not generated'));
    expect(
      fixture.exists('definitions/lib/src/generated/authored.dart'),
      isTrue,
    );
  });

  test('names the missing part and write import', () {
    product(annotation: "@ServerpodAdminModel.editable(area: 'catalog')");
    fixture.write(
      'definitions/lib/src/catalog/product.dart',
      fixture
          .read('definitions/lib/src/catalog/product.dart')
          .replaceFirst(
            "part '../generated/models/catalog/product.beak.dart';",
            '',
          )
          .replaceFirst(
            "import 'package:shop_definitions/src/generated/definitions_support.dart';",
            '',
          ),
    );

    expect(
      () => runServerpodGenerate(fixture.env()),
      throwsA(
        isA<BeakGenerateException>().having(
          (error) => error.issues.map((issue) => issue.message).toList(),
          'messages',
          containsAll([
            contains(
              "add `part '../generated/models/catalog/product.beak.dart';`",
            ),
            contains(
              "add `import 'package:shop_definitions/src/generated/definitions_support.dart';`",
            ),
          ]),
        ),
      ),
    );
  });

  test('emits one support library that exports enums and writes', () {
    fixture
      ..project()
      ..model('status', '''
enum: Status
values:
  - draft
  - active
''')
      ..model('product', '''
class: Product
table: product
fields:
  id: UuidValue
  status: Status
''')
      ..database([
        ServerpodFixture.table(
          'product',
          ['id', 'status'],
          types: {'status': 'protocol:Status?'},
        ),
      ])
      ..define('catalog/product', '''
@Resource()
@ServerpodAdminModel.editable(area: 'catalog')
final class Product extends BeakSchema {
  late final Status status;
}''', writes: true);

    runServerpodGenerate(fixture.env());

    final support = fixture.read(
      'definitions/lib/src/generated/definitions_support.dart',
    );
    expect(support, contains("export 'enums.dart';"));
    expect(support, contains("export 'writes.dart';"));
  });

  test('custom code needs generate.handlers', () {
    product(
      annotation:
          "@ServerpodAdminModel(area: 'catalog', create: BeakHandling.custom)",
    );

    expect(
      () => runServerpodGenerate(fixture.env()),
      throwsA(
        isA<BeakGenerateException>().having(
          (error) => error.issues.single.message,
          'message',
          contains('needs generate.handlers'),
        ),
      ),
    );
  });

  test('writes a handler base per custom model and the aggregate', () {
    product(
      handlers: 'server/lib/src/admin',
      annotation:
          "@ServerpodAdminModel(area: 'catalog', create: BeakHandling.custom, "
          "update: BeakHandling.derived, commands: [BeakCommand('archive')])",
    );
    runServerpodGenerate(fixture.env());

    final handler = fixture.read('server/lib/src/admin/product_handler.dart');
    expect(handler, contains('abstract base class ProductHandler {'));
    expect(handler, contains('Future<Object?> create(ProductWrite write);'));
    expect(
      handler,
      contains('FutureOr<BeakRecord?> derive(ProductWrite write);'),
    );
    expect(handler, contains('Future<Object?> archive(ProductWrite write);'));
    expect(handler, contains("'archive': (context) => archive("));
    expect(handler, contains('String get name =>'));
    expect(handler, contains('UuidValue get id =>'));
    expect(handler, contains('laid over an update before it is saved'));
    expect(
      handler,
      contains('context.operation.kind == BeakSaveOperationKind.update'),
    );

    final aggregate = fixture.read('server/lib/src/admin/shop_handlers.dart');
    expect(aggregate, contains('required this.product'));
    expect(
      aggregate,
      contains("import 'package:shop_server/src/admin/product_handler.dart';"),
    );
    expect(aggregate, contains('admin.ShopWrite.product => product.writes,'));
    expect(runServerpodGenerate(fixture.env(), check: true).isSuccess, isTrue);
  });

  test('a command with an input exposes it as a typed write', () {
    fixture
      ..project(handlers: 'server/lib/src/admin')
      ..model('product', '''
class: Product
table: product
fields:
  id: UuidValue
  name: String
''')
      ..database([
        ServerpodFixture.table('product', ['id', 'name']),
      ])
      ..define('catalog/role_command', '''
@Resource()
@CommandInput()
final class RoleCommand extends BeakSchema {
  late final String roleId;
}''')
      ..define('catalog/product', '''
@Resource()
@ServerpodAdminModel(
  area: 'catalog',
  commands: [BeakCommand('assign', input: RoleCommand)],
)
final class Product extends BeakSchema {
  late final String name;
}''', writes: true);

    runServerpodGenerate(fixture.env());

    final handler = fixture.read('server/lib/src/admin/product_handler.dart');
    expect(handler, contains('extension type RoleCommandWrite'));
    expect(handler, contains('RoleCommandValues get input'));
    expect(
      handler,
      contains('Future<Object?> assign(RoleCommandWrite write);'),
    );
  });

  test('emits a translation display and its relation resolver', () {
    fixture
      ..project()
      ..model('category', '''
class: Category
table: category
fields:
  id: UuidValue
  translations: List<CategoryTranslation>?, relation
''')
      ..model('category_translation', '''
class: CategoryTranslation
table: category_translation
fields:
  id: UuidValue
  locale: String
  name: String
''')
      ..model('product', '''
class: Product
table: product
fields:
  id: UuidValue
  category: Category?, relation(field=categoryId)
''')
      ..database([
        ServerpodFixture.table('category', ['id']),
        ServerpodFixture.table('category_translation', [
          'id',
          'locale',
          'name',
          '_categoryTranslationsCategoryId',
        ]),
        ServerpodFixture.table('product', ['id', 'categoryId']),
      ])
      ..define(
        'catalog/category',
        '''
@Resource()
@ServerpodAdminModel(area: 'catalog', reason: 'Closed.')
final class Category extends BeakSchema {
  @Display()
  @HasMany(owned: true)
  late final List<CategoryTranslation> translations;
}''',
        imports: [
          'package:shop_definitions/src/catalog/category_translation.dart',
        ],
      )
      ..define('catalog/category_translation', '''
@Resource()
@ServerpodAdminModel(area: 'catalog', reason: 'Closed.')
final class CategoryTranslation extends BeakSchema {
  late final String locale;

  @Display()
  late final String name;
}''')
      ..define(
        'catalog/product',
        '''
@Resource()
@ServerpodAdminModel(area: 'catalog', reason: 'Closed.')
final class Product extends BeakSchema {
  @BelongsTo()
  late final Category? category;
}''',
        imports: ['package:shop_definitions/src/catalog/category.dart'],
      );

    runServerpodGenerate(fixture.env());

    final part = fixture.read(
      'definitions/lib/src/generated/models/catalog/category.beak.dart',
    );
    expect(part, contains('BeakTranslationDisplay? get translationDisplay'));
    final product = fixture.read(
      'definitions/lib/src/generated/models/catalog/product.beak.dart',
    );
    expect(
      product,
      contains('displayTranslation: const BeakTranslationDisplay('),
    );
  });

  test('a stock-only project gets a handler aggregate without arguments', () {
    product(
      handlers: 'server/lib/src/admin',
      annotation: "@ServerpodAdminModel.editable(area: 'catalog')",
    );
    runServerpodGenerate(fixture.env());

    final aggregate = fixture.read('server/lib/src/admin/shop_handlers.dart');
    expect(aggregate, contains('const ShopHandlers();'));
    expect(
      aggregate,
      contains('admin.ShopWrite.product => const BeakWriteHandler.stock(),'),
    );
    expect(
      fixture.exists('server/lib/src/admin/product_handler.dart'),
      isFalse,
    );
  });
}
