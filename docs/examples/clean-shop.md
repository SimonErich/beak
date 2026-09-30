---
title: Clean shop
description: "Tour the clean shop, the teaching example: 20 models, exact money, invoice actions, a server-side preparer, custom pages, tests and limits."
type: example
audience: [beginner, expert, agent]
status: stable
---

# Clean shop

A small shop with a catalog, customers, orders and invoices, written the way a Beak project is meant to look after the quickstart. Most pages in this documentation quote it, so this page is the map: what it does, where each idea lives and what it leaves out.

## At a glance

| | |
| --- | --- |
| Domain | A shop: catalog with variants and attributes, customers, orders, vouchers, invoices, fulfillment policies |
| Models | 20 schema classes in `lib/resources/*/models/` |
| Resources | 11 registered in `lib/main.dart`, plus 2 custom pages (`shopOverview`, `shopOperations`) |
| Panel bootstrap | Authored: `main()` builds `BeakPanel(resources: [...])` |
| API port | 8080 |
| Auth | None, on purpose. It is a local demo |
| Database | SQLite file `beak.db` in the project folder |
| Money | Exact `BeakDecimal`, EUR, two decimals, formatted as `de_AT` |
| Seed | 3 products, 2 variants, 2 users, 1 order, 1 invoice, 2 vouchers, 3 tax rates |
| Tests | 24 in the Dart VM (API, arithmetic, migrations) and 20 widget tests |
| Read it if | You finished the [quickstart](quickstart.md) and want to see a whole application |

## Run it

```console
cd examples/clean_beak_config
flutter pub get
beak prepare
beak migrate
beak seed
beak dev
```

`beak migrate` runs the two framework migrations and then the shop's own, in name order. The shop has 22 of its own, in `lib/migrations/`:

```console
$ beak migrate
  20 models · 11 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  generated  up to date (25 files)
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260926_201252_create_companies_table
migrated  20260926_201253_create_users_table
...
migrated  20260926_235900_expand_shop_catalog
migrated  20260927_012941_create_fulfillment_policies_table
migrated  20260927_012942_create_product_images_table
migrated  20260927_230000_add_variant_combinations

$ beak seed
  20 models · 11 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  generated  up to date (25 files)
seeded  ShopSeeder
```

The seed is repeatable and leaves rows you edited alone. In a second terminal start the panel on the port the README uses:

```console
flutter run -d chrome --web-port=3000
```

To point the panel at a different API origin, add `--dart-define=BEAK_API_BASE_URL=http://host:port`. To start over, stop the server, delete `beak.db` and run `beak migrate` and `beak seed` again.

!!! note "What just happened"
    - `beak dev` regenerated the wiring (a no-op here), printed the `flutter run` line and served the API on 8080. The shop's server has one addition over the generated defaults: `lib/server.dart`, which you will meet in stop 8.
    - Every list is a `POST /api/<table>/query`. Every form save is a `POST /api/commits`. The shop turns direct writes off for its transactional tables.

## Tour

### 1. One panel, eleven resources

The shop owns its entrypoint, so the panel is a `BeakPanel` you can read top to bottom: a theme from one brand colour, one formatting policy for every date and amount, two pages and the resources.

```dart title="examples/clean_beak_config/lib/main.dart"
--8<-- "examples/clean_beak_config/lib/main.dart:shopMain"
```

Twenty models, eleven entries. The other nine (order items, variant attributes, voucher applications and so on) reach the screen through the relationships that own them, so a line item never needs its own sidebar entry to appear inside an order. `beak doctor` warns when you write a resource class and forget to list it here. [Two ways to boot a panel](../start-here/generated-or-authored.md) compares this with the generated bootstrap.

### 2. Money that never touches a double

Every amount is a `BeakDecimal`, declared once on the schema class:

```dart title="examples/clean_beak_config/lib/resources/products/models/product.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/models/product.dart:productPrice"
```

The database stores whole hundredths, the API carries the same integers, the form edits them with `inputCurrency()`, the table and the review format them with the panel's `de_AT` policy, and no line of the shop converts an amount to `double`. The seeded invoice shows what the wire sees:

```console
$ curl -s -X POST localhost:8080/api/invoices/query -H 'content-type: application/json' -d '{"table":"invoices"}'
{"items":[{"values":{"number":"INV-DEMO-2026-001","status":"issued",
  "subtotal":12300,"discount":1730,"tax":1899,"total":12469, ... }}],"total":1,"page":1,"perPage":25}
```

That is 123.00, 17.30, 18.99 and 124.69 euros. Totals over a money column are exact too: the receivables card in stop 9 calls `InvoiceModel.total.sum(...)` and the server adds integers. [Semantic fields](../models/semantic-fields.md) explains `BeakSemantic.money` and the other semantics, and [A money field](../recipes/a-money-field.md) is the short version.

### 3. A resource in a page of typed code

A resource says how a model looks in the panel. Everything it names is a generated handle, so a renamed field breaks the build where it was used:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductResourceIdentity"
```

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:listProductFilters"
```

`relationFilter()` renders a searchable picker over the related model, `boolFilter` a yes/no select and `rangeFilter` a min-max pair typed for the field. `globalSearchSources` in the same file reaches into related rows (`ProductModel.variants.search(ProductVariantModel.sku)`), which is how the header search finds a product by the SKU of one of its variants. See [Resources](../panel/resources.md), [Tables and filters](../panel/tables-and-filters.md) and [Filter builders](../reference/filter-builders.md).

### 4. Rules written once

A rule that involves more than one field lives on the schema class as a `BeakRecordRule`. The client evaluates it while you type, the server evaluates it again on save:

```dart title="examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order_item.dart:OrderItemValidationRules"
```

Behavior fills in values instead of rejecting them. Here the line label and the price follow the selected variant or product until the administrator overrides them:

```dart title="examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/models/order_item.dart:OrderItemBehavior"
```

`BeakValueBehavior.suggested` gives way to a manual edit. `BeakValueBehavior.derived`, used by the invoice actions below, does not. See [Validation](../models/validation.md) and [Model behavior](../models/behavior.md).

### 5. Forms that become wizards, tabs and read pages

The order form is written once as `BeakFormSections`, and the same sections are projected into a wizard for creating and into tabs for reading:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart:orderWizardScreen"
```

Inside a step, the line items are a nested table editor. Nothing is saved while the administrator types; the rows stay in the draft until the final Save sends one graph:

```dart title="examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart"
--8<-- "examples/clean_beak_config/lib/resources/orders/screens/order_form_wizard_screen.dart:orderItemsTableForm"
```

The invoice does the same with four sections (customer and document, line items, vouchers, review):

```dart title="examples/clean_beak_config/lib/resources/invoices/invoice_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/invoice_resource.dart:invoiceWizardAndReadScreens"
```

`drafts:` makes the wizard resumable, and `reviewBeforeSave: true` adds a review step before the commit. The drafts file is sixteen lines, and it carries the honest caveat about who owns the identity:

```dart title="examples/clean_beak_config/lib/shop_drafts.dart"
--8<-- "examples/clean_beak_config/lib/shop_drafts.dart"
```

See [Form screens](../forms/form-screens.md), [Multi-step forms](../forms/multi-step-forms.md), [Related records in forms](../forms/related-records.md) and [Drafts, review and conflicts](../forms/drafts-and-review.md).

### 6. The invoice workflow

An invoice is a draft until someone issues it. Issuing, paying and cancelling are named actions, declared once and referenced by object from screens, lists and the server:

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart:InvoiceActions"
```

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart:InvoiceBehavior"
```

Only a draft is editable, and nobody deletes an invoice. The interesting part is what the server does with a client that ignores the buttons. This test drives the real API: a forged `status: paid` is refused, `issue` succeeds and replays with the same result, `markPaid` succeeds, and cancelling a paid invoice is refused.

```dart title="examples/clean_beak_config/test/shop_api_test.dart"
--8<-- "examples/clean_beak_config/test/shop_api_test.dart:invoiceWorkflowTest"
```

An action's menu position grants nothing. The rule `availableWhen` runs on the panel to hide a button and on the server to refuse a request. [Actions](../panel/actions.md) and [Behavior and actions](../reference/behavior-and-actions.md) cover the API.

### 7. Arithmetic that adds up to the cent

Vouchers apply one after another to the remaining net amount, the reduction is allocated across the lines by largest remainder, and tax is rounded half-up per line at the end. The order of the vouchers changes the result, and the test says by how much:

```dart title="examples/clean_beak_config/test/shop_totals_test.dart"
--8<-- "examples/clean_beak_config/test/shop_totals_test.dart:voucherOrderTest"
```

`ShopTotals.calculate` is a pure function in `lib/domain/shop_totals.dart`. Three callers use the same one: the invoice form's live preview (`invoice_preview.dart`), the server's preparer (`shop_graph_preparer.dart`) and the seeder. That is why the total in the browser and the total on the invoice cannot disagree by a cent.

Prices, descriptions, rates, customer details and voucher codes are copied onto the invoice when it is saved. Editing the catalog later cannot rewrite an issued document.

### 8. The server has the last word

The browser calculates a preview. The server recalculates from the submitted graph and writes the snapshots itself, inside the transaction of the save. One file registers that:

```dart title="examples/clean_beak_config/lib/server.dart"
--8<-- "examples/clean_beak_config/lib/server.dart"
```

`preparePlan` runs `ShopGraphPreparer.prepare` on every commit. `graphOnly` closes the direct routes for the twelve tables that only make sense as part of a whole graph. Try one:

```console
$ curl -s -X PATCH localhost:8080/api/invoices/00000000-0000-4000-8000-000000000022 \
    -H 'content-type: application/json' -d '{"status":"paid"}'
{"code":"validation","message":"This resource must be saved through a graph commit.","requestId":"0490e09761d49d9f"}
```

The response is a 422. A table outside the list, such as `categories`, still takes a plain `POST`. The preparer is over 600 lines because it owns every rule that needs more than one record. The smallest instructive one is the duplicate-variant check: two variants of a product may not carry the same attribute combination, and no single row can know that.

```dart title="examples/clean_beak_config/lib/domain/shop_graph_preparer.dart"
--8<-- "examples/clean_beak_config/lib/domain/shop_graph_preparer.dart:shopVariantCombinationCheck"
```

See [Transactional business rules](../backend/graph-business-rules.md) and [Graph commits](../architecture/graph-commits.md).

### 9. Pages that are not resources

The overview is a screen assembled from data blocks. Each metric asks the database for a count:

```dart title="examples/clean_beak_config/lib/overview.dart"
--8<-- "examples/clean_beak_config/lib/overview.dart:overviewProductsMetric"
```

The Operations page reuses ordinary resource tables with a base filter, and it embeds the category import:

```dart title="examples/clean_beak_config/lib/operations.dart"
--8<-- "examples/clean_beak_config/lib/operations.dart:categoryImportBlock"
```

The receivables card is a hand-written `HookWidget` that reads the panel's own data source, formats with the panel's formatting policy and refetches when an invoice changes:

```dart title="examples/clean_beak_config/lib/widgets/receivables_card.dart"
--8<-- "examples/clean_beak_config/lib/widgets/receivables_card.dart:receivablesData"
```

`useBeakDataRevision` re-runs the query after a confirmed write to `invoices`, for instance when an invoice is marked paid from its detail page. See [Dashboards](../panel/dashboards.md), [Custom screens](../panel/custom-screens.md) and [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md).

### 10. Variants, attributes, galleries and semantic fields

Four smaller demonstrations, each in one file:

- **Gallery.** A product owns an ordered list of pictures. `galleryForm` stages uploads until Save.

  ```dart title="examples/clean_beak_config/lib/resources/products/screens/product_form.dart"
  --8<-- "examples/clean_beak_config/lib/resources/products/screens/product_form.dart:productGallery"
  ```

- **Attributes.** A category defines attribute definitions, and a product's specifications can draw on the chosen category's definitions. `lib/domain/shop_attributes.dart` adapts the shop's storage to `BeakAttributeDefinition`, and the same adapter feeds the dynamic controls and the server validation.
- **Variants.** `ShopVariantBuilder` in `lib/resources/products/screens/variant_builder.dart` previews the combinations of dimensions you enter, lets you pick some and stages them as ordinary rows in the relationship editor. The server rejects duplicates independently.
- **Semantic fields.** `FulfillmentPolicy` carries an exact amount whose currency comes from another field of the same record, and further fields for percentages, weights, file sizes, dates, times, durations, tags and typed addresses.

  ```dart title="examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart"
  --8<-- "examples/clean_beak_config/lib/resources/fulfillment/models/fulfillment_policy.dart:FulfillmentMoney"
  ```

See [Uploads and galleries](../forms/uploads-and-galleries.md), [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md) and [Semantic fields](../models/semantic-fields.md).

## Where things are

| Path | Role |
| --- | --- |
| `lib/main.dart` | The panel: theme, formatting, pages and the 11 resources |
| `lib/resources/<name>/models/` | Schema classes with columns, relationships, rules and behavior |
| `lib/resources/<name>/*_resource.dart` | How a model appears: navigation, search, filters, screens |
| `lib/resources/<name>/screens/` | Form layouts, sections, wizard steps, the variant builder |
| `lib/overview.dart`, `lib/operations.dart` | Custom pages built from blocks |
| `lib/widgets/receivables_card.dart` | A reusable custom widget |
| `lib/shop_drafts.dart` | The draft store shared by the wizards |
| `lib/domain/shop_totals.dart` | Pure invoice arithmetic, shared by client and server |
| `lib/domain/shop_graph_preparer.dart` | Authoritative cross-record rules and invoice snapshots |
| `lib/domain/shop_attributes.dart` | Category attribute adapter |
| `lib/server.dart` | Registers the preparer and closes direct writes |
| `lib/migrations/` | 22 explicit migrations, including two that upgrade an existing shop |
| `lib/seeders/shop_seeder.dart` | Repeatable demo data |
| `lib/beak/*.g.dart`, `*.beak.dart` | Generated. Never edit |
| `test/` | API, arithmetic, migration, form and widget tests |

## Features shown

| Feature | File | Docs page |
| --- | --- | --- |
| Authored panel bootstrap | `lib/main.dart` | [Two ways to boot a panel](../start-here/generated-or-authored.md) |
| Exact money and formatting | `lib/resources/products/models/product.dart` | [Semantic fields](../models/semantic-fields.md) |
| Resource classes, filters, global search | `lib/resources/products/product_resource.dart` | [Resources](../panel/resources.md) |
| Relationship filters and pickers | `lib/resources/invoices/invoice_resource.dart` | [Tables and filters](../panel/tables-and-filters.md) |
| Record rules on the schema class | `lib/resources/orders/models/order_item.dart` | [Validation](../models/validation.md) |
| Suggested and derived values | `lib/resources/orders/models/order_item.dart` | [Model behavior](../models/behavior.md) |
| Named model actions | `lib/resources/invoices/models/invoice.dart` | [Actions](../panel/actions.md) |
| Sections as wizard, tabs and read page | `lib/resources/invoices/screens/invoice_form.dart` | [Multi-step forms](../forms/multi-step-forms.md) |
| Nested table editor for owned rows | `lib/resources/orders/screens/order_form_wizard_screen.dart` | [Related records in forms](../forms/related-records.md) |
| Resumable drafts and review before save | `lib/shop_drafts.dart` | [Drafts, review and conflicts](../forms/drafts-and-review.md) |
| Gallery editor | `lib/resources/products/screens/product_form.dart` | [Uploads and galleries](../forms/uploads-and-galleries.md) |
| Dynamic attributes and variants | `lib/domain/shop_attributes.dart` | [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md) |
| Semantic and structured fields | `lib/resources/fulfillment/models/fulfillment_policy.dart` | [Semantic fields](../models/semantic-fields.md) |
| Duplicating a record | `lib/resources/products/product_resource.dart` | [Actions](../panel/actions.md) |
| Bulk edit actions | `lib/resources/products/product_resource.dart` | [A bulk edit](../recipes/a-bulk-edit.md) |
| Import with preview | `lib/operations.dart` | [Imports and bulk edits](../forms/imports-and-bulk-edits.md) |
| Dashboard metrics | `lib/overview.dart` | [Dashboards](../panel/dashboards.md) |
| A custom screen | `lib/operations.dart` | [Custom screens](../panel/custom-screens.md) |
| A custom widget on panel data | `lib/widgets/receivables_card.dart` | [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) |
| Transactional preparer and graph-only tables | `lib/server.dart`, `lib/domain/shop_graph_preparer.dart` | [Transactional business rules](../backend/graph-business-rules.md) |
| Explicit migrations that upgrade data | `lib/migrations/expand_shop_catalog.dart` | [Migrations](../backend/migrations.md) |
| Repeatable seeding | `lib/seeders/shop_seeder.dart` | [Seeding](../backend/seeding.md) |

## Tests

```console
cd examples/clean_beak_config
dart test test/shop_api_test.dart test/shop_totals_test.dart test/shop_migration_test.dart
flutter test test/order_form_test.dart test/invoice_form_test.dart test/shop_resource_test.dart \
  test/shop_widget_test.dart test/custom_shop_test.dart test/fulfillment_form_test.dart
```

The first command ran 24 tests, the second 20 (the counts of the day this page was re-verified, 2026-09-30). Both passed.

| Test file | What it proves |
| --- | --- |
| `shop_api_test.dart` | The real host on in-memory SQLite: graph saves, rollback of an invalid child, replay by save id, invoice snapshots and actions, variant rules, semantic values through HTTP and SQLite |
| `shop_totals_test.dart` | The arithmetic: voucher order, largest remainders, per-line tax, scale and range checks |
| `shop_migration_test.dart` | The additive upgrade keeps legacy records, and re-seeding keeps edits |
| `order_form_test.dart`, `invoice_form_test.dart` | The real form layouts, with previews, against an in-memory source and against the API |
| `shop_widget_test.dart`, `custom_shop_test.dart` | Responsive rendering at 375, 1280 and 1440 pixels, drafts surviving tab switches, the receivables card refreshing after a commit |

`test/support/shop_test_api.dart` is the harness worth copying: it migrates and seeds a fresh in-memory database, starts the real generated host on an ephemeral port and hands you a `BeakClient`. [Testing](../shipping/testing.md) builds on it.

## Limits

- One currency. Everything is EUR with two decimals. There is no conversion, and the `FulfillmentPolicy` currency field only shows how a per-record currency works.
- Not a business. It does not process payments, reserve inventory, produce certified invoices or PDFs, or file taxes. Those belong behind the server and screen extension points shown above.
- No auth and no policy. The API answers everyone, and the draft store uses the fixed namespace `clean-shop:local-demo`. A real host scopes drafts by user and tenant.
- No data migration from earlier versions of this example, which stored amounts as floating point. Delete `beak.db` and start again.
- The seed is small on purpose. For a large fixture, see the [Foodio admin](foodio.md).

## Continue reading

- [Foodio admin](foodio.md): a second complete application with composed lists, a five-step wizard and durable effects.
- [Showcase](showcase.md): everything the shop does not use, one page per block category.
- [Feature map](feature-map.md): find the file that demonstrates any feature.
- [Tutorial](../tutorial/index.md): build the first three shop resources yourself.
