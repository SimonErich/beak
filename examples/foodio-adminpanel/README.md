# Gabel food-ordering admin

A persistent admin application built with Beak’s declarative resources, forms,
wizards, record templates and summaries. The folder is named Foodio; the interface
preserves the **Gabel** branding of the prototype in
[`design/food-ordering-shop.html`](design/food-ordering-shop.html). The original
`examples/clean_beak_config` shop remains available as a separate example.

The reference screens cover order operations, advanced filtering, customer and
delivery selection, a dish catalog, payment and approval, order details, invoices,
notes and activity. Supporting destinations use working configured screens for
customers, organizations, profiles, locations, staff, budgets, vouchers, delivery
slots, menus, complaints and settings.

[Design contracts](DESIGN.md) explains how the prototype maps to shared Beak
layouts, Obers components and the Gabel theme, including hover, surface ownership,
variable-font typography and responsive composition. [DOMAIN.md](DOMAIN.md) has
the accounting, capacity, approval and snapshot rules, and
[VERIFICATION.md](VERIFICATION.md) the tests and browser checks.

## Run locally

You need Dart `^3.11` and Flutter 3.41 or newer, one installation used for
dependency resolution, generation, tests and builds alike. The checks in
[VERIFICATION.md](VERIFICATION.md) ran on Flutter 3.44.0 and Dart 3.12.0.

From a clean clone, resolve the workspace at the repository root first
(`melos bootstrap`, and `melos run link-obers-ui` until the obers_ui pin catches
up; the root README explains both). Then, from this directory:

```sh
flutter pub get
cp -n .env.example .env
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
dart run bin/serve.dart
```

The API listens on `127.0.0.1:8081` and uses `foodio.sqlite` in this directory;
`.env` sets host, port and database (`beak.yaml` names port 8081 for the server and
for the panel's default API origin). The seed is idempotent and preserves later
edits. Keep an existing `.env`; `cp -n` does. While
it serves, the host drains the durable demo outbox once per second (`lib/server.dart`
passes the schedule, `lib/domain/foodio_effects.dart` defines it). Leave that
terminal running.

In another terminal in this directory:

```sh
flutter run -d chrome --web-port=3002 \
  --dart-define=BEAK_API_BASE_URL=http://127.0.0.1:8081
```

For a release build with locally bundled CanvasKit, without fetching renderer
assets from a CDN:

```sh
flutter build web --release --no-web-resources-cdn \
  --dart-define=BEAK_API_BASE_URL=http://127.0.0.1:8081
python3 -m http.server 3002 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:3002`. The panel is an unauthenticated local demonstration.
It does not provide a production identity provider, card gateway or email service.

To deliberately discard demo edits and recreate the reference dataset:

```sh
DATABASE_URL=sqlite:foodio.sqlite dart run bin/migrate.dart migrate:fresh --seed
```

Stop the API before resetting its database. Ordinary development uses `migrate`
and `db:seed`, which preserve data. Unknown migration history is rejected before
the fresh command drops known tables. The SQLite schema rebuild is atomic and keeps
foreign-key enforcement enabled, deferring checks until commit so populated cyclic
relationships can be reset safely.

## Try the reference workflow

1. Open Orders. The seed contains **48,213 actual orders**, with **412 today**,
   **96 scheduled for release**, seven attention items across all dates and three
   drafts. Charts and badges query the database; counts change with real edits.
2. Open `ORD-24817`, Lena’s order. Its four lines total **€31.40**. Add the soup
   before the cutoff to obtain **€35.90**. Saved catalog prices and invoice
   snapshots stay stable when catalog data changes.
3. Create an order for Lena’s company profile: two regular risottos, one regular
   dal and one schnitzel total **€48.60** before the `LUNCH15` voucher and
   **€41.31** afterward. The company budget must cover the order; the amount above
   €40 also requires approval. Capacity reserves one order, regardless of portions.
4. Try changing the delivery slot, requesting approval, confirming allergy
   handling, issuing an invoice and adding an internal note. Named actions use
   the same eligibility and input validation on the panel and API. Notes remain
   append-only even after fulfillment ends.
5. Use the advanced filter for 28–29 September 2026, Confirmed / In kitchen /
   Needs attention, company profiles, Nordlicht / Kessler, 11:30–12:00 /
   12:00–12:30 and Company invoice / Subsidy + card. The original fixture has
   **214 matching records**. A selected date range replaces the Today preset.

The demo clock stays at **28 September 2026, 09:42 Vienna summer time** so the
reference data and 10:30 cutoff stay reproducible. Today’s corrected non-cancelled
revenue is **€9,826.40**; future deliveries total 664, of which 96 await release.
See [DOMAIN.md](DOMAIN.md) for the precise accounting, capacity, approval and
snapshot contracts and the six disjoint chart populations.

## Where things are

| Concern | Authored source |
| --- | --- |
| Panel, navigation and global formatting | `lib/main.dart`, `lib/navigation.dart`, `lib/theme/` |
| Resource registration | `lib/foodio_resources.dart` |
| Typed fields, relationships, validation, labels and badges | `lib/models/` |
| Order list, filters, presets and table columns | `lib/resources/orders/list/` |
| Order wizard shell and named customer, delivery, dish and payment steps | `lib/resources/orders/forms/order_wizard_screen.dart`, `lib/resources/orders/forms/steps/` |
| Reused order-item editor, review step, summary layout and exact totals | `lib/resources/orders/forms/` |
| Read/edit detail screen and its delivery, customer, activity and presentation sections | `lib/resources/orders/details/` |
| Shared identity, dish and status bindings | `lib/resources/orders/presentations/` |
| Dashboard overview and printable order document | `lib/resources/orders/dashboard/`, `lib/resources/orders/actions/` |
| Operations page | `lib/pages/operations.dart` |
| Reusable inline customer, profile and payment forms | `lib/resources/people/people_forms.dart` |
| Dish catalog | `lib/resources/catalog/` |
| Supporting configured screens | `lib/resources/people/`, `lib/resources/finance/`, `lib/resources/operations/` |
| Shared read/create/edit form wrapper | `lib/supporting_forms.dart` |
| Model defaults and named commands | `lib/domain/order_behavior.dart` |
| Exact cents, discount allocation and inclusive VAT | `lib/domain/foodio_money.dart` |
| Authoritative reservations, snapshots and workflow rules | `lib/domain/foodio_order_preparer.dart`, `lib/domain/foodio_invoice_rules.dart` |
| Persistent demo payment/message adapters | `lib/domain/foodio_effects.dart` |
| Backend registration, graph rules and the outbox schedule | `lib/server.dart` |
| Real fixture records | `lib/seeders/foodio_seeder.dart` |
| Schema upgrades | `lib/migrations/` |

`lib/beak/`, `*.beak.dart`, `bin/serve.dart` and `bin/migrate.dart` are
generated. The panel uses normal Beak graph commits: application views do not
fetch, bind, validate or save records through custom controllers. Pure domain
calculations also power live form previews. The custom preparer supplies the
business invariants that belong to this shop, inside the same transaction as
child changes and the durable save receipt.

The wizard's steps, review Edit links, inline creation dialogs and summary share
one draft. Totals stay pinned beneath the scrolling summary, and the compact
layout opens that summary in a sheet. Local Save draft uses browser storage;
placing the order performs the authoritative graph commit. Detail cards can
collapse while retaining draft state, and the same record templates supply
identities in choices, review, lists and details.
Completed wizard steps summarize the current selections; footer guidance changes
with the step. The header reports a draft time only after local storage confirms
the write, including automatic saves.

## Delivery, catalog and wizard behavior

Delivery configuration uses typed date shortcuts (including tomorrow and next
week), compact responsive slot cards with live capacity, saved-location cards, an
explicit one-order address override, and a three-line driver note. The note’s
200-character limit comes from its model rule. One-time addresses remain inside
the selected location’s city/postal area and retain its route; disabling the
override restores the saved address. For an existing demo database, run
`DATABASE_URL=sqlite:foodio.sqlite dart run bin/migrate.dart migrate` before
restarting the API; the additive address-intent migration preserves existing
records.

The wizard uses equal-height profile cards, a plain secondary-address disclosure,
segmented catalog categories, allergen filter chips and accessible quantity
steppers. The Menu plan segment keeps the authoritative menu eligibility scope;
it does not expose otherwise ineligible dishes. Detail/edit item rows reserve
usable widths for Qty and Total, with Size beside the item metadata and the
formatted unit price below Total.
Options expand inline: extras are typed, priced checkboxes and the preparation
note is a secondary disclosure. All changes stay in the parent draft until Save;
whole-form Cancel discards them. Adding a new item opens the complete row dialog,
whose Cancel restores its checkpoint without leaving an empty item.

The ordering catalog requires an active customer profile, an eligible delivery
date, and an active menu. The Menu plan tab is a convenience filter; All dishes,
Drinks and Desserts allow the full active catalog. The server validates every
selected dish and variant, including active status and ownership, while
retaining stock, allergy, price and authorization rules. Historical items remain
readable after a menu changes. The review’s kitchen preparation time is a
configured daily forecast (`FoodioClock.kitchenPreparationStart`); kitchen start
remains an explicit authorized action.

## Demo effects

Payment attempts, message deliveries and their receipts persist in SQLite. The
outbox retries at least once; the adapters deduplicate by the stable effect key.
Obsolete charges and notifications receive skipped receipts. A declined saved
payment method demonstrates retry; cancellation of a paid order queues a refund.
Paid amounts and payment methods are locked until cancellation/refund. Provider
results advance the order revision, so saving a stale browser draft yields a
conflict instead of overwriting the result. Payment links use the reserved
`.example` domain and never contact a real provider.

## Tests

```sh
flutter analyze --fatal-infos --fatal-warnings
flutter test --concurrency=2
```

The money, behavior, API, typed-rules and migration suites need no Flutter and
also run with `dart test`, for example `dart test test/foodio_api_test.dart`.
Tests use isolated data and never touch the interactive `foodio.sqlite`. They
verify real fixture counts, money and tax, reservation rollback, API bypass
attempts, action replay, snapshots and effect receipts. They also cover atomic
inline customer/profile/payment creation, current and delivery-month company
ledgers, active customer-scoped payment identities, payment-mode kind checks,
dated menu eligibility, terminal action guards, stale edits after provider
results, and two fully populated SQLite resets.

The browser checks (`tool/verify_*.cjs`, driven by Playwright against a release
build and the real API) cover the list and its filters, search, documents, the
supporting destinations, the order wizard and drafts on a phone, delivery
settings and the edit workflow. [VERIFICATION.md](VERIFICATION.md) has every
command, what each check exercises, the two that write, and how to run those
against a copy of the database. Artifacts go to the git-ignored `.artifacts/`
folder; `FOODIO_ARTIFACTS` selects another.
