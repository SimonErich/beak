---
title: Related records
description: Link products to categories, give categories an owned list of attribute definitions, and edit both from one form that saves in a single request.
type: tutorial
audience: [beginner]
status: stable
---

# Related records

Products and categories exist side by side and know nothing about each other yet. This chapter links them, adds a second kind of link (rows that belong to one category and to nothing else), and changes an existing table without losing a row.

## What you'll build

- `Product.category`: a product points at a category it shares with other products.
- `Category.attributes`: a category owns a list of attribute definitions, such as "Roast level".
- A migration for the new column, scaffolded from the difference between your schema and the database.
- A category form with an editable table of attributes, and a product form that can create a category on the spot.

## Before you start

You need chapter 2 finished, with Products and Categories migrated. Stop `beak dev` if it is still running; you change the schema below and it does not watch files.

## Two kinds of link

A link in Beak is one of two things, and the difference decides how the form treats it.

| | Shared | Owned |
| --- | --- | --- |
| Example | A product and its category | A category and its attribute definitions |
| Other rows may point at the same record | Yes, many products share a category | No, the rows exist for this parent alone |
| Annotation | `@BelongsTo` on the product | `@HasMany(owned: true)` on the category, `@BelongsTo` on the child |
| In the form | A picker, cleared to unlink | A table, and removing a row deletes it once the parent is saved |
| When the category is deleted | Products stay, their link clears (`setNull`) | Attributes go with it (`cascade`) |

The rest of the chapter builds one of each.

## Declare the owned side

A category attribute is a name, a value type, an optional list of choices and a required flag. It points back at its category. Create `lib/resources/categories/models/category_attribute.dart`; the file is the shop's, unchanged:

```dart title="lib/resources/categories/models/category_attribute.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/models/category_attribute.dart"
```

Two things are new here. `AttributeValueType` is an enum, so the form gets a select and any table a badge without you writing either. And the `@BelongsTo` on `category` is the side that owns the database column, `category_id`, together with its delete rule: `cascade` means the database removes an attribute when its category goes.

Now the parent. Add the import and the `attributes` list to `lib/resources/categories/models/category.dart`:

```dart title="lib/resources/categories/models/category.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'category_attribute.dart';

part 'category.beak.dart';

/// Catalog grouping with reusable attribute definitions.
@Resource()
final class Category extends BeakSchema {
  --8<-- "examples/clean_beak_config/lib/resources/categories/models/category.dart:CategoryFields"

  --8<-- "examples/clean_beak_config/lib/resources/categories/models/category.dart:CategoryAttributes"
}
```

`owned: true` is a promise about editing: these rows are changed through their category, so the category form may add, edit and remove them. It deletes nothing by itself. The `cascade` on the child's `@BelongsTo` does that, and the shop repeats it on the `@HasMany` so either class reads the same.

## Declare the shared side

A product may have a category, so the field is nullable. Add the import and the field to `lib/resources/products/models/product.dart`:

```dart title="lib/resources/products/models/product.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../categories/models/category.dart';

part 'product.beak.dart';

/// Product schema; all metadata and typed helpers are generated.
@Resource()
final class Product extends BeakSchema {
  --8<-- "examples/clean_beak_config/lib/resources/products/models/product.dart:ProductFields"

  --8<-- "examples/clean_beak_config/lib/resources/products/models/product.dart:ProductCategory"
}
```

`Category?` makes the link optional. `onDelete: BeakOnDelete.setNull` means deleting a category keeps its products and clears their category, which is what a shop wants. `inverse: false` stops Beak from also giving `Category` a `products` list; categories do not need to know.

You declared no column. `@BelongsTo` adds `category_id` to `products`, with an index and a foreign key. It also gives you `ProductModel.category` as a typed reference, and `ProductModel.category.name` reaches through it to the category's name. Chapter 5 uses that.

## Change the database

Generate, then ask `beak doctor` what the database is missing:

```bash
beak prepare
```

```console
$ beak prepare
  3 models · 2 resource classes · 0 screens · 0 overrides
  generated  7 of 11 files
  agents     up to date · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md
```

```bash
beak doctor
```

```console
$ beak doctor
  OK   every model has a migration
  ...
  WARN CategoryAttribute declares table "category_attributes", which the database does not have
       → write a migration with `beak make:migration`, then `migrate`
  WARN products.category_id is declared by Product.categoryId but missing from the database
       → write a migration with `beak make:migration`, then `migrate`
  WARN products.category_id backs Product.category but is missing from the database
       → write a migration with `beak make:migration`, then `migrate`
  ...
All checks passed.
```

Warnings, not failures, and they are two different problems. The first has a fix waiting: `beak prepare` wrote `create_category_attributes_table.dart` for the new model, exactly as it did for categories. The remedy line is slightly off there, since nothing needs writing. The other two are one problem seen twice. The `products` table exists, and a create-table migration never runs again, so a column you add later needs a migration of its own.

Apply the pending one first:

```bash
beak migrate
```

```console
$ beak migrate
  3 models · 2 resource classes · 0 screens · 0 overrides
  generated  up to date (7 files)
migrated  20260929_174548_create_category_attributes_table
```

Then let Beak write the second from the difference between your schema classes and the database:

```bash
beak make:migration AddCategoryToProducts --from-drift
```

```console
$ beak make:migration AddCategoryToProducts --from-drift
  created lib/migrations/add_category_to_products.dart
  run `beak migrate` to apply it
```

Read it before you run it. It is yours from now on, like every migration:

```dart title="add_category_to_products.dart (generated, trimmed)"
  @override
  Future<void> upSchema(Schema schema) async {
    final live = await schema.adapter.introspectSchema();
    if (!_has(live, 'products', 'category_id')) {
      await schema.alter('products', (table) {
        BeakBlueprint.defineColumn(
          table,
          ProductColumns.categoryId,
          isForeignKey: true,
        );
        final relation = ProductRelations.category;
        table.index([relation.foreignKey]);
        table.foreign(
          column: relation.foreignKey,
          references: 'id',
          onTable: relation.relatedTable,
          onDelete: wormOnDelete(relation.onDelete),
        );
      });
    }
  }
```

The `if` is there on purpose. `create_products_table` reads `ProductModel` as it is today, so on a fresh database it already creates `category_id`, and an unguarded `alter` would then fail with a duplicate column. On your database the guard finds the column missing and adds it.

```bash
beak migrate
```

```console
$ beak migrate
  3 models · 2 resource classes · 0 screens · 0 overrides
  generated  1 of 7 files
migrated  20260929_174611_add_category_to_products
```

`beak doctor` now says `the database matches the schema classes`, and the timestamps in your file names differ from these.

## Give the forms a layout

Start `beak dev` and the panel if you want to look before you continue. Without a layout Beak still helps. The product form has grown a Category picker at the bottom, searching by the category's `@Display` field, because a to-one link needs no decisions. The category form shows a Name and a Description and nothing else. An owned collection is a table, and Beak cannot guess which of the child's fields belong in its columns.

So the category form needs a layout. The shop's is one function, and this is the whole file:

```dart title="lib/resources/categories/screens/category_form.dart"
--8<-- "examples/clean_beak_config/lib/resources/categories/screens/category_form.dart"
```

Three ideas are in there. `BeakTabs` splits the form into Overview and Attribute definitions. `CategoryModel.attributes.tableForm(...)` is the table editor: `children` are the columns, `advancedForm` holds the fields that would make the row too wide, and `removeBehavior: BeakRemoveBehavior.deleteOwned` says removing a row deletes the owned child. And the `includeAttributes` flag exists so that the same layout can be reused without the second tab, which the product form does in a moment.

Every input starts from a generated reference, `CategoryModel.name.inputText()` or `CategoryAttributeModel.valueType.input()`. There is no string field name anywhere, so a rename shows up as a compile error and not as an empty input.

Hand the layout to the resource. `screens:` takes the screens you want to configure, and the ones you leave out keep their defaults. The list page stays as it was:

```dart title="lib/resources/categories/category_resource.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/category.dart';
import 'screens/category_form.dart';

/// Catalog organization and reusable attribute definitions.
final class CategoryResource extends BeakResource {
  /// Creates the categories section.
  CategoryResource()
    : super(
        --8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryIdentity"
        screens: [
          --8<-- "examples/clean_beak_config/lib/resources/categories/category_resource.dart:CategoryFormScreen"
        ],
      );
}
```

One form serves three roles. `BeakScreenRole.read`, `create` and `edit` share the layout, so the detail page, the create form and the edit form cannot drift apart.

The product form is smaller. Two cards side by side, with the category picker taught one new trick:

```dart title="lib/resources/products/screens/product_form.dart"
import 'package:beak/panel.dart';
import '../../categories/screens/category_form.dart';
import '../models/product.dart';

/// Shared product layout: core data, organization and pricing.
BeakFormLayout productForm() => BeakFormLayout(
  children: [
    BeakColumns(
      children: [
        --8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:ProductDetailsCard"
        BeakCard(
          title: 'Organization and pricing',
          children: [
            --8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:productCategoryPicker"
            --8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:ProductPriceInput"
            --8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:ProductActiveInput"
          ],
        ),
      ],
    ),
  ],
);
```

`exclusive: false` lets the picker offer to create a record that does not exist yet, and `createForm:` says what that dialog contains: the category layout, without its attributes tab. The shop's product form also has a tax rate picker, a gallery and tabs. This one keeps the pieces that fit your project.

```dart title="lib/resources/products/product_resource.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/product.dart';
import 'screens/product_form.dart';

/// Catalog management.
final class ProductResource extends BeakResource {
  /// Creates the products section.
  ProductResource()
    : super(
        --8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductResourceIdentity"
        screens: [
          BeakFormScreen(
            --8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductFormLayout"
          ),
        ],
      );
}
```

## Run it

Nothing new to migrate. Start the API and the panel:

```bash
beak dev
```

```bash
flutter run -d chrome
```

Open Categories and edit `Coffee`, the category you created with `curl` in chapter 1: press the pencil icon in its row. The form now has two tabs. Switch to Attribute definitions and press Add Attributes. A dialog opens with the fields of one attribute. Give it the name `Roast level` and press Apply: the row lands in the table with a Name, a Value Type and a Required switch. Then press Save.

Everything before Save happened in the browser. The API log of `beak dev` shows what reached the server:

```console
[0d47ce336c1294ec] POST /api/categories/query -> 200 (1ms)
[afcaf43766ef27a1] GET /api/categories/capabilities -> 200 (1ms)
[35996a226b454ffb] GET /api/category_attributes/capabilities -> 200 (1ms)
[f9b6a0f971838f37] OPTIONS /api/commits -> 204 (0ms)
[f7ff6c3d0c00d367] POST /api/commits -> 200 (33ms)
```

Reads while the form opened, then one write. Adding the row sent nothing, because the draft holds every change until Save. Chapter 4 opens that request up.

Now Products. Edit `Espresso Beans` and open the Category picker: it lists `Coffee`. Pick it and Save. Then press Create for a new product, open the picker and type `Tea`. The list is empty and offers `Create "Tea"`. Pick that, and the dialog opens with the name already filled in and only the Overview tab. Press Apply, give the product a name (`Green Tea`) and a price (`8.5`), and press Save. One `POST /api/commits` carries the new category and the product that points at it.

Relations are never loaded on their own. Ask for the category and you get it:

```bash
curl -s -X POST localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table":"products","relations":[{"relation":"category","filter":null,"nested":[]}]}'
```

```json
{"items":[{"values":{"id":"ab8bf8c4-7c0e-4310-bc3d-1b484dc18859","name":"Espresso Beans","price":1290,"sku":"ESP-001","description":null,"active":true,"category_id":"67060d38-2d5d-499e-9b85-b339ff3c51cd"},"relations":{"category":[{"values":{"id":"67060d38-2d5d-499e-9b85-b339ff3c51cd","name":"Coffee","description":"Beans and blends"},"relations":{}}]}},{"values":{"id":"5eeac3e8-c806-4cbc-8590-7e306dc7a8a6","name":"Green Tea","price":850,"sku":null,"description":null,"active":true,"category_id":"3555833c-8b7a-4fcc-8d85-fb602808266c"},"relations":{"category":[{"values":{"id":"3555833c-8b7a-4fcc-8d85-fb602808266c","name":"Tea","description":null},"relations":{}}]}}],"total":2,"page":1,"perPage":25}
```

Each product now carries its category under `relations`, and `category_id` sits in `values` as before. Leave `relations` out of the query and every record comes back with `"relations":{}` while `category_id` is still there. Beak does not lazy-load: a relation is on the record because the query asked for it, and the panel's tables ask for exactly the ones their columns show.

Finally the delete rules, which are the second row of the table above. Delete the `Tea` category with the trash icon in its row: Green Tea stays, and its Category picker is empty when you open it. That is `setNull`. Delete a category that owns attributes and its attributes go with it, which is `cascade`. Both are foreign-key rules in the database, so a script or a second admin gets the same result. Try the second one on a category you made for the purpose, not on `Coffee`.

!!! note "What just happened"
    - Two `@BelongsTo` annotations and one `@HasMany(owned: true)` gave you a picker, a table editor, two foreign keys and the delete behavior. No join and no column name appears in your code.
    - Nested edits are staged. Rows added, changed or removed in the category form live in a draft until Save, and Save sends the whole draft as one graph commit that either applies fully or not at all.
    - Adding a column to an existing table is a migration you scaffold and read, not a side effect of running the app.

!!! question "What this skipped"
    - Has-one, many-to-many and the `foreignKey:` override: [Relationships](../models/relationships.md).
    - The picker's other modes, cards, dependent options and galleries: [Related records in forms](../forms/related-records.md). A picker whose choices depend on another field (an order's delivery profile must belong to its customer) is the recipe [A belongs-to picker](../recipes/a-belongs-to-picker.md).
    - The table editor in depth: [A nested table editor](../recipes/a-nested-table-editor.md).
    - The shop also gives products variants and specifications, edited the same way. They are not in your project, so `ProductModel` here has no `variants`.

## Checkpoint

```bash
beak doctor
```

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 3 models · 2 resource classes · 0 screens · 0 overrides
  OK   lib/main.dart lists every resource class
  OK   generated files up to date
  OK   every model has a migration
  ...
  OK   the database matches the schema classes
  ...
All checks passed.
```

Your project has three schema classes, two resources, four migrations of your own, and a form that saves a category, its attributes and a product in one request. The database is still nearly empty. Chapter 4 fills it and looks at the API.

## Continue reading

- [Seeding and the API](04-seeding-and-the-api.md): a seeder for the shop data, and the API called by hand.
- [Relationships](../models/relationships.md): every link kind, `onDelete`, `inverse` and `owned` in one place.
- [Related records in forms](../forms/related-records.md): pickers, cards and inline creation.
