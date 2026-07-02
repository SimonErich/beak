# Phase 10 — beak_backend: auth guard + global search + CSV export

## Objective
Complete the backend: a minimal token/session auth guard with per-resource policies, a
global search endpoint over searchable columns, and CSV export driven by a `BeakQuerySpec`.

## Prerequisites
- Phase 09 `✅ DONE`.

## Files created (in `packages/beak_backend/lib/src/`)
- `auth/beak_auth_guard.dart`, `auth/token_session_store.dart`, `auth/beak_policy.dart`
- `auth/auth_router.dart` (login/logout/me)
- `search/global_search_service.dart`, `search/search_router.dart`
- `export/csv_export_service.dart`, `export/export_router.dart`
- barrel updates

## Auth (contract)
```dart
final class BeakPrincipal { const BeakPrincipal({required this.id, this.roles = const {}}); }
abstract interface class BeakAuthGuard {
  Future<BeakPrincipal?> authenticate(Request request); // returns principal or null
}
final class TokenSessionAuthGuard implements BeakAuthGuard {
  TokenSessionAuthGuard(this.store, {required this.secret});
  // Bearer token -> session lookup -> principal. Opaque tokens in TokenSessionStore.
}
abstract interface class BeakPolicy {
  bool canView(BeakPrincipal? p, String table);
  bool canCreate(BeakPrincipal? p, String table);
  bool canUpdate(BeakPrincipal? p, String table, Object id);
  bool canDelete(BeakPrincipal? p, String table, Object id);
}
```
- The auth middleware (slot added in Phase 07) now resolves a `BeakPrincipal` and stores
  it in the request context; CRUD/upload handlers consult the configured `BeakPolicy`
  before acting (deny → `BeakAuthorizationException` → 401/403).
- Endpoints: `POST /api/auth/login` (returns token), `POST /api/auth/logout`,
  `GET /api/auth/me`. Keep it minimal but real (hashed credentials, opaque session token).
  A `BeakAllowAllPolicy` default keeps things open for the reference app unless configured.

## Global search (contract)
```dart
final class GlobalSearchService {
  GlobalSearchService(this.registry, this.dataSource);
  Future<List<BeakSearchHit>> search(String term, {int perModel = 5, List<String>? tables});
  // For each registered model, run a BeakQuerySpec.searching(term, searchableColumns)
  // limited to perModel; return typed hits (table, id, displayLabel, matchedColumnKey).
}
```
Endpoint: `GET /api/search?q=…` → grouped `BeakSearchHit`s. Uses each model's
`searchable` columns and `displayColumnKey`.

## CSV export (contract)
```dart
final class CsvExportService {
  CsvExportService(this.registry, this.dataSource);
  Stream<List<int>> exportCsv(String table, BeakQuerySpec spec);
  // Streams a CSV: header from the model's table-context columns, rows from the query
  // (paged/iterated). Values rendered per column's intent (dates ISO, decimals formatted).
}
```
Endpoint: `POST /api/{table}/export` body: `BeakQuerySpec` → `text/csv` stream
(`Content-Disposition: attachment`).

## Tests to write FIRST
- `auth_test.dart` — login issues a token; `me` returns the principal for a valid Bearer;
  invalid/expired token → 401; logout invalidates; password hashing verified (no plaintext
  stored).
- `policy_test.dart` — with a restrictive `BeakPolicy`, CRUD handlers enforce it
  (403 on denied create/update/delete; 401 when unauthenticated and view is protected).
- `global_search_test.dart` — seeds two models; a term returns grouped hits limited per
  model; only `searchable` columns match; display labels correct.
- `csv_export_test.dart` — export streams a well-formed CSV (parse it back); header matches
  table-context columns; date/decimal formatting correct; honors the posted spec's filter.

## Implementation notes / constraints
- Layering intact: guard/policy checks in handlers/middleware (the auth boundary), logic
  in services. No `dynamic`; principals/hits/policies all typed.
- Tokens are opaque + stored server-side (`TokenSessionStore`, swappable; default
  in-memory for tests, a Postgres-backed impl acceptable but not required at V1).
- CSV rendering reuses the column intent formatting (share with the frontend's display
  logic where practical, but backend renders server-side).

## Definition of Done (gate)
- [ ] analyze 0 · tests green · coverage ≥ 90% · format clean.
- [ ] Protected endpoints enforce auth + policy (proven).
- [ ] Search + CSV export proven over seeded data.
- [ ] STATE.md row 10 → `✅ DONE` + SHA. Backend is now feature-complete.

## Commit
`feat(beak_backend): add auth guard with policies, global search and CSV export`
