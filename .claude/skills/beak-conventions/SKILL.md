---
name: beak-conventions
description: Beak's own API design conventions — the type-safety promise, column/relationship config objects, the serializable query spec, the source-agnostic data layer, and the pluggable storage-driver system with Filament-style file rules.
---

# beak-conventions

Beak lets a developer **define a model once** and then compose obers_ui-style widgets
that auto-wire to the backend. These are the design rules for Beak's own public API.

## The promise (never break it)

- **Zero string field references, zero `dynamic`.** Users reference columns as typed
  constants (`ProductColumns.name`), never `'name'`. Values are typed
  (`formData.get(ProductColumns.price)` returns `double`).
- **Define once, render everywhere.** A single `BeakColumn` knows how to render as a
  table cell, a form input, a detail entry, and a filter — the user never picks a widget.
- **Backend is invisible.** No endpoints, serialization, or HTTP in user code (a
  low-level typed client exists as a documented escape hatch only).
- **Escape hatches everywhere.** `BeakCustomColumn`, custom form sections, and a raw
  client are always available for the ~5% Beak can't express.

## Column type system (`beak_core`)

Concrete, `const`-constructible classes extending a sealed `BeakColumn`:
`BeakStringColumn`, `BeakTextColumn`, `BeakIntColumn`, `BeakDecimalColumn`,
`BeakBoolColumn`, `BeakEnumColumn<T extends Enum>`, `BeakDateTimeColumn`,
`BeakImageColumn`, `BeakFileColumn`, `BeakJsonColumn`, `BeakColorColumn`,
`BeakRichTextColumn`. Each carries: `key`, `label`, `visibleOn: Set<BeakContext>`,
`sortable`/`searchable`/`filterable`, `rules: List<BeakRule>`, and type-specific display
config (e.g. image `storagePath`, `maxSizeInBytes`, `allowedTypes`, `thumbnail`,
`transforms`; decimal `precision`/`prefix`; enum `values` + `badgeColors`).

Users expose columns as a namespaced `abstract final class`:
```dart
abstract final class ProductColumns {
  static const name = BeakStringColumn(key: 'name', label: 'Name',
      searchable: true, sortable: true, rules: [BeakRequired(), BeakMaxLength(255)]);
  static const price = BeakDecimalColumn(key: 'price', label: 'Price',
      precision: 2, prefix: '€', sortable: true, rules: [BeakMin(0)]);
  static const List<BeakColumn> values = [name, price /* ... */];
}
```
`beak_core` is **UI-agnostic**: a column declares a `BeakRenderIntent` per context;
`beak_frontend` maps intents → obers_ui widgets. Never import Flutter in `beak_core`.

## Relationships (`beak_core`)

`BeakBelongsTo<T>`, `BeakHasMany<T>`, `BeakBelongsToMany<T>`, etc., each carrying keys +
`displayColumn` + `searchColumns` and mapping onto worm's relation annotations. The
render matrix (belongsTo → searchable combobox in a form, linked text in a table, etc.)
lives in `beak_frontend`.

## The serializable query spec (the wire contract)

`BeakQuerySpec` is a **typed, JSON-serializable** description the frontend builds and the
backend executes via worm. It mirrors the fluent builder from the concept
(`.with([...]).where(col, op, value).orderBy(...).search(...).paginate(...)`), but
serializes losslessly. `beak_frontend` builds it; `WormDataSource` translates it to a
worm `QueryBuilder`. Golden tests pin its JSON shape. It must never leak `dynamic`.

## Source-agnostic data layer (keep this seam clean)

`BeakDataSource` is an interface (list/get/create/update/delete/query/batchGet/relations/
aggregate). `WormDataSource` (in `beak_backend`) is the default implementation. A future
`beak_serverpod` package will provide `ServerpodDataSource` that adapts **generated
Serverpod classes as Beak models without duplicating them** — so:
- `beak_core` must not depend on worm types in its public API (map worm concepts behind
  Beak's own abstractions where the boundary matters).
- Model metadata (columns/relations/table) must be expressible independent of the ORM,
  so a Serverpod-backed model can supply the same `BeakModel` metadata.

## Storage drivers (pluggable, credentials at init, Filament-style rules)

`beak_core` defines the abstraction; driver packages implement it:

```dart
abstract interface class BeakStorageDriver {
  Future<BeakStoredFile> put(BeakUpload upload, {required String path});
  Future<Uint8List> get(String key);
  Future<void> delete(String key);
  Future<Uri> url(String key, {Duration? expiresIn});
  Future<bool> exists(String key);
}
```
- Configured at app init: `BeakStorageConfig` selects a driver + credentials
  (`BeakS3Config(endpoint, bucket, accessKey, secretKey, region, usePathStyle)`,
  `BeakFtpConfig(host, port, user, password, baseDir)`, plus an in-memory and a
  local-disk driver for tests/dev). Drivers register by key; the backend resolves the
  configured one. **Never hard-code a driver in core.**
- **File rules mirror Filament** and live on the column, enforced on upload:
  `maxSizeInBytes`, `allowedTypes` (MIME/extension), and for images
  `maxDimensions`, `aspectRatio`, and a `transforms` pipeline
  (`BeakImageTransform.resize(width:)`, `.webp(quality:)`, `.thumbnail(size:)`).
  The upload endpoint validates rules, runs transforms, stores via the configured
  driver, and returns a typed `BeakStoredFile` (key + url + metadata). Each image column
  owns its `storagePath` (subfolder) and transform set — defined once.

## Package boundaries

- `beak_core`: pure Dart. No Flutter, no Shelf, no direct DB driver. Columns, relations,
  query spec, storage abstraction + rules, model metadata, validation, DTOs, errors.
- `beak_backend`: Shelf + worm. Auto CRUD, uploads, auth, search, export. Depends on
  `beak_core` + a storage driver.
- `beak_frontend`: Flutter + obers_ui. Panel, table, form, detail, actions, dashboard,
  data-provider client. Depends on `beak_core` (for the shared spec/DTOs/metadata).
- `beak_cli`: scaffolding (make:resource → model + columns + screen stubs).

## Testing conventions
Every public behavior is covered test-first. `beak_core` is 100%-pure unit tested
(no I/O). `beak_backend` uses worm's `InMemoryAdapter` for logic and MinIO/Postgres via
Docker for integration. `beak_frontend` uses `flutter_test` widget tests with a fake
`BeakDataSource`. See the `tdd-loop` skill.
