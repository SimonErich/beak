---
name: beak-serverpod-add-model
description: Expose a Serverpod model in a generated Beak admin. Read the model and migration, write its definition class, run beak generate, and prove the generated part and the server compile.
---

# Expose a Serverpod model in the admin

Use this when an existing Serverpod `.spy.yaml` model should appear in the Beak
admin. Generated code is not edited by hand: the model, the newest migration
and the definition class are the inputs.

## 1. Read the model

Open the model's `.spy.yaml` and note:

- the `class:` name and `table:`,
- its scalar fields, their types and nullability,
- belongs-to, has-many and has-one relations (and any `relation(name:)`),
- enums it uses,
- fields marked `scope=serverOnly`, `!persist` or secret-looking.

Open the newest `*/definition_project.json` under the server's `migrations/`
and confirm the table and every column you expect. A column that is not in the
migration cannot be generated; create a migration first.

## 2. Write the definition class

One file per model in the definitions package, named after the class:

```dart
import 'package:beak_core/beak_core.dart';
import 'package:beak_serverpod/schema.dart';
import 'package:shop_definitions/src/catalog/product_category.dart';
import 'package:shop_definitions/src/generated/enums.dart';
import 'package:shop_definitions/src/generated/writes.dart';

part 'product.beak.dart';

/// A sellable product.
@Resource()
@ServerpodModel(
  area: 'catalog',
  create: BeakHandling.stock,
  update: BeakHandling.derived,
  delete: BeakHandling.stock,
)
final class Product extends BeakSchema {
  /// Unique stock keeping unit.
  @Display()
  late final String sku;

  /// Lifecycle status.
  late final ProductStatus status;

  /// The category it is listed under.
  @BelongsTo()
  late final ProductCategory? category;

  /// Bumped by the server on every edit.
  @ReadOnly()
  late final int version;

  /// Fields an import may no longer overwrite.
  @Hidden(defaultValue: '[]')
  late final BeakJson importLockedFields;

  /// Saved with the product.
  @HasMany(owned: true)
  late final List<ProductTranslation> translations;
}
```

- The class and field names are Serverpod's. `UuidValue` is `String`, a list
  or JSON is `BeakJson`, a Serverpod enum keeps its name; `?` matches.
- Leave out what the admin must not read or write. Keys, timestamps and soft
  delete are exposed anyway.
- Every operation is `off` until opened; a read-only model names `reason:`.
  `@ServerpodModel.editable()` opens stock create, update and delete.
- `access:` overrides the area's roles for one operation.
- A foreign key declared without its relation stays a plain key column.
- Rules and commands: `static get validationRules`, `static get behavior`.

When `beak.yaml` has `labels:`, add the model's names to each
`labels/models_<locale>.arb` (`product`, `product.sku`,
`productStatus.active`).

## 3. Generate

```console
$ beak generate --project apps/shop_admin
$ beak generate --project apps/shop_admin --check
```

The run names every mismatch with Serverpod (a missing field, a wrong type or
`?`, a wrong relation kind, a required field a stock create leaves empty, a
missing `part` or import) before it writes anything. `--check` is what CI runs.

## 4. Implement custom code

A `derived` or `custom` operation, a custom `list` or a command adds a handler
base class in `generate.handlers` and a required argument to
`<Prefix>Handlers`. Implement it with the `beak-serverpod-bind-write` skill.

## 5. Prove it

- `dart analyze` the definitions package and the server.
- Run the panel's route sweep or open the list, detail, create and edit pages.
- One write per open operation reaches its stock path or its handler.
- A read-only model shows no create, edit or delete action.

## Example prompt

> Expose the Serverpod `Invoice` model in our Beak admin: read-only for now,
> with a reason naming the use case that must own payment changes. Write its
> definition class, run `beak generate`, make the definitions and the server
> analyze, and add the route-sweep case that opens the invoice list and detail
> pages.
