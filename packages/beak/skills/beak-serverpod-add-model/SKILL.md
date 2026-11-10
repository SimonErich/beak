---
name: beak-serverpod-add-model
description: Expose a Serverpod model in a generated Beak admin. Read the model and migration, review the inventory entry, run beak generate, and prove the generated library and its authored definitions compile.
---

# Expose a Serverpod model in the admin

Use this when an existing Serverpod `.spy.yaml` model should appear in the Beak
admin. The generated package is not edited by hand: the model, the newest
migration and the reviewed inventory are the inputs.

## 1. Read the model

Open the model's `.spy.yaml` and note:

- the `class:` name and `table:`,
- its scalar fields and their nullability,
- belongs-to, has-many and has-one relations (and any `relation(name:)`),
- enums it uses,
- fields marked `scope=serverOnly`, `!persist` or secret-looking.

Open the newest `*/definition_project.json` under the server's `migrations/`
and confirm the table and every column you expect. A column that is not in the
migration cannot be generated; create a migration first.

## 2. Review the inventory

Add the model under `definitions/resources/<area>.yaml`:

```yaml
area: catalog
resources:
  Product:
    display: sku
    operations: [read, create, update, delete]
    write: catalog
    writeFields: [sku, productType, status, netPriceCents, categoryId]
    ownedRelations: [translations, variants]
```

- `operations` defaults to `[read]`.
- A write operation needs `write:` (a value of `generate.writes`) and a
  `writeFields:` list. An empty list means every change goes through a command.
- A read-only model needs a `reason:` saying why the write is closed.
- `exclude:` drops a model from the generated package; `hidden:` keeps a
  column in the model but never sends it to a client.
- `scalarRelations:` exposes only a relation's stored foreign key.
- `access:` overrides the area's roles for one operation.
- `fields:` renames or constrains one column (`label`, `min`, `max`, `text`,
  `semantic`).

The file-level `area:` and `generate.areas` decide the read/write roles.

## 3. Generate

```console
$ beak generate --project apps/shop_admin
$ beak generate --project apps/shop_admin --check
```

`--check` is what CI runs. A stale, missing or orphaned file fails it.

## 4. Bind the authored behavior

Business logic stays authored. Add the model to the project's
`BeakDefinitions` when it needs a behavior or a record rule:

```dart
final shopDefinitions = BeakDefinitions([
  BeakModelDefinition(const ProductModel(), rules: [ProductPriceRule()]),
]);
```

Do not restate columns, permissions or write admission there: the generator
already put those on the model.

## 5. Prove it

- `dart analyze` the generated package and the authored definitions.
- Run the panel's route sweep or open the list, detail, create and edit pages.
- One write per open operation goes through its use case or stock persistence.
- A read-only model shows no create/edit/delete action.

If the write is closed, add it to the project's open-workflows document with
the use case it still needs instead of opening stock persistence.

## Example prompt

> Expose the Serverpod `Invoice` model in our Beak admin: read-only for now,
> with a reason naming the use case that must own payment changes. Add the
> inventory entry, run `beak generate`, make the generated package and the
> definitions analyze, and add the route-sweep case that opens the invoice list
> and detail pages.
