---
title: Glossary
description: One-line definitions of Beak's core vocabulary, alphabetical and cross-linked to the page that explains each in full.
---

# Glossary

A fast reference for every noun Beak uses. Each entry is one or two sentences and
links to the page that covers it properly. Scan it when a type name in a snippet
is unfamiliar, or read it top to bottom once to learn the shape of the framework.

Beak's naming has one rule: types that belong to the framework start with
`Beak`. There are two deliberate exceptions. The annotations
(`@Resource`, `@Column`, `@Display`, `@BelongsTo`) drop the prefix, because they
live in their own library that a panel file never imports. And its siblings,
`worm` (the ORM) and `obers_ui` (the widget kit), are things Beak builds on but
does not own.

## Terms

| Term | Definition |
| --- | --- |
| Annotation | One of `@Resource`, `@Column`, `@Display`, `@Image`, `@FileField`, `@Badges`, `@Custom`, `@BelongsTo`, `@HasOne`, `@HasMany`, `@BelongsToMany`. They come from `package:beak/schema.dart` and are the whole vocabulary of a schema class. See [Annotations](annotations.md). |
| Authoring type | A zero-cost extension type over `String` whose only job is to pick a column kind Dart has no type for: `BeakText`, `BeakRichText`, `BeakHexColor`, `BeakImageRef`, `BeakFileRef`. Declared on a field, gone at runtime. See [Column types](column-types.md). |
| `beak.yaml` | The project file: panel title, API origin, server binding, and per-resource presentation (icon, label, section, hidden). Read at generate time, emitted as typed Dart. Every key is optional. See [beak.yaml](beak-yaml.md). |
| `beak prepare` | The command that reads your declarations and writes everything else: the part file beside each schema class, the registry, the panel config, the app widget, the server host, the entrypoints, and any migration a new resource needs. Every other `beak` command runs it first. See [CLI commands](cli-commands.md). |
| `BeakBlock` | A sealed, `const` description of one piece of UI (a card, a chart, a field, a table). The panel walks a tree of blocks and renders it; the same block reads read-only in a detail view and editable in a form. See [The block system](../concepts/the-block-system.md). |
| `BeakClient` | The thin typed REST transport in the core library. It sends a `BeakQuerySpec`, reads records back, and rebuilds typed [exceptions](exceptions.md) from the error `code`. Most apps use it through a data source rather than directly. See the [REST API reference](rest-api.md). |
| `BeakColumn` | One typed field definition. You declare a field on a schema class; Beak generates the `const` column into the part file. A single column drives the table cell, the form field, the detail row, the filter, the server validation, and the CSV column. See [Column basics](../models/column-basics.md) and the [column types reference](column-types.md). |
| `BeakContext` | The surface a value is being rendered for: `table`, `form`, `detail`, or `filter`. A column asks its context which render intent to use. See [Rendering per surface](../concepts/rendering-per-surface.md). |
| `BeakDataSource` | The source-agnostic interface (`query`, `getOne`, `create`, `update`, `delete`, ...) that both sides speak. `WormDataSource` implements it over the ORM on the server; `HttpBeakDataSource` implements it over REST in the panel; `InMemoryBeakDataSource` implements it over maps in tests. See [The data source seam](../backend/the-data-source-seam.md). |
| `BeakException` | The sealed base of Beak's single error family. Every failure carries a stable `code` and a `message`, and the backend maps each variant to an HTTP status. See [Exceptions](exceptions.md). |
| `beakLocator` | Beak's package-scoped `GetIt` service locator. Dependency injection lives here so app code never reaches for a global singleton. See [The four layers](../concepts/the-four-layers.md). |
| `BeakModel` | The runtime definition of one resource: its table name, display column, [columns](../models/column-basics.md), and [relationships](../models/relationships.md). Generated from the `@Resource` class as `<Name>Model`, and consumed by both the server and the panel. See [Defining a resource](../models/defining-models.md). |
| `BeakModelRegistry` | The lookup table of every `BeakModel` an app knows, keyed by table name. `buildBeakRegistry()` in `lib/beak/registry.g.dart` builds it; the backend generates routes from it and the panel builds its navigation from it. See [The model registry](../models/the-registry.md). |
| `BeakOperator` | The comparison in a filter clause: `eq`, `gt`, `like`, `inList`, `between`, and the rest. It travels inside a `BeakFieldFilter` as part of a query spec. See [How data flows](../concepts/how-data-flows.md). |
| `BeakPanel` / `BeakPanelConfig` | `BeakPanel` is the Flutter root widget; `BeakPanelConfig` (title, resources, API base URL, dashboard, auth, theme) is what it is handed. Beak generates the config; `lib/panel.dart` is where you change it. See [The panel](../panel/index.md). |
| `BeakQuerySpec` | The serializable description of a read: table, filter, sorts, search, relation loads, and pagination. It travels losslessly as JSON between panel and server, so a query means the same thing on both sides. See [How data flows](../concepts/how-data-flows.md). |
| `BeakRecord` | One row as typed values plus its eager-loaded relations. It is `Map`-free: values are `BeakValue`s keyed by column, never `Map<String, dynamic>`. Read it through the generated record view (below) rather than by key. See [How data flows](../concepts/how-data-flows.md). |
| `BeakRenderIntent` | The concrete way to draw a value: `text`, `currency`, `badge`, `thumbnail`, `relationLink`, and so on. A column resolves one intent per [context](../concepts/rendering-per-surface.md). |
| `BeakResource` | The panel-side pairing of a `BeakModel` with its UI configuration: icon, actions, filters, view modes, detail layout, and form steps. Generated from the model and `beak.yaml`; adjusted one resource at a time in `lib/resources/<table>.dart`. See [Resources](../panel/resources.md). |
| `BeakResult<T>` | The sealed return type of the frontend catch boundary: `BeakOk<T>` or `BeakErr`. View models switch on it and never `try/catch`. See [Results and errors](../concepts/results-and-errors.md). |
| `BeakRowPolicy` | A policy that answers "which rows", not just "which tables". Its `scopeFor(principal, table)` filter is intersected with every read and write of that table, in the service layer, so no endpoint can forget it. See [Auth and policies](../backend/auth-and-policies.md). |
| `BeakRule` | A single validation rule (`BeakMin`, `BeakEmail`, `BeakMaxLength`, ...) listed in `@Column(rules: [...])`. The identical rule runs client-side in the form and server-side before a write. `BeakRequired` is the one you never write: nullability decides it. See [Validation rules](../models/validation-rules.md). |
| `BeakSchema` | The marker class every `@Resource` class extends. A schema class is a *description*, never an instance: its fields are `late final` with no constructor, and `beak prepare` reads them to generate the columns, the model, the relationships and the record view. See [Defining a resource](../models/defining-models.md). |
| `BeakServeHost` | The server's whole lifecycle in one object: environment to typed config to database adapter to registry to a running server, plus the migrate and seed CLI over the same wiring. Generated into `lib/beak/server.g.dart`. See [Running the server](../backend/running-the-server.md). |
| `BeakStorageDriver` | The interface a file backend implements (`put`, `get`, `delete`, `url`, `exists`). Memory, local disk, S3, and FTP drivers all satisfy it, and a `BeakStorageConfig` resolves to one through a registry. See [Files and storage columns](../models/files-and-storage-columns.md). |
| `BeakValue` | The sealed wrapper around a single primitive (`BeakStringValue`, `BeakIntValue`, `BeakDateTimeValue`, `BeakNullValue`, ...). It keeps every value typed and JSON-safe as it crosses the wire. See [How data flows](../concepts/how-data-flows.md). |
| Dual-mode blocks | The property that one record-block tree (`BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock`) renders read-only inside a detail view and editable inside a form. One layout, two surfaces. See [Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md). |
| Ejecting | Taking a Beak default over as a file this project owns. `beak eject <target>` writes it pre-filled with the default, so the first edit is a diff rather than a rewrite from the documentation. See [CLI commands](cli-commands.md). |
| Generated part file | `lib/models/<name>.beak.dart`, written beside each schema class by `beak prepare`. It holds `<Name>Columns`, `<Name>Relations` (both sides), `<Name>Model` and `<Name>Record`. Committed, and never edited. See [Generated code](../models/generated-code.md). |
| Handler | The backend's outermost layer: a Shelf handler that reads the request, calls a service, and lets the [error-mapping middleware](../backend/middleware.md) turn thrown exceptions into HTTP. The backend flow is Handler to Service to DataSource. See [The four layers](../concepts/the-four-layers.md). |
| `HttpBeakDataSource` | The panel-side `BeakDataSource` that talks to the generated REST API over HTTP. It is what wires a running `BeakPanel` to a `BeakServer`. See [The data source seam](../backend/the-data-source-seam.md). |
| obers_ui | The widget kit Beak's UI is built on. Beak uses `obers_ui`, `obers_ui_autoforms`, and `obers_ui_charts` for everything visual and never Material or Cupertino. See [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md). |
| One-definition promise | The design rule that a single typed field declaration feeds the table, form, detail, filter, REST validation, migration, and CSV export, so you write a field once. See [The one-definition promise](../concepts/the-one-definition-promise.md). |
| Record view | The generated extension type over a `BeakRecord` (`ProductRecord`, reached as `record.asProduct`). Reading through it returns the declared Dart type with the declared nullability: `record.asProduct.name` is a `String`, `record.asProduct.summary` a `String?`. See [Generated code](../models/generated-code.md). |
| Repository | The frontend's catch boundary. It wraps each data-source call and returns a `BeakResult` instead of throwing, so view models stay `try/catch`-free. The frontend flow is Widget to ViewModel to Repository to DataSource. See [The four layers](../concepts/the-four-layers.md). |
| Resource override | `lib/resources/<table>.dart`, a `BeakResource beakResource(BeakResource generated)` that `copyWith`s the parts of one generated resource you want different. Every other resource stays generated. See [Resources](../panel/resources.md). |
| Service | The backend's logic layer. Services hold the business rules and throw typed [exceptions](exceptions.md); DataSources below them do raw I/O only. See [The four layers](../concepts/the-four-layers.md). |
| Type-safety promise | Beak's guarantee that you never write a string field reference and never touch `dynamic`. Columns, values, filters, and results are all typed end to end. See [The type-safety promise](../concepts/the-type-safety-promise.md). |
| ViewModel | The frontend layer that exposes state as `ReadonlySignal`s and forwards intent. It reads outcomes from the Repository and never catches exceptions itself. See [The four layers](../concepts/the-four-layers.md). |
| worm | The Dart ORM behind Beak's default storage. You touch it directly in exactly two places: [migrations](../backend/migrations.md) and [seeders](../backend/seeding.md), both through `package:beak/migrations.dart`. It is vendored under `packages/worm` and imported only by `beak_backend`. See the [packages reference](packages.md). |
| `WormDataSource` | The default server-side `BeakDataSource`. It translates every `BeakQuerySpec` into worm queries against a database adapter, and it is the only place worm types appear. See [The data source seam](../backend/the-data-source-seam.md). |

## Continue reading

- [Core concepts](../concepts/index.md) the ideas behind the vocabulary, in prose.
- [Annotations](annotations.md) the vocabulary you actually type.
- [Packages](packages.md) which package each of these types lives in.
- [Exceptions](exceptions.md) the full `BeakException` family and its wire mapping.
