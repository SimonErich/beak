# Columns and validation

> Add a Product with exact money and a rule, then watch the form and the server refuse the same bad value with the same message.

Categories were two text fields. Products bring money, a yes/no flag and a rule that must hold, so this chapter is about where each of those is written and who enforces it. The answer to the second part is short: the form checks, and then the server checks again, using the same Dart.

## What you'll build

- a `Product` schema with five fields, one of them exact money,
- a `ProductResource` that puts Products above Categories in the Catalog group,
- a `products` table, created by a migration you can read,
- a rule (`price` cannot be negative) that you watch refuse a value twice, once in the form and once at the API.

## Before you start

You need chapter 1 finished: a `shop` project with Categories migrated and `beak doctor` green. If `beak dev` is still running from last time, leave it. It does not watch files, so you restart it after the migration below.

## Declare the schema

A product has a name, a price, an optional SKU and description, and an on/off switch. Create `lib/resources/products/models/product.dart`:

```dart title="lib/resources/products/models/product.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';

/// Product schema; all metadata and typed helpers are generated.
@Resource()
final class Product extends BeakSchema {
  /// Product name used in picker suggestions.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Current catalog unit price, exact and in euros.
  @Column(
    label: 'Net price',
    semantic: BeakSemantic.money(currency: 'EUR'),
    sortable: true,
    rules: [BeakMin(0)],
  )
  late final BeakDecimal price;

  /// Optional stock-keeping identifier for the base product.
  @Column(searchable: true)
  late final String? sku;

  /// Catalog description.
  late final String? description;

  /// Whether this product can be sold.
  @Column(defaultValue: true)
  late final bool active;
}
```

The Dart type still picks the column, and nullability still decides what is required. The new parts are the price, the default and the rule:

| Field | Column | Required | What else it says |
| --- | --- | --- | --- |
| `name` | single-line text | yes | Searchable and sortable, and `@Display` makes it the product's label in pickers and page titles. |
| `price` | integer, holding money | yes | `BeakSemantic.money(currency: 'EUR')` says the value is an amount of euros, `BeakMin(0)` says it cannot be negative. |
| `sku` | single-line text | no | Searchable. |
| `description` | single-line text | no | No annotation at all, which is valid. Declare it `BeakText?` instead of `String?` for a paragraph input. |
| `active` | on/off switch | yes | `defaultValue: true`, so a new product starts on sale. |

### Why the price is not a double

A `double` cannot hold 0.10 exactly, and an order total that is off by a cent is a bug report you do not want. `BeakDecimal` is an integer count of units at a scale: `BeakDecimal(1290, scale: 2)` is 12.90, and every operation is integer arithmetic. The money semantic adds the currency, so the form shows `EUR`, and the database stores the integer.

Beak writes the column for you. This is what `price` became in the generated part file:

```dart title="examples/clean_beak_config/lib/resources/products/models/product.beak.dart"
  static const BeakIntColumn price = BeakIntColumn(
    key: 'price',
    label: 'Net price',
    rules: [BeakRequired(), BeakMin(0)],
    semantic: BeakSemantic.money(currency: 'EUR'),
    sortable: true,
  );
```

`BeakRequired()` came from the non-nullable type, `BeakMin(0)` is your rule, and both sit in one list that the form and the server read. That list is the whole trick behind "validated twice".

### Rules that look at more than one field

`BeakMin(0)` sees one value. A rule that compares fields, such as "a promotion cannot end before it starts", is a record rule and lives in a static getter on the class instead. Products do not need one, but the shop's fulfillment policy has two, and they are worth reading once:

```dart
/// Conditions shared by local validation and authoritative API writes.
static List<BeakRecordRule> get validationRules => [
  BeakAfterField(
    FulfillmentPolicyModel.promotionEndsAt,
    FulfillmentPolicyModel.promotionStartsAt,
    inclusive: true,
  ),
  BeakRequiredIf(
    FulfillmentPolicyModel.promotionEndsAt,
    when: BeakWhen.present(FulfillmentPolicyModel.promotionStartsAt),
  ),
];
```

Every field reference in there is a generated `FulfillmentPolicyModel.field`, so a misspelled field is a compile error and not a rule that silently never fires. [Validation](../models/validation.md) covers the whole family, including the ones that ask the database.

## Add the resource

The resource is the same five lines as last time, with a different model, title and icon. Create `lib/resources/products/product_resource.dart`:

```dart title="lib/resources/products/product_resource.dart"
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'models/product.dart';

/// Catalog management.
final class ProductResource extends BeakResource {
  /// Creates the products section.
  ProductResource()
    : super(
        model: const ProductModel(),
        title: 'Products',
        icon: const BeakIconToken(OiIcons.package),
        navigationGroup: 'Catalog',
        navigationRank: 3,
      );
}
```

Both resources share `navigationGroup: 'Catalog'`. The lower `navigationRank` sorts first, so Products (3) sits above Categories (5).

Register it in `lib/main.dart`, next to the category:

```dart title="lib/main.dart"
import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';

import 'resources/categories/category_resource.dart';
import 'resources/products/product_resource.dart';

/// Boots the panel.
void main() => runApp(buildPanel());

/// The panel, and every resource it shows.
///
/// This file is yours: `beak prepare` never rewrites it, so add each
/// resource class you write to `resources`.
///
/// [dataSource] replaces the HTTP-backed source, so a widget test
/// can pump this exact panel against an in-memory one.
BeakPanel buildPanel({BeakDataSource? dataSource}) => BeakPanel(
  title: 'Shop',
  resources: [ProductResource(), CategoryResource()],
  dataSource: dataSource,
);
```

## Run it

`beak migrate` runs `beak prepare` first, so it writes the part file and the migration and then applies it:

```bash
beak migrate
```

```console
$ beak migrate
  2 models · 2 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  generated  4 of 8 files
migrated  20260929_174339_create_products_table
```

Only the products migration ran. The categories one is already in the ledger, and `beak migrate status` would show all four as applied. Start the API again (stop the old one first if it is still running), and the panel in a second terminal:

```bash
beak dev
```

```bash
flutter run -d chrome
```

The sidebar shows Products above Categories. Open Products and press Create. The form has a Name, a Net price with `EUR` at its right edge, a Sku, a Description and an Active switch that starts on. Type `-5` into the price and press Save.

Nothing leaves the browser. The form marks Name with `This field is required.` and the price with `Must be at least 0.`, both from the rule list above.

Now go around the form. A browser is not a security boundary, and anyone with `curl` walks around it:

```bash
curl -s -i -X POST localhost:8080/api/products \
  -H 'content-type: application/json' \
  -d '{"price":-1290}'
```

```text
HTTP/1.1 422 Status 422
{"code":"validation","message":"Validation failed for \"products\".","fieldErrors":{"name":["This field is required."],"price":["Must be at least 0."]},"requestId":"56a7c19dabe43000"}
```

The server refused it with the same two messages, keyed by the column name on the wire (`name`, `price`). (`-i` also prints the response headers. The blocks on these pages keep the status line and the body.) Try a price that looks reasonable to a human:

```bash
curl -s -X POST localhost:8080/api/products \
  -H 'content-type: application/json' \
  -d '{"name":"Espresso Beans","price":12.9}'
```

```json
{"code":"validation","message":"Validation failed for \"products\".","fieldErrors":{"price":["Invalid money value."]},"requestId":"d02d82338207395e"}
```

Here is the price of exactness, and Beak does not hide it: over the wire a money amount is the stored integer, so 12.90 euros is `1290`. The panel converts for you. A script has to do it itself.

```bash
curl -s -i -X POST localhost:8080/api/products \
  -H 'content-type: application/json' \
  -d '{"name":"Espresso Beans","price":1290,"sku":"ESP-001"}'
```

```text
HTTP/1.1 201 Created
{"values":{"id":"ab8bf8c4-7c0e-4310-bc3d-1b484dc18859","name":"Espresso Beans","price":1290,"sku":"ESP-001","description":null,"active":true},"relations":{}}
```

`active` is `true` because you left it out and the default filled it in. The id differs on your machine. Reload Products in the panel and the row is there, with the price shown as `€12.90` and Active as a Yes badge.

> **Note: What just happened**
>
> - You wrote one rule list and got two enforcers. The form runs it before sending and the server runs it again on arrival, from the same Dart, so a rule cannot be right in one place and missing in the other.
> - The server is the door and the form is a courtesy. That is why the `curl` call was refused with the form nowhere in sight.
> - `Product` needed no code for a money input, a currency label or an amount in the table. The semantic on the field chose all three.

> **Question: What this skipped**
>
> - Every column type and what `@Column` accepts: [Fields](../models/fields.md).
> - Money, percentages, dates and durations, and what each stores: [Semantic fields](../models/semantic-fields.md).
> - Uniqueness, existence checks and record rules, with the errors they return: [Validation](../models/validation.md). The shop's product variants use `unique: true` on their SKU; the products here do not.

## Checkpoint

```bash
beak doctor
```

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 2 models · 2 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  OK   lib/main.dart lists every resource class
  OK   generated files up to date
  OK   every model has a migration
  ...
All checks passed.
```

You added two files and a line in `main.dart`, and the project gained a table, a form that says no, and an API that says no as well. The next chapter connects the two resources: a product belongs to a category, and a category owns a list of attribute definitions.

## Continue reading

- [Related records](03-relationships.md): link products to categories and edit a category's attributes in its own form.
- [Validation](../models/validation.md): the three layers a rule can live in, and the errors each one returns.
- [Semantic fields](../models/semantic-fields.md): exact money, percentages, dates and lists.
