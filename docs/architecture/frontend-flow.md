---
title: Frontend flow
description: The Widget to ViewModel to Repository to DataSource path in the panel, Signals state, the BeakResult catch boundary, and package-scoped GetIt.
---

# Frontend flow

After this page you will be able to follow a user tap from a widget to the network and back, name which layer holds state and which holds the `try/catch`, and know why the panel never throws an exception at a widget. This is the client side of Beak's [four layers](../concepts/the-four-layers.md).

The frontend flow is `Widget -> ViewModel -> Repository -> DataSource`, four layers and no fifth. State lives in Signals, failures are caught once at the repository and returned as values, and the whole thing is wired through a GetIt container scoped to Beak so it never collides with your app's own registrations.

## The path of an interaction

```mermaid
flowchart TD
  U[User intent: sort, filter, page] --> W[Widget: HookWidget]
  W -->|forward intent| VM[ViewModel: BeakViewModel]
  VM -->|call, await BeakResult| R[Repository: BeakResourceRepository]
  R -->|delegate| DS[DataSource: HttpBeakDataSource]
  DS -->|typed HTTP| CLIENT[BeakClient]
  CLIENT -->|REST| API[(Generated API)]
  R -. catch BeakException .-> RES[BeakResult: BeakOk / BeakErr]
  RES --> VM
  VM -->|ReadonlySignal| W
```

State flows up as Signals; intent flows down as method calls. The only layer that ever runs a `try/catch` is the repository.

## The Widget: render Signals, forward intent

Panel widgets are `HookWidget`s (Beak forbids `StatefulWidget`). A widget watches a `ReadonlySignal` and rebuilds when it changes, and it forwards user intent to its view model. It holds no business logic and no `try/catch`.

`BeakDataTable` is the generated list view. It renders a model's table-context columns as an `OiTable`, and every sort, filter, or page change is forwarded to an internal `TableViewModel`.

```dart title="packages/beak_frontend/lib/src/table/beak_data_table.dart"
class BeakDataTable extends HookWidget {
```

Its own doc comment sums up the deal: table-context columns rendered as an `OiTable` with server-side sort, filter, and pagination through `BeakQuerySpec`, per-row and bulk actions, optimistic delete with undo, and inline edit, all with zero per-resource table code.

Because the widget only reads Signals and forwards intent, there is nothing in it to unit-test beyond rendering: the interesting behavior sits one layer down.

## The ViewModel: owns Signals, never catches

Every view model extends `BeakViewModel`, which owns its Signals, exposes them as `ReadonlySignal`s, and disposes them together. Its doc comment states the rule plainly: a view model never runs a `try/catch`, because the repository is the catch boundary. State is created with `ownedSignal` so it is released on `dispose`, and exposed upward as a `ReadonlySignal` so widgets read but never write it.

```dart title="packages/beak_frontend/lib/src/state/beak_view_model.dart"
abstract base class BeakViewModel {
  @protected
  Signal<T> ownedSignal<T>(T value) {
    final owned = signal<T>(value);
    _cleanups.add(owned.dispose);
    return owned;
  }
```

`TableViewModel` is the concrete example. It owns the query spec, the current page, a loading flag, and the last error, each as a `ReadonlySignal`. A sort or filter intent rewrites the `BeakQuerySpec` and refetches through the repository. Note that it switches on a `BeakResult`; it does not catch.

```dart title="packages/beak_frontend/lib/src/table/table_view_model.dart"
Future<void> refresh() async {
  final int requestId = ++_latestRequestId;
  _loading.value = true;
  _error.value = null;
  final result = await _repository.query(_spec.value);
  if (requestId != _latestRequestId) {
    return;
  }
  switch (result) {
    case BeakOk(:final value):
      _page.value = value;
    case BeakErr(:final error):
      _error.value = error;
  }
  _loading.value = false;
}
```

That `requestId` guard is latest-wins concurrency: a slow response from a superseded request is dropped so it can never overwrite newer state. The view model turns an outcome into signal updates, and the widget rebuilds. No exception was ever thrown at a widget.

## The Repository: the single catch boundary

`BeakResourceRepository` is a thin, stateless wrapper over a `BeakDataSource`. Every method mirrors a source operation but returns `BeakResult<T>` instead of throwing. A thrown `BeakException` becomes a `BeakErr`; any other error still propagates (a bug should not be swallowed as a value).

```dart title="packages/beak_frontend/lib/src/data/beak_resource_repository.dart"
Future<BeakResult<BeakPage<BeakRecord>>> query(BeakQuerySpec spec) =>
    _guard(() => dataSource.query(spec));

Future<BeakResult<T>> _guard<T>(Future<T> Function() run) async {
  try {
    return BeakOk(await run());
  } on BeakException catch (exception) {
    return BeakErr(exception);
  }
}
```

This is the mirror of the backend's error-mapping middleware: on the server, exceptions become HTTP status codes at one boundary; on the client, they become `BeakResult` values at one boundary. Everything above the repository deals in `BeakOk` and `BeakErr`, never in `try`. See [Results and errors](../concepts/results-and-errors.md) for the result type in full.

## The DataSource: transport-blind delegation

`HttpBeakDataSource` implements the same `BeakDataSource` interface the backend implements, delegating every call to a typed `BeakClient` that speaks REST to the generated API. Widgets and view models stay transport-blind: they never see a URL, a header, or a JSON map.

```dart title="packages/beak_frontend/lib/src/data/http_beak_data_source.dart"
final class HttpBeakDataSource implements BeakDataSource, BeakUploadClient {
  const HttpBeakDataSource(this.client);

  final BeakClient client;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) =>
      client.query(spec.table, spec);
```

Because the source is behind an interface, a test injects a fake `BeakDataSource` and the entire stack above it runs without a socket, and a future transport such as Serverpod could replace it without touching a single widget. That is the same seam described in [The data source seam](data-source-seam.md).

## Wiring: package-scoped GetIt

Beak resolves its dependencies from `beakLocator`, a GetIt container created with `GetIt.asNewInstance()` so it never collides with your app's own `GetIt.instance` registrations.

```dart title="packages/beak_frontend/lib/src/di/beak_locator.dart"
final GetIt beakLocator = GetIt.asNewInstance();
```

`registerBeakDependencies` populates it from a `BeakPanelConfig`: the model registry, the `BeakClient` pointed at `apiBaseUrl`, the `BeakDataSource`, a reference cache, and the theme controller. Registration is synchronous, because the router built right after reads the locator on its first frame, and it allows reassignment so hot restarts and tests can call it repeatedly.

```dart title="packages/beak_frontend/lib/src/di/beak_locator.dart"
final source = dataSource ?? HttpBeakDataSource(client);
container
  ..registerSingleton<BeakPanelConfig>(config)
  ..registerSingleton<BeakModelRegistry>(registry)
  ..registerSingleton<BeakClient>(client)
  ..registerSingleton<BeakDataSource>(source)
  ..registerSingleton<ReferenceCache>(ReferenceCache(source, registry))
  ..registerSingleton<BeakThemeController>(
    BeakThemeController(config.initialThemeMode),
  );
```

The `dataSource` parameter is the test seam: pass a fake and the panel talks to it instead of the network. `BeakPanel` calls this for you, so app authors set `apiBaseUrl` in config and never touch the locator directly. UI is obers_ui throughout, routing is go_router, and state is Signals, exactly as the [principles](principles.md) require.

## Continue reading

- [Backend flow](backend-flow.md) the server side, where the middleware plays the role the repository plays here.
- [Results and errors](../concepts/results-and-errors.md) the `BeakResult` type the repository returns and the view model switches on.
- [The panel](../panel/index.md) the widgets this flow drives, from tables to forms to dashboards.
