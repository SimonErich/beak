import 'dart:convert';
import 'dart:io';

import 'package:beak_cli/src/schema/beak_schema_ir.dart';
import 'package:beak_cli/src/serverpod/database_definition.dart';
import 'package:beak_cli/src/serverpod/generate_issue.dart';
import 'package:beak_cli/src/serverpod/generate_settings.dart';
import 'package:beak_cli/src/serverpod/inventory_reader.dart';
import 'package:beak_cli/src/serverpod/serverpod_ir.dart';
import 'package:beak_cli/src/serverpod/spy_reader.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('beak-gen-'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String path, String source) {
    File(p.join(root.path, path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(source);
  }

  void database(List<Map<String, Object?>> tables) => write(
    'server/migrations/0001/definition_project.json',
    jsonEncode({'tables': tables}),
  );

  Map<String, Object?> table(
    String name,
    List<String> columns, {
    List<Map<String, Object?>> foreignKeys = const [],
    List<Map<String, Object?>> indexes = const [],
  }) => {
    'name': name,
    'columns': [
      for (final column in columns)
        {
          'name': column,
          'dartType':
              column.startsWith('id') ||
                  column.endsWith('Id') ||
                  column.startsWith('_')
              ? 'UuidValue?'
              : 'String?',
        },
    ],
    'foreignKeys': foreignKeys,
    'indexes': indexes,
  };

  const serverpod = BeakServerpodSettings(server: 'server');
  const settings = BeakGenerateSettings(
    output: 'generated',
    prefix: 'Shop',
    areas: {
      'catalog': BeakAreaRoles(read: ['readCatalog'], write: ['writeCatalog']),
    },
    writes: ['configuration', 'translation', 'menu', 'catalog'],
    conventions: BeakGenerateConventions(dateOnly: ['*Date']),
  );

  ServerpodIr generate() => buildServerpodIr(
    project: SpyReader(
      Directory(p.join(root.path, 'server')),
      serverpod,
    ).read(),
    database: DatabaseDefinition.read(
      Directory(p.join(root.path, 'server')),
      'migrations',
    ),
    inventory: readInventory(
      Directory(p.join(root.path, 'definitions')),
      settings,
    ),
    settings: settings,
  );

  test('a writable model needs a write binding, fields and an area', () {
    write(
      'server/lib/src/sample.spy.yaml',
      'class: Sample\ntable: sample\nfields:\n  id: UuidValue\n  title: String\n',
    );
    write(
      'definitions/catalog.yaml',
      'area: catalog\nresources:\n  Sample:\n    operations: [read, create]\n',
    );
    database([
      table('sample', ['id', 'title']),
    ]);

    expect(generate, throwsA(isA<BeakGenerateException>()));
  });

  test('inherited audit columns stay, secrets never enter the model', () {
    write('server/lib/src/base.spy.yaml', '''
class: Base
fields:
  createdAt: DateTime, default=now
  updatedAt: DateTime, default=now
  isDeleted: bool, default=false
  deletedAt: DateTime?
''');
    write('server/lib/src/sample.spy.yaml', '''
class: Sample
extends: Base
table: sample
fields:
  id: UuidValue
  title: String
  unitPriceInCents: int, default=0
  passwordToken: String?
  internalValue: String?, scope=serverOnly
  cacheKey: String?, scope=none
  presentationOnly: String?, !persist
''');
    write('definitions/catalog.yaml', '''
area: catalog
resources:
  Sample:
    display: title
    operations: [read, create, update]
    write: configuration
    writeFields: [title, unitPriceInCents]
''');
    database([
      table('sample', [
        'id',
        'createdAt',
        'updatedAt',
        'isDeleted',
        'deletedAt',
        'title',
        'unitPriceInCents',
        'passwordToken',
        'internalValue',
        'cacheKey',
        'presentationOnly',
      ]),
    ]);

    final model = generate().models.single;
    final names = {for (final column in model.schema.columns) column.fieldName};
    expect(names, containsAll(['createdAt', 'updatedAt', 'isDeleted']));
    expect(names, isNot(contains('passwordToken')));
    expect(names, isNot(contains('internalValue')));
    expect(names, isNot(contains('cacheKey')));
    expect(names, isNot(contains('presentationOnly')));
    expect(model.schema.createdAtColumnKey, 'createdAt');
    expect(model.admission.writable, ['title', 'unitPriceInCents']);
    final price = model.schema.columns.firstWhere(
      (column) => column.fieldName == 'unitPriceInCents',
    );
    expect(price.arguments['defaultValue'], '0');
  });

  test('named inverse relations keep their actual foreign key', () {
    write('server/lib/src/owner.spy.yaml', '''
class: Owner
table: owner
fields:
  id: UuidValue
  title: String
  children: List<Child>?, relation(name=owner_children)
''');
    write('server/lib/src/child.spy.yaml', '''
class: Child
table: child
fields:
  id: UuidValue
  title: String
  ownerRefId: UuidValue
  owner: Owner?, relation(name=owner_children, field=ownerRefId, onDelete=Cascade)
''');
    write(
      'definitions/catalog.yaml',
      'area: catalog\nresources:\n  Owner: {reason: Closed.}\n  Child: {reason: Closed.}\n',
    );
    database([
      table('owner', ['id', 'title']),
      table('child', ['id', 'title', 'ownerRefId']),
    ]);

    final ir = generate();
    final owner = ir.models.firstWhere((m) => m.schema.className == 'Owner');
    final child = ir.models.firstWhere((m) => m.schema.className == 'Child');
    expect(owner.schema.relations.single.foreignKey, 'ownerRefId');
    expect(child.schema.relations.single.foreignKey, 'ownerRefId');
    expect(child.schema.relations.single.kind, BeakRelationKind.belongsTo);
  });

  test('a one-sided has-many takes the shadow key from the migration', () {
    write('server/lib/src/parent.spy.yaml', '''
class: Parent
table: parent_main
fields:
  id: UuidValue
  name: String
  variants: List<Variant>?, relation
''');
    write('server/lib/src/variant.spy.yaml', '''
class: Variant
table: variant
fields:
  id: UuidValue
  name: String
''');
    write(
      'definitions/catalog.yaml',
      'area: catalog\nresources:\n  Parent: {reason: Closed.}\n  Variant: {reason: Closed.}\n',
    );
    database([
      table('parent_main', ['id', 'name']),
      table(
        'variant',
        ['id', 'name', '_parentMainVariantsParentMainId'],
        foreignKeys: [
          {
            'referenceTable': 'parent_main',
            'columns': ['_parentMainVariantsParentMainId'],
          },
        ],
      ),
    ]);

    final ir = generate();
    final variant = ir.models.firstWhere(
      (m) => m.schema.className == 'Variant',
    );
    expect(
      variant.schema.columns.map((column) => column.columnKey),
      contains('_parentMainVariantsParentMainId'),
    );
  });

  test('an external module reference stays a scalar foreign key', () {
    write('server/lib/src/account.spy.yaml', '''
class: Account
table: account
fields:
  id: UuidValue
  firstName: String?
  authUser: module:serverpod_auth_core:AuthUser?, relation(onDelete=Cascade)
''');
    write(
      'definitions/catalog.yaml',
      'area: catalog\nresources:\n  Account: {reason: Closed.}\n',
    );
    database([
      table('account', ['id', 'firstName', 'authUserId']),
    ]);

    final model = generate().models.single;
    final names = {for (final column in model.schema.columns) column.fieldName};
    expect(names, contains('authUserId'));
    expect(model.schema.relations, isEmpty);
  });

  test('enum wire names and properties come from the single source', () {
    write('server/lib/src/state.spy.yaml', '''
enum: State
properties:
  description: String
values:
  - ready:
      description: Ready to serve
  - done:
      description: Finished
''');
    write('server/lib/src/sample.spy.yaml', '''
class: Sample
table: sample
fields:
  id: UuidValue
  state: State, default=ready
''');
    write(
      'definitions/catalog.yaml',
      'area: catalog\nresources:\n  Sample: {reason: Closed.}\n',
    );
    database([
      table('sample', ['id', 'state']),
    ]);

    final ir = generate();
    final state = ir.enums.single;
    expect(state.name, 'State');
    expect(state.values.first.name, 'ready');
    expect(state.values.first.properties, ["'Ready to serve'"]);
    expect(state.properties, {'description': 'String'});
  });

  test('a new source field stays unwritable and an unknown review fails', () {
    write('server/lib/src/sample.spy.yaml', '''
class: Sample
table: sample
fields:
  id: UuidValue
  title: String
  serverCounter: int, default=0
''');
    write('definitions/catalog.yaml', '''
area: catalog
resources:
  Sample:
    operations: [read, create]
    write: configuration
    writeFields: [title]
''');
    database([
      table('sample', ['id', 'title', 'serverCounter']),
    ]);

    final model = generate().models.single;
    expect(model.admission.writable, ['title']);

    write('definitions/catalog.yaml', '''
area: catalog
resources:
  Sample:
    operations: [read, create]
    write: configuration
    writeFields: [misspelled]
''');
    expect(generate, throwsA(isA<BeakGenerateException>()));
  });

  test('a translation table detects its restore key from the unique index', () {
    write('server/lib/src/product.spy.yaml', '''
class: Product
table: product
fields:
  id: UuidValue
  name: String
  translations: List<ProductTranslation>?, relation
''');
    write('server/lib/src/product_translation.spy.yaml', '''
class: ProductTranslation
table: product_translation
fields:
  id: UuidValue
  locale: String
  name: String
''');
    write('definitions/catalog.yaml', '''
area: catalog
resources:
  Product: {operations: [read], reason: Closed.}
  ProductTranslation:
    operations: [read, update]
    write: translation
    writeFields: [name]
''');
    database([
      table('product', ['id', 'name']),
      table(
        'product_translation',
        ['id', 'locale', 'name', '_productTranslationsProductId'],
        indexes: [
          {
            'indexName': 'product_translation_locale',
            'isUnique': true,
            'elements': [
              {'definition': '_productTranslationsProductId'},
              {'definition': 'locale'},
            ],
          },
        ],
      ),
    ]);

    final model = generate().models.firstWhere(
      (m) => m.schema.className == 'ProductTranslation',
    );
    expect(model.admission.restoreKey, isNotEmpty);
    expect(model.admission.translationOwner, isNotNull);
    expect(model.admission.translationLocale, 'locale');
  });
}
