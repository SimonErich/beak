import 'package:beak_cli/src/schema/beak_schema_ir.dart';
import 'package:beak_cli/src/serverpod/generate_issue.dart';
import 'package:test/test.dart';

import 'serverpod_fixture.dart';

void main() {
  late ServerpodFixture fixture;

  setUp(() => fixture = ServerpodFixture());
  tearDown(() => fixture.delete());

  Matcher failsWith(String text) => throwsA(
    isA<BeakGenerateException>().having(
      (error) => error.issues.map((issue) => issue.message).join('\n'),
      'messages',
      contains(text),
    ),
  );

  void sample(String fields) {
    fixture
      ..model('sample', '''
class: Sample
table: sample
fields:
  id: UuidValue
$fields
''')
      ..database([
        ServerpodFixture.table(
          'sample',
          [
            'id',
            for (final line in fields.trim().split('\n'))
              line.trim().split(':').first,
          ],
          types: {'version': 'int?', 'count': 'int?'},
        ),
      ]);
  }

  test('a writable model needs an area or roles', () {
    sample('  title: String');
    fixture.define('sample', '''
@Resource()
@ServerpodModel(create: BeakHandling.stock)
final class Sample extends BeakSchema {
  late final String title;
}''');

    expect(fixture.ir, failsWith('opens writes but names no area'));
  });

  test('a read-only model says why', () {
    sample('  title: String');
    fixture.define('sample', '''
@Resource()
@ServerpodModel(area: 'catalog')
final class Sample extends BeakSchema {
  late final String title;
}''');

    expect(fixture.ir, failsWith('@ServerpodModel(reason:) says why'));
  });

  test('audit columns stay, undeclared fields and secrets never enter', () {
    fixture
      ..model('base', '''
class: Base
fields:
  createdAt: DateTime, default=now
  updatedAt: DateTime, default=now
  isDeleted: bool, default=false
  deletedAt: DateTime?
''')
      ..model('sample', '''
class: Sample
extends: Base
table: sample
fields:
  id: UuidValue
  title: String
  unitPriceInCents: int, default=0
  passwordToken: String?
  internalNote: String?
''')
      ..database([
        ServerpodFixture.table('sample', [
          'id',
          'createdAt',
          'updatedAt',
          'isDeleted',
          'deletedAt',
          'title',
          'unitPriceInCents',
          'passwordToken',
          'internalNote',
        ]),
      ])
      ..define('sample', '''
@Resource()
@ServerpodModel(
  area: 'catalog',
  create: BeakHandling.stock,
  update: BeakHandling.stock,
)
final class Sample extends BeakSchema {
  @Display()
  late final String title;

  late final int unitPriceInCents;
}''', writes: true);

    final model = fixture.ir().models.single;
    final names = {for (final column in model.schema.columns) column.fieldName};
    expect(names, containsAll(['createdAt', 'updatedAt', 'isDeleted']));
    expect(names, isNot(contains('passwordToken')));
    expect(names, isNot(contains('internalNote')));
    expect(model.schema.softDeletes, isTrue);
    expect(model.schema.displayColumnKey, 'title');
    expect(model.admission.writable, ['title', 'unitPriceInCents']);
    expect(model.admission.writeValue, 'ShopWrite.sample');
    final price = model.schema.columns.firstWhere(
      (column) => column.fieldName == 'unitPriceInCents',
    );
    expect(price.arguments['defaultValue'], '0');
  });

  test('a declared secret is refused', () {
    sample('  passwordToken: String?');
    fixture.define('sample', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Sample extends BeakSchema {
  late final String? passwordToken;
}''');

    expect(fixture.ir, failsWith('looks like a secret'));
  });

  test('a declared field must exist with its Serverpod type and `?`', () {
    sample('  title: String\n  count: int');
    fixture.define('sample', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Sample extends BeakSchema {
  late final String? title;
  late final String count;
  late final String misspelled;
}''');

    expect(
      fixture.ir,
      throwsA(
        isA<BeakGenerateException>().having(
          (error) => error.issues.map((issue) => issue.message).toList(),
          'messages',
          containsAll([
            contains('Sample.title is not nullable in Serverpod'),
            contains('Sample.count is declared `String`'),
            contains('Sample.misspelled is not a field'),
          ]),
        ),
      ),
    );
  });

  test('a scalar foreign key keeps the relation\'s nullability', () {
    fixture
      ..model('account', '''
class: Account
table: account
fields:
  id: UuidValue
  authUser: module:serverpod_auth_core:AuthUser?, relation(onDelete=Cascade)
''')
      ..database([
        ServerpodFixture.table('account', ['id', 'authUserId']),
      ])
      ..define('account', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Account extends BeakSchema {
  late final String authUserId;
}''');

    expect(fixture.ir, failsWith('authUserId is nullable in Serverpod'));
  });

  test('a stock create needs every required field', () {
    sample('  title: String\n  code: String');
    fixture.define('sample', '''
@Resource()
@ServerpodModel(area: 'catalog', create: BeakHandling.stock)
final class Sample extends BeakSchema {
  late final String title;
}''', writes: true);

    expect(fixture.ir, failsWith('required Serverpod field "code"'));
  });

  test('@ReadOnly, @Hidden and @Column shape admission and columns', () {
    sample('  title: String\n  version: int, default=1\n  locks: List<String>');
    fixture.define('sample', '''
@Resource()
@ServerpodModel(
  area: 'catalog',
  create: BeakHandling.stock,
  update: BeakHandling.stock,
)
final class Sample extends BeakSchema {
  @Column(label: 'Heading', searchable: false, rules: [BeakMin(1)])
  late final String title;

  @ReadOnly()
  late final int version;

  @Hidden(defaultValue: '[]')
  late final BeakJson locks;
}''', writes: true);

    final model = fixture.ir().models.single;
    expect(model.admission.writable, ['title']);
    expect(model.admission.hidden, ['locks']);
    final title = model.schema.columns.firstWhere(
      (column) => column.fieldName == 'title',
    );
    expect(title.label, 'Heading');
    expect(title.arguments['searchable'], 'false');
    expect(title.arguments['rules'], '[BeakMin(1)]');
    final locks = model.schema.columns.firstWhere(
      (column) => column.fieldName == 'locks',
    );
    expect(locks.arguments['defaultValue'], "'[]'");
  });

  test('a commands-only model opens update and writes no field', () {
    sample('  title: String');
    fixture.define('sample', '''
@Resource()
@ServerpodModel(area: 'catalog', commands: [BeakCommand('archive')])
final class Sample extends BeakSchema {
  static BeakModelBehavior get behavior => const BeakModelBehavior();

  late final String title;
}''', writes: true);

    final ir = fixture.ir();
    final model = ir.models.single;
    expect(model.capabilities, {'read', 'update'});
    expect(model.admission.writable, isEmpty);
    expect(model.schema.hasBehavior, isTrue);
    expect(ir.writes, ['sample']);
  });

  test('named inverse relations keep their actual foreign key', () {
    fixture
      ..model('owner', '''
class: Owner
table: owner
fields:
  id: UuidValue
  title: String
  children: List<Child>?, relation(name=owner_children)
''')
      ..model('child', '''
class: Child
table: child
fields:
  id: UuidValue
  title: String
  ownerRefId: UuidValue
  owner: Owner?, relation(name=owner_children, field=ownerRefId, onDelete=Cascade)
''')
      ..database([
        ServerpodFixture.table('owner', ['id', 'title']),
        ServerpodFixture.table('child', ['id', 'title', 'ownerRefId']),
      ])
      ..define('owner', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Owner extends BeakSchema {
  late final String title;

  @HasMany()
  late final List<Child> children;
}''')
      ..define('child', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Child extends BeakSchema {
  late final String title;

  @BelongsTo()
  late final Owner? owner;
}''');

    final ir = fixture.ir();
    final owner = ir.models.firstWhere((m) => m.schema.className == 'Owner');
    final child = ir.models.firstWhere((m) => m.schema.className == 'Child');
    expect(owner.schema.relations.single.foreignKey, 'ownerRefId');
    expect(child.schema.relations.single.foreignKey, 'ownerRefId');
    expect(child.schema.relations.single.kind, BeakRelationKind.belongsTo);
  });

  test('a relation annotated as the wrong kind is refused', () {
    fixture
      ..model('owner', '''
class: Owner
table: owner
fields:
  id: UuidValue
  title: String
''')
      ..model('child', '''
class: Child
table: child
fields:
  id: UuidValue
  owner: Owner?, relation
''')
      ..database([
        ServerpodFixture.table('owner', ['id', 'title']),
        ServerpodFixture.table('child', ['id', 'ownerId']),
      ])
      ..define('owner', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Owner extends BeakSchema {
  late final String title;
}''')
      ..define('child', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Child extends BeakSchema {
  @HasOne()
  late final Owner? owner;
}''');

    expect(fixture.ir, failsWith('is a belongsTo relation in Serverpod'));
  });

  test('a one-sided has-many takes the shadow key from the migration', () {
    fixture
      ..model('parent', '''
class: Parent
table: parent_main
fields:
  id: UuidValue
  name: String
  variants: List<Variant>?, relation
''')
      ..model('variant', '''
class: Variant
table: variant
fields:
  id: UuidValue
  name: String
''')
      ..database([
        ServerpodFixture.table('parent_main', ['id', 'name']),
        ServerpodFixture.table(
          'variant',
          ['id', 'name', '_parentMainVariantsParentMainId'],
          foreignKeys: [
            {
              'referenceTable': 'parent_main',
              'columns': ['_parentMainVariantsParentMainId'],
            },
          ],
        ),
      ])
      ..define('parent', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Parent extends BeakSchema {
  late final String name;

  @HasMany(owned: true)
  late final List<Variant> variants;
}''')
      ..define('variant', '''
@Resource()
@ServerpodModel.editable(area: 'catalog')
final class Variant extends BeakSchema {
  late final String name;
}''', writes: true);

    final variant = fixture.ir().models.firstWhere(
      (m) => m.schema.className == 'Variant',
    );
    expect(
      variant.schema.columns.map((column) => column.columnKey),
      contains('_parentMainVariantsParentMainId'),
    );
    // The key the parent stores is written with the variant.
    expect(variant.admission.writable, ['name', 'parentId']);
  });

  test('a foreign key without its relation stays a scalar column', () {
    fixture
      ..model('account', '''
class: Account
table: account
fields:
  id: UuidValue
  firstName: String?
  authUser: module:serverpod_auth_core:AuthUser?, relation(onDelete=Cascade)
''')
      ..database([
        ServerpodFixture.table('account', ['id', 'firstName', 'authUserId']),
      ])
      ..define('account', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Account extends BeakSchema {
  late final String? firstName;

  late final String? authUserId;
}''');

    final model = fixture.ir().models.single;
    final names = {for (final column in model.schema.columns) column.fieldName};
    expect(names, contains('authUserId'));
    expect(model.schema.relations, isEmpty);
  });

  test('enum wire names and properties come from Serverpod', () {
    fixture
      ..model('state', '''
enum: State
properties:
  description: String
values:
  - ready:
      description: Ready to serve
  - done:
      description: Finished
''')
      ..model('sample', '''
class: Sample
table: sample
fields:
  id: UuidValue
  state: State, default=ready
''')
      ..database([
        ServerpodFixture.table('sample', ['id', 'state']),
      ])
      ..define('sample', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Sample extends BeakSchema {
  late final State state;
}''');

    final state = fixture.ir().enums.single;
    expect(state.name, 'State');
    expect(state.values.first.name, 'ready');
    expect(state.values.first.properties, ["'Ready to serve'"]);
    expect(state.properties, {'description': 'String'});
  });

  test('a translation table detects its restore key from the unique index', () {
    fixture
      ..model('product', '''
class: Product
table: product
fields:
  id: UuidValue
  name: String
  translations: List<ProductTranslation>?, relation
''')
      ..model('product_translation', '''
class: ProductTranslation
table: product_translation
fields:
  id: UuidValue
  locale: String
  name: String
''')
      ..database([
        ServerpodFixture.table('product', ['id', 'name']),
        ServerpodFixture.table(
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
      ])
      ..define('product', '''
@Resource()
@ServerpodModel(area: 'catalog', reason: 'Closed.')
final class Product extends BeakSchema {
  late final String name;

  @HasMany(owned: true)
  late final List<ProductTranslation> translations;
}''')
      ..define('product_translation', '''
@Resource()
@ServerpodModel(area: 'catalog', update: BeakHandling.stock)
final class ProductTranslation extends BeakSchema {
  @ReadOnly()
  late final String locale;

  late final String name;
}''', writes: true);

    final model = fixture.ir().models.firstWhere(
      (m) => m.schema.className == 'ProductTranslation',
    );
    expect(model.admission.restoreKey, isNotEmpty);
    expect(model.admission.translationOwner, isNotNull);
    expect(model.admission.translationLocale, 'locale');
  });
}
