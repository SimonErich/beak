---
title: Frontend flow
description: Follow the Widget, ViewModel, Repository and DataSource path, and see where state lives and where failures become values.
type: concept
audience: [contributor, expert]
status: stable
---

# Frontend flow

The panel has four layers, `Widget -> ViewModel -> Repository -> DataSource`. State lives in Signals, failures are caught once and turned into values, and the whole thing hangs off a dependency container that belongs to one panel. After this page you can follow a tap from a widget to the network and back, and say which layer holds the state and which one holds the `try/catch`.

## The idea in one picture

```mermaid
flowchart TD
  U["intent: sort, filter, page"] --> W["Widget<br/>HookWidget"]
  W -->|forward intent| VM["ViewModel<br/>BeakViewModel"]
  VM -->|await| R["Repository<br/>BeakResourceRepository"]
  R -->|delegate| DS["DataSource<br/>ModelBeakDataSource"]
  DS -->|per model| HTTP[HttpBeakDataSource]
  DS -->|model-owned| OWN["a model's own source"]
  HTTP --> C[BeakClient] -->|REST| API[(generated API)]
  R -. "BeakException becomes" .-> RES["BeakOk / BeakErr"]
  RES --> VM
  VM -->|ReadonlySignal| W
```

State flows up as `ReadonlySignal`s and intent flows down as method calls. The repository is where an exception turns into a value.

## How it works

### Wiring above the widgets

`BeakPanel` is the root widget. On its first build it creates a `GetIt.asNewInstance()` container of its own, registers Beak's dependencies into it, and builds the go_router. All three are memoized on the configuration and the two transport seams (`dataSource:` and `httpClient:`), which a test replaces with fakes and a host with its own transport, such as the Serverpod admin, sets in production.

```dart title="packages/beak_frontend/lib/src/panel/beak_panel.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_panel.dart:panelRouting"
```

The container is exposed through an `InheritedWidget`. Two panels in one app do not share credentials, caches or data sources, and a custom widget reads its own panel's container with `beakDependencies(context)`:

```dart title="packages/beak_frontend/lib/src/di/beak_locator.dart"
--8<-- "packages/beak_frontend/lib/src/di/beak_locator.dart:beakDependencies"
```

`beakLocator`, a package-level container, is the fallback for hosts that call `registerBeakDependencies` themselves and drive the router without a `BeakPanel`.

Registration is synchronous, because the router built right after it reads the container on its first frame. It runs in two halves. The first builds the REST client and the session store. They are created in that order for a reason: the client reads the store's token on every request, and the store mints one through the client when you sign in. Two halves of one session.

```dart title="packages/beak_frontend/lib/src/di/beak_locator.dart"
--8<-- "packages/beak_frontend/lib/src/di/beak_locator.dart:clientAndSessions"
```

The second half registers what the widgets resolve:

```dart title="packages/beak_frontend/lib/src/di/beak_locator.dart"
--8<-- "packages/beak_frontend/lib/src/di/beak_locator.dart:registerDataLayer"
```

Note what `BeakDataSource` is here. It is not the HTTP source. It is `ModelBeakDataSource`, which wraps the HTTP source as a fallback. With an external authentication adapter (`BeakAuthConfig.adapter`, or `externalAuthentication: true`) no `BeakClient` and no session store are registered, and registration throws a `BeakConfigurationException` unless every model is bound to a source of its own or a `dataSource:` is supplied.

The API origin is a compile-time value. The panel is a Flutter web app with no environment to read at runtime, so `beak.yaml`'s `api.baseUrl` becomes a `String.fromEnvironment` default in `panel.g.dart`, overridable with `--dart-define=BEAK_API_BASE_URL=...`. Setting `baseUrl: auto` makes the generated expression resolve to the origin the panel was served from.

```dart title="examples/quickstart/lib/beak/panel.g.dart"
    apiBaseUrl: const String.fromEnvironment(
      'BEAK_API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
```

### The Widget: render Signals, forward intent

Panel widgets are `HookWidget`s. `StatefulWidget` is forbidden in Beak code. A widget owns its view model through hooks, refreshes it once and disposes it with the widget, and rebuilds through `Watch` when a signal changes.

```dart title="packages/beak_frontend/lib/src/table/beak_data_table.dart"
--8<-- "packages/beak_frontend/lib/src/table/beak_data_table.dart:viewModelLifecycle"
```

```dart title="packages/beak_frontend/lib/src/table/beak_data_table.dart"
--8<-- "packages/beak_frontend/lib/src/table/beak_data_table.dart:watchPage"
```

`BeakDataTable` is the generated list view. It renders a model's table columns as an `OiTable` with server-side sort, filter and pagination, per-row and bulk actions, optimistic delete with undo and inline edit. Every sort, filter or page change goes to its view model as a method call. There is no business logic in the widget and no `try/catch` around a data call.

### The ViewModel: owns Signals, never catches

Every view model extends `BeakViewModel`. It creates state with `ownedSignal`, which is released with the view model, and exposes it upward as `ReadonlySignal`, so widgets read and never write.

```dart title="packages/beak_frontend/lib/src/state/beak_view_model.dart"
--8<-- "packages/beak_frontend/lib/src/state/beak_view_model.dart:BeakViewModel"
```

There are three concrete ones: `BeakTableViewModel` for a list, `BeakQueryController` for a list definition shared by several views, and `BeakAuthViewModel` for the sign-in flow. `BeakTableViewModel` owns the query spec, the current page, a loading flag and the last error. A sort, filter, search or page intent rewrites the spec and refetches. Repeating an unchanged intent sends no request, and an explicit `refresh()` always does. It also listens to the source's change stream, so a confirmed write to its table (or to a table that references it) refetches it without any wiring.

```dart title="packages/beak_frontend/lib/src/table/beak_table_view_model.dart"
--8<-- "packages/beak_frontend/lib/src/table/beak_table_view_model.dart:refresh"
```

It switches on a `BeakResult` and never catches. The `requestId` guard makes the fetch latest-wins: a slow response that lost the race to a newer one, or that arrives after `dispose`, writes nothing.

### The Repository: the catch boundary

`BeakResourceRepository` wraps a `BeakDataSource`. Each method mirrors a source operation and returns `BeakResult<T>` instead of throwing. A thrown `BeakException` becomes a `BeakErr`. Any other error still propagates, because a bug should crash where you can see it and not hide inside a value.

```dart title="packages/beak_frontend/lib/src/data/beak_resource_repository.dart"
--8<-- "packages/beak_frontend/lib/src/data/beak_resource_repository.dart:query"
```

The default repository is uncached. `BeakResourceRepository.coalescing` shares identical pending queries within one owner and forgets them when they complete, and `invalidateQueries()` stops a new read from joining a request that started before a write. The mechanism is `beakRun`, which is also public, so a custom workflow gets the same boundary without a repository:

```dart title="packages/beak_frontend/lib/src/data/beak_run.dart"
--8<-- "packages/beak_frontend/lib/src/data/beak_run.dart:beakRun"
```

This mirrors the backend's error-mapping middleware. There, exceptions become status codes at one point. Here, they become `BeakResult` values at one point. See [Results and errors](../concepts/results-and-errors.md) for the type.

The rule holds for data operations. It does not mean nothing else in the package contains a `catch`. The form runtime catches when it persists a local draft (`beak_form_draft_runtime.dart`), the upload field catches a failing file picker, and the configured form catches a failing URI launch. Each is a local, non-data failure with its own message. A view model never catches, and no data call is caught outside a repository, `beakRun`, or the data source itself.

### The DataSource: routing, mapping, commits

`ModelBeakDataSource` is what a panel holds as its `BeakDataSource`. It captures one source per model when it is built: the model's own `dataSource` if it has one, else the HTTP fallback. An explicit `dataSource:` on the panel replaces every binding, which is how tests run.

```dart title="packages/beak_frontend/lib/src/data/http_beak_data_source.dart"
--8<-- "packages/beak_frontend/lib/src/data/http_beak_data_source.dart:HttpBeakDataSource"
```

`HttpBeakDataSource` implements the same `BeakDataSource` the backend does and then the optional capability interfaces, each of which a transport may skip. It forwards to `BeakClient`, so no widget and no view model sees a URL, a header or a JSON map.

The dispatcher adds four things on top of the source it picks.

#### One error mapper

Every call runs through `_run`. Typed `BeakException`s pass, and a host exception goes through the panel's `mapException` when there is one. A `BeakAuthenticationException`, whether the server sent it or `mapException` produced it, also calls `onUnauthorized` before it is rethrown. The panel wires that to the session authority: the request that finds the session dead signs the user out, and the router lands on `/login`.

```dart title="packages/beak_frontend/lib/src/data/model_beak_data_source.dart"
--8<-- "packages/beak_frontend/lib/src/data/model_beak_data_source.dart:run"
```

#### A change stream

It implements `BeakMutationSource`. A confirmed write, or an optional `BeakRefreshPolicy` tick, emits a `BeakDataChange` with the affected tables and the tables that reference them. Tables and `useBeakDataRevision` listen.

#### Commit routing

A form save is a `BeakSavePlan`. If every table in the plan resolves to one source that is a `BeakCommitDataSource`, the plan goes there. Otherwise `BeakStagedCommitDataSource` replays it as ordinary create, update and delete calls in dependency order. That path is not atomic, its receipts live in memory for the session, and an error after dispatch is recorded as unknown and never retried.

```dart title="packages/beak_frontend/lib/src/data/model_beak_data_source.dart"
--8<-- "packages/beak_frontend/lib/src/data/model_beak_data_source.dart:commit"
```

The same save id with different content is a `BeakConflictException` before anything is sent.

#### Single-record writes through the same door

A non-forced delete, and a create or an update made outside a form (a dragged board card, a chat message, an inline edit), against a commit-capable source is sent as a one-operation plan, so behavior, rules and `graphOnly` models apply to it. A repeated identical call recovers the pending receipt instead of submitting a second write, and a receipt that is not complete becomes the typed exception its error code names. A forced delete uses the transport's own operation.

[Graph commits](graph-commits.md) covers what the server does with a plan.

## Why it is shaped this way

- Signals, not callbacks. A widget subscribes to exactly the values it reads. The view model can be tested without a widget, and the widget without a network.
- Failures as values. A list that fails to load is data (`error` is a signal), not an exception thrown through a build method.
- One container per panel. Credentials and caches that belong to a panel stay with it. Tests replace the source without touching a global.
- A dispatcher, not a source. Putting routing, error mapping and the change stream in one class means a model-owned transport gets all three without implementing them. That is how the Serverpod bridge plugs in.

## What it means for you

- Read state through `Watch` on a `ReadonlySignal`. Do not copy a signal's value into widget state.
- Custom widgets resolve dependencies with `beakDependencies(context)`, not `GetIt.instance`.
- Call `beakRun` when a custom workflow needs the result boundary. Do not catch `BeakException` in a view model.
- In a widget test pass `dataSource:` to `BeakPanel` with an `InMemoryBeakDataSource`. It implements no commit interface, so form saves go through the staged path.
- The panel does not poll. Set a `refreshPolicy` if the data changes without the panel writing it.

## Continue reading

- [Backend flow](backend-flow.md) the server side, where the error-mapping middleware plays the role the repository plays here.
- [The data source seam](data-source-seam.md) the interface every layer above the transport speaks.
- [Block system internals](block-system-internals.md) how the widgets that render a page are chosen.
- [The panel](../panel/index.md) the widgets this flow drives, from tables to forms to dashboards.
