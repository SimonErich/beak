import 'dart:io';

import 'package:beak_cli/src/labels/label_catalog.dart';
import 'package:beak_cli/src/labels/label_resolver.dart';
import 'package:beak_cli/src/labels/label_settings.dart';
import 'package:beak_cli/src/schema/beak_schema_ir.dart';
import 'package:test/test.dart';

const _order = BeakSchemaIr(
  className: 'PlacedOrder',
  table: 'placed_order',
  libraryPath: 'src/models/placed_order.dart',
  displayColumnKey: 'email',
  softDeletes: false,
  timestamps: false,
  managesSchema: false,
  columns: [
    BeakColumnIr(
      fieldName: 'id',
      columnKey: 'id',
      label: 'Id',
      kind: BeakColumnKind.string,
      isRequired: true,
      arguments: {'visibleOn': '{BeakContext.detail}'},
    ),
    BeakColumnIr(
      fieldName: 'email',
      columnKey: 'email',
      label: 'Email',
      kind: BeakColumnKind.string,
      isRequired: true,
    ),
    BeakColumnIr(
      fieldName: 'sortOrder',
      columnKey: 'sortOrder',
      label: 'Sort Order',
      kind: BeakColumnKind.integer,
      isRequired: true,
    ),
    BeakColumnIr(
      fieldName: 'status',
      columnKey: 'status',
      label: 'Status',
      kind: BeakColumnKind.enumeration,
      isRequired: true,
      enumTypeName: 'OrderStatus',
      enumValueNames: ['pending', 'active'],
    ),
    BeakColumnIr(
      fieldName: 'profileId',
      columnKey: 'profileId',
      label: 'Profile Id',
      kind: BeakColumnKind.string,
      isRequired: true,
    ),
    BeakColumnIr(
      fieldName: 'searchVector',
      columnKey: 'searchVector',
      label: 'Search Vector',
      kind: BeakColumnKind.string,
      isRequired: false,
      arguments: {'visibleOn': '{}'},
    ),
  ],
  relations: [
    BeakRelationIr(
      fieldName: 'profile',
      key: 'profile',
      label: 'Profile',
      kind: BeakRelationKind.belongsTo,
      relatedSchema: 'Profile',
      foreignKey: 'profileId',
    ),
  ],
);

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('beak-resolve-'));
  tearDown(() => root.deleteSync(recursive: true));

  BeakLabelCatalog catalog(Map<String, String> files) {
    for (final MapEntry(:key, :value) in files.entries) {
      File('${root.path}/$key').writeAsStringSync(value);
    }
    return BeakLabelCatalog.read(root, template: 'de');
  }

  const complete = {
    'models_de.arb': '''
{
  "@@locale": "de",
  "*.id": "ID",
  "*.sortOrder": "Reihenfolge",
  "*.status": "Status",
  "*.active": "Aktiv",
  "placedOrder": "{count, plural, one{Bestellung} other{Bestellungen}}",
  "placedOrder.email": "E-Mail",
  "placedOrder.email.hint": "Adresse der Bestätigung",
  "placedOrder.profile": "Kundenprofil",
  "orderStatus.pending": "Offen",
  "placedOrder.actions.cancel": "Stornieren",
  "placedOrder.actions.cancel.description": "Die Bestellung wird storniert."
}''',
    'models_en.arb': '''
{
  "@@locale": "en",
  "*.id": "ID",
  "*.sortOrder": "Sort order",
  "*.status": "Status",
  "*.active": "Active",
  "placedOrder": "{count, plural, one{Order} other{Orders}}",
  "placedOrder.email": "Email",
  "placedOrder.email.hint": "Where the confirmation went",
  "placedOrder.profile": "Customer profile",
  "orderStatus.pending": "Pending",
  "placedOrder.actions.cancel": "Cancel",
  "placedOrder.actions.cancel.description": "The order is cancelled."
}''',
  };

  test('exact keys, shared keys, enum values, hints and actions', () {
    final resolution = resolveBeakLabels(
      catalog: catalog(complete),
      schemas: const [_order],
    );
    final labels = resolution.labels.of(_order);

    expect(resolution.errors, isEmpty);
    expect(resolution.warnings, isEmpty);
    expect(resolution.labels.template, 'de');
    expect(labels.one, {'de': 'Bestellung', 'en': 'Order'});
    expect(labels.other, {'de': 'Bestellungen', 'en': 'Orders'});
    expect(labels.fields['email'], {'de': 'E-Mail', 'en': 'Email'});
    expect(labels.fields['sortOrder'], {
      'de': 'Reihenfolge',
      'en': 'Sort order',
    });
    expect(labels.hints['email'], {
      'de': 'Adresse der Bestätigung',
      'en': 'Where the confirmation went',
    });
    expect(labels.values['status'], {
      'de': {'pending': 'Offen', 'active': 'Aktiv'},
      'en': {'pending': 'Pending', 'active': 'Active'},
    });
    expect(labels.actions['cancel'], {'de': 'Stornieren', 'en': 'Cancel'});
    expect(labels.actionDescriptions['cancel'], {
      'de': 'Die Bestellung wird storniert.',
      'en': 'The order is cancelled.',
    });
  });

  test('a foreign key column takes its relationship label', () {
    final labels = resolveBeakLabels(
      catalog: catalog(complete),
      schemas: const [_order],
    ).labels.of(_order);

    expect(labels.fields['profile'], {
      'de': 'Kundenprofil',
      'en': 'Customer profile',
    });
    expect(labels.fields['profileId'], labels.fields['profile']);
  });

  test('a labelKey moves the model under another key', () {
    const renamed = BeakSchemaIr(
      className: 'PlacedOrder',
      labelKey: 'order',
      table: 'placed_order',
      libraryPath: 'src/models/placed_order.dart',
      displayColumnKey: 'id',
      softDeletes: false,
      timestamps: false,
      managesSchema: false,
      columns: [],
      relations: [],
    );
    final resolution = resolveBeakLabels(
      catalog: catalog({
        'models_de.arb': '{"@@locale": "de", "order": "Bestellung"}',
      }),
      schemas: const [renamed],
    );

    expect(resolution.errors, isEmpty);
    expect(resolution.labels.of(renamed).one, {'de': 'Bestellung'});
  });

  test('a key that names nothing is an error with a suggestion', () {
    final resolution = resolveBeakLabels(
      catalog: catalog({
        'models_de.arb': '''
{"@@locale": "de", "placedOrder.emial": "E-Mail", "nobody.actions.x": "X"}''',
      }),
      schemas: const [_order],
    );
    final messages = resolution.errors.map((issue) => issue.message).join('\n');

    expect(messages, contains('"placedOrder.emial"'));
    expect(messages, contains('Did you mean "placedOrder.email"?'));
    expect(messages, contains('"nobody.actions.x"'));
  });

  test('a shared key every model overrides is reported as unused', () {
    final resolution = resolveBeakLabels(
      catalog: catalog({
        'models_de.arb': '''
{"@@locale": "de", "*.email": "E-Mail", "placedOrder.email": "Adresse"}''',
      }),
      schemas: const [_order],
    );

    expect(
      resolution.errors.single.message,
      allOf(contains('"*.email" is never used'), isNot(contains('Did you'))),
    );
  });

  test('a key missing in one locale is an error', () {
    final resolution = resolveBeakLabels(
      catalog: catalog({
        'models_de.arb': '{"@@locale": "de", "placedOrder.email": "E-Mail"}',
        'models_en.arb': '{"@@locale": "en"}',
      }),
      schemas: const [_order],
    );

    expect(
      resolution.errors.single.message,
      contains('"placedOrder.email" is missing in en'),
    );
  });

  test('shown fields without a label warn, or fail with require: shown', () {
    final source = catalog({
      'models_de.arb': '{"@@locale": "de", "placedOrder.email": "E-Mail"}',
    });
    final warned = resolveBeakLabels(catalog: source, schemas: const [_order]);
    final required = resolveBeakLabels(
      catalog: source,
      schemas: const [_order],
      require: BeakLabelRequirement.shown,
    );

    expect(warned.errors, isEmpty);
    final String warning = warned.warnings.single.message;
    expect(warning, contains('de'));
    expect(warning, contains('placedOrder'));
    expect(warning, contains('placedOrder.sortOrder'));
    expect(warning, contains('orderStatus.pending'));
    expect(warning, isNot(contains('searchVector')));
    expect(required.errors.single.message, warning);
  });
}
