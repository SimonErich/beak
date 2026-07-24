---
title: Glossary
description: One-line definitions of Beak's core vocabulary, alphabetical and cross-linked to the page that explains each in full.
---

# Glossary

A fast reference for every noun Beak uses. Each entry is one or two sentences and
links to the page that covers it properly. Scan it when a type name in a snippet
is unfamiliar, or read it top to bottom once to learn the shape of the framework.

Beak's naming has one rule: types that belong to the framework start with `Beak`.
The two exceptions are its siblings, `worm` (the ORM) and `obers_ui` (the widget
kit), which Beak builds on but does not own.

## Terms

| Term | Definition |
| --- | --- |
| `BeakBlock` | A sealed, `const` description of one piece of UI (a card, a chart, a field, a table). The panel walks a tree of blocks and renders it; the same block reads read-only in a detail view and editable in a form. See [The block system](../concepts/the-block-system.md). |
| `BeakClient` | The thin typed REST transport in `beak_core`. It sends a `BeakQuerySpec`, reads records back, and rebuilds typed [exceptions](exceptions.md) from the error `code`. Most apps use it through a data source rather than directly. See the [REST API reference](rest-api.md). |
| `BeakColumn` | One typed field definition, declared once as a `const`. A single column drives the table cell, the form field, the detail row, the filter, the server validation, and the CSV column. See [Column basics](../models/column-basics.md) and the [column types reference](column-types.md). |
| `BeakContext` | The surface a value is being rendered for: `table`, `form`, `detail`, or `filter`. A column asks its context which render intent to use. See [Rendering per surface](../concepts/rendering-per-surface.md). |
| `BeakDataSource` | The source-agnostic interface (`query`, `getOne`, `create`, `update`, `delete`, ...) that both sides speak. `WormDataSource` implements it over the ORM on the server; `HttpBeakDataSource` implements it over REST in the panel. See [The data source seam](../backend/the-data-source-seam.md). |
| `BeakException` | The sealed base of Beak's single error family. Every failure carries a stable `code` and a `message`, and the backend maps each variant to an HTTP status. See [Exceptions](exceptions.md). |
| `beakLocator` | Beak's package-scoped `GetIt` service locator. Dependency injection lives here so app code never reaches for a global singleton. See [The four layers](../concepts/the-four-layers.md). |
| `BeakModel` | The definition of one resource: its table name, display column, [columns](../models/column-basics.md), and [relationships](../models/relationships.md). You subclass it once and both the server and the panel consume it. See [Defining models](../models/defining-models.md). |
| `BeakModelRegistry` | The lookup table of every `BeakModel` an app knows, keyed by table name. The backend generates routes from it and the panel builds its navigation from it. See [The model registry](../models/the-registry.md). |
| `BeakOperator` | The comparison in a filter clause: `eq`, `gt`, `like`, `inList`, `between`, and the rest. It travels inside a `BeakFieldFilter` as part of a query spec. See [How data flows](../concepts/how-data-flows.md). |
| `BeakPanel` / `BeakPanelConfig` | `BeakPanel` is the Flutter root widget; you hand it a `BeakPanelConfig` (title, resources, API base URL, dashboard, auth, theme) and it stands up the whole admin app. See [The panel](../panel/index.md). |
| `BeakQuerySpec` | The serializable description of a read: table, filter, sorts, search, relation loads, and pagination. It travels losslessly as JSON between panel and server, so a query means the same thing on both sides. See [How data flows](../concepts/how-data-flows.md). |
| `BeakRecord` | One row as typed values plus its eager-loaded relations. It is `Map`-free: values are `BeakValue`s keyed by column, never `Map<String, dynamic>`. See [How data flows](../concepts/how-data-flows.md). |
| `BeakRenderIntent` | The concrete way to draw a value: `text`, `currency`, `badge`, `thumbnail`, `relationLink`, and so on. A column resolves one intent per [context](../concepts/rendering-per-surface.md). |
| `BeakResource` | The panel-side pairing of a `BeakModel` with its UI configuration: icon, actions, filters, view modes, detail layout, and form steps. See [Resources](../panel/resources.md). |
| `BeakResult<T>` | The sealed return type of the frontend catch boundary: `BeakOk<T>` or `BeakErr`. View models switch on it and never `try/catch`. See [Results and errors](../concepts/results-and-errors.md). |
| `BeakRule` | A single validation rule (`BeakRequired`, `BeakMin`, `BeakEmail`, ...) attached to a column. The identical rule runs client-side in the form and server-side before a write. See [Validation rules](../models/validation-rules.md). |
| `BeakStorageDriver` | The interface a file backend implements (`put`, `get`, `delete`, `url`, `exists`). Memory, local disk, S3, and FTP drivers all satisfy it, and a `BeakStorageConfig` resolves to one through a registry. See [Files and storage columns](../models/files-and-storage-columns.md). |
| `BeakValue` | The sealed wrapper around a single primitive (`BeakStringValue`, `BeakIntValue`, `BeakDateTimeValue`, `BeakNullValue`, ...). It keeps every value typed and JSON-safe as it crosses the wire. See [How data flows](../concepts/how-data-flows.md). |
| Dual-mode blocks | The property that one record-block tree (`BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock`) renders read-only inside a detail view and editable inside a form. One layout, two surfaces. See [Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md). |
| Handler | The backend's outermost layer: a Shelf handler that reads the request, calls a service, and lets the [error-mapping middleware](../backend/middleware.md) turn thrown exceptions into HTTP. The backend flow is Handler to Service to DataSource. See [The four layers](../concepts/the-four-layers.md). |
| `HttpBeakDataSource` | The panel-side `BeakDataSource` that talks to the generated REST API over HTTP. It is what wires a running `BeakPanel` to a `BeakServer`. See [The data source seam](../backend/the-data-source-seam.md). |
| obers_ui | The widget kit Beak's UI is built on. Beak uses `obers_ui`, `obers_ui_autoforms`, and `obers_ui_charts` for everything visual and never Material or Cupertino. See [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md). |
| One-definition promise | The design rule that a single typed column definition feeds the table, form, detail, filter, REST validation, and CSV export, so you write a field once. See [The one-definition promise](../concepts/the-one-definition-promise.md). |
| Repository | The frontend's catch boundary. It wraps each data-source call and returns a `BeakResult` instead of throwing, so view models stay `try/catch`-free. The frontend flow is Widget to ViewModel to Repository to DataSource. See [The four layers](../concepts/the-four-layers.md). |
| Service | The backend's logic layer. Services hold the business rules and throw typed [exceptions](exceptions.md); DataSources below them do raw I/O only. See [The four layers](../concepts/the-four-layers.md). |
| Type-safety promise | Beak's guarantee that you never write a string field reference and never touch `dynamic`. Columns, values, filters, and results are all typed end to end. See [The type-safety promise](../concepts/the-type-safety-promise.md). |
| ViewModel | The frontend layer that exposes state as `ReadonlySignal`s and forwards intent. It reads outcomes from the Repository and never catches exceptions itself. See [The four layers](../concepts/the-four-layers.md). |
| worm | The Dart ORM that backs Beak's default storage. App authors touch it directly in exactly two places: [migrations](../backend/migrations.md) and seeders. It is vendored under `packages/worm` and imported only by `beak_backend`. See the [packages reference](packages.md). |
| `WormDataSource` | The default server-side `BeakDataSource`. It translates every `BeakQuerySpec` into worm queries against a database adapter, and it is the only place worm types appear. See [The data source seam](../backend/the-data-source-seam.md). |

## Continue reading

- [Core concepts](../concepts/index.md) the ideas behind the vocabulary, in prose.
- [Packages](packages.md) which package each of these types lives in.
- [Exceptions](exceptions.md) the full `BeakException` family and its wire mapping.
