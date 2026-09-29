# Clean Beak Shop

A working shop administration example built from model definitions, resource
configuration and reusable layouts. `lib/main.dart` registers eleven resources and
a live operational overview, a custom Operations screen and one display policy. Beak owns fetching, form state, validation, related drafts,
CRUD routes, global search, filtering and refresh after successful mutations.

## Run

From this directory:

```sh
flutter pub get
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
dart run bin/serve.dart
```

In a second terminal:

```sh
flutter run -d chrome --web-port=3000
```

The API uses `http://localhost:8080` and a local SQLite `beak.db`. The seed is
repeatable and preserves existing records. Migrations upgrade the original clean
example without deleting its customers, products or orders. No login is required
by this local demonstration. Set `BEAK_API_BASE_URL` with `--dart-define` for a
different API origin.

## Explore the shop

The overview shows live catalog, fulfillment, payment and stock counts, with
upcoming deliveries and invoices awaiting payment. Metrics and tables refresh
after successful saves and deletes.

- **Products:** Overview, Images, Specifications and Variants tabs; category and price
  filters; independent variant SKUs, prices, stock and attributes. Nested changes
  remain local until Save. The separate Variants resource associates existing
  variants with their product.
- **Product galleries:** uploaded pictures, descriptions and persisted ordering,
  with local staging until Save and automatic retry/cancel handling.
- **Fulfillment policies:** exact money with per-record currency, percentages,
  weights, file sizes, date/time/duration fields, tags, region checkboxes,
  three-state signature requirements, typed addresses and JSON provider options.
  Shared model rules validate promotional date dependencies on both client and API.
- **Categories:** reusable attribute definitions with text, number, boolean or
  choice values. Product specifications can reference the category definitions.
  Required definitions and value types are enforced when products are saved.
  Inline category creation sets up basic details; manage definitions in Categories.
- **Orders:** customer selection, dependent delivery profile, fulfillment status,
  catalog/variant/custom lines, price adjustments and a final review.
- **Invoices:** four steps for billing details, lines, ordered vouchers and review.
  Include products, variants, delivery charges and custom services on the same
  document. Drafts can change; issued documents retain their historical content.
  Named Issue invoice, Mark paid and Cancel invoice actions enforce valid transitions.
- **Vouchers:** fixed and percentage discounts, active dates, minimum subtotal and
  a maximum reduction. Multiple vouchers apply in ascending, unique Position order.
- **Customers, companies and delivery profiles:** shared view/create/edit layouts,
  reusable addresses and customer-specific associations.
- **Tax rates:** configurable exclusive rates reused by products and invoice lines.

Global search finds references, customers, company names, product names/SKUs,
category names, product/variant attribute values, voucher codes and invoice line
text. Filters use typed model helpers, including relationship selectors, numeric
ranges, dates, enums and both boolean values.

## Configuration map

```text
lib/main.dart                       resources, theme and global date/money formats
lib/overview.dart                   responsive live metrics and operational tables
lib/operations.dart                 custom fulfillment, stock and category import screen
lib/widgets/receivables_card.dart    reusable custom widget with scoped data/format/refresh
lib/shop_drafts.dart                 resumable local demo drafts
lib/resources/<name>/models/        schema, rules, relationships and generated helpers
lib/resources/<name>/*_resource.dart navigation, search, filters and table fields
lib/resources/<name>/screens/       shared forms, tabs, cards and wizard steps
lib/domain/shop_totals.dart          pure exact-decimal invoice arithmetic
lib/domain/shop_graph_preparer.dart  authoritative cross-record shop rules
lib/server.dart                     one registration of that business policy
lib/migrations/                     explicit schema changes, including upgrades
lib/seeders/shop_seeder.dart         repeatable catalog and realistic sample documents
```

For example, a list filter is `ProductModel.category.relationFilter()`, a money
input is `ProductModel.price.inputCurrency()`, and a nested editor is
`ProductModel.variants.tableForm(...)`. A product picker can request its tax rate
with `ProductModel.options().including([ProductModel.taxRate])`. There are no
widget-level HTTP calls, handwritten CRUD endpoints or per-screen save handlers.

The shop's calculations are application-specific and live once in `domain/`.
The frontend uses the same pure calculator for its preview. A single server-side
`preparePlan` registration validates the complete graph and writes authoritative
snapshots within its transaction. Protected tables reject direct CRUD writes that
would bypass the policy. Beak's normal delete action uses a native graph commit.

## Exact money

Every amount is a `BeakDecimal` declared once on its schema class with
`@Column(semantic: BeakSemantic.money(currency: 'EUR'))`: product and variant
prices, order and invoice lines, discounts, voucher limits and every saved
invoice total. Tax rates and voucher values that are not euro amounts use
`BeakSemantic.exactDecimal(scale: 2)`. The database stores whole hundredths, the
API transports the same integers, forms edit them with `inputCurrency()`, tables
and reviews format them with the panel's `de_AT` currency policy, and no code in
this example converts an amount to a `double`. `BeakScalarField.sum` totals a
money column exactly on the server.

The example is unreleased, so it ships no data migration from the earlier
floating-point columns. Use a fresh database: delete `beak.db`, then run
`dart run bin/migrate.dart migrate` and `dart run bin/migrate.dart db:seed`
again. The migrations derive each column from its model, so a fresh database
always matches the schema classes.

## Invoice arithmetic and history

This example deliberately uses one currency, EUR, with two decimal places:

1. Multiply whole-unit quantities by net unit prices, then subtract line discounts.
2. Apply vouchers sequentially to the remaining net subtotal. Cap reductions at
   the remaining amount and any configured maximum.
3. Allocate each voucher proportionally across lines using largest remainders.
4. Add exclusive tax and round half-up to cents per line.

Prices, descriptions, rates, customer details, voucher codes and totals are saved
as snapshots. Editing catalog data cannot rewrite an issued invoice. The server
recalculates amounts instead of trusting browser-supplied totals. Saved drafts keep
their tax-rate snapshots until the tax, product or variant selection changes.
The server validates variant
ownership and voucher eligibility, and retains save receipts for idempotent replay.
The documented rounding policy follows the line-level option described in
[Stripe's tax-rate documentation](https://docs.stripe.com/tax/tax-rates).

Dates display as `dd.MM.yyyy` or `dd.MM.yyyy HH:mm`, in the device's local timezone.
Money uses the `de_AT` locale; API values retain their exact integer, decimal and timestamp types.
Changing `BeakPanel.formatting` updates standard forms, table cells, detail values
and calculated summaries together.

## Tests

```sh
flutter test test/order_form_test.dart test/invoice_form_test.dart \
  test/shop_resource_test.dart test/shop_widget_test.dart test/custom_shop_test.dart
dart test test/shop_api_test.dart test/shop_totals_test.dart test/shop_migration_test.dart
flutter analyze
```

API tests use real SQLite and exercise graph saves, rollback, invoice snapshots,
relationships and catalog changes. Form tests use the actual layouts, including
invoice previews and responsive tabs that preserve drafts.

This is an executable admin example, not a payment processor or tax filing
system. It does not process payments, issue legally certified documents, reserve
inventory, convert currencies or generate PDFs. Those domain integrations can be
added behind Beak's existing server and custom-screen extension points.


## Field-system examples

`resources/fulfillment/models/fulfillment_policy.dart` demonstrates semantic model
metadata; `screens/fulfillment_policy_form.dart` contains only layout and optional
control choices. Generated helpers preserve typed calendar dates, times, durations,
exact decimals and lists across HTTP/SQLite round trips. `ProductImage` and
`ProductModel.images.galleryForm(...)` demonstrate an owned ordered gallery.

See [semantic fields](../../docs/models/semantic-fields.md) and
[uploads and galleries](../../docs/forms/uploads-and-galleries.md) for contracts and
custom-transport extension points. Category attribute editors follow their selected
definition's type while preserving the shop's existing string storage.


## Customization and declarative workflows

The Operations route reuses standard resource tables and a custom receivables
widget; its category import uses Beak's shared preview and per-record receipt
runtime. `ShopReceivablesCard` also embeds in the overview and uses the panel's
repository, formatting policy and automatic mutation refresh.

Order and invoice layouts use `BeakFormSections` to project the same definitions
into wizard steps and tabs. Model-level rules own dependent selectors, custom-line
requirements, date ordering and collection constraints. Order line label and price
suggestions follow catalog selections until the administrator overrides them.
Invoice transitions are named model actions, enforced by the API, with idempotent
receipts; generic writes cannot forge a workflow status.

The product Variants tab includes a custom combination builder. Enter dimensions,
preview, select and stage combinations, then review prices and stock in the normal
relationship editor. Repeating the preview excludes existing draft combinations.
The server independently rejects duplicate combinations and SKUs. Dynamic product
attribute controls and server validation share one `BeakAttributeDefinition`
adapter, and category changes report incompatible values without silently deleting
them.

Orders, products and invoices opt into resumable drafts and a review before Save.
This unauthenticated local demo uses a fixed namespace; a real authenticated host
must scope drafts by its user and tenant identity. Browser drafts use local storage;
native examples use an in-memory store. Uncommitted media bytes and passwords are
excluded by the framework.

The remaining shop policy uses `BeakCandidateGraph` for transaction-local typed
reads, relationship candidates and calculated patches. It does not implement its
own graph overlay, persistence order or receipt protocol. `ShopTotals` remains the
pure shared domain calculator.

See [custom screens](../../docs/panel/custom-screens.md),
[embedded widgets](../../docs/extending/custom-blocks-and-widgets.md), and
[attributes and variants](../../docs/models/dynamic-attributes-and-variants.md).
