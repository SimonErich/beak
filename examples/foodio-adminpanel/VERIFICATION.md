# Foodio / Gabel verification

Verification uses the release web build in installed Chrome, a real SQLite API,
and isolated unit/widget/API test databases. The reference is the supplied
`food-ordering-shop.html`; its ten screens are extracted with embedded fonts and
native HTML elements restored by `tool/extract_reference.py`.

The subsequent design correction pass is documented in [DESIGN.md](DESIGN.md).
It replaces the earlier surface, hover, typography and density behavior described
by the historical baseline below.

## Reproduce

Follow [README.md](README.md) to seed and run the API and release web preview.
Use the same Flutter installation for Dart, Flutter, generation and testing.
The current correction pass uses Flutter **3.44.0 stable**, revision
`559ffa3f75`, with Dart **3.12.0**. The local installation directory is named
`3.41.6-stable`; the version reported by the executable is recorded here.
Use that SDK for the app and both linked Obers packages. Earlier baseline logs
used a different SDK.

```sh
flutter test --concurrency=2
export FOODIO_URL=http://127.0.0.1:3002
npm exec --yes --package=playwright -- node tool/verify_list.cjs
npm exec --yes --package=playwright -- node tool/verify_search.cjs
npm exec --yes --package=playwright -- node tool/verify_documents.cjs
npm exec --yes --package=playwright -- node tool/verify_edit.cjs
npm exec --yes --package=playwright -- node tool/verify_workflow.cjs
npm exec --yes --package=playwright -- node tool/verify_delivery.cjs
npm exec --yes --package=playwright -- node tool/verify_supporting.cjs
npm exec --yes --package=playwright -- node tool/verify_search_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_pagination_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_wizard_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_drafts_mobile.cjs
npm exec --yes --package=playwright -- node tool/verify_hover.cjs
npm exec --yes --package=playwright -- node tool/verify_table_headers.cjs
npm exec --yes --package=playwright -- node tool/verify_compact_surfaces.cjs
```

The URL above matches the README's launch commands. The scripts default to
port 59389, the preview used during this implementation, if `FOODIO_URL` is unset.

The list, global search, document, edit and creation checks exercise cold and warm
passes. Run the edit and creation checks sequentially: both reserve Lena's budget.
The creation check cancels its orders afterward; the edit check restores the
original basket and delivery slot. Audit notes and demo effect receipts remain.
For a read-only wizard preview, set `FOODIO_PREVIEW_ONLY=1` on the workflow check.

Screenshots, accessible snapshots, API response codes and timing reports are
written to ignored `.artifacts/` directories. Reference screenshots use the
prototype's original viewports; the supporting-resource check also captures a
390 px mobile layout. These scripts are retained so checks can be repeated after
changing a reusable Beak or Obers component.

### Isolated commit verification

To exercise placement/cancellation without altering the serving fixture, make a
SQLite backup into an ignored artifact and serve it on a separate port. Run
these commands from `examples/foodio-adminpanel` (the source fixture filename
can be changed to the database you want to verify):

```sh
python3 - <<'PY_SQLITE'
import sqlite3
with sqlite3.connect('foodio-fidelity.sqlite') as source:
    with sqlite3.connect('.artifacts/foodio-verification.sqlite') as target:
        source.backup(target)
PY_SQLITE
DATABASE_URL=sqlite:.artifacts/foodio-verification.sqlite dart run bin/migrate.dart migrate
DATABASE_URL=sqlite:.artifacts/foodio-verification.sqlite PORT=8082 \
  dart run bin/serve.dart
```

In another terminal, route the workflow browser's API requests to that clone:

```sh
FOODIO_URL=http://127.0.0.1:59389 \
FOODIO_API_OVERRIDE=http://127.0.0.1:8082 \
FOODIO_ARTIFACTS=.artifacts/isolated-workflow \
  npm exec --yes --package=playwright -- node tool/verify_workflow.cjs
```

`FOODIO_PREVIEW_ONLY=1` stops before placement. Without it, the check places and
cancels its own orders in the clone; resulting audit notes/receipts remain there.
The override is supported by `verify_workflow.cjs` and `verify_edit.cjs`; the
release app otherwise uses `http://127.0.0.1:8081`. Run the edit script afterward
with the same override to check basket add/remove and inline notes. Do not run mutating verification scripts concurrently on
one database, since they share Lena's budget and slot reservations.

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

## Recorded checks — 28 September 2026

### Current correction pass

- Build 28 full suites: **680 frontend / 90 Foodio passed**; the chart
  package passed **797** at source 27, unchanged by 28. Compact/reduced-motion
  release matrix: **six passes**, zero browser errors, failed requests or writes.
  Recurring preference changes
  passed **32 API tests + two migration tests**, including typed times,
  Tuesday home-slot eligibility, unchanged Monday five-slot scope, nullable
  legacy upgrades, operator preference preservation and repeated migration.
- Source 24 pending-edit marker targets: **six passed**, covering persisted
  scalar and inline-note changes, restoration/discard, default-off/create,
  read-only/server permission denial, and newly added compact-row removal.
  Existing form targets passed **38 tests** and Obers text-input/quantity
  targets **27**; focused analyzers report no issues.
- Shared default-selection targets: **six passed**, covering blank resolution,
  manual preservation, unmatched/disabled preferences, dependency changes and
  stale responses. Repository/session/default targets: **35 passed**, including
  pending query sharing, fresh reads after completion, mutation invalidation
  and failure retry.
- Build 27 list checks passed cold/warm with **53 / 64 API requests**, zero
  errors and **214 staged-filter matches**; readiness **2,616 / 8,079 ms** under
  concurrent suites/captures. At 1440×1000 the natural table pagination begins at
  y1309 and page scrolling reaches it at y932; the last row begins below the
  viewport at y1261. Both passes assert reachable pagination and no errors.
  Build 21 isolated placement and
  cancellation passed twice: gross **€41.31**, net **€37.55**, approval pending;
  placement **1,866 / 572 ms**, cancellation **2,064 / 1,268 ms**. The separate
  edit check passed add/remove cycles, restoring **€31.40** total and **€56.60**
  budget; inline notes persisted immediately and after hard reload. Evidence:
  `.artifacts/fidelity-21/{workflow,edit}/report.json` and
  `.artifacts/fidelity-27-list/{report,short-page-report}.json`. Mutations used API port 8082's
  verification clone; the serving fixture on 8081 was unchanged.
- Build 24 isolated edit also passed two complete cycles and note persistence,
  restoring the same total and budget with zero browser errors. Under concurrent
  suites/captures, readiness was **5,764 / 2,453 ms**, save **6,021 / 3,976 ms**,
  and note **2,114 ms**. Its 377 requests include scheduled refresh traffic;
  comparing aggregate path counts across differently timed runs does not
  establish a performance improvement. Evidence:
  `.artifacts/fidelity-24/edit/report.json`. The final quiet workflow and edit
  checks run sequentially against the isolated API clone.
- Source 28 focused list targets: **10 passed**, including bounded/default
  versus intrinsic/page scrolling, reachable pagination and contextual branch/code
  mapping. Source 27 navigation/shell/breadcrumb/dialog targets passed **67**, including default
  expandable groups and keyboard navigation. Bar/theme axis targets passed **34**;
  the themed gap is 8px and the omitted numeric default stays 4px. Subsequent
  Cartesian propagation targets passed **11**, including every remaining painter
  and unchanged grid label typography. The 320px actual discard flow passes.
- Source 28 connector targets: **17 passed**; raw RGBA checks cover 21px inset,
  radius 8 and a distinct themed stroke. Code-label placement is unchanged.
- Build 26 list checks passed twice with **53 API requests each**, no errors,
  **214 staged-filter matches** and readiness **2,313 / 2,315 ms**. Evidence:
  `.artifacts/fidelity-26-list/report.json`.
- Source 26 button gap/padding targets: **60 passed**, including exact 2px width
  change for small controls, stable medium/large geometry, unchanged global
  fallback, leading/trailing icon-side padding, unchanged compact/plain
  controls, and theme copy/equality. Obers and Gabel focused analyzers are clean.
- Latest pagination/list/palette targets: **70 passed**; labelled segment
  geometry/interaction targets: **11 passed**. Both Foodio and frontend
  analyzers report no issues.
- Earlier Obers component checkpoint: **195 controls / 785 charts passed**.
  The final complete chart suite is 797 as recorded above.
  Subsequent list/menu/solid-facet, capacity, button and search targets passed
  **64 tests**, and the long-breadcrumb/search shell targets passed **31 tests**.
  Current record-template/composed-list targets passed **15 tests**.
- Build 28 expanded hover audit: **176 frames and four keyboard-focus checks**
  across light/dark and cold/warm passes. It covers the navigation rail plus
  New order, Export, All filters and both Show charts states at 0/100/250/500ms.
  Action bounds remain unchanged; browser errors, failed requests and writes
  are zero. Evidence: `.artifacts/fidelity28-hover/report.json`.
- Build 20 list checks completed cold/warm with **53 API requests each**,
  **214 staged-filter matches**, two-record selection export, keyboard row
  selection, row menu roles, organization removal/reselection and Escape,
  amount entry/clear, applied URL restoration, and formatted CSV. No browser
  errors or failed API requests. Readiness: **2,142 / 1,911 ms** locally.
- Global search completed both passes across orders, customers, dishes and
  invoices, including keyboard activation of an order result. Readiness waits
  accept the actual Today count rather than a fixed prototype number.
- Actual Mona Sans raster targets: **four passed**. For native weights 400,
  500, 600 and 700, a 350×40 raw RGBA text render is byte-identical to the matching
  explicit `wght` axis and differs from the preceding weight. Catalog titles
  declare the prototype's 14/20 weight 500; native hundred weights carry no stale
  `wght` override. This establishes the loaded Flutter test font and weight
  selection, not equality between Chrome CSS and Flutter engine rendering.
  The decoded embedded reference WOFF2 and app TTF also match instantiated
  glyph coordinates, contour endpoints/flags and hmtx metrics for all 221 shared
  Latin codepoints at weights 400, 500 and 580 (width 100). Evidence:
  `.artifacts/design-audit/font-outline-parity.json`. Matching roles/assets still
  leave measured shaping/raster differences between the two engines.
- Exact typography inspection confirms the reference payment title uses Mona
  Sans 14/20 weight 400, normal width, with a 116.514px text run. A 140px column
  with 12px padding leaves 116px: HTML allows the half-pixel overflow, whereas
  Flutter truncated it. The shared binding now allows an explicit overflow
  policy for that short label while keeping ordinary metadata truncation.
- Build 28 numeric total captures: both aside and review totals measure
  **77.671875px**, versus the reference's **77.6875px** text run; their 28px
  height and vertical position match. Four loaded-font role tests cover equal
  digit widths. Evidence: `.artifacts/fidelity28-wizard/currency-geometry.json`.

Evidence: `.artifacts/fidelity-20-list/report.json`,
`.artifacts/fidelity-23/{hover,compact}/report.json`, and screenshots/snapshots
alongside them. The initial ten-state measurements and CSS remain in
`.artifacts/design-audit/MEASUREMENTS.md` and `prototype-computed.json`.
Build 26 cold/warm captures establish the toolbar and header action strokes in
`.artifacts/fidelity-26-list/geometry.json`; the earlier card/drawer anchors
remain in the measurement matrix. Build 27 captures confirm the same strokes and capacity rows. Axis tick right
edges match x414 and their vertical paint rows match; some glyph left extents
still differ 1–3px. Detail breadcrumb/code paint matches within 1px. These are
measured anchors, not a claim that every painted pixel matches.
Build 28 compact list checks pass cold/warm at 375×812: a real row is reachable
and selectable at y422; selection clears and pagination is reachable at y676.
No browser errors or commit writes; evidence:
`.artifacts/fidelity-28-list/compact-reachability-report.json`.
Final contextual connector ink is x97–107/y104–121, reference x97–108/y104–121;
the code glyph bounds remain within 1px. Evidence:
`.artifacts/detail-fidelity-28/nav-raster.json`.

Final staged-edit captures exposed a region-wrapper flag omission; source 26
preserves the root opt-in and adds a header/aside regression. The final staged-edit release checks cover those indicators. Completed historical checks are retained below;
they do not certify the latest source checkpoint.

### Earlier functional baseline

| Gate | Result |
| --- | --- |
| Foodio complete unit/widget/API suite | 68 passed; analyzer clean |
| Beak frontend complete suite | 612 passed; analyzer clean |
| Beak backend complete suite | 412 passed; 2 external-service tests skipped |
| Beak core | 674 passed |
| Obers UI non-golden baseline and affected components | 5,567 baseline tests passed; subsequent input (247), shell/drawer (36), popover/trigger (26) related component (139) and sheet/layout (20) suites passed |
| Obers Autoforms affected widget suite | 48 passed |
| Worm / SQLite / migration suites | 1,243 / 98 / 43 passed |
| MySQL adapter | 75 passed; 4 service-dependent tests skipped |
| CLI unit/integration checks | 324 passed; PostgreSQL-only E2E requires its external service |
| Documentation | Documentation, Material-import and web-safety guards passed; strict MkDocs build passed |
| Example health | All three retained examples passed |

Obers' full analyzer has no errors or warnings; 19 existing informational SDK
notices remain. The MySQL guarded no-op change has explicit current-read and
concurrent-revision regressions plus independent review; service-dependent
integration coverage is not claimed for unavailable database services.

Latest completed local Chrome samples (some checks ran concurrently):

| Scenario | Cold / warm result |
| --- | --- |
| Orders, attention, advanced filters | 2,857 / 1,977 ms ready; 12 initial API requests; 214 canonical filter matches |
| Global search | Eight successful cross-resource navigations; 1,209–2,150 ms including typing/debounce |
| Delivery-note generation | 229 / 239 ms; one authorized query, no writes |
| Order editing | 2,232 / 1,276 ms ready; 3,818 / 2,498 ms atomic save, including live reservation adjustments |
| Add note | 874 ms; visible immediately and after hard reload |
| Five-step order creation | 1,538 / 209 ms ready; 874 / 515 ms atomic placement; €41.31 with exact discount and VAT |
| Cancellation | 927 / 817 ms; budget and capacity reservations released |
| Stored drafts on mobile | Resume at 390 px and Discard/reload at 320 px; wrapping actions stay visible and preserve/remove the intended local draft; zero commits |
| Mobile wizard | Two 390 px passes through all five steps, invalid/valid voucher correction, Back retention, padded summary sheets with visible close buttons and €41.31 total; zero commits |
| Compact shell | Search and labelled header controls at 320/390 px; readable stacked charts and working page navigation |
| Supporting destinations | 14 lists/details and a 390 px mobile layout; 90 requests, no browser or API failures |
| Delivery controls | Two browser passes verified private/company scope, date shortcuts, slot invalidation, multiline entry, address restoration, priced extras and uninterrupted preparation-note typing; zero commits |

Corresponding local evidence directories are
`.artifacts/foodio-list-1790572314917`,
`.artifacts/foodio-search-1790574851886`,
`.artifacts/foodio-documents-1790571763537`,
`.artifacts/foodio-edit-1790572255622`,
`.artifacts/foodio-workflow-1790575254320`,
`.artifacts/foodio-supporting-1790571627224`, and
`.artifacts/foodio-delivery-1790574175516`. Compact-shell evidence is in
`.artifacts/foodio-search-mobile-1790575253105` and
`.artifacts/foodio-pagination-1790574749222`. Complete mobile wizard evidence is
in `.artifacts/foodio-mobile-wizard-1790575719383`; final draft checks are in
`.artifacts/foodio-mobile-drafts-1790576245993`. Full gate logs are retained under
`.artifacts/` and `.artifacts/form-checks/RESULTS.md`.

After the earlier functional baseline, the demo was rebuilt from all 30 migrations and reseeded.
Those historical handoff checks confirmed 48,213 orders, 412 for the reference day, the original
four-item €31.40 order at 11:30, €56.60 budget remaining, one original note and
zero foreign-key violations. The pre-reset verification database is backed up
under `.artifacts/database-before-final-fidelity-handoff-20260928T060425Z/`; reset and integrity evidence
are in `.artifacts/final-handoff-seed.log`, `.artifacts/final-seed-check.json` and
`.artifacts/final-readiness.json`. That earlier release and seed state
were checked again in `.artifacts/final-handoff-state.json`.

## Visual and data interpretation

The implementation uses Beak layouts and Obers components for the navigation,
charts, list, filter sheet, wizard, profile cards, catalog, detail/edit pages,
review sections and action surfaces. It uses the reference's embedded Mona Sans
and JetBrains Mono fonts, color tokens, radii and desktop column geometry.
Responsive layouts adapt these surfaces for smaller widths. Fixed grids stack
when their spanned children would become too narrow; shell controls remain
accessible independently of nested navigation routes.

The final wizard passes include compact catalog rows, exact allergen filters,
live completed-step descriptions, actual saved-draft timestamps, priced basket
summaries and a pinned subtotal/discount/VAT/budget breakdown. Longer summaries
scroll independently while the total and actions remain available.

Visual verification compares rendered screens against the reference; it is not
a claim of pixel-identical raster output. Shared Beak and Obers configuration now
controls compact selectors, filter chips, pagination, row geometry, disclosure
sections, inset metrics and labelled actions. Existing item options expand
inline and internal notes submit inline. Adding a new item still uses the shared
staged-row dialog. The compact basket omits dish accompaniments from its labels;
the catalog, review and invoice retain the full saved name. These interactions
are exercised through UI and API checks.

Some prototype text is intentionally data-driven: reference numbers are assigned
only when an order is saved, budgets/capacity/counts come from persisted records,
and current workflow events replace illustrative timestamps. Tax, discount,
revenue and chart values reconcile instead of reproducing contradictory mock
figures. Lena's seeded phone uses the valid complete customer number. See
[DOMAIN.md](DOMAIN.md) for the precise business contracts.

This is a local seeded demonstration. Payment and email providers persist demo
receipts; they do not charge cards or send external email. The application does
not include a production identity provider. Browser printing checks intercept
the native print dialog and additionally render the resulting document to PDF.

Timing reports measure local Chrome/API behavior, including request settling;
they are regression evidence, not a production load-test claim. The release
bundles its rendering assets locally and does not require a CanvasKit CDN.
