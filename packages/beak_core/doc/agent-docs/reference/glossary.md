# Glossary

> Look up one-line definitions of Beak vocabulary, cross-linked to the page that explains each.

A reference for the main terms Beak uses. Each entry is one or two sentences and
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
| Annotation | Schema metadata such as `@Resource`, `@Column`, relationship declarations and semantic field annotations. They come from `package:beak/schema.dart`. See [Annotations](annotations.md). |
| Authoring type | A type that selects field semantics in a schema. String-backed markers include `BeakText`, `BeakRichText`, `BeakHexColor`, `BeakImageRef` and `BeakFileRef`; domain values such as `BeakDate` and `BeakDecimal` retain their typed representation through generated readers and codecs. See [Semantic fields](../models/semantic-fields.md). |
| `beak.yaml` | The project file: panel title, API origin, server binding, and per-resource presentation (icon, label, section, hidden). Read at generate time, emitted as typed Dart. Every key is optional. See [beak.yaml](beak-yaml.md). |
| `beak prepare` | The generator command that reads declarations and writes schema parts, registry, generated panel/server wiring and migrations for newly discovered resources. See [CLI commands](cli-commands.md). |
| `BeakBlock` | A sealed, immutable description of a card, chart, field or other page element. `BeakBlockHost` renders its tree; record fields read from `BeakRecordScope`. Configured forms use typed form layouts for editing. See [The block system](../concepts/the-block-system.md). |
| `BeakClient` | The thin typed REST transport in the core library. It sends a `BeakQuerySpec`, reads records back, and rebuilds typed [exceptions](exceptions.md) from the error `code`. Most apps use it through a data source rather than directly. See the [REST API reference](rest-api.md). |
| `BeakColumn` | One typed field definition. You declare a field on a schema class; Beak generates the `const` column into the part file. A single column drives the table cell, the form field, the detail row, the filter, the server validation, and the CSV column. See [Column basics](../models/fields.md) and the [column types reference](field-types.md). |
| `BeakContext` | The surface a value is being rendered for: `table`, `form`, `detail`, or `filter`. A column asks its context which render intent to use. See [Rendering per surface](../concepts/the-one-definition-promise.md). |
| `BeakDataSource` | The source-agnostic interface (`query`, `getOne`, `create`, `update`, `delete`, ...) that both sides speak. `WormDataSource` implements it over the ORM on the server; `HttpBeakDataSource` implements it over REST in the panel; `InMemoryBeakDataSource` implements it over maps in tests. See [The data source seam](../architecture/data-source-seam.md). |
| `BeakException` | The sealed base of Beak's single error family. Every failure carries a stable `code` and a `message`, and the backend maps each variant to an HTTP status. See [Exceptions](exceptions.md). |
| `beakLocator` | The package-level fallback dependency container. Panel child widgets should use `beakDependencies(context)` to resolve their own panel scope. See [The four layers](../concepts/the-four-layers.md). |
| `BeakModel` | The runtime definition of one resource: its table name, display column, [columns](../models/fields.md), and [relationships](../models/relationships.md). Generated from the `@Resource` class as `<Name>Model`, and consumed by both the server and the panel. See [Defining a resource](../models/defining-models.md). |
| `BeakModelRegistry` | The lookup table of runtime models keyed by table. Generated `buildBeakRegistry()` includes discovered models and relations; the backend derives routes from it. Panel navigation comes from configured resources and pages. See [The model registry](../models/generated-code.md). |
| `BeakOperator` | The comparison in a filter clause: `eq`, `gt`, `like`, `inList`, `between`, and the rest. It travels inside a `BeakFieldFilter` as part of a query spec. See [How data flows](../concepts/how-data-flows.md). |
| `BeakPanel` / `BeakPanelConfig` | `BeakPanel(resources: [...])` mounts declared resources and custom pages with routing, navigation and scoped services. `BeakPanel.fromConfig` accepts a complete config, which may be generated or supplied by the host. See [The panel](../panel/index.md). |
| `BeakQuerySpec` | The serializable description of a read: table, filter, sorts, search, relation loads, and pagination. It travels losslessly as JSON between panel and server, so a query means the same thing on both sides. See [How data flows](../concepts/how-data-flows.md). |
| `BeakRecord` | One row with `BeakValue` entries and eagerly loaded relations. Application code reads typed fields or generated record views rather than string map keys. See [How data flows](../concepts/how-data-flows.md). |
| `BeakRenderIntent` | The concrete way to draw a value: `text`, `currency`, `badge`, `thumbnail`, `relationLink`, and so on. A column resolves one intent per [context](../concepts/the-one-definition-promise.md). |
| `BeakResource` | The panel-side model configuration for navigation, screens, search, filters, view modes and actions. Define it explicitly or customize a generated default. See [Resources](../panel/resources.md). |
| `BeakResult<T>` | The sealed return type of the frontend catch boundary: `BeakOk<T>` or `BeakErr`. View models switch on it and never `try/catch`. See [Results and errors](../concepts/results-and-errors.md). |
| `BeakRowPolicy` | A policy that answers "which rows", not just "which tables". Its `scopeFor(principal, table)` filter is intersected with every read and write of that table, in the service layer, so no endpoint can forget it. See [Auth and policies](../backend/auth-and-policies.md). |
| `BeakRule` | A scalar validation rule such as `BeakMin`, `BeakEmail` or `BeakMaxLength` consumed by both form and server validation. Requiredness is inferred from schema nullability; explicit `BeakRequired` and model record rules refine the contract. See [Validation rules](../models/validation.md). |
| `BeakSchema` | The marker class every `@Resource` class extends. A schema class is a *description*, never an instance: its fields are `late final` with no constructor, and `beak prepare` reads them to generate the columns, the model, the relationships and the record view. See [Defining a resource](../models/defining-models.md). |
| `BeakServeHost` | The server's whole lifecycle in one object: environment to typed config to database adapter to registry to a running server, plus the migrate and seed CLI over the same wiring. Generated into `lib/beak/server.g.dart`. See [Running the server](../backend/running-the-server.md). |
| `BeakStorageDriver` | The interface a file backend implements (`put`, `get`, `delete`, `url`, `exists`). Memory, local disk, S3, and FTP drivers all satisfy it, and a `BeakStorageConfig` resolves to one through a registry. See [Files and storage columns](../models/files-and-storage-columns.md). |
| `BeakValue` | The sealed wrapper around a single primitive (`BeakStringValue`, `BeakIntValue`, `BeakDateTimeValue`, `BeakNullValue`, ...). It keeps every value typed and JSON-safe as it crosses the wire. See [How data flows](../concepts/how-data-flows.md). |
| Dual-mode forms | A configured `BeakFormScreen` can serve read, create and edit roles from one layout. Record blocks themselves remain record presentation. See [Detail and dual mode](../forms/detail-views.md). |
| Ejecting | Taking a Beak default over as a file this project owns. `beak eject <target>` writes it pre-filled with the default, so the first edit is a diff rather than a rewrite from the documentation. See [CLI commands](cli-commands.md). |
| Generated part file | The `.beak.dart` part beside a schema class. It contains generated columns, relations, model descriptors, field helpers and typed record/draft readers. Regenerate it rather than editing it. See [Generated code](../models/generated-code.md). |
| Handler | The backend's outermost layer: a Shelf handler that reads the request, calls a service, and lets the [error-mapping middleware](../backend/middleware.md) turn thrown exceptions into HTTP. The backend flow is Handler to Service to DataSource. See [The four layers](../concepts/the-four-layers.md). |
| `HttpBeakDataSource` | The panel-side `BeakDataSource` that talks to the generated REST API over HTTP. It is what wires a running `BeakPanel` to a `BeakServer`. See [The data source seam](../architecture/data-source-seam.md). |
| obers_ui | The widget kit Beak's UI is built on. Beak uses `obers_ui`, `obers_ui_autoforms`, and `obers_ui_charts` for everything visual and never Material or Cupertino. See [Using Beak widgets standalone](../extending/using-beak-widgets-standalone.md). |
| One-definition promise | The design rule that a single typed field declaration feeds the table, form, detail, filter, REST validation, migration, and CSV export, so you write a field once. See [The one-definition promise](../concepts/the-one-definition-promise.md). |
| Record view | The generated typed reader over a `BeakRecord`, reached through an extension such as `record.asProduct`. Draft readers use nullable values while editing incomplete records. See [Generated code](../models/generated-code.md). |
| Repository | The frontend's catch boundary. It wraps each data-source call and returns a `BeakResult` instead of throwing, so view models stay `try/catch`-free. The frontend flow is Widget to ViewModel to Repository to DataSource. See [The four layers](../concepts/the-four-layers.md). |
| Resource override | `lib/resources/<table>.dart`, a `BeakResource beakResource(BeakResource generated)` that `copyWith`s the parts of one generated resource you want different. Every other resource stays generated. See [Resources](../panel/resources.md). |
| Service | The backend's logic layer. Services hold the business rules and throw typed [exceptions](exceptions.md); DataSources below them do raw I/O only. See [The four layers](../concepts/the-four-layers.md). |
| Type-safety promise | Beak's guarantee that you never write a string field reference and never touch `dynamic`. Columns, values, filters, and results are all typed end to end. See [The type-safety promise](../concepts/the-type-safety-promise.md). |
| ViewModel | The frontend layer that exposes state as `ReadonlySignal`s and forwards intent. It reads outcomes from the Repository and never catches exceptions itself. See [The four layers](../concepts/the-four-layers.md). |
| worm | The Dart ORM used by Beak’s default backend, migrations and seeders. It is vendored under `packages/worm`; frontend packages do not import it. See [Packages](packages.md). |
| `WormDataSource` | The backend `BeakDataSource` that translates typed queries and writes into worm database operations. It supplies transactional graph persistence through the backend service. See [The data source seam](../architecture/data-source-seam.md). |

| `BeakFormSession` | The configured form runtime that owns values, related drafts, validation, uploads, review and commit recovery. [Forms](../forms/form-screens.md) describes the declarative entry point. |
| `BeakCandidateGraph` | The server-side final-state view of a save plan, including staged and stored relationships. Business preparation can read typed fields and write trusted derived values before committing. See [Transactional business rules](../backend/graph-business-rules.md). |
| `BeakModelBehavior` | Shared declarations for initial, suggested, derived and snapshot values, lifecycle guards and named actions. See [Lifecycle and actions](../models/behavior.md). |
| `BeakSavePlan` | A graph mutation with stable operation references and an idempotency key. Its result records definite success, definite failure or unknown outcomes per operation. See [Declarative resources](../concepts/declarative-resources.md). |

## Continue reading

- [Core concepts](../concepts/index.md) the ideas behind the vocabulary, in prose.
- [Annotations](annotations.md) the vocabulary you actually type.
- [Packages](packages.md) which package each of these types lives in.
- [Exceptions](exceptions.md) the full `BeakException` family and its wire mapping.
