# Glossary

> Look up one-line definitions of Beak vocabulary, from schema class to graph commit to Serverpod tunnel, each linked to the page that explains it.

Scan this page when a name in a snippet is unfamiliar, or read it once to learn the shape of the framework. Each entry is one or two sentences and links to the page that covers it properly.

## Import

This page defines words, so it needs no import. Where a term is a Dart symbol, the definition names the library that exports it.

Beak's naming has one rule. Types that belong to the framework start with `Beak`. The schema annotations (`@Resource`, `@Column`, `@Display`, `@BelongsTo`) drop the prefix because they live in their own library, `package:beak/schema.dart`, which a panel file never imports. The types of the Serverpod bridge start with `Serverpod`, obers_ui's start with `Oi`, and `worm` and `obers_ui` are things Beak builds on and does not own.

## Summary

| Term | Definition | Read more |
| --- | --- | --- |
| Admin app in workspace | The Serverpod path where Beak's stock API runs inside your Serverpod server, behind one gated endpoint method and on Serverpod's own database. A Beak panel in the same pub workspace calls it. | [Admin app in your workspace](../serverpod/admin-app/index.md) |
| Adopt | The default `--ownership` of `beak introspect`. The generated schema classes own their tables, and a baseline migration (`BeakBaselineMigration`) records them: it changes nothing on the database you read and creates the tables on an empty one. | [An existing database](../start-here/paths/existing-database.md) |
| Annotation | Schema metadata on a schema class or field: `@Resource`, `@Column`, `@Display`, `@Image`, `@FileField`, `@Badges`, `@EnumLabels`, `@Custom` and the relationship annotations `@BelongsTo`, `@HasOne`, `@HasMany`, `@BelongsToMany`. | [Annotations](annotations.md) |
| Authored panel | A panel booted from a `lib/main.dart` you own, a `BeakPanel(resources: [...])` listing every resource class. `beak prepare` never rewrites it, and `beak eject main` switches a generated project to it. | [Two ways to boot a panel](../start-here/generated-or-authored.md) |
| Authoring type | An extension type over `String` in `package:beak/schema.dart` that names a column kind: `BeakText`, `BeakRichText`, `BeakHexColor`, `BeakImageRef`, `BeakFileRef`. Plain Dart types such as `BeakDecimal` and `BeakDate` need no marker. | [Semantic fields](../models/semantic-fields.md) |
| `beak prepare` | The generator command. It reads schema classes, resource classes, screens and `beak.yaml`, and writes the part files, the registry, the panel, app and server wiring, and the create-table migration for a model that has none. | [CLI commands](cli-commands.md) |
| `beak.yaml` | The project file: panel title, API origin, server binding, sidebar behaviour, agent settings and the presentation of default resources. Read at generate time and emitted as typed Dart. Every key is optional. | [beak.yaml](beak-yaml.md) |
| `BeakAccess` | Who may do something: `BeakAccess.role`, `authenticated`, or a combination through `any`, `all` and `not`. The building block of a `BeakModelRules` rule. | [Auth and policies](../backend/auth-and-policies.md) |
| `BeakBlock` | A sealed, immutable description of a piece of a page: a card, a chart, a field, a table. `BeakBlockHost` renders a tree of blocks onto obers_ui widgets, and a `BeakScreen` body is one. | [The block system](../concepts/the-block-system.md) |
| `BeakClient` | The typed REST transport in `beak_core`. It sends a `BeakQuerySpec`, reads records back, and maps an error body to a `BeakException` by its `code`. Most code reaches it through a data source. | [REST API](rest-api.md) |
| `BeakColumn` | One typed field definition, a sealed hierarchy with a leaf per column kind. Generated from your schema class, it drives the table cell, the form input, the detail row, the filter, the server validation and the CSV column. | [Field types](field-types.md) |
| `BeakContext` | The surface a value is drawn for: `table`, `form`, `detail` or `filter`. A column resolves one `BeakRenderIntent` per context. | [The one-definition promise](../concepts/the-one-definition-promise.md) |
| `BeakDataSource` | The source-agnostic interface both sides speak: `query`, `getOne`, `create`, `update`, `delete`, `restore` and more. `WormDataSource` implements it on the server, `HttpBeakDataSource` in the panel, `InMemoryBeakDataSource` in tests, `ServerpodDataSource` over a Serverpod client. | [The data source seam](../architecture/data-source-seam.md) |
| `BeakException` | The sealed base of Beak's error family. Every failure carries a stable `code` and a `message`, and the backend maps each subtype to an HTTP status. | [Exceptions](exceptions.md) |
| `BeakFormLayout` | A reusable tree of typed field nodes. The same tree serves reading, creating and editing. | [Screens and form layouts](screens-and-layouts.md) |
| `BeakFormScreen` | One layout for reading, creating and editing a resource. `BeakWizardScreen` presents the same form as steps. | [Form screens](../forms/form-screens.md) |
| `BeakFormSections` | A set of sections that can be projected into a stacked form, tabs or wizard steps. Conditions stay attached to the section when the presentation changes. | [Multi-step forms](../forms/multi-step-forms.md) |
| `BeakFormSession` | The runtime of one configured form. It owns the local record graph, validation, uploads, review and the save, and it asks the server for the receipt when the outcome of a save is unknown. | [Drafts, review and conflicts](../forms/drafts-and-review.md) |
| `BeakModel` | The runtime metadata of one resource: table, columns, relationships, delete semantics and display column. `beak prepare` writes one per schema class, named `<Name>Model`. | [Defining models](../models/defining-models.md) |
| `BeakModelAction` | A named, transactional command on one record. Declared once on the model and referred to by object from a form's submit action, a row or bulk action, and a server preparer. | [Behavior and actions](behavior-and-actions.md) |
| `BeakModelBehavior` | Shared declarations on a model: initial, suggested, derived and snapshot values, edit and delete guards, and named actions. The server re-runs them on every write. | [Model behavior](../models/behavior.md) |
| `BeakModelRegistry` | The index of registered models, keyed by table name. `beak prepare` generates `buildBeakRegistry()`, and the backend derives its routes from it. | [Generated files and symbols](generated-files.md) |
| `BeakModelRules` | The access rules of one model: who reads it, writes it and deletes it, which rows a principal sees (`rowScope`), which fields the server owns. Anything left out is denied. | [Auth and policies](../backend/auth-and-policies.md) |
| `BeakNavigationItem` | A resource or custom-screen destination inside a `BeakNavigationSection`. Both belong to the optional two-level `BeakNavigation`; without it navigation stays automatic. | [Navigation](../panel/navigation.md) |
| `BeakOperator` | The comparison in a filter clause: `eq`, `neq`, `gt`, `lt`, `contains`, `inList`, `between` and the rest. | [Queries](queries.md) |
| `BeakPanel` and `BeakPanelConfig` | `BeakPanel(resources: [...])` is the root widget. `BeakPanelConfig` is the complete configuration value, passed as `BeakPanel(config: ...)`. | [Panel and resource options](panel-options.md) |
| `BeakPolicies` | The typed policy of a server: one `BeakModelRules` per model, everything else denied. It compiles to the row, field and action hooks the handlers consult. | [Auth and policies](../backend/auth-and-policies.md) |
| `BeakQuerySpec` | The serializable description of a read: table, filter, sorts, search, relation loads and pagination. It travels as JSON between panel and server and means the same on both sides. | [Queries](queries.md) |
| `BeakRecord` | One row: `BeakValue`s keyed by column key, plus eagerly loaded relations. A record never lazy-loads. | [How data flows](../concepts/how-data-flows.md) |
| `BeakRenderIntent` | The UI-neutral hint a column resolves to for a context: `text`, `currency`, `badge`, `thumbnail`, `relationLink` and so on. `beak_frontend` maps each intent to an obers_ui widget. | [The one-definition promise](../concepts/the-one-definition-promise.md) |
| `BeakResource` | One resource in the panel: a model plus its navigation presentation and the screens, actions and filters its generated pages expose. A `BeakResource` subclass that `beak prepare` finds replaces the model's default. | [Resources](../panel/resources.md) |
| `BeakResult<T>` | The sealed return type of the panel's catch boundary: `BeakOk<T>` or `BeakErr`. View models switch on it and never `try/catch`. | [Results and errors](../concepts/results-and-errors.md) |
| `BeakRowPolicy` | A policy that answers which rows. Its `scopeFor(principal, model)` filter is intersected with every read and write of that model. | [Auth and policies](../backend/auth-and-policies.md) |
| `BeakRule` | A scalar validation rule such as `BeakMin`, `BeakEmail` or `BeakMaxLength`, shared by form and server validation. `BeakRecordRule` (`BeakExists`, `BeakFieldMatch`) validates across fields or records. Requiredness comes from nullability. | [Validation rules](validation-rules.md) |
| `BeakSavePlan` | The immutable snapshot a form submits: operations against stable record references, plus a `saveId` that makes a retry idempotent. The body of `POST /api/commits`. | [Graph commits](../architecture/graph-commits.md) |
| `BeakSchema` | The marker base class of every `@Resource` class. A schema class is a description, never an instance: its fields are `late final` with no constructor. | [Defining models](../models/defining-models.md) |
| `BeakScreen` | A custom page that is not a resource: a route, a navigation entry and a `BeakBlock` body, registered on `BeakPanelConfig.pages`. `BeakResourceScreen` is a resource's own page, and `BeakPage<T>` is a page of query results. | [Custom screens](../panel/custom-screens.md) |
| `BeakServeHost` | The server's whole lifecycle in one object: environment, typed config, database adapter, registry, running server, plus the migrate and seed CLI. Generated into `lib/beak/server.g.dart` as `beakHost()`. | [Running the server](../backend/running-the-server.md) |
| `BeakStorageDriver` | The interface of a file backend: `put`, `get`, `delete`, `url`, `exists`. Memory, local disk, S3 and FTP drivers implement it, and a `BeakStorageConfig` resolves to one through a `BeakStorageRegistry`. | [Files and storage columns](../models/files-and-storage-columns.md) |
| `BeakValue` | The sealed wrapper around one primitive (`BeakStringValue`, `BeakIntValue`, `BeakDateTimeValue`, `BeakNullValue` and others). It keeps every operand typed and JSON-safe on the wire. | [Queries](queries.md) |
| Bridge | The frontend-only Serverpod path. The panel calls your own typed endpoints through the generated client, each resource is a `ServerpodResource`, and no Beak code runs on the server. | [Client bridge](../serverpod/bridge/index.md) |
| Candidate graph | `BeakCandidateGraph`: a transaction-local view of existing records overlaid with all proposed writes. Business preparation reads it and writes trusted derived values before the commit. | [Transactional business rules](../backend/graph-business-rules.md) |
| Docs bundle | The Markdown copy of this site that matches the Beak version a project resolved. It ships inside `beak_core` and `beak prepare` or `beak docs` copies it to `.dart_tool/beak/docs`. | [Machine-readable docs](../ai/machine-readable-docs.md) |
| Drift | The difference between the columns the schema classes declare and the columns the live database has. `beak doctor` warns about it, and `beak make:migration --from-drift` writes a migration for the missing columns. | [Migrations](../backend/migrations.md) |
| Ejecting | Taking a Beak default over as a file your project owns. `beak eject <target>` takes `main`, `panel`, `resource`, `theme`, `auth` or `server` and writes the file pre-filled with the default, so the first edit is a diff. | [CLI commands](cli-commands.md) |
| Embedded panel | A panel added to an existing Flutter app by `beak init`. The app keeps its `lib/main.dart`, and `panel.entrypoint` in `beak.yaml` names the file that boots the panel. | [An existing Flutter app](../start-here/paths/existing-flutter-app.md) |
| External | The other `--ownership` value of `beak introspect`. Another system owns the tables: the classes are marked `managesSchema: false` and Beak writes no migration. It is the default when the database carries another tool's migration history. | [An existing database](../start-here/paths/existing-database.md) |
| Generated panel | A panel booted by the generated `BeakApp` in `lib/beak/app.g.dart`, built from `beak.yaml`, every model and the resource classes under `lib/`. `lib/main.dart` is git-ignored and rewritten by `beak prepare`. | [Two ways to boot a panel](../start-here/generated-or-authored.md) |
| Generated part file | The `<name>.beak.dart` part beside a schema class: columns, relations, fields, the model, and the draft and record views. Regenerate it, never edit it. | [Generated files and symbols](generated-files.md) |
| Graph commit | A whole form save sent as one `BeakSavePlan` to `POST /api/commits`: ordered operations across several records, committed in one transaction and answered with a receipt. | [Graph commits](../architecture/graph-commits.md) |
| `graphOnly` | The `BeakServer` option that lists models whose per-record write routes are closed, so every write to them goes through a graph commit and its business rules. | [Transactional business rules](../backend/graph-business-rules.md) |
| Handler | The backend's outer layer: a Shelf handler that parses the request, asks the policy, calls a service and encodes the result. The error-mapping middleware around it turns a thrown `BeakException` into a status and JSON. | [The four layers](../concepts/the-four-layers.md) |
| `HttpBeakDataSource` | The panel-side `BeakDataSource` that talks to the generated REST API. It connects a running `BeakPanel` to a `BeakServer`. | [The data source seam](../architecture/data-source-seam.md) |
| Managed block | The part of `AGENTS.md` between `<!-- BEGIN:beak-agent-rules -->` and `<!-- END:beak-agent-rules -->`. Beak rewrites only that block and keeps the rest of the file byte for byte. | [Set up your agent](../ai/setup.md) |
| Models-only package | A package that depends on `beak_core` and no app package, holding schema classes shared by a server and an admin. `beak prepare` writes the parts and the registry there and nothing else. | [Generated files and symbols](generated-files.md) |
| obers_ui | The widget kit Beak's UI is built on, with `obers_ui_autoforms` and `obers_ui_charts`. Beak never uses Material or Cupertino. | [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md) |
| One-definition promise | A single typed field declaration feeds the table, the form, the detail view, the filter, the REST validation, the migration and the CSV export. | [The one-definition promise](../concepts/the-one-definition-promise.md) |
| Outbox | A durable queue of effects. A commit enqueues into `_beak_outbox` in its own transaction (`BeakOutbox`), and a scheduled worker (`BeakOutboxSchedule`) delivers them after it, so no effect is delivered for a save that rolled back. | [Durable effects](../backend/durable-effects.md) |
| Presentation | How something is drawn, apart from what it does. `BeakRecordTemplate` presents a row, card or form identity, `BeakActionPresentation` redraws an existing action, `BeakInputPresentation` styles an input. Execution and policy stay shared. | [Workflow presentations](../forms/workflow-presentations.md) |
| Preset | A `BeakQueryPreset`: a named, counted view of a list, such as Today or Needs attention, over the same resource and permanent query scope. | [Composed lists and query state](../panel/composed-lists.md) |
| Receipt | The server's record of a graph commit, a `BeakSaveResult` stored in `_beak_commit_receipts` under the principal and the plan's `saveId`. It says what happened per operation, and a retry with the same id gets the same receipt. | [Graph commits](../architecture/graph-commits.md) |
| Record view | The generated typed reader over a `BeakRecord`, an extension type such as `NoteRecord` reached through `record.asNote`. A draft reader (`NoteDraft`) holds nullable values while a form is incomplete. | [Generated code](../models/generated-code.md) |
| Repository | The panel's catch boundary. It wraps each data-source call and returns a `BeakResult` instead of throwing. | [The four layers](../concepts/the-four-layers.md) |
| Saved view | A `BeakSavedView`: one named combination of a list's query choices, stored through a `BeakSavedViewStore` and resolved through normal resource authorization. | [Composed lists and query state](../panel/composed-lists.md) |
| `ServerpodResource` | A `BeakModel` bound to typed callbacks over your generated Serverpod client. It never opens a database connection or infers write behavior from an entity. | [Bridge resources](../serverpod/bridge/resources.md) |
| Service | The backend's logic layer. Services hold the business rules and throw typed exceptions, and data sources below them do raw I/O only. | [The four layers](../concepts/the-four-layers.md) |
| Skill | A workflow for a coding agent, shipped as `skills/<name>/SKILL.md` in a Beak package, with names that start with `beak-`. `beak agents` installs them into `.claude/skills`, `.agents/skills` or `.cursor/skills`. | [Set up your agent](../ai/setup.md) |
| Summary | A bounded grouped query over the whole matching population, never one page. `model.summary(groupBy: ..., measures: [...])` builds a `BeakSummarySpec`, and `BeakSummaryBlock` shows it. | [Population summaries](../blocks/summaries.md) |
| Tunnel | One Beak HTTP exchange flattened into the string a single Serverpod endpoint method carries (`BeakWireRequest`, `BeakWireResponse`). `BeakTunnelHttpClient` turns the string call back into an `http.Client`, so the panel's HTTP layer runs unchanged. | [How the admin app works](../serverpod/admin-app/how-it-works.md) |
| Type-safety promise | Beak's guarantee that you never write a string field reference and never touch `dynamic`. Columns, values, filters and results are typed end to end. | [The type-safety promise](../concepts/the-type-safety-promise.md) |
| ViewModel | The panel layer that exposes state as `ReadonlySignal`s and forwards intent. It reads outcomes from the repository and never catches. | [The four layers](../concepts/the-four-layers.md) |
| Wizard | A resource form presented as validated steps, `BeakWizardScreen`. `BeakFormSections` can project the same sections into a form or tabs. | [Multi-step forms](../forms/multi-step-forms.md) |
| worm | The Dart ORM under Beak's default backend, migrations and seeders. It is vendored under `packages/worm*`, and worm types reach application code only through `package:beak/migrations.dart`. | [Packages](packages.md) |
| `WormDataSource` | The backend's `BeakDataSource`. It translates a `BeakQuerySpec` and writes into worm operations and runs graph commits in a transaction. | [The data source seam](../architecture/data-source-seam.md) |

## Source

- `packages/beak_core/lib/src/` defines the data, query, column, rule, storage and error types.
- `packages/beak_frontend/lib/src/` defines the panel, screen, form, block and list types.
- `packages/beak_backend/lib/src/` defines the host, policy, commit and outbox types.
- `packages/beak_serverpod/lib/src/` and `packages/beak_serverpod_server/lib/src/` define the Serverpod types.
- `packages/beak_cli/lib/src/` defines the commands, `beak.yaml` and the agent files.

## Continue reading

- [Core concepts](../concepts/index.md) the ideas behind the vocabulary, in prose.
- [Annotations](annotations.md) the vocabulary you type in a schema class.
- [Packages](packages.md) which package each of these types lives in.
- [Exceptions](exceptions.md) the `BeakException` family and its wire mapping.
