# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it
reaches `1.0.0`.

Until then, all packages share the pre-release `0.0.x` line and the API may
change without notice.

## [Unreleased]

### Added

- Declarative list `scrollMode` chooses a bounded table viewport (default) or
  intrinsic rows within page scrolling, using existing shared UI layout.
- Navigation can present the current record as a contextual branch and opt
  resource identifiers into semantic code typography, including breadcrumbs.


- Form layouts can opt into draft-derived change indicators for persisted
  editable fields, inline command arguments and newly added compact rows.
  Restoration, cancellation and field permissions retain their existing state.
- Quantity inputs forward optional `controlWidth` to the shared control.

- Relation card inputs can match and select an eligible default through
  `defaultOptionMatch` and `selectDefaultOption`, preserving manual choices
  and guarding stale dependency responses.
- Form sessions coalesce identical pending queries without retaining settled
  results; mutation notifications invalidate pending joins.

- Record value bindings expose `textOverflow` for deliberate natural overflow
  of short titles while retaining truncation for ordinary bounded metadata.
  Declared avatar tones participate in automatic presentation dependencies.

- Capacity summaries use consistent row gaps; compact list facets, counts,
  staged organization selection and exact monetary filter edits retain their
  shared presentation and query contracts.

- Typed table columns expose `cellPadding` for aligned, compact headings and
  cells, including scalar shortcuts and action columns.

- Record bindings support labelled status markers with `badgeDot`. Badge icons
  render inside the semantic badge instead of being duplicated alongside it.

- Composed list headers align actions with the bottom of their title and
  subtitle. Record-template metadata follows caption typography consistently
  across tables, relationship choices and summaries.

- Fixed block grids automatically stack when a spanned child would be narrower
  than `minChildWidthInPixels` (240 by default), using available container width.
  Desktop spans and natural card heights remain intact; zero disables the fallback.

- Configured forms isolate editable semantics from transient validation status,
  keeping web input focus stable while asynchronous checks run.

- Header search automatically becomes a labelled icon button on compact screens
  while preserving the global command-search callback and configured hint.

- Compact composed lists scroll their overview and filters around a bounded row
  viewport, keeping pagination reachable at narrow phone widths without app code.

- Relationship pickers invalidate independently, avoiding unrelated repeated
  queries while retaining source-mutation freshness and selected-option guards.

- Relationship tables support inline advanced forms, typed identity controls and
  explicit compact cell widths. Checkbox catalogs stage priced owned extras;
  retired selections remain removable. Calculated subtitles use global formatting.

- Dynamic scalar inputs declare typed presentation dependencies for automatic
  relationship loading and permission-aware rendering; checkbox labels expose
  the same declarative helper.

- `BeakFormatting.dateInputPattern` separates editable calendar and filter
  endpoint labels from date display, inheriting `datePattern` by default and
  preserving typed values, locale and portable policy serialization.

- Compact catalog toolbars combine segmented categories, accessible filter chips,
  aligned row headings and quantity steppers; record metadata suppresses empty
  badges and orphan separators. Relationship rows support independent column
  headings, inline size choices and typed `inputQuantity()` bounds.
- Sections expose heading typography/color and spacing. Plain form cards use an
  accessible disclosure that retains editor state and expands on validation;
  relation choice cards align their heights. Date shortcuts use segmented
  controls, while unavailable delivery slots remain visible but unselectable.

- Value-bearing quick-filter chips, accessible inline date ranges, distinct
  preset count tones and per-preset row heights. Clearing editable preset
  defaults now remains cleared in previews, applied queries and bookmarks.
- Lists support compact quick-filter labels independently of full editor labels;
  presentation columns share declared text alignment between headings and cells.
- Navigation count styling and distributed, keyboard-accessible pagination are
  provided by shared Obers theme options in the Foodio example.

- Inline model-command argument forms share their owner’s dirty guard, durable
  drafts, validation and receipt recovery; primary commands can consume the same
  arguments in one atomic submission. Foodio uses this for order amendments with
  optional internal notes while preserving the stricter standalone note command.
- Generated form headers expose edit labels/emphasis, accessible compact action
  menus, explicit Back visibility, and configurable outer spacing.
- Detail screens support full-region tabs, configurable aside widths, separate
  read/edit layouts over one draft, compact message timelines, copyable record
  headings, and metric spacing/reactive captions. Inline notices wrap gracefully.
- Foodio suggests eligible saved payment defaults through the customer's typed
  payment-method relation while retaining authoritative ownership/kind checks.

- Typed date shortcuts retain a full calendar picker; text placements support
  multiline sizing and model-derived character limits/counters. Compact relation
  cards accept responsive minimum widths and typed template progress bindings.
- Foodio supports explicit, area-bound one-order delivery addresses with an
  additive migration; location eligibility, route and transport stay authoritative.
- `BeakCatalogPresentation.rows` composes compact variant/price/quantity rows;
  bounded local facets use `BeakCatalogFilter.matches` and typed dependencies.
  `formatBeakField` exposes shared formatting for composed option labels.
- `BeakNavigationItem.showCount`, `BeakListDefinition.fitTableToRows` and
  `floatingBulkActions` configure authorized navigation counts and list density.


- Live form summaries can repeat related draft rows, including nested extras,
  without a separate editor. Conditional lines, reactive labels, tax captions
  and value emphasis share the panel formatting policy. Capacity tracks support
  compact accessible presentations with reactive explanations.
- Wizard rails support live completed-step descriptions using the panel's
  formatting policy and contextual footer guidance. Header draft timestamps
  come from successful local writes or explicit resumption of a saved draft.
- `CurrentReadCapable` supplies current locking reads for MySQL guarded no-op
  writes, avoiding repeatable-read snapshots when changed-row counts are zero.
- Navigation items can show authorized destination counts that refresh after
  writes; list tables can fit their rows and use floating bulk actions.
- Scalar radio inputs support cards with option descriptions and icons through
  `inputRadio(cards: true)` and `BeakInputOption` metadata.
- Relation tables expose row padding/dividers and omit empty row grids; workflow
  progress accepts a display-only initial state for absent values.
- Configurable filter choice layouts, columns, all-value labels and advanced
  groups; typed range presets with semantic/calendar bounds, sheet width and
  descriptions. Record breadcrumbs preserve the parent resource hierarchy.
- Declarative wizard review sections navigate through session-owned step state;
  custom components read `BeakFormReader.stepIndex` and call `session.goToStep`.
- Collapsed list summaries and compact summary strips; configurable list search
  placeholders. Cards support optional headings, controlled collapse state and
  automatic expansion for validation errors. Form/wizard aside footers share
  their owner session and remain pinned in desktop and mobile summaries.
- Advanced collection creation opens the complete row editor immediately and
  discards the staged row on cancellation. Card picker metadata fills its
  available width, with creation actions placed beside the heading.

- Composed resource lists with query presets, grouped filters, saved views and
  shared query state for tables, operational summaries and exports. Conditional
  count/sum measures share the base filter, search and authorization scope.
- Typed record templates, searchable selection cards, grouped variant catalogs,
  full-screen form wizards, progress, timelines, capacity indicators and inline
  named commands over the existing configured-form runtime.
- Declarative record headers and printable documents with authorized persisted
  snapshots, inferred relationship loads, shared formatting and portable HTML
  delivery. Named table action columns support operational next steps.
- Per-export typed columns and formats, including date patterns, currency minor
  units and enum labels. Schema `@EnumLabels` preserves readable labels across
  generated views without changing stored enum identifiers.
- Typed candidate-graph relationship writes preserve staged identities and
  revision guards. Foodio inline company profiles initialize monthly ledgers
  atomically, and catalog selections enforce their dated profile menu.
- Transactional graph finalizers and a durable outbox with leases, bounded
  retries and stable effect keys for idempotent provider adapters.
- The Gabel food-ordering admin in `examples/foodio-adminpanel`, preserving the
  original clean shop. Its 48,213 persisted demo orders exercise catalog ordering,
  inclusive VAT, voucher snapshots, delivery capacity, company budgets, approvals,
  invoices, append-only notes and persistent demo payment/message effects.

- Shared model value lifecycles, named business actions and edit/delete guards,
  generated from schema behavior and enforced by graph commits.
- Typed candidate graphs, inverse dependency recalculation, field capabilities
  and server field-access enforcement across reads, queries, writes and receipts.
- Reusable form sections, inferred dependent pickers, resumable drafts, change
  review, conflict resolution, an inspector and owned-graph duplication.
- Shared attribute descriptors, bounded variant-matrix previews, typed CSV
  imports and bulk-edit previews with per-record receipt recovery.
- Shop Operations, live receivables, variant staging, activation bulk actions
  and category imports demonstrating supported custom extension points.

- Semantic model metadata and generated typed helpers for email, URL, phone,
  slug, UUID, secret inputs, calendar dates, times, durations, exact decimals and
  money, percentages, quantities, file sizes, primitive lists and embedded objects.
- Automatic choice controls, nullable booleans, dynamic product attributes, paired
  ranges, shared formatting and CSV policies, plus model-driven defaults.
- Shared conditional, cross-field and collection validation; debounced unique and
  existence preflight checks; authoritative write checks and inferred unique indexes.
- Draft uploads, stored image URL resolution, and ordered owned galleries with
  local previews, retry/recovery and cleanup of definitely uncommitted uploads.
- The clean shop example's fulfillment policies and product galleries, including
  additive migrations, seed data, responsive forms and semantic-field coverage docs.
- Per-package `README.md`s, workspace `LICENSE` (Apache-2.0), `NOTICE`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, and
  `docs/architecture.md`.
- `public_member_api_docs` lint enabled workspace-wide; every public API now
  carries dartdoc, with usage examples on the primary user-facing types.
- `BeakPolicy.canDeleteUpload` — a dedicated authorization hook for upload
  removal, so the file's storage key is no longer passed to `canDelete`'s
  record-id parameter.

### Fixed

- Composed list tables use the card theme, compact control sizes and bottom-aligned
  header actions. Record metadata uses caption typography. Summary view switches
  expose their selected state and chart series default to the chart palette.
- Foodio's reference theme uses outside card shadows without layout insets,
  independent rail hover colors, exact caption typography and ordinary variable
  font weights that remain overridable by shared components.

- Revision-guarded hard and soft deletion uses exact SQL compare-and-set checks.
  Unchanged graph updates preserve timestamps and snapshots while retaining
  operation receipts and guarded no-op version checks.
- Record capabilities load in bounded batches and refresh on reload. Foodio
  note commands accept unchanged form rows, reject unsaved material edits, and
  audit descriptions use model labels instead of storage keys/derived amounts.
- Completed and recovered form commands refresh related history in the current
  clean session. Failed refreshes retain known relations and confirmed receipts;
  hidden unsubmitted edits prevent replacing the draft.
- Foodio saved payments require an active identity belonging to the customer
  and matching the selected payment mode, including inline staged identities.
- Combobox clear actions expose a separate named keyboard-accessible control;
  activating the field opens its choices without clearing its selection.
- Catalog and rich search results disappear immediately while a changed term
  is debouncing, preventing selection from an obsolete result set.
- Foodio provider effects advance monotonic revisions, and finished orders no
  longer offer operational approval/payment commands. Seeded dish lines retain
  their allergen snapshots. New food/drink selections populate classification
  and allergen previews, preserving food-only voucher parity with the server.

- Browser graph edits retain millisecond revision timestamps. Revisions advance
  monotonically under a frozen clock; legacy microsecond rows retain exact
  database compare-and-set checks after accepting a browser-truncated revision.
- Suggested relationship defaults preserve explicitly submitted links. Graph
  preparation reloads dependencies until values stabilize, allowing a customer
  default profile to supply its delivery location before authoritative validation.
  Nonconverging value calculations fail within a bounded number of passes.
- Picker hydration retains nested relationships requested by presentation
  bindings, including budget ledgers. Suggested defaults do not propagate writes
  into existing snapshot records when a referenced catalog record changes.
- SQLite fresh migrations reverse registered applied migrations and reset seed
  tracking before rebuilding. A dedicated SQLite schema-reset transaction
  defers foreign-key checks until commit, retaining enforcement and rolling back
  failed populated rebuilds. Unknown applied migrations fail before deletion.
- Foodio queues skip obsolete charges and notifications; paid financial terms
  cannot change without cancellation/refund. Budget previews replace existing
  reservations and use the same voucher, food and tax snapshots as the server.

- Currency storage scale stays independent of display precision. Empty required
  lists and objects retain their declared semantics; invalid editor text blocks
  saving without overwriting the last valid typed value.
- Collection constraints inspect the final transaction state, including hidden
  siblings. Scoped media URL lookup enforces visible record ownership, and cleanup
  handles close-during-save, recovery, preparation and partial rendition failures.
- **Eager loading:** nested relation loads that share a head (e.g.
  `items.product` + `items.tax`) no longer clobber each other — the head is
  loaded once and every sibling nested relation is attached to the same records.
- **Backend:** malformed `POST /query` and `/aggregate` spec bodies now return
  `422` instead of an opaque `500`; an explicit `null` primary key on create
  still mints a uuid (and `null` timestamp fields still stamp); CSV export runs
  its first page inside the request so query failures map through the error
  boundary instead of streaming a `200` with a truncated body.
- **Frontend:** the filter bar and in-table column filters now AND-merge instead
  of clobbering; `BeakDecimalColumn` cells honor their precision in the table
  (matching CSV export); a rejected many-to-many detach reverts the optimistic
  selection; concurrent table refetches resolve latest-wins; built-in
  View/Edit row actions navigate without a wasted `getOne`; client-side content
  rules validate submitted whitespace strings exactly as the server does.
- **CLI:** `beak` misuse now prints the usage message and exits `64` instead of
  dumping a stack trace.
- **Storage (FTP):** MKD directory-creation paths share the transfer path's
  rooting, so relative `baseDir`s work on non-chrooted servers.
- **Core:** `BeakJsonColumn`'s contract now matches its behavior — it carries
  its JSON document as text (`valueType` is `String`), with `BeakJson`
  used automatically by generated typed readers and writers over that storage.

### Changed

- Configured forms are the single editing runtime. Removed the older
  `BeakDataForm`/`FormViewModel` stack and resource form-step/layout fallbacks;
  page blocks remain available for read views and custom composition.
- Retained the quickstart and clean shop examples; removed obsolete example
  applications and updated CI, deployment files, tutorials and API guides.

- Extracted the malformed-spec decode-and-map-to-422 logic into a shared
  `readBeakSpec` helper, reused by the query, aggregate, and export handlers.
