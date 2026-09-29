# Changelog

All notable changes to Beak are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Beak aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) from `1.0.0`.
Until then the API is not frozen and the wire format is: a change to the query
spec, the commit and receipt JSON or the tunnel envelope is a breaking release.

Three things to know before you read on:

- **Lockstep.** `beak`, `beak_core`, `beak_backend`, `beak_frontend`,
  `beak_cli`, `beak_test`, `beak_image`, `beak_storage_s3`, `beak_storage_ftp`,
  `beak_serverpod`, `beak_serverpod_flutter`, `beak_serverpod_generator` and
  `beak_serverpod_server` share one version, `0.9.0`, and are released
  together. Each package's own `CHANGELOG.md` points back to this file. The
  vendored `worm*` packages keep their own `0.1.0` line and are not part of a
  Beak release.
- **The obers_ui pin must be fetchable, and current.** `beak` and `beak_frontend`
  depend on obers_ui by git commit (`c956d25634c93e23847ec5a4150c1d62fe3a7c90`, in
  the `pubspec.yaml` of both). Any `melos bootstrap`, and any project that
  resolves Beak from git, needs that commit to exist on
  `github.com/SimonErich/obers_ui`. It does, but it predates components
  `beak_frontend` uses (`OiFilterChip`, `OiPageLayout`, `OiCapacityIndicator`,
  `OiFieldLabel`, `OiIcon.raw` and more), so the pin resolves and the panel then
  fails to compile. The obers_ui state that has them is not published. Until the
  pin moves to it, work against a local checkout with
  `melos run link-obers-ui`, and go back to the pin with
  `melos run unlink-obers-ui`.
- **Nothing is tagged yet.** A scaffold written by `beak create` pins
  `ref: v0.9.0`, so until that tag exists use
  `beak create --beak-path <repo root of a checkout>` (absolute; `packages/<name>`
  is appended) or `--beak-ref <branch>`.

## [0.9.0] - Unreleased

The first release of the `beak*` packages. "Breaking" below means it changes or
removes something the pre-release line (`0.0.x`, the tree before the 0.9
cleanup) had. Where a break has a replacement, the entry names it, and the
migration table at the end collects the common ones.

### Added

#### Serverpod

- **Admin app in a Serverpod 4 workspace.** `beak_serverpod_server` runs Beak's
  stock Shelf API inside the Serverpod server, behind one gated endpoint method,
  on Serverpod's own database session. `BeakServerpodEngine` runs the pipeline in
  memory, `BeakAdminGate` puts `requireLogin` and the `beak.admin` scope in front
  of the endpoint, `ServerpodSessionAdapter` is a worm adapter on `session.db`
  (savepoints for nested transactions, typed error mapping), and commit receipts
  live in a Serverpod-owned table (`beak_commit_receipt`). A policy is required:
  there is no allow-all default. Only `/api/**` (minus `/api/auth/**`) is
  reachable, and only `content-type`, `accept`, `if-unmodified-since` and
  `x-beak-request-id` travel.
- `beak_serverpod`: tunnel envelope v1 and an HTTP client over it.
  `beak_serverpod_flutter`: `ServerpodBeakHttpClient` and a data source over the
  tunnel; it handles the sealed Serverpod client exceptions.
- **Client bridge.** `beak_serverpod` holds `ServerpodResource`,
  `ServerpodDataSource` and generated-model codecs so a panel can read and write
  through an existing Serverpod client. `beak_serverpod_generator` generates the
  typed resources from a Serverpod client.
- `examples/serverpod`: a Serverpod 4.0.3 workspace with an admin for `Author`
  and `Book` (see Examples below).
- `beak_backend`: `BeakFrameworkTables`, so the receipts table can be owned by
  another migration system, and an allowlist so only declared columns are
  selected, returned or stored in receipts.
- `sqlite3 ^3` in `worm_sqlite` and `beak_cli`, which Serverpod needs. The pinned
  Serverpod 4.0.3 CLI wrapper lives in `tool/serverpod_cli_4`.

#### Command line

- `beak init` adds Beak to an existing Flutter app: the dependency, `beak.yaml`,
  an authored entrypoint and a `.gitignore` block. It is idempotent and keeps
  comments. `--entrypoint`, `--beak-ref`, `--beak-path`, `--example`,
  `--[no-]pub` and `--dry-run` shape it.
- `beak introspect --ownership adopt|external` (adopt is the default). Adopt
  writes a baseline migration that changes nothing on the database it was read
  from and builds the tables on an empty one. External marks the resources
  `managesSchema: false` and writes no migration; foreign migration tables switch
  to it, and a Serverpod database is refused. `--save-url` writes `DATABASE_URL`
  into `.env`. `beak introspect` also accepts text columns as the display column,
  preferring `name`, `title`, `label`, `email`, then `code`.
- `BeakBaselineMigration` and `BeakIrreversibleMigrationException` in
  `beak_backend`. Discovery counts what a baseline lists, so `beak prepare`
  writes no create-table migration for adopted tables.
- `beak.yaml` `panel.entrypoint`: `beak prepare` never writes `lib/main.dart`,
  `beak doctor` walks the panel from it, and `beak dev` prints the matching
  `flutter run`.
- `beak migrate [status|up|down|fresh|refresh]` with `--pretend`, `--step`,
  `--steps`, `--seed`, `--force` and `-- <worm args>`, and
  `beak seed --class/--env/--force`. Both run the project's own
  `bin/migrate.dart`, show its output and return its exit code
  (`BeakCliEnvironment.runInteractive`).
- `beak create --authored` writes a `lib/main.dart` the project owns: a
  `BeakPanel(resources: [...])` that `beak prepare` never rewrites, a
  `NoteResource` and a smoke test that pumps `buildPanel(dataSource:)`. Plain
  `beak create` still generates the panel. Also new: `--[no-]example`,
  `--[no-]pub`, `--skills claude,agents,cursor|none` and `--beak-ref <ref>`.
  `create` runs `flutter pub get` first and installs the workflow skills.
- `beak eject main` switches a project from the generated entrypoint to an
  authored one, listing every resource the generated panel showed, in the same
  order, and un-ignoring `lib/main.dart`. With a `lib/panel.dart` override or
  non-default `beak.yaml` sidebar settings it writes
  `BeakPanel(config: BeakPanelConfig(...))` instead, so nothing on screen
  changes. It warns about each resource class whose model it cannot tell.
  `beak eject resource <table>` writes a `BeakResource` subclass to
  `lib/resources/<table>/<name>_resource.dart`, seeded from the table's
  `beak.yaml` icon, label and section, and refuses a table marked `hidden: true`.
- The generated panel (`lib/beak/panel.g.dart`) uses any `BeakResource` subclass
  under `lib/` (public, not abstract, an unnamed constructor that needs no
  arguments) in place of the default resource of the model whose table matches.
- `beak --version`, and `executables: {beak: beak}` in the pubspec, so
  `dart pub global activate --source path packages/beak_cli` puts `beak` on
  `PATH`. `beak create --beak-ref <ref>` pins the scaffold's git dependency;
  the default is `v0.9.0`, derived from `beakCliVersion`.
- `beak prepare` on a package of schema classes on its own (a package that
  depends on `beak_core` but not on `beak`, `beak_frontend` or `beak_backend`,
  such as the shared models package of a Serverpod workspace). It writes the
  `*.beak.dart` parts and `lib/beak/registry.g.dart` and nothing else; `beak
  doctor` checks what applies; `beak agents` and `beak docs` skip it with one line.
- `beak doctor` warns for every `BeakResource` subclass that an authored
  `lib/main.dart` does not list, naming the class and its file, and has an
  `agents` check group. The generated `bin/serve.dart` shuts down cleanly on
  SIGINT and SIGTERM, which also stops the host-scheduled outbox. A YAML syntax
  error in `beak.yaml` reports file, line and column and exits 1.
- `beak introspect` writes `lib/resources/<table>/models/` by default; `--out`
  still writes flat. `make:resource` prints the registration line for an authored
  project.
- Schema classes may declare `static BeakPermissions get permissions` and
  `static Set<BeakOperation> get capabilities`; the generated model forwards
  both. `beakStorageRegistry()` in `lib/server.dart` is wired into the generated
  host even when the file declares no `beakServer` override.
- `beak make:migration --force` and `beak introspect --force` replace a file that
  exists; without them both stop and name it. `--fields` takes the kind `double`.
  The generated host orders create-table migrations behind the tables their
  foreign keys point at, and a generated entrypoint that meets a refused setting
  (`PORT`, `DATABASE_URL`, a storage variable) prints one line and exits `78`
  (`BeakServeHost.configurationExitCode`).
- `beak prepare` says when a project has no models yet, refuses a directory that
  is not a Beak project, checks that a schema class declares its `part`
  directive, and reports with the file and the fix a bare `@Image()` or
  `@FileField()` (both need a `storagePath`), more than one `@Display`, and a
  field named like a member the typed record view owns (`record`, `summary`).
- `beak doctor` fails on a schema issue and on a migration that imports a file
  that no longer exists, warns about panel wiring that an earlier generated
  entrypoint left behind, and names the remedy for each kind of drift.
  `BeakCliEnvironment.processEnvironment` is the shell's environment, so a
  `DATABASE_URL` in the shell wins over `.env`.

#### Coding agents

- `beak agents` keeps a managed block in `AGENTS.md` between
  `<!-- BEGIN:beak-agent-rules -->` and `<!-- END:beak-agent-rules -->` (and a
  `CLAUDE.md` that imports it), pointing agents at the docs of the Beak version
  the project resolved. It never touches anything outside the markers, works in
  pub workspaces and is idempotent. `--check`, `--dry-run`, `--print`, `--force`
  and `--remove` are the switches; `beak.yaml` gains an `agents:` section
  (`instructions`, `docs`, `skills`). Four templates (standalone, embedded,
  Serverpod admin, workspace root), each under 2 KB.
- `beak docs` copies the docs bundle of the resolved `beak_core` to
  `.dart_tool/beak/docs`. `beak create`, `beak prepare` and `beak init` refresh
  the files.
- `melos run agent-docs` builds that bundle from `docs/` into
  `packages/beak_core/doc/agent-docs`: snippet includes expanded, admonitions and
  tabs flattened, links pinned to the release tag, plus a manifest, `SUMMARY.md`,
  `llms.txt` and this changelog. `melos run check-agent-docs` fails when the
  committed bundle is stale.
- Eight workflow skills, installed by `beak agents` and versioned with the
  packages: `beak-add-resource`, `beak-evolve-schema`, `beak-adopt-database`,
  `beak-add-business-rule`, `beak-secure-api` and `beak-upgrade` (in `beak`),
  `beak-frontend-build-screens` (in `beak_frontend`) and `beak-serverpod-setup`
  (in `beak_serverpod`). `tool/published_skills.dart` validates them.
- The repository has its own `AGENTS.md` for contributors, and the examples have
  `AGENTS.md` and `CLAUDE.md`.

#### Documentation and repository

- The documentation site is rebuilt: seven tabs (Start, Learn, Guides,
  Serverpod, Reference, AI directory, Contributing), 186 pages, published to
  GitHub Pages. `tool/check_docs.dart` checks front matter, nav labels, section
  indexes, headings per page type, quoted snippets, backticked repo paths and
  that no published address stops working; `--release` fails while any page is a
  draft. `/llms.txt`, `/llms-full.txt` and a Markdown twin of every page are
  generated. Docs tooling is pinned in `docs/requirements.txt`.
- LICENSE and README for the `beak` umbrella package, README for `beak_test`,
  LICENSE and CHANGELOG for `beak_serverpod`, CHANGELOG for
  `beak_serverpod_flutter`, `beak_serverpod_server` and `beak_serverpod_generator`.
- Per-package `README.md`s, workspace `LICENSE` (Apache-2.0), `NOTICE`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` and the architecture
  pages under `docs/architecture/`.
- `public_member_api_docs` lint enabled workspace-wide; every public API carries
  dartdoc, with usage examples on the primary user-facing types.
- `melos run unlink-obers-ui` goes back to the pinned obers_ui, which
  `link-obers-ui -- --unlink` could not. `melos run guard-hooks`
  (`tool/check_hook_widgets.dart`) fails a `StatefulWidget` or `State` in any
  package's `lib/`, and `check-agent-docs` runs inside `melos run analyze`. The
  docs workflow builds the agent bundle and, for a `v*` tag, checks it with
  `--release`. `tool/check_docs.dart` also checks snippet marker lines,
  line-range includes and routing scope, and the web guard walks both
  `schema.dart` libraries and the Serverpod libraries. CI gains the jobs
  `install-smoke`, `showcase-web`, `foodio-web` and `serverpod-example`.

#### Examples

- `examples/showcase` (the Aviary): all 47 block types on six pages, all 13
  column kinds on one specimen model and all four relationship kinds (including
  a many-to-many pivot), with soft deletes, timestamps and semantic fields. Three
  matrix tests switch exhaustively over the sealed hierarchies with no default
  branch, so a new block, column or relation kind fails to compile until the
  example shows it. Authored panel, SQLite, API on port 8082.
- `examples/serverpod`: a real Serverpod 4.0.3 workspace with a Beak admin for
  `Author` and `Book`. The server runs Beak's API behind one endpoint that needs
  a login and the `beak.admin` scope, with a deny-by-default policy and a
  server-only column that never leaves the database. Tests cover worm's adapter
  contract and Beak's data-source contract over the Serverpod session adapter,
  gate, leak, path and forgery cases, widget tests with a fake dispatch, and a
  live test against a running server on embedded Postgres.
- `examples/clean_beak_config` (the shop) and `examples/foodio-adminpanel`, the
  Gabel food-ordering admin: 48,213 persisted demo orders that exercise catalog
  ordering, inclusive VAT, voucher snapshots, delivery capacity, company budgets,
  approvals, invoices, append-only notes and persistent demo payment and message
  effects. The shop stores every amount as an exact `BeakDecimal` declared with
  `BeakSemantic.money`. Foodio's order resource is split into `list/`, `forms/`
  (with named wizard steps), `details/`, `presentations/`, `dashboard/` and
  `actions/`.
- The shop's fulfillment policies and product galleries, with additive
  migrations, seed data and responsive forms; Shop Operations, live receivables,
  variant staging, activation bulk actions and category imports as supported
  custom extension points.

#### Authoring in beak_core

- Semantic model metadata and generated typed helpers for email, URL, phone,
  slug, UUID, secret inputs, calendar dates, times, durations, exact decimals and
  money, percentages, quantities, file sizes, primitive lists and embedded
  objects.
- Shared model value lifecycles, named business actions and edit and delete
  guards, generated from schema behavior and enforced by graph commits. Typed
  candidate graphs, inverse dependency recalculation, field capabilities and
  server field-access enforcement across reads, queries, writes and receipts.
- Typed helpers so preparers and effects never spell a table or column name:
  `BeakRecordRef.of/draftOf/isOf`, `BeakModel.record`, `BeakScalarField.to`,
  `BeakToOneField.linkTo`, `BeakFieldValue` and `BeakFieldLink` build and check
  references and values; `BeakSaveOperation.create/sets/isVia`,
  `BeakCandidateNode.isOf/changedColumns` and
  `BeakCandidateGraph.writeAll/restore` read and adjust a candidate graph;
  `BeakDataSource` gains `find`, `findWhere`, `insert` and `patch` by model.
- Generated field roots are clean under Dart 3.12: `BeakXFields` has a
  no-argument constructor and a positional `.via(model, path)`.
- A byte-for-byte pinned wire-format test for `BeakSummarySpec` and
  `BeakSummaryResult`, plus decode tests for absent and null optional keys and
  int and double summary values.
- `rules: [BeakMaxLength(n)]` on a `String` field now also sets the stored column
  length, and `BeakMin` and `BeakMax` on an `int` field also set the column's
  `min` and `max`. When several apply, the tightest bound wins.
- Shared conditional, cross-field and collection validation; debounced unique
  and existence preflight checks; authoritative write checks and inferred unique
  indexes. Automatic choice controls, nullable booleans, dynamic product
  attributes, paired ranges, shared formatting and CSV policies, and model-driven
  defaults.
- Shared attribute descriptors, bounded variant-matrix previews, typed CSV
  imports and bulk-edit previews with per-record receipt recovery.
- Per-export typed columns and formats, including date patterns, currency minor
  units and enum labels. Schema `@EnumLabels` preserves readable labels across
  generated views without changing stored enum identifiers.
- `BeakInternalException` (`internal`), `BeakPayloadTooLargeException`
  (`payload_too_large`) and `BeakTransportException` (`transport`) join the
  sealed `BeakException`. `BeakPagination.maxPerPage` (200) is the largest page a
  server serves.
- `beakLikeEscape`, `beakEscapeLike` and `beakLikeRegExp` build and evaluate
  `LIKE` patterns with one escape character on every database, and worm's
  `Predicate.escape` states it in the SQL.
- Exact money sums: `BeakModel.sumDecimal` and `avgDecimal`,
  `BeakSummaryMeasure.sumDecimal`, `BeakSummaryRow.decimalOf`,
  `BeakScalarField<BeakDecimal>.avg`, `.scale` and `.exactColumn`,
  `BeakDecimal.tryFromUnits` and `fromRoundedUnits`, and `BeakRounding`.

#### beak_backend

- **Typed policies.** `BeakPolicies`, `BeakModelRules` and `BeakAccess` (`role`,
  `authenticated`, `anyone`, `any`, `all`, `not`) are a typed rule set that
  denies everything it does not list, with row scopes, per-action rules and
  read-only fields. `readOnlyFields` are enforced on the server: a client-supplied
  value is a 422 field error on create, update, validate, attach and detach,
  upload and graph commits, and the field is left out of the writable set.
- `BeakServer` and `BeakServerDefaults.build` accept `middleware` (after
  authentication, inside the error mapping, the first listed outermost),
  `routes` (tried before the generated API; a 404 or 405 falls through to it),
  `corsOrigin`, `generateId`, `transformRunner`, `graphOnly` and `outbox`.
  `BeakServer` also takes `now`, and exposes `outbox` and `onUnexpectedError`.
  `beakApiRouter` takes `transformRunner`, `onUnexpectedError` and `graphOnly`.
- `BeakOutboxSchedule(handlers:, interval:, drainLimit:, leaseDuration:,
  retryDelay:, maxAttempts:)` and `BeakOutboxLoop`: pass `outbox:` to
  `defaults.build` and `BeakServeHost.serve()` drains the outbox while it
  listens, and stops the loop after the drain in flight when the returned server
  closes. `BeakOutboxSchedule.validate()` throws a `BeakConfigurationException`
  for an invalid interval, drain limit or retry policy.
- `BeakServeHost.serve()` applies the host migrations and runs its seeders when
  the database is in-memory (`DATABASE_URL=sqlite::memory:`).
- `package:beak_backend` (and `package:beak/server.dart`) re-exports Shelf's
  `Handler`, `Middleware`, `Pipeline`, `Request` and `Response` and shelf_router's
  `Router`, so a `lib/server.dart` needs no direct Shelf dependency.
- Transactional graph finalizers and a durable outbox with leases, bounded
  retries and stable effect keys for idempotent provider adapters.
- Typed candidate-graph relationship writes preserve staged identities and
  revision guards.
- worm: `CurrentReadCapable` supplies current locking reads for MySQL guarded
  no-op writes, avoiding repeatable-read snapshots when changed-row counts are
  zero.
- `BeakPolicy.canDeleteUpload`, a dedicated authorization hook for upload removal,
  so the file's storage key never flows through `canDelete`'s record-id parameter.
- Upload routes resolve their column first: an unknown column is a 404, a non-file
  column a 422.
- worm_sqlite refuses adding a referencing column that has a non-NULL default
  (`alter.addColumn.foreignKey`), since SQLite would make every existing row point
  at the default.
- `BeakServerDefaults.build(storage:, dataSource:, signedUrlLifetime:,
  maxPerPage:)` takes a storage driver, a data source other than the worm
  default, the lifetime of signed upload links (one hour) and the largest page
  served (200). `BeakServer` also takes `onWarning`, which receives the one line
  it prints at boot when it listens beyond loopback with the allow-all policy.
- `POST /api/commits` is mounted over every data source. Over a source that is
  not a `WormDataSource` on a transactional adapter a save is staged: every
  operation is authorized first, then written through the source's own
  `create`, `update`, `delete`, `attach` and `detach` in dependency order,
  stopping at the first that fails. There is no rollback, and the receipts live in
  memory (`maxStagedReceipts`, 1024 by default).
- `GET /api/{table}/capabilities` reports `canCreate` and `canDelete` next to the
  field lists. `BeakModelRules(hiddenFields:)` hides a field from the principals a
  `BeakAccess` names. `WormDataSource.authorizeRead` is the read check that a
  graph preparer hands to `BeakCandidateGraph.open`, so it loads only what the
  caller may read.
- `BeakOutboxTable`, `BeakFrameworkTables.outbox`, `BeakOutbox.prune`,
  `BeakGraphCommitService.pruneReceipts` and `BeakCommitReceiptTable.createdAtColumn`
  let a project map the outbox onto its own table and prune old rows and receipts.
- `BeakTransformRunner.inspect` reads an image's size from its header, and
  `ImageTransformRunner(maxPixelCount:)` (50 megapixels by default) refuses a
  larger bitmap before it is decoded. `BEAK_S3_PUBLIC_BASE_URL` names the
  address S3 file URLs are built from. worm_postgres exports `decodeColumnValue`.

#### beak_test

- `InMemoryBeakDataSource` follows the backend more closely: dotted relation
  paths and relation filters, has-many attach and detach, `like` patterns with
  `%` and `_` (with `\` as the escape character, through `beakLikeRegExp`), and
  search through the same filter builder the server uses (`beakSearchFilter`). A
  widget test that filters or searches now sees what the server would return.
- `runBeakDataSourceContract` has groups for relation loads and for `attach` and
  `detach`, so a custom data source is held to them too.

#### beak_frontend: lists, filters and navigation

- Composed resource lists with query presets, grouped filters, saved views and
  shared query state for tables, operational summaries and exports. Conditional
  count and sum measures share the base filter, search and authorization scope.
- Resource filter bars default to compact chips that open their typed editor in a
  popover, with a clear action (`BeakFilterBarPresentation`).
- Configurable filter choice layouts, columns, all-value labels and advanced
  groups; typed range presets with semantic or calendar bounds, sheet width and
  descriptions. Value-bearing quick-filter chips, accessible inline date ranges,
  distinct preset count tones and per-preset row heights. Clearing an editable
  preset default stays cleared in previews, applied queries and bookmarks.
- Lists support compact quick-filter labels independently of full editor labels,
  collapsed summaries and compact summary strips, and configurable search
  placeholders. Presentation columns share their declared text alignment between
  headings and cells. Typed table columns expose `cellPadding`.
- `BeakListDefinition.scrollMode` chooses a bounded table viewport (the default)
  or intrinsic rows within page scrolling. `BeakNavigationItem.showCount`,
  `BeakListDefinition.fitTableToRows` and `floatingBulkActions` configure
  authorized navigation counts, list density and bulk actions.
- Compact composed lists scroll their overview and filters around a bounded row
  viewport, keeping pagination reachable at phone widths. Header search becomes a
  labelled icon button on compact screens, keeping the global command-search
  callback and the configured hint.
- Navigation can present the current record as a contextual branch and opt
  resource identifiers into semantic code typography, including breadcrumbs.
  Record breadcrumbs preserve the parent resource hierarchy. Navigation items can
  show authorized destination counts that refresh after writes.

#### beak_frontend: forms, wizards and drafts

- Reusable form sections, inferred dependent pickers, resumable drafts, change
  review, conflict resolution, an inspector and owned-graph duplication.
- Typed record templates, searchable selection cards, grouped variant catalogs,
  full-screen form wizards, progress, timelines, capacity indicators and inline
  named commands over the configured-form runtime. Inline model-command argument
  forms share their owner's dirty guard, durable drafts, validation and receipt
  recovery; primary commands can consume the same arguments in one atomic
  submission.
- Form layouts can opt into draft-derived change indicators for persisted
  editable fields, inline command arguments and newly added compact rows.
- Detailed form progress can opt into an intrinsic connected timeline rail.
  Wizard rails support live completed-step descriptions using the panel's
  formatting policy and contextual footer guidance. Header draft timestamps come
  from successful local writes or explicit resumption of a saved draft.
- Wizard steps separate navigation labels from pinned content headings and
  introductions. Input scrolling and step changes preserve the managed draft.
  Declarative wizard review sections navigate through session-owned step state;
  custom components read `BeakFormReader.stepIndex` and call
  `session.goToStep`.
- Record actions declare optional resource roles, including document actions.
  Generated lists and live read and edit forms honor them without changing
  permissions. Custom form frame builders also receive the current presentation
  mode.
- Relation card inputs can match and select an eligible default through
  `defaultOptionMatch` and `selectDefaultOption`, preserving manual choices and
  guarding stale dependency responses. Relationship pickers invalidate
  independently. Exact relationship code entry with automatic scoped lookup,
  loading, validation and local Apply and Remove actions.
- Relationship tables support inline advanced forms, typed identity controls and
  explicit compact cell widths, row padding and dividers, and omit empty row
  grids. Checkbox catalogs stage priced owned extras; retired selections remain
  removable. Compact relationship rows support minimum height, a configurable
  stacking threshold, scoped identity input sizes and conditional read-only
  details.
- Advanced collection creation opens the complete row editor immediately and
  discards the staged row on cancellation.
- Form sessions coalesce identical pending queries without retaining settled
  results; mutation notifications invalidate pending joins.
- Dynamic scalar inputs declare typed presentation dependencies for automatic
  relationship loading and permission-aware rendering. Calculated values support
  read-only field and checkbox presentations with explicit loading and permission
  dependencies; input labels and workflow milestones can describe the live draft.
- Scalar radio inputs support cards with option descriptions and icons through
  `inputRadio(cards: true)` and `BeakInputOption` metadata. Typed date shortcuts
  retain a full calendar picker; text placements support multiline sizing and
  model-derived character limits and counters. Quantity inputs forward an
  optional `controlWidthInPixels`, and `inputQuantity()` has typed bounds.
- `BeakFormatting.dateInputPattern` separates editable calendar and filter
  endpoint labels from date display, inheriting `datePattern` by default and
  preserving typed values, locale and portable policy serialization.
- Live form summaries can repeat related draft rows, including nested extras,
  without a separate editor. Conditional lines, reactive labels, tax captions and
  value emphasis share the panel formatting policy. Summary labels use the
  available width beside trailing prices; summary headings and inset metric strips
  support compact themed presentations. Capacity tracks support compact,
  accessible presentations with reactive explanations.
- `BeakCatalogPresentation.rows` composes compact variant, price and quantity
  rows; bounded local facets use `BeakCatalogFilter.matches` and typed
  dependencies; `formatBeakField` exposes shared formatting for composed option
  labels. Compact catalog toolbars combine segmented categories, accessible
  filter chips, aligned row headings and quantity steppers.
- Draft uploads, stored image URL resolution, and ordered owned galleries with
  local previews, retry and recovery, and cleanup of definitely uncommitted
  uploads.

#### beak_frontend: records, detail pages and layout

- Declarative record headers and printable documents with authorized persisted
  snapshots, inferred relationship loads, shared formatting and portable HTML
  delivery. Named table action columns support operational next steps.
- Detail screens support full-region tabs, configurable aside widths, separate
  read and edit layouts over one draft, compact message timelines, copyable
  record headings, and metric spacing and reactive captions. Generated form
  headers expose edit labels and emphasis, accessible compact action menus,
  explicit Back visibility and configurable outer spacing.
- The default show page is a read-mode form derived from the model, with a
  read-only tab per to-many relationship, loaded in one query.
- Record value bindings expose `textOverflow` for deliberate natural overflow of
  short titles and `badgeDot` for labelled status markers; badge icons render
  inside the semantic badge. Declared avatar tones take part in automatic
  presentation dependencies. Record metadata follows caption typography across
  tables, relationship choices and summaries and suppresses empty badges and
  orphan separators.
- Fixed block grids stack automatically when a spanned child would be narrower
  than `minChildWidthInPixels` (240 by default), using the available container
  width; zero disables the fallback. Expanded row blocks distribute space by child
  weights after actual gaps and stack when their container becomes too narrow.
- Sections expose heading typography, color and spacing. Plain form cards use an
  accessible disclosure that retains editor state and expands on validation;
  relation choice cards align their heights. Cards support optional headings,
  controlled collapse state and automatic expansion for validation errors.
  Form and wizard aside footers share their owner session and stay pinned in
  desktop and mobile summaries. Form and block card headers have an overridable
  16-pixel content gap.
- `BeakMetricBlock` compares against a prior period (`previous:`), shows the
  change as a signed percentage with a trend icon, and draws progress towards a
  goal (`target:`). It formats through the panel's display policy with `format:`
  (`BeakValueFormat.number`, `.currency` or `.percent`; `minorUnits:` and
  `scale:` display minor-unit sums as major units or rates) and appends `unit:`
  to the value and the target. It refreshes after writes to its prior period's
  table.
- Radio choice groups inherit section heading typography and selectable-card
  geometry from shared obers_ui component themes. Framed dashboards and generated
  record details no longer add a second card behind their declared surfaces.
  Navigation count styling and distributed, keyboard-accessible pagination come
  from shared obers_ui theme options in the Foodio example.

### Changed

- **Breaking, `beak_frontend`: one way to configure a resource.** `BeakResource`
  loses `label`, `section`, `detail`, `viewModes`, `createFields`, `editFields`,
  `createBuilder`, `editBuilder`, `formValueMode`, `createModel`, `editModel`,
  `editValues` and the `canXWhen` and `visibleWhen` hooks. Titles come from
  `title`, `navigationTitle` and `navigationGroup`, forms from screens, and
  visibility and permissions from `BeakModel.permissions`. `BeakScreen.label` and
  `section` become `navigationTitle` and `navigationGroup`. Every filter takes a
  typed `field:` instead of a column. `BeakPanel.fromConfig` is removed (the
  `config:` parameter stays); the form controller types are no longer exported;
  `TableViewModel` is `BeakTableViewModel`.
- **Breaking, `beak_frontend` and `beak_core`: no string references.** Model
  actions are referenced by object (`submitAction`, `bulkModelActions`,
  `BeakActionPresentation.model`, `snapshot(onAction:)`), and server preparers ask
  `plan.runs(action)`; the action's name stays the wire id. Sorting and search
  take typed fields: `field.ascending()`, `orderBy(field)`,
  `searching(term, fields)`. Aggregates take numeric fields. Summaries are
  `model.summary(groupBy:, measures:)` read with `row.valueOf(measure)`. List
  presets, preset counts and navigation destinations (`BeakNavigationItem.screen`)
  are objects, not keys or paths. `BeakNotificationSource` takes typed fields; the
  kanban and inbox blocks take typed field references.
- **Breaking, `beak_frontend`: units in names.** Numeric size, gap and spacing
  parameters carry their unit (`...InPixels`): the form layout family and its
  input helpers, aside and page gaps, the filter sheet, table columns, record
  templates and stored images. The form layer takes model actions by object
  (`submitAction`, `BeakFormActionInput(action:)`, `BeakFormActions(actions:)`,
  `BeakFormSession.save(action:)`). `BeakSummaryBlock.groupField` is gone; the
  group label comes from the summary query's `groupBy` field.
- **Breaking, `beak_backend`: typed policy hooks.** `BeakPolicy` and
  `BeakRowPolicy` take the `BeakModel`, `BeakFieldPolicy` takes a model and a
  field ref, `BeakActionPolicy` takes a `BeakModelAction`, and the upload hooks
  take a `BeakUploadColumn`. Wire strings are resolved inside the handlers.
- **Breaking, `beak_backend`.** `initializeWormPostgres` is renamed
  `initializeBeakDatabase`. `graphOnlyTables: Set<String>` is now
  `graphOnly: List<BeakModel>` (`graphOnly: [OrderModel()]`) on `beakApiRouter`,
  `BeakServer` and `BeakServerDefaults.build`; every model listed must be
  registered. `beakApiRouter` builds its upload service from `storage:` (plus
  `transformRunner:` and `generateId:`); the `uploads:` and `validation:`
  parameters are gone. `BeakServerDefaults.dataSource` is typed `WormDataSource`.
- **Breaking, `beak_cli`.** `@Column(min:, max:, maxLength:)` are replaced by
  `rules: [BeakMin(n)]`, `[BeakMax(n)]` and `[BeakMaxLength(n)]`.
  `@BelongsTo(searchOn:)` and `@BelongsToMany(searchOn:)` take `List<Symbol>`
  (`searchOn: [#email, #lastName]`), each checked against the related schema's
  fields; a list of strings is reported with the symbol spelling to use.
  `package:beak_cli/beak_cli.dart` exports only `createBeakRunner`,
  `BeakCliEnvironment`, `BeakPortProbe` and `BeakProcessRunner`.
- **Breaking, `beak_frontend`: the metric block.** `BeakMetricBlock` renders its
  own card and no longer depends on the dashboard stat card. `format:` accepts only
  `BeakValueFormat.number`, `.currency` and `.percent`; other formats fail an
  assertion. The chart data types (`BeakChartType`, `BeakChartPoint`,
  `BeakChartMapper`, `BeakBubblePoint`, `BeakCandle`, `BeakMatrixCell` and their
  mappers) live with the blocks; imports through
  `package:beak_frontend/beak_frontend.dart` are unchanged.
- Configured forms are the single editing runtime. The older
  `BeakDataForm`/`FormViewModel` stack and the resource form-step and layout
  fallbacks are removed; page blocks remain available for read views and custom
  composition. (Breaking.)
- `beak_backend`: the host clock (`BeakServeHost(now:)`) reaches every write,
  including per-record CRUD, graph commits and upload storage keys. CORS
  allow-headers include `if-unmodified-since`, and the origin is configurable.
  `authSessions` without an `authGuard` installs
  `TokenSessionAuthGuard(authSessions.store)`, so issued tokens are validated and
  `/api/auth/me` works. `BeakServeHost.serve()` validates the outbox schedule
  before it binds the port. `BeakOutboxWorker.drain` no longer lets a malformed
  row abort the drain: it marks the row `failed` (last error `malformedRow`),
  delivers every other candidate, then throws a `BeakConfigurationException` that
  names the rows it set aside. `/readyz` probes through the model's `count()` and
  answers 503 with a generic detail; the underlying error goes to
  `onUnexpectedError`.
- `beak_cli`: the generated panel sets `title:` and `navigationGroup:` from
  `beak.yaml` `label` and `section`. `beak create` and `beak make:resource` use
  the feature-folder layout `lib/resources/<plural>/models/<snake>.dart`;
  `make:resource` also writes `lib/resources/<plural>/<snake>_resource.dart` and
  refuses to overwrite. The scaffold's `.gitignore` no longer ignores
  `pubspec.lock`; generated mode still ignores `lib/main.dart`, `bin/serve.dart`
  and `bin/migrate.dart`, authored mode only the `bin/` entrypoints. The
  scaffold's README and `AGENTS.md` match the tool: `beak dev` serves the API and
  prints the `flutter run` line, field references are `NoteModel.title`, and both
  entrypoints are explained. `beak introspect` marks the tables it reads
  `managesSchema: false` and writes column lengths as `BeakMaxLength` rules.
  `beak migrate`, `seed`, `dev` and `init` show their child process's output and
  return its exit code. `beak_cli` is version 0.9.0.
- `examples/clean_beak_config`: `ExpandShopCatalog` adds reference columns only
  through the portable Blueprint path. The receivables card's actions stack
  full-width when the card is narrower than 320 px, and the availability toggles
  are labelled "For sale" so they fit a 375 px form column. Every amount is an
  exact `BeakDecimal`, so the shop needs a fresh database (delete `beak.db`, then
  migrate and seed).
- The foodio `VERIFICATION.md` holds only reproducible commands; the design
  reference `food-ordering-shop.html` moved to `examples/foodio-adminpanel/design/`.
  The bug-report template lists the current packages. `.gitignore` anchors local
  tooling patterns to the repo root, and the examples ignore `/storage/` and
  `*.db*`.
- `tool/link_obers_ui.dart` links by declared dependencies only. A pubspec's
  `executables:` entry named `beak` used to be read as a dependency on the panel,
  which gave the pure Dart CLI an obers_ui override.
- **Breaking, `beak_core`: three more `BeakException` variants.** An exhaustive
  `switch` over the sealed `BeakException` needs arms for
  `BeakInternalException`, `BeakPayloadTooLargeException` and
  `BeakTransportException`. `BeakClient` maps the codes `internal`,
  `payload_too_large` and `transport` to them, and a response without a Beak
  code by its status (`401`, `403`, `404`, `409`, `413` and `422` to their own
  variants, any `5xx` to `BeakInternalException`, anything else to
  `BeakTransportException`). It used to report every unknown code as a
  `BeakConfigurationException`.
- **Breaking, the wire format and `like`.** A backslash in the operand of `like`
  and `ilike` is the escape character on every database (`50\%` matches the text
  `50%`), and `contains`, `startsWith`, `endsWith` and searches escape `%`, `_`
  and `\` in the term, so a term matches the text it was given.
  `BeakDateTimeValue` serializes UTC and compares by instant.
- **Breaking, `beak_backend`: the query contract.** The server serves at most 200
  rows a page; a larger `perPage` is served as 200 and the envelope's `perPage`
  says so (`maxPerPage` on `defaults.build` lowers it). A mistake in a spec is a
  `422`, not a `500`: an unknown table, field or relation, an operand of the
  wrong type, a filter nested too deep, a dotted sort, aggregate or summary
  column, a non-numeric aggregate column, bad search columns.
  `BeakPagination`, `BeakSort` and `BeakRelationLoad` decode absent optional keys
  with their defaults.
- **Breaking, `beak_backend` and `beak_storage_s3`: the server host.**
  `BeakTransformRunner` has a new abstract `inspect`. `MinioS3ObjectClient` is
  renamed `HttpS3ObjectClient` and takes `httpClient:` and `clock:` instead of
  `minio:`; a failing S3 response throws `S3ResponseException`. Storage errors
  reach an HTTP caller as a generic message, and the driver's own text goes to the
  log. Upload responses carry signed links (`signedUrlLifetime`, one hour), so a
  private bucket is readable through them. A CSV cell that would run as a formula
  starts with `'`, and a null cell is empty. `PUT` is no longer a CORS method.
  `graphOnly` no longer needs a `preparePlan`.
- **Breaking, `beak_cli`: safer commands.** `beak create` refuses a directory
  that is not empty, `beak make:migration` refuses to overwrite a file, and
  `beak introspect` stops at a schema file you edited (`--force` overrides the
  last two). `beak migrate` checks its flags per verb (`--steps` belongs to `down`,
  `--seed` to `fresh`, `--force` to `fresh` and `refresh`) and exits `64` on one
  that does not fit; `migrate fresh` and `refresh` read `WORM_ENV` from `.env`.
  `--fields decimal`
  writes a `BeakDecimal` (it wrote a `double`, which is now `--fields double`).
  With an authored `lib/main.dart` or a `panel.entrypoint`, `beak prepare` neither
  writes nor compares `lib/beak/panel.g.dart` and `app.g.dart` and removes a pair
  a generated entrypoint left behind, unless a file of yours imports one. A
  refusal reads `Cannot generate: fix these first:` and lists every issue. The
  table-name pluraliser knows irregulars (`Person` is `people`, `Day` is
  `days`). A project counts as a Serverpod admin app only when it reaches its
  server through the tunnel.
- **Breaking (development only).** The ports of the compose stack bind to
  `127.0.0.1`. The corrections table of the agent docs takes its heading from
  the version, a missing table fails `check-agent-docs`, and a removed symbol is
  proven gone against public declarations, the vendored worm packages excluded.

### Removed

- **Breaking, examples.** `examples/store`, `examples/superdashboard` and
  `examples/embedded` are gone, with their CI, deployment files and tutorial
  references. `examples/quickstart` stays, byte-identical to `beak create`
  output; `examples/clean_beak_config`, `examples/foodio-adminpanel`,
  `examples/showcase` and `examples/serverpod` are the maintained ones.
- **Breaking, `beak_frontend`.** The legacy dashboard (`BeakDashboard`,
  `BeakStat`, `BeakChart` and the `dashboardStats`/`dashboardCharts` config): `/`
  redirects to `home:` or the first visible destination, and a custom overview is
  a `BeakScreen`. `BeakKpiBlock` and `BeakKpiFormat`: use `BeakMetricBlock` with
  `previous:`, `target:` and `format:`. `BeakWizardBlock` and
  `BeakBlockWizardStep`: use `BeakWizardScreen` for data wizards, or `OiWizard`
  from `package:beak/ui.dart`. `BeakMetricBlock.prefix` and `.suffix`: use
  `format:` for money and `unit:` for a unit. `beakChartWidget` is no longer
  exported. The dead `BeakDetailView`, relation fields and `ReferenceCache`.
- **Breaking, `beak_cli`.** The `lib/resources/<table>.dart`
  `BeakResource beakResource(BeakResource generated)` override: `beak prepare`
  reports the file and points at a `BeakResource` subclass, which
  `beak eject resource <table>` writes. The `lib/dashboard.dart`
  `beakDashboard()` override and `beak eject dashboard`: declare a `BeakScreen`
  with `path: '/'` under `lib/screens/`.
- **Breaking, `beak_backend`.** `GET /api/search`, `GlobalSearchService`,
  `BeakSearchHandlers`, `BeakClient.search` and `BeakSearchHit`: the panel searches
  each model through `globalSearchSources`. `BeakResourceService.query` and
  `aggregate(scope:)`. `BeakGraphCommitService(validation:)` and
  `beakApiRouter(validation:)`: custom rules belong on the model or in
  `preparePlan`. `postgresAdapterFromUrl` is private; use `adapterFromUrl` or
  `initializeBeakDatabase`. Un-exported internals: `WormQueryTranslator`,
  `WormRecordModel`, `BeakCrudHandlers`, `BeakExportHandlers`,
  `registerExportRoutes`, `BeakUploadHandlers`, `registerUploadRoutes`,
  `registerBeakCommitRoutes`, `beakResourceRouter`, `beakLocalUploadsRouter`,
  `beakHealthRouter`, `generateUuidV4`, `CsvExportService`, `UploadService`,
  `BeakResourceService`, `ValidationService` and `beakRowScope`.
- `beak_cli`: the unused `BeakDatabaseOpener` typedef; `isIntrospectableUrl` and
  `openPostgresConnection` are private to the live-schema reader.
- The tracked `.flutter-plugins-dependencies` under `packages/beak_frontend`, and
  the obsolete `/SUPERDASHBOARD_STATE.md` ignore entry.
- `package:minio` and, with it, the `dependency_overrides: xml: ^7.0.1` that a
  project depending on both `beak` and `beak_storage_s3` needed. The internal
  `requireJsonMapOrNull` in `beak_core`.

### Fixed

- `beak make:migration --from-drift` produced an unguarded alter that failed with
  `duplicate column name` on a fresh database. Every alteration is now guarded on
  the introspected schema, so the migration is re-runnable. Its belongs-to key was
  created as a varchar instead of a uuid, with no index or foreign key; it is now
  an indexed foreign key. It also imported `../models/...` for schemas under
  `lib/resources/**/models`; it now imports `../<libraryPath>`.
- `beak migrate status` exited 2 and `--pretend` printed usage.
- A project with no models had an unused `beak/ui.dart` import in `panel.g.dart`.
- `beak prepare` accepted a resource class that declares only named constructors
  and wrote a `Name()` call into `panel.g.dart` that does not compile. That class
  is now left alone and its model keeps the generated default.
- `beak eject main` dropped the project's `lib/panel.dart` override and the
  `beak.yaml` sidebar settings, listed a hidden model's resource class in the
  model's position, and wrote imports as several blocks. All three are fixed, and
  the entrypoint is `const` exactly when everything in it is constant.
- `beak create` shipped Flutter's Material counter-app `lib/main.dart`: `flutter
  create .` wrote it and `beak prepare` kept it because it had no GENERATED
  header. The scaffold now writes Beak's entrypoint before `flutter create` runs.
- Running `beak introspect` and then `beak prepare` wrote create-table migrations
  for tables that already existed.
- `@Column(maxLength:)` sized the column without validating it, while
  `rules: [BeakMaxLength]` validated without sizing it. The rule now does both.
- `beakStorageRegistry` was ignored unless `lib/server.dart` also declared
  `beakServer`. String literals generated from `beak.yaml` escape `$`.
- `beak` misuse prints the usage message and exits `64` instead of dumping a stack
  trace.
- `beak_backend`: the outbox claim ignored `availableAt` on SQL adapters; a graph
  commit's `preparePlan` ran before the policy check; integer route ids arrived as
  strings; graph commits ignored the injected clock and id generator; a malformed
  outbox row stopped every effect queued behind it on every drain; an invalid
  outbox schedule briefly bound the port and could serve requests before the boot
  failed; `sqlite::memory:` with `serve` served a database with no tables; CORS
  preflights rejected the optimistic-lock `if-unmodified-since` header, which
  broke cross-origin saves; `/readyz` leaked raw driver error text to
  unauthenticated callers.
- `beak_core`: `BeakSummaryMeasure`, `BeakSummarySpec` and `BeakSummaryRow` decode
  with typed pattern matching instead of `as` casts, wire format unchanged. Marking
  one notification read passed the notification object as the record id.
- `BeakJsonColumn`'s contract now matches its behavior: it carries its JSON
  document as text (`valueType` is `String`), with `BeakJson` used automatically
  by generated typed readers and writers over that storage.
- Eager loading: nested relation loads that share a head (`items.product` and
  `items.tax`) no longer clobber each other; the head is loaded once and every
  sibling nested relation is attached to the same records.
- Backend: malformed `POST /query` and `/aggregate` spec bodies return `422`
  instead of an opaque `500`, through a shared `readBeakSpec` helper used by the
  query, aggregate and export handlers. An explicit `null` primary key on create
  still mints a uuid, and `null` timestamp fields still stamp. CSV export runs its
  first page inside the request, so query failures map through the error boundary
  instead of streaming a `200` with a truncated body.
- Frontend: the filter bar and in-table column filters AND-merge instead of
  clobbering; `BeakDecimalColumn` cells honor their precision in the table
  (matching CSV export); a rejected many-to-many detach reverts the optimistic
  selection; concurrent table refetches resolve latest-wins; the built-in View and
  Edit row actions navigate without a wasted `getOne`; client-side content rules
  validate submitted whitespace strings exactly as the server does.
- Frontend: configured forms isolate editable semantics from transient validation
  status, keeping web input focus stable while asynchronous checks run. Combobox
  clear actions expose a separate, keyboard-accessible control, and activating the
  field opens its choices without clearing the selection. Catalog and rich search
  results disappear immediately while a changed term is debouncing. Completed and
  recovered form commands refresh related history in the current clean session;
  failed refreshes retain known relations and confirmed receipts, and hidden
  unsubmitted edits prevent replacing the draft. Record capabilities load in
  bounded batches and refresh on reload. Embedded table base filters apply from
  the first query and survive shared query changes, pagination, search and
  mutation refreshes. Stored-draft Resume and Discard actions wrap inside narrow
  forms and wizards. Picker hydration retains nested relationships requested by
  presentation bindings. Summary view switches expose their selected state, and
  chart series default to the chart palette.
- Graph commits and drafts: revision-guarded hard and soft deletion uses exact SQL
  compare-and-set checks, and unchanged graph updates preserve timestamps and
  snapshots while retaining operation receipts. Browser graph edits retain
  millisecond revision timestamps; revisions advance monotonically under a frozen
  clock, and legacy microsecond rows keep exact compare-and-set checks. Suggested
  relationship defaults preserve explicitly submitted links, and graph preparation
  reloads dependencies until values stabilize (a nonconverging calculation fails
  within a bounded number of passes). Suggested defaults do not propagate writes
  into existing snapshot records. Collection constraints inspect the final
  transaction state, including hidden siblings. Currency storage scale stays
  independent of display precision, and invalid editor text blocks saving without
  overwriting the last valid typed value.
- Uploads and media: scoped media URL lookup enforces visible record ownership,
  and cleanup handles close-during-save, recovery, preparation and partial
  rendition failures. FTP storage: `MKD` directory creation shares the transfer
  path's rooting, so relative `baseDir`s work on non-chrooted servers.
- SQLite: fresh migrations reverse registered applied migrations and reset seed
  tracking before rebuilding. A dedicated schema-reset transaction defers
  foreign-key checks until commit, retaining enforcement and rolling back failed
  populated rebuilds; unknown applied migrations fail before deletion. An alter
  that adds a column and declares a single-column foreign key over it compiles to
  one inline `ADD COLUMN ... REFERENCES ... ON DELETE ...` (it used to fail with
  `UnsupportedOperationException(alter.foreignKey)`), so `migrate:fresh` of the
  shop works again. Keys on existing columns, composite keys and dropping a key
  are still refused, with a clearer message.
- Examples: the shop's operations screen and product form no longer overflow at a
  375 px viewport, and the operations screen no longer overflows at 600 px; the
  foodio overview and orders list fit phone widths; foodio's reference theme uses
  outside card shadows without layout insets, and its provider effects advance
  monotonic revisions. Foodio saved payments require an active identity belonging
  to the customer and matching the selected payment mode, finished orders no
  longer offer approval or payment commands, seeded dish lines retain their
  allergen snapshots, queues skip obsolete charges and notifications, and paid
  financial terms cannot change without cancellation or refund.
- Tooling: `tool/check_coverage.dart` no longer describes the removed store
  example, and `test/check_examples_test.dart` expects `foodio-adminpanel`. Unlink
  no longer leaves a bare `dependency_overrides:` header behind.
- Queries: `%`, `_` and `\` in `contains`, `startsWith`, `endsWith` and search
  terms were wildcards. A `sum` or `avg` over a money column no longer goes
  through floating point: it keeps its integer units and reads back as a
  `BeakDecimal`.
- Server host: an invalid graph commit plan answered `500` at commit time and now
  answers `422`; health probes (`/healthz`, `/readyz`) failed on a bad
  `Authorization` header; a serial integer primary key could not be created or
  edited (SQLite; see Known issues for Postgres); a native Postgres enum column
  came back as raw bytes; a belongs-to eager load ignored its filter and a
  has-many load included a soft-deleted related row; an image that declared a
  huge bitmap was decoded before its size was checked; a port already in use
  ended in a stack trace and now in one line that names `PORT`.
- `beak_cli`: a field named like a member the generated model or its typed record
  view owns (`summary`, `record`), a non-unique `@Display`, a bare `@Image()` or
  `@FileField()` and an untyped `BeakScreen` produced generated code that did not
  compile or went unseen, and are now reported or found. `beak prepare` and `beak migrate`
  in a directory that is not a Beak project wrote files instead of refusing,
  `beak create` into a directory with files overwrote them, and `beak prepare`
  gave no note for an empty project. `beak introspect` wrote schema classes for
  `_beak_commit_receipts` and `_beak_outbox`, and warns once for each `numeric`
  column it reads as a `double`. `DATABASE_URL` from the shell now wins over
  `.env`, and `beak doctor` gives the right advice for a pending migration.

### Known issues

These are open at 0.9.0. None is listed as fixed above.

- A default `beak create` scaffold pins `ref: v0.9.0`, which does not exist until
  the release is tagged (use `--beak-path` or `--beak-ref` until then).
  `beak create --beak-path` and `beak init --beak-path` write the path into the
  pubspec as given, so a relative path resolves from the new project.
- The tracked lockfiles of `clean_beak_config`, `foodio-adminpanel` and
  `showcase` record a linked obers_ui (`path: "../../../obers_ui"`) until they are
  re-resolved against the pin. Run `melos run unlink-obers-ui` before you tag.
- `BeakWizardScreen` silently ignores several `BeakFormScreen` parameters.
- A composed list saves a view but shows no picker to load one.
- SQLite: `migrate:refresh` cannot roll back a belongs-to column made by a
  create-table migration (a table-level foreign key). Postgres can. The order of
  create-table migrations was proven on SQLite only.
- Not tested against a real Postgres: creating a row on a serial integer key,
  which relies on `RETURNING`, and writing a label into a native enum column.
  Reads of both work.
- `BeakDecimal` cannot read an existing `NUMERIC` column, because it reads and
  writes integer units. `beak introspect` keeps `double` for such a column and
  warns; converting it takes a migration of your own. A bare `@Image()` or
  `@FileField()` is reported by `beak prepare`, because `storagePath` is required.
- A graph commit over a data source that is not a `WormDataSource` on a
  transactional adapter is staged: no rollback, receipts in memory (a restart
  forgets them), and an operation with a version precondition
  (`expectedUpdatedAt`) is refused. `canDelete` in
  `GET /api/{table}/capabilities` is approximate for a per-record policy when the
  request has no `?id=`. The image pixel ceiling counts one frame of an animated
  GIF.
- worm's production gate reads `WORM_ENV` from the shell, so a value in `.env`
  applies through `beak migrate` but not when `bin/migrate.dart` runs directly.
- The Serverpod admin app path is a proof, not a product: it has no uploads, no
  drift check between `.spy.yaml` files and the Beak schema classes, and no tested
  deployment. `BeakPanel(...)` has no `mapException`; the bridge's exception
  mapping needs `BeakPanel(config: BeakPanelConfig(...))`.

### Migrating

From the pre-0.9 line, the renames people meet first:

| Before | Now |
| --- | --- |
| `@Column(maxLength: 80)`, `min:`, `max:` | `rules: [BeakMaxLength(80)]`, `[BeakMin(n)]`, `[BeakMax(n)]` |
| `@BelongsTo(searchOn: ['email'])` | `@BelongsTo(searchOn: [#email])` |
| `BeakResource(label:, section:)`, `BeakScreen(label:, section:)` | `title:`, `navigationTitle:`, `navigationGroup:` |
| A filter on a `BeakColumn` | A filter with `field: ProductModel.category` |
| `orderBy(column)`, `searching(term, [column])` | `orderBy(ProductModel.name)`, `searching(term, [ProductModel.name])`, `field.ascending()` |
| An action by name string | The `BeakModelAction` object |
| `graphOnlyTables: {'orders'}` | `graphOnly: [OrderModel()]` |
| `initializeWormPostgres` | `initializeBeakDatabase` |
| `BeakKpiBlock` | `BeakMetricBlock(previous:, target:, format:)` |
| `BeakWizardBlock` | `BeakWizardScreen` |
| `lib/dashboard.dart` `beakDashboard()` | A `BeakScreen` with `path: '/'` under `lib/screens/` |
| `lib/resources/<table>.dart` `beakResource()` override | A `BeakResource` subclass (`beak eject resource <table>`) |
| `GET /api/search`, `BeakClient.search` | `globalSearchSources` on the resource |
| `headerGap`, `minColumnWidth`, `dividerSpacing` and the other size and gap parameters | `headerGapInPixels`, `minColumnWidthInPixels`, `dividerSpacingInPixels` |
| `MinioS3ObjectClient(minio: ...)`, `dependency_overrides: xml` | `HttpS3ObjectClient(httpClient: ...)`, no override |
| A `switch` over `BeakException` | Add arms for `BeakInternalException`, `BeakPayloadTooLargeException` and `BeakTransportException` |
| `beak make:resource --fields price:decimal` (a `double`) | `price:double` for a `double`; `price:decimal` is a `BeakDecimal` now |

#### Migrating from beak_serverpod 0.0.x

The client bridge keeps its shape: `ServerpodResource`, `ServerpodModel`,
`ServerpodCodecs`, `ServerpodQueryReader`, `ServerpodDataSource` and
`ServerpodAuthAdapter` have the constructors they had at `0.0.1`, and nothing
here asks you to regenerate with `beak_serverpod_generator`. Three things change
around them.

- **Serverpod 4.0.3 or newer within 4.x.** `beak_serverpod_flutter` used to pin
  `4.0.0-beta.0` for `serverpod_auth_core_flutter` and `serverpod_auth_idp_client`
  and now declares `>=4.0.3 <5.0.0` (and `serverpod_client` in the same range),
  so raise your own pins to match. In that line `ServerpodClientException` is
  sealed and carries only a `message`; the `statusCode` lives on
  `ServerpodClientHttpException`, and transport failures are
  `ServerpodClientNetworkException` and `ServerpodClientUnknownException`. Code
  that caught `ServerpodClientException` and read `statusCode` must catch
  `ServerpodClientHttpException` instead. `ServerpodAuthAdapter` and
  `ServerpodAuthErrors` already do, and the tunnel classifies failures with a
  `switch` over the sealed family. Serverpod 4.0.3 also raises the floors to Dart
  3.12.2 and Flutter 3.44.4 for the admin app.
- **Typed ordering and searching.** `BeakQuerySpec.orderBy` and `searching` take
  typed fields (`BeakScalarField`), not columns. Over a hand-built
  `ServerpodModel` that is
  `BeakScalarField<Object>(model: model, column: title)`, passed as
  `spec.orderBy(titleField)` and `spec.searching('term', [titleField])`. This
  matters wherever you build a spec by hand, in tests for instance.
  `ServerpodQueryReader` reads sorts and searches from those fields, and a sort
  or search on a field it does not map still throws a
  `BeakConfigurationException`.
- **The resource is configured like any other.** A bridge resource sits in a
  `BeakResource`, so `title`, `navigationTitle` and `navigationGroup` replace
  `label` and `section`, and filters take `field:`.

New, and not required: `beak_serverpod` now depends on `http` and adds
`package:beak_serverpod/wire.dart` (the tunnel), and `beak_serverpod_server`
adds the admin app path. Neither changes what a bridge panel does.
