# Phase 08 — beak_backend: auto-generated CRUD endpoints

## Objective
From a registered `BeakModel`, auto-expose the full CRUD + query REST surface over Shelf,
with server-side validation (from column rules), soft-delete support, and relationship
attach/detach — no per-model endpoint code.

## Prerequisites
- Phase 07 `✅ DONE`.

## Files created (in `packages/beak_backend/lib/src/`)
- `endpoints/beak_resource_router.dart` (builds routes for a model)
- `endpoints/crud_handlers.dart`
- `service/beak_resource_service.dart` (logic + validation boundary)
- `service/validation_service.dart`
- barrel updates

## REST surface (generated per registered model, `table` = plural snake)
```
POST   /api/{table}/query          body: BeakQuerySpec JSON  -> BeakPage<BeakRecord>
GET    /api/{table}/{id}                                       -> BeakRecord
POST   /api/{table}                body: record fields         -> created BeakRecord (201)
PATCH  /api/{table}/{id}           body: partial fields        -> updated BeakRecord
DELETE /api/{table}/{id}?force=…                                -> 204 (soft unless force)
POST   /api/{table}/batch          body: {ids:[...]}           -> [BeakRecord]  (dedup)
POST   /api/{table}/{id}/relations/{relationKey}/attach  body:{ids}  -> 204
POST   /api/{table}/{id}/relations/{relationKey}/detach  body:{ids}  -> 204
```
`beak_resource_router.dart` mounts these using `shelf_router`, wiring each to the service.
A top-level `BeakServer` composes a router per registered model.

## Service + validation (contract)
```dart
final class BeakResourceService {
  BeakResourceService(this.model, this.dataSource);
  final BeakModel model; final BeakDataSource dataSource;
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec);
  Future<BeakRecord> getOne(Object id);          // throws BeakNotFoundException
  Future<BeakRecord> create(BeakRecord input);   // validates, then dataSource.create
  Future<BeakRecord> update(Object id, BeakRecord input);
  Future<void> delete(Object id, {bool force = false});
  Future<void> attach(Object id, String relationKey, List<Object> ids);
  Future<void> detach(Object id, String relationKey, List<Object> ids);
}
final class ValidationService {
  const ValidationService();
  /// Runs each column's rules over the incoming record; aggregates typed field errors;
  /// throws BeakValidationException(fieldErrors) if any fail. Unknown/extra keys rejected.
  void validate(BeakModel model, BeakRecord input, {required bool isCreate});
}
```
Rules:
- Validation lives in `ValidationService`, called by the service — **never** in handlers
  (handlers only parse/route/map-errors), matching the layering rule.
- Create vs update: `required` enforced on create; on update only provided fields
  validated (partial semantics) but still type-checked.
- Soft delete: if `model.softDeletes`, `DELETE` sets `deleted_at`; `?force=true` hard
  deletes; `query` excludes trashed unless `spec.withTrashed`.
- Attach/detach only valid for `BeakBelongsToMany`/`BeakHasMany` relations (else 400).

## Tests to write FIRST
- `crud_handlers_test.dart` — full CRUD contract via the Shelf `Handler` and `InMemoryAdapter`:
  - create returns 201 + body with generated id + timestamps;
  - invalid create returns 422 with `fieldErrors` for each failing column (assert exact
    shape, typed);
  - getOne 404 for missing id;
  - query returns a correct `BeakPage` (total/page/perPage) and honors filter/sort/search
    from the posted spec;
  - patch updates only provided fields; delete soft-deletes then query hides it; `force`
    removes it; batch returns requested records in one query.
- `relations_test.dart` — attach/detach on a many relation persists via pivot; attach on a
  belongsTo relation is rejected (400).
- `validation_service_test.dart` — each rule surfaces the right message; extra keys
  rejected; create vs update semantics.
- Query-count regression: a list with a relation load makes the expected (small) number
  of queries (`InMemoryQueryLogger`).

## Implementation notes / constraints
- Handlers are thin and pure-ish; all logic in the service. Error mapping is the
  middleware's job (Phase 07).
- Everything typed via `BeakRecord`/`BeakValue`; request bodies parsed into these with
  validation, never surfaced as `Map<String,dynamic>` beyond the parse boundary.
- Generated routes must be data-driven from the registry so adding a model needs zero new
  handler code (test: register a second model and its endpoints work).

## Definition of Done (gate)
- [ ] analyze 0 · tests green · coverage ≥ 90% · format clean.
- [ ] Registering a new `BeakModel` yields a working CRUD surface with no new handler code
      (proved by a test that registers two models).
- [ ] 422 validation body shape is typed and asserted.
- [ ] STATE.md row 08 → `✅ DONE` + SHA.

## Commit
`feat(beak_backend): generate CRUD + query + relations endpoints from model metadata`
