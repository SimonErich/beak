---
title: Foodio admin
description: "Tour Gabel, the Foodio example: composed order lists, a five-step wizard, named actions, a transactional preparer, durable effects and a custom theme."
type: example
audience: [expert, agent]
status: stable
---

# Foodio admin

The [clean shop](clean-shop.md) shows Beak's features. Foodio shows what happens when you take a few of them all the way: a food-ordering admin for a company canteen, with a designed look, 48,213 seeded orders and business rules that live on the server. The folder is called `foodio-adminpanel`, the interface keeps the brand of its design prototype, Gabel.

Read this page after the shop. It is a tour of where the parts are and why they are shaped this way, not a tutorial.

## At a glance

| | |
| --- | --- |
| Domain | Food ordering for companies: customers, organizations, delivery profiles and slots, dishes and menus, orders, invoices, budgets, complaints |
| Models | 26 schema classes in `lib/models/` |
| Resources | 14, split by team area in `lib/resources/`, plus 2 custom pages |
| Panel bootstrap | Authored: `BeakPanel(config: foodioPanel())` |
| API port | 8081, on `127.0.0.1` |
| Auth | None. A local demo with a fixed demo user and clock |
| Database | SQLite file `foodio.sqlite` |
| Money | Integer cents, VAT inclusive |
| Fixture | 48,213 orders, seeded in about 20 to 30 seconds |
| Highlights | Composed list with presets and saved views, wizard, record templates, printable document, 15 named order actions, transactional preparer, outbox effects, custom theme |
| Tests | 43 in the Dart VM (money, behavior, API), 101 across the whole folder |
| Read it if | You are building a designed panel or a workflow with real invariants |

## Run it

```console
cd examples/foodio-adminpanel
cp .env.example .env     # first time only, keep an existing .env
flutter pub get
beak migrate
beak seed
beak dev
```

`.env.example` sets `DATABASE_URL=sqlite:foodio.sqlite`, `PORT=8081`, `HOST=127.0.0.1` and `BEAK_STORAGE_DRIVER=none`. `beak migrate` applies the two framework migrations and 30 of the example's own. The seed prints one line:

```console
$ beak seed
  26 models · 1 resource class · screens and overrides not applicable (lib/main.dart is authored)
  generated  up to date (31 files)
seeded  FoodioSeeder
```

Start the panel in a second terminal, on the port the README uses:

```console
flutter run -d chrome --web-port=3002 --dart-define=BEAK_API_BASE_URL=http://127.0.0.1:8081
```

Leave the API terminal running. Besides serving requests it drains the durable outbox once per second, which is what turns a placed order into a payment attempt and a message (stop 7).

The seed is repeatable and keeps later edits. To throw the demo data away and rebuild it, stop the API and run `beak migrate fresh --seed`, which reapplies all 32 migrations and seeds again in about 20 to 30 seconds.

The demo clock is fixed at 28 September 2026, 09:42 Vienna summer time, so the fixture's "today" and the 10:30 order cutoff stay reproducible. `FoodioClock` takes an injected clock for boundary tests, and its two-hour offset belongs to that reference week. It is not a time-zone service.

!!! note "What just happened"
    - The seed inserted 48,213 real orders with their lines. The API confirms it: `POST /api/orders/query` reports `"total":48213`. The counts the README quotes (412 orders today, 96 awaiting release, and so on) are queries over those rows, and `test/foodio_api_test.dart` asserts them.
    - Nothing is faked in the panel. Charts, badges and tab counts query the database, so the numbers change when you edit orders.

## Tour

### 1. One panel configuration

The whole application is `BeakPanel(config: foodioPanel())`, and `foodioPanel` is a public function so tests can boot the same panel against another API origin:

```dart title="examples/foodio-adminpanel/lib/main.dart"
--8<-- "examples/foodio-adminpanel/lib/main.dart:foodioPanelConfig"
```

Besides the theme and formatting, three options are worth knowing: `navigation` replaces the automatic sidebar with a rail and contextual sections, `notifications` binds the shell's notifications to a model (`NotificationModel`), and `refreshPolicy` re-queries every 30 seconds and when the app resumes. [Navigation](../panel/navigation.md) and [Panel and resource options](../reference/panel-options.md) list the rest.

The navigation is data, and screens and resources are referenced by object:

```dart title="examples/foodio-adminpanel/lib/navigation.dart"
--8<-- "examples/foodio-adminpanel/lib/navigation.dart:foodioNavigationSections"
```

`showCount: true` puts a live count on a rail item. The count is a query, not a stored number.

### 2. One population for the orders list

The order list is a `BeakTableScreen` with a `BeakListDefinition`. The definition declares the presets, the quick filters, the summary header, the row and bulk actions, the CSV export and the saved views. One query controller resolves scope, preset, filters and search once, and the table, the counts, the summaries and the export all read that same population.

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListQuery"
```

A preset is an object, and everything else refers to it rather than to a key:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart:composedListPresetToday"
```

A saved view stores the versioned query choices as a row in an ordinary resource, so the resource's authorization decides who may read or change it:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListSavedViews"
```

Table cells are record templates. A template binds fields to a title and subtitles, so the same identity can appear in a list, a choice, a review step and a detail page:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_table_columns.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_table_columns.dart:composedListColumnOrder"
```

The header summaries count over the whole filtered population, not the current page. The status chart intersects each ordinary status with `needsAttention == false` and gives attention its own measure, so the six numbers add up:

```dart title="examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/dashboard/order_overview.dart:foodioStatusValues"
```

See [Composed lists and query state](../panel/composed-lists.md), [Population summaries](../blocks/summaries.md) and [A saved list view](../recipes/a-saved-list-view.md).

### 3. Rules and commands on the model

Order rules are the same kind of `BeakRecordRule` the shop uses. These two make sure the chosen payment method and delivery profile belong to the chosen customer:

```dart title="examples/foodio-adminpanel/lib/models/order.dart"
--8<-- "examples/foodio-adminpanel/lib/models/order.dart:FoodioOrderRules"
```

Commands are named actions. `OrderActions` in `lib/domain/order_behavior.dart` declares 15 of them: `place`, `approve`, `reject`, `cancel`, `startKitchen`, `dispatch`, `deliver`, `sendPaymentLink`, `retryPayment` and so on. Screens, list rows and the server refer to the objects, never to the wire names. An action can take typed input, which is a small model of its own:

```dart title="examples/foodio-adminpanel/lib/domain/order_behavior.dart"
--8<-- "examples/foodio-adminpanel/lib/domain/order_behavior.dart:FoodioAddNote"
```

```dart title="examples/foodio-adminpanel/lib/domain/_order_note_input.dart"
--8<-- "examples/foodio-adminpanel/lib/domain/_order_note_input.dart:FoodioNoteInput"
```

The same input model validates the Add note dialog in the browser and the request on the server. An action's menu position grants nothing: `availableWhen` and the server's guards decide. See [Model behavior](../models/behavior.md) and [Behavior and actions](../reference/behavior-and-actions.md).

### 4. A wizard over one draft

Placing an order takes five steps, and all five edit the same draft. The final action, `OrderActions.place`, saves the complete order graph in one commit:

```dart title="examples/foodio-adminpanel/lib/resources/orders/forms/order_wizard_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/forms/order_wizard_screen.dart:orderWizard"
```

`aside` shows the live summary with the basket, the budget and the slot capacity. `asideFooter` pins the totals, so they stay visible while the summary scrolls. On a narrow screen the same summary opens in a sheet. The catalog step creates staged rows only, so no order exists on the server while the person is still choosing dishes. Forward navigation validates the steps before it, and the review step's Edit links return to the owning step without losing anything.

The totals in the preview come from pure Dart in `lib/domain/foodio_money.dart`, the same functions the server runs. This test is the reference basket, with a voucher of 15 percent on food, capped:

```dart title="examples/foodio-adminpanel/test/foodio_money_test.dart"
--8<-- "examples/foodio-adminpanel/test/foodio_money_test.dart:foodioVoucherTest"
```

The discount is spread over the lines with stable largest-remainder allocation, and VAT rounds once per rate bucket and reconciles to the line totals. See [Multi-step forms](../forms/multi-step-forms.md) and [Workflow presentations](../forms/workflow-presentations.md).

### 5. The server has the last word

Capacity, budget and order numbers cannot be checked in a browser, because two browsers may race for the last slot. `FoodioOrderPreparer` runs inside the graph commit's transaction and validates the whole proposed graph. Capacity, budget and order-number updates are compare-and-set, so any failure rolls back everything, including a customer and a company profile created in the same save.

```dart title="examples/foodio-adminpanel/lib/server.dart"
--8<-- "examples/foodio-adminpanel/lib/server.dart"
```

Four hooks on `defaults.build` carry the load: `preparePlan` validates and derives, `finalizePlan` queues effects in the same transaction, `outbox` schedules the worker, and `graphOnly` closes the direct routes of eleven tables, so no request can bypass the preparer. Rules that hold for the reference data live in `DOMAIN.md`: every placed order reserves one order in its delivery slot, an order above the profile's threshold needs approval, and cancelling before preparation releases the reservation.

Two design choices repay a look. Invoices and orders keep snapshots of prices, labels, tax and voucher terms, so a later catalog edit cannot rewrite history. And a provider result advances the order's revision, so a stale browser tab that saves afterwards gets a conflict instead of overwriting the result. See [Transactional business rules](../backend/graph-business-rules.md) and [Graph commits](../architecture/graph-commits.md).

### 6. A printable document without print code

A record document is declared with the same field bindings as a template. The panel renders it to HTML for printing and offers a download when the browser blocks the print window:

```dart title="examples/foodio-adminpanel/lib/resources/orders/actions/order_documents.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/actions/order_documents.dart:deliveryNoteAction"
```

The action is registered on `OrderResource` in `recordActions`, next to a `call-customer` link action that builds a `tel:` URI. See [Printable record documents](../forms/record-documents.md).

### 7. Effects that outlive the request

Placing an order may have to charge a card or send a message. Doing that inside the transaction would hold the database while a provider answers, and doing it after would lose it on a crash. Foodio queues the effect in the same transaction as the order and lets a worker deliver it after the commit:

```dart title="examples/foodio-adminpanel/lib/domain/foodio_effects.dart"
--8<-- "examples/foodio-adminpanel/lib/domain/foodio_effects.dart:foodioEffectKindList"
```

The queue key is derived from the save id and the effect kind, and enqueueing a key that already exists with the same content does nothing. The worker delivers at least once, and the demo providers deduplicate by that key: a `PaymentAttempt` or a `MessageDelivery` row holds the receipt. A retry after a crash between delivery and acknowledgement neither charges nor sends again. Obsolete effects, such as a charge for an order cancelled in the meantime, end with a skipped receipt. A payment method with `demoOutcome: declined` exercises the failure and retry path.

Nothing leaves the machine. The payment and message providers are local adapters, and payment links use the reserved `.example` domain. See [Durable effects](../backend/durable-effects.md).

### 8. A custom theme, still Obers

The look comes from one function that returns an `OiThemeData`. It starts from Obers' own light or dark theme with two font families, then overrides colors, text styles, shadows, borders, icons and the chart palette from a token file:

```dart title="examples/foodio-adminpanel/lib/theme/gabel_theme.dart"
--8<-- "examples/foodio-adminpanel/lib/theme/gabel_theme.dart:gabelBase"
```

The fonts (Mona Sans and JetBrains Mono, both under the SIL Open Font License) are bundled in `assets/fonts/`. `DESIGN.md` records why an earlier rendering differed from the prototype and which contracts fixed it: who paints a card, how hover keeps geometry stable, why a fixed `wght` axis breaks `copyWith(fontWeight:)`. The panel around it is plain Beak. See [Theming basics](../theming/theming-basics.md).

## Where things are

| Path | Role |
| --- | --- |
| `lib/main.dart` | Panel configuration: theme, formatting, navigation, notifications, refresh |
| `lib/foodio_resources.dart` | Registration and ordering of the 14 resources |
| `lib/navigation.dart` | The rail, the sections, the account menu, the shell actions |
| `lib/models/` | The 26 schema classes, with enum labels, badges and record rules |
| `lib/resources/orders/list/` | Filters, presets, table columns, the composed list |
| `lib/resources/orders/forms/` | Wizard, its five steps, the items table, review and summary |
| `lib/resources/orders/details/` | The read and edit screen: delivery, customer, activity |
| `lib/resources/orders/presentations/` | Record templates shared by list, choices, review and detail |
| `lib/resources/orders/dashboard/`, `actions/` | Overview summaries and charts, the delivery-note document |
| `lib/resources/people/`, `finance/`, `operations/`, `catalog/` | The supporting resources, on shared read, create and edit forms |
| `lib/domain/` | Money, commands, the preparer, the effects, the clock |
| `lib/server.dart` | Preparer, finalizer, outbox and graph-only registration |
| `lib/seeders/foodio_seeder.dart` | The 48,213-order fixture |
| `lib/migrations/` | 30 migrations, including additive upgrades for existing databases |
| `lib/theme/` | Tokens, icons and the theme function |
| `DOMAIN.md`, `DESIGN.md`, `VERIFICATION.md` | Contracts, design notes, browser checks |
| `tool/` | Playwright scripts for browser verification |

## Features shown

| Feature | File | Docs page |
| --- | --- | --- |
| Composed list: presets, quick filters, saved views, export | `lib/resources/orders/list/order_list_screen.dart` | [Composed lists and query state](../panel/composed-lists.md) |
| Record templates in table cells | `lib/resources/orders/list/order_table_columns.dart` | [Composed lists and query state](../panel/composed-lists.md) |
| Population summaries and conditional measures | `lib/resources/orders/dashboard/order_overview.dart` | [Population summaries](../blocks/summaries.md) |
| Wizard with named steps, aside and drafts | `lib/resources/orders/forms/order_wizard_screen.dart` | [Workflow presentations](../forms/workflow-presentations.md) |
| Read and edit on one screen | `lib/resources/orders/details/order_detail_screen.dart` | [Detail views](../forms/detail-views.md) |
| Named actions with typed input | `lib/domain/order_behavior.dart` | [Actions](../panel/actions.md) |
| Record rules against related rows | `lib/models/order.dart` | [Validation](../models/validation.md) |
| Printable record document | `lib/resources/orders/actions/order_documents.dart` | [Printable record documents](../forms/record-documents.md) |
| Custom navigation with counts | `lib/navigation.dart` | [Navigation](../panel/navigation.md) |
| Notifications and refresh policy | `lib/main.dart` | [Panel and resource options](../reference/panel-options.md) |
| Transactional preparer and graph-only tables | `lib/server.dart`, `lib/domain/foodio_order_preparer.dart` | [Transactional business rules](../backend/graph-business-rules.md) |
| Durable effects and outbox | `lib/domain/foodio_effects.dart` | [Durable effects](../backend/durable-effects.md) |
| Integer-cent money and exact VAT | `lib/domain/foodio_money.dart` | [Semantic fields](../models/semantic-fields.md) |
| Enum labels and badges on a model | `lib/models/order.dart` | [An enum badge column](../recipes/an-enum-badge-column.md) |
| A complete custom theme | `lib/theme/gabel_theme.dart` | [Theming basics](../theming/theming-basics.md) |
| A large seeded fixture with real counts | `lib/seeders/foodio_seeder.dart` | [Seeding](../backend/seeding.md) |

## Tests

```console
cd examples/foodio-adminpanel
dart test test/foodio_money_test.dart test/foodio_behavior_test.dart test/foodio_api_test.dart
flutter test --concurrency=1
```

The first command ran 43 tests, the second 101 across 16 files (2026-09-29). Both passed. The tests use isolated in-memory SQLite and never touch `foodio.sqlite`.

| Test file | What it proves |
| --- | --- |
| `foodio_money_test.dart` | Cents, VAT buckets, voucher caps, stable remainder allocation |
| `foodio_behavior_test.dart` | Defaults, suggestions and snapshot retention |
| `foodio_api_test.dart` | The fixture counts, atomic placement, reservation rollback, replay and recovery, API bypass attempts, effect retries and refunds, invoice locking, budget settlement, repeated fresh migrations on the full fixture |
| `foodio_panel_test.dart` | The complete panel boots against seeded SQLite, and its routes render |
| `order_wizard_presentation_test.dart`, `order_preview_test.dart`, `order_presentation_test.dart` | The five steps, live previews, persisted order presentation |
| `supporting_forms_test.dart` | Create, detail and edit routes of the supporting resources |
| `*_migration_test.dart` | Additive migrations keep existing data |
| `gabel_*_test.dart`, `overview_layout_test.dart` | Typography, numeric alignment and overview layout |

Browser checks are separate. `tool/verify_*.cjs` drive Chrome through Playwright against a running API and a release build, and `VERIFICATION.md` lists what each one asserts. They need `npm` and a browser, and the gate does not run them.

## Limits

- No authentication and no policy. The seeded user is a fixed name, and the demo clock never moves.
- Local providers only. There is no card gateway, email service or identity provider.
- The rules are one canteen's rules. The capacity model reserves one order per slot regardless of portions, and delivery areas are postal codes, not geocoding.
- The example uses a lot of Beak at once. When something here looks heavier than you expected, the [clean shop](clean-shop.md) shows the same idea with less around it.
- Its look is a prototype's look. The theme file is a good template for a token-driven theme, but it is not a design system you should copy wholesale.

## Continue reading

- [Composed lists and query state](../panel/composed-lists.md): the list definition in detail.
- [Durable effects](../backend/durable-effects.md): the outbox, the worker and receipts.
- [Transactional business rules](../backend/graph-business-rules.md): what a preparer can and cannot do.
- [Showcase](showcase.md): the features neither application uses.
