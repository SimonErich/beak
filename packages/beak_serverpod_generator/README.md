# beak_serverpod_generator

Generate typed Beak models from existing Serverpod client models **and endpoint
signatures**. Model fields, enums, nested DTOs, constructor shapes and RPC calls
remain owned by Serverpod. No duplicate entity declarations or handwritten
standard query transport are needed.

Add this package as a development dependency and `beak_serverpod` as a runtime
dependency. Generate Serverpod first, resolve packages, then configure the consumer:

```yaml
library: package:example_client/example_client.dart
models:
  - AdminUserDto
  - AdminOrderDto
output: lib/core/beak/generated/admin_models.g.dart
```

```sh
dart run beak_serverpod_generator:generate --config beak_serverpod.yaml
```

`--root` selects the consumer package when running elsewhere. Only the configured
output is written; unchanged output is left untouched. Regenerate after Serverpod
model or endpoint changes. Never edit the companions.

`models` produces `<Model>Resource` classes. An optional `types` list adds metadata
and codecs without transport discovery. Referenced command and nested model types
are collected automatically; do not list them again.

## Consumer surface

The generated constructor takes the existing client, logical resource name,
typed primary key descriptor and selected columns. Optional presentation includes
a display column, model permissions and typed create/edit label overrides.
Its model-owned data source is discovered by `BeakPanel`; no source list or
repository initialization is needed. See the [runtime guide](../beak_serverpod/README.md)
for presentation, command projections and explicit operation overrides.

Each selected/referenced model also receives:

- `<Model>Fields`: typed scalar/collection descriptors. Nested `account.id`
  becomes `accountId`; colliding flattened paths use `__` separators.
- `<Model>FormSlot`: an enum pool sized to scalar fields, including commands
  wider than the default 32-field pool. Generated form metadata uses it directly.
- `<Model>Relations`: typed object/list references for complete loaded records.
- `<Model>Codec`: typed record encoding and constructor-based command decoding.

## Endpoint conventions

Discovery resolves the exported `Client` class and requires exactly one endpoint
property with `list(query)` returning a page containing exactly one `List<Model>`
and an integer `totalCount`. Named and positional RPC arguments are supported.

The query DTO must be constructible without required named arguments and expose
integer `page` / `pageSize`. Its actual constructor defaults determine zero- or
one-based paging; the resource accepts an explicit `firstPage` override. Page DTOs
may return `page` / `pageSize`; otherwise Beak retains the requested window.

Recognized optional query vocabulary:

- `search: String?` forwards a validated search term.
- `sort: Enum` matches enum names to generated field leaves. Direct siblings of
  the configured identity take precedence over deeper relations; other ambiguity
  requires a typed `sortFields` mapping.
- `descending: bool` retains the endpoint default until a sort is selected.
- `includeArchived: bool` forwards the explicit archived-record request.
- Nullable scalar/enum properties matching read-field leaves become equality
  filters. Nested conjunctions work; other predicates are rejected explicitly.

`get` or `getById` must return `Model` / `Model?` and accept one nonnull scalar ID.
An additional `locale: String` is supplied from the constructor's live callback.
Compatible `create(Input)` and `update(Id, Input)` / `edit(Id, Input)` bind generic
forms only when their result is the same read model. Commands returning other
results remain available to custom application workflows.

A `delete` or `archive` returning `void` binds ordinary deletion. `getMany` returning
`List<Model>` binds batch reads. Count reuses the authorized list query and its
total; there is no separate permissive aggregate endpoint. Ambiguous operations,
missing contracts and unsupported required context fail generation with a
specific diagnostic. Use typed `ServerpodResource` callbacks for contracts outside
these conventions; generation never writes or changes server endpoints.

## Type and projection limits

Supported scalars: strings, integers, doubles, booleans, dates, UUIDs, URIs and Dart
enums, including nullable properties and scalar lists/sets. Nested objects and
lists of nonnullable objects work. Flattened descriptors stop at recursive type
boundaries. Constructors must be public, unnamed and use named parameters.
Arbitrary maps, nullable object-list elements and duplicate class names in the
selected graph fail explicitly.

The generated `editInput(read, ...)` helper projects uniquely matching compatible
scalar leaves. Nullable-to-required values and domain conversions become required
typed parameters. Default generic edit prefill matches exact paths, then the
identity branch, then unique leaves; missing/ambiguous input requires the helper
or an explicit `editValues` callback. No related IDs, fallback values or domain
business rules are inferred.

This is structural/RPC generation. Physical table names, authorization, validation,
transactions and cleanup stay in Serverpod. Presentation controls expose only
selected read columns; generic form fields come from explicit command DTOs.

Run `dart test` and `dart analyze`. Tests resolve models with the analyzer, then
compile and execute the generated codecs and model-owned CRUD transport.
