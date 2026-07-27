---
title: Principles
description: The invariants every part of Beak obeys, from define-once to no lazy loading, and why each one exists.
---

# Principles

After this page you will know the seven rules that shape every API in Beak. They are not style preferences. They are load-bearing: break one and something downstream stops working, so every pull request is read against them.

Beak is a low-code, configuration-driven admin-panel framework. You define models once and compose obers_ui widgets that auto-wire to a Shelf backend. The principles below are what keep that story true as the codebase grows.

## 1. Define once, render everywhere

A column is declared one time, as a typed constant, and that single declaration feeds every surface.

```dart
abstract final class ProductColumns {
  static const name = BeakStringColumn(
    key: 'name', label: 'Name',
    searchable: true, sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );
  static const price = BeakDecimalColumn(
    key: 'price', label: 'Price', prefix: '€', rules: [BeakMin(0)],
  );
  static const List<BeakColumn> values = [name, price];
}
```

From that one `const`, `beak_frontend` renders the table cell and the form field, `beak_backend` validates writes and exports the CSV column, and `beak_core` carries the column inside the serializable query spec that travels between them. One declaration, six mouths to feed: the table cell, the form input, the detail row, the filter, the REST validator, and the export column. If you change the label in one place, all six move together, because there is only one place.

!!! note "What this buys you"
    There is no second definition to keep in sync. The client validator and the server validator are the *same* `BeakRule` list, so a form never accepts what the API will reject.

## 2. Type safety, no escape hatches in the hot path

Users never write a string field reference and never touch `dynamic`.

- No `dynamic` (interop only, and then behind a `// interop:` comment).
- No `as` casts. Use pattern matching and typed APIs.
- No `Map<String, dynamic>` as a domain, presentation, or public API type. Use typed DTOs, sealed classes, generics, and enums.
- Known value sets are enums or sealed classes, never bare strings. Numeric fields carry their unit in the name (`maxSizeInBytes`, `idleLockTimeout`).

Values that cross the wire travel as the sealed `BeakValue` family, so `record['price']?.raw` is a real `double`, not an untyped blob. This is Beak's promise, quoted from its own conventions: if an API you add would force a user to write a string field name or reach for `dynamic`, redesign the API. The escape hatches (`BeakCustomColumn`, `BeakWidgetBlock`, and the raw `BeakClient`) exist for the small fraction Beak cannot express, and they are documented as such, not reached for by default.

## 3. Source-agnostic data

Every data operation goes through one interface, `BeakDataSource`, and that interface speaks only `beak_core` types.

```dart title="packages/beak_core/lib/src/data/beak_data_source.dart"
abstract interface class BeakDataSource {
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec);
  Future<BeakRecord?> getOne(String table, Object id);
  Future<BeakRecord> create(String table, BeakRecord data);
  // update, delete, batchGet, attach, detach, aggregate ...
}
```

`WormDataSource` (backend, over the worm ORM) and `HttpBeakDataSource` (frontend, over REST) both implement it. Because the seam trades only in `BeakQuerySpec`, `BeakRecord`, and friends, a future `beak_serverpod` package can add a `ServerpodDataSource` without changing `beak_core` or `beak_backend`. The rule that makes this hold: worm types never leak past `beak_backend`, and obers_ui types never leak past `beak_frontend`. See [The data source seam](data-source-seam.md) for the full contract.

## 4. No Material, obers_ui only

Beak's UI is `obers_ui` (plus `obers_ui_autoforms` and `obers_ui_charts`) and nothing else.

- Forbidden imports: `package:flutter/material.dart` and `package:flutter/cupertino.dart`. Flutter's `widgets.dart` and `foundation.dart` are allowed only for core types such as `BuildContext`, `Widget`, `Key`, and `EdgeInsets`.
- Widgets are `HookWidget`. `StatefulWidget` is forbidden.
- State is Signals. Dependency injection is GetIt through a package-scoped `beakLocator`. Routing is go_router.

App authors rarely touch any of this directly. They write configuration, and Beak wires the widgets. A CI check (`tool/check_no_material.dart`, run by `melos run guard-material`) fails the build on a stray Material import, so the rule is enforced, not just asked for.

## 5. Four layers, no more

Beak has exactly four layers per side, and no fifth.

| Side | Flow | Catch boundary |
| --- | --- | --- |
| Backend | `Handler (Shelf) -> Service -> DataSource` | the error-mapping middleware |
| Frontend | `Widget -> ViewModel -> Repository -> DataSource` | the repository |

- On the backend, handlers only parse, authorize, and route. Services own the logic and throw typed exceptions. Data sources do raw I/O and let exceptions propagate. One middleware maps the sealed `BeakException` family to HTTP status and JSON.
- On the frontend, widgets render Signals and forward intent. View models expose `ReadonlySignal`s and never `try/catch`. The repository is the catch boundary and returns `BeakResult<T>`, so failures arrive at a view model as values, not thrown exceptions.

There is no extra indirection layer between these four. If you find yourself reaching for one, the logic belongs in a service (backend) or the coordination belongs in a view model (frontend). See [Backend flow](backend-flow.md) and [Frontend flow](frontend-flow.md) for each path in depth.

## 6. No lazy loading

Reading an unloaded relation throws. Beak never silently fires a query behind your back.

You eager-load what you need with `relationLoads` on the query spec, and the data source resolves every one of them before returning. This keeps request counts predictable and keeps a table render from turning into an N+1 storm. Design your specs to declare their relations up front, because there is no second chance to fetch them on access.

## 7. Reuse first, escape hatches on purpose

Two rules of hygiene round out the set.

- Search the repo before adding any widget, util, mapper, or type, and extend rather than fork. `const` and `final` by default. Small, single-responsibility units. Every public symbol carries a doc comment, and there is no `print`; the project logger is used instead.
- The escape hatches are deliberate and few: `BeakCustomColumn` for a cell Beak cannot express, `BeakWidgetBlock` for a raw widget in a block tree, custom form sections, and the low-level `BeakClient`. They are the pressure-release valves for the last five percent, not the front door.

## Continue reading

- [Package graph](package-graph.md) how these principles show up as dependency edges between packages.
- [The one-definition promise](../concepts/the-one-definition-promise.md) principle one, told at concept altitude with a full worked example.
- [Backend flow](backend-flow.md) principle five on the server side, layer by layer.
