# Gabel food-ordering admin

A persistent admin application built with Beak’s declarative resources, forms,
wizards, record templates and summaries. The folder is named Foodio; the interface
preserves the **Gabel** branding of `food-ordering-shop.html`. The original
`examples/clean_beak_config` shop remains available as a separate example.

The reference screens cover order operations, advanced filtering, customer and
delivery selection, a dish catalog, payment and approval, order details, invoices,
notes and activity. Supporting destinations use working configured screens for
customers, organizations, profiles, locations, staff, budgets, vouchers, delivery
slots, menus, complaints and settings.

[Design contracts](DESIGN.md) explains how the prototype maps to shared Beak
layouts, Obers components and the Gabel theme, including hover, surface ownership,
variable-font typography and responsive composition.

## Run locally

Verified with **Flutter 3.44.0 / Dart 3.12**. Use one Flutter installation and its
bundled Dart consistently for dependency resolution,
generation, tests and builds. This workspace also extends the sibling
`../obers_ui` checkout. From the Beak repository root, link its three packages:

```sh
flutter --version
dart run tool/link_obers_ui.dart
cd examples/foodio-adminpanel
flutter pub get
cp .env.example .env
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
dart run bin/serve.dart
```

The API listens on `127.0.0.1:8081` and uses `foodio.sqlite` in this directory.
The seed is idempotent and preserves later edits. Copy `.env.example` only for a
new local setup; preserve an existing `.env`. The API process also drains the
durable demo outbox once per second. Leave that terminal running.

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
the fresh command drops known tables. The SQLite schema rebuild is atomic and keeps foreign-key enforcement enabled, deferring checks until commit so populated cyclic relationships can be reset safely.

## Configuration map

| Concern | Authored source |
| --- | --- |
| Panel, navigation and global formatting | `lib/main.dart`, `lib/theme/` |
| Resource registration | `lib/foodio_resources.dart` |
| Typed fields, relationships, validation, labels and badges | `lib/models/` |
| Order list, filters, summaries and record templates | `lib/resources/orders/` |
| Order wizard and shared detail/edit sections | `order_form.dart`, `order_review.dart`, `order_detail.dart`, `order_items.dart`, `order_summary.dart` in that folder |
| Reusable inline customer, profile and payment forms | `lib/resources/people/people_forms.dart` |
| Printable persisted delivery note | `order_documents.dart` in that folder |
| Dish catalog | `lib/resources/catalog/` |
| Supporting configured screens | `lib/resources/people/`, `finance/`, `operations/` |
| Shared read/create/edit form wrapper | `lib/supporting_forms.dart` |
| Model defaults and named commands | `lib/domain/order_behavior.dart` |
| Exact cents, discount allocation and inclusive VAT | `lib/domain/foodio_money.dart` |
| Authoritative reservations, snapshots and workflow rules | `lib/domain/foodio_order_preparer.dart`, `foodio_invoice_rules.dart` |
| Persistent demo payment/message adapters | `lib/domain/foodio_effects.dart` |
| Backend registration | `lib/server.dart`, `bin/serve.dart` |
| Real fixture records | `lib/seeders/foodio_seeder.dart` |
| Schema upgrades | `lib/migrations/` |

`lib/beak/` and `*.beak.dart` are generated. The panel uses normal Beak graph
commits: application views do not fetch, bind, validate or save records through
custom controllers. Pure domain calculations also power live form previews.
The custom preparer supplies the business invariants that belong to this shop,
inside the same transaction as child changes and the durable save receipt.

The wizard's steps, review Edit links, inline creation dialogs and summary share
one draft. Totals stay pinned beneath the scrolling summary, and the compact
layout opens that summary in a sheet. Local Save draft uses browser storage;
placing the order performs the authoritative graph commit. Detail cards can
collapse while retaining draft state, and the same record templates supply
identities in choices, review, lists and details.
Completed wizard steps summarize the current selections; footer guidance changes
with the step. The header reports a draft time only after local storage confirms
the write, including automatic saves.

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

## Demo effects and verification

See [VERIFICATION.md](VERIFICATION.md) for the repeatable browser checks,
coverage, reference-data corrections and the limits of the local demo.

Payment attempts, message deliveries and their receipts persist in SQLite. The
outbox retries at least once; the adapters deduplicate by the stable effect key.
Obsolete charges and notifications receive skipped receipts. A declined saved
payment method demonstrates retry; cancellation of a paid order queues a refund.
Paid amounts and payment methods are locked until cancellation/refund. Provider results advance the order revision, so saving a stale browser draft yields a conflict instead of overwriting the result. Payment
links use the reserved `.example` domain and never contact a real provider.

```sh
dart test test/foodio_money_test.dart test/foodio_behavior_test.dart \
  test/foodio_api_test.dart
flutter test test/supporting_forms_test.dart test/foodio_panel_test.dart \
  test/order_preview_test.dart test/order_presentation_test.dart \
  test/order_wizard_presentation_test.dart --concurrency=1
```

With the API and release preview running, the Chrome smoke check captures each
supporting resource's list and detail, a mobile list, browser errors, API status
codes and loading timings in an ignored artifact folder:

```bash
npm exec --yes --package=playwright -- node tool/verify_supporting.cjs
```

It defaults to `http://127.0.0.1:59389`; set `FOODIO_URL` for another preview port.
It performs read-only navigation and does not change orders or other records.

The list and document checks each run a cold and warm pass. List verification
tests the canonical advanced filter, URL restoration and formatted CSV export.
Document verification checks the print invocation and captures the delivery note
as HTML, PDF and a screenshot, using one authorized query and no writes:

```bash
npm exec --yes --package=playwright -- node tool/verify_list.cjs
npm exec --yes --package=playwright -- node tool/verify_documents.cjs
npm exec --yes --package=playwright -- node tool/verify_search.cjs
npm exec --yes --package=playwright -- node tool/verify_search_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_pagination_mobile.cjs
```

The pagination check captures 320px and 390px layouts and advances a bookmarked
middle page without changing records. The mobile search check uses the visible
header button at both widths and verifies a matching global order result.

The workflow check creates the reference €41.31 order twice and cancels both
through the UI to release reservations. Its local audit history and demo messages
remain available. It verifies all five wizard steps, preview totals, approval,
atomic saving and cancellation:

```bash
npm exec --yes --package=playwright -- node tool/verify_workflow.cjs
```

The mobile wizard check traverses all five steps twice at 390px, corrects an
invalid voucher with real keyboard input, and opens the summary sheet to verify
the same €41.31 draft after navigation. It closes the sheet through its visible
close button, captures every step and verifies that
the final action remains reachable. It does not place orders or make commits:

```bash
npm exec --yes --package=playwright -- node tool/verify_wizard_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_drafts_mobile.cjs
```

The focused draft check verifies narrow Resume/Discard actions, local restoration
and persistent discard at 390px and 320px, without server commits.

The edit check validates inline-row cancellation through the owner form and
new-row dialog cancellation, retains the complete contact phone, then adds the
€4.50 soup and moves delivery to noon. It saves the edit and an inline internal
note in one atomic amendment, removes the soup, and restores the 11:30 slot.
It verifies €35.90 / €52.10 budget remaining, then €31.40 / €56.60, and appends a
second note using the standalone inline command. Run it against the reference
basket:

```bash
npm exec --yes --package=playwright -- node tool/verify_edit.cjs
```

The edit check also asserts that the standalone note appears immediately and
survives a hard reload. Save timings include authoritative client refresh after
the applied HTTP receipt, before the completed read state permits navigation. Set `FOODIO_EDIT_NOTE_ONLY=1` to repeat just that action and capture
read/edit screens without changing the basket or delivery; `FOODIO_EDIT_NOTE`
can supply a distinct verification note. `FOODIO_EDIT_RESTORE_ONLY=1` resumes
removal of a previously saved test soup if an interrupted run needs cleanup.

Artifacts default to the ignored `.artifacts/` folder. `FOODIO_ARTIFACTS` selects
another directory. Headless document verification intercepts the native print
dialog and confirms its invocation; the rendered HTML is also printed to PDF.
It also verifies a working HTML download when the browser blocks the print
window. Global search verification opens orders, customers by email, dishes and
invoices, including keyboard activation. List verification uses Space and Enter
to select rows for the bulk-action surface.

To recreate the ten reference screenshots with their embedded fonts and native
HTML elements restored from the supplied prototype bundle:

```bash
python3 tool/extract_reference.py --references-only
npm exec --yes --package=playwright -- node tool/render_reference.cjs
npm exec --yes --package=playwright -- node tool/inspect_reference.cjs
```

The inspection helper records computed typography and geometry for reference
states 0–2 alongside their screenshots.

Tests use isolated data. They verify real fixture counts, money and tax,
reservation rollback, API bypass attempts, action replay, snapshots and effect
receipts. They also cover atomic inline customer/profile/payment creation,
current and delivery-month company ledgers, active customer-scoped payment identities,
payment-mode kind checks, dated
menu eligibility, terminal action guards, stale edits after provider results,
and two fully populated SQLite resets. Configured-route tests use isolated data
and never reset the interactive demo.

Delivery configuration uses typed date shortcuts (including tomorrow and next week), compact responsive slot cards with live capacity, saved-location cards, an explicit one-order address override, and a three-line driver note. The note’s 200-character limit comes from its model rule. One-time addresses remain inside the selected location’s city/postal area and retain its route; disabling the override restores the saved address. For an existing demo database, run `DATABASE_URL=sqlite:foodio.sqlite dart run bin/migrate.dart migrate` before restarting the API; the additive address-intent migration preserves existing records.

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

`npm exec --yes --package=playwright -- node tool/verify_delivery.cjs` runs cold/warm delivery checks in a disposable Chrome context. It switches private/company profiles, exercises date shortcuts and slot invalidation, enters a multiline note, and checks the one-time address preview and toggle-off restoration. It also verifies inline extras update the shared total and that collapsing preserves checkbox and preparation-note edits. Normal-speed note typing asserts exact text and uninterrupted browser focus during validation. It makes no order commits. Screenshots, accessible snapshots, request timings and a JSON report are retained under `.artifacts/foodio-delivery-*`; `FOODIO_URL` and `FOODIO_ARTIFACTS` override the defaults.

The ordering catalog requires an active customer profile, an eligible delivery date, and an active menu. The Menu plan tab is a convenience filter; All dishes, Drinks and Desserts allow the full active catalog. The server validates every selected dish and variant, including active status and ownership, while retaining stock, allergy, price and authorization rules. Historical items remain readable after a menu changes. The review’s kitchen preparation time is a configured daily forecast (`FoodioClock.kitchenPreparationStart`); kitchen start remains an explicit authorized action.
