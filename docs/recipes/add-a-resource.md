---
title: Add a resource
description: Scaffold a schema and a resource class with beak make:resource, migrate the table and register the section in a generated or an authored panel.
type: recipe
audience: [beginner, expert, agent]
status: stable
---

# Add a resource

You want one more section in the panel: a table, a form and a REST API for a new model. `beak make:resource` writes the schema class and the resource class, `beak migrate` creates the table, and one line registers the section if you own `lib/main.dart`.

## Recipe

Run this in a project that `beak create` made. `--fields` takes `name:kind` pairs (`string`, `text`, `int`, `decimal`, `bool`, `datetime`), and a trailing `!` makes the field required:

```console
$ beak make:resource Product --fields name:string!,price:decimal!,active:bool
  created lib/resources/products/models/product.dart
  created lib/resources/products/product_resource.dart
  1 model · 1 resource class · 0 screens · 0 overrides
  generated  8 of 9 files
```

The schema class is the only place the fields exist. This is what the command wrote (imports and the `part` line trimmed):

```dart
/// A product.
@Resource(timestamps: true)
final class Product extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// Price.
  @Column(sortable: true)
  late final BeakDecimal price;

  /// Active.
  @Column(filterable: true)
  late final bool? active;
}
```

`beak prepare` ran as part of the command. It generated the typed columns, the model, `ProductModel` and the create-table migration `lib/migrations/create_products_table.dart`. Nothing is in the database yet, so apply it:

```console
$ beak migrate
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_121946_create_products_table
```

The first two lines are Beak's own tables for graph-commit receipts and the effects outbox. They appear once per database.

Now the panel has to show the section. That depends on who owns `lib/main.dart`, see [Two ways to boot a panel](../start-here/generated-or-authored.md).

=== "Generated panel"

    Nothing to register. `lib/main.dart` boots `BeakApp`, and `beak prepare` builds the panel from every model it finds. A `BeakResource` class replaces the default resource of the model it configures, so `ProductResource` is picked up by being there. Every other model keeps its generated default.

    To give a model that has only a default its own class later, `beak eject resource <table>` writes the same scaffold:

    ```console
    $ beak eject resource products
      created lib/resources/products/product_resource.dart

      run `beak prepare` to wire it up
    ```

=== "Authored panel"

    `beak prepare` never rewrites an authored `lib/main.dart`, so the command prints the two lines you add (here for a `Category`):

    ```console
    $ beak make:resource Category --fields name:string!
      created lib/resources/categories/models/category.dart
      created lib/resources/categories/category_resource.dart
      2 models · 2 resource classes · 0 screens · 0 overrides
      generated  5 of 9 files

      lib/main.dart is yours; register the resource there:
        import 'resources/categories/category_resource.dart';
        const CategoryResource(),  // in resources: [...]
    ```

    Forget them and the section never appears. `beak doctor` is the safety net:

    ```console
    $ beak doctor
      WARN CategoryResource (lib/resources/categories/category_resource.dart) is not listed in lib/main.dart's resources: [...], so the panel never shows it
           → add CategoryResource() to the resources list in lib/main.dart; `beak prepare` never rewrites an authored entrypoint
    ```

    The shop example is an authored panel. Its whole panel setup is a list of resource objects:

    ```dart title="examples/clean_beak_config/lib/main.dart"
    --8<-- "examples/clean_beak_config/lib/main.dart:shopMain"
    ```

The scaffolded resource class is a model, an icon and nothing else. The panel already gives it a table, a create form, an edit form and a show page from the schema. What you add to the class is presentation: a title, a navigation group, search sources, filters and screens. The shop's `CategoryResource` is a complete small one:

```dart title="examples/clean_beak_config/lib/resources/categories/category_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryResource"
```

Start the API, then the panel in a second terminal:

```console
$ beak dev
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
listening on http://0.0.0.0:8080
```

## How it works

- The schema class carries the fields, the required-ness (a non-nullable Dart type is required), the searchable and sortable flags and the relations. The table cell, the form input, the filter, the API validation and the migration all read it.
- `make:resource` writes two files and runs `beak prepare`. The schema goes to `lib/resources/<plural>/models/<name>.dart`, the resource class next to it. The generated wiring in `lib/beak/*.g.dart` and `*.beak.dart` is never edited by hand.
- Migrations are yours once written. `beak prepare` writes a create-table migration for any model whose table nothing creates, then leaves it alone. Change the schema later and you add a migration; see [Migrations](../backend/migrations.md).
- The resource class replaces the default for its model. It is matched by the table its own `model` reports, so the class name is free.
- The API exists as soon as the model does. `POST /api/products/query` answers whether or not the panel lists the section.

## Variations

| You want | Do this |
| --- | --- |
| Start from an empty project | `beak create shop --no-example`, then `make:resource`. The default `beak create` writes a `Note` first. |
| A money field or a relation | `price:decimal` is an exact `BeakDecimal` at scale 2, but knows no currency, and `--fields` has no relation kind. Edit the schema class after scaffolding: see [A money field](a-money-field.md) and [A belongs-to picker](a-belongs-to-picker.md). |
| Hide the section but keep the model | [Hide a resource](hide-a-resource.md) |
| Custom table columns, filters, form layout | `BeakTableScreen` and `BeakFormScreen` in the resource's `screens:`, see [Resources](../panel/resources.md) |

`--fields price:decimal` gives a `BeakDecimal`, an exact number stored as integer units, so a total adds up. For a measurement that may round, write `weight:double` and get a Dart `double`.

The table name is the plural of the class name: `Category` becomes `categories` and `Person` becomes `people`. The pluraliser only knows the regular rules and a short list of irregular words, so read the name in the printed file list before you migrate.

## Verify

The API answers, with an empty page:

```console
$ curl -s -X POST localhost:8080/api/products/query -H 'content-type: application/json' -d '{"table":"products"}'
{"items":[],"total":0,"page":1,"perPage":25}
```

The panel lists the section. This test ran in a scratch project (imports trimmed) against the authored `buildPanel` that `beak eject main` writes. A generated panel pumps `BeakApp(dataSource: source)` instead, as the scaffolded `test/widget_test.dart` does:

```dart
testWidgets('the products section lists a seeded product', (tester) async {
  final source = InMemoryBeakDataSource(registry: buildBeakRegistry())
    ..seed(const ProductModel(), [
      const ProductModel().record([
        ProductModel.id.to('p1'),
        ProductModel.name.to('Espresso Beans'),
        ProductModel.price.to(BeakDecimal.parse('12.50')),
      ]),
    ]);
  await tester.pumpWidget(buildPanel(dataSource: source));
  await tester.pumpAndSettle();
  expect(find.text('Espresso Beans'), findsOneWidget);
});
```

```console
$ flutter test
00:01 +2: All tests passed!
```

`beak doctor` ends with `All checks passed.` when the model, the migration and the registration agree.

## Continue reading

- [An enum badge column](an-enum-badge-column.md) gives the new resource a status column that reads at a glance.
- [A money field](a-money-field.md) gives the scaffolded exact price a currency and a locale.
- [Defining models](../models/defining-models.md) covers every annotation the schema class takes.
