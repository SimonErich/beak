# Phase 11 — beak_frontend: panel foundation + data-provider client

## Objective
Create the Flutter side's backbone: the `BeakPanel` app shell (obers_ui + go_router +
GetIt + Signals), and the typed data-provider client that talks to `beak_backend` with
reference deduplication and optimistic-update-with-undo. This is the first Flutter phase —
obers_ui path deps must resolve.

## Prerequisites
- Phase 04 `✅ DONE` (shared `BeakQuerySpec`/`BeakRecord` from `beak_core`).
- `~/Flutters/obers_ui` present (obers_ui + obers_ui_autoforms + obers_ui_charts).
  If absent → `NEEDS_HUMAN.md` and stop (external blocker for all frontend phases).

## Files created (in `packages/beak_frontend/lib/src/`)
- `panel/beak_panel.dart`, `panel/beak_panel_config.dart`, `panel/beak_router.dart`
- `data/beak_client.dart` (typed HTTP client), `data/http_beak_data_source.dart`
- `data/reference_cache.dart` (dedup), `data/optimistic.dart`
- `di/beak_locator.dart` (GetIt setup)
- `state/*` (Signals-based view-model base)
- `beak_frontend` local `analysis_options.yaml` (Flutter lints + Material-import ban)
- barrel updates

## Public API to implement (contract)

### Panel
```dart
final class BeakResource {                 // registered UI resource (pairs with a BeakModel)
  const BeakResource({required this.model, required this.icon, this.label,
      this.actions = const [], this.filters = const [], this.dashboard});
  final BeakModel model; final BeakIconToken icon; ...
}
final class BeakPanelConfig {
  const BeakPanelConfig({required this.title, required this.resources,
      required this.apiBaseUrl, this.theme, this.auth});
  final List<BeakResource> resources; final String apiBaseUrl; ...
}
class BeakPanel extends HookWidget {       // NO StatefulWidget
  const BeakPanel({super.key, required this.config});
  // Builds OiApp.router with a go_router derived from resources; wraps pages in
  // OiAppShell whose navigation is generated from config.resources (one OiNavItem each);
  // registers dependencies in GetIt; provides theme via OiThemeData.
}
```
Routing (go_router), generated per resource: `/{table}` (list), `/{table}/create`,
`/{table}/{id}` (show), `/{table}/{id}/edit`, plus `/` (dashboard) and `/login`. Actual
page widgets are filled by Phases 12–14; here provide route scaffolding rendering
`OiResourcePage` placeholders so navigation works and is testable.

### Typed client + HTTP data source (mirrors the backend surface)
```dart
final class BeakClient {                   // thin typed transport over package:http
  BeakClient({required this.baseUrl, this.tokenProvider});
  Future<BeakPage<BeakRecord>> query(String table, BeakQuerySpec spec);
  Future<BeakRecord?> getOne(String table, Object id);
  Future<BeakRecord> create(String table, BeakRecord data);
  Future<BeakRecord> update(String table, Object id, BeakRecord data);
  Future<void> delete(String table, Object id, {bool force = false});
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids);
  Future<void> attach(...); Future<void> detach(...);
  Future<BeakStoredFile> upload(String table, String columnKey, BeakUpload file);
  Future<List<BeakSearchHit>> search(String term);
}
final class HttpBeakDataSource implements BeakDataSource { HttpBeakDataSource(this.client); ... }
```
The frontend reuses the SAME `BeakDataSource` interface and `BeakQuerySpec`/`BeakRecord`
types from `beak_core` — the client just serializes them to the REST surface. All errors
mapped from HTTP status → typed `BeakException`.

### Reference dedup + optimism
```dart
final class ReferenceCache {               // batches getOne calls into batchGet, caches
  Future<BeakRecord> resolve(String table, Object id);   // coalesces within a frame
  void invalidate(String table, Object id);
}
final class BeakOptimistic {               // wraps OiOptimisticAction for mutations
  static Future<void> mutate(BuildContext context, {required VoidCallback apply,
      required VoidCallback rollback, required Future<void> Function() commit,
      required String message});
}
```

### DI + view-model base
`beak_locator.dart` registers `BeakClient`, `HttpBeakDataSource`, `ReferenceCache`,
repositories, per-resource view models in GetIt. `BeakViewModel` base exposes
`ReadonlySignal` state; never `try/catch` (repository is the catch boundary).

## Tests to write FIRST
- `beak_client_test.dart` — with a mocked `http.Client`: each method issues the right
  method/path/body and parses responses into typed objects; HTTP 422 → `BeakValidationException`
  with fieldErrors; 404 → `BeakNotFoundException`; 401/403 → auth exceptions.
- `reference_cache_test.dart` — multiple `resolve` calls for the same table within a frame
  coalesce into ONE `batchGet` (assert on the fake data source call count); cache hit
  avoids refetch; invalidate works.
- `beak_panel_test.dart` (widget) — pump `BeakPanel` with 2 resources + a fake data
  source; `OiAppShell` renders a nav item per resource; go_router navigates to each
  list/create/show/edit route; **no Material widget** in the tree (assert by type/finder);
  login route renders `OiAuthPage`.
- `optimistic_test.dart` (widget) — a mutation applies immediately, shows an undo affordance,
  commits on timeout, and rolls back on undo.

## Implementation notes / constraints
- `HookWidget` only. State via Signals. DI via GetIt. Routing via go_router. Zero Material.
- The Material-import ban is enforced by the local analysis config + a CI/grep check that
  fails the gate on any `material.dart`/`cupertino.dart` import in `beak_frontend`.
- Depend on `beak_core`, `obers_ui`, `obers_ui_autoforms`, `obers_ui_charts` (path),
  `go_router`, `get_it`, `signals`/`flutter_hooks` (match obers_ui's versions), `http`.

## Definition of Done (gate)
- [ ] `flutter analyze` 0 issues · `flutter test` green · coverage ≥ 85% · format clean.
- [ ] Material-import ban is active and green.
- [ ] Panel navigation + client + dedup + optimism proven by tests.
- [ ] STATE.md row 11 → `✅ DONE` + SHA.

## Commit
`feat(beak_frontend): add BeakPanel shell, typed client, reference dedup and optimism`
