---
name: beak-add-resource
description: Add a table and its panel screens to a Beak-owned project (no external server). Declare the model and its columns, generate the wiring with beak prepare, and open the list and form. Not for a Serverpod-backed admin; use beak-serverpod-add-model there.
---

# Add a resource

Use this when Beak owns the database (a standalone or embedded Beak app). A
Serverpod project adds models by definition class and `beak generate` instead.

## 1. Declare the model

Write one schema class under `lib/resources/<plural>/models/<name>.dart`, or
run `beak make:resource Supplier` and edit what it wrote:

```dart
@Resource(table: 'suppliers')
final class Supplier extends BeakSchema {
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  static const active = BeakBoolColumn(key: 'active', label: 'Active');
}
```

`beak prepare` writes the typed columns, fields, model and draft for this
class. Never hand-write a column string outside the schema class.

## 2. Generate

```console
$ beak prepare
```

It discovers the schema classes, writes the `.beak.dart` parts, the registry
and the panel wiring, and reports anything it could not resolve. Run
`beak doctor` when a check fails.

## 3. Declare the resource

`beak make:resource` writes a `BeakResource`; otherwise add one:

```dart
BeakResource.standard(
  const SupplierModel(),
  'Suppliers',
  navigationGroup: 'Catalog',
  columns: [SupplierModel.name, SupplierModel.active],
  filters: [
    SupplierModel.name.textFilter(label: 'Name'),
    SupplierModel.active.boolFilter(label: 'Active'),
  ],
)
```

`standard` gives you the list, detail page, create/edit forms and the metadata
aside. Pass `form:` when the generated form needs a chosen order, and `tabs:`
to split it.

Register it where the panel is built: a generated `lib/main.dart` picks up every
resource class under `lib/`; an authored one lists them in
`BeakPanel(resources: [...])`.

## 4. Migrate

```console
$ beak migrate
```

This runs `beak prepare` and applies the generated migration. A failing
migration prints its error and exits non-zero.

## 5. Prove it

- `beak doctor`, `dart format .`, `flutter analyze` and `flutter test` pass.
- A widget test opens the list over an `InMemoryBeakDataSource`.
- The route sweep visits the list, detail, create and edit routes.

## Example prompt

```text
Use the beak-add-resource skill to add a Supplier resource (name required, email, active) with a searchable table, an active filter, and the standard detail and form screens.
```
