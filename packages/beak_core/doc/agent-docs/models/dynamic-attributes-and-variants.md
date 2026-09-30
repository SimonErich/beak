# Dynamic attributes and variants

> Describe category-driven attributes once for the editor and the server, and stage product variants from a bounded matrix with a stable key.

A coffee category wants a roast, a kettle category wants a voltage, and every product sells in a few sizes and finishes. After this page you can describe an attribute once so the editor and the server agree on it, reconcile stored values against changed definitions without losing data, and stage variant combinations with a guarantee that survives two people saving at the same time.

## At a glance

Beak ships no attributes table and no variant resource. Your schema decides where definitions and values live; Beak supplies value types that describe them and do the arithmetic. That is why the shop has an adapter file, a graph preparer and a migration next to the two types below, and why the guarantee comes from the server and a unique constraint, not from the preview.

| Piece | Job | Lives in |
| --- | --- | --- |
| `BeakAttributeDefinition` | One attribute: stable id, label, type, choices, requiredness, revision, extra rules | `beak_core` |
| `BeakAttributeSet.reconcile` | Compares stored values with the current definitions and reports, never deletes | `beak_core` |
| `inputAttribute(...)` | A form input whose editor follows the definition | `beak_frontend` |
| `BeakVariantAxis`, `BeakVariantMatrix`, `BeakVariantCombination` | Dimensions, a bounded preview of missing combinations, a stable key | `beak_core` |
| Adapter, graph preparer, unique constraint | Turn your rows into the types above and enforce the result | your app |

The shop keeps definitions as owned `CategoryAttribute` rows under a `Category`. A `Product` owns `ProductAttribute` rows (a value, and optionally the definition it answers) and `ProductVariant` rows, each owning `VariantAttribute` name and value rows.

```dart title="examples/clean_beak_config/lib/resources/categories/models/category_attribute.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'category.dart';
part 'category_attribute.beak.dart';

/// How a category attribute should be interpreted.
enum AttributeValueType {
  /// Free text.
  text,

  /// A numeric value.
  number,

  /// The literal value true or false.
  boolean,

  /// One of the configured choices.
  choice,
}

/// A reusable category attribute, such as roast or material.
@Resource()
final class CategoryAttribute extends BeakSchema {
  /// Attribute label.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// Optional guidance for entering the value.
  late final String? description;

  /// Expected value shape.
  @Column(defaultValue: AttributeValueType.text)
  late final AttributeValueType valueType;

  /// Comma-separated choices when the type is choice.
  late final String? choices;

  /// Whether products should supply this attribute.
  late final bool required;

  /// Category that owns this definition.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Category category;
}
```

Values are canonical strings on purpose. An existing attribute-value table keeps its shape, and the type only says how to read the string.

## One definition, two callers

The shop converts a stored `CategoryAttribute` into a definition in one function. The product editor calls it to draw the input and the graph preparer calls it to validate the save, so the two cannot disagree:

```dart title="examples/clean_beak_config/lib/domain/shop_attributes.dart"
import 'package:beak/beak.dart';
import '../resources/categories/models/category_attribute.dart';

/// One adapter supplies both dynamic controls and authoritative validation.
BeakAttributeDefinition shopAttributeDefinition(
  BeakRecord record, {
  String? identity,
}) {
  final definition = record.asCategoryAttribute;
  return BeakAttributeDefinition(
    id: identity ?? definition.id ?? definition.name,
    label: definition.name,
    description: definition.description,
    type: switch (definition.valueType) {
      AttributeValueType.text => BeakAttributeType.text,
      AttributeValueType.number => BeakAttributeType.number,
      AttributeValueType.boolean => BeakAttributeType.boolean,
      AttributeValueType.choice => BeakAttributeType.choice,
    },
    required: definition.required,
    choices: shopAttributeChoices(definition.choices),
  );
}

/// Existing catalog choices retain their storage while becoming typed metadata.
List<String> shopAttributeChoices(String? value) => (value ?? '')
    .split(',')
    .map((choice) => choice.trim())
    .where((choice) => choice.isNotEmpty)
    .toSet()
    .toList();
```

A `BeakAttributeDefinition` takes `id`, `label` and `type`, and optionally `required` (default `false`), `choices`, `version` (default 1), `description` and `rules`. `BeakAttributeType` has four values:

| Type | Valid value | Extra rules see |
| --- | --- | --- |
| `text` | Any string | the string |
| `number` | A finite number that `double.tryParse` accepts, written with `.` | a `double` |
| `boolean` | Exactly `true` or `false` | a `bool` |
| `choice` | One of `choices`, character for character | the string |

The constructor throws `BeakConfigurationException('Invalid attribute definition.')` for an empty id or label, a version below 1, a `choice` without choices, or choices that are blank or repeated. `id` is the identity. It stays put when a label is renamed, which is why the adapter takes an `identity` (the server passes the definition's record key) and otherwise falls back to the record's id and, for an unsaved row, its name.

`validate(value, {version})` returns the first problem as a message, or `null`. Two scratch definitions (illustrative, every name is real API) and what they say:

```dart
final roast = BeakAttributeDefinition(
  id: 'roast',
  label: 'Roast',
  type: BeakAttributeType.choice,
  required: true,
  choices: ['light', 'dark'],
  version: 2,
);
final weight = BeakAttributeDefinition(
  id: 'weight',
  label: 'Weight',
  type: BeakAttributeType.number,
  rules: [BeakMin(0)],
);
```

```text
roast.validate('medium')            Enter a valid choice value for Roast.
roast.validate('')                  Roast is required.
roast.validate('dark', version: 1)  Review this value because its attribute definition changed.
weight.validate('12,5')             Enter a valid number value for Weight.
weight.validate('-3')               Must be at least 0.
weight.validate('12.5')             null
```

`12,5` fails because the canonical form uses a point. The input does the locale conversion for you (see below), and the API never sees a comma.

## The editor follows the definition

In the form, `inputAttribute` reads the definition from the live draft. The shop's value field switches shape as the user picks a different category attribute, and the whole table sits in the product form:

```dart
ProductModel.attributes.tableForm(
  label: 'Specifications',
  removeBehavior: BeakRemoveBehavior.deleteOwned,
  children: [
    ProductAttributeModel.definition.inputCombobox(
      label: 'Category attribute',
      enabledIf: (state) =>
          state.parent?.asProduct.categoryId != null,
      options: (state) => CategoryAttributeModel.options(
        filter: CategoryAttributeModel.categoryId.eq(
          state.parent?.asProduct.categoryId,
        ),
      ),
    ),
    ProductAttributeModel.name.inputText(
      label: 'Attribute name',
      derive: (state) =>
          state.asProductAttribute.definition?.name ??
          ProductAttributeModel.name.readFrom(
            state.draft.snapshot,
          ),
    ),
    ProductAttributeModel.value.inputAttribute(
      label: 'Value',
      definition: (state) => switch (state.read(
        ProductAttributeModel.definition,
      )) {
        final BeakRecord record => shopAttributeDefinition(
          record,
        ),
        null => null,
      },
    ),
  ],
),
```

The `definition:` callback runs against the draft, so it can follow another field. `null` means no definition is selected yet, and the field falls back to plain text, which is also how a custom specification (a row with no category attribute) works. What the editor becomes:

| Definition type | Editor |
| --- | --- |
| `text` | Text field |
| `number` | Numeric keyboard, accepts the panel's decimal separator, stores the canonical string |
| `boolean` | Yes and No radio |
| `choice` | Select over `choices` |

The definition also supplies the label and the description, and its `validate` runs as client-side validation. Pass `version:` a callback returning the revision stored with the value when you track them. `type:` is a lighter form of the same idea for when you have a type and no full definition; a definition wins over it.

## The server re-checks

A hidden or edited input proves nothing, so the shop checks again inside the graph commit. `ProductAttributeModel` and its neighbours are `graphOnly` in `examples/clean_beak_config/lib/server.dart`, and `preparePlan` runs `ShopGraphPreparer`. For a product it loads the category's definitions and reconciles the final rows against them:

```dart
final result =
    BeakAttributeSet([
      for (final definition in definitions)
        shopAttributeDefinition(
          definition.record,
          identity: _key(definition.ref),
        ),
    ]).reconcile([
      for (final attribute in attributes.where((node) => !node.deleted))
        if (attribute.reference(ProductAttributeModel.definition)
            case final reference?)
          BeakAttributeEntry(
            definitionId: _key(reference),
            value: attribute.read(ProductAttributeModel.value),
            version: 1,
          ),
    ]);
if (!result.valid) {
  final message = result.missing.isNotEmpty
      ? 'Provide the required attribute: ${result.missing.first.label}.'
      : result.obsolete.isNotEmpty
      ? 'Review attributes that no longer belong to this category.'
      : result.errors.values.first.first;
  _invalid(ProductModel.attributes, message);
}
```

`BeakAttributeSet(definitions)` requires unique ids (`Attribute identities must be unique.`). `reconcile(entries)` returns a `BeakAttributeReconciliation`:

| Field | Meaning |
| --- | --- |
| `retained` | Entries that still belong to the set, including invalid ones |
| `obsolete` | Entries whose definition is gone. Never deleted for you |
| `missing` | Required definitions with no entry at all |
| `errors` | Messages per definition id, including `This attribute appears more than once.` |
| `valid` | `true` when `obsolete`, `missing` and `errors` are all empty |

The result is data and the policy is yours. The shop turns a missing required attribute into `Provide the required attribute: <label>.`, an obsolete one into `Review attributes that no longer belong to this category.`, and anything else into the first error. Two more checks sit next to it: a row's definition has to belong to the product's own category (`Choose an attribute from this product category.`), and one definition can be answered once per product (`A category attribute can only be provided once.`). Moving a product to another category therefore fails until its old rows are fixed or removed, and nothing is deleted on the way.

The shop passes `version: 1` for every entry because it never changes what a definition means. If yours does, persist the revision beside each value and pass it: a value entered under revision 1 then fails against revision 2 with `Review this value because its attribute definition changed.`, and a person decides what it means now.

## Variants: a bounded preview

A variant is a sellable choice (250 g, whole bean) with its own SKU, price and stock. The matrix does the boring part, the Cartesian product, and refuses to do it for too many.

```dart
final matrix = BeakVariantMatrix([
  BeakVariantAxis(
    key: firstName.text.trim(),
    label: firstName.text.trim(),
    values: first,
  ),
  if (second.isNotEmpty)
    BeakVariantAxis(
      key: secondName.text.trim(),
      label: secondName.text.trim(),
      values: second,
    ),
], maximumCombinations: 100);
preview.value = matrix.preview(
  existing: shopVariantCombinations(draft),
);
```

In that fragment `first` and `second` are the value lists parsed from the two text fields, and the second axis is optional. `BeakVariantAxis(key, label, values)` needs at least one value, all non-blank and distinct (`BeakConfigurationException` otherwise). `BeakVariantMatrix(axes, {maximumCombinations})` rejects duplicate axis keys and multiplies the value counts before it builds anything. The default limit is 500, the shop uses 100, and going over throws `BeakValidationException('Choose fewer variant values; the limit is $maximumCombinations combinations.')`. A matrix of two axes with three values each and a limit of 4 shows it:

```dart
// Illustrative scratch script; every name is real API.
final matrix = BeakVariantMatrix([
  BeakVariantAxis(key: 'Size', label: 'Size', values: ['250 g', '1 kg']),
  BeakVariantAxis(key: 'Grind', label: 'Grind', values: ['Whole', 'Ground']),
]);
final existing = BeakVariantCombination({'Grind': 'Whole', 'Size': '250 g'});
for (final combination in matrix.preview(existing: [existing])) {
  print('${combination.label}   ${combination.key}');
}
try {
  BeakVariantMatrix([
    BeakVariantAxis(key: 'Size', label: 'Size', values: ['a', 'b', 'c']),
    BeakVariantAxis(key: 'Grind', label: 'Grind', values: ['x', 'y', 'z']),
  ], maximumCombinations: 4);
} on BeakValidationException catch (error) {
  print(error.message);
}
```

```text
250 g / Ground   [["Grind","Ground"],["Size","250 g"]]
1 kg / Whole   [["Grind","Whole"],["Size","1 kg"]]
1 kg / Ground   [["Grind","Ground"],["Size","1 kg"]]
Choose fewer variant values; the limit is 4 combinations.
```

`preview` returns only what `existing` does not already contain. Order follows the axes, so the result is stable. A combination's `key` is the JSON of its sorted key and value pairs. Axis order does not matter (`{'Grind': 'Whole', 'Size': '250 g'}` is the same key however you build it), and neither the separator nor a colon in a value can make two different combinations collide. The `label` joins the values with ` / ` in the order they were put in the map.

## Staging rows

The preview makes nothing. The shop's builder takes up to two dimensions as comma-separated text, previews, lets the user tick a subset, and adds ordinary unsaved rows to the product draft:

```dart
int stageShopVariants(
  BeakDraftRecord product,
  Iterable<BeakVariantCombination> combinations,
) {
  final existing = shopVariantCombinations(
    product,
  ).map((row) => row.key).toSet();
  final skus = product
      .rows(ProductModel.variants)
      .map((row) => row.read(ProductVariantModel.sku))
      .toSet();
  final prefix = product.read(ProductModel.sku)!.trim();
  var suffix = 1;
  var added = 0;
  for (final combination in combinations) {
    if (!existing.add(combination.key)) continue;
    while (skus.contains('$prefix-${suffix.toString().padLeft(3, '0')}')) {
      suffix++;
    }
    final sku = '$prefix-${suffix.toString().padLeft(3, '0')}';
    skus.add(sku);
    final variant = product.addRow(ProductModel.variants);
    variant.set(ProductVariantModel.name, combination.label);
    variant.set(ProductVariantModel.sku, sku);
    variant.set(ProductVariantModel.price, product.read(ProductModel.price));
    variant.set(ProductVariantModel.stock, 0);
    variant.set(ProductVariantModel.active, true);
    for (final entry in combination.values.entries) {
      final attribute = variant.addRow(ProductVariantModel.attributes);
      attribute.set(VariantAttributeModel.name, entry.key);
      attribute.set(VariantAttributeModel.value, entry.value);
    }
    added++;
  }
  return added;
}
```

Every added variant inherits the catalog price, starts at stock 0, is active, and gets the next free `<base SKU>-001` style SKU within the draft. Its attributes become owned `VariantAttribute` rows. The base SKU and price must be filled in first, and nothing is written until the product is saved. Rows already in the draft, loaded or staged, are excluded from the next preview through `shopVariantCombinations(draft)`. The builder is placed with a `BeakFormWidget`:

```dart
BeakFormWidget(
  showOnRead: false,
  builder: (context, draft) => ShopVariantBuilder(draft: draft),
),
```

Two dimensions is a limit of this widget. The matrix accepts any number of axes.

## Uniqueness: what the preview does not promise

The preview is a bouncer counting heads at the door. It cannot know what another admin saved a second ago, so the guarantee is built in three more layers.

The variant model declares rules that every caller shares. `BeakDistinct` rejects repeated attribute names inside one variant, and `BeakUnique` on the hidden `combinationKey` column is the asynchronous check:

```dart
/// A product can sell a particular attribute combination only once.
static List<BeakRecordRule> get validationRules => [
  BeakUnique(
    ProductVariantModel.combinationKey,
    scope: [ProductVariantModel.productId],
  ),
  BeakDistinct(ProductVariantModel.attributes, VariantAttributeModel.name),
];
```

`combinationKey` is declared `@Column(visibleOn: {})`, so no form, table or detail view shows it, and nobody types it. The graph preparer derives it from the final attribute rows and refuses a save that repeats a sibling:

```dart
for (final ref in variantRefs) {
  final variant = await graph.load(ref);
  if (variant.deleted) continue;
  final key = await _combination(graph, variant);
  if (key != null) {
    final product = await graph.linked(
      variant,
      ProductVariantModel.product,
    );
    if (product != null) {
      for (final sibling in await graph.children(
        product,
        ProductModel.variants,
      )) {
        if (sibling.ref != variant.ref &&
            await _combination(graph, sibling) == key) {
          _invalid(
            ProductVariantModel.attributes,
            'This product already has a variant with these attributes.',
          );
        }
      }
    }
  }
  graph.write(variant, ProductVariantModel.combinationKey, key);
}
```

```dart
Future<String?> _combination(
  BeakCandidateGraph graph,
  BeakCandidateNode variant,
) async {
  final values = <String, String>{};
  for (final attribute in await graph.children(
    variant,
    ProductVariantModel.attributes,
  )) {
    final name = (attribute.read(VariantAttributeModel.name) ?? '').trim();
    if (values.containsKey(name)) {
      _invalid(
        ProductVariantModel.attributes,
        'Each variant attribute must have a different name.',
      );
    }
    values[name] = (attribute.read(VariantAttributeModel.value) ?? '').trim();
  }
  return values.isEmpty ? null : BeakVariantCombination(values).key;
}
```

The key is computed from trimmed names and values, and a repeated name inside one variant is refused with `Each variant attribute must have a different name.` A variant with no attributes gets `null`, so unconfigured variants never collide. Because the comparison walks the attribute rows and not the stored key, variants that have no key yet (created before the column existed) are checked too.

The last word belongs to the database. The migration adds the column and a unique constraint over the product and the key, and it skips itself when the column already exists:

```dart
import 'package:beak/migrations.dart';
import '../resources/products/models/product_variant.dart';

/// Adds optional combination identities without replacing any catalog records.
final class AddVariantCombinations extends Migration {
  /// Creates the additive migration.
  const AddVariantCombinations();

  @override
  String get name => '20260927_230000_add_variant_combinations';

  @override
  Future<void> upSchema(Schema schema) async {
    final columns = await schema.adapter.introspectSchema();
    if (columns[const ProductVariantModel().table]?.contains(
          ProductVariantColumns.combinationKey.key,
        ) ??
        false) {
      return;
    }
    await schema.alter(const ProductVariantModel().table, (table) {
      BeakBlueprint.defineColumn(table, ProductVariantColumns.combinationKey);
      table.unique([
        ProductVariantColumns.productId.key,
        ProductVariantColumns.combinationKey.key,
      ]);
    });
  }

  @override
  Future<void> downSchema(
    Schema schema,
  ) async => throw IrreversibleMigrationException(
    migration: name,
    message:
        'Removing combination identities requires an explicit data migration.',
  );
}
```

Two admins saving the same combination at the same moment both pass the checks that read first, and the constraint rejects the second write. On a fresh SQLite database the second row fails with `UniqueConstraintException: UNIQUE constraint failed: product_variants.combination_key, product_variants.product_id`, while any number of rows with a `null` key coexist. The ordinary `sku` column keeps its own unique constraint across all products.

## Rules and limits

- Definitions and values are your tables. Beak has no attribute store, so the adapter from your rows to `BeakAttributeDefinition` is code you write and test.
- Values are strings. `number` means "parses as a finite double", so `1e3` passes. The panel input stores the parsed number as text, so digits beyond a double are lost. Use an exact-decimal column if you need them.
- A row without a definition (a custom specification) is not reconciled. Only column rules and your own checks apply to it.
- `missing` counts a required definition with no entry at all. An entry with an empty value is reported in `errors` as `<label> is required.`
- `reconcile` reports and never deletes. Removing obsolete rows is a decision for a person, or for your own code.
- Combination keys compare exact strings. `Whole` and `whole` are different combinations, and the matrix does not trim. The shop trims in the preparer.
- Variant SKUs made by the builder are unique inside the draft only. The unique constraint on `sku` decides across products and concurrent saves.
- The reconcile and the sibling comparison live in `ShopGraphPreparer`, which is shop code and not Beak. A project that copies the editor pieces and skips the preparer has an editor that validates and a server that only runs the model rules.

## Verify it

The value types are plain Dart. Run the scratch script from above, or the package tests:

```bash
cd packages/beak_core
dart test test/src/model/beak_attribute_definition_test.dart test/src/model/beak_variant_matrix_test.dart
```

The shop covers the staging and the server checks. Each command runs one test against an in-memory database:

```bash
cd examples/clean_beak_config
flutter test test/custom_shop_test.dart --plain-name "variant preview stages only selected missing combinations"
flutter test test/shop_api_test.dart --plain-name "required category attributes"
flutter test test/shop_api_test.dart --plain-name "duplicate variant combinations"
```

Each prints `All tests passed!`. The last one commits a variant that repeats an existing combination and expects an incomplete receipt and no new row.

## Reference

| Symbol | Kind | Notes |
| --- | --- | --- |
| `BeakAttributeType` | enum | `text`, `number`, `boolean`, `choice` |
| `BeakAttributeDefinition` | class | `id`, `label`, `type`, `required`, `choices`, `version`, `description`, `rules`; `validate(String? value, {int? version})` |
| `BeakAttributeEntry` | class | `definitionId`, `value`, `version` |
| `BeakAttributeSet` | class | `definitions`; `reconcile(Iterable<BeakAttributeEntry>)` |
| `BeakAttributeReconciliation` | class | `retained`, `obsolete`, `missing`, `errors`, `valid` |
| `BeakVariantAxis` | class | `key`, `label`, `values` |
| `BeakVariantCombination` | class | `values`, `key`, `label` |
| `BeakVariantMatrix` | class | `axes`, `maximumCombinations` (default 500), `preview({existing})` |
| `inputAttribute` | extension on `BeakScalarField<String>` | `type`, `definition`, `version`, `options`, `label`, `description`, `validators`, `visibleIf`, `enabledIf` |

The types are in `packages/beak_core/lib/src/model/beak_attribute_definition.dart` and `packages/beak_core/lib/src/model/beak_variant_matrix.dart`. `inputAttribute` is in `packages/beak_frontend/lib/src/form/beak_input_presentation.dart`. The rule types behind `BeakUnique` and `BeakDistinct` are on [Validation rules](../reference/validation-rules.md).

## Continue reading

- [Validation](validation.md) covers `BeakUnique`, `BeakDistinct` and the other shared rules.
- [Transactional business rules](../backend/graph-business-rules.md) shows how a graph preparer sees and rewrites a save.
- [Related records](../forms/related-records.md) covers the owned tables these forms are built from.
- [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) is where a builder like `ShopVariantBuilder` plugs in.
