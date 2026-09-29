# The four layers

> The two layered flows a request runs through, on the server and in the panel, where each one catches errors, and where a transport plugs in.

A request in Beak passes through the same few layers on both sides. On the server it is `Handler -> Service -> DataSource`. In the panel it is `Widget -> ViewModel -> Repository -> DataSource`. This page names what each layer may and may not do, says where errors are caught, and lists the seams where you swap a transport.

There is no `UseCase` layer, on either side. If you feel one is missing, the code you have in mind belongs in a `Service` on the server or in the `ViewModel` and `Repository` in the panel. Four layers on the panel side, three on the server, none between. The title counts the panel's.

## The idea in one picture

```mermaid
flowchart LR
  subgraph panel["Panel"]
    W["Widget<br/>renders signals"] --> VM["ViewModel<br/>owns the spec"]
    VM --> R["Repository<br/>catches, returns BeakResult"]
    R --> PD["DataSource<br/>ModelBeakDataSource, HttpBeakDataSource"]
  end
  PD -->|"REST, or a Serverpod tunnel"| M
  subgraph server["Server"]
    M["Error-mapping middleware<br/>catches, returns status + JSON"] --> H["Handler<br/>parse, authorize, route"]
    H --> S["Service<br/>logic, validation, defaults"]
    S --> SD["DataSource<br/>WormDataSource"]
  end
  SD --> DB[("database")]
```

The two flows rhyme on purpose. Learn one and you know where code belongs in the other.

## How it works

### The server: Handler, Service, DataSource

`beakApiRouter` mounts one router per registered model under `/api/{table}`, and every route ends in the same three layers. No endpoint is hand-written.

The Handler parses the request, asks the policy, calls the service and encodes the result. It holds no business logic.

```dart title="packages/beak_backend/lib/src/endpoints/crud_handlers.dart"
Future<Response> query(Request request) async {
  _requireView(request);
  final spec = readBeakSpec(
    await readJsonObject(request),
    BeakQuerySpec.fromJson,
  );
  final page = await service.query(_authorizer(request).authorizeQuery(spec));
  return _json(200, page.toJson((record) => _recordJson(request, record)));
}
```

The Service owns the logic: validation, defaults (a minted uuid for a string key, `created_at` and `updated_at` stamps), relation gating. It throws typed exceptions and never touches a Shelf type. Graph writes have their own service, `BeakGraphCommitService`.

```dart title="packages/beak_backend/lib/src/service/beak_resource_service.dart"
/// Runs [spec] against the data source.
///
/// The handler authorizes [spec] first — a row policy's scope is folded
/// into its filter by `BeakQueryAuthorizer` — so this only checks the
/// target. Throws a [BeakValidationException] when the spec targets another
/// table than this service's model.
Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) {
  _requireSpecTargets(spec.table, 'Query');
  return dataSource.query(spec);
}
```

The DataSource does raw I/O and lets exceptions propagate. It is an interface from `beak_core`, and `WormDataSource` implements it over the worm ORM. Because the service depends on the interface, worm types never leave `beak_backend`.

```dart title="packages/beak_core/lib/src/data/beak_data_source.dart"
abstract interface class BeakDataSource {
  /// Runs [spec] and returns the requested page of typed records, with
  /// every relation load in the spec eagerly resolved (Beak never
  /// lazy-loads).
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec);

  /// The record of [table] with primary key [id], or `null` when it does
  /// not exist (or is soft-deleted).
  Future<BeakRecord?> getOne(String table, Object id);

  /// Inserts [data] into [table] and returns the stored record (including
  /// database-assigned values).
  Future<BeakRecord> create(String table, BeakRecord data);

  /// Updates the record of [table] with primary key [id] with the values of
  /// [data] and returns the stored result.
  ///
  /// Throws a `BeakNotFoundException` when no such record exists.
  Future<BeakRecord> update(String table, Object id, BeakRecord data);

  /// Deletes the record of [table] with primary key [id] — softly when the
  /// model opts into soft deletes, unless [force] hard-deletes.
  ///
  /// Throws a `BeakNotFoundException` when no such record exists.
  Future<void> delete(String table, Object id, {bool force = false});

  /// Clears the soft-delete marker on the record with primary key [id],
  /// returning it as it now reads.
  ///
  /// A deletion the user can walk back is the difference between a panel
  /// people trust and one they are afraid of, and it only works if the row
  /// is still there — so this is the one operation that deliberately reaches
  /// past the soft-delete scope.
  ///
  /// Throws a [BeakNotFoundException] when no soft-deleted record has that
  /// id, and a [BeakValidationException] when the model does not soft-delete
  /// at all — restoring a hard-deleted row is not a thing that can be done,
  /// and reporting success would be a lie.
  Future<BeakRecord> restore(String table, Object id);

  /// The records of [table] whose primary keys appear in [ids], fetched in
  /// a single query (the reference-deduplication path).
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids);

  /// Links [relatedIds] to the record of [table] with primary key [id]
  /// through the to-many relation [relationKey]: belongs-to-many inserts
  /// pivot rows (skipping links that already exist), has-many re-parents
  /// the related rows' foreign keys.
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  );

  /// Unlinks [relatedIds] from the record of [table] with primary key [id]
  /// through the to-many relation [relationKey]: belongs-to-many removes
  /// the pivot rows, has-many clears the related rows' foreign keys.
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  );

  /// Computes [spec]'s aggregate (count/sum/avg) over the matching rows,
  /// returning `0` when no rows match.
  Future<num> aggregate(BeakAggregateSpec spec);
}

```

Around all three sits the catch boundary. `beakErrorMappingMiddleware` is the only code on the server that turns an exception into a response. A `BeakException` becomes its status and a JSON body, and anything else becomes an opaque 500 that reports to `onUnexpectedError` and tells the client nothing:

```dart title="packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart"
Middleware beakErrorMappingMiddleware({
  BeakUnexpectedErrorListener? onUnexpectedError,
}) =>
    (Handler inner) => (Request request) async {
      try {
        return await inner(request);
      } on BeakException catch (exception, stackTrace) {
        if (exception is BeakStorageException) {
          // A driver's message quotes the failure of the system behind it
          // (an endpoint, a bucket, a host). The operator gets all of it; the
          // caller learns only that storage failed.
          onUnexpectedError?.call(exception, stackTrace);
          return _jsonResponse(500, {
            'code': exception.code,
            'message': 'File storage failed.',
            ..._requestIdEntry(request),
          });
        }
        return _exceptionResponse(exception, request);
      } catch (error, stackTrace) {
        onUnexpectedError?.call(error, stackTrace);
        return _jsonResponse(500, {
          'code': 'internal',
          'message': 'Internal server error.',
          ..._requestIdEntry(request),
        });
      }
    };
```

The status mapping is a `switch` over a sealed family, so a new exception type doesn't compile until it has a status:

```dart title="packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart"
final int statusCode = switch (exception) {
  BeakValidationException() => 422,
  BeakNotFoundException() => 404,
  BeakAuthenticationException() => 401,
  BeakAuthorizationException() => 403,
  BeakConflictException() => 409,
  BeakConfigurationException() => 500,
  BeakStorageException() => 500,
  BeakInternalException() => 500,
  BeakPayloadTooLargeException() => 413,
  BeakTransportException() => 502,
};
```

The middleware sits in a fixed stack: request log, CORS, JSON, error mapping, auth, your own middleware, then the router. Auth and your own middleware sit inside the error mapping, so anything they throw becomes JSON too.

### The panel: Widget, ViewModel, Repository, DataSource

The Widget is a `HookWidget`. It reads `ReadonlySignal`s, forwards user intent and holds no data. `BeakDataTable` asks its view model to refresh and watches the page signal:

```dart title="packages/beak_frontend/lib/src/table/beak_data_table.dart"
useEffect(() {
  onViewModel?.call(viewModel);
  viewModel.refresh();
  return viewModel.dispose;
}, [viewModel]);
```

```dart title="packages/beak_frontend/lib/src/table/beak_data_table.dart"
return Watch.builder(
  builder: (context) {
    final page = viewModel.page.value;
    final rows = page?.items ?? const <BeakRecord>[];
    final int total = page?.total ?? 0;
```

The ViewModel owns state as signals and exposes them read-only. It turns intent (a sort, a page change, a search) into a new `BeakQuerySpec`, calls the repository and switches on the result. It never catches a data-source failure itself.

```dart title="packages/beak_frontend/lib/src/state/beak_view_model.dart"
abstract base class BeakViewModel {
  final List<void Function()> _cleanups = [];
  bool _isDisposed = false;

  /// Whether [dispose] has run.
  bool get isDisposed => _isDisposed;

  /// Creates a signal owned by this view model, disposed with it.
  ///
  /// Expose it upward as a [ReadonlySignal] field so widgets can read and
  /// watch — but never write — the state.
  @protected
  Signal<T> ownedSignal<T>(T value) {
    final owned = signal<T>(value);
    _cleanups.add(owned.dispose);
    return owned;
  }

  /// Releases every owned signal; further use is a programming error.
  @mustCallSuper
  void dispose() {
    for (final cleanup in _cleanups) {
      cleanup();
    }
    _cleanups.clear();
    _isDisposed = true;
  }
}
```

```dart title="packages/beak_frontend/lib/src/table/beak_table_view_model.dart"
Future<void> refresh() async {
  if (isDisposed) return;
  final int requestId = ++_latestRequestId;
  _loading.value = true;
  _error.value = null;
  final result = await _repository.query(_spec.value);
  if (isDisposed || requestId != _latestRequestId) {
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

The Repository is the catch boundary. Each method wraps a data-source call in `beakRun`, so a thrown `BeakException` comes back as a `BeakErr` and success as a `BeakOk`:

```dart title="packages/beak_frontend/lib/src/data/beak_run.dart"
Future<BeakResult<T>> beakRun<T>(
  Future<T> Function() operation, {
  BeakException? Function(Exception exception, StackTrace stack)? mapException,
}) async {
  try {
    return BeakOk(await operation());
  } on BeakException catch (exception) {
    return BeakErr(exception);
  } on Exception catch (exception, stack) {
    final mapped = mapException?.call(exception, stack);
    if (mapped != null) return BeakErr(mapped);
    rethrow;
  }
}
```

```dart title="packages/beak_frontend/lib/src/data/beak_resource_repository.dart"
/// Fetches one record; a missing id is a [BeakErr] with a not-found.
Future<BeakResult<BeakRecord>> getOne(String table, Object id) => beakRun(
  () async =>
      await dataSource.getOne(table, id) ??
      (throw BeakNotFoundException('No record of "$table" with id "$id".')),
);
```

Anything that is not a `BeakException` and that no mapper claims is rethrown. A programming error should crash loudly, not turn into a red banner.

The DataSource in the panel is a `ModelBeakDataSource`. It routes each model to its own transport if the model binds one, and to the HTTP source otherwise. The panel registers it once, next to a `BeakClient` and a session store, so widgets and view models never see a URL:

```dart title="packages/beak_frontend/lib/src/di/beak_locator.dart"
final source = ModelBeakDataSource(
  registry: registry,
  fallback: fallback,
  overrideBindings: dataSource != null,
  mapException: config.mapException,
  onUnauthorized: authority == null ? null : _endSessionOf(authority),
  refreshPolicy: config.refreshPolicy,
);
container
  ..registerSingleton<BeakModelActionRunner>(
    BeakModelActionRunner(),
    dispose: (runner) => runner.dispose(),
  )
  ..registerSingleton<BeakPanelConfig>(config)
  ..registerSingleton<BeakModelRegistry>(registry)
  ..registerSingleton<BeakDataSource>(
    source,
    dispose: (_) => source.dispose(),
  )
  ..registerSingleton<BeakThemeController>(
    BeakThemeController(config.initialThemeMode),
  );
```

### Where errors are caught

"One catch boundary per side" is the rule, and it has a few honest footnotes. Each catch has one job.

| Where | Catches | Does |
| --- | --- | --- |
| `beakErrorMappingMiddleware` (server) | everything | `BeakException` to status and JSON, the rest to an opaque 500 |
| `BeakGraphCommitService` (server) | `BeakException` inside the transaction | rolls back and answers with an `unapplied` receipt, not an HTTP error |
| `BeakClient` (core) | HTTP error bodies | decodes `code` back into the matching `BeakException` |
| `ModelBeakDataSource` (panel) | host exceptions | maps them with `mapException` into a `BeakException` and rethrows; it doesn't return results |
| `beakRun` in `BeakResourceRepository` (panel) | `BeakException` | returns `BeakErr`; other exceptions go to `mapException` or are rethrown |
| `BeakFormCommitRepository` (panel) | any `Exception` from a commit | returns an `unapplied` receipt for a typed refusal (422, 413, 401, 403, 404, 409) and an `unknown` one for anything that can't prove the server wrote nothing |

Actions go through the same repository: `executeBeakAction` wraps a row, bulk or global action in `BeakResourceRepository.run` and reports a `BeakErr` to the host. [Results and errors](results-and-errors.md) follows a failure across all of these.

### Where a transport plugs in

Every seam is an interface, so you replace one layer and leave the rest alone.

| Seam | Interface | Swap it for |
| --- | --- | --- |
| Panel to server | the `http.Client` under `BeakClient`, via `BeakPanel(httpClient:)` | a Serverpod tunnel (`ServerpodBeakHttpClient`) or a test client |
| Panel data source | `BeakDataSource`, via `BeakPanel(dataSource:)` or `BeakModel.dataSource` per model | a fake in a widget test, or typed RPC (`ServerpodDataSource`) |
| Server data source | `BeakDataSource`, `WormDataSource` by default | your own, via `defaults.build(dataSource:)`; graph commits are atomic only over a `WormDataSource` on a transactional adapter, and staged over anything else |
| Server database | worm's `DatabaseAdapter` | `ServerpodSessionAdapter`, so Beak runs on Serverpod's database |
| Server pipeline | `BeakServer(middleware:, routes:, router:)` | extra endpoints and middleware in front of the generated API |

The Serverpod admin app is the proof that the layers hold. The panel side is the unchanged `HttpBeakDataSource` over a tunnelling `http.Client`, and the server side is the unchanged Shelf pipeline, run in memory inside one endpoint method:

```dart title="packages/beak_serverpod_flutter/lib/src/serverpod_beak_data_source.dart"
HttpBeakDataSource serverpodBeakDataSource(BeakTunnelDispatch dispatch) =>
    HttpBeakDataSource(
      BeakClient(
        baseUrl: beakServerpodTunnelOrigin,
        httpClient: ServerpodBeakHttpClient(dispatch),
      ),
    );
```

## Why it is shaped this way

Throw freely below, catch once above. Handlers, services and data sources throw and stay short. The middleware is the only server code that knows about status codes, so error shaping lives in one file. On the panel the repository plays the same role, which is why a `ViewModel` can be read top to bottom without a `try`.

A layer you can replace is a layer with one dependency. The service knows `BeakDataSource`, not worm. The view model knows the repository, not HTTP. That is what lets a Serverpod session, a fake or a custom backend take a layer's place, and it is why `beak_core` has no Flutter and `beak_backend` exposes no worm types.

No fifth layer. A use-case class between view model and repository would hold no state and no I/O, only the sequence a view model already runs. Beak keeps that sequence in the view model, where the signals are.

## What it means for you

- Put validation, defaults and rules that must hold for every caller in a service or on the model, and let them throw a `BeakException`. Don't catch in a handler.
- Put anything a widget needs to show in a `ViewModel` signal, and switch on `BeakOk` and `BeakErr` from the repository. Don't write `try/catch` around a data-source call in a widget.
- Implement `BeakDataSource` for a new backend or test double, and hand it to `BeakPanel(dataSource:)`. Nothing above the interface changes.
- Don't add an endpoint that bypasses the middleware. If you embed `beakApiRouter` in your own Shelf app, wrap it in `beakJsonMiddleware` and `beakErrorMappingMiddleware` so typed exceptions still become JSON.

## Continue reading

- [How data flows](how-data-flows.md) the spec and the save plan these layers pass between them.
- [Results and errors](results-and-errors.md) the `BeakResult` and `BeakException` types both catch boundaries speak.
- [Backend flow](../architecture/backend-flow.md) the server side in contributor detail.
- [Frontend flow](../architecture/frontend-flow.md) the panel side in contributor detail.
- [Custom data sources](../extending/custom-data-sources.md) implementing `BeakDataSource` for your own backend.
