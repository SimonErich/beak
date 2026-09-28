# Foodio / Gabel verification

How to check this example yourself. There are two layers:

- unit, widget and API tests, each on its own isolated database;
- browser checks that drive the release web build in installed Chrome against
  the real SQLite API.

The design reference is
[`design/food-ordering-shop.html`](design/food-ordering-shop.html).
`tool/extract_reference.py` extracts its ten screens with their embedded fonts
and native HTML elements restored. [DESIGN.md](DESIGN.md) explains how the
prototype maps onto shared Beak layouts, Obers components and the Gabel theme.

## Prerequisites

- One Flutter installation, used for Dart, Flutter, generation and tests alike.
  These checks were run with Flutter **3.44.0 stable** and Dart **3.12.0**. Link
  the local Obers UI checkout as [README.md](README.md) describes.
- Node.js with `npm`, and Google Chrome. The browser checks load Playwright
  through `npm exec` and launch the installed Chrome.
- Python 3. `tool/verify_hover.cjs` also needs Pillow. A full token and font
  extraction also needs `fonttools[brotli]`.

Run every command below from `examples/foodio-adminpanel`.

## 1. Tests

```sh
flutter analyze --fatal-infos --fatal-warnings
flutter test --concurrency=2
```

The tests never touch the interactive `foodio.sqlite`. They verify fixture
counts, money and tax, reservation rollback, API bypass attempts, action replay,
snapshots, effect receipts and two fully populated SQLite resets.

## 2. Start the API and a release preview

```sh
cp -n .env.example .env
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
dart run bin/serve.dart
```

The API listens on `127.0.0.1:8081`. Leave it running. In a second terminal:

```sh
flutter build web --release --no-web-resources-cdn \
  --dart-define=BEAK_API_BASE_URL=http://127.0.0.1:8081
python3 -m http.server 3002 --bind 127.0.0.1 --directory build/web
```

To start again from the reference dataset, stop the API and run
`DATABASE_URL=sqlite:foodio.sqlite dart run bin/migrate.dart migrate:fresh --seed`.

## 3. Browser checks

Point the checks at the preview. Without `FOODIO_URL` they default to port 59389.

```sh
export FOODIO_URL=http://127.0.0.1:3002
```

These checks never change a record. Run any of them, in any order:

```sh
FOODIO_EXPECT_FILTER_COUNT=214 \
  npm exec --yes --package=playwright -- node tool/verify_list.cjs
npm exec --yes --package=playwright -- node tool/verify_search.cjs
npm exec --yes --package=playwright -- node tool/verify_documents.cjs
npm exec --yes --package=playwright -- node tool/verify_supporting.cjs
npm exec --yes --package=playwright -- node tool/verify_search_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_pagination_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_table_headers.cjs
npm exec --yes --package=playwright -- node tool/verify_hover.cjs
npm exec --yes --package=playwright -- node tool/verify_compact_surfaces.cjs
npm exec --yes --package=playwright -- node tool/verify_delivery.cjs
npm exec --yes --package=playwright -- node tool/verify_wizard_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_drafts_mobile.cjs
```

| Check | What it exercises |
| --- | --- |
| `verify_list` | Cold and warm list passes: filter staging, the canonical advanced filter, URL restoration, keyboard row selection and formatted CSV export |
| `verify_search` | Global search across orders, customers by email, dishes and invoices, including keyboard activation |
| `verify_documents` | The persisted delivery note: one authorized query, print invocation, PDF output and the blocked-popup download |
| `verify_supporting` | Lists and details of the 14 supporting destinations, plus a 390 px mobile layout |
| `verify_search_mobile` | The compact header search button at both phone widths |
| `verify_pagination_mobile` | A bookmarked middle page and reachable pagination at 320 px and 390 px |
| `verify_table_headers` | Narrow headings, hover geometry and model-backed sorts |
| `verify_hover` | Navigation rail and header-action hover and keyboard focus, light and dark |
| `verify_compact_surfaces` | Narrow and short viewports and the reduced-motion wizard |
| `verify_delivery` | Delivery settings in a new-order draft: profile scopes, date shortcuts, slot invalidation, the one-time address and priced extras |
| `verify_wizard_mobile` | All five order steps at 390 px, twice; any commit request fails the check |
| `verify_drafts_mobile` | Resuming and discarding a browser-local draft at 390 px and 320 px |

The next two checks write. Run them one after the other, never concurrently:
they share Lena's budget and slot reservations.

```sh
npm exec --yes --package=playwright -- node tool/verify_workflow.cjs
npm exec --yes --package=playwright -- node tool/verify_edit.cjs
```

- `verify_workflow` places the €41.31 reference order twice and cancels both
  orders through the UI. That releases the budget and capacity again. Set
  `FOODIO_PREVIEW_ONLY=1` to stop before placement.
- `verify_edit` opens `ORD-24817`, adds the €4.50 soup and moves the delivery to
  noon (€35.90, €52.10 budget left), saving an inline note in the same amendment.
  It then restores the original basket and slot (€31.40, €56.60) and appends a
  second note through the standalone note command. `FOODIO_EDIT_PREVIEW_ONLY=1`
  stages the edit without saving. `FOODIO_EDIT_NOTE_ONLY=1` only adds the note,
  and `FOODIO_EDIT_NOTE` sets its text. `FOODIO_EDIT_RESTORE_ONLY=1` cleans up
  after an interrupted run.

Both leave audit notes and demo effect receipts behind.

Each check prints a JSON summary and exits non-zero when an assertion fails.
Screenshots, accessibility snapshots and a `report.json` go to a git-ignored
folder in this example. Set `FOODIO_ARTIFACTS` to write them somewhere else.

### Writing checks against a copy of the database

To run the writing checks without touching the served fixture, back it up into
a scratch database and serve that on a second port:

```sh
python3 - <<'PY_SQLITE'
import sqlite3
with sqlite3.connect('foodio.sqlite') as source:
    with sqlite3.connect('foodio-verification.sqlite') as target:
        source.backup(target)
PY_SQLITE
DATABASE_URL=sqlite:foodio-verification.sqlite dart run bin/migrate.dart migrate
DATABASE_URL=sqlite:foodio-verification.sqlite PORT=8082 dart run bin/serve.dart
```

Then, in another terminal with `FOODIO_URL` still set, send the browser's API
requests to the copy. `FOODIO_API_OVERRIDE` redirects the requests the release
app sends to `127.0.0.1:8081`, and both writing checks honor it:

```sh
FOODIO_API_OVERRIDE=http://127.0.0.1:8082 \
  npm exec --yes --package=playwright -- node tool/verify_workflow.cjs
FOODIO_API_OVERRIDE=http://127.0.0.1:8082 \
  npm exec --yes --package=playwright -- node tool/verify_edit.cjs
```

`*.sqlite` is git-ignored, so the scratch database never shows up in a commit.

## 4. Reference screens

Recreate the ten reference screens, render them in Chrome and record their
computed typography and geometry:

```sh
python3 tool/extract_reference.py --references-only
npm exec --yes --package=playwright -- node tool/render_reference.cjs
npm exec --yes --package=playwright -- node tool/inspect_reference.cjs
npm exec --yes --package=playwright -- node tool/inspect_wizard_reference.cjs
```

`FOODIO_REFERENCE` points `render_reference` and `inspect_reference` at another
folder of `reference-<n>.html` files. To capture any app route for a side-by-side
comparison, pass the route:
`npm exec --yes --package=playwright -- node tool/capture_screen.cjs /orders`.

Without `--references-only`, the extractor also rewrites the four font subsets
in `assets/fonts/` and the color tokens in `lib/theme/gabel_tokens.dart` from
the prototype.

## Contracts checked

| Area | Check |
| --- | --- |
| Order creation | Five steps share one draft; Back and review Edit preserve the graph; one final atomic commit |
| Accounting | €48.60 subtotal − €7.29 voucher = €41.31 total; €37.55 net + €3.76 VAT |
| Order editing | Inline options share the staged graph; whole-form Cancel discards them; the default modal editor retains its cancellation checkpoint; adding soup gives €35.90 and removing it restores €31.40 |
| Reservations | Budget and delivery capacity adjust atomically and are released on cancellation; budget progress and its caption use the same available-before-order denominator |
| Concurrency | Stale root/child edits and guarded deletes conflict without partial writes; successful writes replay safely |
| Payment | Active saved identities belong to the customer and match card/PayPal mode; nested new identities remain staged |
| Voucher entry | Exact normalized code lookup preserves eligibility scopes, rejects missing/ambiguous codes and stale dependency results, and does not save before placement |
| Profile creation | New company profiles receive current and delivery-month budget ledgers in the same transaction |
| Catalog | Dated menu and active variant eligibility; saved price/allergen snapshots survive catalog changes |
| Delivery | Date shortcuts invalidate incompatible slots; private/company location scopes; explicit address overrides stay in the selected delivery area |
| Summary reuse | Nested extras load without an editor; multiple summaries share one row owner; resumption never duplicates staged rows; read permissions apply before calculations |
| Filtering | Typed date boundaries and presets, checkbox/radio/chip controls, staging, matching count, URL restoration and CSV |
| Accessibility | Keyboard row selection and icon/ghost actions, checked/mixed semantics, stable input names and focus during asynchronous validation, independently accessible shell controls around nested routes, wrapped choices and isolated combobox Clear action |
| Formatting | Shared display policy with an independent date input pattern; localized calendar and timestamp pickers preserve typed values |
| Refresh | Saved edits, action results and deletes invalidate affected data views |
| Search | Orders, customer email, dishes and invoices, including keyboard activation |
| Documents | One authorized query, persisted delivery-note content, escaped HTML/CSP, print invocation and blocked-popup download |
| Supporting routes | Lists and details for 14 resource destinations, with no failed API responses or browser exceptions |
| Local effects | Durable idempotent payment/message receipts, retry and refund behavior; provider results advance revisions |
| Reset | Repeated populated SQLite rebuilds preserve foreign-key enforcement and roll back failed resets |

## Reading the results

The visual checks compare rendered screens against the reference at measured
anchors. They do not claim pixel-identical output: Chrome and Flutter shape and
antialias the same fonts differently.

Some prototype text is deliberately driven by data. Reference numbers are
assigned only when an order is saved, and budgets, capacity and counts come from
persisted records. Current workflow events replace the illustrative timestamps.
Tax, discount, revenue and chart values reconcile rather than reproduce the
mock's contradictory figures. [DOMAIN.md](DOMAIN.md) has the exact business
contracts.

This is a local seeded demonstration. The payment and email adapters persist
demo receipts; they never charge a card or send an email. There is no production
identity provider. The document check intercepts the native print dialog and
also renders the document to PDF. Timings in the reports are local regression
signals, not a load test.
